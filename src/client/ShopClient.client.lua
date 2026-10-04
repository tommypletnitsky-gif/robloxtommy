-- Shop windows: Rockets (+ Trails tab) and Upgrades. Opened from the bottom bar or the lobby buildings.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RocketModel = require(ReplicatedStorage.Shared:WaitForChild("RocketModel"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuyRocket = remotes:WaitForChild("BuyRocket")
local BuyUpgrade = remotes:WaitForChild("BuyUpgrade")
local BuyTrail = remotes:WaitForChild("BuyTrail")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local abbreviate, meters = Config.abbreviate, Config.meters

local INK_SOFT = Color3.fromRGB(70, 70, 100)
local GREEN, RED, BLUE, GREY = Color3.fromRGB(80, 200, 90), Color3.fromRGB(235, 90, 90), Color3.fromRGB(70, 140, 255), Color3.fromRGB(160, 165, 185)

local function owned(attr)
	return string.split(player:GetAttribute(attr) or "", ",")
end

local function upgradeMult(key)
	return 1 + (player:GetAttribute(key .. "Level") or 0) * Config.Upgrades[key].perLevel
end

local function rangeOf(def)
	return def.speed * upgradeMult("Speed") * def.fuel * upgradeMult("Fuel")
end

-- Rockets window -------------------------------------------------------------------------
local rocketsWindow, rocketsList = UIKit.window("🚀 Rockets", BLUE)
local tabRow = make("Frame", { Parent = rocketsList, LayoutOrder = 0, Size = UDim2.new(1, -12, 0, 54), BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
})
local rocketsTab = UIKit.button({ Parent = tabRow, Text = "🚀 Rockets", Color = BLUE, Size = UDim2.fromOffset(200, 50), ZIndex = 12 })
local trailsTab = UIKit.button({ Parent = tabRow, Text = "✨ Trails", Color = GREY, Size = UDim2.fromOffset(200, 50), ZIndex = 12 })

local rocketRows, trailRows = {}, {}
local spinning = {}

for i, def in ipairs(Config.Rockets) do
	local r = UIKit.row(rocketsList, i, 110)
	local vp = make("ViewportFrame", { Parent = r, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(90, 90), BackgroundColor3 = Color3.fromRGB(215, 230, 255), Ambient = Color3.fromRGB(200, 200, 210), LightColor = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(16) })
	local model = RocketModel.build(def, 1, false, CFrame.new())
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(3, 4, 15), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
	table.insert(spinning, { model = model, phase = i, vp = vp })
	label({ Parent = r, Position = UDim2.fromOffset(112, 12), Size = UDim2.new(1, -270, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, Text = def.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local stats = label({ Parent = r, Position = UDim2.fromOffset(112, 50), Size = UDim2.new(1, -270, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
	local range = label({ Parent = r, Position = UDim2.fromOffset(112, 76), Size = UDim2.new(1, -270, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = Color3.fromRGB(60, 160, 80), StrokeThickness = 0, ZIndex = 12 })
	local button = UIKit.button({ Parent = r, Text = "", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 58), ZIndex = 12 })
	button.Instance.Activated:Connect(function()
		UIKit.result(BuyRocket:InvokeServer(def.id))
	end)
	rocketRows[def.id] = { def = def, row = r, stats = stats, range = range, button = button }
end

for i, def in ipairs(Config.Trails) do
	local r = UIKit.row(rocketsList, 100 + i, 84)
	r.Visible = false
	local swatch = make("Frame", { Parent = r, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(110, 60), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(14), UIKit.stroke(3) })
	local keys = {}
	for k, c in ipairs(def.colors) do
		table.insert(keys, ColorSequenceKeypoint.new(#def.colors == 1 and 0 or (k - 1) / (#def.colors - 1), c))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, def.colors[1]))
	end
	make("UIGradient", { Parent = swatch, Color = ColorSequence.new(keys) })
	if def.id == "None" then
		swatch.BackgroundColor3 = Color3.fromRGB(230, 230, 240)
		label({ Parent = swatch, Size = UDim2.fromScale(1, 1), Text = "-", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 13 })
	end
	label({ Parent = r, Position = UDim2.fromOffset(136, 14), Size = UDim2.new(1, -300, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, Text = def.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	label({ Parent = r, Position = UDim2.fromOffset(136, 48), Size = UDim2.new(1, -300, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Text = (def.glow or 0) > 0.5 and "Glowing trail" or "Trail", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
	local button = UIKit.button({ Parent = r, Text = "", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 54), ZIndex = 12 })
	button.Instance.Activated:Connect(function()
		UIKit.result(BuyTrail:InvokeServer(def.id))
	end)
	trailRows[def.id] = { def = def, row = r, button = button }
end

-- The rocket meshes may still be downloading when these previews are built; once they're loaded,
-- re-add each preview model so the ViewportFrame draws it.
task.spawn(function()
	local folder = ReplicatedStorage:FindFirstChild("RocketModels")
	if folder then
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(folder:GetChildren())
		end)
	end
	for _, s in ipairs(spinning) do
		s.model.Parent = nil
		s.model.Parent = s.vp
	end
end)

local function showTab(trails)
	for _, info in pairs(rocketRows) do
		info.row.Visible = not trails
	end
	for _, info in pairs(trailRows) do
		info.row.Visible = trails
	end
	rocketsTab.setColor(trails and GREY or BLUE)
	trailsTab.setColor(trails and Color3.fromRGB(230, 90, 200) or GREY)
	rocketsList.CanvasPosition = Vector2.zero
end
rocketsTab.Instance.Activated:Connect(function()
	showTab(false)
end)
trailsTab.Instance.Activated:Connect(function()
	showTab(true)
end)

local function setBuyButton(button, isEquipped, isOwned, price)
	if isEquipped then
		button.setText("EQUIPPED")
		button.setColor(GREY)
	elseif isOwned then
		button.setText("EQUIP")
		button.setColor(BLUE)
	else
		button.setText("$" .. abbreviate(price))
		button.setColor((player:GetAttribute("Money") or 0) >= price and GREEN or RED)
	end
end

local function refreshRockets()
	local mine = owned("OwnedRockets")
	local equipped = player:GetAttribute("Rocket")
	for id, info in pairs(rocketRows) do
		local def = info.def
		info.stats.Text = string.format("Speed %d   Fuel %ss", def.speed, tostring(def.fuel))
		info.range.Text = "Range ~" .. meters(rangeOf(def))
		setBuyButton(info.button, id == equipped, table.find(mine, id) ~= nil, def.price)
	end
	local mineT = owned("OwnedTrails")
	local trail = player:GetAttribute("Trail")
	for id, info in pairs(trailRows) do
		setBuyButton(info.button, id == trail, table.find(mineT, id) ~= nil or id == "None", info.def.price)
	end
end

-- Spin the rocket previews while the window is open
RunService.RenderStepped:Connect(function()
	if not rocketsWindow.Visible then
		return
	end
	local t = os.clock()
	for _, s in ipairs(spinning) do
		s.model:PivotTo(CFrame.Angles(0, t * 0.8 + s.phase, math.rad(25)))
	end
end)

-- Upgrades window ------------------------------------------------------------------------
local upgradesWindow, upgradesList = UIKit.window("⬆️ Upgrades", Color3.fromRGB(170, 80, 240))
local rangeRow = UIKit.row(upgradesList, 0, 60)
local rangeLabel = label({ Parent = rangeRow, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 1, -20), Text = "", TextColor3 = Color3.fromRGB(255, 170, 30), ZIndex = 12 })
local upgradeRows = {}
local ICONS = { Fuel = "⛽", Speed = "🔥", Money = "💰" }
local WHAT = { Fuel = "fuel", Speed = "speed", Money = "money" }
for i, key in ipairs({ "Fuel", "Speed", "Money" }) do
	local u = Config.Upgrades[key]
	local r = UIKit.row(upgradesList, i, 104)
	local iconBox = make("Frame", { Parent = r, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(80, 80), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(20), UIKit.stroke(3), UIKit.gloss(({ Fuel = Color3.fromRGB(255, 170, 40), Speed = Color3.fromRGB(255, 90, 70), Money = GREEN })[key]) })
	label({ Parent = iconBox, Size = UDim2.fromScale(1, 1), Text = ICONS[key], ZIndex = 13 })
	label({ Parent = r, Position = UDim2.fromOffset(104, 12), Size = UDim2.new(1, -270, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, Text = u.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local info = label({ Parent = r, Position = UDim2.fromOffset(104, 50), Size = UDim2.new(1, -270, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
	local levelBack = make("Frame", { Parent = r, Position = UDim2.fromOffset(104, 78), Size = UDim2.new(1, -270, 0, 14), BackgroundColor3 = Color3.fromRGB(220, 225, 240), ZIndex = 12 }, { UIKit.corner(7) })
	local levelFill = make("Frame", { Parent = levelBack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(170, 80, 240), ZIndex = 13 }, { UIKit.corner(7) })
	local button = UIKit.button({ Parent = r, Text = "", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 58), ZIndex = 12 })
	button.Instance.Activated:Connect(function()
		UIKit.result(BuyUpgrade:InvokeServer(key))
	end)
	upgradeRows[key] = { info = info, button = button, fill = levelFill }
end

local function refreshUpgrades()
	local money = player:GetAttribute("Money") or 0
	local def = Config.getRocket(player:GetAttribute("Rocket"))
	rangeLabel.Text = "🚀 " .. def.name .. " range: ~" .. meters(rangeOf(def))
	for key, r in pairs(upgradeRows) do
		local u = Config.Upgrades[key]
		local level = player:GetAttribute(key .. "Level") or 0
		r.info.Text = string.format("Level %d / %d   +%d%% %s", level, u.maxLevel, math.floor(level * u.perLevel * 100 + 0.5), WHAT[key])
		r.fill.Size = UDim2.fromScale(level / u.maxLevel, 1)
		if level >= u.maxLevel then
			r.button.setText("MAX")
			r.button.setColor(GREY)
		else
			local cost = Config.upgradeCost(key, level)
			r.button.setText("$" .. abbreviate(cost))
			r.button.setColor(money >= cost and GREEN or RED)
		end
	end
end

for _, attr in ipairs({ "Money", "Rocket", "OwnedRockets", "Trail", "OwnedTrails", "FuelLevel", "SpeedLevel", "MoneyLevel" }) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		refreshRockets()
		refreshUpgrades()
	end)
end
refreshRockets()
refreshUpgrades()

-- Rockets / Upgrades open only at the lobby buildings (walk in, press E) ----------------------
-- and close again by themselves when you walk away.
local windowsByName = { Rockets = rocketsWindow, Upgrades = upgradesWindow }
local openedAt = nil -- the prompt's part while one of these windows is open

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local w = windowsByName[prompt:GetAttribute("OpenWindow") or ""]
	if w and not w.Visible then
		UIKit.toggle(w)
		openedAt = prompt.Parent
	end
end)

RunService.Heartbeat:Connect(function()
	if not openedAt then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local stillOpen = rocketsWindow.Visible or upgradesWindow.Visible
	if not stillOpen then
		openedAt = nil
	elseif root and openedAt.Parent and (root.Position - openedAt.Position).Magnitude > 24 then
		rocketsWindow.Visible = false
		upgradesWindow.Visible = false
		openedAt = nil
	end
end)
