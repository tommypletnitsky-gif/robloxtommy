-- Client: HUD, launching, steering the rocket (W/S = up/down, A/D = left/right), camera, zone lighting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local LaunchRemote = remotes:WaitForChild("Launch")
local FlightEvent = remotes:WaitForChild("Flight")
local UnlockStage = remotes:WaitForChild("UnlockStage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

local FONT = Enum.Font.FredokaOne
local abbreviate = Config.abbreviate

-- UI helpers ----------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "RocketHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function make(className, props, children)
	local o = Instance.new(className)
	for k, v in pairs(props) do
		o[k] = v
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	return o
end

local function corner(r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

local function stroke(t, c)
	return make("UIStroke", { Thickness = t or 2, Color = c or Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

local function label(props)
	local base = { BackgroundTransparency = 1, Font = FONT, TextColor3 = Color3.new(1, 1, 1), TextScaled = true }
	for k, v in pairs(props) do
		base[k] = v
	end
	return make("TextLabel", base, { stroke(2) })
end

-- Left: money + best ----------------------------------------------------------------------
local statsFrame = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.42, 0),
	Size = UDim2.fromOffset(210, 96),
	BackgroundColor3 = Color3.fromRGB(25, 25, 40),
	BackgroundTransparency = 0.25,
}, { corner(14), stroke(3, Color3.fromRGB(255, 200, 60)) })
local moneyLabel = label({ Parent = statsFrame, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 44), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 255, 120), Text = "$0" })
local bestLabel = label({ Parent = statsFrame, Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Text = "Best: 0m" })

-- Right: stage progress + unlock ----------------------------------------------------------
local stageFrame = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.42, 0),
	Size = UDim2.fromOffset(250, 170),
	BackgroundColor3 = Color3.fromRGB(25, 25, 40),
	BackgroundTransparency = 0.25,
}, { corner(14), stroke(3, Color3.fromRGB(120, 200, 255)) })
local stageTitle = label({ Parent = stageFrame, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 30), Text = "Stage 1" })
local stageName = label({ Parent = stageFrame, Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 22), TextColor3 = Color3.fromRGB(200, 220, 255), Text = "" })
local barBack = make("Frame", { Parent = stageFrame, Position = UDim2.fromOffset(14, 70), Size = UDim2.new(1, -28, 0, 18), BackgroundColor3 = Color3.fromRGB(50, 50, 70) }, { corner(9) })
local barFill = make("Frame", { Parent = barBack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(120, 200, 255) }, { corner(9) })
local barText = label({ Parent = barBack, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2 })
local unlockButton = make("TextButton", {
	Parent = stageFrame,
	Position = UDim2.fromOffset(14, 100),
	Size = UDim2.new(1, -28, 0, 56),
	BackgroundColor3 = Color3.fromRGB(80, 200, 90),
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "UNLOCK",
	AutoButtonColor = true,
}, { corner(12), stroke(2), make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })

