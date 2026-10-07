-- Pet effects (Eggs v2): the flames, frost, sparks, glow... a pet carries wherever it shows up in
-- the world (following you, the 3D hatch show). Which pet gets what is Config.PET_FX; on top of
-- that Legendary and rarer pets always sparkle in their rarity colour.
--   PetFx.apply(model, kind, { strength = 1 }) -> the main part the effects hang on
-- (ViewportFrames can't draw particles, so the UI pictures stay plain.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PetFx = {}

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function emitter(parent, t)
	local e = Instance.new("ParticleEmitter")
	e.Name = t.Name or "Fx"
	e.Texture = t.Texture or SPARK
	e.Color = t.Color
	e.Size = t.Size
	e.Transparency = t.Transparency or NumberSequence.new(0, 1)
	e.Lifetime = t.Lifetime
	e.Speed = t.Speed or NumberRange.new(1, 2)
	e.SpreadAngle = t.SpreadAngle or Vector2.new(180, 180)
	e.Rate = t.Rate
	e.LightEmission = t.LightEmission or 0.6
	e.LightInfluence = t.LightInfluence or 0
	e.Acceleration = t.Acceleration or Vector3.zero
	e.Drag = t.Drag or 0
	e.RotSpeed = t.RotSpeed or NumberRange.new(0, 0)
	e.Rotation = t.Rotation or NumberRange.new(0, 360)
	e.EmissionDirection = t.EmissionDirection or Enum.NormalId.Top
	if t.Shape then
		e.Shape = t.Shape
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	end
	e.Parent = parent
	return e
end

local function seq(a, b)
	return ColorSequence.new(a, b or a)
end

-- presets: build(holder part, color, k = size scale, s = strength)
local PRESETS = {
	flame = function(p, c, k, s)
		emitter(p, { Name = "Flame", Texture = FIRE, Color = seq(c, c:Lerp(Color3.new(1, 1, 0.6), 0.5)), Size = NumberSequence.new(1.1 * k, 0.1), Transparency = NumberSequence.new(0.15, 1), Lifetime = NumberRange.new(0.45, 0.8), Speed = NumberRange.new(2 * k, 3.5 * k), SpreadAngle = Vector2.new(25, 25), Rate = 22 * s, LightEmission = 0.9, RotSpeed = NumberRange.new(-60, 60) })
	end,
	embers = function(p, c, k, s)
		emitter(p, { Name = "Embers", Color = seq(c, Color3.fromRGB(255, 230, 120)), Size = NumberSequence.new(0.22 * k, 0), Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(1.5 * k, 3 * k), SpreadAngle = Vector2.new(40, 40), Rate = 9 * s, LightEmission = 1, Acceleration = Vector3.new(0, 1.5, 0) })
	end,
	frost = function(p, c, k, s)
		emitter(p, { Name = "FrostMist", Texture = SMOKE, Color = seq(c), Size = NumberSequence.new(0.8 * k, 2 * k), Transparency = NumberSequence.new(0.55, 1), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.3, 0.8), Rate = 4 * s, LightEmission = 0.3 })
		emitter(p, { Name = "Snow", Color = seq(Color3.new(1, 1, 1), c), Size = NumberSequence.new(0.25 * k, 0), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.5, 1.2), Rate = 7 * s, LightEmission = 0.5, Acceleration = Vector3.new(0, -1.5, 0) })
	end,
	spark = function(p, c, k, s)
		emitter(p, { Name = "Sparks", Color = seq(c, Color3.new(1, 1, 1)), Size = NumberSequence.new(0.35 * k, 0), Lifetime = NumberRange.new(0.12, 0.3), Speed = NumberRange.new(5 * k, 9 * k), Rate = 14 * s, LightEmission = 1, RotSpeed = NumberRange.new(-400, 400) })
	end,
	sparkle = function(p, c, k, s)
		emitter(p, { Name = "Sparkle", Color = seq(c, Color3.new(1, 1, 1)), Size = NumberSequence.new(0.45 * k, 0), Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(0.6, 1.6), Rate = 6 * s, LightEmission = 0.8, RotSpeed = NumberRange.new(-90, 90) })
	end,
	glow = function(p, c, k, s)
		local l = Instance.new("PointLight")
		l.Name = "Glow"
		l.Color = c
		l.Brightness = 1.2 * math.min(s, 2)
		l.Range = 7 * k
		l.Shadows = false
		l.Parent = p
	end,
	jet = function(p, c, k, s)
		emitter(p, { Name = "Jet", Texture = FIRE, Color = seq(c, Color3.new(1, 1, 1)), Size = NumberSequence.new(0.7 * k, 0), Transparency = NumberSequence.new(0.1, 1), Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(5 * k, 7 * k), SpreadAngle = Vector2.new(10, 10), Rate = 30 * s, LightEmission = 1, EmissionDirection = Enum.NormalId.Back })
	end,
	dust = function(p, c, k, s)
		emitter(p, { Name = "Dust", Texture = SMOKE, Color = seq(c), Size = NumberSequence.new(0.5 * k, 1.6 * k), Transparency = NumberSequence.new(0.55, 1), Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(0.4, 1), Rate = 3 * s, LightEmission = 0, LightInfluence = 1 })
	end,
	void = function(p, c, k, s)
		emitter(p, { Name = "VoidWisp", Texture = SMOKE, Color = seq(Color3.fromRGB(20, 10, 35), c), Size = NumberSequence.new(0.9 * k, 0.2), Transparency = NumberSequence.new(0.3, 1), Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(0.5, 1.2), Rate = 6 * s, LightEmission = 0, LightInfluence = 0, RotSpeed = NumberRange.new(-120, 120) })
		emitter(p, { Name = "VoidSpark", Color = seq(c), Size = NumberSequence.new(0.3 * k, 0), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(0.5, 1.5), Rate = 5 * s, LightEmission = 1 })
	end,
	aura = function(p, c, k, s, model)
		-- sparks rising from a ring at the pet's feet
		local _, size = model:GetBoundingBox()
		local ring = Instance.new("Part")
		ring.Name = "AuraRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.1, math.max(size.X, size.Z) * 1.05, math.max(size.X, size.Z) * 1.05)
		ring.CFrame = model:GetPivot() * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 1
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.Massless = true, false, false, false, true
		ring.Parent = model
		emitter(ring, { Name = "Aura", Color = seq(c, Color3.new(1, 1, 1)), Size = NumberSequence.new(0.35 * k, 0), Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(5, 5), Rate = 14 * s, LightEmission = 0.9, EmissionDirection = Enum.NormalId.Right, Shape = Enum.ParticleEmitterShape.Cylinder })
	end,
}

-- The part the effects hang on: the biggest part of the model (pets are one MeshPart).
local function mainPart(model)
	local best, vol = nil, -1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > vol then
				best, vol = d, v
			end
		end
	end
	return best
end

function PetFx.apply(model, kind, opts)
	opts = opts or {}
	local pet = Config.Pets[kind]
	local main = mainPart(model)
	if not pet or not main then
		return main
	end
	local s = opts.strength or 1
	local k = (pet.height or 3) / 3.2
	local list = Config.PET_FX[kind] or {}
	for _, fx in ipairs(list) do
		local build = PRESETS[fx[1]]
		if build then
			build(main, fx[2] or Config.Rarities[pet.rarity].color, k, s, model)
		end
	end
	-- rarer pets always shine a bit in their rarity colour
	local order = Config.Rarities[pet.rarity].order
	if order >= Config.Rarities.Legendary.order then
		local c = pet.rarity == "Secret" and Color3.fromRGB(255, 255, 255) or Config.Rarities[pet.rarity].color
		PRESETS.sparkle(main, c, k, s * (order - 4) * 0.6)
	end
	return main
end

PetFx.presets = PRESETS
PetFx.emitter = emitter
return PetFx
