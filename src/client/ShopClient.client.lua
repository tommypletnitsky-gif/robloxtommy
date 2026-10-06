-- Shop windows: Rockets (+ Trails tab) and Upgrades. They open at the lobby buildings (walk in,
-- press E) and close again when you walk away.
--   Rockets: a grid of cards - spinning 3D rocket, speed / fuel bars, range, buy / equip button.
--   Trails:  cards with a big color swatch.
--   Upgrades: big cards - 3D icon, level bar, what it does now -> next level, price button.
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
local PURPLE, PINK, ORANGE = Color3.fromRGB(170, 80, 240), Color3.fromRGB(235, 90, 200), Color3.fromRGB(255, 160, 40)
local GOLD = Color3.fromRGB(255, 190, 40)
local MAX_SPEED, MAX_FUEL = Config.Rockets[#Config.Rockets].speed, Config.Rockets[#Config.Rockets].fuel

local function owned(attr)
	return string.split(player:GetAttribute(attr) or "", ",")
end

local function upgradeMult(key)
	return 1 + (player:GetAttribute(key .. "Level") or 0) * Config.Upgrades[key].perLevel
end

local function rangeOf(def)
	return def.speed * upgradeMult("Speed") * def.fuel * upgradeMult("Fuel")
end

local function rocketIcon(def)
	return RocketModel.build(def, 1, false, CFrame.new())
end

-- Buying feels good: purchase chime + the card pops (errors just get the red toast).
-- (a plain toast: UIKit.result's coin sound would swallow the chime)
local function bought(card, ok, msg, pitch)
	UIKit.toast(msg, ok and Color3.fromRGB(130, 255, 130) or Color3.fromRGB(255, 140, 140))
	if ok then
		UIKit.sound("Gem", 0.55, pitch or 1.15)
		UIKit.bounce(card)
	end
end

-- Rockets window -------------------------------------------------------------------------
local rocketsWindow, rocketsList = UIKit.window("Rockets", BLUE, UDim2.fromOffset(780, 520), "Rockets")

-- tabs: a two-part pill switch
local tabRow = make("Frame", { Parent = rocketsList, LayoutOrder = 0, Size = UDim2.new(1, -12, 0, 60), BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }),
})
local rocketsTab = UIKit.button({ Parent = tabRow, Text = "🚀 ROCKETS", Color = BLUE, Size = UDim2.fromOffset(230, 56), ZIndex = 12, Radius = 28 })
local trailsTab = UIKit.button({ Parent = tabRow, Text = "✨ TRAILS", Color = GREY, Size = UDim2.fromOffset(230, 56), ZIndex = 12, Radius = 28 })

