-- Eggs + pets (server). Everything that matters happens here: the roll, the price, the inventory.
--   HatchEgg(eggId, count 1|3|8) -> ok, results | message   (must be standing at that egg's stand;
--                                   8 needs the Hatch 8 pass)
--   PetAction(action, arg)       -> ok, message
--     "equip" | "unequip" | "delete" | "golden" | "lock" (toggle) uid; "deleteMany" { uids };
--     "equipBest"; "upgradeStorage" | "upgradeSlots"; "autoDelete" kind (toggle);
--     "fastHatch" | "tradesOff" bool
-- Saved in player attributes (PlayerData): Pets "uid:Kind:G:L;...", EquippedPets "uid,...", NextPetId,
-- StorageLevel, SlotLevel, AutoDelete "Kind,Kind", FastHatch, TradesOff.
-- Derived (not saved): PetMultiplier (used by GameServer's payouts) and PetKinds (equipped kinds,
-- which every client reads to draw the pets following that player).
-- While a trade is open (attribute Trading, TradeServer) pets can't be deleted or fused.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LobbyLayout = require(ServerScriptService.LobbyLayout)
local PlayerData = require(ServerScriptService.PlayerData)

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function remote(className, name)
	local r = remotes:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local HatchEgg = remote("RemoteFunction", "HatchEgg")
local PetAction = remote("RemoteFunction", "PetAction")
local Notify = remote("RemoteEvent", "Notify")
local HatchNews = remote("RemoteEvent", "HatchNews") -- (a plain chat line for everyone)
remote("RemoteEvent", "PaidHatch") -- (ExtrasServer: the Royal egg show after a purchase)

