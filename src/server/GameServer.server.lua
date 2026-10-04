-- Server: player stats, the rocket tool, flights (launch -> fuel -> glide -> payout), stage unlocks.
-- Player stats live in attributes so the client UI can read them directly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local RocketModel = require(ReplicatedStorage.Shared.RocketModel)
local WorldBuilder = require(ServerScriptService.WorldBuilder)

if not workspace:FindFirstChild("World") then
	WorldBuilder.build()
end

local flightsFolder = workspace:FindFirstChild("Flights") or Instance.new("Folder")
flightsFolder.Name = "Flights"
flightsFolder.Parent = workspace

-- Remotes -----------------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function remote(className, name)
	local r = remotes:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local LaunchRemote = remote("RemoteEvent", "Launch") -- client -> server
local FlightEvent = remote("RemoteEvent", "Flight") -- server -> client: ("start", info) / ("outOfFuel") / ("result", info)
local UnlockStage = remote("RemoteFunction", "UnlockStage")
local BuyRocket = remote("RemoteFunction", "BuyRocket") -- (rocketId) buys if needed, then equips
local BuyUpgrade = remote("RemoteFunction", "BuyUpgrade") -- ("Fuel" | "Speed" | "Money")
local Notify = remote("RemoteEvent", "Notify") -- server -> client: (text, color)

-- Player data -------------------------------------------------------------------------
local DEFAULT_DATA = {
	Money = 0,
	BestDistance = 0,
	UnlockedStage = 1,
	Rocket = "Starter",
	OwnedRockets = "Starter", -- comma separated rocket ids
	FuelLevel = 0,
	SpeedLevel = 0,
	MoneyLevel = 0,
	Rebirths = 0,
}

local flights = {} -- [player] = flight state

local function moneyMultiplier(player)
	local m = 1 + (player:GetAttribute("MoneyLevel") or 0) * Config.Upgrades.Money.perLevel
	m *= 1 + (player:GetAttribute("Rebirths") or 0) * 0.5
	return m
end

local function rocketStats(player)
	local def = Config.getRocket(player:GetAttribute("Rocket"))
	local speed = def.speed * (1 + (player:GetAttribute("SpeedLevel") or 0) * Config.Upgrades.Speed.perLevel)
	local fuel = def.fuel * (1 + (player:GetAttribute("FuelLevel") or 0) * Config.Upgrades.Fuel.perLevel)
	return def, speed, fuel
end

local function giveTool(player)
	local def = Config.getRocket(player:GetAttribute("Rocket"))
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and t.Name == "Rocket" then
					t:Destroy()
				end
			end
		end
	end
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end
	-- Clicking with the tool is picked up by RocketClient, which fires the Launch remote.
	RocketModel.buildTool(def).Parent = backpack
end

-- Flights -----------------------------------------------------------------------------
local function hubCFrame()
	local c = Config.HUB_CENTER
	return CFrame.lookAt(c + Vector3.new(-40, 4, math.random(-8, 8)), c + Vector3.new(100, 4, 0))
end

local function endFlight(player, reason)
	local f = flights[player]
	if not f or f.ended then
		return
	end
	f.ended = true
	local distance = math.max(0, math.floor(f.distance))
	local money = math.floor(Config.moneyForDistance(distance) * moneyMultiplier(player))
	player:SetAttribute("Money", (player:GetAttribute("Money") or 0) + money)
	local newBest = distance > (player:GetAttribute("BestDistance") or 0)
	if newBest then
		player:SetAttribute("BestDistance", distance)
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Sit = false
		if f.seat and f.seat:FindFirstChild("SeatWeld") then
			f.seat.SeatWeld:Destroy()
		end
	end
	if f.model then
		f.model:Destroy()
	end
	flights[player] = nil
	player:SetAttribute("Flying", false)
	if char and char.Parent and hum and hum.Health > 0 then
		task.defer(function()
			char:PivotTo(hubCFrame())
		end)
	end
	FlightEvent:FireClient(player, "result", { distance = distance, money = money, reason = reason, newBest = newBest })
end

local function startFlight(player)
	if flights[player] then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return
	end
	local def, speed, fuel = rocketStats(player)
	hum:UnequipTools()

	local startX = Config.LAUNCH_X - 8
	local origin = CFrame.new(startX, Config.pathY(startX) + 4, 0)
	local model = RocketModel.build(def, 1, true, origin)
	model.Name = player.Name
	local body = model.PrimaryPart
	body.Anchored = true
	model.Parent = flightsFolder

	local f = { model = model, seat = model.Seat, speed = speed, fuel = fuel, distance = 0, startX = Config.LAUNCH_X, ended = false }
	flights[player] = f
	player:SetAttribute("Flying", true)

	char:PivotTo(model.Seat.CFrame * CFrame.new(0, 3, 0))
	model.Seat:Sit(hum)

	-- Physics: the client steers through these; the server watches the result.
	local att = Instance.new("Attachment")
	att.Parent = body
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Thrust"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.zero
	lv.Parent = body
	local ao = Instance.new("AlignOrientation")
	ao.Name = "Aim"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = true
	ao.CFrame = CFrame.new()
	ao.Parent = body

	FlightEvent:FireClient(player, "countdown", { seconds = 3 })
	task.delay(3, function()
		if flights[player] ~= f or f.ended then
			return
		end
		if not (hum.Parent and hum.SeatPart == f.seat) then
			endFlight(player, "jumped")
			return
		end
		body.Anchored = false
		body:SetNetworkOwner(player)
		RocketModel.setThrust(model, true)
		f.launchedAt = os.clock()
		FlightEvent:FireClient(player, "start", { speed = speed, fuel = fuel, startX = f.startX, rocket = model })
	end)
