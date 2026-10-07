-- Halloween event (server). Only does anything while Config.halloweenActive():
--   * the Spooky Egg at the Hatchery's entrance: a little graveyard (gravestones, a dead tree,
--     candles, pumpkins) with the jack-o'-lantern egg on a pedestal - tagged HatcheryEgg like the
--     others, so it gets its bats / ghosts / candle glow (EggLooks) and PetClient's egg window just
--     works (attribute Egg = "Spooky", same prompt) - paid with candy
--   * jack-o-lanterns along the lobby's main path
-- When the event ends (Config.Halloween.ends) everything is removed again.
-- Candy itself is handed out where it's earned (GameServer pickups, QuestServer missions).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Color3.fromRGB
local PURPLE, ORANGE, INK = C(130, 70, 200), C(255, 140, 30), C(30, 30, 50)
local built = nil -- the Halloween folder while it exists

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local UP = CFrame.Angles(0, 0, math.pi / 2)
local function cyl(parent, length, diameter, cf, color)
	return part(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), CFrame = cf, Color = color })
end

-- a jack-o-lantern: the generated mesh if the place has it, else a part pumpkin
local function pumpkin(parent, pos, yaw, scale)
	local template = ReplicatedStorage:FindFirstChild("HalloweenModels") and ReplicatedStorage.HalloweenModels:FindFirstChild("JackOLantern")
	local m
	if template then
		m = template:Clone()
		if scale ~= 1 then
			m:ScaleTo(m:GetScale() * scale)
		end
	else
		m = Instance.new("Model")
		local body = part(m, { Shape = Enum.PartType.Ball, Size = Vector3.new(3, 2.4, 3) * scale, CFrame = CFrame.new(0, 1.2 * scale, 0), Color = ORANGE })
		part(m, { Size = Vector3.new(0.4, 0.7, 0.4) * scale, CFrame = CFrame.new(0, 2.6 * scale, 0), Color = C(70, 140, 50) })
		m.PrimaryPart = body
		m.WorldPivot = CFrame.new()
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0))
	m.Parent = parent
	return m
end

local function gravestone(parent, pos, yaw, scale)
	local stone = C(120, 118, 135)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(math.random(-8, 8)), 0, math.rad(math.random(-6, 6)))
	part(parent, { Size = Vector3.new(1.8, 1.9, 0.45) * scale, CFrame = cf * CFrame.new(0, 0.95 * scale, 0), Color = stone, Material = Enum.Material.Slate, CanCollide = false })
	cyl(parent, 0.45 * scale, 1.8 * scale, cf * CFrame.new(0, 1.9 * scale, 0) * CFrame.Angles(0, math.pi / 2, 0), stone).Material = Enum.Material.Slate
	part(parent, { Size = Vector3.new(1.1, 0.14, 0.05) * scale, CFrame = cf * CFrame.new(0, 1.5 * scale, -0.24 * scale), Color = C(70, 66, 85), CanCollide = false })
	part(parent, { Size = Vector3.new(0.14, 0.9, 0.05) * scale, CFrame = cf * CFrame.new(0, 1.3 * scale, -0.24 * scale), Color = C(70, 66, 85), CanCollide = false })
	-- a little dirt mound in front
	part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.new(2, 0.6, 2) * scale, CFrame = cf * CFrame.new(0, 0, -1.3 * scale), Color = C(85, 65, 60), Material = Enum.Material.Ground, CanCollide = false })
end

local function deadTree(parent, pos, yaw)
	local bark = C(55, 40, 45)
	local base = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
	cyl(parent, 7, 1.1, base * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.pi / 2 + 0.06), bark).Material = Enum.Material.Wood
	for i, b in ipairs({ { 4.6, 0.9, 2.8 }, { 5.6, -1.1, 2.2 }, { 6.4, 0.6, 1.8 }, { 3.6, -0.8, 1.6 } }) do
		local dir = CFrame.Angles(0, i * 1.7, b[2])
		local cf = base * CFrame.new(0, b[1], 0) * dir * CFrame.new(0, b[3] / 2, 0)
		cyl(parent, b[3], 0.45, cf * CFrame.Angles(0, 0, math.pi / 2), bark).Material = Enum.Material.Wood
	end
end

