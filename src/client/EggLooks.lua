-- How each egg moves and glows (Eggs v2, design/features/eggs-v2): orbiting props (bones on a purple
-- magnetic force, molten rocks, storm clouds with electric arcs, mini jets with contrails, an
-- accretion disk...), particles and a light. Cheap eggs get a little, expensive eggs a lot.
--   local rig = EggLooks.attach(eggModel, eggId, { hatch = false })
--   rig.update(dt, t, power)   -- power 0 = idle in the lobby, up to ~3 while a hatch builds up
--   rig.destroy()
-- Props come from ReplicatedStorage.EggProps (generated meshes, place-only); missing ones fall back
-- to simple parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetFx = require(script.Parent:WaitForChild("PetFx"))

local EggLooks = {}
local C = Color3.fromRGB
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local emitter = PetFx.emitter

local function seq(a, b)
	return ColorSequence.new(a, b or a)
end

local function newPart(parent, t)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(t) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- Orbiter makers: return a Model or BasePart (centred on its pivot), scaled for egg size k.
local MAKE = {}

local function fromProp(name, size, fallback)
	return function(parent, k)
		local folder = ReplicatedStorage:FindFirstChild("EggProps")
		local t = folder and folder:FindFirstChild(name)
		if t then
			local m = t:Clone()
			local _, s = m:GetBoundingBox()
			m:ScaleTo(m:GetScale() * (size * k) / math.max(s.X, s.Y, s.Z, 0.01))
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
				end
			end
			m.Parent = parent
			return m
		end
		return fallback(parent, k)
	end
end

local function ballMaker(size, color, mat)
	return function(parent, k)
		return newPart(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * size * k, Color = color, Material = mat or Enum.Material.SmoothPlastic })
	end
end

local function cloudMaker(size, color)
	return function(parent, k)
		local m = Instance.new("Model")
		for i = -1, 1 do
			newPart(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * size * k * (i == 0 and 1 or 0.75), CFrame = CFrame.new(i * size * k * 0.45, i == 0 and size * k * 0.12 or 0, 0), Color = color })
		end
		m.WorldPivot = CFrame.new()
		m.Parent = parent
		return m
	end
end

MAKE.bone = fromProp("Bone", 1.5, function(parent, k)
	local m = Instance.new("Model")
	newPart(m, { Size = Vector3.new(1.1, 0.3, 0.3) * k, Color = C(245, 240, 225) })
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -0.15, 0.15 }) do
			newPart(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.38 * k, CFrame = CFrame.new(s * 0.6 * k, 0, z * k), Color = C(245, 240, 225) })
		end
	end
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m
end)
MAKE.molten = fromProp("MoltenRock", 1.1, ballMaker(1, C(60, 40, 35), Enum.Material.Basalt))
MAKE.floatingRock = fromProp("FloatingRock", 1.5, ballMaker(1.2, C(150, 110, 75), Enum.Material.Rock))
MAKE.miniJet = fromProp("MiniJet", 1.5, function(parent, k)
	return newPart(parent, { Size = Vector3.new(0.5, 0.4, 1.4) * k, Color = C(240, 240, 250) })
end)
MAKE.satellite = fromProp("Satellite", 1.8, function(parent, k)
	return newPart(parent, { Size = Vector3.new(1.6, 0.2, 0.6) * k, Color = C(80, 130, 230) })
end)
MAKE.asteroid = fromProp("Asteroid", 1.1, ballMaker(1, C(130, 120, 115), Enum.Material.Rock))
MAKE.iceShard = function(parent, k)
	return newPart(parent, { Size = Vector3.new(0.35, 1.1, 0.35) * k, Color = C(170, 225, 255), Material = Enum.Material.Glass, Transparency = 0.15 })
end
MAKE.crystal = function(parent, k)
	return newPart(parent, { Size = Vector3.new(0.35, 1, 0.35) * k, Color = C(170, 255, 220), Material = Enum.Material.Neon, Transparency = 0.2 })
end
MAKE.leaf = function(parent, k)
	return newPart(parent, { Size = Vector3.new(0.7, 0.06, 1.1) * k, Color = C(90, 190, 80) })
