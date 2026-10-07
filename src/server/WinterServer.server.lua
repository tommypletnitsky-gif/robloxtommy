-- Winter event (server). Only does anything while Config.winterActive() (Dec 1 - Jan 5):
--   * the Frosty Gift Egg on the event spot north of the spawn plaza (where the Spooky Egg stands at
--     Halloween): a snowy pedestal with pine trees in lights, presents, candy canes and a snowman.
--     Tagged HatcheryEgg like the others (EggLooks: snowflakes + snow), paid with snowflakes.
--   * light snow falling over the spawn plaza.
-- Snowflakes are handed out where they're earned (GameServer pickups, QuestServer missions).
-- When the event ends everything is removed again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Color3.fromRGB
local INK = C(30, 30, 50)
local SNOW, ICE = C(245, 250, 255), C(170, 220, 255)
local built = nil

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end
local UP = CFrame.Angles(0, 0, math.pi / 2)
local function cyl(parent, length, diameter, cf, color, props)
	local p = part(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), CFrame = cf * UP, Color = color })
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end
local function blob(parent, size, cf, color, props)
	local p = part(parent, { Size = size, CFrame = cf, Color = color, Material = Enum.Material.Snow })
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

-- a pine tree (the lobby's pine) with a star and coloured lights wrapped around it
local function pine(parent, pos, h)
	local lights = { C(255, 70, 70), C(255, 220, 70), C(80, 200, 255), C(120, 255, 120) }
	local src = game:GetService("ServerStorage"):FindFirstChild("LobbyProps") and game:GetService("ServerStorage").LobbyProps:FindFirstChild("Pine")
	local r = h * 0.3
	if src then
		local m = src:Clone()
		local _, size = m:GetBoundingBox()
		m:ScaleTo(m:GetScale() * h / size.Y)
		local cf, size2 = m:GetBoundingBox()
		-- bottom middle on `pos`
		m:PivotTo(m:GetPivot() + Vector3.new(pos.X - cf.Position.X, pos.Y + size2.Y / 2 - cf.Position.Y, pos.Z - cf.Position.Z))
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide = true, false
			elseif d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		m.Parent = parent
		r = math.min(size2.X, size2.Z) * 0.32
	else
		cyl(parent, h, h * 0.5, CFrame.new(pos + Vector3.new(0, h / 2, 0)), C(40, 130, 70))
	end
	-- a spiral of lights up the tree
	for k = 1, 22 do
		local t = k / 22
		local a = t * math.pi * 6
		local rr = r * (1.05 - t * 0.85)
		part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.38, CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * rr, h * (0.2 + t * 0.7), math.sin(a) * rr)), Color = lights[k % 4 + 1], Material = Enum.Material.Neon })
	end
	part(parent, { Size = Vector3.new(1, 1, 0.3), CFrame = CFrame.new(pos + Vector3.new(0, h + 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 4), Color = C(255, 220, 70), Material = Enum.Material.Neon })
end

local function present(parent, cf, size, color, ribbon)
	part(parent, { Size = size, CFrame = cf * CFrame.new(0, size.Y / 2, 0), Color = color, CanCollide = true })
	part(parent, { Size = Vector3.new(size.X + 0.05, size.Y + 0.05, size.Z * 0.2), CFrame = cf * CFrame.new(0, size.Y / 2, 0), Color = ribbon })
	part(parent, { Size = Vector3.new(size.X * 0.2, size.Y + 0.05, size.Z + 0.05), CFrame = cf * CFrame.new(0, size.Y / 2, 0), Color = ribbon })
	for _, s in ipairs({ -1, 1 }) do
		part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.35, 0.5) * size.X, CFrame = cf * CFrame.new(s * size.X * 0.15, size.Y + 0.1, 0), Color = ribbon })
	end
end

local function candyCane(parent, pos, yaw)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	for i = 0, 7 do
		cyl(parent, 0.5, 0.45, base * CFrame.new(0, 0.25 + i * 0.5, 0), i % 2 == 0 and C(230, 40, 50) or SNOW)
	end
	for i = 1, 5 do
		local a = i / 6 * math.pi
		part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = base * CFrame.new(math.cos(a) * 0.6 - 0.6, 4 + math.sin(a) * 0.6, 0), Color = i % 2 == 0 and C(230, 40, 50) or SNOW })
	end
end

local function snowman(parent, pos, yaw)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = base * CFrame.new(0, 1.4, 0), Color = SNOW, Material = Enum.Material.Snow })
	part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = base * CFrame.new(0, 3.4, 0), Color = SNOW, Material = Enum.Material.Snow })
	part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = base * CFrame.new(0, 4.9, 0), Color = SNOW, Material = Enum.Material.Snow })
	cyl(parent, 0.9, 0.2, base * CFrame.new(0, 4.95, -0.9) * CFrame.Angles(0, math.pi / 2, math.pi / 2), C(255, 140, 40))
	for _, s in ipairs({ -1, 1 }) do
		part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.22, CFrame = base * CFrame.new(s * 0.3, 5.15, -0.7), Color = INK })
	end
	cyl(parent, 0.5, 1.9, base * CFrame.new(0, 4.25, 0), C(220, 40, 50), { Material = Enum.Material.Fabric })
	cyl(parent, 0.9, 1.1, base * CFrame.new(0, 6, 0), INK)
	cyl(parent, 0.12, 1.6, base * CFrame.new(0, 5.6, 0), INK)
end

local function board(anchor, lines)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(9, 3.6)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.Parent = anchor
	local y = 0
	for _, l in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.Name = l.name
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0, y)
		t.Size = UDim2.fromScale(1, l.h)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = l.text
		t.TextColor3 = l.color
		local st = Instance.new("UIStroke")
		st.Thickness = 2.5
		st.Color = INK
		st.Parent = t
		t.Parent = bb
		y += l.h
	end