local function candle(parent, pos, h)
	cyl(parent, h, 0.4, CFrame.new(pos + Vector3.new(0, h / 2, 0)) * UP, C(245, 235, 210))
	local flame = part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.28, 0.5, 0.28), CFrame = CFrame.new(pos + Vector3.new(0, h + 0.25, 0)), Color = C(255, 180, 60), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
	local light = Instance.new("PointLight")
	light.Color = C(255, 150, 50)
	light.Brightness = 0.8
	light.Range = 7
	light.Parent = flame
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
	local world = workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	local garden = hub and hub:FindFirstChild("Hatchery")
	local egg = Config.getEgg("Spooky")
	if not garden or not egg then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Halloween"
	folder.Parent = hub

	-- Spooky Egg pedestal (inside the Hatchery model so PetClient's egg boards / prompts find it)
	local pos = egg.stand
	local stand = Instance.new("Model")
	stand.Name = "Egg_Spooky"
	stand:SetAttribute("Egg", egg.id)
	stand.Parent = garden
	local floorY = 0.3
	cyl(stand, 1.4, 8.4, CFrame.new(pos + Vector3.new(0, floorY + 0.7, 0)) * UP, C(70, 45, 110))
	cyl(stand, 1.1, 7, CFrame.new(pos + Vector3.new(0, floorY + 1.9, 0)) * UP, PURPLE)
	cyl(stand, 0.4, 7.6, CFrame.new(pos + Vector3.new(0, floorY + 2.55, 0)) * UP, ORANGE)
	local top = floorY + 2.75
	local template = ReplicatedStorage:FindFirstChild("EggModels") and ReplicatedStorage.EggModels:FindFirstChild("Spooky")
	local e
	if template then
		e = template:Clone()
	else
		e = Instance.new("Model")
		local p = part(e, { Shape = Enum.PartType.Ball, Size = Vector3.new(3.6, 4.6, 3.6), CFrame = CFrame.new(0, 2.3, 0), Color = PURPLE })
		e.PrimaryPart = p
		e.WorldPivot = CFrame.new()
	end
	e.Name = "Egg"
	for _, d in ipairs(e:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch = true, false, false
		end
	end
	-- facing the Hatchery walk (south); HatcheryClient bobs it and adds the bats / ghosts / glow
	local home = CFrame.lookAt(pos + Vector3.new(0, top, 0), pos + Vector3.new(0, top, -10))
	e:PivotTo(home)
	e:SetAttribute("Home", home)
	e:SetAttribute("EggId", egg.id)
	e.Parent = stand
	CollectionService:AddTag(e, "HatcheryEgg")
	local _, eggSize = e:GetBoundingBox()
	local anchor = part(stand, { Name = "Board", Size = Vector3.one, CFrame = CFrame.new(pos + Vector3.new(0, top + eggSize.Y + 3.2, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	board(anchor, {
		{ name = "Title", h = 0.4, text = "🎃 " .. egg.name, color = C(255, 190, 90) },
		{ name = "Price", h = 0.32, text = "🍬 " .. egg.price .. " candy", color = C(255, 160, 220) },
		{ name = "Lock", h = 0.28, text = "Press E to hatch!", color = C(255, 255, 255) },
	})
	local hit = part(stand, { Name = "PromptPart", Size = Vector3.new(5, 6, 5), CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0)), Transparency = 1, CanCollide = false, CanTouch = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = egg.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Egg", egg.id)
	prompt.Parent = hit
	-- pumpkins in front of the pedestal, a little graveyard behind it, candles on its rim
	for i, a in ipairs({ 200, 245, 295, 340 }) do
		local r = math.rad(a)
		pumpkin(folder, pos + Vector3.new(math.cos(r) * 6.4, floorY, math.sin(r) * 6.4), a + 90 + i * 20, 1.1)
	end
	for i, a in ipairs({ 25, 62, 118, 155 }) do
		local r = math.rad(a)
		local at = pos + Vector3.new(math.cos(r) * 7.6, floorY, math.sin(r) * 7.6)
		-- (each stone faces the pedestal)
		gravestone(folder, at, math.deg(math.atan2(at.X - pos.X, at.Z - pos.Z)) + (i % 2 == 0 and 8 or -8), i % 2 == 0 and 1 or 0.85)
	end
	deadTree(folder, pos + Vector3.new(-8.5, floorY, 6.5), 20)
	for _, a in ipairs({ 30, 150, 215, 325 }) do
		local r = math.rad(a)
		candle(folder, pos + Vector3.new(math.cos(r) * 3.1, top, math.sin(r) * 3.1), 0.6 + (a % 3) * 0.25)
	end

	-- jack-o-lanterns by the lamp posts along the main path (spawn -> launch pad), both sides
	for i, x in ipairs({ -112, -76, -58, -40 }) do -- (not by the first lamp: the spawn's flower ring is there)
		pumpkin(folder, Vector3.new(x - 3.6, 0.1, 12.6), 180 + (i % 2) * 30, 1.5)
		pumpkin(folder, Vector3.new(x - 3.6, 0.1, -12.6), (i % 2) * -30, 1.5)
	end
	built = { folder = folder, stand = stand }
end

local function teardown()
	if built then
		built.folder:Destroy()
		if built.stand then
			built.stand:Destroy()
		end
		built = nil
	end
end

task.spawn(function()
	workspace:WaitForChild("World"):WaitForChild("Hub"):WaitForChild("Hatchery", 30)
	while true do
		local active = Config.halloweenActive()
		if active and not built then
			build()
		elseif not active and built then
			teardown()
		end
		task.wait(60)
	end
end)
