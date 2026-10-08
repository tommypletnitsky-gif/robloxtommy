-- Player progress, saved with ProfileStore (session-locked, autosaving; the DevForum's standard).
-- Live values are player attributes; every change is mirrored into the profile so ProfileStore's
-- autosave always has the latest. Old saves from the first version (raw DataStore "RocketSim_v1")
-- are copied over once.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Vendor.ProfileStore)

local PlayerData = {}

PlayerData.DEFAULTS = {
	Money = 0,
	TotalEarned = 0,
	BestDistance = 0,
	UnlockedStage = 1,
	Rocket = "Starter",
	OwnedRockets = "Starter",
	Trail = "None",
	OwnedTrails = "None",
	FuelLevel = 0,
	SpeedLevel = 0,
	MoneyLevel = 0,
	CannonLevel = 0,
	Rebirths = 0,
	Donated = 0,
	DailyStreak = 0,
	LastDaily = 0,
	Pets = "", -- "uid:Kind;uid:Kind" (see Config.parsePets)
	EquippedPets = "", -- "uid,uid"
	NextPetId = 1,
	PetIndex = "", -- every pet kind you've ever owned (Pet Index)
	StatFlights = 0, -- quest stats
	StatDistance = 0,
	StatCoins = 0,
	StatRings = 0,
	StatEggs = 0,
	RaceWins = 0,
	BestCombo = 0,
	Spins = 0, -- Lucky Spin: spins waiting
	SpinProgress = 0, -- seconds played toward the next free spin
	FirstSpin = false, -- the welcome spin was given
	BoostMoneyUntil = 0, -- os.time() when the x2 Money boost ends
	BoostLuckUntil = 0, -- os.time() when the x2 Luck boost ends
	FullBoost = false, -- next flight starts with a full boost bar
	Receipts = "", -- last purchase ids handled (developer products), so a retry never counts twice
	StatPerfect = 0, -- PERFECT launches (daily missions)
	Candy = 0, -- Halloween candy (kept between events)
	MissionDay = 0, -- the day (UTC) today's missions were picked
	Missions = "", -- "id:goal:start,..." (Config.parseMissions)
	MissionsClaimed = "", -- ids claimed today
	MissionBonus = false, -- the all-3 bonus spin was given today
	QuestTiers = "", -- "flights:2,best:1" = goals claimed per quest chain
	Codes = "", -- redeemed codes
	StarterChest = false, -- the free starter chest by the spawn was opened
	StorageLevel = 0, -- pet storage upgrades bought (Config.STORAGE)
	SlotLevel = 0, -- equip slot upgrades bought (Config.SLOT_PRICES)
	AutoDelete = "", -- pet kinds deleted right when hatched: "Kind,Kind"
	FastHatch = false, -- short hatch show
	TradesOff = false, -- don't get trade requests
	SuperLuckUntil = 0, -- server time when a Super Luck potion ends
	Snowflakes = 0, -- Winter event currency (kept between events)
	MusicOn = true,
	SoundOn = true,
	Migrated = false,
}

-- Studio play tests save to their own copy ("_Studio"), so test money / owner commands never touch
-- anyone's real save (with "Studio Access to API Services" on, Studio uses the live DataStores).
PlayerData.STUDIO = RunService:IsStudio()
local function storeName(name)
	return PlayerData.STUDIO and (name .. "_Studio") or name
end
PlayerData.storeName = storeName
local store = ProfileStore.New(storeName("RocketSim_PS1"), PlayerData.DEFAULTS)
local profiles = {} -- [player] = profile
local lastSave = {} -- [player] = os.clock() of the last forced save
local pendingSave = {} -- [player] = true while a delayed save (saveSoon) is waiting
local SAVE_GAP = 30 -- saveSoon: at most one forced save per player this often (seconds)

-- One-time copy of progress saved by the old raw-DataStore version.
local function migrateOld(player, data)
	if data.Migrated then
		return
	end
	data.Migrated = true
	local ok, old = pcall(function()
		return DataStoreService:GetDataStore(storeName("RocketSim_v1")):GetAsync("u_" .. player.UserId)
	end)
	if ok and type(old) == "table" then
		for k, default in pairs(PlayerData.DEFAULTS) do
			if k ~= "Migrated" and type(old[k]) == type(default) then
				data[k] = old[k]
			end
		end
	end
end

function PlayerData.load(player)
	for k, v in pairs(PlayerData.DEFAULTS) do
		player:SetAttribute(k, v)
	end
	local profile = store:StartSessionAsync("u_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		-- couldn't load (or the player left while loading): play on defaults, nothing is saved
		player:SetAttribute("SaveStatus", "off")
		player:SetAttribute("DataLoaded", true)
		return
	end
	profile:AddUserId(player.UserId) -- GDPR compliance
	profile:Reconcile() -- fill in any new fields
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data was loaded on another server. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	migrateOld(player, profile.Data)
	profiles[player] = profile
	for k in pairs(PlayerData.DEFAULTS) do
		player:SetAttribute(k, profile.Data[k])
		player:GetAttributeChangedSignal(k):Connect(function()
			if profiles[player] == profile then
				profile.Data[k] = player:GetAttribute(k)
			end
		end)
	end
	player:SetAttribute("SaveStatus", ProfileStore.DataStoreState == "Access" and "on" or "mock")
	player:SetAttribute("DataLoaded", true)
end

-- Ask ProfileStore to save soon (e.g. right after a purchase or daily reward).
function PlayerData.save(player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		lastSave[player] = os.clock()
		profile:Save()
		return true
	end
	return false
end

-- Throttled save for things that happen in quick runs (hatching eggs back to back): saves now if
-- the last save was over SAVE_GAP ago, otherwise once when the gap is up (one pending per player).
function PlayerData.saveSoon(player)
	if pendingSave[player] then
		return
	end
	local since = os.clock() - (lastSave[player] or -math.huge)
	if since > SAVE_GAP then
		PlayerData.save(player)
		return
	end
	pendingSave[player] = true
	task.delay(SAVE_GAP - since, function()
		if pendingSave[player] then -- (cleared if the player left meanwhile)
			pendingSave[player] = nil
			PlayerData.save(player)
		end
	end)
end

-- True while this player's profile is loaded and can still be saved.
function PlayerData.isActive(player)
	local profile = profiles[player]
	return profile ~= nil and profile:IsActive()
end

function PlayerData.release(player)
	lastSave[player] = nil
	pendingSave[player] = nil
	local profile = profiles[player]
	if profile then
		profiles[player] = nil
		profile:EndSession()
	end
end

return PlayerData
