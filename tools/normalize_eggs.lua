-- Eggs v2 asset prep (run in Edit with execute_luau, after generate_mesh has filled
-- ServerStorage.EggGen with egg_<Id>, pet_<Kind> and prop_<Name> models):
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:34873/tools/normalize_eggs.lua"))()
-- * eggs  -> ReplicatedStorage.EggModels.<Id>: scaled to their tier height, pivot at the bottom
--            middle, front = -Z. The Ice Age egg gets two big curled mammoth tusks built from parts.
-- * pets  -> ReplicatedStorage.PetModels.<Kind>: scaled to Config.PET_HEIGHT[rarity] (old pets too),
--            pivot at the feet, turned by YAW so they face -Z.
-- * props -> ReplicatedStorage.EggProps.<Name>: pivot at the middle (orbiters) or bottom (scenery).
-- Re-running is safe: it always starts from the raw generated models (or the existing pets).
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Config = require(RS.Shared.Config:Clone())

local gen = SS:FindFirstChild("EggGen")
local function folder(parent, name)
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local eggOut = folder(RS, "EggModels")
local petOut = folder(RS, "PetModels")
local propOut = folder(RS, "EggProps")
local backup = folder(SS, "PetModels_v1") -- the original pets, so re-runs scale from the original

-- which generated egg to use (later tries first)
local EGG_SOURCE = {
	Moon = { "egg_Moon2", "egg_Moon" },
	IceAge = { "egg_IceAge3", "egg_IceAge2", "egg_IceAge" },
}
local TIER_HEIGHT = { 4.6, 4.6, 4.6, 5.2, 5.2, 5.2, 5.2, 5.8, 5.8, 5.8, 5.8, 6.4, 6.4, 6.4, 6.4 }
-- extra turn (degrees) so a model faces -Z, found from line-up screenshots. Generated pets (Eggs v2)
-- come out facing -X, so they get GEN_PET_YAW unless listed here; the original pets face -Z.
local GEN_PET_YAW = -90
local YAW = {
	Fennec = -60,
	PumpkinKing = 180,
	Spooky = 180,
	BlackHole = -90, -- (its galaxy crack faces the walk)
	CandyDragon = 180,
	TreasureDragon = 180,
}
-- the special eggs' pets (limited / Royal / Winter) came out of the generator already facing -Z
for _, kind in ipairs({ "GemMole", "CrystalBat", "AmethystFox", "DiamondGolem", "GummyBear", "LollipopLamb", "CupcakeKitty", "CandyDragon",
	"BubblePuffer", "SeahorseKnight", "OctoPup", "Megalodon", "RoyalCorgi", "CrownLion", "TreasureDragon", "DiamondPhoenix",
	"SnowmanPup", "GingerbreadCat", "Reindeer", "FrostYeti" }) do
	YAW[kind] = YAW[kind] or 0
end
local EVENT_HEIGHT = 5.2 -- event / limited eggs (made from egg_<Id> only when one has been generated)
local SPECIAL_HEIGHT = { Royal = 5.8 }
local BOTTOM_PROPS = { Pyramid = true, IceCrystals = true, SpaceCrystals = true, LunarLander = true, MarsRover = true, LavaRocks = true }

