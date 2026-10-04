-- Builds the map from Config: hub, launch pad, 30 stages, gates, distance signs, decor.
-- Everything goes into Workspace.World. Safe to run again: it rebuilds from scratch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

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

local function darker(c, f)
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

-- Decor ------------------------------------------------------------------------------
local Decor = {}

function Decor.tree(f, pos, rng, color)
	local h = rng:NextNumber(7, 12)
	newPart(f, { Size = Vector3.new(1.6, h, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
	newPart(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(7, 11), CFrame = CFrame.new(pos + Vector3.new(0, h + 2, 0)), Color = darker(color, 0.75), Material = Enum.Material.Grass })
end

function Decor.hay(f, pos, rng)
	newPart(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 5, 5), CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(230, 200, 90), Material = Enum.Material.Fabric })
end

function Decor.cactus(f, pos, rng)
	local h = rng:NextNumber(8, 14)
	local c = Color3.fromRGB(70, 150, 70)
	newPart(f, { Size = Vector3.new(2, h, 2), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color = c })
	newPart(f, { Size = Vector3.new(3, 1.6, 1.6), CFrame = CFrame.new(pos + Vector3.new(1.8, h * 0.55, 0)), Color = c })
	newPart(f, { Size = Vector3.new(1.6, 4, 1.6), CFrame = CFrame.new(pos + Vector3.new(3, h * 0.55 + 2, 0)), Color = c })
end

function Decor.rock(f, pos, rng, color)
	local s = rng:NextNumber(4, 12)
	newPart(f, { Size = Vector3.new(s, s * 0.7, s * 0.9), CFrame = CFrame.new(pos + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Color = darker(color, 0.7), Material = Enum.Material.Slate })
end

function Decor.palm(f, pos, rng)
	local h = rng:NextNumber(12, 18)
	newPart(f, { Size = Vector3.new(1.4, h, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, 0.12), Color = Color3.fromRGB(140, 100, 60), Material = Enum.Material.Wood })
	for i = 1, 4 do
		newPart(f, { Size = Vector3.new(9, 0.4, 2.5), CFrame = CFrame.new(pos + Vector3.new(0, h, 0)) * CFrame.Angles(0, i * math.pi / 2, -0.3) * CFrame.new(4, 0, 0), Color = Color3.fromRGB(50, 150, 60), Material = Enum.Material.Grass })
	end
end

function Decor.pine(f, pos, rng)
	local green = Color3.fromRGB(40, 100, 60)
	newPart(f, { Size = Vector3.new(1.4, 4, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)), Color = Color3.fromRGB(100, 70, 40), Material = Enum.Material.Wood })
	for i = 0, 2 do
		local w = 8 - i * 2.4
		newPart(f, { Size = Vector3.new(w, 3, w), CFrame = CFrame.new(pos + Vector3.new(0, 5 + i * 3, 0)) * CFrame.Angles(0, math.rad(45 * i), 0), Color = i == 2 and Color3.new(1, 1, 1) or green, Material = Enum.Material.Grass })
	end
end

function Decor.crystal(f, pos, rng, color)
	for _ = 1, 3 do
		local h = rng:NextNumber(5, 12)
		newPart(f, { Size = Vector3.new(2, h, 2), CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-3, 3), h / 2, rng:NextNumber(-3, 3))) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Material = Enum.Material.Neon, Transparency = 0.2 })
	end
end

function Decor.lava(f, pos, rng)
	local s = rng:NextNumber(10, 18)
	newPart(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, s, s), CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 100, 20), Material = Enum.Material.Neon })
	Decor.rock(f, pos + Vector3.new(s / 2, 0, 0), rng, Color3.fromRGB(70, 60, 60))
end

function Decor.cloud(f, pos, rng, color)
	local base = pos + Vector3.new(0, rng:NextNumber(-25, 50), 0)
	for _ = 1, 4 do
		newPart(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(10, 20), CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-3, 3), rng:NextNumber(-6, 6))), Color = color:Lerp(Color3.new(1, 1, 1), 0.6), Material = Enum.Material.SmoothPlastic, CanCollide = false, Transparency = 0.15 })
	end