end

LaunchRemote.OnServerEvent:Connect(startFlight)

-- Watch every active flight: distance, fuel, gates, cheating.
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, f in pairs(flights) do
		if f.ended or not f.launchedAt then
			continue
		end
		local body = f.model and f.model.PrimaryPart
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not body or not hum or hum.Health <= 0 or hum.SeatPart ~= f.seat then
			endFlight(player, "jumped")
			continue
		end
		local elapsed = now - f.launchedAt
		local x = body.Position.X
		-- Can't go farther than the rocket could possibly have flown.
		local maxX = f.startX + f.speed * 1.15 * elapsed + 15
		x = math.min(x, maxX)
		f.distance = math.max(f.distance, x - f.startX)

		local unlocked = player:GetAttribute("UnlockedStage") or 1
		if unlocked < Config.NUM_STAGES and x >= Config.stageEndX(unlocked) - 2 then
			f.distance = Config.stageEndX(unlocked) - f.startX
			endFlight(player, "gate")
		elseif unlocked >= Config.NUM_STAGES and x >= Config.stageEndX(Config.NUM_STAGES) then
			f.distance = Config.stageEndX(Config.NUM_STAGES) - f.startX
			endFlight(player, "finish")
		elseif not f.outOfFuel and elapsed >= f.fuel then
			f.outOfFuel = now
			RocketModel.setThrust(f.model, false)
			FlightEvent:FireClient(player, "outOfFuel")
		elseif f.outOfFuel and now - f.outOfFuel >= 1.5 then
			endFlight(player, "fuel")
		end
	end
end)

-- Stage unlocking ---------------------------------------------------------------------
UnlockStage.OnServerInvoke = function(player)
	local unlocked = player:GetAttribute("UnlockedStage") or 1
	local nextStage = unlocked + 1
	if nextStage > Config.NUM_STAGES then
		return false, "You unlocked every stage!"
	end
	if (player:GetAttribute("BestDistance") or 0) < Config.stageEndX(unlocked) - Config.LAUNCH_X - 5 then
		return false, "Fly to the end of Stage " .. unlocked .. " first!"
	end
	local cost = Config.stageCost(nextStage)
	local money = player:GetAttribute("Money") or 0
	if money < cost then
		return false, "You need " .. Config.abbreviate(cost - money) .. " more money!"
	end
	player:SetAttribute("Money", money - cost)
	player:SetAttribute("UnlockedStage", nextStage)
	return true, "Stage " .. nextStage .. " unlocked: " .. Config.Stages[nextStage].name .. "!"
end

-- Shop ----------------------------------------------------------------------------------
local function owns(player, id)
	return table.find(string.split(player:GetAttribute("OwnedRockets") or "", ","), id) ~= nil
end

local function spend(player, cost)
	local money = player:GetAttribute("Money") or 0
	if money < cost then
		return false, "You need $" .. Config.abbreviate(cost - money) .. " more!"
	end
	player:SetAttribute("Money", money - cost)
	return true
end

BuyRocket.OnServerInvoke = function(player, id)
	if typeof(id) ~= "string" or flights[player] then
		return false, "Can't do that while flying!"
	end
	local def
	for _, r in ipairs(Config.Rockets) do
		if r.id == id then
			def = r
		end
	end
	if not def then
		return false, "Unknown rocket."
	end
	if not owns(player, id) then
		local ok, msg = spend(player, def.price)
		if not ok then
			return false, msg
		end
		player:SetAttribute("OwnedRockets", player:GetAttribute("OwnedRockets") .. "," .. id)
	end
	player:SetAttribute("Rocket", id)
	return true, def.name .. " equipped!"
end

BuyUpgrade.OnServerInvoke = function(player, key)
	local u = typeof(key) == "string" and Config.Upgrades[key]
	if not u then
		return false, "Unknown upgrade."
	end
	local attr = key .. "Level"
	local level = player:GetAttribute(attr) or 0
	if level >= u.maxLevel then
		return false, u.name .. " is maxed!"
	end
	local ok, msg = spend(player, Config.upgradeCost(key, level))
	if not ok then
		return false, msg
	end
	player:SetAttribute(attr, level + 1)
	return true, u.name .. " level " .. (level + 1) .. "!"
end

-- Players -----------------------------------------------------------------------------
local function setupLeaderstats(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local money = Instance.new("StringValue")
	money.Name = "Money"
	money.Parent = ls
	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Parent = ls
	local function refresh()
		money.Value = Config.abbreviate(player:GetAttribute("Money") or 0)
		stage.Value = player:GetAttribute("UnlockedStage") or 1
	end
	player:GetAttributeChangedSignal("Money"):Connect(refresh)
	player:GetAttributeChangedSignal("UnlockedStage"):Connect(refresh)
	refresh()
end

Players.PlayerAdded:Connect(function(player)
	for k, v in pairs(DEFAULT_DATA) do
		player:SetAttribute(k, v)
	end
	player:SetAttribute("Flying", false)
	setupLeaderstats(player)
	player.CharacterAdded:Connect(function()
		task.defer(giveTool, player)
	end)
	player:GetAttributeChangedSignal("Rocket"):Connect(function()
		giveTool(player)
	end)
	if player.Character then
		giveTool(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local f = flights[player]
	if f and f.model then
		f.model:Destroy()
	end
	flights[player] = nil
end)