-- Bottom: launch button -------------------------------------------------------------------
-- Chunky icon buttons along the bottom, LAUNCH in the middle.
local bottomBar = make("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(620, 104), BackgroundTransparency = 1 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function iconButton(order, icon, text, color)
	local b = make("TextButton", { Parent = bottomBar, LayoutOrder = order, Size = UDim2.fromOffset(92, 96), BackgroundColor3 = color, Text = "", AutoButtonColor = true }, { corner(18), stroke(3) })
	label({ Parent = b, Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 58), Text = icon })
	label({ Parent = b, Position = UDim2.new(0, 4, 1, -30), Size = UDim2.new(1, -8, 0, 24), Text = text })
	local scale = make("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	return b
end

local rocketsButton = iconButton(1, "🚀", "ROCKETS", Color3.fromRGB(70, 140, 255))
local launchButton = make("TextButton", {
	Parent = bottomBar,
	LayoutOrder = 2,
	Size = UDim2.fromOffset(220, 84),
	BackgroundColor3 = Color3.fromRGB(255, 130, 30),
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "LAUNCH!",
}, { corner(20), stroke(3), make("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }) })
local upgradesButton = iconButton(3, "⬆️", "UPGRADES", Color3.fromRGB(160, 80, 230))
local eggsButton = iconButton(4, "🥚", "EGGS", Color3.fromRGB(80, 190, 110))

-- Top: flight HUD ---------------------------------------------------------------------------
local flightFrame = make("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(360, 130), BackgroundTransparency = 1, Visible = false })
local distanceLabel = label({ Parent = flightFrame, Size = UDim2.new(1, 0, 0, 60), Text = "0m" })
local flightStageLabel = label({ Parent = flightFrame, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 26), TextColor3 = Color3.fromRGB(200, 220, 255), Text = "" })
local fuelBack = make("Frame", { Parent = flightFrame, Position = UDim2.fromOffset(30, 94), Size = UDim2.new(1, -60, 0, 22), BackgroundColor3 = Color3.fromRGB(40, 40, 55) }, { corner(11), stroke(2) })
local fuelFill = make("Frame", { Parent = fuelBack, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 170, 40) }, { corner(11) })
label({ Parent = fuelBack, Size = UDim2.fromScale(1, 1), Text = "FUEL", ZIndex = 2 })
local helpLabel = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(520, 28), Text = "W / S = up / down     A / D = left / right", Visible = false })

-- Steering input: keyboard, gamepad stick, or the on-screen arrows (phones/tablets).
local touchHeld = { up = false, down = false, left = false, right = false }
local arrowPad = make("Frame", { Parent = gui, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(210, 210), BackgroundTransparency = 1, Visible = false })
for dir, spec in pairs({ up = { 70, 0, "^" }, down = { 70, 140, "v" }, left = { 0, 70, "<" }, right = { 140, 70, ">" } }) do
	local b = make("TextButton", {
		Parent = arrowPad,
		Position = UDim2.fromOffset(spec[1], spec[2]),
		Size = UDim2.fromOffset(70, 70),
		BackgroundColor3 = Color3.fromRGB(30, 30, 45),
		BackgroundTransparency = 0.3,
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = spec[3],
	}, { corner(35), stroke(2) })
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			touchHeld[dir] = true
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			touchHeld[dir] = false
		end
	end)
end

local function keyDown(...)
	for _, k in ipairs({ ... }) do
		if UserInputService:IsKeyDown(k) then
			return true
		end
	end
	return false
end

-- Returns (side, up): side -1 = left, +1 = right; up +1 = climb, -1 = dive.
local function getSteer()
	if UserInputService:GetFocusedTextBox() then
		return 0, 0
	end
	local K = Enum.KeyCode
	local side = (keyDown(K.D, K.Right) and 1 or 0) - (keyDown(K.A, K.Left) and 1 or 0)
	local up = (keyDown(K.W, K.Up, K.Space) and 1 or 0) - (keyDown(K.S, K.Down, K.LeftShift) and 1 or 0)
	side += (touchHeld.right and 1 or 0) - (touchHeld.left and 1 or 0)
	up += (touchHeld.up and 1 or 0) - (touchHeld.down and 1 or 0)
	for _, input in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
		if input.KeyCode == K.Thumbstick1 and input.Position.Magnitude > 0.2 then
			side += input.Position.X
			up += input.Position.Y
		end
	end
	return math.clamp(side, -1, 1), math.clamp(up, -1, 1)
end

-- Center: countdown, banners, results -----------------------------------------------------
local bigLabel = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(500, 120), Text = "", Visible = false })
local resultFrame = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(380, 190),
	BackgroundColor3 = Color3.fromRGB(25, 25, 40),
	BackgroundTransparency = 0.1,
	Visible = false,
}, { corner(18), stroke(4, Color3.fromRGB(255, 200, 60)) })
local resultTitle = label({ Parent = resultFrame, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 44), Text = "" })
local resultDistance = label({ Parent = resultFrame, Position = UDim2.fromOffset(16, 62), Size = UDim2.new(1, -32, 0, 40), Text = "" })
local resultMoney = label({ Parent = resultFrame, Position = UDim2.fromOffset(16, 106), Size = UDim2.new(1, -32, 0, 40), TextColor3 = Color3.fromRGB(120, 255, 120), Text = "" })
local resultHint = label({ Parent = resultFrame, Position = UDim2.fromOffset(16, 152), Size = UDim2.new(1, -32, 0, 24), TextColor3 = Color3.fromRGB(255, 220, 150), Text = "" })

local toast = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 200), Size = UDim2.fromOffset(600, 40), Text = "", Visible = false })
local toastToken = 0
local function showToast(text, color)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	toast.Visible = true
	task.delay(3, function()
		if toastToken == my then
			toast.Visible = false
		end
	end)
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(showToast)

