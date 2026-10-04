-- Builds the map from Config: hub, launch pad, 30 stages, gates, distance signs, decor.
-- Everything goes into Workspace.World. Safe to run again: it rebuilds from scratch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Scenery = require(game:GetService("ServerScriptService").Scenery)
local Lobby = require(game:GetService("ServerScriptService").Lobby)

local WorldBuilder = {}

local L = Config.STAGE_LENGTH
local HALF = Config.PATH_HALF_WIDTH

local function newPart(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function sign(part, face, text, textColor, bg)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg or Color3.fromRGB(25, 25, 35)
	label.BackgroundTransparency = bg and 0 or 1
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = label
	return label
end

-- Map --------------------------------------------------------------------------------
local function cyl(parent, length, diameter, cf, color, props)
	local t = { Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), CFrame = cf, Color = color }
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return newPart(parent, t)
end

local UP = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's X axis to point up

local function buildHub(world)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world
	Lobby.build(hub) -- spawn is kept empty: lawn, paths, two shops, launcher
end

-- Pickups ----------------------------------------------------------------------------------
local nextPickupId = 0
local function pickupModel(folder, kind, s)
	nextPickupId += 1
	local m = Instance.new("Model")
	m.Name = kind
	m:SetAttribute("Id", nextPickupId)
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Stage", s)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = folder
	return m
end

local function buildPickups(folder, s)
	local st = Config.Stages[s]
	local x0 = Config.LAUNCH_X + (s - 1) * L
	local rng = Random.new(s * 3571)
	local function spot(x)
		return Vector3.new(x, Config.pathY(x) + rng:NextNumber(Config.FLY_MIN_HEIGHT + 3, 42), rng:NextNumber(-HALF + 6, HALF - 6))
	end
	local first = s == 1 and 40 or 15
	-- Coins come in short lines you can steer into
	local made = 0
	while made < Config.Pickups.Coin.perStage do
		local base = spot(rng:NextNumber(x0 + first, x0 + L - 60))
		for i = 0, math.min(4, Config.Pickups.Coin.perStage - made - 1) do
			local m = pickupModel(folder, "Coin", s)
			local p = cyl(m, 0.6, 3.6, CFrame.new(base + Vector3.new(i * 9, 0, 0)), Color3.fromRGB(255, 205, 40), { CanCollide = false, CanQuery = false, CastShadow = false })
			cyl(m, 0.7, 2.2, p.CFrame, Color3.fromRGB(255, 240, 120), { CanCollide = false, CanQuery = false, CastShadow = false })
			m.PrimaryPart = p
			m:SetAttribute("Pos", p.Position)
			made += 1
		end
	end
	for _ = 1, Config.Pickups.Gem.perStage do
		local m = pickupModel(folder, "Gem", s)
		local p = newPart(m, { Size = Vector3.one * 2.6, CFrame = CFrame.new(spot(rng:NextNumber(x0 + first, x0 + L - 20))) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = Color3.fromRGB(90, 230, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		m.PrimaryPart = p
		m:SetAttribute("Pos", p.Position)
	end
	for _ = 1, Config.Pickups.Ring.perStage do
		local m = pickupModel(folder, "Ring", s)
		local center = spot(rng:NextNumber(x0 + first, x0 + L - 30))
		local hit = newPart(m, { Name = "Center", Size = Vector3.one, CFrame = CFrame.new(center), Transparency = 1, CanCollide = false, CanQuery = false })
		m.PrimaryPart = hit
		m:SetAttribute("Pos", center)
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			newPart(m, { Size = Vector3.new(1, 1.2, 4), CFrame = CFrame.new(center) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 7, 0), Color = i % 2 == 0 and Color3.fromRGB(255, 170, 30) or Color3.fromRGB(255, 240, 90), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false })
		end
	end
	for _ = 1, (st.zone == "Earth" and 0 or Config.Pickups.Obstacle.perStage) do -- no birds on Earth
		local m = pickupModel(folder, "Obstacle", s)
		local c = spot(rng:NextNumber(x0 + first + 30, x0 + L - 30))
		local core
		if st.zone == "Earth" then -- a chunky cartoon bird
			core = newPart(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 4, CFrame = CFrame.new(c), Color = Color3.fromRGB(240, 240, 245), CanCollide = false })
			newPart(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.6, CFrame = CFrame.new(c + Vector3.new(-2.4, 1.2, 0)), Color = Color3.fromRGB(240, 240, 245), CanCollide = false })
			newPart(m, { Size = Vector3.new(1.2, 0.6, 0.6), CFrame = CFrame.new(c + Vector3.new(-3.9, 1.1, 0)), Color = Color3.fromRGB(255, 160, 30), CanCollide = false })
			for _, side in ipairs({ -1, 1 }) do
				newPart(m, { Size = Vector3.new(2.6, 0.4, 5), CFrame = CFrame.new(c + Vector3.new(0.3, 0.8, side * 3.2)) * CFrame.Angles(side * 0.35, 0, 0), Color = Color3.fromRGB(200, 200, 210), CanCollide = false })
			end
		elseif st.zone == "Sky" then -- an angry storm cloud
			core = newPart(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 7, CFrame = CFrame.new(c), Color = Color3.fromRGB(80, 80, 100), CanCollide = false })
			for _, off in ipairs({ Vector3.new(0, 0.5, -4), Vector3.new(0, 0.5, 4), Vector3.new(0, 2.5, 0) }) do
				newPart(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 5.5, CFrame = CFrame.new(c + off), Color = Color3.fromRGB(95, 95, 115), CanCollide = false })
			end
			newPart(m, { Size = Vector3.new(0.6, 5, 0.6), CFrame = CFrame.new(c + Vector3.new(0, -4.5, 0)) * CFrame.Angles(0, 0, 0.4), Color = Color3.fromRGB(255, 240, 80), Material = Enum.Material.Neon, CanCollide = false })
		else -- an asteroid
			core = newPart(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 6, CFrame = CFrame.new(c), Color = Color3.fromRGB(130, 115, 105), Material = Enum.Material.Slate, CanCollide = false })
			newPart(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = CFrame.new(c + Vector3.new(-1.5, 2, 1)), Color = Color3.fromRGB(100, 90, 85), Material = Enum.Material.Slate, CanCollide = false })
		end
		core.Name = "Core"
		m.PrimaryPart = core
		m:SetAttribute("Pos", c)
	end
end

local function buildStage(world, s)
	local f = Instance.new("Folder")
	f.Name = string.format("Stage%02d", s)
	f.Parent = world
	Scenery.buildStage(f, s)
	buildPickups(world.Pickups, s)
end

function WorldBuilder.build()
	local old = workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
		local p = workspace:FindFirstChild(name)
		if p then
			p:Destroy()
		end
	end
	local world = Instance.new("Folder")
	world.Name = "World"
	nextPickupId = 0
	local pickups = Instance.new("Folder")
	pickups.Name = "Pickups"
	pickups.Parent = world
	buildHub(world)
	for s = 1, Config.NUM_STAGES do
		buildStage(world, s)
	end
	world.Parent = workspace
	pcall(function()
		workspace.StreamingEnabled = false -- small map; keep every pickup/gate loaded on the client
	end)
	return world
end

return WorldBuilder
