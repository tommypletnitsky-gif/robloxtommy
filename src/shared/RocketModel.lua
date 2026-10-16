-- Builds rocket models out of plain parts (no toolbox assets).
-- The rocket points along its body's +X axis.
local RocketModel = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

-- Toolbox rocket visuals live in ReplicatedStorage.RocketModels, one Model per rocket id,
-- normalized: pivot at the center, nose pointing +X, about 10 studs long, scripts stripped.
-- Attributes on each: SeatHeight (top of the rocket, local Y), BackX (engine end, local X).
local function visualFor(def)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("RocketModels")
	return folder and folder:FindFirstChild(def.id)
end

-- A handlebar in front of the seat so the rider has something to hold. RiderAnimator's base pose
-- puts the hands on the grips: `ahead` studs in front of the seat, `up` above its top, `half` out.
RocketModel.HANDLEBAR = { ahead = 1.55, up = 0.62, half = 1.5 }
local function handlebar(seatTop, accent)
	-- seatTop: CFrame on top of the seat in the rocket's axes (+X = nose)
	local h = RocketModel.HANDLEBAR
	local metal = Color3.fromRGB(70, 75, 92)
	local c = seatTop * CFrame.new(h.ahead, h.up, 0)
	local list = {
		part({ Name = "HandlePost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 0.38, 0.38), CFrame = seatTop * CFrame.new(h.ahead, h.up - 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = accent or metal, Material = Enum.Material.SmoothPlastic }),
		part({ Name = "HandleBar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h.half * 2 + 0.3, 0.26, 0.26), CFrame = c * CFrame.Angles(0, math.pi / 2, 0), Color = metal, Material = Enum.Material.Metal }),
	}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(list, part({ Name = "Grip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.85, 0.38, 0.38), CFrame = c * CFrame.new(0, 0, side * (h.half - 0.15)) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(35, 35, 42) }))
	end
	return list
end

-- How far below its pivot the rocket's belly is (where the launcher cradle holds it).
function RocketModel.belly(def)
	local template = visualFor(def)
	return template and template:GetAttribute("Belly") or 1.3
end

-- def: entry from Config.Rockets. scale: 1 = flying size. withSeat: adds a Seat on top.
function RocketModel.build(def, scale, withSeat, origin)
	scale = scale or 1
	origin = origin or CFrame.new()
	local model = Instance.new("Model")
	model.Name = def.name

	local function at(x, y, z)
		return origin * CFrame.new(x * scale, y * scale, z * scale)
	end

	local template = visualFor(def)
	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 2.6, 2.6) * scale,
		Color = def.color,
		CFrame = at(0, 0, 0),
		Transparency = template and 1 or 0,
	})
	body.Parent = model
	model.PrimaryPart = body

	if template then
		local visual = template:Clone()
		visual.Name = "Visual"
		if scale ~= 1 then
			visual:ScaleTo(visual:GetScale() * scale)
		end
		visual:PivotTo(origin)
		for _, d in ipairs(visual:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
				if d.Name == "Wheel" then
					local w = Instance.new("Weld") -- (FlightFxClient spins it: C0 = Rest * roll)
					w.Name = "WheelWeld"
					w.Part0 = body
					w.Part1 = d
					w.C0 = body.CFrame:ToObjectSpace(d.CFrame)
					w:SetAttribute("Rest", w.C0)
					w.Parent = d
				else
					local w = Instance.new("WeldConstraint")
					w.Part0 = body
					w.Part1 = d
					w.Parent = d
				end
			end
		end
		visual.Parent = model
		local seatY = (template:GetAttribute("SeatHeight") or 1.5) * scale
		local backX = (template:GetAttribute("BackX") or -5) * scale
		local extras = {}
		local flame = part({ Name = "Flame", Size = Vector3.one * 0.5 * scale, Transparency = 1, CFrame = origin * CFrame.new(backX - 0.5 * scale, 0, 0) })
		table.insert(extras, flame)
		RocketModel._addFlameFx(flame, scale, def.thrusters)
		if withSeat then
			local seat = Instance.new("Seat")
			seat.Name = "Seat"
			seat.Size = Vector3.new(2, 0.4, 2) * scale
			seat.Transparency = 1
			seat.CanCollide = false
			seat.CanQuery = false
			seat.CanTouch = false
			seat.CFrame = origin * CFrame.new(-0.5 * scale, seatY, 0) * CFrame.Angles(0, -math.pi / 2, 0)
			table.insert(extras, seat)
			for _, p in ipairs(handlebar(origin * CFrame.new(-0.5 * scale, seatY + 0.2 * scale, 0), def.accent)) do
				p.Transparency = def.thrusters and 1 or p.Transparency -- (a car: the rider drives, no bar)
				table.insert(extras, p)
			end
		end
		if def.thrusters then
			for _, p in ipairs(RocketModel._thrusters(origin, scale, template:GetAttribute("CarSize"))) do
				table.insert(extras, p)
			end
		end
		for _, p in ipairs(extras) do
			p.Massless = true
			p.Anchored = false
			p.Parent = model
			local w = Instance.new("WeldConstraint")
			w.Part0 = body
			w.Part1 = p
			w.Parent = p
		end
		model:SetAttribute("BackX", backX)
		model:SetAttribute("Car", def.thrusters == true or nil)
		return model
	end

	local pieces = def.thrusters and RocketModel._carParts(def, at, scale) or {
		part({ Name = "Nose", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.6 * scale, Color = def.color, CFrame = at(4, 0, 0) }),
		part({ Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4 * scale, Color = def.accent, CFrame = at(5.1, 0, 0) }),
		part({ Name = "Stripe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2.7, 2.7) * scale, Color = def.accent, CFrame = at(1.6, 0, 0) }),
		part({ Name = "Nozzle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 2, 2) * scale, Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Metal, CFrame = at(-4.4, 0, 0) }),
		part({ Name = "FinBottom", Size = Vector3.new(2.2, 2, 0.25) * scale, Color = def.accent, CFrame = at(-3, -1.8, 0) }),
		part({ Name = "FinLeft", Size = Vector3.new(2.2, 0.25, 2) * scale, Color = def.accent, CFrame = at(-3, 0, -1.8) }),
		part({ Name = "FinRight", Size = Vector3.new(2.2, 0.25, 2) * scale, Color = def.accent, CFrame = at(-3, 0, 1.8) }),
		part({ Name = "Window", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1 * scale, Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Glass, CFrame = at(2.6, 0.9, 0) }),
	}

	local flame = part({ Name = "Flame", Size = Vector3.one * 0.5 * scale, Transparency = 1, CFrame = at(-5, 0, 0) })
	table.insert(pieces, flame)
	RocketModel._addFlameFx(flame, scale, def.thrusters)
	if def.thrusters then
		body.Transparency = 1
		for _, p in ipairs(RocketModel._thrusters(origin, scale)) do
			table.insert(pieces, p)
		end
	end

	if withSeat then
		-- A Seat faces its LookVector; rotate it so the rider faces the rocket's nose (+X).
		local seat = Instance.new("Seat")
		seat.Name = "Seat"
		seat.Size = Vector3.new(2, 0.4, 2) * scale
		seat.Transparency = 1
		seat.CanCollide = false
		seat.CanQuery = false
		seat.CanTouch = false
		seat.Anchored = false
		local seatY = def.thrusters and 0.55 or 1.5 -- (a car: you sit down in the cockpit)
		seat.CFrame = at(-0.5, seatY, 0) * CFrame.Angles(0, -math.pi / 2, 0)
		table.insert(pieces, seat)
		for _, p in ipairs(handlebar(at(-0.5, seatY + 0.2, 0), def.accent)) do
			p.Transparency = def.thrusters and 1 or p.Transparency
			table.insert(pieces, p)
		end
	end

	for _, p in ipairs(pieces) do
		p.Massless = true
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = p
		w.Parent = p
	end
	model:SetAttribute("BackX", -5 * scale)
	model:SetAttribute("Car", def.thrusters == true or nil)
	return model
end

-- Fire, smoke and light at the engine end. Turned on by setThrust.
-- gas = true (thruster cars): no fire, a white cold-gas jet out of the back instead.
function RocketModel._addFlameFx(flame, scale, gas)
	if gas then
		-- (no exhaust streak: the rear thrusters are real jets - see _thrusters. This emitter never
		-- emits; setThrust turning it on tells FlightFxClient the car is flying.)
		local jet = Instance.new("ParticleEmitter")
		jet.Name = "Trail"
		jet.Rate = 0
		jet.Enabled = false
		jet.Parent = flame
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(150, 210, 255)
		glow.Range = 10 * scale
		glow.Brightness = 1
		glow.Enabled = false
		glow.Parent = flame
		return
	end
	local fire = Instance.new("Fire")
	fire.Size = 6 * scale
	fire.Heat = 0
	fire.Color = Color3.fromRGB(255, 140, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 230, 80)
	fire.Enabled = false
	fire.Parent = flame
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Trail"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(180, 180, 180))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * scale), NumberSequenceKeypoint.new(1, 4 * scale) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.6, 1)
	smoke.Rate = 40
	smoke.Speed = NumberRange.new(2)
	smoke.EmissionDirection = Enum.NormalId.Left
	smoke.Enabled = false
	smoke.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 60)
	light.Range = 14 * scale
	light.Brightness = 2
	light.Enabled = false
	light.Parent = flame
end

-- A colored Trail streaming from the engine end (trailDef from Config.Trails).
function RocketModel.addTrail(model, trailDef)
	if not trailDef or trailDef.id == "None" or model:GetAttribute("Car") then -- (cars: no trails)
		return
	end
	local body = model.PrimaryPart
	local backX = model:GetAttribute("BackX") or -5
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(backX, 1.3, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(backX, -1.3, 0)
	a1.Parent = body
	local keypoints = {}
	for i, c in ipairs(trailDef.colors) do
		table.insert(keypoints, ColorSequenceKeypoint.new(#trailDef.colors == 1 and 0 or (i - 1) / (#trailDef.colors - 1), c))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, trailDef.colors[1]))
	end
	local trail = Instance.new("Trail")
	trail.Name = "RocketTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(keypoints)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.9
	trail.LightEmission = trailDef.glow or 0
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Parent = body
end

-- Cold-gas thruster jets (the thruster car), built like the real thing: one tight, straight column
-- of gas that only breaks up into a small puff at its end. FlightFxClient drives each layer with how
-- hard that jet is pushing (0..1):
--   Column - a Beam: the solid jet itself, pale blue at the nozzle turning white, barely widening
--   Glow   - a Beam: the brighter high-pressure core in the first part of the column
--   Grain  - fast, tight particles running down the column (gives it texture and motion)
--   Tail   - a small puff where the column ends (emitted from the ConeB attachment at its tip)
--   Light  - a soft blue glow at the nozzle
-- All locked to the car (it flies far faster than the gas, so the jet stays a column, not a streak).
local JET_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(175, 215, 255)),
	ColorSequenceKeypoint.new(0.22, Color3.fromRGB(240, 248, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
})
local function emitter(name, dir, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(228, 234, 244))
	e.EmissionDirection = dir
	e.LockedToPart = true
	e.Rate = 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	for k, v in pairs(props) do
		e[k] = v
	end
	return e
end
local function beam(name, a0, a1, props)
	local bm = Instance.new("Beam")
	bm.Name = name
	bm.Attachment0, bm.Attachment1 = a0, a1
	bm.FaceCamera = true
	bm.Segments = 4
	bm.Texture = "rbxasset://textures/particles/smoke_main.dds"
	bm.TextureMode = Enum.TextureMode.Stretch
	bm.Enabled = false
	for k, v in pairs(props) do
		bm[k] = v
	end
	bm.Parent = a0.Parent
	return bm
end
function RocketModel._gasJet(holder, scale, dir, axis)
	local a0 = Instance.new("Attachment")
	a0.Name = "ConeA"
	a0.Parent = holder
	local tip = Instance.new("Attachment")
	tip.Name = "ConeB" -- the end of the column (FlightFxClient moves it out along `Axis`)
	tip:SetAttribute("Axis", axis)
	tip.Position = axis * 0.1
	tip.Parent = holder
	local glowTip = Instance.new("Attachment")
	glowTip.Name = "GlowB"
	glowTip.Position = axis * 0.05
	glowTip.Parent = holder
	beam("Cone", a0, tip, {
		Color = JET_COLOR,
		LightEmission = 0.4,
		LightInfluence = 0.3,
		TextureSpeed = 4,
		TextureLength = 1,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(0.9, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Width0 = 0.4 * scale,
		Width1 = 0.6 * scale,
	})
	beam("Glow", a0, glowTip, {
		Color = ColorSequence.new(Color3.fromRGB(205, 232, 255), Color3.fromRGB(255, 255, 255)),
		LightEmission = 1,
		LightInfluence = 0,
		TextureSpeed = 6,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Width0 = 0.22 * scale,
		Width1 = 0.3 * scale,
	})
	emitter("Gas", dir, { -- the grain running down the column
		LightEmission = 0.3,
		LightInfluence = 0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55 * scale), NumberSequenceKeypoint.new(0.85, 0.85 * scale), NumberSequenceKeypoint.new(1, 1.2 * scale) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.15),
		Speed = NumberRange.new(55, 60),
		SpreadAngle = Vector2.new(0.8, 0.8),
	}).Parent = holder
	emitter("Tail", dir, { -- the small puff where the column breaks up
		LightEmission = 0.12,
		LightInfluence = 0.6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * scale), NumberSequenceKeypoint.new(0.4, 1.4 * scale), NumberSequenceKeypoint.new(1, 2.4 * scale) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.5, 0.65), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(5, 11),
		Drag = 4,
		SpreadAngle = Vector2.new(28, 28),
	}).Parent = tip
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = Color3.fromRGB(150, 200, 255)
	light.Range = 5 * scale
	light.Brightness = 0
	light.Shadows = false
	light.Parent = holder
end

-- Thruster jets around the car. Dir: "D" under the car (lift), "U" on top (push down), "L" left
-- side (blows left = pushes the car right), "R" right side, "B" rear pair (boost). Each is an
-- invisible holder with the three gas layers, plus a small dark nozzle you can see.
-- carSize: the car's length / height / width (default 10 x 2.6 x 4.6, pivot at its middle).
function RocketModel._thrusters(origin, scale, carSize)
	local L, H, W = 10, 2.6, 4.6
	if typeof(carSize) == "Vector3" then
		L, H, W = carSize.X, carSize.Y, carSize.Z
	end
	local list = {}
	local nozzleColor = Color3.fromRGB(38, 40, 46)
	local function jet(dir, normal, axis, x, y, z, nozzleAxis)
		local cf = origin * CFrame.new(x * scale, y * scale, z * scale)
		local p = part({ Name = "Thruster", Size = Vector3.one * 0.3 * scale, Transparency = 1, CFrame = cf })
		p:SetAttribute("Dir", dir)
		RocketModel._gasJet(p, scale, normal, axis)
		table.insert(list, p)
		-- (no visible nozzle: on the real car the thrusters sit inside the body)
	end
	local vertical = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis (X) turned to point up/down
	local sideways = CFrame.Angles(0, math.pi / 2, 0) -- axis turned to point left/right
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			jet("D", Enum.NormalId.Bottom, Vector3.new(0, -1, 0), sx * L * 0.3, -H * 0.4, sz * W * 0.3, vertical)
		end
		jet("L", Enum.NormalId.Front, Vector3.new(0, 0, -1), sx * L * 0.28, -H * 0.1, -W * 0.5, sideways) -- Front = -Z
		jet("R", Enum.NormalId.Back, Vector3.new(0, 0, 1), sx * L * 0.28, -H * 0.1, W * 0.5, sideways) -- Back = +Z
		jet("B", Enum.NormalId.Left, Vector3.new(-1, 0, 0), -L * 0.5, -H * 0.15, sx * W * 0.28, CFrame.new()) -- Left = -X (out the back)
	end
	return list
end

-- The car itself, from parts (used until / unless ReplicatedStorage.RocketModels.Roadster exists):
-- a low silver wedge with a dark glass canopy, four wheels and light bars. +X = the front.
function RocketModel._carParts(def, at, scale)
	local silver = def.color
	local glass = Color3.fromRGB(25, 30, 40)
	local tire = Color3.fromRGB(22, 22, 25)
	local rim = Color3.fromRGB(60, 62, 70)
	local list = {
		part({ Name = "Chassis", Size = Vector3.new(9.6, 0.9, 4.4) * scale, CFrame = at(0, -0.55, 0), Color = silver, Reflectance = 0.25 }),
		part({ Name = "Hood", Size = Vector3.new(3.4, 0.5, 4.2) * scale, CFrame = at(3.2, 0.05, 0) * CFrame.Angles(0, 0, math.rad(-7)), Color = silver, Reflectance = 0.25 }),
		part({ Name = "Nose", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.3, 0.95, 0.95) * scale, CFrame = at(4.75, -0.5, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = silver, Reflectance = 0.25 }),
		part({ Name = "Deck", Size = Vector3.new(3, 0.6, 4.3) * scale, CFrame = at(-3.2, 0.05, 0), Color = silver, Reflectance = 0.25 }),
		part({ Name = "Canopy", Size = Vector3.new(4.2, 0.9, 3.4) * scale, CFrame = at(-0.2, 0.55, 0), Color = glass, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.3 }),
		part({ Name = "Windshield", Size = Vector3.new(1.6, 0.18, 3.3) * scale, CFrame = at(2.15, 0.55, 0) * CFrame.Angles(0, 0, math.rad(-32)), Color = glass, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.3 }),
		part({ Name = "HeadLight", Size = Vector3.new(0.12, 0.12, 3.6) * scale, CFrame = at(4.82, -0.25, 0), Color = Color3.fromRGB(230, 245, 255), Material = Enum.Material.Neon }),
		part({ Name = "TailLight", Size = Vector3.new(0.12, 0.14, 4) * scale, CFrame = at(-4.82, -0.05, 0), Color = Color3.fromRGB(255, 40, 50), Material = Enum.Material.Neon }),
		part({ Name = "Skirt", Size = Vector3.new(9.4, 0.12, 4.5) * scale, CFrame = at(0, -1.02, 0), Color = Color3.fromRGB(30, 32, 38) }),
	}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local x, z = sx * 3.05, sz * 2.15
			table.insert(list, part({ Name = "Tire", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.75, 1.75, 1.75) * scale, CFrame = at(x, -0.75, z) * CFrame.Angles(0, math.pi / 2, 0), Color = tire }))
			table.insert(list, part({ Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 1.1, 1.1) * scale, CFrame = at(x, -0.75, z) * CFrame.Angles(0, math.pi / 2, 0), Color = rim, Material = Enum.Material.Metal, Reflectance = 0.2 }))
		end
	end
	return list
end

function RocketModel.setThrust(model, on)
	local flame = model:FindFirstChild("Flame", true)
	if not flame then
		return
	end
	for _, c in ipairs(flame:GetChildren()) do
		if c:IsA("Fire") or c:IsA("ParticleEmitter") or c:IsA("PointLight") then
			c.Enabled = on
		end
	end
end

return RocketModel
