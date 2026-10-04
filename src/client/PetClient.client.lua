-- Eggs + pets (client):
--   * Egg window: walk up to an egg in the Egg Garden and press E. Shows its 4 pets (chance + money
--     boost) and Hatch x1 / x3.
--   * Hatch show: the egg wobbles while a "roll" flickers through its pets, then cracks with a flash
--     and reveals what you got (rarity color, boost, NEW!). Click / tap or wait to close.
--   * PETS button: your pets. Click a pet to equip / unequip, Equip Best, delete (click twice).
--   * Pets follow every player (drawn on each client, so they move smoothly): they hop behind you
--     when you walk and fly beside you on the rocket.
--   * The boards above the eggs show 🔒 for eggs you haven't unlocked yet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local HatchEgg = remotes:WaitForChild("HatchEgg")
local PetAction = remotes:WaitForChild("PetAction")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local abbreviate, multText = Config.abbreviate, Config.multText

local INK_SOFT = Color3.fromRGB(70, 70, 100)
local GREEN, BLUE, GREY, RED = Color3.fromRGB(80, 200, 90), Color3.fromRGB(70, 140, 255), Color3.fromRGB(160, 165, 185), Color3.fromRGB(235, 90, 90)
local PINK = Color3.fromRGB(255, 120, 190)
local RARITIES = { "Common", "Rare", "Epic", "Legendary" }

-- Models ---------------------------------------------------------------------------------------
local petFolder = ReplicatedStorage:WaitForChild("PetModels", 10)
local eggFolder = ReplicatedStorage:WaitForChild("EggModels", 10)

local function prep(m)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	return m
end

local function petModel(kind)
	local t = petFolder and petFolder:FindFirstChild(kind)
	if t then
		return prep(t:Clone())
	end
	local pet = Config.Pets[kind]
	local m = Instance.new("Model")
	make("Part", { Parent = m, Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = CFrame.new(0, 1.3, 0), Color = pet and Config.Rarities[pet.rarity].color or GREY, Material = Enum.Material.SmoothPlastic })
	m.WorldPivot = CFrame.new()
	return prep(m)
end

local function eggModel(egg)
	local t = eggFolder and eggFolder:FindFirstChild(egg.id)
	if t then
		return prep(t:Clone())
	end
	local m = Instance.new("Model")
	local p = make("Part", { Parent = m, Size = Vector3.new(3.6, 4.6, 3.6), CFrame = CFrame.new(0, 2.3, 0), Color = egg.color, Material = Enum.Material.SmoothPlastic })
	make("SpecialMesh", { Parent = p, MeshType = Enum.MeshType.Sphere })
	m.WorldPivot = CFrame.new()
	return prep(m)
end

-- A ViewportFrame showing `model` from the front (models face -Z, pivot at their feet).
local viewports = {} -- re-parented once the meshes have downloaded
local function viewport(parent, model, props)
	local vp = make("ViewportFrame", props)
	vp.Parent = parent
	vp.BackgroundTransparency = props.BackgroundTransparency or 1
	vp.Ambient = Color3.fromRGB(190, 190, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-0.5, -1, 0.8)
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	local d = size.Magnitude * 1.75
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(d * 0.28, d * 0.18, -d), cf.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
	table.insert(viewports, { vp = vp, model = model })
	return vp
end

task.spawn(function()
	local list = {}
	for _, f in ipairs({ petFolder, eggFolder }) do
		if f then
			for _, m in ipairs(f:GetChildren()) do
				table.insert(list, m)
			end
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
	for _, v in ipairs(viewports) do
		if v.model.Parent == v.vp then
			v.model.Parent = nil
			v.model.Parent = v.vp
		end
	end
end)

local function windowTitle(w)
	for _, d in ipairs(w:GetDescendants()) do
		if d:IsA("TextLabel") and d.Parent and d.Parent.Parent == w and d.TextXAlignment == Enum.TextXAlignment.Left then
			return d
		end
	end
end

-- Egg window --------------------------------------------------------------------------------------
local eggWindow, eggList = UIKit.window("Egg", GREEN, UDim2.fromOffset(640, 440))
local eggTitle = windowTitle(eggWindow)
local currentEgg = nil -- the egg def while its window is open
local eggPrompt = nil -- the prompt's part (window closes when you walk away)
local hatching = false

