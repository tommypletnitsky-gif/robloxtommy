-- Everything you see along the flight path: the runway / cloud road / space track, arch gates,
-- distance signs, and themed scenery for every stage (Earth biomes on real terrain, a sky of
-- clouds and floating islands, and a space zone with planets).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(ServerScriptService.BuildKit)
local TerrainBuilder = require(ServerScriptService.TerrainBuilder)
local Foliage = require(ServerScriptService.Foliage)

local part, ball, cyl, column, beam, sign = Kit.part, Kit.ball, Kit.cyl, Kit.column, Kit.beam, Kit.sign
local darker, lighter = Kit.darker, Kit.lighter
local UP = Kit.UP
local L = Config.STAGE_LENGTH
local HALF = Config.PATH_HALF_WIDTH
local C = Color3.fromRGB
local M = Enum.Material

local Scenery = {}

local WHITE = C(255, 255, 255)
local WOOD = C(130, 85, 50)

local function ground(x, z)
	local h, wet = TerrainBuilder.height(x, z)
	return Vector3.new(x, h, z), wet, h
end

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

-- Earth decorations ------------------------------------------------------------------------
local D = {}

-- A real stylized tree (Foliage). palette: "meadow", "orchard", "jungle", "island", ... or a Color3.
function D.roundTree(f, p, rng, palette, height)
	Foliage.tree(f, p, rng, height or rng:NextNumber(16, 26), palette or "meadow")
end

function D.bush(f, p, rng, color)
	color = color or C(80, 175, 70)
	for _ = 1, rng:NextInteger(2, 3) do
		ball(f, rng:NextNumber(3.5, 6), p + Vector3.new(rng:NextNumber(-2.5, 2.5), 1, rng:NextNumber(-2.5, 2.5)), color:Lerp(C(150, 220, 90), rng:NextNumber(0, 0.3)), { Material = M.Grass })
	end
end

local FLOWER_COLORS = { C(255, 120, 180), C(255, 220, 60), C(255, 255, 255), C(255, 90, 90), C(190, 120, 255) }
function D.flowers(f, p, rng)
	local c = pick(rng, FLOWER_COLORS)
	for _ = 1, 6 do
		local q = p + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
		column(f, 1.4, 0.3, q - Vector3.new(0, 0.3, 0), C(70, 160, 60), { CanCollide = false, CastShadow = false })
		ball(f, rng:NextNumber(1, 1.4), q + Vector3.new(0, 1.3, 0), c, { CanCollide = false, CastShadow = false })
	end
end

function D.rocks(f, p, rng, color)
	color = color or C(140, 140, 150)
	for _ = 1, rng:NextInteger(2, 3) do
		local s = rng:NextNumber(3, 8)
		part(f, { Size = Vector3.new(s, s * 0.7, s * 0.85), CFrame = CFrame.new(p + Vector3.new(rng:NextNumber(-4, 4), s * 0.2, rng:NextNumber(-4, 4))) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), Color = color:Lerp(C(0, 0, 0), rng:NextNumber(0, 0.25)), Material = M.Slate })
	end
end

function D.pine(f, p, rng, snowy)
	local green = C(40, 130, 75):Lerp(C(30, 100, 60), rng:NextNumber())
	local scale = rng:NextNumber(0.9, 1.5)
	column(f, 4 * scale, 1.5 * scale, p - Vector3.new(0, 0.5, 0), WOOD, { Material = M.Wood })
	for i = 0, 3 do
		local d = (11 - i * 2.6) * scale
		local y = (3.5 + i * 3) * scale
		cyl(f, 2.6 * scale, d, CFrame.new(p + Vector3.new(0, y, 0)) * UP, green, { Material = M.Grass })
		if snowy then
			cyl(f, 0.7 * scale, d * 0.82, CFrame.new(p + Vector3.new(0, y + 1.5 * scale, 0)) * UP, WHITE, { Material = M.Snow })
		end
	end
	ball(f, 2.4 * scale, p + Vector3.new(0, 15.5 * scale, 0), snowy and WHITE or green, { Material = snowy and M.Snow or M.Grass })
end

function D.palm(f, p, rng)
	local lean = rng:NextNumber(-0.25, 0.25)
	local top = p
	for i = 0, 4 do
		local seg = CFrame.new(top) * CFrame.Angles(0, 0, lean * i * 0.5)
		local nextTop = (seg * CFrame.new(0, 3.2, 0)).Position
		cyl(f, 3.4, 1.6 - i * 0.12, CFrame.new((top + nextTop) / 2) * CFrame.Angles(0, 0, lean * i * 0.5) * UP, C(150, 105, 60), { Material = M.Wood })
		top = nextTop
	end
	for i = 0, 5 do
		local yaw = i / 6 * math.pi * 2 + rng:NextNumber(0, 0.4)
		part(f, { Size = Vector3.new(9, 0.4, 2.6), CFrame = CFrame.new(top) * CFrame.Angles(0, yaw, -0.35) * CFrame.new(4.2, 0, 0), Color = C(60, 170, 70), Material = M.Grass, CanCollide = false })
	end
	for i = 0, 2 do
		ball(f, 1.2, top + Vector3.new(math.cos(i * 2.1) * 0.9, -0.8, math.sin(i * 2.1) * 0.9), C(110, 75, 40))
	end
end

function D.cactus(f, p, rng)
	local g = C(80, 175, 80)
	local h = rng:NextNumber(8, 14)
	column(f, h, 2.8, p - Vector3.new(0, 0.5, 0), g)
	ball(f, 2.8, p + Vector3.new(0, h - 0.5, 0), g)
	for _, side in ipairs({ -1, 1 }) do
		if rng:NextNumber() < 0.75 then
			local y = h * rng:NextNumber(0.35, 0.6)
			cyl(f, 3, 1.8, CFrame.new(p + Vector3.new(side * 2.2, y, 0)), g)
			column(f, 4, 1.8, p + Vector3.new(side * 3.5, y, 0), g)
			ball(f, 1.8, p + Vector3.new(side * 3.5, y + 4, 0), g)
		end
	end
	if rng:NextNumber() < 0.4 then
		ball(f, 1.4, p + Vector3.new(0, h + 0.6, 0), C(255, 110, 170))
	end