-- Stats / stage panel -----------------------------------------------------------------------
local function refreshGates()
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	local unlocked = player:GetAttribute("UnlockedStage") or 1
	for _, gate in ipairs(world:GetDescendants()) do
		if gate:IsA("Model") and gate.Name == "Gate" then
			local open = (gate:GetAttribute("Stage") or 99) <= unlocked
			local barrier = gate:FindFirstChild("Barrier")
			if barrier then
				barrier.Transparency = open and 1 or 0.55
				local surface = barrier:FindFirstChildOfClass("SurfaceGui")
				if surface then
					surface.Enabled = not open
				end
			end
		end
	end
end

local function refreshStats()
	local money = player:GetAttribute("Money") or 0
	local best = player:GetAttribute("BestDistance") or 0
	local unlocked = player:GetAttribute("UnlockedStage") or 1
	moneyLabel.Text = "$" .. abbreviate(money)
	bestLabel.Text = "Best: " .. Config.meters(best)

	stageTitle.Text = "Stage " .. unlocked .. " / " .. Config.NUM_STAGES
	stageName.Text = Config.Stages[unlocked].name
	if unlocked >= Config.NUM_STAGES then
		barFill.Size = UDim2.fromScale(1, 1)
		barText.Text = "ALL STAGES OPEN!"
		unlockButton.Visible = false
		return
	end
	local goal = Config.stageEndX(unlocked) - Config.LAUNCH_X
	local stageStart = goal - Config.STAGE_LENGTH
	local progress = math.clamp((best - stageStart) / Config.STAGE_LENGTH, 0, 1)
	barFill.Size = UDim2.fromScale(progress, 1)
	barText.Text = Config.meters(math.min(best, goal)) .. " / " .. Config.meters(goal)
	unlockButton.Visible = true
	local cost = Config.stageCost(unlocked + 1)
	if best < goal - 5 then
		unlockButton.Text = "Reach " .. Config.meters(goal) .. " to unlock Stage " .. (unlocked + 1)
		unlockButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	elseif money < cost then
		unlockButton.Text = "Unlock Stage " .. (unlocked + 1) .. ": $" .. abbreviate(cost)
		unlockButton.BackgroundColor3 = Color3.fromRGB(150, 110, 60)
	else
		unlockButton.Text = "UNLOCK Stage " .. (unlocked + 1) .. ": $" .. abbreviate(cost)
		unlockButton.BackgroundColor3 = Color3.fromRGB(80, 200, 90)
	end
end

for _, attr in ipairs({ "Money", "BestDistance", "UnlockedStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(refreshStats)
end
player:GetAttributeChangedSignal("UnlockedStage"):Connect(refreshGates)
task.spawn(function()
	repeat
		task.wait(0.2)
	until player:GetAttribute("UnlockedStage")
	refreshStats()
	refreshGates()
end)

unlockButton.Activated:Connect(function()
	local ok, msg = UnlockStage:InvokeServer()
	showToast(msg, ok and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 140, 140))
end)

-- Shop windows ------------------------------------------------------------------------------
local RocketModel = require(ReplicatedStorage.Shared.RocketModel)
local BuyRocket = remotes:WaitForChild("BuyRocket")
local BuyUpgrade = remotes:WaitForChild("BuyUpgrade")

local windows = {}
local function makeWindow(title, accent)
	local w = make("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(560, 430),
		BackgroundColor3 = Color3.fromRGB(28, 28, 44),
		Visible = false,
	}, { corner(20), stroke(4, accent), make("UISizeConstraint", { MaxSize = Vector2.new(560, 430) }) })
	local header = make("Frame", { Parent = w, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = accent }, { corner(20) })
	label({ Parent = header, Position = UDim2.fromOffset(20, 8), Size = UDim2.new(1, -90, 1, -16), TextXAlignment = Enum.TextXAlignment.Left, Text = title })
	local close = make("TextButton", { Parent = header, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = Color3.fromRGB(230, 70, 70), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "X" }, { corner(12), stroke(2) })
	close.Activated:Connect(function()
		w.Visible = false
	end)
	local list = make("ScrollingFrame", {
		Parent = w,
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(1, -28, 1, -80),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, { make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	table.insert(windows, w)
	return w, list
end

local function toggleWindow(w)
	local open = not w.Visible
	for _, other in ipairs(windows) do
		other.Visible = false
	end
	w.Visible = open
	if open then
		local s = w:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = w })
		s.Scale = 0.85
		TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

local function row(list, order, height)
	return make("Frame", { Parent = list, LayoutOrder = order, Size = UDim2.new(1, -10, 0, height), BackgroundColor3 = Color3.fromRGB(44, 44, 66) }, { corner(14) })
end

local function actionButton(parent)
	return make("TextButton", {
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(130, 52),
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
	}, { corner(12), stroke(2), make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })
end

local function result(ok, msg)
	showToast(msg, ok and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 140, 140))