local function clean(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = true
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	return m
end

-- scale `m` so its height is h, then put its pivot at the bottom middle (or the middle) at the origin
local function fit(m, h, yaw, middle)
	if yaw and yaw ~= 0 then
		m:PivotTo(m:GetPivot() * CFrame.Angles(0, math.rad(yaw), 0))
	end
	local _, size = m:GetBoundingBox()
	if h then
		m:ScaleTo(m:GetScale() * h / size.Y)
	end
	local cf, size2 = m:GetBoundingBox()
	local anchor = middle and cf.Position or (cf.Position - Vector3.new(0, size2.Y / 2, 0))
	-- an upright pivot (the model keeps its turn), then park it at the origin
	m.WorldPivot = CFrame.new(anchor)
	m:PivotTo(CFrame.new())
	m:SetAttribute("Height", size2.Y)
	return m
end

-- two big curled ivory tusks coming out of the Ice Age egg's sides (part-built: the generator made
-- a tiny mammoth when asked for a tusk)
local function addTusks(m)
	local _, size = m:GetBoundingBox()
	local ivory = Color3.fromRGB(246, 238, 218)
	local w, h, dpt = size.X, size.Y, size.Z
	for _, side in ipairs({ -1, 1 }) do
		local n = 12
		local prev, prevD
		for i = 0, n do
			local t = i / n
			-- a curve: out from the egg's side at mid height, dipping down, then up and forward
			local x = side * (w * 0.36 + w * 0.34 * math.sin(t * math.pi * 0.6))
			local y = h * (0.46 - 0.16 * math.sin(t * math.pi) + 0.28 * t * t)
			local z = -dpt * (0.12 + 0.85 * t * t)
			local p = Vector3.new(x, y, z)
			local d = h * (0.21 - 0.12 * t) -- thick root, thinner tip
			if prev then
				local seg = Instance.new("Part")
				seg.Name = "Tusk"
				seg.Shape = Enum.PartType.Cylinder
				seg.Size = Vector3.new((p - prev).Magnitude, (d + prevD) / 2, (d + prevD) / 2)
				seg.CFrame = CFrame.lookAt((p + prev) / 2, p) * CFrame.Angles(0, math.pi / 2, 0)
				seg.Color = ivory
				seg.Material = Enum.Material.SmoothPlastic
				seg.Parent = m
			end
			local j = Instance.new("Part")
			j.Name = "TuskJoint"
			j.Shape = Enum.PartType.Ball
			j.Size = Vector3.one * d
			j.CFrame = CFrame.new(p)
			j.Color = ivory
			j.Material = Enum.Material.SmoothPlastic
			j.Parent = m
			prev, prevD = p, d
		end
		-- a brown band where the tusk leaves the egg
		local root = Instance.new("Part")
		root.Name = "TuskRoot"
		root.Shape = Enum.PartType.Ball
		root.Size = Vector3.one * h * 0.25
		root.CFrame = CFrame.new(side * w * 0.38, h * 0.46, -dpt * 0.12)
		root.Color = Color3.fromRGB(150, 110, 80)
		root.Material = Enum.Material.SmoothPlastic
		root.Parent = m
	end
end