local cardsRow = make("Frame", { Parent = eggList, LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 196), BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIGridLayout", { CellSize = UDim2.fromOffset(128, 190), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local eggCards = {}
for i, rarity in ipairs(RARITIES) do
	local color = Config.Rarities[rarity].color
	local card = make("Frame", { Parent = cardsRow, LayoutOrder = i, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(16), UIKit.stroke(4, color) })
	make("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), UIKit.lighter(color, 0.7)) })
	local holder = make("Frame", { Parent = card, Position = UDim2.fromOffset(9, 6), Size = UDim2.fromOffset(110, 92), BackgroundTransparency = 1, ZIndex = 13 })
	local name = label({ Parent = card, Position = UDim2.fromOffset(4, 98), Size = UDim2.new(1, -8, 0, 24), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 13 })
	label({ Parent = card, Position = UDim2.fromOffset(4, 122), Size = UDim2.new(1, -8, 0, 20), Text = rarity, TextColor3 = color, StrokeThickness = 1.5, ZIndex = 13 })
	local boost = label({ Parent = card, Position = UDim2.fromOffset(4, 143), Size = UDim2.new(1, -8, 0, 22), Text = "", TextColor3 = Color3.fromRGB(40, 170, 70), StrokeThickness = 0, ZIndex = 13 })
	label({ Parent = card, Position = UDim2.fromOffset(4, 165), Size = UDim2.new(1, -8, 0, 20), Text = Config.RARITY_CHANCE[rarity] .. "%", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 13 })
	eggCards[rarity] = { holder = holder, name = name, boost = boost }
end

local hatchRow = UIKit.row(eggList, 2, 84)
local lockLabel = label({ Parent = hatchRow, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 1, -20), Text = "", TextColor3 = RED, StrokeThickness = 0, ZIndex = 12, Visible = false })
local hatch1 = UIKit.button({ Parent = hatchRow, Text = "", Color = GREEN, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.new(0.5, -21, 0, 62), ZIndex = 12 })
local hatch3 = UIKit.button({ Parent = hatchRow, Text = "", Color = BLUE, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.new(0.5, -21, 0, 62), ZIndex = 12 })

local function refreshEggWindow()
	local egg = currentEgg
	if not egg then
		return
	end
	local unlocked = (player:GetAttribute("UnlockedStage") or 1) >= egg.stage
	local money = player:GetAttribute("Money") or 0
	lockLabel.Visible = not unlocked
	lockLabel.Text = "🔒 Unlock Stage " .. egg.stage .. " to hatch this egg!"
	hatch1.Instance.Visible = unlocked
	hatch3.Instance.Visible = unlocked
	hatch1.setText("Hatch 1  $" .. abbreviate(egg.price))
	hatch3.setText("Hatch 3  $" .. abbreviate(egg.price * 3))
	hatch1.setColor(money >= egg.price and GREEN or RED)
	hatch3.setColor(money >= egg.price * 3 and BLUE or RED)
end

local function openEgg(egg, promptPart)
	currentEgg = egg
	eggPrompt = promptPart
	eggTitle.Text = egg.name
	for rarity, c in pairs(eggCards) do
		local kind = egg.pets[rarity]
		local pet = Config.Pets[kind]
		c.name.Text = pet.name
		c.boost.Text = multText(pet.mult) .. " 💰"
		c.holder:ClearAllChildren()
		viewport(c.holder, petModel(kind), { Size = UDim2.fromScale(1, 1), ZIndex = 13 })
	end
	refreshEggWindow()
	if not eggWindow.Visible then
		UIKit.toggle(eggWindow)
	end
end

-- Hatch show --------------------------------------------------------------------------------------
local gui = UIKit.gui()
local overlay = make("TextButton", { Parent = gui, Name = "HatchShow", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 50 })
local slotsHolder = make("Frame", { Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(900, 420), BackgroundTransparency = 1, ZIndex = 51 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 16) }),
	make("UISizeConstraint", { MaxSize = Vector2.new(900, 420) }),
	make("UIAspectRatioConstraint", { AspectRatio = 900 / 420 }),
})
local hint = label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(500, 34), Text = "Click to continue", TextColor3 = Color3.fromRGB(230, 230, 240), ZIndex = 52, Visible = false })
local flash = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 60, Active = false })