end

local function upgradeMult(key)
	return 1 + (player:GetAttribute(key .. "Level") or 0) * Config.Upgrades[key].perLevel
end

local function rangeOf(def)
	return def.speed * upgradeMult("Speed") * def.fuel * upgradeMult("Fuel")
end

-- Rockets window: a 3D preview of each rocket, its stats, and Buy / Equip.
local rocketsWindow, rocketsList = makeWindow("🚀 Rockets", Color3.fromRGB(70, 140, 255))
local rocketRows = {}
for i, def in ipairs(Config.Rockets) do
	local r = row(rocketsList, i, 96)
	local vp = make("ViewportFrame", { Parent = r, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(80, 80), BackgroundColor3 = Color3.fromRGB(30, 30, 48), Ambient = Color3.fromRGB(180, 180, 190), LightColor = Color3.new(1, 1, 1) }, { corner(12) })
	local model = RocketModel.build(def, 1, false, CFrame.Angles(0, 0, math.rad(35)))
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.lookAt(Vector3.new(4, 3, 13), Vector3.new(0.5, 0, 0))
	cam.FieldOfView = 45
	cam.Parent = vp
	vp.CurrentCamera = cam
	label({ Parent = r, Position = UDim2.fromOffset(100, 12), Size = UDim2.new(1, -250, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, Text = def.name })
	local stats = label({ Parent = r, Position = UDim2.fromOffset(100, 50), Size = UDim2.new(1, -250, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 200, 230), Text = "" })
	local button = actionButton(r)
	button.Activated:Connect(function()
		result(BuyRocket:InvokeServer(def.id))
	end)
	rocketRows[def.id] = { stats = stats, button = button, def = def }
end

local function refreshRockets()
	local owned = string.split(player:GetAttribute("OwnedRockets") or "Starter", ",")
	local equipped = player:GetAttribute("Rocket")
	local money = player:GetAttribute("Money") or 0
	for id, info in pairs(rocketRows) do
		local def = info.def
		info.stats.Text = string.format("Speed %d  |  Fuel %ss  |  ~%s", def.speed, tostring(def.fuel), Config.meters(rangeOf(def)))
		if id == equipped then
			info.button.Text = "EQUIPPED"
			info.button.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
		elseif table.find(owned, id) then
			info.button.Text = "EQUIP"
			info.button.BackgroundColor3 = Color3.fromRGB(70, 140, 255)
		else
			info.button.Text = "$" .. abbreviate(def.price)
			info.button.BackgroundColor3 = money >= def.price and Color3.fromRGB(80, 200, 90) or Color3.fromRGB(150, 70, 70)
		end
	end
end

-- Upgrades window: Fuel Tank / Engine / Money Boost.
local upgradesWindow, upgradesList = makeWindow("⬆️ Upgrades", Color3.fromRGB(160, 80, 230))
local rangeRow = row(upgradesList, 0, 50)
local rangeLabel = label({ Parent = rangeRow, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), TextColor3 = Color3.fromRGB(255, 220, 90), Text = "" })
local upgradeRows = {}
for i, key in ipairs({ "Fuel", "Speed", "Money" }) do
	local u = Config.Upgrades[key]
	local r = row(upgradesList, i, 96)
	label({ Parent = r, Position = UDim2.fromOffset(10, 18), Size = UDim2.fromOffset(60, 60), Text = ({ Fuel = "⛽", Speed = "🔥", Money = "💰" })[key] })
	label({ Parent = r, Position = UDim2.fromOffset(80, 12), Size = UDim2.new(1, -230, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, Text = u.name })
	local info = label({ Parent = r, Position = UDim2.fromOffset(80, 50), Size = UDim2.new(1, -230, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 200, 230), Text = "" })
	local button = actionButton(r)
	button.Activated:Connect(function()
		result(BuyUpgrade:InvokeServer(key))
	end)
	upgradeRows[key] = { info = info, button = button }
end

local function refreshUpgrades()
	local money = player:GetAttribute("Money") or 0
	local def = Config.getRocket(player:GetAttribute("Rocket"))
	rangeLabel.Text = def.name .. " range: ~" .. Config.meters(rangeOf(def))
	for key, r in pairs(upgradeRows) do
		local u = Config.Upgrades[key]
		local level = player:GetAttribute(key .. "Level") or 0
		local what = ({ Fuel = "fuel", Speed = "speed", Money = "money" })[key]
		r.info.Text = string.format("Lv %d/%d  |  +%d%% %s", level, u.maxLevel, math.floor(level * u.perLevel * 100 + 0.5), what)
		if level >= u.maxLevel then
			r.button.Text = "MAX"
			r.button.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
		else
			local cost = Config.upgradeCost(key, level)
			r.button.Text = "$" .. abbreviate(cost)
			r.button.BackgroundColor3 = money >= cost and Color3.fromRGB(80, 200, 90) or Color3.fromRGB(150, 70, 70)
		end
	end
end

for _, attr in ipairs({ "Money", "Rocket", "OwnedRockets", "FuelLevel", "SpeedLevel", "MoneyLevel" }) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		refreshRockets()
		refreshUpgrades()
	end)
