--[[
	PetServer  (Script @ ServerScriptService)
	Pet Fusion Simulator v2 — ALL server logic.

	Server-authoritative. Implements Sections E, F, G, I of the contract plus
	gamepass/devproduct effects, daily rewards, quests, follower movement loop,
	and anti-exploit validation. Depends ONLY on ReplicatedStorage.PetData and
	ReplicatedStorage.Remotes (names pinned by the contract).
--]]

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local HttpService        = game:GetService("HttpService")
local DataStoreService   = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace          = game:GetService("Workspace")

----------------------------------------------------------------------
-- DEPENDENCIES
----------------------------------------------------------------------
local PetData = require(ReplicatedStorage:WaitForChild("PetData"))
local Config  = PetData.Config

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function RE(name) return Remotes:WaitForChild(name) end

-- client -> server events
local ClickCoin       = RE("ClickCoin")
local HatchRequest    = RE("HatchRequest")
local EquipPet        = RE("EquipPet")
local UnequipPet      = RE("UnequipPet")
local FuseRequest     = RE("FuseRequest")
local FuseAll         = RE("FuseAll")
local SellPets        = RE("SellPets")
local SellBulk        = RE("SellBulk")
local LockPet         = RE("LockPet")
local RebirthRequest  = RE("RebirthRequest")
local TravelTo        = RE("TravelTo")
local ClaimDaily      = RE("ClaimDaily")
local ClaimQuest      = RE("ClaimQuest")
local ClaimPlaytime   = RE("ClaimPlaytime")
local ClaimIndexTier  = RE("ClaimIndexTier")
local UseBoostItem    = RE("UseBoostItem")
local SetSetting      = RE("SetSetting")
local SetTutorialStep = RE("SetTutorialStep")

-- server -> client events
local StateSync   = RE("StateSync")
local HatchResult = RE("HatchResult")
local Notify      = RE("Notify")
local BoostUpdate = RE("BoostUpdate")
local BigHatch    = RE("BigHatch")
local FXEvent     = RE("FXEvent")

-- request/response
local GetDropTable = RE("GetDropTable")

----------------------------------------------------------------------
-- FORWARD DECLARATIONS (avoid global namespace pollution / use-before-define)
----------------------------------------------------------------------
local pushSnapshot
local savePlayer
local addQuestProgress
local questTarget
local grantPetByRarity
local recomputeCPS
local effectiveLuck
local currentEquipSlots
local inventoryCount
local boostsSnapshot
local indexSnapshot
local petListSnapshot
local questsSnapshot
local syncCore
local fullSnapshot

----------------------------------------------------------------------
-- DATASTORE (with Studio mock fallback)
----------------------------------------------------------------------
local STORE_NAME = "PetFusionV2"
local SAVE_VERSION = 2
local LOCK_STALE_SEC = 600

local realStore
local mockMode = false
local mockData = {}   -- userId -> data table (in-memory)

do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and store then
		realStore = store
	else
		mockMode = true
		warn("[PetServer] DataStore unavailable -> MOCK SAVE mode")
	end
end

local function keyFor(userId) return "p_" .. tostring(userId) end

-- UpdateAsync with retry; transform(old) -> (newData) ; returns ok, result
local function safeUpdate(userId, transform)
	if mockMode then
		local k = keyFor(userId)
		local newData = transform(mockData[k])
		if newData ~= nil then
			mockData[k] = newData
		end
		return true, mockData[k]
	end
	local attempts = 0
	local lastErr
	while attempts < 5 do
		attempts += 1
		local ok, res = pcall(function()
			return realStore:UpdateAsync(keyFor(userId), function(old)
				return transform(old)
			end)
		end)
		if ok then
			return true, res
		end
		lastErr = res
		task.wait(2)
	end
	return false, lastErr
end

local function safeRead(userId)
	if mockMode then
		return true, mockData[keyFor(userId)]
	end
	local attempts = 0
	local lastErr
	while attempts < 5 do
		attempts += 1
		local ok, res = pcall(function()
			return realStore:GetAsync(keyFor(userId))
		end)
		if ok then return true, res end
		lastErr = res
		task.wait(2)
	end
	return false, lastErr
end

----------------------------------------------------------------------
-- PROFILE CACHE  (runtime state per player)
----------------------------------------------------------------------
local Profiles = {}

local JOB_ID = game.JobId ~= "" and game.JobId or ("studio_" .. HttpService:GenerateGUID(false))

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function now() return os.time() end

local function getProfile(player)
	return Profiles[player.UserId]
end

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local n = {}
	for k, v in pairs(t) do n[k] = deepCopy(v) end
	return n
end

-- Default persisted data for a brand-new player
local function defaultData()
	return {
		Version = SAVE_VERSION,
		coins = 0,
		coinsEarned = 0,
		rebirths = 0,
		equipSlotsBonus = 0,
		zonesUnlocked = 1,            -- bit 1 = zone 1 always
		pets = {},
		index = {},
		indexTiersClaimed = {},
		daily = { streak = 0, lastClaimTs = 0, cycleDay = 0 },
		quests = { dayKey = "", list = {} },
		boosts = {},
		inventorySoftCap = Config.InvSoftCap,
		rebirthTokens = 0,
		settings = { music = true, sfx = true, lowfx = false, reducedmotion = false, floats = true, autohatch = false },
		tutorialStep = 0,
		firstJoin = true,
		lastLeaveTs = 0,
		processedReceipts = {},
		items = { luck = 0, coin = 0 },
		lock = { jobId = JOB_ID, ts = now() },
	}
end

-- V1 -> V2 migration
local function migrate(old)
	if old == nil then return nil end
	if old.Version and old.Version >= 2 then
		old.items = old.items or { luck = 0, coin = 0 }
		old.settings = old.settings or { music = true, sfx = true, lowfx = false, reducedmotion = false, floats = true, autohatch = false }
		old.processedReceipts = old.processedReceipts or {}
		old.boosts = old.boosts or {}
		old.index = old.index or {}
		old.indexTiersClaimed = old.indexTiersClaimed or {}
		old.daily = old.daily or { streak = 0, lastClaimTs = 0, cycleDay = 0 }
		old.quests = old.quests or { dayKey = "", list = {} }
		old.inventorySoftCap = old.inventorySoftCap or Config.InvSoftCap
		old.equipSlotsBonus = old.equipSlotsBonus or 0
		old.zonesUnlocked = old.zonesUnlocked or 1
		return old
	end
	-- old is V1 (or unversioned). Keep coins/rebirths/pets.
	local d = defaultData()
	d.coins = tonumber(old.coins) or 0
	d.coinsEarned = tonumber(old.coinsEarned) or d.coins
	d.rebirths = tonumber(old.rebirths) or 0
	d.pets = {}
	if type(old.pets) == "table" then
		for _, p in ipairs(old.pets) do
			if p and p.Type and PetData.Pets[p.Type] then
				table.insert(d.pets, {
					Type = p.Type,
					Mut = (p.Mut and PetData.Mutations[p.Mut]) and p.Mut or "None",
					Equipped = p.Equipped == true,
					Locked = false,
					Shiny = false,
				})
			end
		end
	end
	d.firstJoin = false        -- no starter chest for returning players
	d.tutorialStep = 6         -- done
	d.Version = SAVE_VERSION
	return d
end

----------------------------------------------------------------------
-- LEADERSTATS / ATTRIBUTES
----------------------------------------------------------------------
local function setupLeaderstats(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue"); coins.Name = "Coins"; coins.Parent = ls
	local rb = Instance.new("IntValue"); rb.Name = "Rebirths"; rb.Parent = ls
	ls.Parent = player
end

local function setAttr(player, k, v)
	player:SetAttribute(k, v)
end

----------------------------------------------------------------------
-- ZONES BITMASK
----------------------------------------------------------------------
local function recomputeZoneMask(prof)
	local d = prof.data
	local mask = 0
	for i = 1, 5 do
		if PetData.zoneUnlocked(i, d.coinsEarned, d.rebirths) then
			mask = bit32.bor(mask, bit32.lshift(1, i - 1))
		end
	end
	d.zonesUnlocked = bit32.bor(d.zonesUnlocked or 0, mask)
	return d.zonesUnlocked
end

local function zoneMaskToTable(mask)
	local t = {}
	for i = 1, 5 do
		t[i] = bit32.band(mask, bit32.lshift(1, i - 1)) ~= 0
	end
	return t
end

----------------------------------------------------------------------
-- GAMEPASS OWNERSHIP (cached per session)
----------------------------------------------------------------------
local function refreshGamepasses(prof)
	local player = prof.player
	prof.gamepasses = prof.gamepasses or {}
	for name, info in pairs(PetData.Gamepasses) do
		if info.assetId and info.assetId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.assetId)
			end)
			prof.gamepasses[name] = ok and owns or false
		else
			prof.gamepasses[name] = prof.gamepasses[name] or false
		end
	end