end
MAKE.cloud = cloudMaker(1.1, C(255, 255, 255))
MAKE.stormCloud = cloudMaker(1.4, C(80, 84, 100))
MAKE.moon = ballMaker(0.55, C(220, 200, 170))
MAKE.moonGrey = ballMaker(0.45, C(200, 200, 210))
MAKE.comet = function(parent, k)
	local p = newPart(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55 * k, Color = C(200, 230, 255), Material = Enum.Material.Neon })
	return p
end
MAKE.butterfly = function(parent, k)
	local m = Instance.new("Model")
	local body = newPart(m, { Name = "Body", Size = Vector3.new(0.12, 0.12, 0.5) * k, Color = C(60, 40, 40) })
	m.PrimaryPart = body
	local col = ({ C(255, 170, 60), C(120, 190, 255), C(255, 130, 200) })[math.random(1, 3)]
	for _, s in ipairs({ -1, 1 }) do
		local w = newPart(m, { Name = s < 0 and "WingL" or "WingR", Size = Vector3.new(0.45, 0.04, 0.5) * k, CFrame = CFrame.new(s * 0.25 * k, 0, 0), Color = col })
		w:SetAttribute("Side", s)
	end
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m
end
MAKE.bird = function(parent, k)
	local m = Instance.new("Model")
	for _, s in ipairs({ -1, 1 }) do
		local w = newPart(m, { Name = s < 0 and "WingL" or "WingR", Size = Vector3.new(0.5, 0.06, 0.18) * k, CFrame = CFrame.new(s * 0.22 * k, 0, 0) * CFrame.Angles(0, 0, s * 0.3), Color = C(255, 255, 255) })
		w:SetAttribute("Side", s)
	end
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m
end
-- a little bat: round body, pointy ears, glowing orange eyes, wings that flap
MAKE.bat = function(parent, k)
	local m = Instance.new("Model")
	local dark = C(45, 30, 60)
	local body = newPart(m, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.42 * k, Color = dark })
	m.PrimaryPart = body
	for _, s in ipairs({ -1, 1 }) do
		local w = newPart(m, { Name = s < 0 and "WingL" or "WingR", Size = Vector3.new(0.62, 0.04, 0.34) * k, CFrame = CFrame.new(s * 0.36 * k, 0.04 * k, 0.02 * k) * CFrame.Angles(0, s * -0.25, s * 0.15), Color = C(80, 45, 110) })
		w:SetAttribute("Side", s)
		newPart(m, { Name = "Ear", Size = Vector3.new(0.1, 0.18, 0.06) * k, CFrame = CFrame.new(s * 0.1 * k, 0.24 * k, -0.04 * k) * CFrame.Angles(0, 0, s * -0.25), Color = dark })
		newPart(m, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.09 * k, CFrame = CFrame.new(s * 0.09 * k, 0.05 * k, -0.19 * k), Color = C(255, 170, 40), Material = Enum.Material.Neon })
	end
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m
end

