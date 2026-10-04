-- Loads/saves player progress with DataStores. Live values are player attributes.
-- If DataStores aren't available (e.g. Studio without API access) the game still works, it just doesn't save.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

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
	Rebirths = 0,
	Donated = 0,
	DailyStreak = 0,
	LastDaily = 0,
}

local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore("RocketSim_v1")
end)

local loaded = {} -- [player] = true once data loaded successfully (never save over data we failed to read)

local function key(player)
	return "u_" .. player.UserId
end

function PlayerData.load(player)
	for k, v in pairs(PlayerData.DEFAULTS) do
		player:SetAttribute(k, v)
	end
	if not storeOk or not store then
		player:SetAttribute("DataLoaded", true)
		player:SetAttribute("SaveStatus", "off")
		return
	end
	local data
	local ok, err
	for _ = 1, 3 do
		ok, err = pcall(function()
			data = store:GetAsync(key(player))
		end)
		if ok then
			break
		end
		task.wait(1)
	end
	if ok then
		if type(data) == "table" then
			for k, default in pairs(PlayerData.DEFAULTS) do
				if type(data[k]) == type(default) then
					player:SetAttribute(k, data[k])
				end
			end
		end
		loaded[player] = true
		player:SetAttribute("SaveStatus", "on")
	else
		warn("[PlayerData] load failed for " .. player.Name .. ": " .. tostring(err))
		player:SetAttribute("SaveStatus", "off")
	end
	player:SetAttribute("DataLoaded", true)
end

function PlayerData.save(player)
	if not loaded[player] or not store then
		return false
	end
	local data = {}
	for k in pairs(PlayerData.DEFAULTS) do
		data[k] = player:GetAttribute(k)
	end
	local ok, err = pcall(function()
		store:SetAsync(key(player), data)
	end)
	if not ok then
		warn("[PlayerData] save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

function PlayerData.release(player)
	PlayerData.save(player)
	loaded[player] = nil
end

-- Autosave every 90 seconds and on shutdown.
task.spawn(function()
	while true do
		task.wait(90)
		for player in pairs(loaded) do
			if player.Parent then
				PlayerData.save(player)
			end
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() then
		task.wait(1)
	end
	for player in pairs(loaded) do
		PlayerData.save(player)
	end
end)

return PlayerData