end

local function hasPass(prof, name)
	return prof.gamepasses and prof.gamepasses[name] == true
end

----------------------------------------------------------------------
-- BOOSTS (timed)  prof.boosts = { {boostType=, expiresAt=} }
----------------------------------------------------------------------
local function pruneBoosts(prof)
	local t = now()
	local kept = {}
	local changed = false
	for _, b in ipairs(prof.boosts) do
		if b.expiresAt > t then
			table.insert(kept, b)
		else
			changed = true
		end
	end
	prof.boosts = kept
	return changed
end

local function boostActive(prof, kind)
	local t = now()
	for _, b in ipairs(prof.boosts) do
		if b.boostType == kind and b.expiresAt > t then
			return true
		end
	end
	return false
end

local function addBoost(prof, kind, sec)
	local t = now()
	for _, b in ipairs(prof.boosts) do
		if b.boostType == kind then
			b.expiresAt = math.max(b.expiresAt, t) + sec
			return
		end
	end
	table.insert(prof.boosts, { boostType = kind, expiresAt = t + sec })
end

----------------------------------------------------------------------
-- MULTIPLIER / CPS COMPUTATION
----------------------------------------------------------------------
local function coinMultiplier(prof)
	local m = 1
	if hasPass(prof, "Coins2x")  then m *= PetData.Gamepasses.Coins2x.coinMult end
	if hasPass(prof, "FastCoins") then m *= PetData.Gamepasses.FastCoins.coinMult end
	if hasPass(prof, "VIP")       then m *= PetData.Gamepasses.VIP.coinMult end
	if boostActive(prof, "coin")  then m *= 2 end
	if boostActive(prof, "newplayer") then m *= 2 end
	return m
end

local function luckMultiplier(prof)
	local gp = 1
	if hasPass(prof, "Luck2x") then gp *= PetData.Gamepasses.Luck2x.luckMult end
	if hasPass(prof, "VIP")    then gp *= PetData.Gamepasses.VIP.luckMult end
	local potion = 1
	if boostActive(prof, "luck")  then potion *= 3 end
	return gp, potion
end

effectiveLuck = function(prof)
	local gp, potion = luckMultiplier(prof)
	return PetData.effectiveLuck(prof.data.rebirths, gp, potion)
end

local function effectiveShinyChance(prof)
	if hasPass(prof, "VIP") then return Config.ShinyChanceVIP end
	return Config.ShinyChance
end

local function indexBonusFraction(prof)
	local d = prof.data
	local bonus = 0
	local pools = { Meadow = {}, Forest = {}, Frost = {}, Volcano = {}, Sky = {} }
	for typeId, info in pairs(PetData.Pets) do
		pools[info.pool] = pools[info.pool] or {}
		pools[info.pool][typeId] = true
	end
	for poolName, members in pairs(pools) do
		local complete = true
		for typeId in pairs(members) do
			if not d.index[typeId] then complete = false break end
		end
		if complete and d.indexTiersClaimed[poolName] then
			bonus += PetData.IndexRewards.poolComplete
		end
	end
	if d.indexTiersClaimed.full100 then
		bonus += PetData.IndexRewards.full100.cpsBonus
	end
	return bonus
end

-- Recompute CPS from equipped pets + all global mults. Caches into prof.cps and CPS attr.
recomputeCPS = function(prof)
	local d = prof.data
	local sum = 0
	for _, pet in pairs(prof.pets) do
		if pet.Equipped then
			sum += PetData.power(pet)
		end
	end
	local rbMult = PetData.rebirthMult(d.rebirths)
	local idxBonus = indexBonusFraction(prof)
	setAttr(prof.player, "IndexBonus", idxBonus)
	local cps = sum * rbMult * coinMultiplier(prof) * (1 + idxBonus)
	prof.cps = cps
	setAttr(prof.player, "CPS", cps)
	return cps
end

----------------------------------------------------------------------
-- EQUIP SLOTS
----------------------------------------------------------------------
local function gamepassEquipBonus(prof)
	local b = prof.data.equipSlotsBonus or 0
	if hasPass(prof, "EquipSlots2") then b += PetData.Gamepasses.EquipSlots2.equipSlots end
	if hasPass(prof, "VIP")         then b += PetData.Gamepasses.VIP.equipSlots end
	return b
end

currentEquipSlots = function(prof)
	return PetData.equipSlots(prof.data.rebirths, gamepassEquipBonus(prof))
end

local function countEquipped(prof)
	local c = 0
	for _, pet in pairs(prof.pets) do
		if pet.Equipped then c += 1 end
	end
	return c
end

----------------------------------------------------------------------
-- INVENTORY
----------------------------------------------------------------------
inventoryCount = function(prof)
	local c = 0
	for _ in pairs(prof.pets) do c += 1 end
	return c
end

----------------------------------------------------------------------
-- COINS
----------------------------------------------------------------------
local function addCoins(prof, amount)
	if amount <= 0 then return end
	amount = math.floor(amount)
	local d = prof.data
	d.coins += amount
	d.coinsEarned += amount
	local player = prof.player
	local ls = player:FindFirstChild("leaderstats")
	if ls then ls.Coins.Value = math.clamp(d.coins, 0, 2^31 - 1) end
	setAttr(player, "CoinsEarned", d.coinsEarned)
	-- unlocking zones as coinsEarned grows
	local before = d.zonesUnlocked
	recomputeZoneMask(prof)
	if d.zonesUnlocked ~= before then
		setAttr(player, "ZonesUnlocked", d.zonesUnlocked)
		pushSnapshot(player, { zonesUnlocked = zoneMaskToTable(d.zonesUnlocked) })
	end
end

local function spendCoins(prof, amount)
	if prof.data.coins < amount then return false end
	prof.data.coins -= amount
	local ls = prof.player:FindFirstChild("leaderstats")
	if ls then ls.Coins.Value = math.clamp(prof.data.coins, 0, 2^31 - 1) end
	return true
end

----------------------------------------------------------------------
-- SNAPSHOT (StateSync)
----------------------------------------------------------------------
pushSnapshot = function(player, partial)
	StateSync:FireClient(player, partial)
end

petListSnapshot = function(prof)
	local list = {}
	for guid, pet in pairs(prof.pets) do
		table.insert(list, {
			guid = guid,
			Type = pet.Type,
			Mut = pet.Mut,
			Equipped = pet.Equipped,
			Locked = pet.Locked,
			Shiny = pet.Shiny,
			power = PetData.power(pet),
		})
	end
	return list
end

boostsSnapshot = function(prof)
	local t = {}
	for _, b in ipairs(prof.boosts) do
		table.insert(t, { boostType = b.boostType, expiresAt = b.expiresAt })
	end
	return t
end

local function dailySnapshot(prof)
	local d = prof.data.daily
	local lastDay = math.floor((d.lastClaimTs or 0) / 86400)
	local today = math.floor(now() / 86400)
	local claimable = today > lastDay
	return {
		streak = d.streak or 0,
		claimableToday = claimable,
		nextResetTs = (today + 1) * 86400,
	}
end

questsSnapshot = function(prof)
	local out = {}
	for _, q in ipairs(prof.data.quests.list) do
		local def = PetData.Quests[q.id]
		out[#out + 1] = {
			id = q.id,
			desc = q.descText or (def and def.desc) or q.id,
			progress = q.progress or 0,
			target = q.target or 1,
			done = (q.progress or 0) >= (q.target or 1),
			claimed = q.claimed == true,
			reward = def and def.reward or {},
		}
	end
	return out
end

local function playtimeSnapshot(prof)
	return {
		sessionSec = prof.sessionSec or 0,
		nextRewardSec = prof.nextPlaytimeReward or 300,
		claimable = (prof.sessionSec or 0) >= (prof.nextPlaytimeReward or 300),
	}
end

