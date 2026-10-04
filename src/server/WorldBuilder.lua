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
local function buildHub(world)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world
	local c = Config.HUB_CENTER
	newPart(hub, { Name = "HubGround", Size = Vector3.new(140, 4, 140), CFrame = CFrame.new(c + Vector3.new(0, -2, 0)), Color = Color3.fromRGB(100, 170, 80), Material = Enum.Material.Grass })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(c + Vector3.new(-45, 0.5, 0), c + Vector3.new(100, 0.5, 0))
	spawn.Color = Color3.fromRGB(80, 160, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = hub

	-- Launch pad at the start line
	local pad = newPart(hub, { Name = "LaunchPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 16, 16), CFrame = CFrame.new(Config.LAUNCH_X - 8, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 140, 30), Material = Enum.Material.Neon })
	pad.CanCollide = true
	newPart(hub, { Name = "StartLine", Size = Vector3.new(2, 0.3, HALF * 2 + 10), CFrame = CFrame.new(Config.LAUNCH_X, 0.15, 0), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })

	local board = newPart(hub, { Name = "TitleSign", Size = Vector3.new(1, 18, 44), CFrame = CFrame.new(c + Vector3.new(30, 14, -60)) * CFrame.Angles(0, math.rad(-35), 0), Color = Color3.fromRGB(30, 30, 45) })
	sign(board, Enum.NormalId.Left, "ROCKET SIMULATOR\nEquip your rocket and click to launch!", Color3.fromRGB(255, 210, 60))
	newPart(hub, { Size = Vector3.new(1.5, 6, 1.5), CFrame = CFrame.new(c + Vector3.new(30, 2.5, -60)), Color = Color3.fromRGB(60, 60, 70) })
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
	buildHub(world)
	for s = 1, Config.NUM_STAGES do
		buildStage(world, s)
	end
	world.Parent = workspace
	return world
end

return WorldBuilder