-- The Magma egg is built here (the generator kept painting it beige or pink): a black basalt egg
-- with glowing lava cracks branching over it and a few molten spots. (No PrimaryPart: the pivot
-- must stay at the bottom, or the egg sinks into its plinth.)
local function magmaEgg(h)
	local m = Instance.new("Model")
	m.Name = "Magma"
	-- the shell: the smooth Aurora egg's shape, untextured, in dark basalt (a true egg shape -
	-- wider low, narrower top); a plain ellipsoid if that model is missing
	local src = gen and gen:FindFirstChild("egg_Aurora")
	local shape = src and src:FindFirstChildWhichIsA("MeshPart", true)
	local r, yMid
	if shape then
		local shell = shape:Clone()
		shell.Name = "Shell"
		shell.TextureID = ""
		shell.Color = Color3.fromRGB(42, 32, 34)
		shell.Material = Enum.Material.Basalt
		shell.Size = shell.Size * (h / shell.Size.Y)
		shell.CFrame = CFrame.new(0, h / 2, 0)
		shell.Parent = m
		r = math.min(shell.Size.X, shell.Size.Z) / 2
		yMid = h * 0.42 -- (where the egg is widest)
	else
		r = h * 0.37
		yMid = h / 2
		local shell = Instance.new("Part")
		shell.Name = "Shell"
		shell.Size = Vector3.new(r * 2, h, r * 2)
		shell.CFrame = CFrame.new(0, h / 2, 0)
		shell.Color = Color3.fromRGB(42, 32, 34)
		shell.Material = Enum.Material.Basalt
		shell.Parent = m
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = shell
	end
	-- a point on the egg's surface for a direction (top half taller than the bottom half)
	local function surface(dir)
		local ry = dir.Y >= 0 and (h - yMid) or yMid
		local v = Vector3.new(dir.X * r, dir.Y * ry, dir.Z * r)
		local k = 1 / math.sqrt((v.X / r) ^ 2 + (v.Y / ry) ^ 2 + (v.Z / r) ^ 2)
		return Vector3.new(0, yMid, 0) + v * k * 1.025
	end
	local rng = Random.new(9)
	local lava = Color3.fromRGB(255, 95, 15)
	local glow = Color3.fromRGB(255, 110, 20)
	local function crack(dir, steps, width)
		local d = dir.Unit
		local heading = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local prev = surface(d)
		for _ = 1, steps do
			heading = (heading + Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6))).Unit
			d = (d + heading * 0.2).Unit
			local p = surface(d)
			local seg = Instance.new("Part")
			seg.Name = "Lava"
			seg.Size = Vector3.new(width, width * 0.5, (p - prev).Magnitude + width * 0.5)
			seg.CFrame = CFrame.lookAt((p + prev) / 2, p, (p - Vector3.new(0, yMid, 0)).Unit)
			seg.Color = lava
			seg.Material = Enum.Material.Neon
			seg.Parent = m
			if rng:NextNumber() < 0.3 and width > h * 0.02 then
				crack(d, math.floor(steps / 2), width * 0.65)
			end
			prev = p
		end
	end
	for i = 1, 14 do
		local ang = i / 14 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		crack(Vector3.new(math.cos(ang), (i % 2 == 0 and 0.45 or -0.35) + rng:NextNumber(-0.3, 0.3), math.sin(ang)), 7, h * 0.042)
	end
	for _ = 1, 6 do
		local d = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.9), rng:NextNumber(-1, 1)).Unit
		local spot = Instance.new("Part")
		spot.Name = "Molten"
		spot.Shape = Enum.PartType.Cylinder
		local rr = h * rng:NextNumber(0.045, 0.08)
		spot.Size = Vector3.new(0.1, rr * 2, rr * 2)
		local at = surface(d)
		spot.CFrame = CFrame.lookAt(at, at + (at - Vector3.new(0, yMid, 0)).Unit) * CFrame.Angles(0, math.pi / 2, 0)
		spot.Color = glow
		spot.Material = Enum.Material.Neon
		spot.Parent = m
	end
	m.WorldPivot = CFrame.new()
	return m
end

-- Twin Ring Dragon: the generator only ever made one head, so two dragons stand shoulder to shoulder,
-- turned a little apart, inside a golden ring (one pet, two heads). Built in the raw model's space,
-- where generated pets face -X (so "side by side" is along Z).
local function twinDragon(src)
	local m = Instance.new("Model")
	m.Name = "TwinRingDragon"
	local center, size = src:GetBoundingBox()
	local toOrigin = CFrame.new(-center.Position) -- (generated models sit wherever the camera was)
	for _, side in ipairs({ -1, 1 }) do
		local c = src:Clone()
		for _, d in ipairs(c:GetDescendants()) do -- (the mesh sits inside a sub-model)
			if d:IsA("BasePart") then
				d.CFrame = CFrame.new(0, 0, side * size.Z * 0.32) * CFrame.Angles(0, math.rad(side * 18), 0) * toOrigin * d.CFrame
			end
		end
		for _, d in ipairs(c:GetChildren()) do
			d.Parent = m
		end
		c:Destroy()
	end
	local cf, s2 = m:GetBoundingBox()
	local r = math.max(s2.X, s2.Z) * 0.62
	local n = 24
	for i = 0, n - 1 do
		local a1, a2 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
		local p1 = cf.Position + Vector3.new(math.cos(a1) * r * 0.55, -s2.Y * 0.05, math.sin(a1) * r)
		local p2 = cf.Position + Vector3.new(math.cos(a2) * r * 0.55, -s2.Y * 0.05, math.sin(a2) * r)
		local seg = Instance.new("Part")
		seg.Name = "Ring"
		seg.Size = Vector3.new(s2.Y * 0.07, s2.Y * 0.04, (p2 - p1).Magnitude + 0.05)
		seg.CFrame = CFrame.lookAt((p1 + p2) / 2, p2)
		seg.Color = Color3.fromRGB(255, 205, 80)
		seg.Material = Enum.Material.Neon
		seg.Parent = m
	end
	return m
end

