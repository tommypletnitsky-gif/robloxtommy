-- Server: player stats, the rocket tool, flights (launch -> fuel -> glide -> payout), pickups,
-- stage unlocks and the shop. Player stats live in attributes so the client UI can read them directly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local RocketModel = require(ReplicatedStorage.Shared.RocketModel)
local WorldBuilder = require(ServerScriptService.WorldBuilder)
local PlayerData = require(ServerScriptService.PlayerData)

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
local FlightEvent = remote("RemoteEvent", "Flight") -- server -> client: countdown / start / pickup / outOfFuel / result
local CollectRemote = remote("RemoteEvent", "Collect") -- client -> server: (pickupId)
local UnlockStage = remote("RemoteFunction", "UnlockStage")
local BuyRocket = remote("RemoteFunction", "BuyRocket") -- (rocketId) buys if needed, then equips
local BuyUpgrade = remote("RemoteFunction", "BuyUpgrade") -- ("Fuel" | "Speed" | "Money")
local BuyTrail = remote("RemoteFunction", "BuyTrail") -- (trailId) buys if needed, then equips
local Notify = remote("RemoteEvent", "Notify") -- server -> client: (text, color)
local RebirthRemote = remote("RemoteFunction", "Rebirth") -- () -> ok, message

local flights = {} -- [player] = flight state

local function moneyMultiplier(player)
	local m = 1 + (player:GetAttribute("MoneyLevel") or 0) * Config.Upgrades.Money.perLevel
	m *= Config.rebirthMultiplier(player:GetAttribute("Rebirths") or 0)
	m *= player:GetAttribute("PetMultiplier") or 1 -- set by PetServer from the equipped pets
	return m
end

local function addMoney(player, amount)
	amount = math.floor(amount)
	player:SetAttribute("Money", (player:GetAttribute("Money") or 0) + amount)
	player:SetAttribute("TotalEarned", (player:GetAttribute("TotalEarned") or 0) + amount)
end

local function rocketStats(player)
	local def = Config.getRocket(player:GetAttribute("Rocket"))
	local speed = def.speed * (1 + (player:GetAttribute("SpeedLevel") or 0) * Config.Upgrades.Speed.perLevel)
	local fuel = def.fuel * (1 + (player:GetAttribute("FuelLevel") or 0) * Config.Upgrades.Fuel.perLevel)
	return def, speed, fuel
end

-- Pickups (coins, gems, boost rings, obstacles) are built into Workspace.World.Pickups.
local pickups = {} -- [id] = { kind, pos, stage }
do
	local folder = workspace.World:WaitForChild("Pickups", 10)
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			local id = m:GetAttribute("Id")
			if id then
				pickups[id] = { kind = m:GetAttribute("Kind"), pos = m:GetAttribute("Pos") or m:GetPivot().Position, stage = m:GetAttribute("Stage") or 1 }
			end
		end
	end
end

-- Flights -----------------------------------------------------------------------------
local function hubCFrame()
	local c = Config.HUB_CENTER
	return CFrame.lookAt(c + Vector3.new(-40, 4, math.random(-8, 8)), c + Vector3.new(100, 4, 0))
end

-- How far the hip joints sit below the root part's center, read from the rig (not the animation).
local function hipDrop(char)
	local rootJ = char:FindFirstChild("Root", true)
	local hipJ = char:FindFirstChild("RightHip", true)
	if rootJ and hipJ and rootJ:IsA("AnimationConstraint") and hipJ:IsA("AnimationConstraint") and rootJ.Attachment0 and rootJ.Attachment1 and hipJ.Attachment0 then
		return -(rootJ.Attachment0.Position.Y - rootJ.Attachment1.Position.Y + hipJ.Attachment0.Position.Y)
	elseif rootJ and hipJ and rootJ:IsA("Motor6D") and hipJ:IsA("Motor6D") then
		return -(rootJ.C0.Position.Y - rootJ.C1.Position.Y + hipJ.C0.Position.Y)
	end
	return 1.1
end