end

function D.hay(f, p, rng)
	cyl(f, 4, 4.4, CFrame.new(p + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), C(235, 200, 90), { Material = M.Fabric })
end

-- A red barn facing the runway
function D.barn(f, p, rng)
	local face = CFrame.lookAt(p, Vector3.new(p.X, p.Y, 0))
	local function at(x, y, z)
		return face * CFrame.new(x, y, z)
	end
	local red = C(210, 60, 55)
	part(f, { Size = Vector3.new(16, 10, 14), CFrame = at(0, 5, 0), Color = red })
	-- gable roof: two tilted panels meeting at the ridge
	for _, side in ipairs({ -1, 1 }) do
		part(f, { Size = Vector3.new(17, 1, 9.6), CFrame = at(0, 12.6, side * 3.6) * CFrame.Angles(side * -0.72, 0, 0), Color = C(120, 60, 50) })
	end
	part(f, { Size = Vector3.new(16, 3.5, 7), CFrame = at(0, 11.3, 0), Color = red })
	part(f, { Size = Vector3.new(6, 7, 0.4), CFrame = at(0, 3.5, -7.1), Color = C(150, 40, 40) })
	beam(f, (at(-3, 0.2, -7.3)).Position, (at(3, 6.8, -7.3)).Position, 0.5, WHITE)
	beam(f, (at(3, 0.2, -7.3)).Position, (at(-3, 6.8, -7.3)).Position, 0.5, WHITE)
	part(f, { Size = Vector3.new(16.2, 0.6, 14.2), CFrame = at(0, 10, 0), Color = WHITE })
end

function D.windmill(f, p, rng)
	column(f, 22, 5, p - Vector3.new(0, 1, 0), C(245, 240, 230))
	ball(f, 6, p + Vector3.new(0, 22, 0), C(210, 60, 55))
	local hub = p + Vector3.new(0, 21, -3.6 * (p.Z > 0 and 1 or -1))
	for i = 0, 3 do
		part(f, { Size = Vector3.new(1.2, 13, 0.4), CFrame = CFrame.new(hub) * CFrame.Angles(0, 0, i * math.pi / 2 + 0.3) * CFrame.new(0, 6.5, 0), Color = WHITE })
	end
end

function D.crops(f, p, rng)
	part(f, { Size = Vector3.new(24, 0.4, 14), CFrame = CFrame.new(p + Vector3.new(0, 0.1, 0)), Color = C(140, 95, 55), Material = M.Ground })
	local color = pick(rng, { C(110, 200, 70), C(250, 200, 60), C(230, 120, 60) })
	for i = -2, 2 do
		part(f, { Size = Vector3.new(22, 1.4, 1.6), CFrame = CFrame.new(p + Vector3.new(0, 0.9, i * 2.8)), Color = color, Material = M.Grass })
	end
end

function D.fence(f, a, b)
	local n = math.floor((b - a).Magnitude / 6)
	for i = 0, n do
		local q = a:Lerp(b, i / n)
		part(f, { Size = Vector3.new(0.8, 3.2, 0.8), CFrame = CFrame.new(q + Vector3.new(0, 1.4, 0)), Color = WHITE })
	end
	beam(f, a + Vector3.new(0, 2.4, 0), b + Vector3.new(0, 2.4, 0), 0.5, WHITE)
	beam(f, a + Vector3.new(0, 1.2, 0), b + Vector3.new(0, 1.2, 0), 0.5, WHITE)
end

-- Stepped pyramid far out in the desert
function D.pyramid(f, p, rng)
	local size = rng:NextNumber(60, 90)
	for i = 0, 7 do
		local w = size * (1 - i / 8)
		part(f, { Size = Vector3.new(w, size / 14, w), CFrame = CFrame.new(p + Vector3.new(0, i * size / 14 + size / 28 - 1, 0)), Color = C(235, 200, 130):Lerp(C(210, 170, 100), i % 2), Material = M.Sandstone })
	end
end

function D.tumbleweed(f, p, rng)
	ball(f, rng:NextNumber(2.5, 4), p + Vector3.new(0, 1.5, 0), C(170, 130, 80), { Material = M.Fabric })
end

function D.rockArch(f, p, rng)
	local color = C(200, 110, 70)
	local face = CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
	for i = 0, 8 do
		local a = i / 8 * math.pi
		local q = (face * CFrame.new(math.cos(a) * 16, math.sin(a) * 16, 0)).Position
		part(f, { Size = Vector3.new(7, 7, 7), CFrame = CFrame.new(q) * CFrame.Angles(0, 0, a), Color = color:Lerp(C(0, 0, 0), (i % 2) * 0.08), Material = M.Sandstone })
	end
end

function D.mushroom(f, p, rng)
	local h = rng:NextNumber(4, 8)
	column(f, h, 1.8, p - Vector3.new(0, 0.5, 0), C(245, 240, 225))
	local capColor = pick(rng, { C(230, 60, 60), C(240, 140, 50), C(170, 90, 230) })
	local s = rng:NextNumber(7, 10)
	ball(f, s, p + Vector3.new(0, h + s * 0.1, 0), capColor)
	cyl(f, 0.6, s * 0.95, CFrame.new(p + Vector3.new(0, h - s * 0.15, 0)) * UP, C(250, 240, 220))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		ball(f, s * 0.18, p + Vector3.new(math.cos(a) * s * 0.33, h + s * 0.42, math.sin(a) * s * 0.33), WHITE)
	end