indexSnapshot = function(prof)
	local d = prof.data
	local pools = { Meadow = {}, Forest = {}, Frost = {}, Volcano = {}, Sky = {} }
	for typeId, info in pairs(PetData.Pets) do
		pools[info.pool] = pools[info.pool] or {}
		pools[info.pool][typeId] = true
	end
	local poolsComplete = {}
	for poolName, members in pairs(pools) do
		local complete = true
		for typeId in pairs(members) do
			if not d.index[typeId] then complete = false break end
		end
		poolsComplete[poolName] = complete
	end
	local seen = {}
	for k, v in pairs(d.index) do seen[k] = v end
	return { seen = seen, poolsComplete = poolsComplete, full100 = d.indexTiersClaimed.full100 == true }
end

fullSnapshot = function(prof)
	local d = prof.data
	return {
		coins = d.coins,
		coinsEarned = d.coinsEarned,
		rebirths = d.rebirths,
		cps = prof.cps or 0,
		zone = prof.player:GetAttribute("Zone") or 1,
		zonesUnlocked = zoneMaskToTable(d.zonesUnlocked),
		equipSlots = currentEquipSlots(prof),
		luck = effectiveLuck(prof),
		indexBonus = prof.player:GetAttribute("IndexBonus") or 0,
		rebirthTokens = d.rebirthTokens,
		tutorialStep = d.tutorialStep,
		pets = petListSnapshot(prof),
		boosts = boostsSnapshot(prof),
		daily = dailySnapshot(prof),
		quests = questsSnapshot(prof),
		playtime = playtimeSnapshot(prof),
		index = indexSnapshot(prof),
		inventory = { count = inventoryCount(prof), softCap = d.inventorySoftCap, hardCap = Config.InvHardCap },
		gamepasses = {
			Coins2x = hasPass(prof, "Coins2x"),
			Luck2x = hasPass(prof, "Luck2x"),
			AutoHatch = hasPass(prof, "AutoHatch"),
			VIP = hasPass(prof, "VIP"),
			EquipSlots2 = hasPass(prof, "EquipSlots2"),
			FastCoins = hasPass(prof, "FastCoins"),
			AutoCollect = hasPass(prof, "AutoCollect"),
		},
		settings = deepCopy(d.settings),
	}
end

syncCore = function(prof)
	local d = prof.data
	pushSnapshot(prof.player, {
		coins = d.coins,
		coinsEarned = d.coinsEarned,
		cps = prof.cps,
		equipSlots = currentEquipSlots(prof),
		luck = effectiveLuck(prof),
		inventory = { count = inventoryCount(prof), softCap = d.inventorySoftCap, hardCap = Config.InvHardCap },
	})
end

----------------------------------------------------------------------
-- PET INSTANCE STORAGE (player.Pets Folder; each pet = Configuration)
----------------------------------------------------------------------
local function makePetInstance(player, guid, pet)
	local folder = player:FindFirstChild("Pets")
	if not folder then return end
	local cfg = Instance.new("Configuration")
	cfg.Name = guid
	cfg:SetAttribute("Guid", guid)
	cfg:SetAttribute("Type", pet.Type)
	cfg:SetAttribute("Mut", pet.Mut)
	cfg:SetAttribute("Equipped", pet.Equipped)
	cfg:SetAttribute("Locked", pet.Locked)
	cfg:SetAttribute("Shiny", pet.Shiny)
	cfg.Parent = folder
	return cfg
end

local function updatePetInstance(player, guid, pet)
	local folder = player:FindFirstChild("Pets")
	if not folder then return end
	local cfg = folder:FindFirstChild(guid)
	if not cfg then return end
	cfg:SetAttribute("Mut", pet.Mut)
	cfg:SetAttribute("Equipped", pet.Equipped)
	cfg:SetAttribute("Locked", pet.Locked)
	cfg:SetAttribute("Shiny", pet.Shiny)
end

local function removePetInstance(player, guid)
	local folder = player:FindFirstChild("Pets")
	if not folder then return end
	local cfg = folder:FindFirstChild(guid)
	if cfg then cfg:Destroy() end
end

-- add a freshly-created pet to the runtime + instance storage. returns guid or nil (capped).
local function addPet(prof, petTbl)
	local count = inventoryCount(prof)
	if count >= Config.InvHardCap then
		return nil, "hardcap"
	end
	local guid = HttpService:GenerateGUID(false)
	petTbl.Mut = petTbl.Mut or "None"
	petTbl.Equipped = petTbl.Equipped == true
	petTbl.Locked = petTbl.Locked == true
	petTbl.Shiny = petTbl.Shiny == true
	prof.pets[guid] = petTbl
	makePetInstance(prof.player, guid, petTbl)
	if not prof.data.index[petTbl.Type] then
		prof.data.index[petTbl.Type] = true
		prof._indexChanged = true
	end
	return guid
end

----------------------------------------------------------------------
-- TOKEN BUCKETS (rate limit)
----------------------------------------------------------------------
local function checkBucket(prof, name, capPerSec)
	local b = prof.buckets[name]
	local t = os.clock()
	if not b then
		b = { tokens = capPerSec, last = t }
		prof.buckets[name] = b
	end
	local elapsed = t - b.last
	b.tokens = math.min(capPerSec, b.tokens + elapsed * capPerSec)
	b.last = t
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

local function errToast(player, msg)
	Notify:FireClient(player, "error", { text = msg })
end

----------------------------------------------------------------------
-- HATCHING
----------------------------------------------------------------------
local function rarityRank(rarity)
	for i, r in ipairs(PetData.RarityOrder) do
		if r == rarity then return i end
	end
	return 0
end

