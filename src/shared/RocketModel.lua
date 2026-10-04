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

-- def: entry from Config.Rockets. scale: 1 = flying size. withSeat: adds a Seat on top.
function RocketModel.build(def, scale, withSeat, origin)
	scale = scale or 1
	origin = origin or CFrame.new()
	local model = Instance.new("Model")
	model.Name = def.name

	local function at(x, y, z)
		return origin * CFrame.new(x * scale, y * scale, z * scale)
	end

	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 2.6, 2.6) * scale,
		Color = def.color,
		CFrame = at(0, 0, 0),
	})
	body.Parent = model
	model.PrimaryPart = body

	local pieces = {
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
		seat.CFrame = at(-0.5, 1.5, 0) * CFrame.Angles(0, -math.pi / 2, 0)
		table.insert(pieces, seat)
	end

	for _, p in ipairs(pieces) do
		p.Massless = true
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = p
		w.Parent = p
	end
	return model
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

-- A small rocket the player holds as a Tool.
function RocketModel.buildTool(def)
	local tool = Instance.new("Tool")
	tool.Name = "Rocket"
	tool.ToolTip = def.name .. " - click to launch!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local model = RocketModel.build(def, 0.35, false)
	local body = model.PrimaryPart
	body.Name = "Handle"
	for _, p in ipairs(model:GetChildren()) do
		p.Parent = tool
	end
	model:Destroy()
	tool.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	tool:SetAttribute("RocketId", def.id)
	return tool
end

return RocketModel