end

function D.deadTree(f, p, rng)
	local gray = C(110, 100, 95)
	local h = rng:NextNumber(10, 15)
	column(f, h, 1.6, p - Vector3.new(0, 0.5, 0), gray, { Material = M.Wood })
	for _ = 1, 3 do
		local y = h * rng:NextNumber(0.5, 0.95)
		local a = rng:NextNumber(0, 6.28)
		beam(f, p + Vector3.new(0, y, 0), p + Vector3.new(math.cos(a) * 4, y + 3, math.sin(a) * 4), 0.7, gray, { Material = M.Wood })
	end
end

function D.lilypad(f, p, rng)
	cyl(f, 0.2, rng:NextNumber(3, 5), CFrame.new(p.X, TerrainBuilder.WATER_LEVEL + 0.1, p.Z) * UP, C(70, 170, 70), { CanCollide = false })
	if rng:NextNumber() < 0.3 then
		ball(f, 1, Vector3.new(p.X, TerrainBuilder.WATER_LEVEL + 0.6, p.Z), C(255, 150, 200))
	end
end

function D.snowman(f, p, rng)
	ball(f, 6, p + Vector3.new(0, 2.6, 0), WHITE, { Material = M.Snow })
	ball(f, 4.4, p + Vector3.new(0, 6.6, 0), WHITE, { Material = M.Snow })
	ball(f, 3.2, p + Vector3.new(0, 9.6, 0), WHITE, { Material = M.Snow })
	local toward = Vector3.new(0, 0, p.Z > 0 and -1 or 1)
	part(f, { Size = Vector3.new(0.5, 0.5, 1.8), CFrame = CFrame.lookAt(p + Vector3.new(0, 9.6, 0) + toward * 1.8, p + Vector3.new(0, 9.6, 0) + toward * 4), Color = C(255, 140, 40) })
	cyl(f, 2.2, 2.6, CFrame.new(p + Vector3.new(0, 11.8, 0)) * UP, C(30, 30, 40))
	cyl(f, 0.3, 3.6, CFrame.new(p + Vector3.new(0, 10.8, 0)) * UP, C(30, 30, 40))
	for _, side in ipairs({ -1, 1 }) do
		ball(f, 0.5, p + Vector3.new(side * 0.7, 10, 0) + toward * 1.4, C(20, 20, 30))
	end
end

function D.igloo(f, p, rng)
	ball(f, 16, p + Vector3.new(0, -1, 0), C(220, 240, 255), { Material = M.Ice })
	local toward = Vector3.new(0, 0, p.Z > 0 and -1 or 1)
	cyl(f, 6, 6, CFrame.lookAt(p + toward * 7 + Vector3.new(0, 1.5, 0), p + toward * 20 + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.pi / 2, 0), C(220, 240, 255), { Material = M.Ice })
end

function D.iceSpikes(f, p, rng)
	for _ = 1, 3 do
		local h = rng:NextNumber(10, 22)
		part(f, { Size = Vector3.new(3, h, 3), CFrame = CFrame.new(p + Vector3.new(rng:NextNumber(-4, 4), h / 2 - 1, rng:NextNumber(-4, 4))) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Color = C(170, 225, 255), Material = M.Ice, Transparency = 0.1 })
	end
end

function D.charredTree(f, p, rng)
	local c = C(55, 45, 45)
	local h = rng:NextNumber(8, 12)
	column(f, h, 1.4, p - Vector3.new(0, 0.5, 0), c)
	for _ = 1, 2 do
		local y = h * rng:NextNumber(0.5, 0.9)
		local a = rng:NextNumber(0, 6.28)
		beam(f, p + Vector3.new(0, y, 0), p + Vector3.new(math.cos(a) * 3, y + 2.5, math.sin(a) * 3), 0.6, c)
	end
end

function D.smokeVent(f, p, rng, big)
	local s = big and 30 or 6
	local vent = part(f, { Size = Vector3.one * 2, CFrame = CFrame.new(p), Transparency = 1, CanCollide = false, CanQuery = false })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(C(90, 85, 90), C(160, 150, 150))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.4), NumberSequenceKeypoint.new(1, s) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = big and 4 or 3
	e.Speed = NumberRange.new(big and 10 or 4)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Parent = vent
	if big then
		local light = Instance.new("PointLight")
		light.Color = C(255, 120, 40)
		light.Range = 60
		light.Brightness = 3
		light.Parent = vent
	end
end

function D.lavaPool(f, p, rng)
	local s = rng:NextNumber(10, 20)
	local lava = cyl(f, 0.6, s, CFrame.new(p + Vector3.new(0, 0.15, 0)) * UP, C(255, 120, 30), { Material = M.Neon, CastShadow = false })
	cyl(f, 0.5, s + 3, CFrame.new(p + Vector3.new(0, 0.05, 0)) * UP, C(60, 45, 45), { Material = M.Basalt })
	local glow = Instance.new("PointLight")
	glow.Color = C(255, 130, 40)
	glow.Range = s * 1.2
	glow.Brightness = 2
	glow.Parent = lava
end

function D.cabin(f, p, rng)
	local face = CFrame.lookAt(p, Vector3.new(p.X, p.Y, 0))
	local function at(x, y, z)
		return face * CFrame.new(x, y, z)
	end
	part(f, { Size = Vector3.new(12, 7, 10), CFrame = at(0, 3.5, 0), Color = C(150, 95, 55), Material = M.WoodPlanks })
	for _, side in ipairs({ -1, 1 }) do
		part(f, { Size = Vector3.new(13, 1, 6.6), CFrame = at(0, 8.6, side * 2.7) * CFrame.Angles(side * -0.6, 0, 0), Color = WHITE, Material = M.Snow })
	end
	part(f, { Size = Vector3.new(1.6, 4, 1.6), CFrame = at(4, 10, 2), Color = C(120, 110, 110), Material = M.Brick })
	part(f, { Size = Vector3.new(3, 5, 0.3), CFrame = at(0, 2.5, -5.1), Color = C(90, 55, 30) })
	part(f, { Size = Vector3.new(2.4, 2.4, 0.3), CFrame = at(3.5, 4.2, -5.1), Color = C(255, 220, 120), Material = M.Neon })
