-- The special egg stands on the lawn north of the spawn plaza (built at runtime, inside the Hatchery
-- model so the egg prompts, boards and EggLooks rigs work like the other eggs):
--   * LIMITED EGG: a marble showcase with a "⏳ LIMITED" sign. The egg on it changes every week
--     (Config.limitedEgg, the same on every server); its colours follow the egg. The client fills
--     in the price (it follows your best egg) and the time left on the board (HatcheryClient).
--   * ROYAL EGG: a golden throne-like stand with a red carpet, pillars and treasure. Bought with
--     Robux (EggClient / ExtrasServer).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Color3.fromRGB
local INK = C(30, 30, 50)
local GOLD, GOLD_DARK = C(255, 196, 60), C(200, 140, 30)
local MARBLE, MARBLE_DARK = C(240, 240, 248), C(205, 208, 222)

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
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
local function ball(parent, d, pos, color, props)
	local p = part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * d, CFrame = CFrame.new(pos), Color = color })
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

-- the lawn height at a spot
local function groundY(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), params)
	return hit and hit.Position.Y or 0.3
end

local function board(parent, pos, lines)
	local anchor = part(parent, { Name = "Board", Size = Vector3.one, CFrame = CFrame.new(pos), Transparency = 1, CanQuery = false })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(9, 3.6)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.Parent = anchor
	local y = 0
	for _, l in ipairs(lines) do
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
	return anchor
end

-- a plaque on the front of a plinth with big text (both sides readable)
local function sign(parent, cf, width, text, color, textColor)
	local panel = part(parent, { Name = "Plaque", Size = Vector3.new(width, 1.25, 0.3), CFrame = cf, Color = color })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 50
		sg.LightInfluence = 0
		sg.Parent = panel
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = textColor or Color3.new(1, 1, 1)
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = INK
		st.Parent = t
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.05, 0), UDim.new(0.05, 0)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.08, 0), UDim.new(0.08, 0)
		pad.Parent = t
		t.Parent = sg
	end
	return panel
end

local function prompt(parent, pos, egg)
	local hit = part(parent, { Name = "PromptPart", Size = Vector3.new(5, 6, 5), CFrame = CFrame.new(pos), Transparency = 1, CanQuery = true })
	local p = Instance.new("ProximityPrompt")
	p.Name = "EggPrompt"
	p.ActionText = "Open"
	p.ObjectText = egg.name
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p:SetAttribute("Egg", egg.id)
	p.Parent = hit
	return p
end

