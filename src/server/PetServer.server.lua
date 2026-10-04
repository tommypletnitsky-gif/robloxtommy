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
local function slots(player) -- 3 pet slots, +1 per rebirth (Config.petSlots)
	return Config.petSlots(player:GetAttribute("Rebirths") or 0)
end

local function getPets(player)
	return Config.parsePets(player:GetAttribute("Pets"))
end

local function setPets(player, list)
	local parts = {}
	for _, p in ipairs(list) do
		table.insert(parts, p.uid .. ":" .. p.kind)
	end
	player:SetAttribute("Pets", table.concat(parts, ";"))
end

local function getEquipped(player, pets)
	-- only uids the player still owns, at most MAX_EQUIPPED
	local owned = {}
	for _, p in ipairs(pets or getPets(player)) do
		owned[p.uid] = p.kind
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
		table.insert(kinds, owned[uid])
	end
	player:SetAttribute("PetMultiplier", Config.petMultiplier(kinds))
	player:SetAttribute("PetKinds", table.concat(kinds, ","))
end

local function bestFirst(a, b)
	local pa, pb = Config.Pets[a.kind], Config.Pets[b.kind]
	if pa.mult ~= pb.mult then
		return pa.mult > pb.mult
	end
	return a.uid < b.uid
end

-- Hatching --------------------------------------------------------------------------------------
local function rollRarity()
	local roll = rng:NextNumber(0, 100)
	local acc = 0
	for i = #RARITY_ORDER, 1, -1 do -- rarest first so rounding never eats a Legendary
		local r = RARITY_ORDER[i]
		acc += Config.RARITY_CHANCE[r]
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
		local rarity = rollRarity()
		local kind = egg.pets[rarity]
		table.insert(pets, { uid = nextId, kind = kind })
		table.insert(results, { uid = nextId, kind = kind })
		nextId += 1
		if rarity == "Legendary" then
			Notify:FireAllClients("🌟 " .. player.DisplayName .. " hatched a LEGENDARY " .. Config.Pets[kind].name .. "!", Config.Rarities.Legendary.color)
		end
	end
	player:SetAttribute("NextPetId", nextId)
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
	local name = Config.Pets[owned[uid]].name
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

-- Players ---------------------------------------------------------------------------------------
local function watch(player)
	for _, attr in ipairs({ "Pets", "EquippedPets", "DataLoaded", "Rebirths" }) do
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