-- The looks. Orbit: { make, n, r (x egg width), y (x egg height, 0 = middle), speed, tilt, spin,
-- bob, beam = { color, width, electric }, trail = color, flap = true }.
-- fx: { preset, color, at = "base" | "middle" | "top", strength }.
-- light: { color, brightness, range (x egg height), flicker, pulse }. rings: { r, width, color,
-- tilt, speed }. spiral / ribbons: special effects.
local LOOKS = {
	Meadow = {
		orbit = { { make = "butterfly", n = 2, r = 0.95, y = 0.15, speed = 0.9, bob = 0.25, flap = true } },
		fx = { { "sparkle", C(255, 250, 180), "middle", 0.4 } },
	},
	Ancient = {
		orbit = { { make = "bone", n = 5, r = 1.45, y = 0.12, speed = 0.55, tilt = 0.22, spin = 1.2, bob = 0.25, beam = { C(190, 110, 255), 0.16, true }, chain = { C(200, 120, 255), 0.22 } } },
		fx = { { "dust", C(235, 205, 150), "base", 1 }, { "sparkle", C(255, 215, 90), "middle", 0.6 } },
		light = { C(200, 140, 255), 0.6, 2.2 },
	},
	Jungle = {
		orbit = { { make = "leaf", n = 3, r = 0.85, y = 0.1, speed = 0.5, tilt = 0.4, spin = 2, bob = 0.3 } },
		fx = { { "fireflies", C(200, 255, 120), "middle", 1 } },
		light = { C(150, 255, 150), 0.4, 2 },
	},
	IceAge = {
		orbit = { { make = "iceShard", n = 5, r = 0.9, y = 0.1, speed = 0.7, tilt = 0.2, spin = 1.5, bob = 0.15 } },
		fx = { { "frost", C(210, 240, 255), "middle", 1.2 } },
		light = { C(150, 220, 255), 0.8, 2.4 },
	},
	Magma = {
		orbit = { { make = "molten", n = 4, r = 1.3, y = 0, speed = 0.8, tilt = 0.3, spin = 1, bob = 0.25, trail = C(255, 130, 40) } },
		fx = { { "embers", C(255, 140, 40), "middle", 1.6 }, { "flame", C(255, 110, 20), "base", 0.8 } },
		light = { C(255, 120, 30), 1.6, 3, flicker = true },
	},
	Cloud = {
		orbit = { { make = "cloud", n = 4, r = 1, y = -0.1, speed = 0.45, bob = 0.25 } },
		rings = { { r = 0.42, width = 0.18, color = C(255, 220, 110), tiltY = 0.62, speed = 0.8, halo = true } },
		fx = { { "sparkle", C(255, 225, 130), "middle", 0.8 } },
		light = { C(255, 235, 170), 0.9, 2.4 },
	},
	Thunder = {
		orbit = { { make = "stormCloud", n = 3, r = 1.55, y = 0.25, speed = 0.6, bob = 0.25, beam = { C(255, 240, 90), 0.22, true }, chain = { C(255, 245, 140), 0.15 } } },
		fx = { { "spark", C(255, 240, 80), "middle", 0.8 }, { "rain", C(170, 190, 230), "top", 1 } },
		light = { C(255, 245, 160), 1.2, 3, flash = true },
	},
	SkyIsland = {
		orbit = {
			{ make = "floatingRock", n = 3, r = 1.05, y = -0.05, speed = 0.35, tilt = 0.15, spin = 0.4, bob = 0.3 },
			{ make = "bird", n = 2, r = 1.6, y = 0.55, speed = 1.1, bob = 0.2, flap = true },
		},
		fx = { { "sparkle", C(255, 200, 150), "middle", 0.7 }, { "mist", C(200, 235, 255), "base", 1 } },
		light = { C(255, 180, 120), 1.2, 2.6 },
	},
	Aurora = {
		orbit = { { make = "crystal", n = 6, r = 0.95, y = 0, speed = 0.6, tilt = 0.35, spin = 1.6, bob = 0.2 } },
		ribbons = { n = 3, colors = { C(110, 255, 180), C(190, 110, 255), C(110, 220, 255) } },
		fx = { { "sparkle", C(150, 255, 210), "middle", 1.2 } },
		light = { C(140, 255, 210), 1.3, 2.8, pulse = 1.2 },
	},
	JetStream = {
		orbit = { { make = "miniJet", n = 2, r = 1.25, y = 0.25, speed = 1.4, tilt = 0.35, bob = 0.15, trail = C(255, 255, 255) } },
		fx = { { "thruster", C(90, 180, 255), "base", 1 }, { "sparkle", C(170, 220, 255), "middle", 0.6 } },
		light = { C(110, 190, 255), 1.4, 2.8 },
	},
	Moon = {
		orbit = {
			{ make = "satellite", n = 1, r = 1.25, y = 0.3, speed = 0.6, tilt = 0.5, spin = 0.5 },
			{ make = "moonGrey", n = 3, r = 0.9, y = -0.1, speed = 0.9, tilt = -0.3, bob = 0.15 },
		},
		fx = { { "sparkle", C(230, 235, 255), "middle", 1 } },
		light = { C(210, 220, 255), 1.2, 2.8 },
	},
	Mars = {
		orbit = { { make = "asteroid", n = 4, r = 1.05, y = 0, speed = 0.75, tilt = 0.3, spin = 1.2, bob = 0.2, trail = C(220, 120, 80) } },
		fx = { { "duststorm", C(210, 110, 70), "middle", 1 }, { "sparkle", C(255, 130, 200), "middle", 0.8 } },
		light = { C(255, 120, 150), 1.5, 3 },
	},
	GasGiant = {
		orbit = { { make = "moon", n = 3, r = 0.95, y = 0.05, speed = 0.7, tilt = 0.45, bob = 0.05 } },
		rings = { { r = 1.05, width = 0.32, color = C(255, 215, 130), tilt = 0.45, speed = 0.35, alpha = 0.25 } },
		fx = { { "sparkle", C(255, 220, 140), "middle", 1 } },
		light = { C(255, 190, 110), 1.6, 3 },
	},
	Nebula = {
		orbit = { { make = "comet", n = 2, r = 1.1, y = 0.1, speed = 1.3, tilt = 0.5, trail = C(150, 210, 255) } },
		fx = { { "nebula", C(220, 120, 255), "middle", 1 }, { "sparkle", C(255, 200, 255), "middle", 1.4 } },
		light = { C(210, 110, 255), 2, 3.2, pulse = 1 },
	},
	BlackHole = {
		rings = {
			{ r = 1.05, width = 0.45, color = C(255, 150, 60), tilt = 0.32, speed = 1.6, alpha = 0.15 },
			{ r = 0.85, width = 0.3, color = C(200, 100, 255), tilt = 0.32, speed = 2.3, alpha = 0.1 },
		},
		spiral = { n = 12, color = C(255, 240, 210) },
		fx = { { "void", C(190, 100, 255), "middle", 1.4 } },
		light = { C(180, 90, 255), 2.4, 3.4, pulse = 1.8 },
	},
	-- Halloween: bats circling, ghost wisps drifting up, purple fog, a flickering candle glow
	Spooky = {
		orbit = { { make = "bat", n = 3, r = 1.3, y = 0.6, speed = 1.3, bob = 0.35, flap = true } },
		fx = { { "mist", C(140, 80, 210), "base", 1.2 }, { "ghosts", C(230, 220, 255), "middle", 1 }, { "embers", C(255, 150, 40), "top", 0.5 } },
		light = { C(255, 140, 40), 1.3, 2.4, flicker = true },
	},
}