local function makeSlot(count)
	local w = count == 1 and 0.42 or 0.31
	local slot = make("Frame", { Parent = slotsHolder, Size = UDim2.fromScale(w, 1), BackgroundTransparency = 1, ZIndex = 51 })
	-- a sparkle burst behind the pet, tinted with its rarity color
	local rays = make("ImageLabel", { Parent = slot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(1.15, 0.85), BackgroundTransparency = 1, Image = "rbxasset://textures/particles/sparkles_main.dds", ImageTransparency = 1, ZIndex = 51 })
	make("UIAspectRatioConstraint", { Parent = rays, AspectRatio = 1 })
	local holder = make("Frame", { Parent = slot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(0.9, 0.7), BackgroundTransparency = 1, ZIndex = 52 }, {
		make("UIAspectRatioConstraint", { AspectRatio = 1 }),
	})
	local roll = label({ Parent = slot, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromScale(1, 0.11), Text = "", ZIndex = 53 })
	local sub = label({ Parent = slot, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.88), Size = UDim2.fromScale(1, 0.09), Text = "", ZIndex = 53 })
	local new = label({ Parent = slot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.78, 0.1), Size = UDim2.fromScale(0.4, 0.1), Rotation = 12, Text = "NEW!", TextColor3 = Color3.fromRGB(255, 230, 60), Visible = false, ZIndex = 54 })
	return { slot = slot, rays = rays, holder = holder, roll = roll, sub = sub, new = new }
end

local spinning = {} -- models spinning in the show
RunService.RenderStepped:Connect(function(dt)
	if not overlay.Visible then
		return
	end
	for _, s in ipairs(spinning) do
		if s.rays then
			s.rays.Rotation += dt * 40
		end
		if s.model and s.spin then
			s.model:PivotTo(CFrame.Angles(0, math.sin(os.clock() * 1.5) * 0.6, 0))
		end
	end
end)

