-- The Hatchery (Eggs v2, design/features/eggs-v2): the meadow behind the spawn. A walk runs west
-- from the spawn plaza through three areas - Earth (eggs 1-5), Sky (6-10, a cloud floor), Space
-- (11-15, a dark star floor) - each starting under an arch. Every egg stands on its own diorama that
-- matches it (sand dune + pyramid, snow + ice crystals, basalt + lava pool, launch pad, moon
-- crater...), facing the walk, with a board (name / price / lock) and an E prompt.
-- Only the static scenery is built here; HatcheryClient animates the eggs (bob, orbiting props,
-- particles, light) near the player. Generated props live in ReplicatedStorage.EggProps and the
-- eggs in ReplicatedStorage.EggModels (place-only).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(ServerScriptService.BuildKit)
local Foliage = require(ServerScriptService.Foliage)
local LobbyLayout = require(ServerScriptService.LobbyLayout)

local part, ball, cyl, beam, sign = Kit.part, Kit.ball, Kit.cyl, Kit.beam, Kit.sign
local darker, lighter = Kit.darker, Kit.lighter
local UP = Kit.UP
local C = Color3.fromRGB
local M = Enum.Material
local WHITE = C(255, 255, 255)
local INK = C(30, 30, 50)

local H = LobbyLayout.HATCHERY
local FLOOR = 0.3 -- top of the walk / floors (just above the terrain)

local Hatchery = {}

-- Small helpers -----------------------------------------------------------------------------------
local function deco(t) -- props for decoration: no collision, no queries, no shadow spam
	t.CanCollide = false
	t.CanQuery = false
	t.CanTouch = false
	return t
end

local function slab(parent, cf, size, color, mat, props)
	local t = { Size = size, CFrame = cf, Color = color, Material = mat or M.SmoothPlastic, CastShadow = false }
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return part(parent, t)
end

-- an upright disc of height h standing on y = bottom
local function disc(parent, center, r, bottom, h, color, mat, props)
	local t = { Material = mat or M.SmoothPlastic, CastShadow = false }
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return cyl(parent, h, r * 2, CFrame.new(center.X, bottom + h / 2, center.Z) * UP, color, t)
end

-- a squashed / stretched ball (Shape = Ball parts are always round)
local function blob(parent, size, pos, color, mat, props)
	local t = { Size = size, CFrame = CFrame.new(pos), Color = color, Material = mat or M.SmoothPlastic, CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false }
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	local p = part(parent, t)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- a Creator Store prop from the lobby pack (ServerStorage.LobbyProps: Fern1, Bush, Plant, ...)
local LOBBY_PROPS = game:GetService("ServerStorage"):FindFirstChild("LobbyProps")
local function lobbyProp(parent, name, pos, yaw, scale)
	local t = LOBBY_PROPS and LOBBY_PROPS:FindFirstChild(name)
	if not t then
		return nil
	end
	local m = t:Clone()
	if scale and scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
		end
	end
	m.Parent = parent
	return m
end

local function prop(parent, name, cf, scale)
	local folder = ReplicatedStorage:FindFirstChild("EggProps")
	local t = folder and folder:FindFirstChild(name)
	if not t then
		return nil
	end
	local m = t:Clone()
	if scale and scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	m:PivotTo(cf)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	m.Parent = parent
	return m
end

-- point on the diorama: `along` toward the walk (negative = behind the egg), `across` sideways
local function at(p, f, along, across, y)
	local right = Vector3.new(f.Z, 0, -f.X)
	return p + f * along + right * across + Vector3.new(0, y or 0, 0)
end

-- Dioramas --------------------------------------------------------------------------------------
-- Each builds the scenery around stand position p (facing f = toward the walk) and returns the
-- height of the top it puts the egg on.
local D = {}

