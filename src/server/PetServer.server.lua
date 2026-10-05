-- Eggs + pets (server). Everything that matters happens here: the roll, the price, the inventory.
--   HatchEgg(eggId, count 1|3) -> ok, results | message   (must be standing at that egg's stand)
--   PetAction(action, uid)     -> ok, message             ("equip" | "unequip" | "delete" | "equipBest")
-- Saved in player attributes (PlayerData): Pets "uid:Kind;...", EquippedPets "uid,...", NextPetId.
-- Derived (not saved): PetMultiplier (used by GameServer's payouts) and PetKinds (equipped kinds,
-- which every client reads to draw the pets following that player).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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

local rng = Random.new()
local busy = {} -- [player] = true while a hatch is being handled
local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary" }

-- Pet list helpers ----------------------------------------------------------------------------
local function slots(player) -- 3 pet slots, +1 per rebirth, + gamepasses (Config.petSlotsFor)
	return Config.petSlotsFor(player)
end

local function getPets(player)
	return Config.parsePets(player:GetAttribute("Pets"))
end

local function setPets(player, list)
	local parts = {}
	for _, p in ipairs(list) do
		table.insert(parts, p.uid .. ":" .. p.kind .. (p.golden and ":G" or ""))
	end
	player:SetAttribute("Pets", table.concat(parts, ";"))
end

local function getEquipped(player, pets)
	-- only uids the player still owns, at most MAX_EQUIPPED
	local owned = {} -- [uid] = pet record { uid, kind, golden }
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

-- Recompute the multiplier + the kinds other players see following you.
local function refresh(player)
	local equipped, owned = getEquipped(player)
	local kinds = {}
	for _, uid in ipairs(equipped) do
		local p = owned[uid]
		table.insert(kinds, p.kind .. (p.golden and ":G" or "")) -- (":G": everyone draws it golden)
	end
	local mult = Config.petMultiplier(kinds)
	if Config.hasPass(player, "RainbowPets") then
		mult = 1 + (mult - 1) * Config.PASS.RainbowBoost
	end
	player:SetAttribute("PetMultiplier", mult)
	player:SetAttribute("PetKinds", table.concat(kinds, ","))

	-- Pet Index: every kind you've ever owned (kept even if you delete the pet); a full egg set
	-- (all 4 of its pets) gives +10% money forever (IndexSets, used by GameServer).
	local index = {}
	for kind in string.gmatch(player:GetAttribute("PetIndex") or "", "%w+") do
		index[kind] = true
	end
	local changed = false
	for _, p in pairs(owned) do
		if not index[p.kind] then
			index[p.kind] = true
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

local function bestFirst(a, b)
	local ma, mb = Config.petMult(a.kind, a.golden), Config.petMult(b.kind, b.golden)
	if ma ~= mb then
		return ma > mb
	end
	return a.uid < b.uid
end

-- Hatching --------------------------------------------------------------------------------------
local function rollRarity(lucky, player)
	-- x2 from the Lucky Eggs server event or a Lucky Spin luck boost
	local luckBoost = Config.activeEvent() == "Luck" or (player and (player:GetAttribute("BoostLuckUntil") or 0) > os.time())
	local chance = Config.rarityChances(lucky, luckBoost)
	local roll = rng:NextNumber(0, 100)
	local acc = 0
	for i = #RARITY_ORDER, 1, -1 do -- rarest first so rounding never eats a Legendary
		local r = RARITY_ORDER[i]
		acc += chance[r]
		if roll < acc then
			return r
		end
	end
	return "Common"
end

local function eggIndex(id)
	for i, e in ipairs(Config.Eggs) do
		if e.id == id then
			return i
		end
	end
end

HatchEgg.OnServerInvoke = function(player, eggId, count)
	if typeof(eggId) ~= "string" or (count ~= 1 and count ~= 3) then
		return false, "Unknown egg."
	end
	local index = eggIndex(eggId)
	if not index or busy[player] then
		return false, "Unknown egg."
	end
	local egg = Config.Eggs[index]
	if player:GetAttribute("Flying") then
		return false, "Can't hatch while flying!"
	end
	if (player:GetAttribute("UnlockedStage") or 1) < egg.stage then
		return false, "Unlock Stage " .. egg.stage .. " to open the " .. egg.name .. "!"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local standPos = LobbyLayout.eggStand(index, #Config.Eggs)
	if not root or (root.Position - standPos).Magnitude > 24 then
		return false, "Walk up to the egg first!"
	end
	local pets = getPets(player)
	if #pets + count > Config.MAX_PETS then
		return false, "Your pets are full (" .. Config.MAX_PETS .. ")! Delete some first."
	end
	local cost = egg.price * count
	local money = player:GetAttribute("Money") or 0
	if money < cost then
		return false, "You need $" .. Config.abbreviate(cost - money) .. " more!"
	end

	busy[player] = true
	player:SetAttribute("Money", money - cost)
	local nextId = player:GetAttribute("NextPetId") or 1
	local results = {}
	for _ = 1, count do
		local rarity = rollRarity(Config.hasPass(player, "LuckyEggs"), player)
		local kind = egg.pets[rarity]
		table.insert(pets, { uid = nextId, kind = kind })
		table.insert(results, { uid = nextId, kind = kind })
		nextId += 1
		if rarity == "Legendary" then
			Notify:FireAllClients("🌟 " .. player.DisplayName .. " hatched a LEGENDARY " .. Config.Pets[kind].name .. "!", Config.Rarities.Legendary.color)
		end
	end
	player:SetAttribute("NextPetId", nextId)
	player:SetAttribute("StatEggs", (player:GetAttribute("StatEggs") or 0) + count)
	setPets(player, pets)

	-- fill empty pet slots with the new pets (best first) so hatching feels instant
	local equipped = getEquipped(player, pets)
	table.sort(results, bestFirst)
	for _, r in ipairs(results) do
		if #equipped < slots(player) then
			table.insert(equipped, r.uid)
		end
	end
	setEquipped(player, equipped)
	refresh(player)
	PlayerData.save(player)
	busy[player] = nil
	return true, results
end

-- Inventory actions -----------------------------------------------------------------------------
PetAction.OnServerInvoke = function(player, action, uid)
	if typeof(action) ~= "string" then
		return false, "?"
	end
	local pets = getPets(player)
	local equipped, owned = getEquipped(player, pets)

	if action == "equipBest" then
		table.sort(pets, bestFirst)
		local best = {}
		for i = 1, math.min(slots(player), #pets) do
			table.insert(best, pets[i].uid)
		end
		setEquipped(player, best)
		refresh(player)
		return true, #best > 0 and "Equipped your best pets!" or "You have no pets yet!"
	end

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
			return false, "You can equip " .. slots(player) .. " pets. Unequip one first! (Rebirth for more slots)"
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
	elseif action == "golden" then
		-- fuse GOLDEN_COST copies of this pet (unequipped ones first) into one Golden pet
		local base = owned[uid]
		if base.golden then
			return false, name .. " is already golden!"
		end
		local same = {}
		for _, p in ipairs(pets) do
			if p.kind == base.kind and not p.golden then
				table.insert(same, p)
			end
		end
		if #same < Config.GOLDEN_COST then
			return false, "You need " .. Config.GOLDEN_COST .. " " .. name .. " pets (you have " .. #same .. ")."
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
		table.insert(kept, { uid = newUid, kind = base.kind, golden = true })
		local newEquipped = {}
		for _, e in ipairs(equipped) do
			if not used[e] then
				table.insert(newEquipped, e)
			end
		end
		if wasEquipped then
			table.insert(newEquipped, 1, newUid)
		end
		setPets(player, kept)
		setEquipped(player, newEquipped)
		refresh(player)
		PlayerData.save(player)
		local pet = Config.Pets[base.kind]
		if pet.rarity == "Epic" or pet.rarity == "Legendary" then
			Notify:FireAllClients("⭐ " .. player.DisplayName .. " made a GOLDEN " .. pet.name .. "!", Color3.fromRGB(255, 215, 60))
		end
		return true, newUid
	elseif action == "delete" then
		for i, p in ipairs(pets) do
			if p.uid == uid then
				table.remove(pets, i)
				break
			end
		end
		if at then
			table.remove(equipped, at)
		end
		setPets(player, pets)
		setEquipped(player, equipped)
		refresh(player)
		return true, name .. " deleted."
	end
	return false, "?"
end

-- Free pet (mystery crates): a normal roll from the best egg you've unlocked, put straight into an
-- empty slot. ServerStorage.GivePet:Invoke(player) -> pet kind, or nil when your pets are full.
local GivePet = game:GetService("ServerStorage"):FindFirstChild("GivePet") or Instance.new("BindableFunction")
GivePet.Name = "GivePet"
GivePet.Parent = game:GetService("ServerStorage")
GivePet.OnInvoke = function(player)
	local pets = getPets(player)
	if #pets >= Config.MAX_PETS then
		return nil
	end
	local egg = Config.Eggs[1]
	for _, e in ipairs(Config.Eggs) do
		if (player:GetAttribute("UnlockedStage") or 1) >= e.stage then
			egg = e
		end
	end
	local rarity = rollRarity(Config.hasPass(player, "LuckyEggs"), player)
	local kind = egg.pets[rarity]
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
	for _, attr in ipairs({ "Pets", "EquippedPets", "DataLoaded", "Rebirths", "Pass_RainbowPets", "Pass_VIP", "Pass_PetSlots" }) do
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
end)