end

-- What each Earth stage is decorated with: { decor, count, maxHeight, extra args }
local BIOMES = {
	{ { "roundTree", 22 }, { "bush", 12 }, { "flowers", 18 }, { "rocks", 4 } },
	{ { "barn", 2 }, { "windmill", 2 }, { "hay", 10 }, { "crops", 5 }, { "roundTree", 8, nil, "orchard" }, { "flowers", 8 } },
	{ { "cactus", 22 }, { "rocks", 6, nil, C(220, 180, 120) }, { "pyramid", 2 }, { "tumbleweed", 8 } },
	{ { "cactus", 10 }, { "rocks", 12, nil, C(200, 105, 70) }, { "rockArch", 2 } },
	{ { "palm", 16 }, { "roundTree", 14, nil, "jungle" }, { "bush", 16, nil, C(50, 150, 60) }, { "mushroom", 4 } },
	{ { "deadTree", 14 }, { "mushroom", 12 }, { "lilypad", 26 }, { "bush", 8, nil, C(80, 110, 60) } },
	{ { "pine", 28, nil, true }, { "snowman", 4 }, { "igloo", 2 }, { "rocks", 4, nil, C(200, 210, 225) } },
	{ { "iceSpikes", 16 }, { "pine", 12, nil, true }, { "igloo", 2 } },
	{ { "charredTree", 12 }, { "rocks", 14, nil, C(70, 60, 65) }, { "smokeVent", 6 }, { "lavaPool", 10 } },
	{ { "pine", 22 }, { "cabin", 2 }, { "rocks", 12, nil, C(150, 150, 160) } },
}

local function decorateEarth(f, s)
	local x0 = Config.LAUNCH_X + (s - 1) * L
	local rng = Random.new(s * 7919)
	for _, entry in ipairs(BIOMES[s]) do
		local name, count, _, extra = entry[1], entry[2], entry[3], entry[4]
		local placed, tries = 0, 0
		while placed < count and tries < count * 12 do
			tries += 1
			local x = rng:NextNumber(x0 + 10, x0 + L - 10)
			local side = rng:NextNumber() < 0.5 and -1 or 1
			local near = { roundTree = 56, bush = 52, flowers = 50, crops = 70, barn = 80, windmill = 90, pyramid = 170, igloo = 70, cabin = 80, rockArch = 90 }
			local z = side * rng:NextNumber(near[name] or 54, name == "pyramid" and 240 or 200)
			local pos, wet, h = ground(x, z)
			local wantsWater = name == "lilypad"
			if (wantsWater and wet) or (not wantsWater and not wet and h < 55) then
				D[name](f, pos, rng, extra)
				placed += 1
			end
		end
	end
	-- farm fences along the runway
	if s == 2 then
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 3 do
				local xa = x0 + 30 + i * 120
				D.fence(f, Vector3.new(xa, 0, side * 52), Vector3.new(xa + 90, 0, side * 52))
			end
		end
	end
	-- smoke + glow from every volcano crater
	if s == 9 then
		for _, v in ipairs(TerrainBuilder.VOLCANOES) do
			local h = TerrainBuilder.height(v[1] + 26, v[2])
			D.smokeVent(f, Vector3.new(v[1], h + 6, v[2]), rng, true)
		end
	end
end

-- Roads -------------------------------------------------------------------------------------
-- Earth: a dark runway with white edge lines, a dashed yellow center line, red/white kerbs and arrows.
local function earthRoad(f, s)
	local x0 = Config.LAUNCH_X + (s - 1) * L
	local mx = x0 + L / 2
	part(f, { Name = "Runway", Size = Vector3.new(L, 0.4, 34), CFrame = CFrame.new(mx, 0, 0), Color = C(78, 84, 110) })
	for _, side in ipairs({ -1, 1 }) do
		part(f, { Size = Vector3.new(L, 0.42, 1), CFrame = CFrame.new(mx, 0.02, side * 15), Color = WHITE, CastShadow = false })
		part(f, { Size = Vector3.new(L, 0.7, 2.6), CFrame = CFrame.new(mx, 0.15, side * 18.3), Color = C(235, 60, 60), CastShadow = false })
		for x = x0, x0 + L - 10, 10 do
			part(f, { Size = Vector3.new(5, 0.72, 2.6), CFrame = CFrame.new(x + 2.5, 0.16, side * 18.3), Color = WHITE, CastShadow = false })
		end
	end
	for x = x0 + 4, x0 + L - 8, 16 do
		part(f, { Size = Vector3.new(7, 0.42, 0.9), CFrame = CFrame.new(x + 3.5, 0.02, 0), Color = C(255, 210, 50), CastShadow = false })
	end
	for x = x0 + 50, x0 + L - 1, 100 do
		for _, side in ipairs({ -1, 1 }) do
			part(f, { Size = Vector3.new(9, 0.43, 2), CFrame = CFrame.new(x - 3.3, 0.03, side * 4.2) * CFrame.Angles(0, side * math.rad(40), 0), Color = WHITE, CastShadow = false })
		end
	end
end