function D.Meadow(m, p, f, rng)
	disc(m, p, 6.4, 0, 0.7, C(150, 110, 70), M.Ground)
	disc(m, p, 6, 0.2, 0.7, C(120, 205, 80), M.Grass)
	-- stump plinth
	disc(m, p, 2.2, 0.9, 1.4, C(150, 100, 60), M.Wood)
	disc(m, p, 1.9, 2.25, 0.12, C(220, 180, 120), M.Wood)
	-- flowers + mushrooms on the back half
	for i = 1, 14 do
		local a = math.rad(rng:NextNumber(-160, 160))
		local r = rng:NextNumber(3, 5.6)
		local q = p + Vector3.new(math.cos(a) * r, 0.95, math.sin(a) * r)
		if (q - p):Dot(f) < 2.5 then
			local col = ({ C(255, 255, 255), C(255, 220, 70), C(255, 140, 190), C(150, 120, 255) })[rng:NextInteger(1, 4)]
			part(m, deco({ Size = Vector3.new(0.2, 0.7, 0.2), CFrame = CFrame.new(q + Vector3.new(0, 0.35, 0)), Color = C(80, 160, 60) }))
			ball(m, 0.55, q + Vector3.new(0, 0.75, 0), col, deco({}))
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		local q = at(p, f, -3.6, s * 3.2, 0.9)
		part(m, deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 0.5, 0.5), CFrame = CFrame.new(q + Vector3.new(0, 0.6, 0)) * UP, Color = C(250, 240, 220) }))
		blob(m, Vector3.new(1.7, 0.9, 1.7), q + Vector3.new(0, 1.3, 0), C(235, 70, 70))
	end
	-- a little picket fence arc behind
	for i = -4, 4 do
		local a = i * 0.28
		local back = -f
		local dir = Vector3.new(back.X * math.cos(a) - back.Z * math.sin(a), 0, back.X * math.sin(a) + back.Z * math.cos(a))
		part(m, deco({ Size = Vector3.new(0.35, 1.6, 0.18), CFrame = CFrame.lookAt(p + dir * 6.1 + Vector3.new(0, 1.7, 0), p + Vector3.new(0, 1.7, 0)), Color = WHITE }))
	end
	return 2.37
end

function D.Ancient(m, p, f, rng)
	local sand = C(232, 200, 140)
	disc(m, p, 6.6, 0, 0.6, darker(sand, 0.15), M.Sand)
	blob(m, Vector3.new(12.6, 1.6, 12.6), p + Vector3.new(0, 0.35, 0), sand, M.Sand)
	-- sandstone plinth with gold trim
	slab(m, CFrame.new(p + Vector3.new(0, 1.6, 0)), Vector3.new(3.6, 1.6, 3.6), C(220, 180, 110), M.Sandstone)
	slab(m, CFrame.new(p + Vector3.new(0, 2.45, 0)), Vector3.new(4, 0.2, 4), C(255, 200, 60), M.SmoothPlastic)
	-- the mini pyramid behind
	local back = at(p, f, -4.6, 0, 0)
	if not prop(m, "Pyramid", CFrame.lookAt(back + Vector3.new(0, 0.6, 0), back + Vector3.new(0, 0.6, 0) + f), 0.9) then
		for k = 0, 3 do
			slab(m, CFrame.lookAt(back + Vector3.new(0, 0.8 + k * 1.1, 0), back + Vector3.new(0, 0.8 + k * 1.1, 0) + f), Vector3.new(7 - k * 1.7, 1.1, 7 - k * 1.7), C(222, 186, 116), M.Sandstone, deco({}))
		end
		slab(m, CFrame.new(back + Vector3.new(0, 5.2, 0)), Vector3.new(1, 0.8, 1), C(255, 200, 60), M.SmoothPlastic, deco({}))
	end
	-- broken pillars + bones in the sand
	for _, s in ipairs({ -1, 1 }) do
		local q = at(p, f, -1.5, s * 4.7, 0.6)
		local h = s > 0 and 3.6 or 2.2
		cyl(m, h, 1.3, CFrame.new(q + Vector3.new(0, h / 2, 0)) * UP, C(225, 190, 125), deco({ Material = M.Sandstone }))
		cyl(m, 0.4, 1.7, CFrame.new(q + Vector3.new(0, h + 0.2, 0)) * UP, C(210, 175, 110), deco({ Material = M.Sandstone }))
	end
	for i = 1, 2 do
		prop(m, "Bone", CFrame.new(at(p, f, 2.6 - i * 1.4, (i == 1 and -1 or 1) * 3.4, 1.1)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.15), 0.7)
	end
	return 2.55
end