-- Put the rider on the rocket: kneeling on top of the seat, facing the nose, welded on, and
-- PlatformStanding so no default animation fights RiderAnimator's pose.
local RIDE_HIP_LIFT = 0.45 -- hips this far above the seat (the knees rest on the rocket)
local function mountRider(f, char, hum, root)
	local body = f.model.PrimaryPart
	local seatLocal = body.CFrame:ToObjectSpace(f.seat.CFrame).Position
	local y = seatLocal.Y + f.seat.Size.Y / 2 + math.clamp(hipDrop(char), 0.5, 3) + RIDE_HIP_LIFT
	hum.Sit = false
	hum.PlatformStand = true
	char:PivotTo(body.CFrame * CFrame.new(seatLocal.X, y, seatLocal.Z) * CFrame.Angles(0, -math.pi / 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Name = "RideWeld"
	weld.Part0 = body
	weld.Part1 = root
	weld.Parent = root
	f.weld = weld
end

local function dismountRider(f, hum)
	if f.weld then
		f.weld:Destroy()
		f.weld = nil
	end
	if hum then
		hum.PlatformStand = false
	end
end

local function endFlight(player, reason)
	local f = flights[player]
	if not f or f.ended then
		return
	end
	f.ended = true
	flights[player] = nil
	local distance = math.max(0, math.floor(f.distance))
	local money = math.floor(Config.moneyForDistance(distance) * moneyMultiplier(player))
	addMoney(player, money)
	-- quest stats
	player:SetAttribute("StatFlights", (player:GetAttribute("StatFlights") or 0) + 1)
	player:SetAttribute("StatDistance", (player:GetAttribute("StatDistance") or 0) + distance)
	local newBest = distance > (player:GetAttribute("BestDistance") or 0)
	if newBest then
		player:SetAttribute("BestDistance", distance)
	end
	FlightEvent:FireClient(player, "result", {
		distance = distance,
		money = money,
		bonus = f.bonus,
		coins = f.coins,
		reason = reason,
		newBest = newBest,
	})

	-- Keep the rocket where it landed for a moment (landing celebration), then go home.
	local body = f.model and f.model.PrimaryPart
	if body and body.Parent then
		body.Anchored = true
		RocketModel.setThrust(f.model, false)
	end
	task.delay(reason == "jumped" and 0 or 2.6, function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		dismountRider(f, hum)
		if f.model then
			f.model:Destroy()
		end
		-- Wait a moment after getting off: the client takes back physics ownership of its character
		-- and would otherwise overwrite our teleport with its old position.
		task.wait(0.2)
		if player.Parent then
			local home = hubCFrame()
			for _ = 1, 3 do
				if char and char.Parent and hum and hum.Health > 0 and (char:GetPivot().Position - home.Position).Magnitude > 20 then
					char:PivotTo(home)
				end
				task.wait(0.25)
			end
			player:SetAttribute("Flying", false)
		end
	end)
end

local function startFlight(player)
	if flights[player] or player:GetAttribute("Flying") then
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

	-- the rocket is loaded inside the launch cannon's barrel (Lobby sets LoadX / LoadY / Tilt on it)
	local hub = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Hub")
	local cannon = hub and hub:FindFirstChild("Cannon")
	local startX = cannon and cannon:GetAttribute("LoadX") or (Config.LAUNCH_X - 8)
	local loadY = cannon and cannon:GetAttribute("LoadY") or (Config.pathY(startX) + 4)
	local origin = CFrame.new(startX, loadY, 0) * CFrame.Angles(0, 0, cannon and cannon:GetAttribute("Tilt") or 0)
	local model = RocketModel.build(def, 1, true, origin)
	model.Name = player.Name
	RocketModel.addTrail(model, Config.getTrail(player:GetAttribute("Trail")))
	local body = model.PrimaryPart
	body.Anchored = true
	model:SetAttribute("InCannon", true) -- clients hide the rocket + rider until the cannon fires
	model.Parent = flightsFolder

	local f = {
		model = model,
		seat = model:FindFirstChild("Seat", true),
		speed = speed,
		fuel = fuel,
		distance = 0,
		startX = Config.LAUNCH_X,
		ended = false,
		collected = {},
		bonus = 0,
		coins = 0,
	}
	flights[player] = f
	player:SetAttribute("Flying", true)

	mountRider(f, char, hum, root)

	-- Physics: the client steers through these; the server watches the result.
	local att = Instance.new("Attachment")
	att.Name = "ThrustAttachment"
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

	FlightEvent:FireClient(player, "countdown", { seconds = 3, rocket = model })
	task.delay(3, function()
		if flights[player] ~= f or f.ended then
			return
		end
		if not (hum.Parent and f.weld and f.weld.Parent) then
			endFlight(player, "jumped")
			return
		end
		body.Anchored = false
		body:SetNetworkOwner(player)
		model:SetAttribute("InCannon", false)
		RocketModel.setThrust(model, true)
		f.launchedAt = os.clock()
		f.maxX = math.max(f.startX, body.Position.X) + 15
		-- BOOM: the cannon blast (stronger + longer with Cannon Power upgrades)
		f.blastPower, f.blastTime = Config.cannonBlast(player:GetAttribute("CannonLevel") or 0)
		FlightEvent:FireClient(player, "start", { speed = speed, fuel = fuel, startX = f.startX, rocket = model, blastPower = f.blastPower, blastTime = f.blastTime })
	end)
end

LaunchRemote.OnServerEvent:Connect(startFlight)

-- Pickups: the client says "I hit this one", the server checks it's believable.
CollectRemote.OnServerEvent:Connect(function(player, id)
	local f = flights[player]
	local p = typeof(id) == "number" and pickups[id]
	if not f or f.ended or not f.launchedAt or not p or f.collected[id] then
		return
	end
	local body = f.model and f.model.PrimaryPart
	if not body then
		return
	end
	-- The server sees the rocket a little behind where the client is, so allow some lag.
	local d = p.pos - body.Position
	if d.X < -20 or d.X > f.speed * 0.6 + 25 or math.abs(d.Y) > 30 or math.abs(d.Z) > 30 or p.pos.X > f.maxX + 20 then
		return
	end
	f.collected[id] = true
	local now = os.clock()
	if p.kind == "Coin" or p.kind == "Gem" then
		local amount = math.floor(Config.moneyPerStud(p.stage) * Config.Pickups[p.kind].studs * moneyMultiplier(player))
		addMoney(player, amount)
		f.bonus += amount
		f.coins += 1
		player:SetAttribute("StatCoins", (player:GetAttribute("StatCoins") or 0) + 1)
		FlightEvent:FireClient(player, "pickup", { id = id, kind = p.kind, money = amount })
	elseif p.kind == "Ring" then
		local r = Config.Pickups.Ring
		f.fuel += r.fuel
		f.boostUntil = now + r.boostTime
		player:SetAttribute("StatRings", (player:GetAttribute("StatRings") or 0) + 1)
		FlightEvent:FireClient(player, "pickup", { id = id, kind = "Ring", fuel = f.fuel })
	elseif p.kind == "Obstacle" then
		local o = Config.Pickups.Obstacle
		f.fuel = math.max(now - f.launchedAt + 0.2, f.fuel - o.fuelLoss)
		FlightEvent:FireClient(player, "pickup", { id = id, kind = "Obstacle", fuel = f.fuel })
	end
end)

-- Watch every active flight: distance, fuel, gates, cheating.
local GLIDE_TIME = 2.5
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for player, f in pairs(flights) do
		if f.ended or not f.launchedAt then
			continue
		end
		local body = f.model and f.model.PrimaryPart
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not body or not hum or hum.Health <= 0 or not (f.weld and f.weld.Parent) then
			endFlight(player, "jumped")
			continue
		end
		local elapsed = now - f.launchedAt
		-- Can't go farther than the rocket could possibly have flown (boost rings allow a bit more).
		local boosting = now < (f.boostUntil or 0)
		local cap = boosting and Config.Pickups.Ring.boost * 1.1 or 1.15
		if f.blastTime and elapsed < f.blastTime + 0.5 then
			cap = math.max(cap, f.blastPower * 1.1) -- the cannon blast
		end
		f.maxX += f.speed * cap * dt
		local x = math.min(body.Position.X, f.maxX)
		f.distance = math.max(f.distance, x - f.startX)

		local unlocked = player:GetAttribute("UnlockedStage") or 1
		if unlocked < Config.NUM_STAGES and x >= Config.stageEndX(unlocked) - 2 then
			f.distance = Config.stageEndX(unlocked) - f.startX
			endFlight(player, "gate")
		elseif unlocked >= Config.NUM_STAGES and x >= Config.stageEndX(Config.NUM_STAGES) then
			f.distance = Config.stageEndX(Config.NUM_STAGES) - f.startX
			endFlight(player, "finish")
		elseif elapsed > 1.5 and body.Position.Y - Config.pathY(body.Position.X) < Config.LAND_HEIGHT then
			-- touched down: dove into the ground on purpose, or the glide reached the ground
			endFlight(player, f.outOfFuel and "fuel" or "landed")
		elseif not f.outOfFuel and elapsed >= f.fuel then
			f.outOfFuel = now
			RocketModel.setThrust(f.model, false)
			FlightEvent:FireClient(player, "outOfFuel")
		elseif f.outOfFuel and now - f.outOfFuel >= GLIDE_TIME then
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
		return false, "You need $" .. Config.abbreviate(cost - money) .. " more!"
	end
	player:SetAttribute("Money", money - cost)
	player:SetAttribute("UnlockedStage", nextStage)
	return true, "Stage " .. nextStage .. " unlocked: " .. Config.Stages[nextStage].name .. "!"
end

-- Shop ----------------------------------------------------------------------------------
local function ownsIn(player, attr, id)
	return table.find(string.split(player:GetAttribute(attr) or "", ","), id) ~= nil
end

local function spend(player, cost)
	local money = player:GetAttribute("Money") or 0
	if money < cost then
		return false, "You need $" .. Config.abbreviate(cost - money) .. " more!"
	end
	player:SetAttribute("Money", money - cost)
	return true
end

local function findById(list, id)
	for _, item in ipairs(list) do
		if item.id == id then
			return item
		end
	end
end

-- Buy (if not owned) then equip. Used for rockets and trails.
local function buyOrEquip(player, list, ownedAttr, equipAttr, id)
	if typeof(id) ~= "string" then
		return false, "Unknown item."
	end
	if player:GetAttribute("Flying") then
		return false, "Can't do that while flying!"
	end
	local item = findById(list, id)
	if not item then
		return false, "Unknown item."
	end
	if not ownsIn(player, ownedAttr, id) then
		local ok, msg = spend(player, item.price)
		if not ok then
			return false, msg
		end
		player:SetAttribute(ownedAttr, player:GetAttribute(ownedAttr) .. "," .. id)
	end
	player:SetAttribute(equipAttr, id)
	return true, item.name .. " equipped!"
end

BuyRocket.OnServerInvoke = function(player, id)
	return buyOrEquip(player, Config.Rockets, "OwnedRockets", "Rocket", id)
end

BuyTrail.OnServerInvoke = function(player, id)
	return buyOrEquip(player, Config.Trails, "OwnedTrails", "Trail", id)
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

-- Rebirth ---------------------------------------------------------------------------------
-- Unlock far enough, then start over for a permanent money bonus and one more pet slot.
-- Resets money, stages, best distance, rockets and upgrades; keeps pets, trails and rewards.
RebirthRemote.OnServerInvoke = function(player)
	if player:GetAttribute("Flying") then
		return false, "Land first, then rebirth!"
	end
	local rebirths = player:GetAttribute("Rebirths") or 0
	local need = Config.rebirthStage(rebirths)
	if (player:GetAttribute("UnlockedStage") or 1) < need then
		return false, "Unlock Stage " .. need .. " to rebirth!"
	end
	player:SetAttribute("Money", 0)
	player:SetAttribute("UnlockedStage", 1)
	player:SetAttribute("BestDistance", 0)
	player:SetAttribute("Rocket", "Starter")
	player:SetAttribute("OwnedRockets", "Starter")
	for key in pairs(Config.Upgrades) do
		player:SetAttribute(key .. "Level", 0)
	end
	player:SetAttribute("Rebirths", rebirths + 1)
	PlayerData.save(player)
	Notify:FireAllClients("🌟 " .. player.DisplayName .. " rebirthed! (Rebirth " .. (rebirths + 1) .. ")", Color3.fromRGB(255, 210, 90))
	return true, "Rebirth " .. (rebirths + 1) .. "! Money x" .. Config.rebirthMultiplier(rebirths + 1) .. " forever"
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
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = ls
	local function refresh()
		money.Value = "$" .. Config.abbreviate(player:GetAttribute("Money") or 0)
		stage.Value = player:GetAttribute("UnlockedStage") or 1
		rebirths.Value = player:GetAttribute("Rebirths") or 0
	end
	player:GetAttributeChangedSignal("Money"):Connect(refresh)
	player:GetAttributeChangedSignal("UnlockedStage"):Connect(refresh)
	player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
	refresh()
end

local function onPlayerAdded(player)
	player:SetAttribute("Flying", false)
	player:SetAttribute("JoinedAt", os.time())
	PlayerData.load(player)
	setupLeaderstats(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local f = flights[player]
	if f and f.model then
		f.model:Destroy()
	end
	flights[player] = nil
	PlayerData.release(player)
end)
