-- The starting area: a cartoon space-center park.
--   spawn plaza -> flower avenue + entrance arch -> shuttle statue fountain -> launch apron
--   Rocket Shop hangar (north) and Upgrade Lab dome (south) open onto the statue plaza.
-- Animated bits are tagged for LobbyClient: LobbySpin / LobbyBob / LobbyBlink / MiniPad.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local RocketModel = require(ReplicatedStorage.Shared.RocketModel)
local Kit = require(ServerScriptService.BuildKit)
local Scenery = require(ServerScriptService.Scenery)

local part, ball, cyl, column, beam, sign = Kit.part, Kit.ball, Kit.cyl, Kit.column, Kit.beam, Kit.sign
local darker, lighter = Kit.darker, Kit.lighter
local UP = Kit.UP
local C = Color3.fromRGB
local M = Enum.Material

local Lobby = {}

local WHITE = C(255, 255, 255)
local CREAM = C(250, 244, 230)
local STONE = C(225, 228, 238)
local BLUE = C(70, 140, 255)
local PURPLE = C(170, 80, 240)
local ORANGE = C(255, 150, 40)
local YELLOW = C(255, 210, 50)
local PINK = C(255, 110, 170)
local GREEN = C(90, 190, 90)
local FLOWERS = { C(255, 120, 180), YELLOW, WHITE, C(255, 90, 90), C(190, 120, 255) }

local SPAWN = Vector3.new(-150, 0, 0)
local PLAZA = Vector3.new(-80, 0, 0)
local PAD_X = Config.LAUNCH_X - 8

local function tag(inst, name)
	CollectionService:AddTag(inst, name)
	return inst
end

-- A flat disc lying on the ground (y = top surface height).
local function disc(parent, diameter, center, top, color, props)
	local t = { Material = M.SmoothPlastic, CastShadow = false }
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return cyl(parent, 0.3, diameter, CFrame.new(center.X, top - 0.15, center.Z) * UP, color, t)
end