local function grid(order, cell)
	return make("Frame", { Parent = rocketsList, LayoutOrder = order, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 11 }, {
		make("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end
local rocketGrid = grid(1, UDim2.fromOffset(226, 300))
local trailGrid = grid(2, UDim2.fromOffset(226, 210))
trailGrid.Visible = false

local rocketCards, trailCards = {}, {}
local previews = {}

for i, def in ipairs(Config.Rockets) do
	local card = UIKit.card(rocketGrid, { LayoutOrder = i, ZIndex = 11, Tint = UIKit.lighter(def.color, 0.75) })
	-- preview stage
	local stage = make("Frame", { Parent = card, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 120), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(16), UIKit.stroke(2.5, Color3.fromRGB(200, 210, 235)) })
	make("UIGradient", { Parent = stage, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(205, 230, 255), Color3.fromRGB(240, 246, 255)) })
	local vp = UIKit.icon3D(stage, rocketIcon(def), { ZIndex = 13, Yaw = 145, Zoom = 1.15 })
	table.insert(previews, vp)
	local tierPill = UIKit.pill(card, { Text = "#" .. i, Color = UIKit.darker(def.color, 0.15), Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(46, 26), ZIndex = 14 })
	local eqPill = UIKit.pill(card, { Text = "EQUIPPED", Color = GREEN, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(98, 26), ZIndex = 14 })
	label({ Parent = card, Position = UDim2.fromOffset(10, 134), Size = UDim2.new(1, -20, 0, 30), Text = def.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	-- stat bars
	label({ Parent = card, Position = UDim2.fromOffset(14, 168), Size = UDim2.fromOffset(60, 18), TextXAlignment = Enum.TextXAlignment.Left, Text = "🔥 Speed", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
	local _, setSpeed = UIKit.bar(card, { Position = UDim2.fromOffset(78, 169), Size = UDim2.new(1, -92, 0, 16), Color = ORANGE, ShowText = true, ZIndex = 12 })
	label({ Parent = card, Position = UDim2.fromOffset(14, 192), Size = UDim2.fromOffset(60, 18), TextXAlignment = Enum.TextXAlignment.Left, Text = "⛽ Fuel", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
	local _, setFuel = UIKit.bar(card, { Position = UDim2.fromOffset(78, 193), Size = UDim2.new(1, -92, 0, 16), Color = Color3.fromRGB(90, 200, 255), ShowText = true, ZIndex = 12 })
	setSpeed(def.speed / MAX_SPEED, tostring(def.speed))
	setFuel(def.fuel / MAX_FUEL, def.fuel .. "s")
	local range = label({ Parent = card, Position = UDim2.fromOffset(10, 214), Size = UDim2.new(1, -20, 0, 22), Text = "", TextColor3 = Color3.fromRGB(40, 160, 70), StrokeThickness = 0, ZIndex = 12 })
	local button = UIKit.button({ Parent = card, Text = "", Color = GREEN, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 52), ZIndex = 12 })
	button.Instance.Activated:Connect(function()
		local ok, msg = BuyRocket:InvokeServer(def.id)
		bought(card, ok, msg)
	end)
	rocketCards[def.id] = { def = def, card = card, range = range, button = button, eq = eqPill, stroke = card:FindFirstChildOfClass("UIStroke") }
end

for i, def in ipairs(Config.Trails) do
	local card = UIKit.card(trailGrid, { LayoutOrder = i, ZIndex = 11 })
	local swatch = make("Frame", { Parent = card, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 84), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(18), UIKit.stroke(3) })
	local keys = {}
	for k, c in ipairs(def.colors) do
		table.insert(keys, ColorSequenceKeypoint.new(#def.colors == 1 and 0 or (k - 1) / (#def.colors - 1), c))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, def.colors[1]))
	end
	make("UIGradient", { Parent = swatch, Color = ColorSequence.new(keys) })
	-- streak shapes so it reads as a trail
	for s = 1, 3 do
		make("Frame", { Parent = swatch, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, Position = UDim2.new(0.1 + s * 0.12, 0, 0.2 + s * 0.18, 0), Size = UDim2.new(0.5, 0, 0, 6), ZIndex = 13 }, { UIKit.corner(4) })
	end
	if def.id == "None" then
		swatch.BackgroundColor3 = Color3.fromRGB(230, 230, 240)
		label({ Parent = swatch, Size = UDim2.fromScale(1, 1), Text = "no trail", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 14 })
	end
	label({ Parent = card, Position = UDim2.fromOffset(10, 100), Size = UDim2.new(1, -20, 0, 30), Text = def.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local eqPill = UIKit.pill(card, { Text = "EQUIPPED", Color = GREEN, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.fromOffset(98, 26), ZIndex = 14 })
	local button = UIKit.button({ Parent = card, Text = "", Color = GREEN, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 52), ZIndex = 12 })
	button.Instance.Activated:Connect(function()
		local ok, msg = BuyTrail:InvokeServer(def.id)
		bought(card, ok, msg)
	end)
	trailCards[def.id] = { def = def, button = button, eq = eqPill, stroke = card:FindFirstChildOfClass("UIStroke") }
end

-- rocket meshes may still be downloading when the previews are built: re-add them once loaded
task.spawn(function()
	local folder = ReplicatedStorage:FindFirstChild("RocketModels")
	if folder then
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(folder:GetChildren())
		end)
	end
	for _, vp in ipairs(previews) do
		local m = vp:FindFirstChildOfClass("Model")
		if m then
			m.Parent = nil
			m.Parent = vp
		end
	end
end)

local function showTab(trails)
	rocketGrid.Visible = not trails
	trailGrid.Visible = trails
	rocketsTab.setColor(trails and GREY or BLUE)
	trailsTab.setColor(trails and PINK or GREY)
	rocketsList.CanvasPosition = Vector2.zero
end
rocketsTab.Instance.Activated:Connect(function()
	showTab(false)
end)
trailsTab.Instance.Activated:Connect(function()
	showTab(true)
end)

local function setBuyButton(info, isEquipped, isOwned, price)
	info.eq.Visible = isEquipped
	if info.stroke then
		info.stroke.Color = isEquipped and GREEN or Color3.fromRGB(190, 200, 225)
		info.stroke.Thickness = isEquipped and 4 or 3
	end
	local button = info.button
	if isEquipped then
		button.setText("✔ EQUIPPED")
		button.setColor(GREY)
	elseif isOwned then
		button.setText("EQUIP")
		button.setColor(BLUE)
	else
		button.setText("💰 $" .. abbreviate(price))
		button.setColor((player:GetAttribute("Money") or 0) >= price and GREEN or RED)
	end
end

local function refreshRockets()
	local mine = owned("OwnedRockets")
	local equipped = player:GetAttribute("Rocket")
	for id, info in pairs(rocketCards) do
		info.range.Text = "Range ~" .. meters(rangeOf(info.def))
		setBuyButton(info, id == equipped, table.find(mine, id) ~= nil, info.def.price)
	end
	local mineT = owned("OwnedTrails")
	local trail = player:GetAttribute("Trail")
	for id, info in pairs(trailCards) do
		setBuyButton(info, id == trail, table.find(mineT, id) ~= nil or id == "None", info.def.price)
	end
end

-- Upgrades window ------------------------------------------------------------------------
local upgradesWindow, upgradesList = UIKit.window("Upgrades", PURPLE, UDim2.fromOffset(720, 520), "Upgrade")
local summary = UIKit.row(upgradesList, 0, 64)
local summaryText = label({ Parent = summary, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 1, -20), Text = "", TextColor3 = Color3.fromRGB(230, 130, 20), StrokeThickness = 0, ZIndex = 12 })

local UPGRADE_LOOK = {
	Cannon = { icon = nil, color = Color3.fromRGB(90, 150, 255), what = "Blast out of the cannon" },
	Fuel = { icon = "FuelCan", color = Color3.fromRGB(255, 170, 40), what = "Fly for longer", word = "fuel" },
	Speed = { icon = "Bolt", color = Color3.fromRGB(255, 90, 70), what = "Fly faster", word = "speed" },
	Money = { icon = "MoneyBag", color = GREEN, what = "Earn more money", word = "money" },
}
local upgradeCards = {}
local function pct(x)
	return math.floor(x * 100 + 0.5)
end
local function cannonIcon(level)
	local tier = Config.cannonTierInfo(level)
	local skins = ReplicatedStorage:FindFirstChild("CannonSkins")
	return skins and skins:FindFirstChild(tier.skin)
end

for i, key in ipairs({ "Cannon", "Fuel", "Speed", "Money" }) do
	local u = Config.Upgrades[key]
	local look = UPGRADE_LOOK[key]
	local card = UIKit.card(upgradesList, { LayoutOrder = i, Size = UDim2.new(1, -12, 0, 132), ZIndex = 11, Tint = UIKit.lighter(look.color, 0.8) })
	local iconBox = make("Frame", { Parent = card, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(108, 108), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(24), UIKit.stroke(3.5), UIKit.gloss(look.color) })
	make("Frame", { Parent = iconBox, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, Position = UDim2.new(0.1, 0, 0.07, 0), Size = UDim2.new(0.8, 0, 0.28, 0), ZIndex = 12 }, { UIKit.corner(14) })
	local iconHolder = make("Frame", { Parent = iconBox, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 13 })
	if look.icon then
		UIKit.icon3D(iconHolder, look.icon, { ZIndex = 13 })
	end
	label({ Parent = card, Position = UDim2.fromOffset(134, 12), Size = UDim2.new(1, -330, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, Text = u.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local levelPill, levelText = UIKit.pill(card, { Text = "", Color = look.color, Position = UDim2.new(1, -306, 0, 16), Size = UDim2.fromOffset(110, 28), ZIndex = 12 })
	local what = label({ Parent = card, Position = UDim2.fromOffset(134, 48), Size = UDim2.new(1, -330, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Text = look.what, TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
	local _, setLevel = UIKit.bar(card, { Position = UDim2.fromOffset(134, 80), Size = UDim2.new(1, -320, 0, 18), Color = look.color, ZIndex = 12 })
	local change = label({ Parent = card, Position = UDim2.fromOffset(134, 102), Size = UDim2.new(1, -320, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = Color3.fromRGB(40, 160, 70), StrokeThickness = 0, ZIndex = 12 })
	local button = UIKit.button({ Parent = card, Text = "", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(170, 74), ZIndex = 12 })
	button.Instance.Activated:Connect(function()
		local ok, msg = BuyUpgrade:InvokeServer(key)
		-- the chime climbs a little with every level
		bought(card, ok, msg, 1 + math.min(30, player:GetAttribute(key .. "Level") or 0) * 0.02)
		if ok then
			-- the gain floats up from the top of the button
			local b = button.Instance
			UIKit.floatText(key == "Cannon" and "BLAST UP!" or "+" .. pct(u.perLevel) .. "% " .. look.word, look.color, b.AbsolutePosition + Vector2.new(b.AbsoluteSize.X / 2, 0))
		end
	end)
	-- gold tag on the card's top edge (right of the icon) for the upgrade to buy next
	local best = UIKit.pill(card, { Name = "BestPick", Text = "⭐ BEST PICK", Color = GOLD, Position = UDim2.fromOffset(134, -12), Size = UDim2.fromOffset(128, 24), ZIndex = 14 })
	best.Visible = false
	upgradeCards[key] = { card = card, best = best, button = button, setLevel = setLevel, levelText = levelText, change = change, what = what, iconHolder = iconHolder, cannonSkin = nil }
end

local function refreshUpgrades()
	local money = player:GetAttribute("Money") or 0
	local def = Config.getRocket(player:GetAttribute("Rocket"))
	summaryText.Text = "🚀 " .. def.name .. " flies about " .. meters(rangeOf(def)) .. " (before the cannon blast)"
	local pick = Config.bestUpgrade(player)
	for key, r in pairs(upgradeCards) do
		local u = Config.Upgrades[key]
		local level = player:GetAttribute(key .. "Level") or 0
		r.best.Visible = key == pick
		r.levelText.Text = "Lv " .. level .. "/" .. u.maxLevel
		-- a level up: the bar springs to its new width and the "Lv" text pops
		local up = r.lastLevel ~= nil and level > r.lastLevel
		r.setLevel(level / u.maxLevel, nil, up)
		if up then
			UIKit.bounce(r.levelText)
		end
		r.lastLevel = level
		local maxed = level >= u.maxLevel
		if key == "Cannon" then
			local power, time = Config.cannonBlast(level)
			local np, nt = Config.cannonBlast(level + 1)
			local tier, nextTier = Config.cannonTierInfo(level)
			r.what.Text = tier.name .. (nextTier and ("  •  new look at Lv " .. nextTier.from) or "  •  final look!")
			r.change.Text = maxed and string.format("Blast x%.1f for %.1fs", power, time) or string.format("Blast x%.1f → x%.1f   (%.1fs → %.1fs)", power, np, time, nt)
			if r.cannonSkin ~= tier.skin then
				r.cannonSkin = tier.skin
				r.iconHolder:ClearAllChildren()
				local skin = cannonIcon(level)
				if skin then
					UIKit.icon3D(r.iconHolder, skin, { ZIndex = 13, Yaw = -60, Zoom = 1.3 })
				end
			end
		else
			local now, nextV = pct(level * u.perLevel), pct((level + 1) * u.perLevel)
			local word = UPGRADE_LOOK[key].word
			r.change.Text = maxed and string.format("+%d%% %s", now, word) or string.format("+%d%% → +%d%% %s", now, nextV, word)
		end
		if maxed then
			r.button.setText("MAX ⭐")
			r.button.setColor(GREY)
		else
			local cost = Config.upgradeCost(key, level)
			r.button.setText("⬆ $" .. abbreviate(cost))
			r.button.setColor(money >= cost and GREEN or RED)
		end
	end
end

for _, attr in ipairs({ "Money", "Rocket", "OwnedRockets", "Trail", "OwnedTrails", "FuelLevel", "SpeedLevel", "MoneyLevel", "CannonLevel", "BestDistance", "UnlockedStage" }) do
	-- only redraw an open window; a closed one refreshes when it opens
	player:GetAttributeChangedSignal(attr):Connect(function()
		if rocketsWindow.Visible then
			refreshRockets()
		end
		if upgradesWindow.Visible then
			refreshUpgrades()
		end
	end)
end
-- every way of opening a window (shop prompt, HUD button, Flight Report) refreshes it here
for w, refresh in pairs({ [rocketsWindow] = refreshRockets, [upgradesWindow] = refreshUpgrades }) do
	w:GetPropertyChangedSignal("Visible"):Connect(function()
		if w.Visible then
			refresh()
		end
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
		UIKit.close(rocketsWindow)
		UIKit.close(upgradesWindow)
		openedAt = nil
	end
end)

-- HUD shortcuts: UPGRADE and ROCKETS next to LAUNCH open the same windows as the shops (no walk
-- needed between flights), with a red "!" when you can afford something there.
local bottom = UIKit.bottomBar()
-- a chunky 3D up-arrow for the UPGRADE button (shaft + two wedges for the head), facing -Z
local upgradeHud = UIKit.button({ Parent = bottom, LayoutOrder = 3, Icon3D = "Upgrade", Icon = "⬆", Text = "UPGRADE", Color = PURPLE, Size = UDim2.fromOffset(104, 104), Radius = 24 })
local rocketsHud = UIKit.button({ Parent = bottom, LayoutOrder = 4, Icon3D = "Rockets", Icon = "🚀", Text = "ROCKETS", Color = BLUE, Size = UDim2.fromOffset(104, 104), Radius = 24 })
local upgradeBadge = UIKit.badge(upgradeHud.Instance)
local rocketsBadge = UIKit.badge(rocketsHud.Instance)
upgradeHud.Instance.Activated:Connect(function()
	openedAt = nil
	UIKit.toggle(upgradesWindow)
end)
rocketsHud.Instance.Activated:Connect(function()
	openedAt = nil
	UIKit.toggle(rocketsWindow)
end)

local function refreshBadges()
	local money = player:GetAttribute("Money") or 0
	local canUpgrade = false
	-- stuck at the gate: only Money Boost still helps, so only it earns the "!"
	local capped = Config.isCapped(player)
	for key, u in pairs(Config.Upgrades) do
		local lvl = player:GetAttribute(key .. "Level") or 0
		if (not capped or key == "Money") and lvl < u.maxLevel and money >= Config.upgradeCost(key, lvl) then
			canUpgrade = true
		end
	end
	local mine = owned("OwnedRockets")
	local canRocket = false
	for _, def in ipairs(Config.Rockets) do
		if not table.find(mine, def.id) and money >= def.price then
			canRocket = true
		end
	end
	if canUpgrade and not upgradeBadge.Visible then
		UIKit.bounce(upgradeBadge)
	end
	if canRocket and not rocketsBadge.Visible then
		UIKit.bounce(rocketsBadge)
	end
	upgradeBadge.Visible = canUpgrade
	rocketsBadge.Visible = canRocket
end
for _, attr in ipairs({ "Money", "OwnedRockets", "FuelLevel", "SpeedLevel", "MoneyLevel", "CannonLevel", "BestDistance", "UnlockedStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(refreshBadges)
end
refreshBadges()