local function playHatch(egg, results)
	hatching = true
	-- NEW! = you had no pet of that kind before this hatch
	local fresh = {}
	for _, r in ipairs(results) do
		fresh[r.uid] = true
	end
	local before = {}
	for _, p in ipairs(Config.parsePets(player:GetAttribute("Pets"))) do
		if not fresh[p.uid] then
			before[p.kind] = true
		end
	end

	for _, c in ipairs(slotsHolder:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	table.clear(spinning)
	hint.Visible = false
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.35 }):Play()
	local eggWasOpen = eggWindow.Visible
	eggWindow.Visible = false -- the show gets the whole screen

	local slots = {}
	for i, r in ipairs(results) do
		local s = makeSlot(#results)
		s.result = r
		s.eggModel = eggModel(egg)
		viewport(s.holder, s.eggModel, { Size = UDim2.fromScale(1, 1), ZIndex = 52 })
		slots[i] = s
		UIKit.bounce(s.holder)
	end

	-- the roll: names flicker faster than you can read, then slow down... while the egg wobbles
	local kinds = {}
	for _, rarity in ipairs(RARITIES) do
		table.insert(kinds, egg.pets[rarity])
	end
	local t0 = os.clock()
	local DUR = 2.1
	local nextTick, idx = 0, 0
	while os.clock() - t0 < DUR do
		local t = os.clock() - t0
		local p = t / DUR
		local amp = math.rad(4 + 26 * p)
		for _, s in ipairs(slots) do
			s.eggModel:PivotTo(CFrame.Angles(0, 0, math.sin(t * (14 + 16 * p)) * amp))
		end
		if t >= nextTick then
			idx += 1
			for k, s in ipairs(slots) do
				local kind = kinds[(idx + k) % #kinds + 1]
				local pet = Config.Pets[kind]
				s.roll.Text = pet.name
				s.roll.TextColor3 = Config.Rarities[pet.rarity].color
			end
			UIKit.sound("Click", 0.25, 0.9 + p * 0.6)
			nextTick = t + 0.05 + p * p * 0.3
		end
		RunService.RenderStepped:Wait()
	end

	-- crack!
	flash.BackgroundTransparency = 0
	TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	local best = "Common"
	for _, s in ipairs(slots) do
		local pet = Config.Pets[s.result.kind]
		local color = Config.Rarities[pet.rarity].color
		if Config.Rarities[pet.rarity].order > Config.Rarities[best].order then
			best = pet.rarity
		end
		s.holder:ClearAllChildren()
		local m = petModel(s.result.kind)
		viewport(s.holder, m, { Size = UDim2.fromScale(1, 1), ZIndex = 52 })
		UIKit.bounce(s.holder)
		s.roll.Text = pet.name
		s.roll.TextColor3 = Color3.new(1, 1, 1)
		s.sub.Text = pet.rarity .. "  •  " .. multText(pet.mult) .. " 💰"
		s.sub.TextColor3 = color
		s.rays.ImageColor3 = color
		s.rays.ImageTransparency = 0.1
		s.new.Visible = not before[s.result.kind]
		if s.new.Visible then
			UIKit.bounce(s.new)
		end
		table.insert(spinning, { rays = s.rays, model = m, spin = true })
	end
	if best == "Legendary" then
		UIKit.sound("Win", 0.9, 1.15)
	elseif best == "Epic" then
		UIKit.sound("Win", 0.7, 1)
	else
		UIKit.sound("Coin", 0.6, 1.1)
	end

	-- wait for a click (or a few seconds)
	task.wait(0.6)
	hint.Visible = true
	local closed = false
	local conn = overlay.Activated:Connect(function()
		closed = true
	end)
	local tEnd = os.clock() + 3.5
	while not closed and os.clock() < tEnd do
		task.wait(0.05)
	end
	conn:Disconnect()
	overlay.Visible = false
	table.clear(spinning)
	eggWindow.Visible = eggWasOpen and currentEgg == egg
	hatching = false
	refreshEggWindow()
end

local function doHatch(count)
	local egg = currentEgg
	if not egg or hatching then
		return
	end
	hatching = true
	local ok, results = HatchEgg:InvokeServer(egg.id, count)
	if ok then
		playHatch(egg, results)
	else
		hatching = false
		UIKit.result(false, results)
	end
end
hatch1.Instance.Activated:Connect(function()
	doHatch(1)
end)
hatch3.Instance.Activated:Connect(function()
	doHatch(3)
end)

-- Egg prompts + walking away -------------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local id = prompt:GetAttribute("Egg")
	local egg = id and Config.getEgg(id)
	if egg then
		openEgg(egg, prompt.Parent)
	end
end)

RunService.Heartbeat:Connect(function()
	if not eggPrompt or hatching then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not eggWindow.Visible then
		eggPrompt = nil
		currentEgg = nil
	elseif root and eggPrompt.Parent and (root.Position - eggPrompt.Position).Magnitude > 22 then
		eggWindow.Visible = false
		eggPrompt = nil
		currentEgg = nil
	end
end)

-- Boards above the eggs: 🔒 until you unlock the egg's stage
local function refreshBoards()
	local hub = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Hub")
	local garden = hub and hub:FindFirstChild("EggGarden")
	if not garden then
		return
	end
	local stage = player:GetAttribute("UnlockedStage") or 1
	for _, stand in ipairs(garden:GetChildren()) do
		local egg = Config.getEgg(stand:GetAttribute("Egg") or "")
		local board = stand:FindFirstChild("Board")
		local lock = board and board:FindFirstChild("Lock", true)
		if egg and lock then
			if stage >= egg.stage then
				lock.Text = "Press E to hatch!"
				lock.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				lock.Text = "🔒 Stage " .. egg.stage
				lock.TextColor3 = Color3.fromRGB(255, 120, 120)
			end
		end
	end
end
player:GetAttributeChangedSignal("UnlockedStage"):Connect(refreshBoards)
task.spawn(function()
	workspace:WaitForChild("World"):WaitForChild("Hub"):WaitForChild("EggGarden", 30)
	refreshBoards()
end)

-- Pets window ---------------------------------------------------------------------------------------
local petsWindow, petsList = UIKit.window("Pets", PINK, UDim2.fromOffset(680, 500), petFolder and petFolder:FindFirstChild("Kitty") or nil)
local topRow = UIKit.row(petsList, 0, 66)
local summary = label({ Parent = topRow, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -370, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
local summary2 = label({ Parent = topRow, Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -370, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = Color3.fromRGB(40, 170, 70), StrokeThickness = 0, ZIndex = 12 })
local equipBest = UIKit.button({ Parent = topRow, Text = "Equip Best", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(180, 50), ZIndex = 12 })
local indexBtn = UIKit.button({ Parent = topRow, Text = "📖 Index", Color = Color3.fromRGB(110, 140, 240), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -200, 0.5, 0), Size = UDim2.fromOffset(140, 50), ZIndex = 12 })

-- Pet Index: all 24 pets by egg; ones you've never had are black silhouettes. A full egg set
-- gives +10% money forever (server: PetServer / GameServer).
local indexWindow, indexList = UIKit.window("Pet Index", Color3.fromRGB(110, 140, 240), UDim2.fromOffset(700, 520))
local indexHead = UIKit.row(indexList, 0, 56)
local indexHeadText = label({ Parent = indexHead, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
local indexCards = {} -- [kind] = { vp, name }
local eggHeads = {} -- [egg.id] = { label, card }
for i, egg in ipairs(Config.Eggs) do
	local section = UIKit.card(indexList, { LayoutOrder = i, Size = UDim2.new(1, -12, 0, 214), ZIndex = 11, Tint = UIKit.lighter(egg.color, 0.7) })
	local head = label({ Parent = section, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local row = make("Frame", { Parent = section, Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 160), BackgroundTransparency = 1, ZIndex = 12 }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for j, rarity in ipairs(RARITIES) do
		local kind = egg.pets[rarity]
		local color = Config.Rarities[rarity].color
		local card = make("Frame", { Parent = row, LayoutOrder = j, Size = UDim2.fromOffset(140, 156), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(16), UIKit.stroke(3.5, color) })
		local vp = viewport(card, petModel(kind), { Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(120, 100), ZIndex = 13 })
		local name = label({ Parent = card, Position = UDim2.fromOffset(4, 104), Size = UDim2.new(1, -8, 0, 24), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 13 })
		label({ Parent = card, Position = UDim2.fromOffset(4, 128), Size = UDim2.new(1, -8, 0, 20), Text = rarity, TextColor3 = color, StrokeThickness = 1.5, ZIndex = 13 })
		indexCards[kind] = { vp = vp, name = name }
	end
	eggHeads[egg.id] = { label = head, egg = egg }
end

local function refreshIndex()
	local have = {}
	for kind in string.gmatch(player:GetAttribute("PetIndex") or "", "%w+") do
		have[kind] = true
	end
	local found = 0
	for kind, c in pairs(indexCards) do
		local got = have[kind] == true
		found += got and 1 or 0
		c.vp.ImageColor3 = got and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		c.vp.ImageTransparency = got and 0 or 0.35
		c.name.Text = got and Config.Pets[kind].name or "???"
	end
	for _, h in pairs(eggHeads) do
		local n = 0
		for _, kind in pairs(h.egg.pets) do
			n += have[kind] and 1 or 0
		end
		local done = n == 4
		h.label.Text = h.egg.name .. "   " .. n .. " / 4" .. (done and "   ✔ +10% money!" or "   (find all 4: +10% money)")
		h.label.TextColor3 = done and Color3.fromRGB(40, 160, 70) or UIKit.INK
	end
	local total = 0
	for _ in pairs(indexCards) do
		total += 1
	end
	local sets = player:GetAttribute("IndexSets") or 0
	indexHeadText.Text = "📖 Found " .. found .. " / " .. total .. " pets   •   Money bonus: +" .. math.floor(sets * Config.INDEX_SET_BONUS * 100 + 0.5) .. "%"
end
player:GetAttributeChangedSignal("PetIndex"):Connect(refreshIndex)
player:GetAttributeChangedSignal("IndexSets"):Connect(refreshIndex)
refreshIndex()
indexBtn.Instance.Activated:Connect(function()
	refreshIndex()
	UIKit.toggle(indexWindow)
end)

equipBest.Instance.Activated:Connect(function()
	UIKit.result(PetAction:InvokeServer("equipBest"))
end)
local emptyLabel = label({ Parent = petsList, LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 80), Text = "No pets yet! Hatch eggs in the Egg Garden next to the spawn 🥚", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
local grid = make("Frame", { Parent = petsList, LayoutOrder = 2, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIGridLayout", { CellSize = UDim2.fromOffset(100, 126), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})

local cards = {} -- [uid] = card info
local function makeCard(p)
	local pet = Config.Pets[p.kind]
	local color = Config.Rarities[pet.rarity].color
	local card = make("TextButton", { Parent = grid, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(14) })
	local stroke = UIKit.stroke(3.5, color)
	stroke.Parent = card
	make("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), UIKit.lighter(color, 0.72)) })
	local holder = make("Frame", { Parent = card, Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(88, 78), BackgroundTransparency = 1, ZIndex = 13 })
	viewport(holder, petModel(p.kind), { Size = UDim2.fromScale(1, 1), ZIndex = 13 })
	label({ Parent = card, Position = UDim2.fromOffset(3, 82), Size = UDim2.new(1, -6, 0, 20), Text = pet.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 13 })
	label({ Parent = card, Position = UDim2.fromOffset(3, 102), Size = UDim2.new(1, -6, 0, 20), Text = multText(pet.mult) .. " 💰", TextColor3 = Color3.fromRGB(40, 170, 70), StrokeThickness = 0, ZIndex = 13 })
	local check = label({ Parent = card, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0, BackgroundColor3 = GREEN, Text = "✔", ZIndex = 15, Visible = false }, nil)
	make("UICorner", { Parent = check, CornerRadius = UDim.new(1, 0) })
	local del = make("TextButton", { Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Color3.fromRGB(255, 235, 235), Text = "🗑", TextScaled = true, Font = UIKit.FONT, ZIndex = 15 }, { UIKit.corner(8) })
	local info = { card = card, check = check, del = del, kind = p.kind, uid = p.uid, armed = 0 }
	card.Activated:Connect(function()
		UIKit.sound("Click", 0.4)
		UIKit.bounce(card)
		local ok, msg = PetAction:InvokeServer(info.equipped and "unequip" or "equip", p.uid)
		if not ok then
			UIKit.result(false, msg)
		end
	end)
	del.Activated:Connect(function()
		if os.clock() - info.armed > 2 then
			info.armed = os.clock()
			del.Text = "?"
			del.BackgroundColor3 = RED
			task.delay(2, function()
				if del.Parent then
					del.Text = "🗑"
					del.BackgroundColor3 = Color3.fromRGB(255, 235, 235)
				end
			end)
			UIKit.toast("Click 🗑 again to delete " .. Config.Pets[p.kind].name, Color3.fromRGB(255, 200, 150))
		else
			UIKit.result(PetAction:InvokeServer("delete", p.uid))
		end
	end)
	return info
end

local function refreshPets()
	local pets = Config.parsePets(player:GetAttribute("Pets"))
	local equipped = Config.parseEquipped(player:GetAttribute("EquippedPets"))
	local seen = {}
	for _, p in ipairs(pets) do
		seen[p.uid] = true
		if not cards[p.uid] then
			cards[p.uid] = makeCard(p)
		end
	end
	for uid, c in pairs(cards) do
		if not seen[uid] then
			c.card:Destroy()
			cards[uid] = nil
		end
	end
	-- equipped first, then strongest
	table.sort(pets, function(a, b)
		local ea, eb = equipped[a.uid] and 1 or 0, equipped[b.uid] and 1 or 0
		if ea ~= eb then
			return ea > eb
		end
		local ma, mb = Config.Pets[a.kind].mult, Config.Pets[b.kind].mult
		if ma ~= mb then
			return ma > mb
		end
		return a.uid > b.uid
	end)
	local nEquipped = 0
	for i, p in ipairs(pets) do
		local c = cards[p.uid]
		c.card.LayoutOrder = i
		c.equipped = equipped[p.uid] == true
		c.check.Visible = c.equipped
		if c.equipped then
			nEquipped += 1
		end
	end
	emptyLabel.Visible = #pets == 0
	summary.Text = string.format("Pets %d / %d    Equipped %d / %d", #pets, Config.MAX_PETS, nEquipped, Config.petSlots(player:GetAttribute("Rebirths") or 0))
	summary2.Text = "Money boost: " .. multText(player:GetAttribute("PetMultiplier") or 1) .. " 💰"
end
for _, attr in ipairs({ "Pets", "EquippedPets", "PetMultiplier", "Rebirths" }) do
	player:GetAttributeChangedSignal(attr):Connect(refreshPets)
end
for _, attr in ipairs({ "Money", "UnlockedStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(refreshEggWindow)
end
refreshPets()

-- PETS button in the bottom bar
local petsBtn = UIKit.button({ Parent = UIKit.bottomBar(), LayoutOrder = 4, Icon3D = petFolder and petFolder:FindFirstChild("Puppy") or nil, Icon = "🐾", Text = "PETS", Color = PINK, Size = UDim2.fromOffset(104, 104), Radius = 24 })
petsBtn.Instance.Activated:Connect(function()
	UIKit.toggle(petsWindow)
end)

-- Following pets -------------------------------------------------------------------------------
local followFolder = Instance.new("Folder")
followFolder.Name = "PetFollowers"
followFolder.Parent = workspace

-- spots around you, in your own space (+Z = behind you)
local WALK_SLOTS = { Vector3.new(-3.6, 0, 4), Vector3.new(3.6, 0, 4), Vector3.new(0, 0, 6.5), Vector3.new(-6, 0, 7.5), Vector3.new(6, 0, 7.5), Vector3.new(0, 0, 10) }
-- in flight the pets fly beside the rocket (never between it and the camera)
local FLY_SLOTS = { Vector3.new(-5.5, 0.5, 0.5), Vector3.new(5.5, 0.5, 0.5), Vector3.new(-9.5, 2, 1.5), Vector3.new(9.5, 2, 1.5), Vector3.new(-13.5, 3.5, 3), Vector3.new(13.5, 3.5, 3) }
local followers = {} -- [player] = { kinds = string, pets = { { model, pos } } }

local function rebuildFollowers(plr)
	local f = followers[plr]
	if f then
		for _, p in ipairs(f.pets) do
			p.model:Destroy()
		end
	end
	local kindsStr = plr:GetAttribute("PetKinds") or ""
	f = { kinds = kindsStr, pets = {} }
	followers[plr] = f
	for kind in string.gmatch(kindsStr, "[^,]+") do
		if Config.Pets[kind] then
			local m = petModel(kind)
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CastShadow = true
				end
			end
			m.Parent = followFolder
			table.insert(f.pets, { model = m, pos = nil })
		end
	end
end

local function watchPlayer(plr)
	plr:GetAttributeChangedSignal("PetKinds"):Connect(function()
		rebuildFollowers(plr)
	end)
	rebuildFollowers(plr)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, plr in ipairs(Players:GetPlayers()) do
	watchPlayer(plr)
end
Players.PlayerRemoving:Connect(function(plr)
	local f = followers[plr]
	if f then
		for _, p in ipairs(f.pets) do
			p.model:Destroy()
		end
	end
	followers[plr] = nil
end)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local camera = workspace.CurrentCamera

RunService.RenderStepped:Connect(function(dt)
	local ignore = { followFolder }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	local flights = workspace:FindFirstChild("Flights")
	if flights then
		table.insert(ignore, flights)
	end
	rayParams.FilterDescendantsInstances = ignore
	local now = os.clock()
	local camPos = camera.CFrame.Position

	for plr, f in pairs(followers) do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local near = root and (root.Position - camPos).Magnitude < 350
		for i, p in ipairs(f.pets) do
			if not near then
				p.model.Parent = nil
				p.pos = nil
				continue
			end
			p.model.Parent = followFolder
			local flying = plr:GetAttribute("Flying")
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			look = look.Magnitude > 0.01 and look.Unit or Vector3.new(1, 0, 0)
			local yaw = CFrame.lookAt(Vector3.zero, look)
			local slot = (flying and FLY_SLOTS or WALK_SLOTS)[i] or Vector3.new(0, 0, 4 + i * 2)
			local target = root.Position + yaw:VectorToWorldSpace(slot)
			local lift = 0
			if flying then
				-- glide into place in the rocket's own space, so going fast never leaves them behind
				local rel = slot + Vector3.new(0, math.sin(now * 3 + i) * 0.6, 0)
				p.rel = p.rel and p.rel:Lerp(rel, 1 - math.exp(-dt * 6)) or rel
				p.pos = nil
				p.model:PivotTo(CFrame.new(root.Position + yaw:VectorToWorldSpace(p.rel)) * yaw)
				continue
			else
				p.rel = nil
				local hit = workspace:Raycast(target + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), rayParams)
				target = Vector3.new(target.X, hit and hit.Position.Y or root.Position.Y - 3, target.Z)
				local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
				lift = speed > 1.5 and math.abs(math.sin(now * 9 + i * 1.3)) * 1.1 or (math.sin(now * 2 + i) + 1) * 0.12
			end
			if not p.pos or (p.pos - target).Magnitude > 80 then
				p.pos = target
			end
			local k = 1 - math.exp(-dt * (flying and 18 or 10))
			p.pos = p.pos:Lerp(target, k)
			p.model:PivotTo(CFrame.new(p.pos + Vector3.new(0, lift, 0)) * yaw)
		end
	end
end)