-- Sky: a pastel road lined with puffy clouds, following the climbing path.
local function skyRoad(f, s, st, rng)
	local x0 = Config.LAUNCH_X + (s - 1) * L
	local a = Vector3.new(x0, Config.pathY(x0), 0)
	local b = Vector3.new(x0 + L, Config.pathY(x0 + L), 0)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) -- local -Z runs forward along the path
	if st.name == "Rainbow Bridge" then
		local colors = { C(255, 80, 80), C(255, 165, 50), C(255, 230, 70), C(90, 220, 100), C(80, 160, 255), C(170, 100, 255) }
		for i, c in ipairs(colors) do
			part(f, { Size = Vector3.new(36 / 6, 2, len), CFrame = cf * CFrame.new(-18 + (i - 0.5) * 6, -1, 0), Color = c })
		end
	else
		part(f, { Name = "CloudRoad", Size = Vector3.new(36, 2, len), CFrame = cf * CFrame.new(0, -1, 0), Color = lighter(st.ground, 0.55) })
		for t = 10, len - 10, 25 do
			part(f, { Size = Vector3.new(0.9, 2.05, 8), CFrame = cf * CFrame.new(0, -1, len / 2 - t), Color = C(130, 200, 255), Material = M.Neon, CastShadow = false })
		end
	end
	local puff = st.name == "Thunder Storm" and C(150, 150, 175) or (st.name == "Sunset Sky" and C(255, 210, 190) or WHITE)
	for t = 0, len, 18 do
		for _, side in ipairs({ -1, 1 }) do
			local size = rng:NextNumber(8, 14)
			ball(f, size, (cf * CFrame.new(side * (19 + size * 0.25), -1.5, len / 2 - t)).Position, puff, { CanCollide = false, CastShadow = false })
		end
	end
	-- the first sky stage starts as a bridge over the ocean: add support pillars
	if s == 11 then
		for t = 30, 420, 55 do
			local p = (cf * CFrame.new(0, -2, len / 2 - t)).Position
			for _, side in ipairs({ -1, 1 }) do
				local h = p.Y + 30
				column(f, h, 4, Vector3.new(p.X, -30, side * 14), C(235, 240, 255))
			end
		end
	end
end

-- Space: a dark glass track with glowing neon edges and arrows.
local function spaceRoad(f, s)
	local x0 = Config.LAUNCH_X + (s - 1) * L
	local mx, y = x0 + L / 2, Config.SKY_RISE
	part(f, { Name = "SpaceTrack", Size = Vector3.new(L, 1, 36), CFrame = CFrame.new(mx, y - 0.5, 0), Color = C(28, 26, 70), Material = M.Glass, Transparency = 0.2, Reflectance = 0.2 })
	for _, side in ipairs({ -1, 1 }) do
		part(f, { Size = Vector3.new(L, 0.6, 1), CFrame = CFrame.new(mx, y, side * 18), Color = C(80, 230, 255), Material = M.Neon, CastShadow = false })
		part(f, { Size = Vector3.new(L, 0.5, 0.5), CFrame = CFrame.new(mx, y, side * 14), Color = C(255, 90, 220), Material = M.Neon, CastShadow = false })
	end
	for x = x0 + 25, x0 + L - 1, 50 do
		for _, side in ipairs({ -1, 1 }) do
			part(f, { Size = Vector3.new(7, 0.3, 1.2), CFrame = CFrame.new(x - 2.6, y + 0.05, side * 3.4) * CFrame.Angles(0, side * math.rad(40), 0), Color = C(80, 230, 255), Material = M.Neon, CastShadow = false })
		end
	end
end

-- Sky scenery ---------------------------------------------------------------------------------
local function cloudCluster(f, center, size, color, rng)
	for _ = 1, 4 do
		ball(f, size * rng:NextNumber(0.6, 1), center + Vector3.new(rng:NextNumber(-size * 0.6, size * 0.6), rng:NextNumber(-size * 0.12, size * 0.15), rng:NextNumber(-size * 0.4, size * 0.4)), color, { CanCollide = false, CastShadow = false })
	end
end

local function floatingIsland(f, p, rng)
	cyl(f, 3, 30, CFrame.new(p) * UP, C(100, 200, 80), { Material = M.Grass })
	ball(f, 26, p + Vector3.new(0, -9, 0), C(150, 105, 70), { Material = M.Ground })
	ball(f, 16, p + Vector3.new(2, -20, 1), C(130, 90, 60), { Material = M.Ground })
	ball(f, 8, p + Vector3.new(-1, -28, -1), C(115, 80, 55), { Material = M.Ground })
	D.roundTree(f, p + Vector3.new(rng:NextNumber(-6, 6), 1.5, rng:NextNumber(-6, 6)), rng, "island", rng:NextNumber(13, 18))
	D.flowers(f, p + Vector3.new(rng:NextNumber(-7, 7), 1.5, rng:NextNumber(-7, 7)), rng)
	-- a little waterfall pouring off the edge
	local edge = p + Vector3.new(0, 0, p.Z > 0 and -14.5 or 14.5)
	part(f, { Size = Vector3.new(4, 40, 1), CFrame = CFrame.new(edge + Vector3.new(0, -19, 0)), Color = C(120, 210, 255), Material = M.Neon, Transparency = 0.35, CanCollide = false, CastShadow = false })
end

local function balloon(f, p, rng)
	local c1 = pick(rng, { C(255, 90, 90), C(255, 200, 60), C(90, 170, 255), C(160, 100, 255), C(90, 220, 140) })
	ball(f, 16, p, c1)
	ball(f, 16.3, p + Vector3.new(0, 0.5, 0), WHITE, { Transparency = 0.7, CastShadow = false })
	part(f, { Size = Vector3.new(4, 3, 4), CFrame = CFrame.new(p + Vector3.new(0, -13, 0)), Color = C(160, 110, 60), Material = M.Wood })
	for _, o in ipairs({ Vector3.new(1.6, 0, 1.6), Vector3.new(-1.6, 0, 1.6), Vector3.new(1.6, 0, -1.6), Vector3.new(-1.6, 0, -1.6) }) do
		beam(f, p + Vector3.new(0, -11.5, 0) + o, p + Vector3.new(0, -6, 0) + o * 2.4, 0.2, C(90, 70, 50))
	end