-- Extra egg-only particle presets (the pet ones come from PetFx).
local EXTRA = {
	fireflies = function(p, c, k, s)
		emitter(p, { Name = "Fireflies", Color = seq(c), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.25 * k), NumberSequenceKeypoint.new(1, 0) }), Transparency = NumberSequence.new(0), Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(0.3, 0.8), Rate = 4 * s, LightEmission = 1 })
	end,
	rain = function(p, c, k, s)
		emitter(p, { Name = "Rain", Color = seq(c), Size = NumberSequence.new(0.08 * k), Transparency = NumberSequence.new(0.3), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(8, 10), SpreadAngle = Vector2.new(5, 5), Rate = 25 * s, LightEmission = 0.3, EmissionDirection = Enum.NormalId.Bottom })
	end,
	mist = function(p, c, k, s)
		emitter(p, { Name = "Mist", Texture = SMOKE, Color = seq(c), Size = NumberSequence.new(1 * k, 2.4 * k), Transparency = NumberSequence.new(0.6, 1), Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.3, 0.6), Rate = 3 * s, LightEmission = 0.2, EmissionDirection = Enum.NormalId.Bottom })
	end,
	thruster = function(p, c, k, s)
		emitter(p, { Name = "Thruster", Texture = "rbxasset://textures/particles/fire_main.dds", Color = seq(c, Color3.new(1, 1, 1)), Size = NumberSequence.new(0.9 * k, 0), Transparency = NumberSequence.new(0.1, 1), Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(4, 6), SpreadAngle = Vector2.new(8, 8), Rate = 30 * s, LightEmission = 1, EmissionDirection = Enum.NormalId.Bottom })
	end,
	duststorm = function(p, c, k, s)
		emitter(p, { Name = "DustStorm", Texture = SMOKE, Color = seq(c), Size = NumberSequence.new(0.8 * k, 2 * k), Transparency = NumberSequence.new(0.55, 1), Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(180, 20), Rate = 6 * s, LightEmission = 0, LightInfluence = 1, RotSpeed = NumberRange.new(-60, 60) })
	end,
	ghosts = function(p, c, k, s)
		emitter(p, { Name = "Ghosts", Texture = SMOKE, Color = seq(c), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2 * k), NumberSequenceKeypoint.new(0.4, 0.9 * k), NumberSequenceKeypoint.new(1, 0.3 * k) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(1.6, 2.4), Speed = NumberRange.new(1, 1.8), SpreadAngle = Vector2.new(35, 35), Rate = 2.5 * s, LightEmission = 0.5, RotSpeed = NumberRange.new(-30, 30) })
	end,
	nebula = function(p, c, k, s)
		emitter(p, { Name = "Nebula", Texture = SMOKE, Color = ColorSequence.new(c, C(110, 180, 255)), Size = NumberSequence.new(1.2 * k, 2.6 * k), Transparency = NumberSequence.new(0.5, 1), Lifetime = NumberRange.new(1.5, 2.4), Speed = NumberRange.new(0.4, 1), Rate = 4 * s, LightEmission = 0.8, RotSpeed = NumberRange.new(-40, 40) })
	end,
}