end

function Decor.rainbow(f, pos, rng)
	local colors = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 160, 50), Color3.fromRGB(255, 230, 60), Color3.fromRGB(80, 220, 90), Color3.fromRGB(70, 150, 255), Color3.fromRGB(170, 90, 255) }
	for i, c in ipairs(colors) do
		local r = 30 - i * 2
		for a = 0, 8 do
			local ang = a / 8 * math.pi
			newPart(f, { Size = Vector3.new(2, 2, 9), CFrame = CFrame.new(pos + Vector3.new(0, math.sin(ang) * r, math.cos(ang) * r)) * CFrame.Angles(ang, 0, 0), Color = c, Material = Enum.Material.Neon, CanCollide = false })
		end
	end
end

function Decor.storm(f, pos, rng)
	Decor.cloud(f, pos, rng, Color3.fromRGB(60, 60, 75))
	newPart(f, { Size = Vector3.new(1, 18, 1), CFrame = CFrame.new(pos + Vector3.new(0, rng:NextNumber(-10, 10), 0)) * CFrame.Angles(0, 0, 0.4), Color = Color3.fromRGB(255, 240, 90), Material = Enum.Material.Neon, CanCollide = false })
end

function Decor.island(f, pos, rng)
	local base = pos + Vector3.new(0, rng:NextNumber(-20, 30), 0)
	newPart(f, { Size = Vector3.new(16, 6, 16), CFrame = CFrame.new(base), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.Ground })
	newPart(f, { Size = Vector3.new(16, 1, 16), CFrame = CFrame.new(base + Vector3.new(0, 3.5, 0)), Color = Color3.fromRGB(90, 180, 80), Material = Enum.Material.Grass })
	Decor.tree(f, base + Vector3.new(0, 4, 0), rng, Color3.fromRGB(90, 180, 80))
end

function Decor.star(f, pos, rng)
	for _ = 1, 3 do
		newPart(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(1, 3), CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-30, 90), rng:NextNumber(-20, 20))), Color = Color3.fromRGB(255, 250, 200), Material = Enum.Material.Neon, CanCollide = false })
	end
end

function Decor.asteroid(f, pos, rng, color)
	local s = rng:NextNumber(6, 20)
	newPart(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * s, CFrame = CFrame.new(pos + Vector3.new(0, rng:NextNumber(-30, 60), 0)), Color = darker(color, rng:NextNumber(0.5, 0.9)), Material = Enum.Material.Slate })
end

function Decor.planet(f, pos, rng, color)
	local s = rng:NextNumber(60, 140)
	local side = pos.Z >= 0 and 1 or -1
	local c = Vector3.new(pos.X, pos.Y + rng:NextNumber(0, 120), side * rng:NextNumber(220, 380))
	newPart(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * s, CFrame = CFrame.new(c), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false })
	if rng:NextNumber() < 0.5 then
		newPart(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, s * 1.8, s * 1.8), CFrame = CFrame.new(c) * CFrame.Angles(0.3, 0, math.pi / 2 + 0.2), Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Material = Enum.Material.SmoothPlastic, Transparency = 0.3, CanCollide = false })
	end
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