end

local function lightning(f, p, rng)
	local pts = { p }
	for i = 1, 4 do
		pts[i + 1] = pts[i] + Vector3.new(rng:NextNumber(-3, 3), -rng:NextNumber(6, 10), rng:NextNumber(-5, 5))
	end
	for i = 1, 4 do
		beam(f, pts[i], pts[i + 1], 1, C(255, 245, 120), { Material = M.Neon, CanCollide = false, CastShadow = false })
	end
end

local function rainbowArc(f, center, radius)
	local colors = { C(255, 80, 80), C(255, 165, 50), C(255, 230, 70), C(90, 220, 100), C(80, 160, 255), C(170, 100, 255) }
	for i, c in ipairs(colors) do
		local r = radius - (i - 1) * 7
		for k = 0, 17 do
			local a1, a2 = k / 18 * math.pi, (k + 1) / 18 * math.pi
			local p1 = center + Vector3.new(math.cos(a1) * r, math.sin(a1) * r, 0)
			local p2 = center + Vector3.new(math.cos(a2) * r, math.sin(a2) * r, 0)
			beam(f, p1, p2, 7, c, { Material = M.Neon, Transparency = 0.15, CanCollide = false, CastShadow = false })
		end
	end
end

local function skyScenery(f, s, st, rng)
	local x0 = Config.LAUNCH_X + (s - 1) * L
	local cloud = WHITE
	if st.name == "Thunder Storm" then
		cloud = C(120, 125, 150)
	elseif st.name == "Sunset Sky" then
		cloud = C(255, 190, 170)
	elseif st.name == "Aurora Lights" then
		cloud = C(200, 245, 240)
	elseif st.name == "Edge of Space" then
		cloud = C(170, 180, 230)
	end
	-- a sea of clouds below the road
	for _ = 1, 16 do
		local x = rng:NextNumber(x0, x0 + L)
		local z = rng:NextNumber(-330, 330)
		-- low over the ocean at the start of the sky, then a sea of clouds below the road
		local y = math.max(Config.pathY(x) - rng:NextNumber(55, 95), rng:NextNumber(18, 45))
		cloudCluster(f, Vector3.new(x, y, z), rng:NextNumber(55, 100), cloud, rng)
	end
	-- floating islands + hot air balloons beside the road
	for _ = 1, 3 do
		local x = rng:NextNumber(x0 + 40, x0 + L - 40)
		local side = rng:NextNumber() < 0.5 and -1 or 1
		floatingIsland(f, Vector3.new(x, Config.pathY(x) + rng:NextNumber(-25, 30), side * rng:NextNumber(85, 200)), rng)
	end
	for _ = 1, 2 do
		local x = rng:NextNumber(x0 + 40, x0 + L - 40)
		local side = rng:NextNumber() < 0.5 and -1 or 1
		balloon(f, Vector3.new(x, Config.pathY(x) + rng:NextNumber(20, 75), side * rng:NextNumber(70, 190)), rng)
	end
	if st.name == "Rainbow Bridge" then
		rainbowArc(f, Vector3.new(x0 + L / 2, Config.pathY(x0 + L / 2) - 40, -300), 170)
	elseif st.name == "Thunder Storm" then
		for _ = 1, 7 do
			local x = rng:NextNumber(x0, x0 + L)
			lightning(f, Vector3.new(x, Config.pathY(x) + rng:NextNumber(50, 110), rng:NextNumber(-150, 150)), rng)
		end
	elseif st.name == "Aurora Lights" then
		for r = 1, 4 do
			local z = -260 + r * 100
			local hue = r % 2 == 0 and C(120, 255, 180) or C(180, 110, 255)
			for k = 0, 9 do
				local x = x0 + k * (L / 10)
				local y = Config.pathY(x) + 170 + math.sin(k * 0.9 + r) * 25
				part(f, { Size = Vector3.new(L / 10 + 4, 40, 1), CFrame = CFrame.new(x + L / 20, y, z + math.sin(k * 1.3 + r) * 20), Color = hue, Material = M.Neon, Transparency = 0.65, CanCollide = false, CastShadow = false })
			end
		end
	elseif st.name == "Stratosphere" or st.name == "Jet Stream" then
		for _ = 1, 22 do
			local x = rng:NextNumber(x0, x0 + L)
			part(f, { Size = Vector3.new(rng:NextNumber(40, 90), 0.4, 0.4), CFrame = CFrame.new(x, Config.pathY(x) + rng:NextNumber(-20, 90), rng:NextNumber(-120, 120)), Color = WHITE, Material = M.Neon, Transparency = 0.55, CanCollide = false, CastShadow = false })
		end
	end
	if st.name == "Edge of Space" then
		for _ = 1, 25 do
			local x = rng:NextNumber(x0, x0 + L)
			ball(f, rng:NextNumber(1, 2.5), Vector3.new(x, Config.pathY(x) + rng:NextNumber(80, 250), rng:NextNumber(-300, 300)), C(255, 250, 210), { Material = M.Neon, CanCollide = false, CastShadow = false })
		end
	end
end