local function buildFx(holder, spec, k, s)
	local build = EXTRA[spec[1]] or PetFx.presets[spec[1]]
	if build then
		build(holder, spec[2], k, (spec[4] or 1) * s)
	end
end

-- A ring of glowing segments around the egg (accretion disk, planet ring, halo).
local function makeRing(parent, r, width, color, alpha)
	local m = Instance.new("Model")
	local n = 28
	for i = 0, n - 1 do
		local a1, a2 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
		local p1 = Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r)
		local p2 = Vector3.new(math.cos(a2) * r, 0, math.sin(a2) * r)
		newPart(m, { Size = Vector3.new(width, 0.08, (p2 - p1).Magnitude + 0.05), CFrame = CFrame.lookAt((p1 + p2) / 2, p2), Color = color, Material = Enum.Material.Neon, Transparency = alpha or 0 })
	end
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m
end

function EggLooks.attach(egg, id, opts)
	opts = opts or {}
	local look = LOOKS[id] or {}
	local folder = Instance.new("Folder")
	folder.Name = "EggRig"
	folder.Parent = opts.parent or workspace
	local home = opts.home or egg:GetPivot()
	local cf, size = egg:GetBoundingBox()
	local k = size.Y / 5 -- (eggs are 4.6 .. 6.4 tall)
	local width = math.max(size.X, size.Z) * 0.5 + 0.6 * k
	local centerOffset = egg:GetPivot():PointToObjectSpace(cf.Position) -- (the egg may not be at home yet)
	local s = opts.hatch and 1.6 or 1

	-- core: an invisible part at the egg's middle for the particles + light
	local core = newPart(folder, { Name = "Core", Size = Vector3.new(size.X * 0.6, size.Y * 0.6, size.Z * 0.6), Transparency = 1, CFrame = cf })
	local base = newPart(folder, { Name = "Base", Size = Vector3.new(size.X * 0.8, 0.2, size.Z * 0.8), Transparency = 1, CFrame = home })
	local top = newPart(folder, { Name = "Top", Size = Vector3.new(size.X, 0.2, size.Z), Transparency = 1, CFrame = home * CFrame.new(0, size.Y + 2 * k, 0) })
	local coreAtt = Instance.new("Attachment")
	coreAtt.Parent = core
	for _, f in ipairs(look.fx or {}) do
		local holder = (f[3] == "base" and base) or (f[3] == "top" and top) or core
		buildFx(holder, f, k, s)
	end
	local light
	if look.light then
		light = Instance.new("PointLight")
		light.Color = look.light[1]
		light.Brightness = look.light[2]
		-- (in the hatch show the eggs stand 7.5 apart: a short light, or each one floods its
		-- neighbours with its colour)
		light.Range = (opts.hatch and math.min(look.light[3], 0.75) or look.light[3]) * size.Y
		light.Shadows = false
		light.Parent = core
	end

	-- orbiters
	local orbs = {}
	for _, o in ipairs(look.orbit or {}) do
		for i = 1, o.n do
			local inst = MAKE[o.make](folder, k)
			local entry = { inst = inst, o = o, phase = (i - 1) / o.n * math.pi * 2, wings = {} }
			if inst:IsA("Model") then
				for _, d in ipairs(inst:GetDescendants()) do
					if d:IsA("BasePart") and d:GetAttribute("Side") then
						table.insert(entry.wings, { part = d, side = d:GetAttribute("Side"), home = inst:GetPivot():ToObjectSpace(d.CFrame) })
					end
				end
			end
			local main = inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)) or inst
			if o.beam and main then
				local a = Instance.new("Attachment")
				a.Parent = main
				local b = Instance.new("Beam")
				b.Attachment0, b.Attachment1 = coreAtt, a
				b.Color = seq(o.beam[1], o.beam[1]:Lerp(Color3.new(1, 1, 1), 0.4))
				b.Width0, b.Width1 = o.beam[2] * k, o.beam[2] * k * 0.6
				b.LightEmission = 1
				b.LightInfluence = 0
				b.FaceCamera = true
				b.Segments = o.beam[3] and 8 or 4
				b.Transparency = NumberSequence.new(0.15, 0.4)
				b.Parent = main
				entry.beam = b
				entry.electric = o.beam[3]
			end
			if o.trail and main then
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position = Vector3.new(0, 0.15 * k, 0)
				a1.Position = Vector3.new(0, -0.15 * k, 0)
				a0.Parent, a1.Parent = main, main
				local tr = Instance.new("Trail")
				tr.Attachment0, tr.Attachment1 = a0, a1
				tr.Color = seq(o.trail)
				tr.Transparency = NumberSequence.new(0.2, 1)
				tr.Lifetime = 0.6
				tr.LightEmission = 0.7
				tr.FaceCamera = true
				tr.Parent = main
			end
			table.insert(orbs, entry)
			entry.main = main
		end
		-- a glowing chain linking the group's orbiters to each other (the "magnetic force")
		if o.chain and o.n > 1 then
			local group = {}
			for j = #orbs - o.n + 1, #orbs do
				table.insert(group, orbs[j])
			end
			for j, e in ipairs(group) do
				local nxt = group[j % #group + 1]
				if e.main and nxt.main then
					local a0 = Instance.new("Attachment")
					a0.Parent = e.main
					local a1 = Instance.new("Attachment")
					a1.Parent = nxt.main
					local b = Instance.new("Beam")
					b.Attachment0, b.Attachment1 = a0, a1
					b.Color = seq(o.chain[1], o.chain[1]:Lerp(Color3.new(1, 1, 1), 0.35))
					b.Width0, b.Width1 = o.chain[2] * k, o.chain[2] * k
					b.LightEmission = 1
					b.LightInfluence = 0
					b.FaceCamera = true
					b.Segments = 10
					b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 0.6) })
					b.Parent = e.main
					e.chainBeam = b
				end
			end
		end
	end

	-- rings
	local rings = {}
	for _, r in ipairs(look.rings or {}) do
		-- (sized by height: some eggs are wide; a bit smaller in the show so 3 eggs' rings don't tangle)
		local m = makeRing(folder, r.r * size.Y * (opts.hatch and 0.6 or 0.75), r.width * k, r.color, r.alpha)
		table.insert(rings, { m = m, r = r, angle = math.random() * 6 })
	end

	-- black hole: stars spiralling in
	local spiral = {}
	if look.spiral then
		for i = 1, look.spiral.n do
			local p = newPart(folder, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.25 * k, Color = look.spiral.color, Material = Enum.Material.Neon })
			table.insert(spiral, { p = p, life = i / look.spiral.n, a = math.random() * 6 })
		end
	end

	-- aurora: glowing ribbons winding round the egg
	local ribbons = {}
	if look.ribbons then
		for i = 1, look.ribbons.n do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent, a1.Parent = core, core
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = a0, a1
			local col = look.ribbons.colors[(i - 1) % #look.ribbons.colors + 1]
			b.Color = seq(col, col:Lerp(Color3.new(1, 1, 1), 0.3))
			b.Width0, b.Width1 = 0.9 * k, 0.4 * k
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Segments = 12
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1) })
			b.Parent = core
			table.insert(ribbons, { a0 = a0, a1 = a1, b = b, phase = i * 2.1 })
		end
	end

	local rig = { folder = folder, k = k, size = size, light = light, core = core }
	local baseBrightness = light and light.Brightness or 0
	local spinAngle = 0

	-- place everything for the egg's current pivot `eggCF` (time t, power p)
	function rig.update(dt, t, p, eggCF)
		p = p or 0
		eggCF = eggCF or egg:GetPivot()
		local center = eggCF * CFrame.new(centerOffset)
		core.CFrame = center
		base.CFrame = eggCF
		top.CFrame = eggCF * CFrame.new(0, size.Y + 2 * k, 0)
		local speedUp = 1 + p * 2.5
		spinAngle += dt * speedUp
		for _, e in ipairs(orbs) do
			local o = e.o
			local a = e.phase + spinAngle * (o.speed or 0.6)
			local r = (o.r or 1) * width * (1 - math.min(p, 2) * 0.08)
			local local3 = Vector3.new(math.cos(a) * r, (o.y or 0) * size.Y + math.sin(t * 2 + e.phase) * (o.bob or 0) * k, math.sin(a) * r)
			local tilt = CFrame.Angles(o.tilt or 0, 0, (o.tilt or 0) * 0.5)
			local pos = center.Position + (CFrame.new() * tilt):VectorToWorldSpace(local3)
			local ahead = center.Position + (CFrame.new() * tilt):VectorToWorldSpace(Vector3.new(math.cos(a + 0.2) * r, local3.Y, math.sin(a + 0.2) * r))
			local face = CFrame.lookAt(pos, ahead) * CFrame.Angles(0, 0, 0) * CFrame.Angles(0, (o.spin or 0) * t, (o.spin or 0) * t * 0.7)
			if e.inst:IsA("Model") then
				e.inst:PivotTo(face)
				if #e.wings > 0 then
					local flap = math.sin(t * 18 + e.phase) * 0.8
					for _, w in ipairs(e.wings) do
						w.part.CFrame = face * CFrame.Angles(0, 0, w.side * flap) * w.home
					end
				end
			else
				e.inst.CFrame = face
			end
			if e.chainBeam then
				e.chainBeam.CurveSize0 = math.sin(t * 3 + e.phase) * 0.6 * k
				e.chainBeam.CurveSize1 = math.cos(t * 2.6 + e.phase) * 0.6 * k
			end
			if e.beam then
				if e.electric then
					e.beam.CurveSize0 = math.random(-10, 10) / 10 * k
					e.beam.CurveSize1 = math.random(-10, 10) / 10 * k
					e.beam.Width0 = (o.beam[2] * k) * (0.6 + math.random() * 0.8) * (1 + p)
				end
			end
		end
		for _, r in ipairs(rings) do
			r.angle += dt * (r.r.speed or 0.5) * speedUp
			local cfR
			if r.r.halo then
				cfR = center * CFrame.new(0, size.Y * (r.r.tiltY or 0.6), 0) * CFrame.Angles(0, r.angle, 0)
			else
				cfR = center * CFrame.Angles(r.r.tilt or 0, 0, (r.r.tilt or 0) * 0.6) * CFrame.Angles(0, r.angle, 0)
			end
			r.m:PivotTo(cfR)
		end
		for _, st in ipairs(spiral) do
			st.life -= dt * 0.35 * speedUp
			if st.life <= 0 then
				st.life = 1
				st.a = math.random() * 6
			end
			st.a += dt * (3 - st.life * 2) * speedUp
			local r = width * (0.35 + st.life * 1.1)
			st.p.CFrame = center * CFrame.Angles(0.32, 0, 0.19) * CFrame.new(math.cos(st.a) * r, 0, math.sin(st.a) * r)
			st.p.Transparency = st.life < 0.15 and 1 - st.life / 0.15 or 0
		end
		for _, rb in ipairs(ribbons) do
			local a = t * 0.7 + rb.phase
			rb.a0.WorldPosition = center.Position + Vector3.new(math.cos(a) * width, math.sin(t + rb.phase) * size.Y * 0.35, math.sin(a) * width)
			rb.a1.WorldPosition = center.Position + Vector3.new(math.cos(a + 2.4) * width, -math.sin(t * 0.8 + rb.phase) * size.Y * 0.35, math.sin(a + 2.4) * width)
			rb.b.CurveSize0 = math.sin(t * 1.3 + rb.phase) * 3 * k
			rb.b.CurveSize1 = math.cos(t * 1.1 + rb.phase) * 3 * k
		end
		if light then
			local b = baseBrightness * (1 + p * (opts.hatch and 0.35 or 0.8))
			if look.light.flicker then
				b *= 0.8 + math.noise(t * 6, 1.3) * 0.5 + 0.2
			end
			if look.light.pulse then
				b *= 0.75 + 0.25 * math.sin(t * look.light.pulse * 3)
			end
			if look.light.flash and math.random() < dt * (0.6 + p * 4) then
				b *= 3.5
			end
			light.Brightness = b
		end
	end

	function rig.destroy()
		folder:Destroy()
	end

	rig.update(0, 0, 0, home)
	return rig
end

EggLooks.LOOKS = LOOKS
return EggLooks