function D.Jungle(m, p, f, rng)
	disc(m, p, 6.4, 0, 0.7, C(70, 60, 45), M.Ground)
	disc(m, p, 6, 0.2, 0.7, C(55, 140, 60), M.LeafyGrass)
	-- mossy rock plinth
	blob(m, Vector3.new(4.2, 3.4, 4.2), p + Vector3.new(0, 1.2, 0), C(120, 130, 120), M.Slate)
	disc(m, p, 1.9, 2.55, 0.15, C(80, 160, 70), M.Grass)
	-- a small pond with lily pads at the side
	local pond = at(p, f, 1.2, -3.8, 0)
	disc(m, pond, 1.9, 0.85, 0.12, C(70, 170, 200), M.Glass, deco({ Transparency = 0.2 }))
	disc(m, pond + Vector3.new(0.6, 0, 0.3), 0.45, 0.98, 0.06, C(90, 190, 80), M.SmoothPlastic, deco({}))
	-- jungle plants behind: ferns, bushes, a tall plant
	local plants = { "Fern1", "Fern2", "Bush", "Plant", "Fern1", "Bush", "Fern2" }
	for i, name in ipairs(plants) do
		local a = math.rad(-70 + (i - 1) * (140 / (#plants - 1)) + rng:NextNumber(-8, 8))
		local back = -f
		local dir = Vector3.new(back.X * math.cos(a) - back.Z * math.sin(a), 0, back.X * math.sin(a) + back.Z * math.cos(a))
		lobbyProp(m, name, p + dir * rng:NextNumber(4, 5.6) + Vector3.new(0, 0.9, 0), rng:NextNumber(0, 360), name == "Bush" and 0.9 or 1.3)
	end
	return 2.65
end

function D.IceAge(m, p, f, rng)
	disc(m, p, 6.6, 0, 0.6, C(200, 220, 235), M.Snow)
	for i = 1, 6 do
		local a = math.rad(i * 60 + rng:NextNumber(-20, 20))
		ball(m, rng:NextNumber(2.2, 3.4), p + Vector3.new(math.cos(a) * 5.4, 0.6, math.sin(a) * 5.4), C(245, 250, 255), deco({ Material = M.Snow }))
	end
	-- clear ice block plinth
	slab(m, CFrame.new(p + Vector3.new(0, 1.55, 0)) * CFrame.Angles(0, math.rad(20), 0), Vector3.new(3.4, 1.9, 3.4), C(170, 220, 255), M.Glass, { Transparency = 0.25 })
	slab(m, CFrame.new(p + Vector3.new(0, 2.55, 0)) * CFrame.Angles(0, math.rad(20), 0), Vector3.new(3.6, 0.15, 3.6), WHITE, M.Snow)
	-- ice crystals behind
	local back = at(p, f, -4.2, 0, 0.5)
	if not prop(m, "IceCrystals", CFrame.lookAt(back, back + f), 0.9) then
		for i = 1, 5 do
			local q = at(p, f, -4 - rng:NextNumber(0, 1.2), rng:NextNumber(-3, 3), 0.5)
			local h = rng:NextNumber(2.5, 5)
			slab(m, CFrame.new(q + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Vector3.new(0.9, h, 0.9), C(150, 210, 255), M.Glass, deco({ Transparency = 0.15 }))
		end
	end
	return 2.62
end

function D.Magma(m, p, f, rng)
	disc(m, p, 6.6, 0, 0.6, C(50, 40, 40), M.Basalt)
	-- a lava moat round the plinth
	disc(m, p, 3.6, 0.55, 0.12, C(255, 120, 30), M.Neon, deco({}))
	disc(m, p, 2.4, 0.5, 0.25, C(40, 32, 34), M.Basalt)
	-- obsidian plinth
	cyl(m, 1.9, 3.6, CFrame.new(p + Vector3.new(0, 1.55, 0)) * UP, C(30, 24, 30), { Material = M.Glass, Reflectance = 0.05, CastShadow = false })
	disc(m, p, 1.8, 2.5, 0.1, C(255, 140, 40), M.Neon, deco({}))
	-- lava rocks behind
	local back = at(p, f, -4.4, 0, 0.5)
	if not prop(m, "LavaRocks", CFrame.lookAt(back, back + f), 1) then
		for i = 1, 6 do
			local q = at(p, f, -4 - rng:NextNumber(0, 1.5), rng:NextNumber(-4, 4), 0.6)
			ball(m, rng:NextNumber(1.4, 2.6), q, C(45, 38, 40), deco({ Material = M.Basalt }))
		end
	end
	-- a smoking vent at the side
	local vent = at(p, f, 0.5, 4.6, 0.6)
	cyl(m, 1.2, 1.6, CFrame.new(vent + Vector3.new(0, 0.6, 0)) * UP, C(60, 50, 50), deco({ Material = M.Basalt }))
	local smoke = part(m, deco({ Name = "Vent", Size = Vector3.one, CFrame = CFrame.new(vent + Vector3.new(0, 1.3, 0)), Transparency = 1 }))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(C(90, 80, 80))
	e.Size = NumberSequence.new(0.8, 2.2)
	e.Transparency = NumberSequence.new(0.5, 1)
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(2, 3)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Rate = 3
	e.Parent = smoke
	return 2.55
end

local function cloudFloor(m, p, r, y, rng, color)
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		ball(m, rng:NextNumber(2.4, 3.4), p + Vector3.new(math.cos(a) * r, y, math.sin(a) * r), color or WHITE, deco({}))
	end
	disc(m, p, r, y - 0.6, 1.2, color or WHITE)
end

function D.Cloud(m, p, f, rng)
	cloudFloor(m, p, 5.6, 0.7, rng)
	-- golden pillars behind with ball tops
	for _, s in ipairs({ -1, 1 }) do
		local q = at(p, f, -3.6, s * 3.6, 1.3)
		cyl(m, 4.6, 0.8, CFrame.new(q + Vector3.new(0, 2.3, 0)) * UP, C(255, 210, 90), deco({ Material = M.SmoothPlastic }))
		ball(m, 1.1, q + Vector3.new(0, 4.8, 0), C(255, 225, 120), deco({}))
	end
	-- cloud plinth with a gold ring
	blob(m, Vector3.new(3.8, 2.2, 3.8), p + Vector3.new(0, 2, 0), WHITE)
	cyl(m, 0.25, 4, CFrame.new(p + Vector3.new(0, 2.4, 0)) * UP, C(255, 210, 90), deco({}))
	return 2.95
end

function D.Thunder(m, p, f, rng)
	disc(m, p, 6.4, 0, 0.6, C(70, 72, 85), M.Slate)
	for i = 1, 3 do
		local q = at(p, f, rng:NextNumber(-3, 2.5), rng:NextNumber(-4.5, 4.5), 0.61)
		disc(m, q, rng:NextNumber(0.6, 1.1), 0.6, 0.04, C(90, 110, 140), M.Glass, deco({ Transparency = 0.3 }))
	end
	-- dark stone plinth with yellow trim
	slab(m, CFrame.new(p + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(3.2, 1.8, 3.2), C(55, 58, 70), M.Slate)
	slab(m, CFrame.new(p + Vector3.new(0, 2.45, 0)) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(3.4, 0.12, 3.4), C(255, 230, 60), M.Neon, deco({}))
	-- a lightning rod behind
	local q = at(p, f, -4.3, 2.5, 0.6)
	cyl(m, 7, 0.35, CFrame.new(q + Vector3.new(0, 3.5, 0)) * UP, C(170, 175, 190), deco({ Material = M.Metal }))
	ball(m, 0.7, q + Vector3.new(0, 7.1, 0), C(255, 240, 120), deco({ Material = M.Neon }))
	return 2.5
end

function D.SkyIsland(m, p, f, rng)
	-- the diorama floats: a grassy island on a rock cone
	local y0 = 1.4
	disc(m, p, 5.8, y0, 1, C(120, 200, 80), M.Grass)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		ball(m, rng:NextNumber(2.4, 3.2), p + Vector3.new(math.cos(a) * 4, y0 - 0.6, math.sin(a) * 4), C(150, 110, 75), deco({ Material = M.Rock }))
	end
	blob(m, Vector3.new(9, 5, 9), p + Vector3.new(0, y0 - 1.4, 0), C(140, 100, 70), M.Rock)
	-- a waterfall off the side
	local q = at(p, f, -1, 5.7, 0)
	slab(m, CFrame.new(q + Vector3.new(0, y0 - 0.5, 0)), Vector3.new(1.6, 3, 0.4), C(120, 200, 255), M.Glass, deco({ Transparency = 0.25 }))
	-- little trees behind
	for _, s in ipairs({ -1, 1 }) do
		local t = at(p, f, -3.6, s * 3, y0 + 1)
		cyl(m, 2.2, 0.5, CFrame.new(t + Vector3.new(0, 1.1, 0)) * UP, C(130, 90, 60), deco({ Material = M.Wood }))
		ball(m, 2.6, t + Vector3.new(0, 2.8, 0), C(110, 200, 90), deco({}))
	end
	disc(m, p, 1.8, y0 + 1, 0.5, C(200, 170, 120), M.Rock)
	return y0 + 1.5
end

function D.Aurora(m, p, f, rng)
	disc(m, p, 6.4, 0, 0.6, C(200, 235, 245), M.Glacier)
	-- crystal shards round the back
	for i = 1, 9 do
		local a = math.rad(-75 + i * 17)
		local back = -f
		local dir = Vector3.new(back.X * math.cos(a) - back.Z * math.sin(a), 0, back.X * math.sin(a) + back.Z * math.cos(a))
		local h = rng:NextNumber(1.8, 4.6)
		local q = p + dir * rng:NextNumber(4.4, 5.6) + Vector3.new(0, 0.6, 0)
		local col = (i % 2 == 0) and C(150, 255, 210) or C(200, 160, 255)
		slab(m, CFrame.new(q + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6), rng:NextNumber(-0.25, 0.25)), Vector3.new(0.8, h, 0.8), col, M.Glass, deco({ Transparency = 0.2 }))
	end
	-- crystal plinth
	cyl(m, 1.8, 3.2, CFrame.new(p + Vector3.new(0, 1.5, 0)) * UP, C(190, 240, 255), { Material = M.Glass, Transparency = 0.2, CastShadow = false })
	return 2.4
end

function D.JetStream(m, p, f, rng)
	-- a little launch pad: dark round pad with hazard stripes
	disc(m, p, 6.4, 0, 0.6, C(60, 64, 75), M.DiamondPlate)
	for i = 0, 11 do
		if i % 2 == 0 then
			local a = i / 12 * math.pi * 2
			slab(m, CFrame.new(p + Vector3.new(0, 0.62, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 5.7), Vector3.new(2.6, 0.06, 0.9), C(255, 200, 40), M.SmoothPlastic, deco({}))
		end
	end
	-- the plinth: a steel hexagon with blue lights
	cyl(m, 1.6, 3.4, CFrame.new(p + Vector3.new(0, 1.4, 0)) * UP, C(190, 195, 210), { Material = M.Metal, CastShadow = false })
	disc(m, p, 1.75, 2.2, 0.1, C(80, 170, 255), M.Neon, deco({}))
	-- a gantry tower behind
	local q = at(p, f, -4.4, -2.8, 0.6)
	for _, o in ipairs({ Vector3.new(-0.7, 0, -0.7), Vector3.new(0.7, 0, -0.7), Vector3.new(-0.7, 0, 0.7), Vector3.new(0.7, 0, 0.7) }) do
		cyl(m, 8, 0.25, CFrame.new(q + o + Vector3.new(0, 4, 0)) * UP, C(220, 70, 60), deco({ Material = M.Metal }))
	end
	for k = 1, 4 do
		slab(m, CFrame.new(q + Vector3.new(0, k * 1.9, 0)), Vector3.new(1.7, 0.18, 1.7), C(220, 70, 60), M.Metal, deco({}))
	end
	ball(m, 0.5, q + Vector3.new(0, 8.3, 0), C(255, 80, 80), deco({ Material = M.Neon }))
	-- traffic cones
	for _, s in ipairs({ -1, 1 }) do
		local c = at(p, f, 2.6, s * 4.4, 0.6)
		cyl(m, 0.9, 0.6, CFrame.new(c + Vector3.new(0, 0.45, 0)) * UP, C(255, 130, 30), deco({}))
	end
	return 2.25
end

function D.Moon(m, p, f, rng)
	disc(m, p, 6.6, 0, 0.6, C(185, 188, 195), M.Slate)
	for i = 1, 5 do
		local q = at(p, f, rng:NextNumber(-4, 3), rng:NextNumber(-4.5, 4.5), 0)
		disc(m, q, rng:NextNumber(0.6, 1.2), 0.55, 0.1, C(150, 152, 160), M.Slate, deco({}))
	end
	-- moon-rock plinth
	blob(m, Vector3.new(3.8, 2.8, 3.8), p + Vector3.new(0, 1.1, 0), C(170, 172, 180), M.Slate)
	disc(m, p, 1.7, 2.3, 0.15, C(150, 152, 160), M.Slate)
	-- a lander + flag behind
	local back = at(p, f, -4.4, 2, 0.6)
	prop(m, "LunarLander", CFrame.lookAt(back, back + f), 0.7)
	local fl = at(p, f, -3.4, -3.6, 0.6)
	cyl(m, 4, 0.18, CFrame.new(fl + Vector3.new(0, 2, 0)) * UP, C(220, 220, 225), deco({ Material = M.Metal }))
	slab(m, CFrame.lookAt(fl + Vector3.new(0, 3.4, 0), fl + Vector3.new(0, 3.4, 0) + f) * CFrame.new(0.7, 0, 0), Vector3.new(1.4, 0.9, 0.06), C(255, 120, 60), M.SmoothPlastic, deco({}))
	return 2.45
end

function D.Mars(m, p, f, rng)
	disc(m, p, 6.6, 0, 0.6, C(190, 95, 60), M.Sandstone)
	-- red rock pillars behind (a tiny canyon)
	for i = 1, 4 do
		local q = at(p, f, -4.2 - rng:NextNumber(0, 1), -4 + i * 1.9, 0.6)
		local h = rng:NextNumber(2.4, 5)
		slab(m, CFrame.new(q + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(1.8, h, 1.6), C(180 + rng:NextInteger(0, 30), 80, 50), M.Sandstone, deco({}))
	end
	-- pink crystals at the side
	for i = 1, 4 do
		local q = at(p, f, 1.5 + rng:NextNumber(-1, 1), 4.4 + rng:NextNumber(-0.6, 0.6), 0.6)
		local h = rng:NextNumber(1.2, 2.6)
		slab(m, CFrame.new(q + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), Vector3.new(0.5, h, 0.5), C(255, 120, 190), M.Neon, deco({ Transparency = 0.15 }))
	end
	-- the rover
	local r = at(p, f, 1.6, -4.2, 0.6)
	prop(m, "MarsRover", CFrame.lookAt(r, r + f), 0.6)
	-- red rock plinth
	slab(m, CFrame.new(p + Vector3.new(0, 1.5, 0)), Vector3.new(3.6, 1.8, 3.6), C(170, 75, 45), M.Sandstone)
	return 2.4
end

local function ring(m, center, r, width, color, pieces, tilt)
	for k = 0, pieces - 1 do
		local a1, a2 = k / pieces * math.pi * 2, (k + 1) / pieces * math.pi * 2
		local p1 = center + (tilt or CFrame.new()):VectorToWorldSpace(Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r))
		local p2 = center + (tilt or CFrame.new()):VectorToWorldSpace(Vector3.new(math.cos(a2) * r, 0, math.sin(a2) * r))
		local b = beam(m, p1, p2, 0.3, color, deco({ Material = M.Neon }))
		b.Size = Vector3.new(width, 0.25, (p2 - p1).Magnitude + 0.1)
	end
end

local function spaceFloor(m, p, color, rim)
	disc(m, p, 6.6, 0, 0.6, color, M.Glass, { Reflectance = 0.05 })
	ring(m, p + Vector3.new(0, 0.66, 0), 6.3, 0.35, rim, 28)
end

function D.GasGiant(m, p, f, rng)
	spaceFloor(m, p, C(30, 34, 60), C(255, 200, 100))
	-- two little banded planets floating behind
	for i, s in ipairs({ -1, 1 }) do
		local q = at(p, f, -3.8, s * 3.2, 4 + i)
		ball(m, 2.2 + i * 0.4, q, i == 1 and C(230, 170, 110) or C(200, 190, 160), deco({}))
		ring(m, q, 1.9 + i * 0.4, 0.25, C(255, 220, 140), 16, CFrame.Angles(0.4, 0, 0.3))
	end
	-- gold plinth
	cyl(m, 1.6, 3.2, CFrame.new(p + Vector3.new(0, 1.4, 0)) * UP, C(255, 200, 90), { Material = M.SmoothPlastic, CastShadow = false })
	return 2.2
end

function D.Nebula(m, p, f, rng)
	-- a purple crystal asteroid
	blob(m, Vector3.new(13.5, 3, 13.5), p + Vector3.new(0, 0.1, 0), C(80, 50, 110), M.Rock)
	local back = at(p, f, -4, 0, 0.8)
	if not prop(m, "SpaceCrystals", CFrame.lookAt(back, back + f), 0.85) then
		for i = 1, 6 do
			local q = at(p, f, -4 - rng:NextNumber(0, 1), rng:NextNumber(-3.5, 3.5), 0.8)
			local h = rng:NextNumber(2, 4.5)
			slab(m, CFrame.new(q + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Vector3.new(0.8, h, 0.8), C(220, 120, 255), M.Neon, deco({ Transparency = 0.25 }))
		end
	end
	-- glowing pools
	for _, s in ipairs({ -1, 1 }) do
		disc(m, at(p, f, 2.2, s * 3.8, 0), 1.2, 1.5, 0.08, C(255, 120, 220), M.Neon, deco({ Transparency = 0.3 }))
	end
	cyl(m, 1.4, 3.2, CFrame.new(p + Vector3.new(0, 2.1, 0)) * UP, C(120, 70, 170), { Material = M.Glass, Transparency = 0.1, CastShadow = false })
	return 2.8
end

function D.BlackHole(m, p, f, rng)
	spaceFloor(m, p, C(15, 10, 25), C(190, 90, 255))
	-- gold rings standing round the back
	for i, s in ipairs({ -1, 0, 1 }) do
		local q = at(p, f, -4.4 + math.abs(s) * 1.2, s * 3.6, 3.6)
		ring(m, q, 2.2 - i * 0.2, 0.3, C(255, 205, 90), 18, CFrame.lookAt(Vector3.zero, f) * CFrame.Angles(math.pi / 2, 0, 0))
	end
	-- obsidian plinth with purple glow
	cyl(m, 1.6, 3.4, CFrame.new(p + Vector3.new(0, 1.4, 0)) * UP, C(20, 15, 30), { Material = M.Glass, Reflectance = 0.1, CastShadow = false })
	disc(m, p, 1.75, 2.2, 0.1, C(190, 90, 255), M.Neon, deco({}))
	return 2.25
end

-- Floors + walk + arches ------------------------------------------------------------------------
local ZONE_FLOOR = {
	{ C(244, 230, 204), C(196, 150, 104), M.Cobblestone }, -- Earth: the lobby's cream stone
	{ C(250, 252, 255), C(170, 210, 245), M.SmoothPlastic }, -- Sky: cloud white with sky-blue edges
	{ C(35, 38, 70), C(120, 200, 255), M.Glass }, -- Space: dark glass with neon edges
}

local function zoneOf(x)
	local z = 1
	for i, zone in ipairs(H.zones) do
		if x <= zone.x then
			z = i
		end
	end
	return z
end

local function walk(m, rng)
	local bounds = { H.x0, H.zones[2].x, H.zones[3].x, H.x1 }
	for i = 1, 3 do
		local xa, xb = bounds[i], bounds[i + 1]
		local cx, len = (xa + xb) / 2, math.abs(xa - xb)
		local top, edge, mat = ZONE_FLOOR[i][1], ZONE_FLOOR[i][2], ZONE_FLOOR[i][3]
		slab(m, CFrame.new(cx, FLOOR - 0.25, 0), Vector3.new(len, 0.4, H.half * 2 + 2.4), edge, i == 3 and M.Neon or M.SmoothPlastic)
		slab(m, CFrame.new(cx, FLOOR - 0.2, 0), Vector3.new(len, 0.4, H.half * 2), top, mat)
		if i == 1 then
			-- Earth: trees behind the dioramas, flower beds along the walk
			for x = xa - 8, xb + 4, -17 do
				for _, s in ipairs({ -1, 1 }) do
					Foliage.tree(m, Vector3.new(x + rng:NextNumber(-3, 3), 0, s * rng:NextNumber(36, 44)), rng, rng:NextNumber(11, 15), "park")
				end
			end
			for x = xa - 18, xb + 4, -14.5 do
				for _, s in ipairs({ -1, 1 }) do
					for k = 1, 5 do
						local col = ({ C(255, 120, 150), C(255, 215, 70), C(255, 255, 255), C(160, 120, 255) })[rng:NextInteger(1, 4)]
						ball(m, 0.7, Vector3.new(x + rng:NextNumber(-3, 3), 0.5, s * (H.half + 2 + rng:NextNumber(0, 1.2))), col, deco({}))
					end
				end
			end
		elseif i == 2 then
			-- Sky: a soft cloud floor, puffs along the walk, clouds drifting above, a rainbow arch
			blob(m, Vector3.new(len + 10, 1.4, 74), Vector3.new(cx, -0.2, 0), C(248, 250, 255))
			for x = xa - 4, xb + 4, -6 do
				for _, s in ipairs({ -1, 1 }) do
					ball(m, rng:NextNumber(2.2, 3.4), Vector3.new(x + rng:NextNumber(-1.5, 1.5), 0.4, s * (H.half + 2.4 + rng:NextNumber(0, 1))), WHITE, deco({}))
				end
			end
			for _ = 1, 7 do
				local q = Vector3.new(rng:NextNumber(xb, xa), rng:NextNumber(18, 30), rng:NextNumber(-45, 45))
				for k = -1, 1 do
					ball(m, rng:NextNumber(4, 6) * (k == 0 and 1.3 or 1), q + Vector3.new(k * 3.2, k == 0 and 1 or 0, 0), WHITE, deco({}))
				end
			end
			local colors = { C(255, 90, 90), C(255, 170, 60), C(255, 230, 80), C(100, 220, 110), C(80, 170, 255), C(170, 110, 255) }
			for b, col in ipairs(colors) do
				local r = 15 - (b - 1) * 0.9
				for k = 0, 15 do
					local a1, a2 = k / 16 * math.pi, (k + 1) / 16 * math.pi
					local p1 = Vector3.new(cx, math.sin(a1) * r, math.cos(a1) * r)
					local p2 = Vector3.new(cx, math.sin(a2) * r, math.cos(a2) * r)
					beam(m, p1, p2, 0.9, col, deco({ Material = M.Neon, Transparency = 0.2 }))
				end
			end
		else
			-- Space: a round dark star platform with a neon rim, tiny stars, planets overhead
			local r = len / 2 + 6
			disc(m, Vector3.new(cx, 0, 0), r, -0.3, 0.45, C(22, 24, 48), M.SmoothPlastic, deco({}))
			ring(m, Vector3.new(cx, 0.18, 0), r - 0.4, 0.5, C(170, 110, 255), 48)
			for _ = 1, 90 do
				local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber(0, 1)) * (r - 1.5)
				ball(m, rng:NextNumber(0.2, 0.45), Vector3.new(cx + math.cos(a) * d, 0.2, math.sin(a) * d), C(255, 250, 220), deco({ Material = M.Neon }))
			end
			for k, pl in ipairs({ { C(230, 150, 90), 9, -28, 26 }, { C(120, 200, 230), 6, 34, 22 }, { C(190, 110, 255), 4.5, -6, 34 } }) do
				local q = Vector3.new(cx + (k - 2) * 22, pl[4], pl[3])
				ball(m, pl[2], q, pl[1], deco({}))
				if k == 1 then
					ring(m, q, pl[2] * 0.9, 0.6, C(255, 220, 140), 24, CFrame.Angles(0.35, 0, 0.2))
				end
			end
		end
	end
end

local function arch(m, zone)
	local x, col = zone.x, zone.color
	local w = H.half + 2.5
	for _, s in ipairs({ -1, 1 }) do
		cyl(m, 11, 1.6, CFrame.new(x, 5.5, s * w) * UP, darker(col, 0.15), { CastShadow = false })
		ball(m, 2.4, Vector3.new(x, 11.4, s * w), lighter(col, 0.2), deco({}))
	end
	local board = slab(m, CFrame.lookAt(Vector3.new(x, 11.4, 0), Vector3.new(x + 1, 11.4, 0)), Vector3.new(w * 2 - 1, 2.6, 0.6), col, M.SmoothPlastic, deco({}))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		sign(board, face, zone.name, WHITE, col, darker(col, 0.5))
	end
end

-- Egg stands --------------------------------------------------------------------------------------
local function board(parent, pos, egg)
	local anchor = part(parent, deco({ Name = "Board", Size = Vector3.one, CFrame = CFrame.new(pos), Transparency = 1 }))
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(8.5, 3.6) -- in studs, so far-away boards shrink and don't overlap
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.Parent = anchor
	local y = 0
	for _, l in ipairs({
		{ "Title", 0.42, egg.name, WHITE },
		{ "Price", 0.31, "$" .. Config.abbreviate(egg.price), C(130, 255, 130) },
		{ "Lock", 0.27, "Stage " .. egg.stage, C(255, 220, 120) },
	}) do
		local t = Instance.new("TextLabel")
		t.Name = l[1]
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0, y)
		t.Size = UDim2.fromScale(1, l[2])
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = l[3]
		t.TextColor3 = l[4]
		local st = Instance.new("UIStroke")
		st.Thickness = 2.5
		st.Color = INK
		st.Parent = t
		t.Parent = bb
		y += l[2]
	end
end

local function fallbackEgg(egg)
	local m = Instance.new("Model")
	local p = part(m, { Size = Vector3.new(3.8, 4.8, 3.8), CFrame = CFrame.new(0, 2.4, 0), Color = egg.color })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	m.PrimaryPart = p
	m.WorldPivot = CFrame.new()
	return m
end

local function stand(parent, i, egg)
	local pos, facing = LobbyLayout.eggStand(i)
	local m = Instance.new("Model")
	m.Name = "Egg_" .. egg.id
	m:SetAttribute("Egg", egg.id)
	m.Parent = parent
	local rng = Random.new(i * 97 + 13)
	local build = D[egg.id]
	local top = build and build(m, pos, facing, rng) or 2.4

	local template = ReplicatedStorage:FindFirstChild("EggModels") and ReplicatedStorage.EggModels:FindFirstChild(egg.id)
	local e = template and template:Clone() or fallbackEgg(egg)
	e.Name = "Egg"
	for _, d in ipairs(e:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	local base = CFrame.lookAt(pos + Vector3.new(0, top, 0), pos + Vector3.new(0, top, 0) + facing)
	e:PivotTo(base)
	e:SetAttribute("Home", base)
	e:SetAttribute("EggId", egg.id)
	e.Parent = m
	CollectionService:AddTag(e, "HatcheryEgg")
	local _, size = e:GetBoundingBox()

	board(m, pos + Vector3.new(0, top + size.Y + 3.2, 0), egg)
	local hit = part(m, deco({ Name = "PromptPart", Size = Vector3.new(5, 6, 5), CFrame = CFrame.new(pos + Vector3.new(0, top + 2, 0)), Transparency = 1 }))
	hit.CanQuery = true -- (the prompt needs it)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Open"
	p.ObjectText = egg.name
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p:SetAttribute("Egg", egg.id)
	p.Parent = hit
end

function Hatchery.build(hub)
	local m = Instance.new("Model")
	m.Name = "Hatchery"
	m.Parent = hub
	local rng = Random.new(2026)
	walk(m, rng)
	for _, zone in ipairs(H.zones) do
		arch(m, zone)
	end
	for i, egg in ipairs(Config.Eggs) do
		stand(m, i, egg)
	end
	return m
end

Hatchery.zoneOf = zoneOf
return Hatchery