end

local function build()
	local hub = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Hub")
	local hatchery = hub and hub:FindFirstChild("Hatchery")
	local egg = Config.getEgg("Frosty")
	if not hatchery or not egg then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Winter"
	folder.Parent = hub
	local pos = egg.stand
	local floorY = 0.3
	local stand = Instance.new("Model")
	stand.Name = "Egg_Frosty"
	stand:SetAttribute("Egg", egg.id)
	stand.Parent = hatchery
	-- snowy ground + an icy pedestal
	blob(folder, Vector3.new(26, 1.4, 22), CFrame.new(pos + Vector3.new(0, floorY, 2)), SNOW)
	cyl(stand, 1.4, 8.4, CFrame.new(pos + Vector3.new(0, floorY + 0.7, 0)), C(200, 230, 255), { Material = Enum.Material.Ice, CanCollide = true })
	cyl(stand, 1.1, 7, CFrame.new(pos + Vector3.new(0, floorY + 1.9, 0)), SNOW, { Material = Enum.Material.Snow, CanCollide = true })
	cyl(stand, 0.4, 7.6, CFrame.new(pos + Vector3.new(0, floorY + 2.55, 0)), C(220, 40, 50))
	local top = floorY + 2.75
	-- the egg (a HatcheryEgg: HatcheryClient bobs it and adds the snowflakes / snow / glow)
	local template = ReplicatedStorage:FindFirstChild("EggModels") and ReplicatedStorage.EggModels:FindFirstChild("Frosty")
	local e
	if template then
		e = template:Clone()
	else
		e = Instance.new("Model")
		local p = part(e, { Size = Vector3.new(3.8, 5, 3.8), CFrame = CFrame.new(0, 2.5, 0), Color = egg.color })
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
		e.WorldPivot = CFrame.new()
	end
	e.Name = "Egg"
	for _, d in ipairs(e:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch = true, false, false
		end
	end
	local home = CFrame.lookAt(pos + Vector3.new(0, top, 0), pos + Vector3.new(0, top, -10))
	e:PivotTo(home)
	e:SetAttribute("Home", home)
	e:SetAttribute("EggId", egg.id)
	e.Parent = stand
	CollectionService:AddTag(e, "HatcheryEgg")
	local _, size = e:GetBoundingBox()
	local anchor = part(stand, { Name = "Board", Size = Vector3.one, CFrame = CFrame.new(pos + Vector3.new(0, top + size.Y + 3.2, 0)), Transparency = 1, CanQuery = false })
	board(anchor, {
		{ name = "Title", h = 0.4, text = "🎁 " .. egg.name, color = C(170, 225, 255) },
		{ name = "Price", h = 0.32, text = "❄ " .. egg.price .. " snowflakes", color = C(220, 240, 255) },
		{ name = "Lock", h = 0.28, text = "Press E to hatch!", color = Color3.new(1, 1, 1) },
	})
	local hit = part(stand, { Name = "PromptPart", Size = Vector3.new(5, 6, 5), CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0)), Transparency = 1, CanQuery = true })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = egg.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Egg", egg.id)
	prompt.Parent = hit
	-- decorations: pines behind, presents and candy canes in front, a snowman to the side
	pine(folder, pos + Vector3.new(-7.5, floorY, 6.5), 9)
	pine(folder, pos + Vector3.new(7.5, floorY, 7.5), 8)
	pine(folder, pos + Vector3.new(0.5, floorY, 9.5), 10.5)
	present(folder, CFrame.new(pos + Vector3.new(-4.6, floorY, -5)) * CFrame.Angles(0, 0.4, 0), Vector3.new(1.6, 1.3, 1.6), C(220, 40, 50), C(255, 220, 70))
	present(folder, CFrame.new(pos + Vector3.new(-5.8, floorY, -3.4)) * CFrame.Angles(0, -0.3, 0), Vector3.new(1.1, 1.6, 1.1), C(60, 170, 90), C(245, 245, 255))
	present(folder, CFrame.new(pos + Vector3.new(5, floorY, -4.8)) * CFrame.Angles(0, 0.8, 0), Vector3.new(1.4, 1.1, 1.4), C(80, 140, 255), C(255, 90, 160))
	candyCane(folder, pos + Vector3.new(-3.2, floorY, -6.4), 0.3)
	candyCane(folder, pos + Vector3.new(3.4, floorY, -6.4), math.pi - 0.3)
	snowman(folder, pos + Vector3.new(9.5, floorY, -2), -2.2)
	-- light snow over the spawn plaza
	local sky = part(folder, { Name = "SnowSky", Size = Vector3.new(90, 1, 90), CFrame = CFrame.new(-150, 45, 0), Transparency = 1, CanQuery = false })
	local snow = Instance.new("ParticleEmitter")
	snow.Color = ColorSequence.new(SNOW)
	snow.Size = NumberSequence.new(0.35)
	snow.Transparency = NumberSequence.new(0.1, 0.5)
	snow.Lifetime = NumberRange.new(9, 12)
	snow.Speed = NumberRange.new(4, 6)
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.Rate = 35
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.LightEmission = 0.3
	snow.Parent = sky
	built = { folder = folder, stand = stand }
end

local function teardown()
	if built then
		built.folder:Destroy()
		built.stand:Destroy()
		built = nil
	end
end

task.spawn(function()
	workspace:WaitForChild("World"):WaitForChild("Hub"):WaitForChild("Hatchery", 30)
	while true do
		local active = Config.winterActive()
		if active and not built then
			build()
		elseif not active and built then
			teardown()
		end
		task.wait(10)
	end
end)