-- Space scenery -------------------------------------------------------------------------------
local function planet(f, center, size, color, props)
	local p = ball(f, size, center, color, { CanCollide = false, CastShadow = false })
	if props and props.glow then
		ball(f, size * 1.06, center, props.glow, { Material = M.Neon, Transparency = 0.85, CanCollide = false, CastShadow = false })
	end
	if props and props.ring then
		cyl(f, 1, size * 2.1, CFrame.new(center) * CFrame.Angles(0.35, 0, math.pi / 2 + 0.25), props.ring, { Transparency = 0.25, CanCollide = false, CastShadow = false })
		cyl(f, 1.1, size * 1.6, CFrame.new(center) * CFrame.Angles(0.35, 0, math.pi / 2 + 0.25), darker(props.ring, 0.2), { Transparency = 0.25, CanCollide = false, CastShadow = false })
	end
	return p
end

-- A banded gas giant: stacked slices with alternating colors.
local function gasGiant(f, center, radius, colors)
	local n = 11
	for i = 0, n - 1 do
		local y0 = -radius + (i + 0.5) * (2 * radius / n)
		local r = math.sqrt(math.max(0, radius * radius - y0 * y0))
		cyl(f, 2 * radius / n + 0.5, r * 2, CFrame.new(center + Vector3.new(0, y0, 0)) * UP, colors[(i % #colors) + 1], { CanCollide = false, CastShadow = false })
	end
end

local function satellite(f, p, rng)
	part(f, { Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(p), Color = C(230, 230, 240), Material = M.Metal })
	for _, side in ipairs({ -1, 1 }) do
		part(f, { Size = Vector3.new(4, 0.3, 14), CFrame = CFrame.new(p + Vector3.new(0, 0, side * 11)), Color = C(60, 90, 200), Material = M.Glass })
	end
	ball(f, 3, p + Vector3.new(0, 4, 0), WHITE)
end

local function spaceScenery(f, s, st, rng)
	local x0 = Config.LAUNCH_X + (s - 1) * L
	local mid = x0 + L / 2
	local y = Config.SKY_RISE
	-- asteroids + far stars everywhere
	local asteroidCount = st.name == "Asteroid Belt" and 40 or 14
	for _ = 1, asteroidCount do
		local z = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(60, 300)
		local size = rng:NextNumber(6, st.name == "Asteroid Belt" and 34 or 24)
		part(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(rng:NextNumber(x0, x0 + L), y + rng:NextNumber(-120, 160), z), Color = C(120, 105, 95):Lerp(C(80, 70, 70), rng:NextNumber()), Material = M.Slate, CanCollide = false })
	end
	for _ = 1, 30 do
		ball(f, rng:NextNumber(1.5, 3.5), Vector3.new(rng:NextNumber(x0, x0 + L), y + rng:NextNumber(-250, 400), (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(150, 520)), C(255, 250, 220), { Material = M.Neon, CanCollide = false, CastShadow = false })
	end
	satellite(f, Vector3.new(rng:NextNumber(x0 + 50, x0 + L - 50), y + rng:NextNumber(30, 80), (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(60, 120)), rng)

	local name = st.name
	if name == "Low Orbit" then
		planet(f, Vector3.new(mid, y - 1180, 0), 2000, C(60, 140, 240), { glow = C(140, 210, 255) })
		for _ = 1, 8 do
			local a, b = rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5)
			local dir = Vector3.new(a, 1, b).Unit
			ball(f, rng:NextNumber(180, 320), Vector3.new(mid, y - 1180, 0) + dir * 960, C(90, 190, 90), { Material = M.Grass, CanCollide = false, CastShadow = false })
		end
	elseif name == "The Moon" then
		local center = Vector3.new(mid, y - 900, 0)
		planet(f, center, 1500, C(205, 205, 210))
		for _ = 1, 14 do
			local dir = Vector3.new(rng:NextNumber(-0.45, 0.45), 1, rng:NextNumber(-0.45, 0.45)).Unit
			ball(f, rng:NextNumber(60, 160), center + dir * 735, C(165, 165, 172), { CanCollide = false, CastShadow = false })
		end
	elseif name == "Mars" then
		planet(f, Vector3.new(mid, y + 120, -820), 900, C(215, 100, 60), { glow = C(255, 160, 120) })
	elseif name == "Jupiter" then
		gasGiant(f, Vector3.new(mid, y + 150, 900), 480, { C(225, 180, 130), C(200, 140, 100), C(240, 215, 180), C(185, 120, 90) })
	elseif name == "Saturn Rings" then
		planet(f, Vector3.new(mid, y + 100, -800), 620, C(235, 210, 150), { ring = C(220, 195, 150) })
	elseif name == "Purple Nebula" then
		for _ = 1, 9 do
			ball(f, rng:NextNumber(160, 340), Vector3.new(rng:NextNumber(x0, x0 + L), y + rng:NextNumber(-80, 260), (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(250, 500)), pick(rng, { C(200, 90, 255), C(255, 100, 200), C(100, 140, 255) }), { Material = M.Neon, Transparency = 0.82, CanCollide = false, CastShadow = false })
		end
	elseif name == "Ice Giant" then
		planet(f, Vector3.new(mid, y + 60, 850), 800, C(110, 210, 240), { glow = C(180, 240, 255), ring = C(170, 230, 250) })
	elseif name == "Black Hole" then
		local c = Vector3.new(mid, y + 140, -650)
		for i, col in ipairs({ C(255, 230, 120), C(255, 150, 50), C(220, 70, 40) }) do
			cyl(f, 2 + i, 520 + i * 200, CFrame.new(c) * CFrame.Angles(0.3, 0, math.pi / 2 + 0.2), col, { Material = M.Neon, Transparency = 0.2 + i * 0.18, CanCollide = false, CastShadow = false })
		end
		ball(f, 300, c, C(5, 5, 10), { CanCollide = false, CastShadow = false })
	elseif name == "Galaxy Core" then
		-- the glowing finish line star, straight ahead
		local c = Vector3.new(x0 + L + 700, y + 120, 0)
		ball(f, 520, c, C(255, 225, 110), { Material = M.Neon, CanCollide = false, CastShadow = false })
		ball(f, 760, c, C(255, 200, 120), { Material = M.Neon, Transparency = 0.8, CanCollide = false, CastShadow = false })
	end
end

-- Gates + signs ---------------------------------------------------------------------------------
local ZONE_ACCENT = { Earth = C(255, 160, 40), Sky = C(90, 180, 255), Space = C(190, 100, 255) }

-- A big arch with striped pillars, a stage banner and a glowing barrier (hidden by the client once unlocked).
local function gate(f, s)
	local nextStage = Config.Stages[s + 1]
	local x1 = Config.LAUNCH_X + s * L
	local base = Config.pathY(x1)
	local accent = ZONE_ACCENT[nextStage.zone]
	local g = Instance.new("Model")
	g.Name = "Gate"
	g:SetAttribute("Stage", s + 1)
	g.Parent = f
	local W, H, R = 50, 64, 50
	for _, side in ipairs({ -1, 1 }) do
		local foot = Vector3.new(x1, base - 8, side * W)
		column(g, H + 8, 8, foot, WHITE)
		for i = 0, 3 do
			column(g, 4, 8.4, foot + Vector3.new(0, 14 + i * 16, 0), accent)
		end
		column(g, 3, 11, foot, darker(accent, 0.2))
		ball(g, 11, foot + Vector3.new(0, H + 8, 0), C(255, 215, 60))
	end
	-- semicircle arch on top
	local center = Vector3.new(x1, base + H, 0)
	for k = 0, 13 do
		local a1, a2 = k / 14 * math.pi, (k + 1) / 14 * math.pi
		local p1 = center + Vector3.new(0, math.sin(a1) * R, math.cos(a1) * R)
		local p2 = center + Vector3.new(0, math.sin(a2) * R, math.cos(a2) * R)
		beam(g, p1, p2, 6, k % 2 == 0 and accent or WHITE)
	end
	-- banner hanging under the top of the arch
	local banner = part(g, { Name = "Banner", Size = Vector3.new(1.5, 9, 54), CFrame = CFrame.new(x1, base + H + 26, 0), Color = accent })
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		local l = sign(banner, face, "STAGE " .. (s + 1) .. " - " .. nextStage.name, WHITE, accent, darker(accent, 0.5))
		l.Parent.PixelsPerStud = 18
	end
	for _, side in ipairs({ -1, 1 }) do
		beam(g, Vector3.new(x1, base + H + 30.5, side * 20), Vector3.new(x1, base + H + R - 1, side * 14), 0.4, C(60, 60, 70))
	end
	-- the barrier: a rectangle + stacked strips that fill the round top (no overlaps)
	local barrierProps = { Name = "Barrier", Color = C(255, 70, 90), Material = M.Neon, Transparency = 0.55, CanCollide = false, CanQuery = false, CastShadow = false }
	local function barrierPart(size, cf)
		local t = table.clone(barrierProps)
		t.Size = size
		t.CFrame = cf
		return part(g, t)
	end
	local inner = W - 4
	local lower = barrierPart(Vector3.new(1, H, inner * 2), CFrame.new(x1, base + H / 2, 0))
	local stripH = 6
	for dy = 0, R - 8, stripH do
		local half = math.sqrt(math.max(0, (R - 4) ^ 2 - (dy + stripH) ^ 2))
		if half > 2 then
			barrierPart(Vector3.new(1, stripH, half * 2), CFrame.new(x1, base + H + dy + stripH / 2, 0))
		end
	end
	local lock = sign(lower, Enum.NormalId.Left, "🔒 STAGE " .. (s + 1) .. "\n$" .. Config.abbreviate(Config.stageCost(s + 1)), C(255, 240, 240), nil, C(120, 0, 30))
	lock.Name = "LockText"
	lock.Size = UDim2.fromScale(0.5, 0.3)
	lock.Position = UDim2.fromScale(0.25, 0.3)
end

-- Distance markers every 100m: a round sign on a striped post (floating holo-signs in the sky/space)
local function distanceSigns(f, s, st)
	local x0 = Config.LAUNCH_X + (s - 1) * L
	local accent = ZONE_ACCENT[st.zone]
	for d = 100, L - 1, 100 do
		local x = x0 + d
		local z = -(HALF + 10)
		local y
		if st.zone == "Earth" then
			y = TerrainBuilder.height(x, z)
			column(f, 9, 1, Vector3.new(x, y - 1, z), WHITE)
			column(f, 2, 1.1, Vector3.new(x, y + 2, z), accent)
		else
			y = Config.pathY(x) + 2
		end
		local board = cyl(f, 0.6, 10, CFrame.new(x, y + 11, z), WHITE, { CastShadow = false })
		cyl(f, 0.5, 10.8, CFrame.new(x + 0.1, y + 11, z), accent, { CastShadow = false })
		local l = sign(board, Enum.NormalId.Left, Config.meters(x - Config.LAUNCH_X), darker(accent, 0.35), nil, WHITE)
		l.Size = UDim2.fromScale(0.86, 0.5)
		l.Position = UDim2.fromScale(0.07, 0.25)
	end
end

-- Public ------------------------------------------------------------------------------------------
function Scenery.buildStage(f, s)
	local st = Config.Stages[s]
	local rng = Random.new(s * 15485863)
	if st.zone == "Earth" then
		earthRoad(f, s)
		decorateEarth(f, s)
	elseif st.zone == "Sky" then
		skyRoad(f, s, st, rng)
		skyScenery(f, s, st, rng)
	else
		spaceRoad(f, s)
		spaceScenery(f, s, st, rng)
	end
	distanceSigns(f, s, st)
	if s < Config.NUM_STAGES then
		gate(f, s)
	end
end

Scenery.Decor = D
return Scenery