local function doHatch(player, eggId, count)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	if not checkBucket(prof, "hatch", Config.HatchCapPerSec) then return end

	local egg = PetData.Eggs[eggId]
	if not egg then errToast(player, "Unknown egg") return end
	if count ~= 1 and count ~= 3 and count ~= 10 and count ~= 50 then
		errToast(player, "Bad count") return
	end
	if not PetData.zoneUnlocked(egg.zone, prof.data.coinsEarned, prof.data.rebirths) then
		errToast(player, "Zone locked") return
	end

	-- x50 needs AutoHatch gamepass or MegaHatch token (consume token only if no gamepass)
	local consumeMega = false
	if count == 50 then
		local megaToken = (prof.megaHatchTokens or 0) > 0
		if not hasPass(prof, "AutoHatch") and not megaToken then
			errToast(player, "x50 requires Auto-Hatch")
			return
		end
		if not hasPass(prof, "AutoHatch") and megaToken then
			consumeMega = true
		end
	end

	-- inventory headroom: clamp count to what we can store
	local headroom = Config.InvHardCap - inventoryCount(prof)
	if headroom <= 0 then errToast(player, "Inventory full") return end
	local realCount = math.min(count, headroom)

	-- charge ONLY for the pets actually hatched (no overcharge when near inv cap)
	local totalCost = egg.cost * realCount
	if prof.data.coins < totalCost then
		errToast(player, "Not enough coins") return
	end
	if not spendCoins(prof, totalCost) then return end

	-- only consume the mega token once we've committed to the hatch
	if consumeMega then
		prof.megaHatchTokens -= 1
	end

	local luck = effectiveLuck(prof)
	local shinyChance = effectiveShinyChance(prof)
	local results = {}
	local bestRank = 0
	local bestPetName, bestRarity = nil, nil
	prof._indexChanged = false

	for _ = 1, realCount do
		local pet = PetData.pickPet(eggId, luck, math.random)
		-- shiny roll using server-side effective chance (authoritative)
		pet.Shiny = math.random() < shinyChance
		local guid = addPet(prof, pet)
		if guid then
			local rarity = PetData.Pets[pet.Type].rarity
			table.insert(results, { Type = pet.Type, Mut = pet.Mut, Shiny = pet.Shiny, rarity = rarity })
			local rk = rarityRank(rarity)
			if rk > bestRank then
				bestRank = rk
				bestPetName = PetData.Pets[pet.Type].name
				bestRarity = rarity
			end
		end
	end

	addQuestProgress(prof, "hatch", #results)
	if prof._indexChanged then
		addQuestProgress(prof, "index", 1)
	end

	HatchResult:FireClient(player, results)

	if bestRarity == "Legendary" or bestRarity == "Mythic" or bestRarity == "Secret" then
		for _, p in ipairs(Players:GetPlayers()) do
			BigHatch:FireClient(p, player.Name, "hatch", bestPetName)
		end
	end

	prof._indexChanged = false
	recomputeCPS(prof)
	syncCore(prof)
	pushSnapshot(player, { pets = petListSnapshot(prof), index = indexSnapshot(prof), quests = questsSnapshot(prof) })
end

----------------------------------------------------------------------
-- EQUIP / UNEQUIP
----------------------------------------------------------------------
local function doEquip(player, guid)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	if not checkBucket(prof, "equip", Config.EquipCapPerSec) then return end
	local pet = prof.pets[guid]
	if not pet then return end
	if pet.Equipped then return end
	if countEquipped(prof) >= currentEquipSlots(prof) then
		errToast(player, "Slots full")
		return
	end
	pet.Equipped = true
	updatePetInstance(player, guid, pet)
	if pet.Mut ~= "None" then
		addQuestProgress(prof, "equipG", 1)
	end
	recomputeCPS(prof)
	syncCore(prof)
	pushSnapshot(player, { pets = petListSnapshot(prof) })
end

local function doUnequip(player, guid)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	if not checkBucket(prof, "equip", Config.EquipCapPerSec) then return end
	local pet = prof.pets[guid]
	if not pet or not pet.Equipped then return end
	pet.Equipped = false
	updatePetInstance(player, guid, pet)
	recomputeCPS(prof)
	syncCore(prof)
	pushSnapshot(player, { pets = petListSnapshot(prof) })
end

----------------------------------------------------------------------
-- FUSION  (server-validated)
----------------------------------------------------------------------
local function fuseTriple(prof, g1, g2, g3)
	if g1 == g2 or g2 == g3 or g1 == g3 then return nil, "distinct" end
	local p1, p2, p3 = prof.pets[g1], prof.pets[g2], prof.pets[g3]
	if not (p1 and p2 and p3) then return nil, "owned" end
	if p1.Type ~= p2.Type or p2.Type ~= p3.Type then return nil, "type" end
	if p1.Mut ~= p2.Mut or p2.Mut ~= p3.Mut then return nil, "mut" end
	local nextM = PetData.nextMut(p1.Mut)
	if not nextM then return nil, "maxmut" end
	if p1.Locked or p2.Locked or p3.Locked then return nil, "locked" end

	local allShiny = p1.Shiny and p2.Shiny and p3.Shiny
	for _, g in ipairs({ g1, g2, g3 }) do
		prof.pets[g] = nil
		removePetInstance(prof.player, g)
	end
	local newPet = { Type = p1.Type, Mut = nextM, Equipped = false, Locked = false, Shiny = allShiny }
	local newGuid = addPet(prof, newPet)
	return newGuid
end

local function doFuse(player, guids)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	if not checkBucket(prof, "fuse", Config.FuseCapPerSec) then return end
	if type(guids) ~= "table" or #guids ~= 3 then errToast(player, "Select 3") return end
	if type(guids[1]) ~= "string" or type(guids[2]) ~= "string" or type(guids[3]) ~= "string" then
		errToast(player, "Bad selection") return
	end
	local newGuid, reason = fuseTriple(prof, guids[1], guids[2], guids[3])
	if not newGuid then
		errToast(player, "Fuse failed: " .. tostring(reason))
		return
	end
	addQuestProgress(prof, "fuse", 1)
	recomputeCPS(prof)
	syncCore(prof)
	pushSnapshot(player, { pets = petListSnapshot(prof), quests = questsSnapshot(prof) })
	Notify:FireClient(player, "toast", { text = "Fused!" })
end

local function doFuseAll(player)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	if not checkBucket(prof, "fuse", Config.FuseCapPerSec) then return end

	local fusedCount = 0
	local progress = true
	while progress do
		progress = false
		local groups = {}
		for guid, pet in pairs(prof.pets) do
			if not pet.Locked and PetData.nextMut(pet.Mut) then
				local key = pet.Type .. "|" .. pet.Mut
				groups[key] = groups[key] or {}
				table.insert(groups[key], guid)
			end
		end
		for _, list in pairs(groups) do
			while #list >= 3 do
				local g1 = table.remove(list)
				local g2 = table.remove(list)
				local g3 = table.remove(list)
				local newGuid = fuseTriple(prof, g1, g2, g3)
				if newGuid then
					fusedCount += 1
					progress = true
				end
			end
		end
		if fusedCount > 500 then break end -- safety
	end

	if fusedCount > 0 then
		addQuestProgress(prof, "fuse", fusedCount)
		recomputeCPS(prof)
		syncCore(prof)
		pushSnapshot(player, { pets = petListSnapshot(prof), quests = questsSnapshot(prof) })
		Notify:FireClient(player, "toast", { text = "Fused " .. fusedCount .. " times!" })
	else
		Notify:FireClient(player, "toast", { text = "No triples to fuse" })
	end
end

----------------------------------------------------------------------
-- SELL
----------------------------------------------------------------------
local function sellValue(pet)
	return math.max(1, math.floor(PetData.power(pet) * 0.25))
end

local function doSellPets(player, guids)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	if type(guids) ~= "table" then return end
	local total = 0
	local sold = 0
	for _, guid in ipairs(guids) do
		if type(guid) == "string" then
			local pet = prof.pets[guid]
			if pet and not pet.Locked and not pet.Equipped then
				total += sellValue(pet)
				prof.pets[guid] = nil
				removePetInstance(player, guid)
				sold += 1
			end
		end
	end
	if sold > 0 then
		addCoins(prof, total)
		recomputeCPS(prof)
		syncCore(prof)
		pushSnapshot(player, { pets = petListSnapshot(prof) })
		Notify:FireClient(player, "toast", { text = "Sold " .. sold .. " for " .. PetData.format(total) })
	end
end

local function doSellBulk(player, filter)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	local toSell = {}
	for guid, pet in pairs(prof.pets) do
		if not pet.Locked and not pet.Equipped then
			local match = false
			if filter == "Common" then
				match = (PetData.Pets[pet.Type].rarity == "Common")
			elseif filter == "Unequipped" then
				match = true
			elseif filter == "Unlocked" then
				match = true
			end
			if match then table.insert(toSell, guid) end
		end
	end
	doSellPets(player, toSell)
end

----------------------------------------------------------------------
-- LOCK
----------------------------------------------------------------------
local function doLock(player, guid, locked)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	local pet = prof.pets[guid]
	if not pet then return end
	pet.Locked = locked == true
	updatePetInstance(player, guid, pet)
	pushSnapshot(player, { pets = petListSnapshot(prof) })
end

----------------------------------------------------------------------
-- REBIRTH
----------------------------------------------------------------------
local function doRebirth(player)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	local d = prof.data
	local cost = PetData.rebirthCost(d.rebirths)
	if d.coins < cost then
		errToast(player, "Need " .. PetData.format(cost) .. " to rebirth")
		return
	end
	d.rebirths += 1
	d.rebirthTokens += 1
	d.coins = Config.StartCoins
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Coins.Value = d.coins
		ls.Rebirths.Value = d.rebirths
	end
	setAttr(player, "RebirthTokens", d.rebirthTokens)
	setAttr(player, "EquipSlots", currentEquipSlots(prof))
	recomputeZoneMask(prof)
	setAttr(player, "ZonesUnlocked", d.zonesUnlocked)
	-- enforce equip slot cap (slots may not have grown enough; keep <= cap)
	local equippedCount = 0
	for guid, pet in pairs(prof.pets) do
		if pet.Equipped then
			equippedCount += 1
			if equippedCount > currentEquipSlots(prof) then
				pet.Equipped = false
				updatePetInstance(player, guid, pet)
			end
		end
	end
	recomputeCPS(prof)
	pushSnapshot(player, fullSnapshot(prof))
	if d.rebirths % 10 == 0 then
		for _, p in ipairs(Players:GetPlayers()) do
			BigHatch:FireClient(p, player.Name, "rebirth", "Rebirth " .. d.rebirths)
		end
	end
	Notify:FireClient(player, "toast", { text = "Rebirth! Now x" .. PetData.rebirthMult(d.rebirths) .. " coins" })
end

----------------------------------------------------------------------
-- TRAVEL
----------------------------------------------------------------------
local function teleportToZone(player, zoneIndex)
	local world = Workspace:FindFirstChild("World")
	if not world then return end
	local zones = world:FindFirstChild("Zones")
	if not zones then return end
	local zoneFolder
	for _, f in ipairs(zones:GetChildren()) do
		if f.Name:match("^Zone" .. zoneIndex .. "_") then zoneFolder = f break end
	end
	if not zoneFolder then return end
	local arrival = zoneFolder:FindFirstChild("Arrival")
	if not arrival or not arrival:IsA("BasePart") then return end
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char:PivotTo(arrival.CFrame + Vector3.new(0, 5, 0))
	end
end

local function doTravel(player, zoneIndex)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	zoneIndex = tonumber(zoneIndex)
	if not zoneIndex or zoneIndex < 1 or zoneIndex > 5 then return end
	if not PetData.zoneUnlocked(zoneIndex, prof.data.coinsEarned, prof.data.rebirths) then
		local gate = PetData.Zones[zoneIndex].gate
		errToast(player, "Need " .. PetData.format(gate.coins) .. " earned & " .. gate.rebirths .. " rebirths")
		return
	end
	teleportToZone(player, zoneIndex)
	setAttr(player, "Zone", zoneIndex)
	pushSnapshot(player, { zone = zoneIndex })
end

----------------------------------------------------------------------
-- QUESTS
----------------------------------------------------------------------
questTarget = function(prof, def, qid)
	local rebirths = prof.data.rebirths
	if qid == "earn" then
		local cps = prof.cps or 1
		return math.max(1, math.floor(10 * cps * (def.scaleCPS or 300) / 100))
	end
	local base = def.baseTarget or 1
	local per = def.perRebirth or 0
	return base + per * rebirths
end

local function rollDailyQuests(prof)
	local pool = {}
	for id in pairs(PetData.Quests) do table.insert(pool, id) end
	table.sort(pool)
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local picks = {}
	for i = 1, math.min(3, #pool) do
		local id = pool[i]
		local def = PetData.Quests[id]
		local target = questTarget(prof, def, id)
		local descText = def.desc
		if descText:find("%%d") then descText = string.format(descText, target)
		elseif descText:find("%%s") then descText = string.format(descText, PetData.format(target)) end
		table.insert(picks, { id = id, progress = 0, target = target, claimed = false, descText = descText })
	end
	return picks
end

local function ensureDailyQuests(prof)
	local dayKey = os.date("!%Y-%m-%d")
	if prof.data.quests.dayKey ~= dayKey or #prof.data.quests.list == 0 then
		prof.data.quests.dayKey = dayKey
		prof.data.quests.list = rollDailyQuests(prof)
		prof.data.quests.bonusClaimed = false
	else
		for _, q in ipairs(prof.data.quests.list) do
			local def = PetData.Quests[q.id]
			if def and not q.target then
				q.target = questTarget(prof, def, q.id)
			end
			if def and not q.descText then
				local descText = def.desc
				if descText:find("%%d") then descText = string.format(descText, q.target)
				elseif descText:find("%%s") then descText = string.format(descText, PetData.format(q.target)) end
				q.descText = descText
			end
		end
	end
end

addQuestProgress = function(prof, questId, amount)
	if not amount or amount <= 0 then return end
	local changed = false
	for _, q in ipairs(prof.data.quests.list) do
		if q.id == questId and not q.claimed then
			q.progress = (q.progress or 0) + amount
			changed = true
		end
	end
	if changed then
		pushSnapshot(prof.player, { quests = questsSnapshot(prof) })
	end
end

local function grantReward(prof, reward)
	if not reward then return end
	if reward.coins then
		local amt = reward.coins
		if hasPass(prof, "VIP") then amt *= 2 end
		addCoins(prof, amt)
	end
	if reward.cpsSec then
		addCoins(prof, (prof.cps or 0) * reward.cpsSec)
	end
	if reward.boost then
		addBoost(prof, reward.boost, reward.sec or 600)
		BoostUpdate:FireClient(prof.player, boostsSnapshot(prof))
	end
	if reward.petRarity then
		grantPetByRarity(prof, reward.petRarity)
	end
end

local function doClaimQuest(player, questId)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	for _, q in ipairs(prof.data.quests.list) do
		if q.id == questId then
			if q.claimed then return end
			if (q.progress or 0) < (q.target or 1) then
				errToast(player, "Quest not complete")
				return
			end
			q.claimed = true
			local def = PetData.Quests[questId]
			grantReward(prof, def and def.reward)
			local allClaimed = true
			for _, qq in ipairs(prof.data.quests.list) do
				if not qq.claimed then allClaimed = false break end
			end
			if allClaimed and not prof.data.quests.bonusClaimed then
				prof.data.quests.bonusClaimed = true
				addCoins(prof, 10000)
				Notify:FireClient(player, "toast", { text = "Daily quests complete! +" .. PetData.format(10000) })
			end
			recomputeCPS(prof)
			syncCore(prof)
			pushSnapshot(player, { quests = questsSnapshot(prof) })
			Notify:FireClient(player, "questdone", { id = questId })
			return
		end
	end
end

----------------------------------------------------------------------
-- GRANT PET BY RARITY (daily/quest rewards) — from highest unlocked zone's pool
----------------------------------------------------------------------
local ZONE_POOL = { "Meadow", "Forest", "Frost", "Volcano", "Sky" }

grantPetByRarity = function(prof, rarity)
	local d = prof.data
	local pool = "Meadow"
	for i = 5, 1, -1 do
		if PetData.zoneUnlocked(i, d.coinsEarned, d.rebirths) then
			pool = ZONE_POOL[i] or "Meadow"
			break
		end
	end
	local candidates = {}
	for typeId, info in pairs(PetData.Pets) do
		if info.pool == pool and info.rarity == rarity then
			table.insert(candidates, typeId)
		end
	end
	if #candidates == 0 then
		for typeId, info in pairs(PetData.Pets) do
			if info.rarity == rarity then table.insert(candidates, typeId) end
		end
	end
	if #candidates == 0 then return end
	table.sort(candidates)
	local pick = candidates[math.random(1, #candidates)]
	local guid = addPet(prof, { Type = pick, Mut = "None", Equipped = false, Locked = false, Shiny = false })
	if guid then
		recomputeCPS(prof)
		pushSnapshot(prof.player, { pets = petListSnapshot(prof), index = indexSnapshot(prof) })
		Notify:FireClient(prof.player, "toast", { text = "Got " .. PetData.Pets[pick].name .. "!" })
	end
end

----------------------------------------------------------------------
-- DAILY REWARDS
----------------------------------------------------------------------
local function doClaimDaily(player)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	local d = prof.data.daily
	local t = now()
	local lastDay = math.floor((d.lastClaimTs or 0) / 86400)
	local today = math.floor(t / 86400)
	if today <= lastDay then
		errToast(player, "Already claimed today")
		return
	end
	if d.lastClaimTs and d.lastClaimTs > 0 and (t - d.lastClaimTs) > 48 * 3600 then
		d.streak = 0
	end
	d.streak = (d.streak or 0) + 1
	d.cycleDay = ((d.streak - 1) % 7) + 1
	d.lastClaimTs = t
	local reward = PetData.DailyRewards[d.cycleDay]
	grantReward(prof, reward)
	recomputeCPS(prof)
	syncCore(prof)
	pushSnapshot(player, { daily = dailySnapshot(prof), pets = petListSnapshot(prof), boosts = boostsSnapshot(prof) })
	Notify:FireClient(player, "toast", { text = "Daily reward day " .. d.cycleDay .. "!" })
end

----------------------------------------------------------------------
-- PLAYTIME REWARD
----------------------------------------------------------------------
local function doClaimPlaytime(player)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	if (prof.sessionSec or 0) < (prof.nextPlaytimeReward or 300) then
		errToast(player, "Not ready yet")
		return
	end
	local grant = math.max(500, math.floor((prof.cps or 0) * 120))
	addCoins(prof, grant)
	prof.nextPlaytimeReward = (prof.sessionSec or 0) + 300
	pushSnapshot(player, { playtime = playtimeSnapshot(prof) })
	Notify:FireClient(player, "toast", { text = "Playtime reward +" .. PetData.format(grant) })
end

----------------------------------------------------------------------
-- INDEX TIER CLAIM
----------------------------------------------------------------------
local function doClaimIndexTier(player, poolName)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	local d = prof.data
	if poolName == "full100" then
		local total, seen = 0, 0
		for typeId in pairs(PetData.Pets) do
			total += 1
			if d.index[typeId] then seen += 1 end
		end
		if seen < total then errToast(player, "Index not complete") return end
		if d.indexTiersClaimed.full100 then return end
		d.indexTiersClaimed.full100 = true
		local grantType = PetData.IndexRewards.full100.grantPet
		if not d.index[grantType] then d.index[grantType] = true end
		addPet(prof, { Type = grantType, Mut = "None", Equipped = false, Locked = false, Shiny = false })
		recomputeCPS(prof)
		pushSnapshot(player, fullSnapshot(prof))
		Notify:FireClient(player, "toast", { text = "Index 100%! +100% CPS + The Architect" })
		return
	end
	local validPools = { Meadow = true, Forest = true, Frost = true, Volcano = true, Sky = true }
	if not validPools[poolName] then return end
	for typeId, info in pairs(PetData.Pets) do
		if info.pool == poolName and not d.index[typeId] then
			errToast(player, "Pool not complete")
			return
		end
	end
	if d.indexTiersClaimed[poolName] then return end
	d.indexTiersClaimed[poolName] = true
	recomputeCPS(prof)
	pushSnapshot(player, { index = indexSnapshot(prof), cps = prof.cps })
	Notify:FireClient(player, "toast", { text = poolName .. " pool complete! +10% CPS" })
end

----------------------------------------------------------------------
-- USE BOOST ITEM (consumes a stored potion)
----------------------------------------------------------------------
local function doUseBoostItem(player, itemId)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	prof.data.items = prof.data.items or { luck = 0, coin = 0 }
	if itemId ~= "luck" and itemId ~= "coin" then return end
	if (prof.data.items[itemId] or 0) <= 0 then
		errToast(player, "No " .. itemId .. " potion")
		return
	end
	prof.data.items[itemId] -= 1
	addBoost(prof, itemId, 600)
	BoostUpdate:FireClient(player, boostsSnapshot(prof))
	recomputeCPS(prof)
	syncCore(prof)
	Notify:FireClient(player, "toast", { text = itemId .. " boost active!" })
end

----------------------------------------------------------------------
-- SETTINGS
----------------------------------------------------------------------
local VALID_SETTINGS = { music = true, sfx = true, lowfx = true, reducedmotion = true, floats = true, autohatch = true }
local function doSetSetting(player, key, val)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	if not VALID_SETTINGS[key] then return end
	prof.data.settings[key] = (val == true)
	pushSnapshot(player, { settings = deepCopy(prof.data.settings) })
end

----------------------------------------------------------------------
-- TUTORIAL
----------------------------------------------------------------------
local function doSetTutorialStep(player, step)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	step = tonumber(step)
	if not step then return end
	step = math.clamp(math.floor(step), 0, 6)
	if step < (prof.data.tutorialStep or 0) and step ~= 0 then
		return
	end
	local prev = prof.data.tutorialStep or 0
	prof.data.tutorialStep = step
	setAttr(player, "TutorialStep", step)
	if step == 6 and prev < 6 and not prof.data._tutBonus then
		prof.data._tutBonus = true
		addCoins(prof, 1000)
		Notify:FireClient(player, "toast", { text = "Tutorial complete! +1,000 coins" })
	end
	pushSnapshot(player, { tutorialStep = step, coins = prof.data.coins })
end

----------------------------------------------------------------------
-- CLICK (also via ClickDetector world fallback)
----------------------------------------------------------------------
local function handleClick(player)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return end
	if not checkBucket(prof, "click", Config.ClickCapPerSec) then return end
	local val = PetData.clickValue(prof.cps or 0, prof.data.rebirths) * coinMultiplier(prof)
	addCoins(prof, val)
	syncCore(prof)
end

----------------------------------------------------------------------
-- ORBS (server Touched, debounced per orb 4s)
----------------------------------------------------------------------
local orbDebounce = {}  -- orbPart -> nextTime
local function setupOrb(orb, zoneIndex)
	orb.Touched:Connect(function(hit)
		local char = hit and hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then return end
		local prof = getProfile(player)
		if not prof or not prof.loaded then return end
		local t = os.clock()
		if orbDebounce[orb] and orbDebounce[orb] > t then return end
		orbDebounce[orb] = t + 4
		local val = (PetData.Zones[zoneIndex] and PetData.Zones[zoneIndex].orbValue or 5) * coinMultiplier(prof)
		addCoins(prof, val)
		syncCore(prof)
		FXEvent:FireClient(player, "orb", orb.Position, { amount = val })
		orb.Transparency = 1
		orb.CanTouch = false
		task.delay(4, function()
			if orb and orb.Parent then
				orb.Transparency = 0
				orb.CanTouch = true
			end
		end)
	end)
end

local function setupWorldInteractions()
	local world = Workspace:FindFirstChild("World")
	if not world then return end

	local hub = world:FindFirstChild("Hub")
	if hub then
		local crystal = hub:FindFirstChild("CoinCrystal")
		if crystal then
			local cd = crystal:FindFirstChildWhichIsA("ClickDetector", true)
			if cd then
				cd.MouseClick:Connect(function(player)
					handleClick(player)
				end)
			end
		end
	end

	local zones = world:FindFirstChild("Zones")
	if zones then
		for i = 1, 5 do
			local zf
			for _, f in ipairs(zones:GetChildren()) do
				if f.Name:match("^Zone" .. i .. "_") then zf = f break end
			end
			if zf then
				local orbField = zf:FindFirstChild("OrbField")
				if orbField then
					for _, orb in ipairs(orbField:GetChildren()) do
						if orb:IsA("BasePart") then
							setupOrb(orb, i)
						end
					end
				end
				local pad = zf:FindFirstChild("TravelPad")
				if pad then
					local prompt = pad:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt then
						prompt.Triggered:Connect(function(player)
							local target = math.min(i + 1, 5)
							doTravel(player, target)
						end)
					end
				end
				local peds = zf:FindFirstChild("Pedestals")
				if peds then
					for _, ped in ipairs(peds:GetChildren()) do
						local eggId = ped:GetAttribute("EggId")
						local prompt = ped:FindFirstChildWhichIsA("ProximityPrompt", true)
						if eggId and prompt then
							prompt.Triggered:Connect(function(player)
								doHatch(player, eggId, 1)
							end)
						end
					end
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- GAMEPASS / DEVPRODUCT (MarketplaceService)
----------------------------------------------------------------------
local function onGamePassPurchased(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	local prof = getProfile(player)
	if not prof then return end
	for name, info in pairs(PetData.Gamepasses) do
		if info.assetId == gamePassId then
			prof.gamepasses[name] = true
		end
	end
	setAttr(player, "EquipSlots", currentEquipSlots(prof))
	recomputeCPS(prof)
	pushSnapshot(player, fullSnapshot(prof))
end

-- ProcessReceipt grant (idempotent per G5)
local function grantProduct(prof, productId)
	for _, info in pairs(PetData.DevProducts) do
		if info.assetId == productId then
			if info.coins or info.minCPS then
				local byCps = (prof.cps or 0) * (info.minCPS or 0)
				addCoins(prof, math.max(info.coins or 0, byCps))
			elseif info.boost == "luck" then
				addBoost(prof, "luck", info.sec or 900)
				BoostUpdate:FireClient(prof.player, boostsSnapshot(prof))
			elseif info.boost == "coin" then
				addBoost(prof, "coin", info.sec or 900)
				BoostUpdate:FireClient(prof.player, boostsSnapshot(prof))
			elseif info.megaHatch then
				prof.megaHatchTokens = (prof.megaHatchTokens or 0) + 1
			elseif info.invAdd then
				prof.data.inventorySoftCap = (prof.data.inventorySoftCap or Config.InvSoftCap) + info.invAdd
			end
			recomputeCPS(prof)
			pushSnapshot(prof.player, fullSnapshot(prof))
			return true
		end
	end
	return false
end

local function processReceipt(receiptInfo)
	local userId = receiptInfo.PlayerId
	local player = Players:GetPlayerByUserId(userId)
	local purchaseId = receiptInfo.PurchaseId
	local productId = receiptInfo.ProductId

	local prof = player and getProfile(player)
	if prof and prof.loaded then
		prof.data.processedReceipts = prof.data.processedReceipts or {}
		for _, pid in ipairs(prof.data.processedReceipts) do
			if pid == purchaseId then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		local ok = grantProduct(prof, productId)
		if not ok then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(prof.data.processedReceipts, purchaseId)
		while #prof.data.processedReceipts > 50 do
			table.remove(prof.data.processedReceipts, 1)
		end
		-- grant only after a successful save
		local saved = savePlayer(player, false)
		if not saved then
			-- roll back: remove receipt id so retry can re-grant after a good save
			for idx = #prof.data.processedReceipts, 1, -1 do
				if prof.data.processedReceipts[idx] == purchaseId then
					table.remove(prof.data.processedReceipts, idx)
					break
				end
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- player not in-session: cannot grant reliably; ask Roblox to retry later
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

----------------------------------------------------------------------
-- SAVE / LOAD
----------------------------------------------------------------------
savePlayer = function(player, releaseLock)
	local prof = getProfile(player)
	if not prof or not prof.loaded then return false end
	local d = prof.data
	local petList = {}
	for _, pet in pairs(prof.pets) do
		table.insert(petList, {
			Type = pet.Type, Mut = pet.Mut, Equipped = pet.Equipped,
			Locked = pet.Locked, Shiny = pet.Shiny,
		})
	end
	d.pets = petList
	d.boosts = boostsSnapshot(prof)
	d.lastLeaveTs = now()

	local ok, err = safeUpdate(player.UserId, function(old)
		-- session-lock check: only write if we hold the lock or it's stale
		if old and old.lock and old.lock.jobId and old.lock.jobId ~= "" and old.lock.jobId ~= JOB_ID then
			if (now() - (old.lock.ts or 0)) < LOCK_STALE_SEC then
				return nil  -- someone else holds a fresh lock; don't clobber
			end
		end
		local out = deepCopy(d)
		if releaseLock then
			out.lock = { jobId = "", ts = now() }
		else
			out.lock = { jobId = JOB_ID, ts = now() }
		end
		return out
	end)
	if not ok then
		warn("[PetServer] save failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	return true
end

local function grantStarterChest(prof)
	local d = prof.data
	d.coins = (d.coins or 0) + Config.StartCoins
	d.coinsEarned = (d.coinsEarned or 0) + Config.StartCoins
	addPet(prof, { Type = "clover_cat", Mut = "None", Equipped = true, Locked = false, Shiny = false })
	d.items = d.items or { luck = 0, coin = 0 }
	d.items.luck = (d.items.luck or 0) + 1
	addBoost(prof, "newplayer", Config.NewPlayerBoostSec)
	d.firstJoin = false
	d.tutorialStep = 0
end

local function grantOfflineEarnings(prof)
	local d = prof.data
	if not d.lastLeaveTs or d.lastLeaveTs <= 0 then return end
	local elapsed = now() - d.lastLeaveTs
	if elapsed <= 0 then return end
	local vip = hasPass(prof, "VIP")
	local rate = vip and Config.OfflineRateVIP or Config.OfflineRate
	local cap = vip and Config.OfflineCapVIP or Config.OfflineCapSeconds
	elapsed = math.min(elapsed, cap)
	local grant = math.floor((prof.cps or 0) * elapsed * rate)
	if grant > 0 then
		addCoins(prof, grant)
		Notify:FireClient(prof.player, "welcomeback", { coins = grant, seconds = elapsed })
	end
end

local function onPlayerAdded(player)
	setupLeaderstats(player)

	local petsFolder = Instance.new("Folder")
	petsFolder.Name = "Pets"
	petsFolder.Parent = player

	for _, k in ipairs({ "CPS","CoinsEarned","Zone","ZonesUnlocked","EquipSlots","Luck","IndexBonus","RebirthTokens","TutorialStep" }) do
		setAttr(player, k, 0)
	end
	setAttr(player, "Zone", 1)
	setAttr(player, "DataLoaded", false)

	-- LOAD with session lock via UpdateAsync
	local loadedData
	local ok, result = safeUpdate(player.UserId, function(old)
		old = migrate(old)
		if old == nil then
			old = defaultData()
		end
		if old.lock and old.lock.jobId and old.lock.jobId ~= "" and old.lock.jobId ~= JOB_ID then
			if (now() - (old.lock.ts or 0)) < LOCK_STALE_SEC then
				return nil  -- locked by another live session; refuse (no write)
			end
		end
		old.lock = { jobId = JOB_ID, ts = now() }
		return old
	end)

	if ok and result then
		loadedData = result
	elseif ok and result == nil then
		-- migrate produced nil (no save) or locked elsewhere; try a plain read
		local rok, rdata = safeRead(player.UserId)
		if rok and rdata then
			loadedData = migrate(rdata)
		end
	end

	-- only the player still being in-game matters; bail if they left during load
	if not player.Parent then
		return
	end

	if not loadedData then
		if not mockMode then
			player:Kick("Data load failed, please rejoin.")
			return
		else
			loadedData = defaultData()
		end
	end

	local prof = {
		player = player,
		data = loadedData,
		pets = {},
		boosts = {},
		buckets = {},
		gamepasses = {},
		cps = 0,
		sessionSec = 0,
		nextPlaytimeReward = 300,
		megaHatchTokens = 0,
		loaded = false,
	}
	Profiles[player.UserId] = prof

	refreshGamepasses(prof)

	for _, b in ipairs(loadedData.boosts or {}) do
		if b.expiresAt and b.expiresAt > now() then
			table.insert(prof.boosts, { boostType = b.boostType, expiresAt = b.expiresAt })
		end
	end

	if loadedData.firstJoin == nil or loadedData.firstJoin == true then
		grantStarterChest(prof)
	end

	loadedData.index = loadedData.index or {}
	for _, pet in ipairs(loadedData.pets or {}) do
		if pet and pet.Type and PetData.Pets[pet.Type] then
			local guid = HttpService:GenerateGUID(false)
			local petTbl = {
				Type = pet.Type,
				Mut = (pet.Mut and PetData.Mutations[pet.Mut]) and pet.Mut or "None",
				Equipped = pet.Equipped == true,
				Locked = pet.Locked == true,
				Shiny = pet.Shiny == true,
			}
			prof.pets[guid] = petTbl
			makePetInstance(player, guid, petTbl)
			loadedData.index[pet.Type] = true
		end
	end

	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Coins.Value = math.clamp(loadedData.coins or 0, 0, 2^31 - 1)
		ls.Rebirths.Value = loadedData.rebirths or 0
	end

	setAttr(player, "CoinsEarned", loadedData.coinsEarned or 0)
	setAttr(player, "RebirthTokens", loadedData.rebirthTokens or 0)
	setAttr(player, "TutorialStep", loadedData.tutorialStep or 0)
	recomputeZoneMask(prof)
	setAttr(player, "ZonesUnlocked", loadedData.zonesUnlocked)
	setAttr(player, "EquipSlots", currentEquipSlots(prof))
	setAttr(player, "Luck", effectiveLuck(prof))

	ensureDailyQuests(prof)

	recomputeCPS(prof)
	grantOfflineEarnings(prof)

	-- enforce equip slot cap (in case slots shrank)
	local equippedCount = 0
	for guid, pet in pairs(prof.pets) do
		if pet.Equipped then
			equippedCount += 1
			if equippedCount > currentEquipSlots(prof) then
				pet.Equipped = false
				updatePetInstance(player, guid, pet)
			end
		end
	end
	recomputeCPS(prof)

	prof.loaded = true
	setAttr(player, "DataLoaded", true)

	pushSnapshot(player, fullSnapshot(prof))
	BoostUpdate:FireClient(player, boostsSnapshot(prof))

	-- re-teleport to current zone on respawn
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		local zone = player:GetAttribute("Zone") or 1
		if zone > 1 then
			teleportToZone(player, zone)
		end
	end)
end

local function onPlayerRemoving(player)
	local prof = getProfile(player)
	if prof and prof.loaded then
		savePlayer(player, true)  -- release lock
	end
	Profiles[player.UserId] = nil
end

----------------------------------------------------------------------
-- FOLLOWER MOVEMENT LOOP  (one loop for all players' equipped pets)
----------------------------------------------------------------------
local function ensureFollowerContainer()
	local world = Workspace:FindFirstChild("World")
	if not world then return nil end
	local pf = world:FindFirstChild("PetFollowers")
	if not pf then
		pf = Instance.new("Folder")
		pf.Name = "PetFollowers"
		pf.Parent = world
	end
	return pf
end

local function rebuildFollowers(prof)
	local pf = ensureFollowerContainer()
	if not pf then return end
	local userTag = tostring(prof.player.UserId)
	local container = pf:FindFirstChild(userTag)
	if not container then
		container = Instance.new("Folder")
		container.Name = userTag
		container.Parent = pf
	end
	local desired = {}
	local n = 0
	for guid, pet in pairs(prof.pets) do
		if pet.Equipped and n < 10 then
			desired[guid] = pet
			n += 1
		end
	end
	for _, m in ipairs(container:GetChildren()) do
		if not desired[m.Name] then m:Destroy() end
	end
	for guid, pet in pairs(desired) do
		if not container:FindFirstChild(guid) then
			local part = Instance.new("Part")
			part.Name = guid
			part.Size = Vector3.new(1.6, 1.6, 1.6)
			part.Shape = Enum.PartType.Ball
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Material = Enum.Material.Neon
			local rarity = PetData.Pets[pet.Type] and PetData.Pets[pet.Type].rarity
			local rcol = rarity and PetData.Rarities[rarity] and PetData.Rarities[rarity].color
			part.Color = rcol or Color3.fromRGB(255, 255, 255)
			part:SetAttribute("Type", pet.Type)
			part:SetAttribute("PetGuid", guid)
			part.Parent = container
		end
	end
end

----------------------------------------------------------------------
-- MAIN HEARTBEAT (1s coin tick) + follower orbit + boost prune
----------------------------------------------------------------------
local coinAccum = 0
RunService.Heartbeat:Connect(function(dt)
	coinAccum += dt
	if coinAccum >= 1 then
		local whole = math.floor(coinAccum)
		coinAccum -= whole
		for _, player in ipairs(Players:GetPlayers()) do
			local prof = getProfile(player)
			if prof and prof.loaded then
				if pruneBoosts(prof) then
					recomputeCPS(prof)
					BoostUpdate:FireClient(player, boostsSnapshot(prof))
				end
				local autoExtra = 0
				if hasPass(prof, "AutoCollect") then
					autoExtra = PetData.clickValue(prof.cps or 0, prof.data.rebirths)
						* PetData.Gamepasses.AutoCollect.autoClick * coinMultiplier(prof)
				end
				local gain = (prof.cps or 0) * whole + autoExtra * whole
				if gain > 0 then
					addCoins(prof, gain)
				end
				prof.sessionSec = (prof.sessionSec or 0) + whole
				syncCore(prof)
				rebuildFollowers(prof)
			end
		end
	end

	local world = Workspace:FindFirstChild("World")
	local pf = world and world:FindFirstChild("PetFollowers")
	if pf then
		local t = os.clock()
		for _, container in ipairs(pf:GetChildren()) do
			local userId = tonumber(container.Name)
			local player = userId and Players:GetPlayerByUserId(userId)
			local char = player and player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local kids = container:GetChildren()
				local count = #kids
				for i, part in ipairs(kids) do
					if part:IsA("BasePart") then
						local angle = (t * 1.5) + (i / math.max(1, count)) * math.pi * 2
						local radius = 4
						local offset = Vector3.new(math.cos(angle) * radius, 2 + math.sin(t * 2 + i) * 0.4, math.sin(angle) * radius)
						part.CFrame = CFrame.new(hrp.Position + offset)
					end
				end
			end
		end
	end
end)

----------------------------------------------------------------------
-- AUTOSAVE LOOP
----------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			local prof = getProfile(player)
			if prof and prof.loaded then
				pcall(function() savePlayer(player, false) end)
			end
		end
	end
end)

----------------------------------------------------------------------
-- AUTO-HATCH (gamepass / setting) loop
----------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(2)
		for _, player in ipairs(Players:GetPlayers()) do
			local prof = getProfile(player)
			if prof and prof.loaded and prof.data.settings.autohatch and hasPass(prof, "AutoHatch") then
				local zone = player:GetAttribute("Zone") or 1
				local zdef = PetData.Zones[zone]
				if zdef then
					for _, eggId in ipairs(zdef.eggs) do
						local egg = PetData.Eggs[eggId]
						if egg and prof.data.coins >= egg.cost then
							doHatch(player, eggId, 1)
							break
						end
					end
				end
			end
		end
	end
end)

----------------------------------------------------------------------
-- BINDTOCLOSE
----------------------------------------------------------------------
game:BindToClose(function()
	local players = Players:GetPlayers()
	local remaining = #players
	if remaining == 0 then return end
	for _, player in ipairs(players) do
		task.spawn(function()
			pcall(function() savePlayer(player, true) end)
			remaining -= 1
		end)
	end
	local deadline = os.clock() + 28
	while remaining > 0 and os.clock() < deadline do
		task.wait(0.2)
	end
end)

----------------------------------------------------------------------
-- REMOTE WIRING
----------------------------------------------------------------------
ClickCoin.OnServerEvent:Connect(function(player) handleClick(player) end)
HatchRequest.OnServerEvent:Connect(function(player, eggId, count)
	doHatch(player, tostring(eggId), tonumber(count) or 1)
end)
EquipPet.OnServerEvent:Connect(function(player, guid) doEquip(player, tostring(guid)) end)
UnequipPet.OnServerEvent:Connect(function(player, guid) doUnequip(player, tostring(guid)) end)
FuseRequest.OnServerEvent:Connect(function(player, guids) doFuse(player, guids) end)
FuseAll.OnServerEvent:Connect(function(player) doFuseAll(player) end)
SellPets.OnServerEvent:Connect(function(player, guids) doSellPets(player, guids) end)
SellBulk.OnServerEvent:Connect(function(player, filter) doSellBulk(player, tostring(filter)) end)
LockPet.OnServerEvent:Connect(function(player, guid, locked) doLock(player, tostring(guid), locked) end)
RebirthRequest.OnServerEvent:Connect(function(player) doRebirth(player) end)
TravelTo.OnServerEvent:Connect(function(player, zoneIndex) doTravel(player, zoneIndex) end)
ClaimDaily.OnServerEvent:Connect(function(player) doClaimDaily(player) end)
ClaimQuest.OnServerEvent:Connect(function(player, questId) doClaimQuest(player, tostring(questId)) end)
ClaimPlaytime.OnServerEvent:Connect(function(player) doClaimPlaytime(player) end)
ClaimIndexTier.OnServerEvent:Connect(function(player, poolName) doClaimIndexTier(player, tostring(poolName)) end)
UseBoostItem.OnServerEvent:Connect(function(player, itemId) doUseBoostItem(player, tostring(itemId)) end)
SetSetting.OnServerEvent:Connect(function(player, key, val) doSetSetting(player, tostring(key), val) end)
SetTutorialStep.OnServerEvent:Connect(function(player, step) doSetTutorialStep(player, step) end)

-- GetDropTable: returns effective percent table applying caller's luck
GetDropTable.OnServerInvoke = function(player, eggId)
	local prof = getProfile(player)
	local egg = PetData.Eggs[tostring(eggId)]
	if not egg then return {} end
	local luck = prof and effectiveLuck(prof) or 1
	local rarerHalf = { Rare = true, Epic = true, Legendary = true, Mythic = true, Secret = true }
	local weights = {}
	local total = 0
	for rarity, pct in pairs(egg.odds) do
		local w = pct * 10
		if rarerHalf[rarity] then w *= luck end
		weights[rarity] = w
		total += w
	end
	local out = {}
	if total > 0 then
		for rarity, w in pairs(weights) do
			out[rarity] = (w / total) * 100
		end
	end
	return out
end

----------------------------------------------------------------------
-- MARKETPLACE WIRING
----------------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPurchased)
MarketplaceService.ProcessReceipt = processReceipt

----------------------------------------------------------------------
-- PLAYER EVENTS
----------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	local ok, err = pcall(function() onPlayerAdded(player) end)
	if not ok then
		warn("[PetServer] onPlayerAdded error: " .. tostring(err))
		Profiles[player.UserId] = nil
		if not mockMode and player.Parent then
			player:Kick("Data load failed, please rejoin.")
		end
	end
end)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- handle players who joined before script ran
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		local ok = pcall(function() onPlayerAdded(player) end)
		if not ok then
			Profiles[player.UserId] = nil
			if not mockMode and player.Parent then player:Kick("Data load failed, please rejoin.") end
		end
	end)
end

-- world interactions after WorldBuilder populates geometry
task.spawn(function()
	local world = Workspace:WaitForChild("World", 30)
	if world then
		task.wait(1) -- let geometry populate
		setupWorldInteractions()
	end
end)

print("[PetServer] online. MockMode=" .. tostring(mockMode))