end
refreshRockets()
refreshUpgrades()

rocketsButton.Activated:Connect(function()
	toggleWindow(rocketsWindow)
end)
upgradesButton.Activated:Connect(function()
	toggleWindow(upgradesWindow)
end)
eggsButton.Activated:Connect(function()
	showToast("🥚 Eggs are coming soon!", Color3.fromRGB(255, 230, 120))
end)

-- Launching ---------------------------------------------------------------------------------
local function requestLaunch()
	if player:GetAttribute("Flying") then
		return
	end
	resultFrame.Visible = false
	for _, w in ipairs(windows) do
		w.Visible = false
	end
	LaunchRemote:FireServer()
end
launchButton.Activated:Connect(requestLaunch)

local function hookTool(tool)
	if tool:IsA("Tool") and tool.Name == "Rocket" and not tool:GetAttribute("Hooked") then
		tool:SetAttribute("Hooked", true)
		tool.Activated:Connect(requestLaunch)
	end
end
player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(hookTool)
end)
if player.Character then
	player.Character.ChildAdded:Connect(hookTool)
end

player:GetAttributeChangedSignal("Flying"):Connect(function()
	local flying = player:GetAttribute("Flying")
	bottomBar.Visible = not flying
	statsFrame.Visible = not flying
	stageFrame.Visible = not flying
end)

-- Flight ------------------------------------------------------------------------------------
local flight = nil -- { body, thrust, aim, speed, fuel, startX, launchedAt, offY, offZ, outOfFuel, stage }

local function noJump()
	return Enum.ContextActionResult.Sink
end

local function setJumpBlocked(blocked)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if blocked then
		ContextActionService:BindActionAtPriority("RocketNoJump", noJump, false, 3000, Enum.PlayerActions.CharacterJump)
	else
		ContextActionService:UnbindAction("RocketNoJump")
	end
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, not blocked)
	end
end

local function stopFlight()
	flight = nil
	flightFrame.Visible = false
	helpLabel.Visible = false
	arrowPad.Visible = false
	setJumpBlocked(false)
	camera.CameraType = Enum.CameraType.Custom
end

FlightEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "countdown" then
		setJumpBlocked(true)
		resultFrame.Visible = false
		bigLabel.Visible = true
		for i = info.seconds, 1, -1 do
			bigLabel.Text = tostring(i)
			bigLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
			task.wait(1)
		end
		bigLabel.Text = "GO!"
		task.delay(0.8, function()
			bigLabel.Visible = false
		end)
	elseif kind == "start" then
		local body = info.rocket and info.rocket.PrimaryPart
		if not body then
			return
		end
		flight = {
			body = body,
			thrust = body:WaitForChild("Thrust"),
			aim = body:WaitForChild("Aim"),
			speed = info.speed,
			fuel = info.fuel,
			startX = info.startX,
			launchedAt = os.clock(),
			offY = 10,
			offZ = 0,
			stage = 0,
		}
		flightFrame.Visible = true
		helpLabel.Visible = not UserInputService.TouchEnabled
		arrowPad.Visible = UserInputService.TouchEnabled
		camera.CameraType = Enum.CameraType.Scriptable
	elseif kind == "outOfFuel" then
		if flight then
			flight.outOfFuel = os.clock()
		end
	elseif kind == "result" then
		stopFlight()
		resultTitle.Text = info.newBest and "NEW BEST!" or "Flight over!"
		resultTitle.TextColor3 = info.newBest and Color3.fromRGB(255, 220, 60) or Color3.new(1, 1, 1)
		resultDistance.Text = "You flew " .. Config.meters(info.distance)
		resultMoney.Text = "+$" .. abbreviate(info.money)
		resultHint.Text = ({
			fuel = "Out of fuel! Upgrade your rocket to go farther.",
			gate = "Stage locked! Unlock the next stage to keep going.",
			jumped = "You fell off your rocket!",
			finish = "You reached the end of the galaxy!",
		})[info.reason] or ""
		resultFrame.Visible = true
		task.delay(4, function()
			if not flight then
				resultFrame.Visible = false
			end
		end)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not flight then
		return
	end
	local f = flight
	if not f.body.Parent then
		stopFlight()
		return
	end
	local pos = f.body.Position
	local side, up = getSteer()
	local steer = Config.STEER_SPEED * dt
	f.offY = math.clamp(f.offY + up * steer, Config.FLY_MIN_HEIGHT, Config.FLY_MAX_HEIGHT)
	f.offZ = math.clamp(f.offZ + side * steer, -Config.PATH_HALF_WIDTH, Config.PATH_HALF_WIDTH)

	local vel
	if f.outOfFuel then
		local t = os.clock() - f.outOfFuel
		local fall = pos.Y > Config.pathY(pos.X) + 2.5 and (-18 - t * 20) or 0 -- land on the path, don't sink through it
		vel = Vector3.new(f.speed * math.max(0.15, 0.6 - t * 0.3), fall, 0)
	else
		local slope = Config.pathY(pos.X + 1) - Config.pathY(pos.X)
		local targetY = Config.pathY(pos.X) + f.offY
		vel = Vector3.new(f.speed, slope * f.speed + (targetY - pos.Y) * 4, (f.offZ - pos.Z) * 4)
	end
	f.thrust.VectorVelocity = vel
	f.aim.CFrame = CFrame.lookAt(Vector3.zero, vel.Unit) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(side * 0.5, 0, 0)

	-- Camera: behind and a little above the rocket.
	local camPos = pos + Vector3.new(-26, 9, 0)
	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camPos, pos + Vector3.new(20, 2, 0)), math.min(1, dt * 8))

	-- HUD
	local dist = math.max(0, pos.X - f.startX)
	distanceLabel.Text = Config.meters(dist)
	local fuelLeft = f.outOfFuel and 0 or math.clamp(1 - (os.clock() - f.launchedAt) / f.fuel, 0, 1)
	fuelFill.Size = UDim2.fromScale(fuelLeft, 1)
	local stage = Config.stageAt(pos.X)
	if stage ~= f.stage then
		f.stage = stage
		flightStageLabel.Text = "Stage " .. stage .. " - " .. Config.Stages[stage].name
		if stage > 1 then
			showToast("STAGE " .. stage .. ": " .. Config.Stages[stage].name, Color3.fromRGB(255, 220, 80))
		end
	end
end)

-- Zone lighting: Earth -> Sky -> Space ----------------------------------------------------------
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
local ZONES = {
	Earth = { lighting = { ClockTime = 14, Brightness = 2, Ambient = Color3.fromRGB(70, 70, 70), OutdoorAmbient = Color3.fromRGB(128, 128, 128) }, atmo = { Density = 0.3, Haze = 0, Color = Color3.fromRGB(199, 199, 199) } },
	Sky = { lighting = { ClockTime = 16.5, Brightness = 2.5, Ambient = Color3.fromRGB(110, 110, 130), OutdoorAmbient = Color3.fromRGB(160, 160, 190) }, atmo = { Density = 0.35, Haze = 1.5, Color = Color3.fromRGB(200, 225, 255) } },
	Space = { lighting = { ClockTime = 0, Brightness = 1, Ambient = Color3.fromRGB(120, 110, 150), OutdoorAmbient = Color3.fromRGB(140, 130, 170) }, atmo = { Density = 0, Haze = 0, Color = Color3.fromRGB(0, 0, 0) } },
}
local currentZone = nil
RunService.Heartbeat:Connect(function()
	local zone = Config.Stages[Config.stageAt(camera.CFrame.Position.X)].zone
	if camera.CFrame.Position.X < Config.LAUNCH_X then
		zone = "Earth"
	end
	if zone ~= currentZone then
		currentZone = zone
		local info = TweenInfo.new(2)
		TweenService:Create(Lighting, info, ZONES[zone].lighting):Play()
		TweenService:Create(atmosphere, info, ZONES[zone].atmo):Play()
	end
end)