-- the Spooky egg is a carved jack-o'-lantern: a glowing orange core inside shows through the cuts
local function lanternGlow(m)
	local cf, size = m:GetBoundingBox()
	local p = Instance.new("Part")
	p.Name = "LanternGlow"
	p.Size = Vector3.new(size.X * 0.74, size.Y * 0.66, size.Z * 0.74)
	p.CFrame = CFrame.new(cf.Position - Vector3.new(0, size.Y * 0.08, 0))
	p.Color = Color3.fromRGB(255, 140, 30)
	p.Material = Enum.Material.Neon
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = m
end

local report = {}
-- eggs
for i, egg in ipairs(Config.Eggs) do
	local src
	for _, key in ipairs(EGG_SOURCE[egg.id] or { "egg_" .. egg.id }) do
		src = src or (gen and gen:FindFirstChild(key))
	end
	if egg.id == "Magma" then
		local m = clean(magmaEgg(TIER_HEIGHT[i]))
		m:SetAttribute("Height", TIER_HEIGHT[i])
		local old = eggOut:FindFirstChild(egg.id)
		if old then
			old:Destroy()
		end
		m.Parent = eggOut
		table.insert(report, "egg Magma <- parts")
	elseif src then
		local m = clean(src:Clone())
		m.Name = egg.id
		fit(m, TIER_HEIGHT[i], YAW[egg.id])
		if egg.id == "IceAge" then
			addTusks(m)
			clean(m)
		end
		local old = eggOut:FindFirstChild(egg.id)
		if old then
			old:Destroy()
		end
		m.Parent = eggOut
		table.insert(report, "egg " .. egg.id .. " <- " .. src.Name)
	else
		table.insert(report, "egg " .. egg.id .. " MISSING")
	end
end
local specials = {}
for _, group in ipairs({ Config.EventEggs, Config.LimitedEggs, Config.ExclusiveEggs }) do
	for _, egg in ipairs(group) do
		table.insert(specials, egg)
	end
end
for _, egg in ipairs(specials) do
	local src = gen and gen:FindFirstChild("egg_" .. egg.id)
	if src then
		local m = clean(src:Clone())
		m.Name = egg.id
		fit(m, SPECIAL_HEIGHT[egg.id] or EVENT_HEIGHT, YAW[egg.id])
		if egg.id == "Spooky" then
			lanternGlow(m)
			clean(m)
		end
		local old = eggOut:FindFirstChild(egg.id)
		if old then
			old:Destroy()
		end
		m.Parent = eggOut
		table.insert(report, "event egg " .. egg.id .. " <- " .. src.Name)
	end
end
for _, old in ipairs({ "Frost", "Galaxy" }) do -- (eggs that don't exist any more)
	local m = eggOut:FindFirstChild(old)
	if m then
		m:Destroy()
	end
end

-- pets
local missing = {}
for kind, pet in pairs(Config.Pets) do
	local src = gen and gen:FindFirstChild("pet_" .. kind)
	if not src then
		-- an existing pet: keep the original in the backup and scale from that
		local orig = backup:FindFirstChild(kind)
		if not orig then
			local cur = petOut:FindFirstChild(kind)
			if cur then
				orig = cur:Clone()
				orig.Parent = backup
			end
		end
		src = orig
	end
	if src then
		local generated = gen and gen:FindFirstChild("pet_" .. kind) ~= nil
		local m = clean(kind == "TwinRingDragon" and generated and twinDragon(src) or src:Clone())
		m.Name = kind
		fit(m, pet.height, YAW[kind] or (generated and GEN_PET_YAW or 0))
		local old = petOut:FindFirstChild(kind)
		if old then
			old:Destroy()
		end
		m.Parent = petOut
	else
		table.insert(missing, kind)
	end
end
table.insert(report, "pets missing: " .. table.concat(missing, ","))

-- props
for _, m0 in ipairs(gen and gen:GetChildren() or {}) do
	local name = m0.Name:match("^prop_(.+)$")
	if name and name ~= "Tusk" then
		local m = clean(m0:Clone())
		m.Name = name
		fit(m, nil, YAW[name], not BOTTOM_PROPS[name])
		local old = propOut:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		m.Parent = propOut
		table.insert(report, "prop " .. name)
	end
end
return table.concat(report, "\n")