local function placeEgg(stand, egg, home)
	local old = stand:FindFirstChild("Egg")
	if old then
		old:Destroy()
	end
	local template = ReplicatedStorage:FindFirstChild("EggModels") and ReplicatedStorage.EggModels:FindFirstChild(egg.id)
	local e
	if template then
		e = template:Clone()
	else
		e = Instance.new("Model")
		local p = part(e, { Size = Vector3.new(3.8, 5, 3.8), CFrame = CFrame.new(0, 2.5, 0), Color = egg.color })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		e.WorldPivot = CFrame.new()
	end
	e.Name = "Egg"
	for _, d in ipairs(e:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch = true, false, false
		end
	end
	e:PivotTo(home)
	e:SetAttribute("Home", home)
	e:SetAttribute("EggId", egg.id)
	e.Parent = stand
	CollectionService:AddTag(e, "HatcheryEgg")
	return e
end

-- Limited egg ---------------------------------------------------------------------------------------
local function buildLimited(hatchery)
	local egg = Config.limitedEgg()
	local pos = Config.LIMITED_STAND
	local y = groundY(pos)
	local stand = Instance.new("Model")
	stand.Name = "Egg_Limited"
	stand:SetAttribute("Egg", egg.id)
	stand:SetAttribute("Limited", true)
	stand.Parent = hatchery
	local base = Vector3.new(pos.X, y, pos.Z)
	-- facing the spawn plaza
	local face = CFrame.lookAt(base, Vector3.new(-152, y, 0))
	cyl(stand, 1, 10.5, CFrame.new(base + Vector3.new(0, 0.5, 0)), MARBLE_DARK, { Material = Enum.Material.Marble, CanCollide = true })
	cyl(stand, 1, 8.6, CFrame.new(base + Vector3.new(0, 1.5, 0)), MARBLE, { Material = Enum.Material.Marble, CanCollide = true })
	local ring = cyl(stand, 0.3, 9, CFrame.new(base + Vector3.new(0, 2.1, 0)), egg.accent or egg.color, { Name = "AccentRing", Material = Enum.Material.Neon })
	local top = cyl(stand, 0.4, 7.6, CFrame.new(base + Vector3.new(0, 2.3, 0)), MARBLE, { Material = Enum.Material.Marble })
	local lights = {}
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = base + Vector3.new(math.cos(a) * 4.7, 1.1, math.sin(a) * 4.7)
		table.insert(lights, ball(stand, 0.6, p, egg.accent or egg.color, { Name = "Light", Material = Enum.Material.Neon }))
	end
	-- four slim pillars with glowing orbs
	for i = 1, 4 do
		local a = (i - 0.5) / 4 * math.pi * 2
		local p = base + Vector3.new(math.cos(a) * 6.4, 0, math.sin(a) * 6.4)
		cyl(stand, 6.5, 0.7, CFrame.new(p + Vector3.new(0, 3.25, 0)), MARBLE, { Material = Enum.Material.Marble })
		cyl(stand, 0.4, 1.2, CFrame.new(p + Vector3.new(0, 6.6, 0)), GOLD, { Material = Enum.Material.Metal })
		table.insert(lights, ball(stand, 1.1, p + Vector3.new(0, 7.3, 0), egg.color, { Name = "Orb", Material = Enum.Material.Neon }))
	end
	-- the sign behind the egg
	sign(stand, face * CFrame.new(0, 1.45, -4.45), 5.6, "⏳ LIMITED EGG", C(255, 120, 190))
	local home = CFrame.lookAt(base + Vector3.new(0, 2.5, 0), base + Vector3.new(0, 2.5, 0) + face.LookVector)
	local e = placeEgg(stand, egg, home)
	local _, size = e:GetBoundingBox()
	local b = board(stand, base + Vector3.new(0, 2.5 + size.Y + 3.2, 0), {
		{ "Title", 0.42, egg.name, Color3.new(1, 1, 1) },
		{ "Price", 0.31, "", C(130, 255, 130) },
		{ "Lock", 0.27, "", C(255, 220, 120) },
	})
	local p = prompt(stand, base + Vector3.new(0, 4.5, 0), egg)

	-- a new egg every week: swap it in place
	task.spawn(function()
		while stand.Parent do
			task.wait(20)
			local now = Config.limitedEgg()
			if now ~= egg then
				egg = now
				stand:SetAttribute("Egg", egg.id)
				p:SetAttribute("Egg", egg.id)
				p.ObjectText = egg.name
				ring.Color = egg.accent or egg.color
				for _, l in ipairs(lights) do
					l.Color = l.Name == "Orb" and egg.color or (egg.accent or egg.color)
				end
				placeEgg(stand, egg, home)
				b.BillboardGui.Title.Text = egg.name
			end
		end
	end)
	return stand, top
end

-- Royal egg ------------------------------------------------------------------------------------------
local function buildRoyal(hatchery)
	local egg = Config.getEgg("Royal")
	local pos = Config.ROYAL_STAND
	local y = groundY(pos)
	local stand = Instance.new("Model")
	stand.Name = "Egg_Royal"
	stand:SetAttribute("Egg", egg.id)
	stand.Parent = hatchery
	local base = Vector3.new(pos.X, y, pos.Z)
	local face = CFrame.lookAt(base, Vector3.new(-152, y, 0))
	-- red carpet toward the plaza
	part(stand, { Name = "Carpet", Size = Vector3.new(4.5, 0.12, 14), CFrame = face * CFrame.new(0, 0.08, -10), Color = C(200, 30, 50), Material = Enum.Material.Fabric })
	for _, s in ipairs({ -1, 1 }) do
		part(stand, { Size = Vector3.new(0.25, 0.14, 14), CFrame = face * CFrame.new(s * 2.25, 0.1, -10), Color = GOLD, Material = Enum.Material.Metal })
		-- velvet rope posts along the carpet
		for k = 0, 2 do
			local post = face * CFrame.new(s * 3.4, 0, -5 - k * 4.5)
			cyl(stand, 2.4, 0.4, post * CFrame.new(0, 1.2, 0), GOLD, { Material = Enum.Material.Metal })
			ball(stand, 0.7, (post * CFrame.new(0, 2.5, 0)).Position, GOLD, { Material = Enum.Material.Metal })
			if k < 2 then
				part(stand, { Size = Vector3.new(0.22, 0.22, 4.4), CFrame = post * CFrame.new(0, 2.1, -2.25), Color = C(170, 20, 50), Material = Enum.Material.Fabric })
			end
		end
	end
	-- golden stepped plinth
	cyl(stand, 1, 10, CFrame.new(base + Vector3.new(0, 0.5, 0)), GOLD_DARK, { Material = Enum.Material.Metal, CanCollide = true })
	cyl(stand, 1, 8.2, CFrame.new(base + Vector3.new(0, 1.5, 0)), GOLD, { Material = Enum.Material.Metal, CanCollide = true })
	cyl(stand, 0.3, 8.6, CFrame.new(base + Vector3.new(0, 2.1, 0)), C(255, 90, 200), { Material = Enum.Material.Neon })
	cyl(stand, 0.4, 7.4, CFrame.new(base + Vector3.new(0, 2.3, 0)), C(150, 20, 50), { Material = Enum.Material.Fabric })
	-- gems around the plinth
	local gems = { C(255, 60, 90), C(60, 140, 255), C(80, 230, 140), C(200, 90, 255) }
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		part(stand, { Size = Vector3.new(0.7, 0.7, 0.7), CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 4.15, 1.5, math.sin(a) * 4.15)) * CFrame.Angles(0.6, a, 0.6), Color = gems[i % 4 + 1], Material = Enum.Material.Glass, Transparency = 0.1 })
	end
	-- golden pillars with crowns of light, behind the egg
	for _, s in ipairs({ -1, 1 }) do
		local p = face * CFrame.new(s * 5.6, 0, 3.2)
		cyl(stand, 8, 1, p * CFrame.new(0, 4, 0), GOLD, { Material = Enum.Material.Metal })
		cyl(stand, 0.5, 1.6, p * CFrame.new(0, 8.2, 0), GOLD_DARK, { Material = Enum.Material.Metal })
		ball(stand, 1.3, (p * CFrame.new(0, 9.1, 0)).Position, C(255, 230, 120), { Material = Enum.Material.Neon })
	end
	sign(stand, face * CFrame.new(0, 1.45, -4.25), 5.6, "👑 ROYAL EGG", C(190, 30, 60), C(255, 225, 120))
	-- treasure: piles of coins and a chest beside the plinth
	local function coins(at, n)
		for i = 1, n do
			local a = i * 2.4
			cyl(stand, 0.18, 0.8, CFrame.new(at + Vector3.new(math.cos(a) * 0.5 * (i % 3), 0.1 + (i // 3) * 0.2, math.sin(a) * 0.5 * (i % 3))), GOLD, { Material = Enum.Material.Metal })
		end
	end
	coins((face * CFrame.new(-4.6, 0, -3.2)).Position, 9)
	coins((face * CFrame.new(4.8, 0, -2.6)).Position, 7)
	local chest = face * CFrame.new(-5.4, 0, -0.4) * CFrame.Angles(0, 0.5, 0)
	part(stand, { Size = Vector3.new(2.2, 1.3, 1.5), CFrame = chest * CFrame.new(0, 0.65, 0), Color = C(140, 80, 40), Material = Enum.Material.Wood, CanCollide = true })
	part(stand, { Size = Vector3.new(2.3, 0.5, 1.6), CFrame = chest * CFrame.new(0, 1.55, -0.4) * CFrame.Angles(-0.7, 0, 0), Color = C(120, 65, 30), Material = Enum.Material.Wood })
	part(stand, { Size = Vector3.new(1.9, 0.3, 1.2), CFrame = chest * CFrame.new(0, 1.35, 0), Color = GOLD, Material = Enum.Material.Neon })
	local home = CFrame.lookAt(base + Vector3.new(0, 2.5, 0), base + Vector3.new(0, 2.5, 0) + face.LookVector)
	local e = placeEgg(stand, egg, home)
	local _, size = e:GetBoundingBox()
	local p1 = Config.getProduct("RoyalEgg1")
	board(stand, base + Vector3.new(0, 2.5 + size.Y + 3.2, 0), {
		{ "Title", 0.42, "👑 " .. egg.name, C(255, 225, 120) },
		{ "Price", 0.31, "R$ " .. p1.robux, C(130, 255, 130) },
		{ "Info", 0.27, "Epic and rarer pets only!", Color3.new(1, 1, 1) },
	})
	prompt(stand, base + Vector3.new(0, 4.5, 0), egg)
	return stand
end

task.spawn(function()
	local hub = workspace:WaitForChild("World"):WaitForChild("Hub")
	local hatchery = hub:WaitForChild("Hatchery", 30)
	if not hatchery then
		return
	end
	buildLimited(hatchery)
	buildRoyal(hatchery)
end)