local rng = Random.new()
local busy = {} -- [player] = true while a hatch is being handled
local lastHatch = {} -- [player] = os.clock() of the last hatch (auto hatch can't spam)

-- Pet list helpers ----------------------------------------------------------------------------
local function slots(player) -- 3 pet slots, +1 per rebirth, + gamepasses + upgrades (Config.petSlotsFor)
	return Config.petSlotsFor(player)
end

local function getPets(player)
	return Config.parsePets(player:GetAttribute("Pets"))
end

local function setPets(player, list)
	player:SetAttribute("Pets", Config.serializePets(list))
end

local function getEquipped(player, pets)
	-- only uids the player still owns, at most the slots they have
	local owned = {} -- [uid] = pet record { uid, kind, golden, locked }
	for _, p in ipairs(pets or getPets(player)) do
		owned[p.uid] = p
	end
	local list = {}
	for uid in string.gmatch(player:GetAttribute("EquippedPets") or "", "%d+") do
		uid = tonumber(uid)
		if owned[uid] and #list < slots(player) and not table.find(list, uid) then
			table.insert(list, uid)
		end
	end
	return list, owned
end

local function setEquipped(player, uids)
	local parts = {}
	for _, uid in ipairs(uids) do
		table.insert(parts, tostring(uid))
	end
	player:SetAttribute("EquippedPets", table.concat(parts, ","))
end

-- strongest first for this player (scaling pets follow their tier)
local function bestFirstFor(player)
	local tier = Config.playerTier(player)
	return function(a, b)
		local ma, mb = Config.petMult(a.kind, a.golden, tier), Config.petMult(b.kind, b.golden, tier)
		if ma ~= mb then
			return ma > mb
		end
		return a.uid < b.uid
	end
end

-- Pet Index: every kind you've ever owned (kept even if you delete the pet); a full egg set
-- (all of its pets) gives +6% money forever (IndexSets, used by GameServer).
local function addToIndex(player, kinds)
	local index = {}
	for kind in string.gmatch(player:GetAttribute("PetIndex") or "", "%w+") do
		index[kind] = true
	end
	local changed = false
	for _, kind in ipairs(kinds) do
		if not index[kind] then
			index[kind] = true
			changed = true
		end
	end
	if changed then
		local list = {}
		for kind in pairs(index) do
			table.insert(list, kind)
		end
		table.sort(list)
		player:SetAttribute("PetIndex", table.concat(list, ","))
	end
	player:SetAttribute("IndexSets", Config.indexSets(index))
end

-- Recompute the multiplier + the kinds other players see following you.
local function refresh(player)
	local equipped, owned = getEquipped(player)
	local kinds = {}
	for _, uid in ipairs(equipped) do
		local p = owned[uid]
		table.insert(kinds, p.kind .. (p.golden and ":G" or "")) -- (":G": everyone draws it golden)
	end
	local mult = Config.petMultiplier(kinds, Config.playerTier(player))
	if Config.hasPass(player, "RainbowPets") then
		mult = 1 + (mult - 1) * Config.PASS.RainbowBoost
	end
	player:SetAttribute("PetMultiplier", mult)
	player:SetAttribute("PetKinds", table.concat(kinds, ","))
	local all = {}
	for _, p in pairs(owned) do
		table.insert(all, p.kind)
	end
	addToIndex(player, all)
end

-- Hatching --------------------------------------------------------------------------------------
-- One pet from `egg` (luck: Config.luckFactor - passes, boosts, events, Lucky Hour).
local function rollPet(egg, player)
	local chance = Config.eggChances(egg, Config.luckFactor(player))
	local roll = rng:NextNumber(0, 100)
	local acc = 0
	for rank = #egg.pets, 1, -1 do -- rarest first so rounding never eats the best pet
		acc += chance[rank]
		if roll < acc then
			return egg.pets[rank]
		end
	end
	return egg.pets[1]
end

local function eggIndex(id)
	for i, e in ipairs(Config.Eggs) do
		if e.id == id then
			return i
		end
	end
end

local function autoDeleteSet(player)
	local set = {}
	for kind in string.gmatch(player:GetAttribute("AutoDelete") or "", "%w+") do
		set[kind] = true
	end
	return set
end

local function canAutoDelete(kind)
	local pet = Config.Pets[kind]
	return pet ~= nil and Config.Rarities[pet.rarity].order < Config.Rarities[Config.AUTO_DELETE_BELOW].order
end

-- Roll `count` pets from `egg` for `player` and keep them (auto-delete skips the ones you don't
-- want; they still count for the Index). Returns results { uid?, kind, deleted? } or nil, message
-- when they don't fit (nothing changed then). overflow = paid hatches may go over storage.
local function grant(player, egg, count, overflow)
	local pets = getPets(player)
	local auto = egg.robux and {} or autoDeleteSet(player) -- (paid pets are never auto-deleted)
	local rolled, keep = {}, 0
	for _ = 1, count do
		local kind = rollPet(egg, player)
		local deleted = auto[kind] and canAutoDelete(kind) or nil
		table.insert(rolled, { kind = kind, deleted = deleted })
		if not deleted then
			keep += 1
		end
	end
	if not overflow and #pets + keep > Config.maxPetsFor(player) then
		return nil, "Your pets are full (" .. Config.maxPetsFor(player) .. ")! Delete some or get more storage."
	end
	local nextId = player:GetAttribute("NextPetId") or 1
	local kinds = {}
	for _, r in ipairs(rolled) do
		local pet = Config.Pets[r.kind]
		table.insert(kinds, r.kind)
		if not r.deleted then
			r.uid = nextId
			table.insert(pets, { uid = nextId, kind = r.kind })
			nextId += 1
		end
		-- rare pets (Legendary and up): one plain line in everyone's chat, nothing else (owner)
		if Config.Rarities[pet.rarity].order >= Config.Rarities.Legendary.order then
			HatchNews:FireAllClients(player.DisplayName .. " has just hatched a " .. pet.rarity .. " " .. pet.name)
		end
	end
	player:SetAttribute("NextPetId", nextId)
	player:SetAttribute("StatEggs", (player:GetAttribute("StatEggs") or 0) + count)
	setPets(player, pets)
	addToIndex(player, kinds)

	-- fill empty pet slots with the new pets (best first) so hatching feels instant
	local equipped = getEquipped(player, pets)
	local fresh = {}
	for _, r in ipairs(rolled) do
		if r.uid then
			table.insert(fresh, r)
		end
	end
	table.sort(fresh, bestFirstFor(player))
	for _, r in ipairs(fresh) do
		if #equipped < slots(player) then
			table.insert(equipped, r.uid)
		end
	end
	setEquipped(player, equipped)
	refresh(player)
	return rolled
end

-- where an egg's stand is (regular eggs by index, the others have their own spot)
local function standOf(egg)
	local index = eggIndex(egg.id)
	return egg.stand or (index and LobbyLayout.eggStand(index))
end

HatchEgg.OnServerInvoke = function(player, eggId, count)
	if not player:GetAttribute("DataLoaded") then
		return false, "Loading your save..."
	end
	if typeof(eggId) ~= "string" or (count ~= 1 and count ~= 3 and count ~= 8) then
		return false, "Unknown egg."
	end
	local egg = Config.getEgg(eggId)
	if not egg or busy[player] then
		return false, "Unknown egg."
	end
	if count == 8 and not Config.hasPass(player, "Hatch8") then
		return false, "Hatch 8 needs the Hatch 8 pass (STORE)."
	end
	if egg.robux then
		return false, "The " .. egg.name .. " is bought with Robux."
	end
	if egg.limited and Config.limitedEgg() ~= egg then
		return false, "The " .. egg.name .. " is gone - a new limited egg is here!"
	end
	if egg.event and not Config.eventActive(egg.event) then
		return false, "The " .. egg.name .. " is gone until the next event!"
	end
	if player:GetAttribute("Flying") then
		return false, "Can't hatch while flying!"
	end
	if (player:GetAttribute("UnlockedStage") or 1) < egg.stage then
		return false, "Unlock Stage " .. egg.stage .. " to open the " .. egg.name .. "!"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local standPos = standOf(egg)
	if not root or not standPos or (root.Position - standPos).Magnitude > 24 then
		return false, "Walk up to the egg first!"
	end
	if os.clock() - (lastHatch[player] or 0) < 0.4 then
		return false, "Slow down!"
	end
	local cost = Config.eggPrice(egg, player) * count
	local currency = egg.currency or "Money"
	local have = player:GetAttribute(currency) or 0
	if have < cost then
		if currency == "Candy" then
			return false, "You need " .. (cost - have) .. " more 🍬 candy! Grab coins in flight to get candy."
		elseif currency == "Snowflakes" then
			return false, "You need " .. (cost - have) .. " more ❄ snowflakes! Grab coins in flight to get them."
		end
		return false, "You need $" .. Config.abbreviate(cost - have) .. " more!"
	end

	busy[player] = true
	lastHatch[player] = os.clock()
	local results, msg = grant(player, egg, count, false)
	if results then
		player:SetAttribute(currency, have - cost)
		PlayerData.saveSoon(player) -- (throttled: eggs get hatched back to back)
	end
	busy[player] = nil
	if not results then
		return false, msg
	end
	return true, results
end

-- Paid hatches (Royal egg developer products, ExtrasServer): ServerStorage.HatchFor:Invoke(player,
-- eggId, count) -> results (always fits: storage may go over).
local HatchFor = ServerStorage:FindFirstChild("HatchFor") or Instance.new("BindableFunction")
HatchFor.Name = "HatchFor"
HatchFor.Parent = ServerStorage
HatchFor.OnInvoke = function(player, eggId, count)
	local egg = Config.getEgg(eggId)
	if not egg then
		return nil
	end
	return (grant(player, egg, count, true))
end

-- Inventory actions -----------------------------------------------------------------------------
local function money(player)
	return player:GetAttribute("Money") or 0
end

local function deleteUids(player, pets, equipped, uids)
	local gone = {}
	for _, uid in ipairs(uids) do
		gone[uid] = true
	end
	local kept, n = {}, 0
	for _, p in ipairs(pets) do
		if gone[p.uid] and not p.locked then
			n += 1
		else
			table.insert(kept, p)
		end
	end
	local newEquipped = {}
	for _, e in ipairs(equipped) do
		if not gone[e] then
			table.insert(newEquipped, e)
		end
	end
	setPets(player, kept)
	setEquipped(player, newEquipped)
	refresh(player)
	return n
end

PetAction.OnServerInvoke = function(player, action, arg)
	if not player:GetAttribute("DataLoaded") then
		return false, "Loading your save..."
	end
	if typeof(action) ~= "string" then
		return false, "?"
	end
	local pets = getPets(player)
	local equipped, owned = getEquipped(player, pets)
	local trading = player:GetAttribute("Trading") == true

	if action == "equipBest" then
		table.sort(pets, bestFirstFor(player))
		local best = {}
		for i = 1, math.min(slots(player), #pets) do
			table.insert(best, pets[i].uid)
		end
		setEquipped(player, best)
		refresh(player)
		return true, #best > 0 and "Equipped your best pets!" or "You have no pets yet!"
	elseif action == "upgradeStorage" then
		local level = player:GetAttribute("StorageLevel") or 0
		local price = Config.STORAGE.prices[level + 1]
		if not price then
			return false, "Pet storage is maxed out!"
		end
		if money(player) < price then
			return false, "You need $" .. Config.abbreviate(price - money(player)) .. " more!"
		end
		player:SetAttribute("Money", money(player) - price)
		player:SetAttribute("StorageLevel", level + 1)
		PlayerData.saveSoon(player)
		return true, "Pet storage: " .. Config.maxPetsFor(player) .. " pets!"
	elseif action == "upgradeSlots" then
		local level = player:GetAttribute("SlotLevel") or 0
		local price = Config.SLOT_PRICES[level + 1]
		if not price then
			return false, "Pet slots are maxed out!"
		end
		if money(player) < price then
			return false, "You need $" .. Config.abbreviate(price - money(player)) .. " more!"
		end
		player:SetAttribute("Money", money(player) - price)
		player:SetAttribute("SlotLevel", level + 1)
		PlayerData.saveSoon(player)
		return true, "+1 pet slot! You can equip " .. slots(player) .. " pets."
	elseif action == "autoDelete" then
		if typeof(arg) ~= "string" or not Config.Pets[arg] then
			return false, "?"
		end
		if not canAutoDelete(arg) then
			return false, "Legendary and rarer pets are always kept."
		end
		local set = autoDeleteSet(player)
		set[arg] = not set[arg] or nil
		local list = {}
		for kind in pairs(set) do
			table.insert(list, kind)
		end
		table.sort(list)
		player:SetAttribute("AutoDelete", table.concat(list, ","))
		local name = Config.Pets[arg].name
		return true, set[arg] and ("🗑 " .. name .. " will be deleted when you hatch it.") or (name .. " will be kept again.")
	elseif action == "fastHatch" or action == "tradesOff" then
		player:SetAttribute(action == "fastHatch" and "FastHatch" or "TradesOff", arg == true)
		return true, ""
	elseif action == "deleteMany" then
		if trading then
			return false, "Finish your trade first!"
		end
		if typeof(arg) ~= "table" then
			return false, "?"
		end
		local uids = {}
		for _, uid in ipairs(arg) do
			if typeof(uid) == "number" and owned[uid] and not owned[uid].locked then
				table.insert(uids, uid)
			end
			if #uids >= 500 then
				break
			end
		end
		local n = deleteUids(player, pets, equipped, uids)
		return true, n == 1 and "1 pet deleted." or (n .. " pets deleted.")
	end

	local uid = arg
	if typeof(uid) ~= "number" or not owned[uid] then
		return false, "You don't have that pet."
	end
	local name = (owned[uid].golden and "Golden " or "") .. Config.Pets[owned[uid].kind].name
	local at = table.find(equipped, uid)
	if action == "equip" then
		if at then
			return true, name .. " is already following you."
		end
		if #equipped >= slots(player) then
			return false, "You can equip " .. slots(player) .. " pets. Unequip one first! (Rebirth or upgrade for more slots)"
		end
		table.insert(equipped, uid)
		setEquipped(player, equipped)
		refresh(player)
		return true, name .. " equipped!"
	elseif action == "unequip" then
		if at then
			table.remove(equipped, at)
			setEquipped(player, equipped)
			refresh(player)
		end
		return true, name .. " unequipped."
	elseif action == "lock" then
		owned[uid].locked = not owned[uid].locked
		setPets(player, pets)
		return true, owned[uid].locked and ("🔒 " .. name .. " is locked: it can't be deleted or traded.") or (name .. " unlocked.")
	elseif action == "golden" then
		if trading then
			return false, "Finish your trade first!"
		end
		-- fuse GOLDEN_COST copies of this pet (unequipped ones first; locked ones are never used,
		-- except the one you pressed) into one Golden pet
		local base = owned[uid]
		if base.golden then
			return false, name .. " is already golden!"
		end
		local same = {}
		for _, p in ipairs(pets) do
			if p.kind == base.kind and not p.golden and (not p.locked or p.uid == uid) then
				table.insert(same, p)
			end
		end
		if #same < Config.GOLDEN_COST then
			return false, "You need " .. Config.GOLDEN_COST .. " unlocked " .. name .. " pets (you have " .. #same .. ")."
		end
		table.sort(same, function(a, b)
			-- the one you pressed first, then unequipped, then the rest
			local ka = (a.uid == uid and 0) or (table.find(equipped, a.uid) and 2 or 1)
			local kb = (b.uid == uid and 0) or (table.find(equipped, b.uid) and 2 or 1)
			if ka ~= kb then
				return ka < kb
			end
			return a.uid < b.uid
		end)
		local used, wasEquipped = {}, false
		for i = 1, Config.GOLDEN_COST do
			used[same[i].uid] = true
			if table.find(equipped, same[i].uid) then
				wasEquipped = true
			end
		end
		local kept = {}
		for _, p in ipairs(pets) do
			if not used[p.uid] then
				table.insert(kept, p)
			end
		end
		local newUid = player:GetAttribute("NextPetId") or 1
		player:SetAttribute("NextPetId", newUid + 1)
		table.insert(kept, { uid = newUid, kind = base.kind, golden = true, locked = base.locked })
		local newEquipped = {}
		for _, e in ipairs(equipped) do
			if not used[e] then
				table.insert(newEquipped, e)
			end
		end
		if wasEquipped then
			table.insert(newEquipped, 1, newUid)
		end
		-- fill any free slots with the best pets you have (the new golden one included)
		local pool = table.clone(kept)
		table.sort(pool, bestFirstFor(player))
		for _, p in ipairs(pool) do
			if #newEquipped >= slots(player) then
				break
			end
			if not table.find(newEquipped, p.uid) then
				table.insert(newEquipped, p.uid)
			end
		end
		setPets(player, kept)
		setEquipped(player, newEquipped)
		refresh(player)
		PlayerData.saveSoon(player)
		local pet = Config.Pets[base.kind]
		if Config.Rarities[pet.rarity].order >= Config.Rarities.Epic.order then
			Notify:FireAllClients("⭐ " .. player.DisplayName .. " made a GOLDEN " .. pet.name .. "!", Color3.fromRGB(255, 215, 60))
		end
		return true, newUid
	elseif action == "delete" then
		if trading then
			return false, "Finish your trade first!"
		end
		if owned[uid].locked then
			return false, "🔒 " .. name .. " is locked. Unlock it first."
		end
		deleteUids(player, pets, equipped, { uid })
		return true, name .. " deleted."
	end
	return false, "?"
end

-- Free pet (Lucky Spin prize): a normal roll from the best egg you've unlocked, put straight into an
-- empty slot. ServerStorage.GivePet:Invoke(player) -> pet kind, or nil when your pets are full.
local GivePet = ServerStorage:FindFirstChild("GivePet") or Instance.new("BindableFunction")
GivePet.Name = "GivePet"
GivePet.Parent = ServerStorage
GivePet.OnInvoke = function(player)
	local pets = getPets(player)
	if #pets >= Config.maxPetsFor(player) then
		return nil
	end
	local egg = Config.Eggs[Config.playerTier(player)]
	local kind = rollPet(egg, player)
	local uid = player:GetAttribute("NextPetId") or 1
	table.insert(pets, { uid = uid, kind = kind })
	player:SetAttribute("NextPetId", uid + 1)
	setPets(player, pets)
	local equipped = getEquipped(player, pets)
	if #equipped < slots(player) then
		table.insert(equipped, uid)
		setEquipped(player, equipped)
	end
	refresh(player)
	return kind
end

-- Players ---------------------------------------------------------------------------------------
local function watch(player)
	for _, attr in ipairs({ "Pets", "EquippedPets", "DataLoaded", "Rebirths", "UnlockedStage", "SlotLevel", "Pass_RainbowPets", "Pass_VIP", "Pass_PetSlots" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			refresh(player)
		end)
	end
	refresh(player)
end

Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(watch, p)
end
Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	lastHatch[player] = nil
end)