-- A cartoon building with an open door, awning, sign and a prompt that opens a shop window.
local function building(parent, name, center, doorDir, color, title, windowName)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	local face = CFrame.lookAt(center, center + Vector3.new(0, 0, doorDir)) -- -Z of this frame = door side
	local function at(x, y, z)
		return face * CFrame.new(x, y, z)
	end
	local W, H, D = 34, 16, 24
	local wall = color:Lerp(Color3.new(1, 1, 1), 0.15)
	newPart(m, { Name = "Floor", Size = Vector3.new(W, 0.6, D), CFrame = at(0, 0.3, 0), Color = Color3.fromRGB(240, 240, 245) })
	newPart(m, { Size = Vector3.new(W, H, 1.2), CFrame = at(0, H / 2, D / 2), Color = wall })
	newPart(m, { Size = Vector3.new(1.2, H, D), CFrame = at(-W / 2, H / 2, 0), Color = wall })
	newPart(m, { Size = Vector3.new(1.2, H, D), CFrame = at(W / 2, H / 2, 0), Color = wall })
	newPart(m, { Size = Vector3.new(12, H, 1.2), CFrame = at(-11, H / 2, -D / 2), Color = wall })
	newPart(m, { Size = Vector3.new(12, H, 1.2), CFrame = at(11, H / 2, -D / 2), Color = wall })
	newPart(m, { Size = Vector3.new(10, 5, 1.2), CFrame = at(0, H - 2.5, -D / 2), Color = wall })
	newPart(m, { Name = "Roof", Size = Vector3.new(W + 3, 1.6, D + 3), CFrame = at(0, H + 0.8, 0), Color = color })
	cyl(m, W + 3, 2.4, at(0, H + 0.8, -D / 2 - 1.5), Color3.new(1, 1, 1))
	-- striped awning over the door
	for i = 0, 5 do
		local stripe = newPart(m, { Size = Vector3.new(2, 0.4, 5), CFrame = at(-5 + i * 2, 10.5, -D / 2 - 2.3) * CFrame.Angles(math.rad(-25), 0, 0), Color = i % 2 == 0 and color or Color3.new(1, 1, 1) })
		stripe.CastShadow = false
	end
	local signPart = newPart(m, { Name = "Sign", Size = Vector3.new(24, 6, 0.8), CFrame = at(0, H + 5, -D / 2 - 0.5), Color = Color3.fromRGB(255, 255, 255) })
	local label = sign(signPart, Enum.NormalId.Front, title, color, Color3.fromRGB(255, 255, 255))
	label.TextColor3 = color
	-- pedestals inside for display rockets
	for i = -1, 1 do
		cyl(m, 2, 6, at(i * 9, 1, 4) * UP, Color3.fromRGB(255, 255, 255), { Name = "Pedestal" })
	end
	local door = newPart(m, { Name = "Door", Size = Vector3.new(10, 10, 1), CFrame = at(0, 5, -D / 2 - 1), Transparency = 1, CanCollide = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenWindow", windowName)
	prompt.Parent = door
	return m
end

-- Leaderboard frame; ExtrasServer fills in the rows.
local function leaderboard(parent, name, cf, title, color)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	for _, side in ipairs({ -1, 1 }) do
		cyl(m, 22, 1.6, cf * CFrame.new(0, -14, side * 11) * UP, Color3.fromRGB(80, 80, 100))
	end
	local board = newPart(m, { Name = "Board", Size = Vector3.new(1.2, 30, 24), CFrame = cf * CFrame.new(0, 3, 0), Color = color })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = color
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.15))
	grad.Rotation = 90
	grad.Parent = bg
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.05, 0.02)
	t.Size = UDim2.fromScale(0.9, 0.11)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = title
	t.Parent = bg
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Parent = t
	local sub = t:Clone()
	sub.Name = "Subtitle"
	sub.Position = UDim2.fromScale(0.1, 0.13)
	sub.Size = UDim2.fromScale(0.8, 0.05)
	sub.Text = "Loading..."
	sub.Parent = bg
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0.05, 0.2)
	rows.Size = UDim2.fromScale(0.9, 0.77)
	rows.Parent = bg
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0.006, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rows
	return m
end