local function flowerBed(parent, pos, rng)
	part(parent, { Size = Vector3.new(4, 1.4, 4), CFrame = CFrame.new(pos + Vector3.new(0, 0.7, 0)), Color = C(160, 110, 70), Material = M.WoodPlanks })
	part(parent, { Size = Vector3.new(3.4, 0.4, 3.4), CFrame = CFrame.new(pos + Vector3.new(0, 1.45, 0)), Color = C(110, 80, 50), Material = M.Ground })
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		ball(parent, rng:NextNumber(0.9, 1.3), pos + Vector3.new(math.cos(a) * 1.1, 2, math.sin(a) * 1.1), FLOWERS[rng:NextInteger(1, #FLOWERS)], { CastShadow = false })
	end
	ball(parent, 2, pos + Vector3.new(0, 2.2, 0), GREEN, { Material = M.Grass })
end

local function lamp(parent, pos, bannerColor)
	column(parent, 11, 0.8, pos, C(60, 60, 80))
	cyl(parent, 1, 1.6, CFrame.new(pos + Vector3.new(0, 0.5, 0)) * UP, C(60, 60, 80))
	ball(parent, 2.4, pos + Vector3.new(0, 11.4, 0), C(255, 245, 215), { Material = M.Glass, Transparency = 0.2 })
	ball(parent, 0.9, pos + Vector3.new(0, 11.4, 0), C(255, 190, 110), { Material = M.Neon, CastShadow = false })
	if bannerColor then
		part(parent, { Size = Vector3.new(0.2, 4, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 7.5, 1.3)), Color = bannerColor, CastShadow = false })
		beam(parent, pos + Vector3.new(0, 9.5, 0), pos + Vector3.new(0, 9.5, 2.4), 0.25, C(60, 60, 80))
	end
end

local function bench(parent, pos, facing)
	local cf = CFrame.lookAt(pos, facing)
	local wood = C(170, 115, 70)
	part(parent, { Size = Vector3.new(6, 0.5, 2), CFrame = cf * CFrame.new(0, 1.6, 0), Color = wood, Material = M.WoodPlanks })
	part(parent, { Size = Vector3.new(6, 1.6, 0.4), CFrame = cf * CFrame.new(0, 2.6, 1) * CFrame.Angles(math.rad(-12), 0, 0), Color = wood, Material = M.WoodPlanks })
	for _, x in ipairs({ -2.4, 2.4 }) do
		part(parent, { Size = Vector3.new(0.4, 1.6, 1.8), CFrame = cf * CFrame.new(x, 0.8, 0), Color = C(60, 60, 80) })
	end
end

local function balloons(parent, pos, rng)
	local m = Instance.new("Model")
	m.Name = "Balloons"
	m.Parent = parent
	local anchor = pos + Vector3.new(0, 0.5, 0)
	part(m, { Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(anchor), Color = C(60, 60, 80) })
	for i = 1, 3 do
		local top = pos + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(11, 15), rng:NextNumber(-1.5, 1.5))
		ball(m, 3.2, top, FLOWERS[(i % #FLOWERS) + 1], { Reflectance = 0.1 })
		beam(m, anchor, top - Vector3.new(0, 1.6, 0), 0.1, WHITE, { CastShadow = false })
	end
	m:SetAttribute("Phase", rng:NextNumber(0, 6))
	tag(m, "LobbyBob")
end

-- Ground: lawn, spawn plaza, avenues, statue plaza, launch apron, hedges ------------------------
local function ground(hub, rng)
	part(hub, { Name = "Lawn", Size = Vector3.new(184, 0.3, 172), CFrame = CFrame.new(-95, 0.15, 0), Color = C(105, 200, 85), Material = M.Grass })

	-- spawn plaza: concentric rings
	disc(hub, 44, SPAWN, 0.45, STONE)
	disc(hub, 38, SPAWN, 0.5, BLUE)
	disc(hub, 32, SPAWN, 0.55, CREAM)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		part(hub, { Size = Vector3.new(1.2, 0.12, 9), CFrame = CFrame.new(SPAWN + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 10.5), Color = i % 2 == 0 and ORANGE or BLUE, CastShadow = false })
	end
	disc(hub, 16, SPAWN, 0.7, C(120, 230, 255), { Material = M.Neon })
	disc(hub, 13, SPAWN, 0.8, WHITE)

	-- avenue spawn -> statue plaza, and statue plaza -> launch apron
	local function avenue(x0, x1)
		local len, mid = x1 - x0, (x0 + x1) / 2
		part(hub, { Size = Vector3.new(len, 0.4, 18), CFrame = CFrame.new(mid, 0.4, 0), Color = STONE, CastShadow = false })
		for _, side in ipairs({ -1, 1 }) do
			part(hub, { Size = Vector3.new(len, 0.45, 1.4), CFrame = CFrame.new(mid, 0.42, side * 8.3), Color = ORANGE, CastShadow = false })
		end
		for x = x0 + 2, x1 - 4, 6 do
			part(hub, { Size = Vector3.new(3, 0.42, 3), CFrame = CFrame.new(x + 1.5, 0.43, 0) * CFrame.Angles(0, math.rad(45), 0), Color = CREAM, CastShadow = false })
		end
	end
	avenue(-131, -104)
	avenue(-56, -38)

	-- statue plaza: rings + star rays
	disc(hub, 56, PLAZA, 0.45, STONE)
	disc(hub, 50, PLAZA, 0.5, ORANGE)
	disc(hub, 46, PLAZA, 0.55, CREAM)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part(hub, { Size = Vector3.new(2, 0.12, 14), CFrame = CFrame.new(PLAZA + Vector3.new(0, 0.62, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 15), Color = BLUE, CastShadow = false })
	end

	-- side paths to the two buildings
	for _, side in ipairs({ -1, 1 }) do
		part(hub, { Size = Vector3.new(12, 0.4, 16), CFrame = CFrame.new(PLAZA.X, 0.4, side * 33), Color = STONE, CastShadow = false })
	end

	-- launch apron: dark concrete with hazard stripes along the edges
	local ax0, ax1, az = -40, 4, 32
	part(hub, { Name = "Apron", Size = Vector3.new(ax1 - ax0, 0.4, az * 2), CFrame = CFrame.new((ax0 + ax1) / 2, 0.4, 0), Color = C(88, 92, 110), CastShadow = false })
	for x = ax0, ax1 - 4, 4 do
		for _, side in ipairs({ -1, 1 }) do
			part(hub, { Size = Vector3.new(4, 0.45, 1.6), CFrame = CFrame.new(x + 2, 0.43, side * (az - 0.8)), Color = (x / 4) % 2 == 0 and YELLOW or C(40, 40, 45), CastShadow = false })
		end
	end

	-- hedges around the park (gaps at the launch side)
	for _, side in ipairs({ -1, 1 }) do
		part(hub, { Size = Vector3.new(170, 3.5, 3), CFrame = CFrame.new(-100, 1.75, side * 84), Color = C(70, 160, 70), Material = M.Grass })
	end
	part(hub, { Size = Vector3.new(3, 3.5, 168), CFrame = CFrame.new(-186, 1.75, 0), Color = C(70, 160, 70), Material = M.Grass })
	for i = 0, 7 do
		for _, side in ipairs({ -1, 1 }) do
			local base = Vector3.new(-175 + i * 22, 3.5, side * 84)
			column(hub, 12, 0.5, base, WHITE)
			part(hub, { Size = Vector3.new(4.5, 2.6, 0.2), CFrame = CFrame.new(base + Vector3.new(2.4, 10.5, 0)), Color = FLOWERS[(i % #FLOWERS) + 1], CastShadow = false })
		end
	end
end

-- Spawn: invisible SpawnLocation on the glowing pad, balloons, title arch ------------------------
local function spawnArea(hub, rng)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.lookAt(SPAWN + Vector3.new(0, 0.9, 0), SPAWN + Vector3.new(1, 0.9, 0))
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = hub
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		balloons(hub, SPAWN + Vector3.new(math.cos(a) * 20, 0, math.sin(a) * 20), rng)
	end

	-- entrance arch over the avenue
	local ax = -118
	for _, side in ipairs({ -1, 1 }) do
		local foot = Vector3.new(ax, 0, side * 12)
		column(hub, 22, 4.4, foot, WHITE)
		for i = 0, 3 do
			column(hub, 2.2, 4.7, foot + Vector3.new(0, 3 + i * 5, 0), i % 2 == 0 and ORANGE or BLUE)
		end
		column(hub, 1.5, 6, foot, darker(BLUE, 0.2))
		ball(hub, 5.5, foot + Vector3.new(0, 23.5, 0), YELLOW)
	end
	local banner = part(hub, { Name = "TitleBanner", Size = Vector3.new(2, 8, 30), CFrame = CFrame.new(ax, 19, 0), Color = BLUE })
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		local l = sign(banner, face, "ROCKET SIMULATOR", YELLOW, BLUE, darker(BLUE, 0.5))
		l.Parent.PixelsPerStud = 20
	end
	-- little rockets standing on top of the banner
	for _, z in ipairs({ -10, 0, 10 }) do
		local r = RocketModel.build(Config.getRocket(z == 0 and "Firework" or "Starter"), 0.45, false, CFrame.new(ax, 25.6, z) * CFrame.Angles(0, 0, math.pi / 2))
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		r.Parent = hub
	end
end

-- Statue plaza: giant shuttle on a pedestal in a fountain, benches, lamps ---------------------------
local function statuePlaza(hub, rng)
	-- fountain pool
	cyl(hub, 1.8, 30, CFrame.new(PLAZA + Vector3.new(0, 1.1, 0)) * UP, WHITE)
	cyl(hub, 1.9, 27, CFrame.new(PLAZA + Vector3.new(0, 1.15, 0)) * UP, C(80, 190, 255), { Material = M.Glass, Transparency = 0.25, Reflectance = 0.3 })
	-- pedestal
	column(hub, 7, 12, PLAZA, STONE)
	column(hub, 1.2, 13, PLAZA + Vector3.new(0, 6.4, 0), ORANGE)
	-- the shuttle, nose up
	local shuttle = RocketModel.build(Config.getRocket("Shuttle"), 5, false, CFrame.new(PLAZA + Vector3.new(0, 7.6 + 25, 0)) * CFrame.Angles(0, math.rad(90), math.pi / 2))
	shuttle.Name = "ShuttleStatue"
	for _, d in ipairs(shuttle:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = true
		elseif d:IsA("Fire") or d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	shuttle.Parent = hub
	-- fountain sprays around the pedestal
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local nozzle = part(hub, { Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(PLAZA + Vector3.new(math.cos(a) * 9.5, 2.2, math.sin(a) * 9.5)), Color = WHITE, Transparency = 1, CanCollide = false })
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(C(200, 240, 255), C(120, 200, 255))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.3) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(1, 1.4)
		e.Rate = 25
		e.Speed = NumberRange.new(14, 18)
		e.SpreadAngle = Vector2.new(8, 8)
		e.Acceleration = Vector3.new(0, -26, 0)
		e.Parent = nozzle
	end
	-- benches facing the statue, lamps around the ring
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + math.pi / 6
		local p = PLAZA + Vector3.new(math.cos(a) * 22, 0.6, math.sin(a) * 22)
		bench(hub, p, Vector3.new(PLAZA.X, 0.6, PLAZA.Z) + (p - PLAZA) * 2)
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		lamp(hub, PLAZA + Vector3.new(math.cos(a) * 27, 0.6, math.sin(a) * 27), FLOWERS[(i % #FLOWERS) + 1])
	end
	-- flower beds + lamps along the avenue
	for _, x in ipairs({ -128, -122, -112, -106 }) do -- (gap at -118 for the arch pillars)
		for _, side in ipairs({ -1, 1 }) do
			flowerBed(hub, Vector3.new(x, 0.3, side * 11.5), rng)
		end
	end
	for _, x in ipairs({ -125, -109, -52, -42 }) do
		for _, side in ipairs({ -1, 1 }) do
			lamp(hub, Vector3.new(x, 0.3, side * 10.5), side == 1 and ORANGE or BLUE)
		end
	end
end

-- Buildings -----------------------------------------------------------------------------------
local function prompt(parent, cf, title, windowName)
	local door = part(parent, { Name = "Door", Size = Vector3.new(12, 10, 1), CFrame = cf, Transparency = 1, CanCollide = false })
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Open"
	p.ObjectText = title
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = 16
	p.RequiresLineOfSight = false
	p:SetAttribute("OpenWindow", windowName)
	p.Parent = door
end

local function radarDish(parent, pos)
	local m = Instance.new("Model")
	m.Name = "Radar"
	m.Parent = parent
	column(m, 4, 1, pos, C(200, 200, 210))
	local head = pos + Vector3.new(0, 5, 0)
	cyl(m, 0.8, 7, CFrame.new(head) * CFrame.Angles(0, 0, math.rad(55)), WHITE)
	beam(m, head, head + Vector3.new(2.5, 2, 0), 0.3, C(200, 200, 210))
	ball(m, 0.9, head + Vector3.new(2.6, 2.1, 0), C(255, 80, 80), { Material = M.Neon })
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	m:SetAttribute("SpinSpeed", 1.2)
	tag(m, "LobbySpin")
end

-- Rocket Shop: a hangar with an arched roof and rockets on display inside (door faces the plaza).
local function rocketShop(hub)
	local center = Vector3.new(PLAZA.X, 0, -54)
	local face = CFrame.lookAt(center, center + Vector3.new(0, 0, 1)) -- local -Z = door side (toward plaza)
	local function at(x, y, z)
		return face * CFrame.new(x, y, z)
	end
	local m = Instance.new("Model")
	m.Name = "RocketShop"
	m.Parent = hub
	local W, D, H = 36, 26, 11
	local wall = lighter(BLUE, 0.1)
	part(m, { Name = "Floor", Size = Vector3.new(W, 0.6, D), CFrame = at(0, 0.5, 0), Color = C(235, 240, 250), Reflectance = 0.15 })
	part(m, { Size = Vector3.new(W, H, 1.2), CFrame = at(0, H / 2, D / 2), Color = wall })
	for _, sx in ipairs({ -1, 1 }) do
		part(m, { Size = Vector3.new(1.2, H, D), CFrame = at(sx * W / 2, H / 2, 0), Color = wall })
		part(m, { Size = Vector3.new(8, H, 1.2), CFrame = at(sx * (W / 2 - 4), H / 2, -D / 2), Color = wall })
		part(m, { Size = Vector3.new(0.4, 6, 4), CFrame = at(sx * (W / 2 + 0.3), 6, 0), Color = C(150, 220, 255), Material = M.Glass, Transparency = 0.3 })
	end
	part(m, { Size = Vector3.new(W - 16, 2, 1.2), CFrame = at(0, H - 1, -D / 2), Color = wall })
	-- arched roof made of curved slats (hollow inside)
	local R = W / 2 + 0.6
	for k = 0, 11 do
		local a1, a2 = k / 12 * math.pi, (k + 1) / 12 * math.pi
		local p1 = (at(math.cos(a1) * R, H + math.sin(a1) * R * 0.55, 0)).Position
		local p2 = (at(math.cos(a2) * R, H + math.sin(a2) * R * 0.55, 0)).Position
		local mid = (p1 + p2) / 2
		local across = p2 - p1
		-- slat: X along the curve, Z running front-to-back through the building
		part(m, { Size = Vector3.new(across.Magnitude + 0.4, 1.2, D + 3), CFrame = CFrame.fromMatrix(mid, across.Unit, face.LookVector:Cross(across.Unit).Unit), Color = k % 2 == 0 and BLUE or WHITE })
	end
	-- front + back arch faces (stacked strips so the curve reads from the plaza)
	for _, z in ipairs({ -D / 2 - 1.4, D / 2 + 1.4 }) do
		for i = 0, 4 do
			local y0 = i * (R * 0.55) / 5
			local half = R * math.sqrt(math.max(0, 1 - ((y0 + R * 0.11) / (R * 0.55)) ^ 2))
			part(m, { Size = Vector3.new(half * 2, R * 0.55 / 5 + 0.1, 1), CFrame = at(0, H + y0 + R * 0.055, z), Color = z < 0 and C(40, 60, 120) or wall })
		end
	end
	local signPart = part(m, { Name = "Sign", Size = Vector3.new(22, 5, 0.6), CFrame = at(0, H + 3.4, -D / 2 - 2.1), Color = WHITE })
	local l = sign(signPart, Enum.NormalId.Front, "🚀 ROCKET SHOP", BLUE, WHITE, darker(BLUE, 0.4))
	l.Parent.PixelsPerStud = 24
	-- neon trim around the doorway
	part(m, { Size = Vector3.new(W - 15, 0.6, 0.6), CFrame = at(0, H - 2.2, -D / 2 - 0.7), Color = C(120, 220, 255), Material = M.Neon, CastShadow = false })
	-- rockets on display inside, noses up
	for i, id in ipairs({ "Turbo", "Galaxy", "Shuttle" }) do
		local x = (i - 2) * 10
		column(m, 1.6, 6, (at(x, 0.8, 4)).Position, WHITE)
		column(m, 0.3, 6.4, (at(x, 2.3, 4)).Position, C(120, 220, 255), { Material = M.Neon })
		local r = RocketModel.build(Config.getRocket(id), 0.9, false, at(x, 7.3, 4) * CFrame.Angles(0, 0, math.pi / 2))
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		r.Parent = m
	end
	radarDish(m, (at(W / 2 - 5, H + R * 0.4, D / 2 - 5)).Position)
	prompt(m, at(0, 5, -D / 2 - 1), "ROCKET SHOP", "Rockets")
end

-- Upgrade Lab: a glass dome on a striped base, glowing tubes, blinking antenna (door faces the plaza).
local function upgradeLab(hub)
	local center = Vector3.new(PLAZA.X, 0, 56)
	local m = Instance.new("Model")
	m.Name = "UpgradeLab"
	m.Parent = hub
	column(m, 10, 32, center, WHITE)
	column(m, 2, 32.6, center + Vector3.new(0, 3, 0), PURPLE)
	column(m, 1, 32.6, center + Vector3.new(0, 7, 0), PINK)
	ball(m, 31, center + Vector3.new(0, 10, 0), C(200, 170, 255), { Material = M.Glass, Transparency = 0.25, Reflectance = 0.2 })
	ball(m, 6, center + Vector3.new(0, 12, 0), C(150, 255, 200), { Material = M.Neon })
	-- antenna
	column(m, 12, 0.8, center + Vector3.new(0, 24, 0), C(200, 200, 210))
	tag(ball(m, 1.6, center + Vector3.new(0, 36.5, 0), C(255, 60, 90), { Material = M.Neon }), "LobbyBlink")
	-- entrance porch toward the plaza (-Z)
	local porch = center + Vector3.new(0, 0, -17)
	part(m, { Size = Vector3.new(14, 10, 8), CFrame = CFrame.new(porch + Vector3.new(0, 5, 0)), Color = lighter(PURPLE, 0.2) })
	part(m, { Size = Vector3.new(8, 7, 0.4), CFrame = CFrame.new(porch + Vector3.new(0, 3.5, -4.1)), Color = C(40, 20, 70) })
	part(m, { Size = Vector3.new(8.6, 0.5, 0.5), CFrame = CFrame.new(porch + Vector3.new(0, 7.2, -4.3)), Color = C(150, 255, 200), Material = M.Neon, CastShadow = false })
	local signPart = part(m, { Name = "Sign", Size = Vector3.new(20, 4.5, 0.6), CFrame = CFrame.new(porch + Vector3.new(0, 12.6, -2)), Color = WHITE })
	local l = sign(signPart, Enum.NormalId.Front, "⬆️ UPGRADE LAB", PURPLE, WHITE, darker(PURPLE, 0.4))
	l.Parent.PixelsPerStud = 24
	-- glowing tubes
	for i, col in ipairs({ C(120, 255, 170), C(120, 220, 255), C(255, 120, 220) }) do
		local p = center + Vector3.new(-14 + (i - 1) * 14, 0, -14 + (i == 2 and -4 or 0))
		if i == 2 then
			p = center + Vector3.new(15, 0, -6)
		end
		column(m, 1, 4, p, C(60, 60, 80))
		column(m, 8, 2.6, p + Vector3.new(0, 1, 0), col, { Material = M.Neon, Transparency = 0.25 })
		ball(m, 3, p + Vector3.new(0, 9.5, 0), col, { Material = M.Glass, Transparency = 0.3 })
	end
	prompt(m, CFrame.new(porch + Vector3.new(0, 5, -4.5)), "UPGRADE LAB", "Upgrades")
end

-- Leaderboard frame (ExtrasServer fills Rows/Subtitle). `cf` faces its text side (+X) at the viewer.
local function leaderboard(parent, name, cf, title, color)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	for _, side in ipairs({ -1, 1 }) do
		column(m, 20, 1.8, (cf * CFrame.new(0, -17, side * 12.5)).Position, darker(color, 0.25))
	end
	part(m, { Size = Vector3.new(1.4, 32, 27), CFrame = cf * CFrame.new(-0.2, 3, 0), Color = darker(color, 0.25) })
	local board = part(m, { Name = "Board", Size = Vector3.new(1.2, 30, 25), CFrame = cf * CFrame.new(0.1, 3, 0), Color = color })
	part(m, { Size = Vector3.new(3, 3, 29), CFrame = cf * CFrame.new(0, 19.5, 0), Color = YELLOW })
	ball(m, 5, (cf * CFrame.new(0, 22.5, 0)).Position, YELLOW)
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
	grad.Color = ColorSequence.new(lighter(color, 0.3), darker(color, 0.15))
	grad.Rotation = 90
	grad.Parent = bg
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.05, 0.02)
	t.Size = UDim2.fromScale(0.9, 0.11)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = WHITE
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
end

-- Launch area: pad, tower, fuel tanks, floodlights, mission screen, mini launch pads -------------
local function launchArea(hub, rng)
	local HALF = Config.PATH_HALF_WIDTH
	cyl(hub, 1.2, 24, CFrame.new(PAD_X, 0.9, 0) * UP, C(150, 155, 170), { Name = "LaunchPad" })
	cyl(hub, 1.3, 14, CFrame.new(PAD_X, 0.95, 0) * UP, ORANGE, { Name = "PadCenter", Material = M.Neon })
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		part(hub, { Size = Vector3.new(4, 1.4, 1.4), CFrame = CFrame.new(PAD_X, 1, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 11.4), Color = i % 2 == 0 and YELLOW or C(40, 40, 45) })
	end
	part(hub, { Name = "StartLine", Size = Vector3.new(2, 0.3, HALF * 2 + 10), CFrame = CFrame.new(Config.LAUNCH_X + 4, 0.45, 0), Color = WHITE, Material = M.Neon })

	-- launch tower (red/white truss) with a gantry arm and a blinking beacon
	local towerC = Vector3.new(PAD_X, 0, -17)
	local TH = 48
	for _, dx in ipairs({ -3, 3 }) do
		for _, dz in ipairs({ -3, 3 }) do
			part(hub, { Size = Vector3.new(1.2, TH, 1.2), CFrame = CFrame.new(towerC + Vector3.new(dx, TH / 2, dz)), Color = C(230, 60, 60), Material = M.Metal })
		end
	end
	for y = 4, TH, 6 do
		local col = (y / 6) % 2 < 1 and WHITE or C(230, 60, 60)
		for _, o in ipairs({ { 0, -3, 7.2, 0.8 }, { 0, 3, 7.2, 0.8 }, { -3, 0, 0.8, 7.2 }, { 3, 0, 0.8, 7.2 } }) do
			part(hub, { Size = Vector3.new(o[3], 0.8, o[4]), CFrame = CFrame.new(towerC + Vector3.new(o[1], y, o[2])), Color = col })
		end
	end
	part(hub, { Size = Vector3.new(9, 1, 9), CFrame = CFrame.new(towerC + Vector3.new(0, TH + 0.5, 0)), Color = WHITE })
	tag(ball(hub, 3, towerC + Vector3.new(0, TH + 2.5, 0), C(255, 60, 60), { Material = M.Neon }), "LobbyBlink")
	part(hub, { Name = "Gantry", Size = Vector3.new(2, 1.4, 12), CFrame = CFrame.new(towerC + Vector3.new(0, 10, 8.5)), Color = WHITE })

	-- fuel tanks with pipes to the pad
	for i, spot in ipairs({ Vector3.new(-30, 0, 46), Vector3.new(-46, 0, 54), Vector3.new(-16, 0, 56) }) do
		local h = 22 + i * 3
		column(hub, h, 12, spot, Color3.fromRGB(250, 250, 255))
		column(hub, 3, 12.4, spot + Vector3.new(0, h * 0.5, 0), C(255, 80, 80))
		ball(hub, 12, spot + Vector3.new(0, h, 0), BLUE)
		beam(hub, spot + Vector3.new(0, 1.2, 0), Vector3.new(PAD_X, 1.2, 9), 1.2, C(170, 175, 190), { Material = M.Metal })
	end

	-- floodlight towers at the apron corners
	for _, corner in ipairs({ Vector3.new(-38, 0, -30), Vector3.new(-38, 0, 30), Vector3.new(2, 0, -34), Vector3.new(2, 0, 34) }) do
		column(hub, 20, 1, corner, C(70, 70, 90))
		local head = corner + Vector3.new(0, 20, 0)
		part(hub, { Size = Vector3.new(3, 2, 4), CFrame = CFrame.lookAt(head, Vector3.new(PAD_X, 0, 0)), Color = C(70, 70, 90) })
		part(hub, { Size = Vector3.new(2.4, 1.4, 0.3), CFrame = CFrame.lookAt(head, Vector3.new(PAD_X, 0, 0)) * CFrame.new(0, 0, -2.1), Color = C(255, 250, 220), Material = M.Neon })
	end

	-- crates, barrels, cones around the apron
	for i = 1, 8 do
		local side = i % 2 == 0 and -1 or 1
		local p = Vector3.new(rng:NextNumber(-38, -24), 0.6, side * rng:NextNumber(20, 28))
		if i <= 4 then
			part(hub, { Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(p + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = C(190, 140, 80), Material = M.WoodPlanks })
		else
			column(hub, 3.2, 2.4, p, i % 3 == 0 and C(230, 60, 60) or BLUE)
			column(hub, 0.3, 2.5, p + Vector3.new(0, 1.2, 0), WHITE)
		end
	end
	for _, z in ipairs({ -14, 14 }) do
		for i = 0, 2 do
			local p = Vector3.new(PAD_X - 16 + i * 5, 0.6, z)
			column(hub, 2.2, 1.6, p, C(255, 120, 30))
			column(hub, 0.5, 1.7, p + Vector3.new(0, 1.1, 0), WHITE)
		end
	end

	-- mission screen at the apron's back corner, angled toward the plaza
	local scrPos = Vector3.new(-44, 18, -40)
	local screenCF = CFrame.lookAt(scrPos, Vector3.new(-120, 14, 0)) * CFrame.Angles(0, -math.pi / 2, 0)
	column(hub, 12, 2, scrPos - Vector3.new(0, 18, 0), C(80, 80, 100))
	local screen = part(hub, { Name = "MissionScreen", Size = Vector3.new(1.4, 13, 24), CFrame = screenCF, Color = C(30, 30, 50) })
	part(hub, { Size = Vector3.new(1.2, 14.4, 25.4), CFrame = screenCF * CFrame.new(0.2, 0, 0), Color = ORANGE })
	local scr = sign(screen, Enum.NormalId.Left, "READY FOR LAUNCH!\nCollect coins, fly through rings,\nunlock new worlds!", C(120, 255, 160), C(20, 30, 60))
	scr.Name = "ScreenText"

	-- toy rocket pads: LobbyClient fires little rockets from these every few seconds
	for _, p in ipairs({ Vector3.new(-30, 0, -44), Vector3.new(-150, 0, 50), Vector3.new(-150, 0, -50) }) do
		disc(hub, 7, p, 0.5, C(60, 60, 75))
		tag(disc(hub, 4, p, 0.6, ORANGE, { Material = M.Neon }), "MiniPad")
	end
end

-- Park props that fill the lawns ------------------------------------------------------------------
local function astronaut(parent, pos, facing)
	local cf = CFrame.lookAt(pos, Vector3.new(facing.X, pos.Y, facing.Z))
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local suit = C(245, 245, 250)
	column(parent, 3, 9, pos, STONE)
	column(parent, 0.6, 9.4, pos + Vector3.new(0, 3, 0), ORANGE)
	local y0 = 3.6
	for _, x in ipairs({ -1.1, 1.1 }) do
		part(parent, { Size = Vector3.new(1.8, 4, 2), CFrame = at(x, y0 + 2, 0), Color = suit })
		part(parent, { Size = Vector3.new(2, 1, 2.6), CFrame = at(x, y0 + 0.5, -0.2), Color = C(90, 90, 110) })
	end
	part(parent, { Size = Vector3.new(4.6, 4.6, 2.8), CFrame = at(0, y0 + 6.2, 0), Color = suit })
	part(parent, { Size = Vector3.new(3.6, 4, 1.6), CFrame = at(0, y0 + 6.4, 2), Color = C(200, 200, 215) })
	part(parent, { Size = Vector3.new(1.6, 1, 0.3), CFrame = at(0, y0 + 6.8, -1.5), Color = C(230, 60, 60) })
	ball(parent, 4.4, at(0, y0 + 10.2, 0).Position, suit)
	ball(parent, 3.4, at(0, y0 + 10.3, -0.9).Position, C(255, 190, 60), { Material = M.Glass, Reflectance = 0.5 })
	-- left arm down, right arm waving
	part(parent, { Size = Vector3.new(1.4, 4, 1.4), CFrame = at(-3, y0 + 6, 0), Color = suit })
	part(parent, { Size = Vector3.new(1.4, 4, 1.4), CFrame = at(3, y0 + 8.6, 0) * CFrame.Angles(0, 0, math.rad(-35)), Color = suit })
	ball(parent, 1.6, at(4.2, y0 + 10.4, 0).Position, C(90, 90, 110))
end

local function planetSculpture(parent, pos)
	column(parent, 9, 1.6, pos, C(200, 200, 215))
	column(parent, 1, 7, pos, STONE)
	local c = pos + Vector3.new(0, 15, 0)
	ball(parent, 11, c, C(70, 150, 255))
	for _, off in ipairs({ Vector3.new(2, 3, -3), Vector3.new(-3, -1, 3), Vector3.new(3, -3, 2) }) do
		ball(parent, 4.5, c + off.Unit * 4.2, C(100, 200, 90), { Material = M.Grass })
	end
	cyl(parent, 0.5, 20, CFrame.new(c) * CFrame.Angles(0.35, 0, math.pi / 2 + 0.25), ORANGE, { Transparency = 0.1, CastShadow = false })
	cyl(parent, 0.55, 16, CFrame.new(c) * CFrame.Angles(0.35, 0, math.pi / 2 + 0.25), YELLOW, { CastShadow = false })
end

local function pond(parent, pos, rng)
	cyl(parent, 0.8, 24, CFrame.new(pos + Vector3.new(0, 0.6, 0)) * UP, C(190, 185, 175), { Material = M.Slate })
	cyl(parent, 0.9, 21, CFrame.new(pos + Vector3.new(0, 0.65, 0)) * UP, C(70, 180, 240), { Material = M.Glass, Transparency = 0.2, Reflectance = 0.4 })
	for _ = 1, 6 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(2, 8)
		local q = pos + Vector3.new(math.cos(a) * r, 1.15, math.sin(a) * r)
		cyl(parent, 0.15, rng:NextNumber(2, 3), CFrame.new(q) * UP, C(80, 175, 80), { CastShadow = false })
		if rng:NextNumber() < 0.4 then
			ball(parent, 0.8, q + Vector3.new(0, 0.3, 0), C(255, 150, 200))
		end
	end
	-- a little duck
	local d = pos + Vector3.new(3, 1.6, -2)
	ball(parent, 1.6, d, YELLOW)
	ball(parent, 1.1, d + Vector3.new(0.7, 0.8, 0), YELLOW)
	part(parent, { Size = Vector3.new(0.6, 0.3, 0.4), CFrame = CFrame.new(d + Vector3.new(1.35, 0.75, 0)), Color = ORANGE })
end

local function picnicTable(parent, pos, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local wood = C(175, 120, 75)
	part(parent, { Size = Vector3.new(6, 0.5, 3), CFrame = cf * CFrame.new(0, 2.6, 0), Color = wood, Material = M.WoodPlanks })
	for _, z in ipairs({ -2.6, 2.6 }) do
		part(parent, { Size = Vector3.new(6, 0.4, 1.2), CFrame = cf * CFrame.new(0, 1.5, z), Color = wood, Material = M.WoodPlanks })
	end
	for _, x in ipairs({ -2.4, 2.4 }) do
		part(parent, { Size = Vector3.new(0.4, 2.6, 5.6), CFrame = cf * CFrame.new(x, 1.3, 0), Color = darker(wood, 0.2) })
	end
	part(parent, { Size = Vector3.new(6.2, 0.05, 3.2), CFrame = cf * CFrame.new(0, 2.88, 0), Color = C(230, 70, 70), CastShadow = false })
end

local function bigDish(parent, pos)
	local m = Instance.new("Model")
	m.Name = "BigDish"
	m.Parent = parent
	column(m, 10, 2.4, pos, C(200, 200, 210))
	local head = pos + Vector3.new(0, 11, 0)
	cyl(m, 1.2, 16, CFrame.new(head) * CFrame.Angles(0, 0, math.rad(50)), WHITE)
	cyl(m, 1.3, 6, CFrame.new(head) * CFrame.Angles(0, 0, math.rad(50)), C(200, 205, 220))
	beam(m, head, head + Vector3.new(5, 4.4, 0), 0.5, C(180, 180, 195))
	tag(ball(m, 1.4, head + Vector3.new(5.2, 4.6, 0), C(255, 70, 70), { Material = M.Neon }), "LobbyBlink")
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	m:SetAttribute("SpinSpeed", 0.35)
	tag(m, "LobbySpin")
end

local function parkProps(hub, rng)
	local D = Scenery.Decor
	planetSculpture(hub, Vector3.new(-122, 0.3, -64))
	pond(hub, Vector3.new(-124, 0, 64), rng)
	astronaut(hub, Vector3.new(-160, 0.3, 70), Vector3.new(-150, 0, 0))
	bigDish(hub, Vector3.new(-40, 0.3, -66))
	picnicTable(hub, Vector3.new(-160, 0.3, -66), 0.4)
	picnicTable(hub, Vector3.new(-104, 0.3, 76), -0.3)
	for _, p in ipairs({ { -174, -72 }, { -176, -40 }, { -140, -78 }, { -102, -76 }, { -60, -78 }, { -174, 40 }, { -178, 72 }, { -142, 79 }, { -106, 60 }, { -18, -60 } }) do
		D.roundTree(hub, Vector3.new(p[1], 0.3, p[2]), rng, C(100, 200, 80))
	end
	for z = -72, 72, 12 do
		D.bush(hub, Vector3.new(-181, 0.3, z), rng, C(80, 180, 75))
	end
	for _, p in ipairs({ { -138, -56 }, { -110, -58 }, { -168, 56 }, { -140, 54 }, { -60, 76 }, { -56, -48 } }) do
		D.flowers(hub, Vector3.new(p[1], 0.3, p[2]), rng)
	end
end

function Lobby.build(hub)
	local rng = Random.new(2026)
	ground(hub, rng)
	spawnArea(hub, rng)
	statuePlaza(hub, rng)
	rocketShop(hub)
	upgradeLab(hub)
	launchArea(hub, rng)
	parkProps(hub, rng)
	-- leaderboards beside the spawn plaza, angled toward the player
	local target = Vector3.new(-160, 17, 0)
	for _, info in ipairs({ { "RichestBoard", -34, "RICHEST", C(60, 190, 90) }, { "DonorBoard", 34, "TOP DONATORS", PINK } }) do
		local pos = Vector3.new(-140, 17, info[2] * 1.15)
		local cf = CFrame.lookAt(pos, target) * CFrame.Angles(0, math.pi / 2, 0)
		leaderboard(hub, info[1], cf, info[3], info[4])
	end
end

return Lobby