local function buildHub(world)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world
	local c = Config.HUB_CENTER
	local padX = Config.LAUNCH_X - 8

	-- Ground: grass field with a big concrete launch plaza on top
	newPart(hub, { Name = "Grass", Size = Vector3.new(260, 4, 320), CFrame = CFrame.new(-130, -2, 0), Color = Color3.fromRGB(110, 200, 90), Material = Enum.Material.Grass })
	newPart(hub, { Name = "PlazaTrim", Size = Vector3.new(182, 0.3, 172), CFrame = CFrame.new(c.X, 0.15, 0), Color = Color3.fromRGB(120, 180, 255) })
	newPart(hub, { Name = "Plaza", Size = Vector3.new(180, 0.4, 170), CFrame = CFrame.new(c.X, 0.2, 0), Color = Color3.fromRGB(232, 234, 240) })
	newPart(hub, { Name = "Walkway", Size = Vector3.new(140, 0.1, 10), CFrame = CFrame.new(-80, 0.45, 0), Color = Color3.fromRGB(90, 160, 255) })
	for i = 0, 13 do
		newPart(hub, { Size = Vector3.new(4, 0.12, 1.2), CFrame = CFrame.new(-145 + i * 10, 0.5, 0), Color = Color3.new(1, 1, 1) })
	end

	-- Spawn under a big title arch
	local spawnPos = c + Vector3.new(-55, 0.5, 0)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.6, 12)
	spawn.CFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.xAxis)
	spawn.Color = Color3.fromRGB(255, 200, 60)
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub
	for _, side in ipairs({ -1, 1 }) do
		cyl(hub, 24, 3.4, CFrame.new(spawnPos + Vector3.new(22, 12, side * 17)) * UP, Color3.fromRGB(255, 90, 90))
		newPart(hub, { Shape = Enum.PartType.Ball, Size = Vector3.one * 5, CFrame = CFrame.new(spawnPos + Vector3.new(22, 25, side * 17)), Color = Color3.fromRGB(255, 220, 60) })
	end
	local banner = newPart(hub, { Name = "TitleBanner", Size = Vector3.new(2, 8, 38), CFrame = CFrame.new(spawnPos + Vector3.new(22, 21, 0)), Color = Color3.fromRGB(70, 130, 255) })
	for _, faceId in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
		local l = sign(banner, faceId, "ROCKET SIMULATOR", Color3.fromRGB(255, 230, 80), Color3.fromRGB(70, 130, 255))
		l.Parent.PixelsPerStud = 20
	end

	-- Launch pad: round platform with a hazard-stripe ring
	cyl(hub, 1.2, 24, CFrame.new(padX, 0.6, 0) * UP, Color3.fromRGB(150, 155, 170), { Name = "LaunchPad" })
	cyl(hub, 1.3, 14, CFrame.new(padX, 0.65, 0) * UP, Color3.fromRGB(255, 140, 30), { Name = "PadCenter", Material = Enum.Material.Neon })
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		newPart(hub, { Size = Vector3.new(4, 1.4, 1.4), CFrame = CFrame.new(padX, 0.7, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 11.4), Color = i % 2 == 0 and Color3.fromRGB(255, 210, 40) or Color3.fromRGB(40, 40, 45) })
	end
	newPart(hub, { Name = "StartLine", Size = Vector3.new(2, 0.3, HALF * 2 + 10), CFrame = CFrame.new(Config.LAUNCH_X + 4, 0.15, 0), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })

	-- Launch tower (red/white truss) beside the pad with a gantry arm
	local towerC = Vector3.new(padX, 0, -17)
	local TH = 48
	for _, dx in ipairs({ -3, 3 }) do
		for _, dz in ipairs({ -3, 3 }) do
			newPart(hub, { Size = Vector3.new(1.2, TH, 1.2), CFrame = CFrame.new(towerC + Vector3.new(dx, TH / 2, dz)), Color = Color3.fromRGB(230, 60, 60), Material = Enum.Material.Metal })
		end
	end
	for y = 4, TH, 6 do
		local col = (y / 6) % 2 < 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(230, 60, 60)
		newPart(hub, { Size = Vector3.new(7.2, 0.8, 0.8), CFrame = CFrame.new(towerC + Vector3.new(0, y, -3)), Color = col })
		newPart(hub, { Size = Vector3.new(7.2, 0.8, 0.8), CFrame = CFrame.new(towerC + Vector3.new(0, y, 3)), Color = col })
		newPart(hub, { Size = Vector3.new(0.8, 0.8, 7.2), CFrame = CFrame.new(towerC + Vector3.new(-3, y, 0)), Color = col })
		newPart(hub, { Size = Vector3.new(0.8, 0.8, 7.2), CFrame = CFrame.new(towerC + Vector3.new(3, y, 0)), Color = col })
	end
	newPart(hub, { Size = Vector3.new(9, 1, 9), CFrame = CFrame.new(towerC + Vector3.new(0, TH + 0.5, 0)), Color = Color3.fromRGB(255, 255, 255) })
	newPart(hub, { Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(towerC + Vector3.new(0, TH + 2.5, 0)), Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon })
	newPart(hub, { Name = "Gantry", Size = Vector3.new(2, 1.4, 12), CFrame = CFrame.new(towerC + Vector3.new(0, 10, 8.5)), Color = Color3.fromRGB(255, 255, 255) })

	-- Fuel tanks with pipes to the pad
	for i, spot in ipairs({ Vector3.new(-30, 0, 44), Vector3.new(-46, 0, 52), Vector3.new(-16, 0, 54) }) do
		local h = 22 + i * 3
		cyl(hub, h, 12, CFrame.new(spot + Vector3.new(0, h / 2, 0)) * UP, Color3.fromRGB(250, 250, 255))
		cyl(hub, 3, 12.4, CFrame.new(spot + Vector3.new(0, h * 0.6, 0)) * UP, Color3.fromRGB(255, 80, 80))
		newPart(hub, { Shape = Enum.PartType.Ball, Size = Vector3.one * 12, CFrame = CFrame.new(spot + Vector3.new(0, h, 0)), Color = Color3.fromRGB(80, 150, 255) })
		local from, to = spot + Vector3.new(0, 1.2, 0), Vector3.new(padX, 1.2, 9)
		newPart(hub, { Size = Vector3.new(1.2, 1.2, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2, to), Color = Color3.fromRGB(170, 175, 190), Material = Enum.Material.Metal })
	end

	-- Big mission screen facing the plaza
	local screenCF = CFrame.new(-34, 20, -48) * CFrame.Angles(0, math.rad(-35), 0)
	newPart(hub, { Size = Vector3.new(2, 20, 2), CFrame = screenCF * CFrame.new(0, -12, 0), Color = Color3.fromRGB(80, 80, 100) })
	local screen = newPart(hub, { Name = "MissionScreen", Size = Vector3.new(1.4, 14, 26), CFrame = screenCF, Color = Color3.fromRGB(30, 30, 50) })
	local scr = sign(screen, Enum.NormalId.Left, "READY FOR LAUNCH!\nCollect coins, fly through rings,\ndodge obstacles!", Color3.fromRGB(120, 255, 160), Color3.fromRGB(20, 30, 60))
	scr.Name = "ScreenText"

	-- Shops
	building(hub, "RocketShop", c + Vector3.new(-15, 0, -62), 1, Color3.fromRGB(70, 140, 255), "ROCKET SHOP", "Rockets")
	building(hub, "UpgradeLab", c + Vector3.new(-15, 0, 62), -1, Color3.fromRGB(170, 80, 240), "UPGRADE LAB", "Upgrades")

	-- Leaderboards behind spawn, angled toward the plaza
	leaderboard(hub, "RichestBoard", CFrame.new(c + Vector3.new(-78, 17, -30)) * CFrame.Angles(0, math.rad(-20), 0), "RICHEST", Color3.fromRGB(60, 190, 90))
	leaderboard(hub, "DonorBoard", CFrame.new(c + Vector3.new(-78, 17, 30)) * CFrame.Angles(0, math.rad(20), 0), "TOP DONATORS", Color3.fromRGB(255, 110, 170))

	-- Decor: round trees, flags, lamps, cones
	local rng = Random.new(42)
	for _ = 1, 26 do
		local x, z
		repeat
			x = rng:NextNumber(-255, -5)
			z = rng:NextNumber(-155, 155)
		until math.abs(z) > 90 or x < -188
		Decor.tree(hub, Vector3.new(x, 0, z), rng, Color3.fromRGB(110, 210, 90))
	end
	local flagColors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 50), Color3.fromRGB(80, 200, 120), Color3.fromRGB(80, 150, 255), Color3.fromRGB(200, 100, 255) }
	for i = 0, 7 do
		for _, side in ipairs({ -1, 1 }) do
			local base = Vector3.new(-175 + i * 22, 0, side * 82)
			cyl(hub, 14, 0.6, CFrame.new(base + Vector3.new(0, 7, 0)) * UP, Color3.fromRGB(230, 230, 235))
			newPart(hub, { Size = Vector3.new(5, 3, 0.2), CFrame = CFrame.new(base + Vector3.new(2.6, 12.5, 0)), Color = flagColors[(i % #flagColors) + 1] })
		end
	end
	for i = 0, 5 do
		for _, side in ipairs({ -1, 1 }) do
			local p = Vector3.new(-140 + i * 24, 0, side * 9)
			cyl(hub, 9, 0.7, CFrame.new(p + Vector3.new(0, 4.5, 0)) * UP, Color3.fromRGB(60, 60, 80))
			newPart(hub, { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = CFrame.new(p + Vector3.new(0, 9.4, 0)), Color = Color3.fromRGB(255, 240, 180), Material = Enum.Material.Neon })
		end
	end
	for _, z in ipairs({ -14, 14 }) do
		for i = 0, 2 do
			local p = Vector3.new(padX - 16 + i * 5, 0, z)
			cyl(hub, 2.2, 1.6, CFrame.new(p + Vector3.new(0, 1.1, 0)) * UP, Color3.fromRGB(255, 120, 30))
			cyl(hub, 0.5, 1.7, CFrame.new(p + Vector3.new(0, 1.4, 0)) * UP, Color3.new(1, 1, 1))
		end
	end
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
	for _ = 1, Config.Pickups.Obstacle.perStage do
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
	local st = Config.Stages[s]
	local f = Instance.new("Folder")
	f.Name = string.format("Stage%02d", s)
	f.Parent = world
	local x0 = Config.LAUNCH_X + (s - 1) * L
	local x1 = x0 + L
	local y0, y1 = Config.pathY(x0), Config.pathY(x1)
	local a, b = Vector3.new(x0, y0, 0), Vector3.new(x1, y1, 0)
	local mid = (a + b) / 2
	local laneCF = CFrame.lookAt(mid, b)
	local zoneColor = st.zone == "Earth" and Color3.fromRGB(255, 200, 60) or (st.zone == "Sky" and Color3.fromRGB(120, 220, 255) or Color3.fromRGB(200, 120, 255))

	if st.zone == "Earth" then
		local mat = ({ cactus = Enum.Material.Sand, pine = Enum.Material.Snow, crystal = Enum.Material.Ice, lava = Enum.Material.Basalt, rock = Enum.Material.Rock })[st.decor] or Enum.Material.Grass
		newPart(f, { Name = "Ground", Size = Vector3.new(L, 4, 300), CFrame = CFrame.new(mid + Vector3.new(0, -2, 0)), Color = st.ground, Material = mat })
		newPart(f, { Name = "Lane", Size = Vector3.new(L, 0.2, HALF * 2 + 6), CFrame = CFrame.new(mid + Vector3.new(0, 0.1, 0)), Color = st.ground:Lerp(Color3.new(1, 1, 1), 0.25), Material = mat })
		-- Low-poly mountain ranges on both sides (tilted blocks half-buried = jagged peaks)
		local mrng = Random.new(s * 104729)
		local snowy = st.decor == "pine" or st.decor == "crystal" or st.decor == "rock"
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 5 do
				local size = mrng:NextNumber(45, 95)
				local x = x0 + (i + mrng:NextNumber(0.1, 0.9)) * (L / 6)
				local z = side * mrng:NextNumber(150, 195)
				local cf = CFrame.new(x, -size * 0.15, z) * CFrame.Angles(math.rad(45), mrng:NextNumber(0, 6.28), math.rad(mrng:NextNumber(30, 55)))
				newPart(f, { Name = "Mountain", Size = Vector3.one * size, CFrame = cf, Color = darker(st.ground, mrng:NextNumber(0.45, 0.65)), Material = Enum.Material.Rock, CastShadow = false })
				if snowy then
					-- Same-shaped smaller block sharing the mountain's highest corner = snow cap
					local top, topY = nil, -math.huge
					for _, c in ipairs({ -1, 1 }) do
						for _, d in ipairs({ -1, 1 }) do
							for _, e in ipairs({ -1, 1 }) do
								local corner = Vector3.new(c, d, e) * size / 2
								local y = (cf * corner).Y
								if y > topY then
									top, topY = corner, y
								end
							end
						end
					end
					local k = 0.35
					newPart(f, { Name = "SnowCap", Size = Vector3.one * size * k + Vector3.one * 0.4, CFrame = cf * CFrame.new(top * (1 - k)), Color = Color3.fromRGB(245, 248, 255), Material = Enum.Material.Snow, CastShadow = false })
				end
			end
		end
	elseif st.zone == "Sky" then
		newPart(f, { Name = "Lane", Size = Vector3.new(HALF * 2 + 20, 3, (b - a).Magnitude), CFrame = laneCF * CFrame.new(0, -1.5, 0), Color = st.ground, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	else
		newPart(f, { Name = "Lane", Size = Vector3.new(HALF * 2 + 6, 0.5, (b - a).Magnitude), CFrame = laneCF * CFrame.new(0, -0.25, 0), Color = st.ground, Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })
	end
	for _, side in ipairs({ -1, 1 }) do
		newPart(f, { Name = "Rail", Size = Vector3.new(0.8, 0.8, (b - a).Magnitude), CFrame = laneCF * CFrame.new(side * (HALF + 3), 0.5, 0), Color = zoneColor, Material = Enum.Material.Neon, CanCollide = false })
	end

	-- Distance signs every 100 studs
	for d = 100, L - 1, 100 do
		local x = x0 + d
		local y = Config.pathY(x)
		local z = -(HALF + 9)
		newPart(f, { Size = Vector3.new(1, 7, 1), CFrame = CFrame.new(x, y + 3.5, z), Color = Color3.fromRGB(60, 60, 70) })
		local board = newPart(f, { Size = Vector3.new(0.5, 4, 9), CFrame = CFrame.new(x, y + 8, z), Color = Color3.fromRGB(30, 30, 45) })
		sign(board, Enum.NormalId.Left, Config.meters(x - Config.LAUNCH_X), Color3.new(1, 1, 1))
	end

	-- Decor on both sides of the lane
	local rng = Random.new(s * 7919)
	local decorFn = Decor[st.decor] or Decor.rock
	for _ = 1, 12 do
		local x = rng:NextNumber(x0 + 15, x1 - 15)
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local z = side * rng:NextNumber(HALF + 18, 120)
		decorFn(f, Vector3.new(x, Config.pathY(x), z), rng, st.ground)
	end

	buildPickups(world.Pickups, s)

	-- Gate into the next stage
	if s < Config.NUM_STAGES then
		local nextStage = Config.Stages[s + 1]
		local g = Instance.new("Model")
		g.Name = "Gate"
		g:SetAttribute("Stage", s + 1)
		g.Parent = f
		local base = y1
		local h = Config.FLY_MAX_HEIGHT + 20
		local w = HALF + 7
		for _, side in ipairs({ -1, 1 }) do
			newPart(g, { Name = "Pillar", Size = Vector3.new(4, h, 4), CFrame = CFrame.new(x1, base + h / 2, side * w), Color = Color3.fromRGB(50, 50, 65), Material = Enum.Material.Metal })
		end
		local beam = newPart(g, { Name = "Beam", Size = Vector3.new(4, 8, w * 2 + 4), CFrame = CFrame.new(x1, base + h, 0), Color = Color3.fromRGB(35, 35, 50), Material = Enum.Material.Metal })
		sign(beam, Enum.NormalId.Left, "STAGE " .. (s + 1) .. " - " .. nextStage.name, zoneColor)
		local barrier = newPart(g, { Name = "Barrier", Size = Vector3.new(1, h - 4, w * 2 - 4), CFrame = CFrame.new(x1, base + (h - 4) / 2, 0), Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = false })
		local lock = sign(barrier, Enum.NormalId.Left, "LOCKED\nStage " .. (s + 1) .. "\nCost: " .. Config.abbreviate(Config.stageCost(s + 1)), Color3.fromRGB(255, 230, 230))
		lock.Name = "LockText"
		lock.Size = UDim2.fromScale(0.6, 0.35)
		lock.Position = UDim2.fromScale(0.2, 0.3)
	end
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
