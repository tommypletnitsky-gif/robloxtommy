-- Client: HUD, launching, flying (rocket follows your mouse / finger; WASD as backup), camera,
-- pickups (coins, gems, rings, obstacles), launch + landing effects, music, zone lighting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local LaunchRemote = remotes:WaitForChild("Launch")
local FlightEvent = remotes:WaitForChild("Flight")
local CollectRemote = remotes:WaitForChild("Collect")
local UnlockStage = remotes:WaitForChild("UnlockStage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local make, label = UIKit.make, UIKit.label
local abbreviate, meters = Config.abbreviate, Config.meters
local gui = UIKit.gui()

-- Top-left: money + best pills ------------------------------------------------------------
local function pill(y, color, icon)
	local f = make("Frame", { Parent = gui, Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(230, 54), BackgroundColor3 = Color3.new(1, 1, 1) }, { UIKit.corner(27), UIKit.stroke(3.5), UIKit.gloss(color), make("UIScale", {}) })
	make("Frame", { Parent = f, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.84, 0.3) }, { UIKit.corner(10) })
	local circle = make("Frame", { Parent = f, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -8, 0.5, 0), Size = UDim2.fromOffset(62, 62), BackgroundColor3 = Color3.new(1, 1, 1) }, { UIKit.corner(31), UIKit.stroke(3.5) })
	label({ Parent = circle, Size = UDim2.fromScale(1, 1), Text = icon })
	local text = label({ Parent = f, Position = UDim2.fromOffset(62, 6), Size = UDim2.new(1, -74, 1, -12), TextXAlignment = Enum.TextXAlignment.Left, Text = "", StrokeThickness = 3 })
	return f, text
end
local moneyPill, moneyText = pill(70, Color3.fromRGB(80, 210, 90), "💰")
local bestPill, bestText = pill(134, Color3.fromRGB(255, 180, 40), "🏆")

-- Right: stage card --------------------------------------------------------------------------
local stageCard = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 70),
	Size = UDim2.fromOffset(250, 176),
	BackgroundColor3 = Color3.new(1, 1, 1),
}, { UIKit.corner(22), UIKit.stroke(4), make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 232, 255)) }) })
local stageTitle = label({ Parent = stageCard, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 32), Text = "Stage 1", TextColor3 = Color3.fromRGB(70, 140, 255), StrokeThickness = 0 })
local stageName = label({ Parent = stageCard, Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 22), Text = "", TextColor3 = Color3.fromRGB(90, 90, 120), StrokeThickness = 0 })
local barBack = make("Frame", { Parent = stageCard, Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 0, 24), BackgroundColor3 = Color3.fromRGB(215, 222, 240) }, { UIKit.corner(12), UIKit.stroke(3) })
local barFill = make("Frame", { Parent = barBack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, { UIKit.corner(12), UIKit.gloss(Color3.fromRGB(90, 180, 255)) })
local barText = label({ Parent = barBack, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2, StrokeThickness = 2 })
local unlockBtn = UIKit.button({ Parent = stageCard, Text = "UNLOCK", Color = Color3.fromRGB(80, 200, 90), Position = UDim2.fromOffset(16, 104), Size = UDim2.new(1, -32, 0, 58) })

-- Bottom bar: LAUNCH (ShopClient adds ROCKETS / UPGRADES around it) + EGGS ------------------
local bottomBar = UIKit.bottomBar()
local launchBtn = UIKit.button({ Parent = bottomBar, LayoutOrder = 2, Text = "LAUNCH!", Color = Color3.fromRGB(255, 130, 30), Size = UDim2.fromOffset(230, 92), Radius = 24, TextStroke = 4 })
local launchPulse = make("UIScale", { Parent = launchBtn.Instance })
task.spawn(function()
	while true do
		TweenService:Create(launchPulse, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { Scale = 1.05 }):Play()
		task.wait(0.7)
		TweenService:Create(launchPulse, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
		task.wait(0.7)
	end
end)
local eggsBtn = UIKit.button({ Parent = bottomBar, LayoutOrder = 4, Icon = "🥚", Text = "EGGS", Color = Color3.fromRGB(80, 200, 120), Size = UDim2.fromOffset(96, 100) })
eggsBtn.Instance.Activated:Connect(function()
	UIKit.toast("🥚 Eggs & pets are coming soon!", Color3.fromRGB(255, 230, 120))
end)

-- Flight HUD ----------------------------------------------------------------------------------
local flightHud = make("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(420, 150), BackgroundTransparency = 1, Visible = false })
local distanceLabel = label({ Parent = flightHud, Size = UDim2.new(1, 0, 0, 70), Text = "0m", StrokeThickness = 4 })
local zoneLabel = label({ Parent = flightHud, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 28), Text = "", TextColor3 = Color3.fromRGB(255, 230, 120) })
local fuelBack = make("Frame", { Parent = flightHud, Position = UDim2.fromOffset(40, 106), Size = UDim2.new(1, -80, 0, 30), BackgroundColor3 = Color3.fromRGB(60, 60, 80) }, { UIKit.corner(15), UIKit.stroke(3.5) })
local fuelFill = make("Frame", { Parent = fuelBack, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, { UIKit.corner(15), UIKit.gloss(Color3.fromRGB(255, 160, 30)) })
label({ Parent = fuelBack, Size = UDim2.fromScale(1, 1), Text = "⛽ FUEL", ZIndex = 2 })
local flightMoney = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 212), Size = UDim2.fromOffset(300, 30), Text = "", TextColor3 = Color3.fromRGB(130, 255, 130), Visible = false })
local hintLabel = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(620, 30), Text = "", Visible = false })

-- Reticle that the rocket steers toward
local reticle = make("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, Visible = false, ZIndex = 5 }, {
	UIKit.corner(23),
	make("UIStroke", { Thickness = 4, Color = Color3.new(1, 1, 1) }),
})
make("Frame", { Parent = reticle, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(255, 120, 40), ZIndex = 6 }, { UIKit.corner(5), UIKit.stroke(2) })

-- Speed lines streaking from the middle of the screen
local linesFrame = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2 })
local linePool = {}
for i = 1, 36 do
	linePool[i] = make("Frame", { Parent = linesFrame, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, ZIndex = 2 })
end
local lineIndex = 0
local function spawnSpeedLine(intensity)
	lineIndex = lineIndex % #linePool + 1
	local l = linePool[lineIndex]
	local a = math.random() * math.pi * 2
	local r0 = 0.32 + math.random() * 0.12
	l.Rotation = math.deg(a)
	l.Size = UDim2.fromOffset(math.random(60, 140), 3)
	l.Position = UDim2.fromScale(0.5 + math.cos(a) * r0, 0.5 + math.sin(a) * r0)
	l.BackgroundTransparency = 1 - 0.55 * intensity
	l.Visible = true
	TweenService:Create(l, TweenInfo.new(0.25, Enum.EasingStyle.Linear), { Position = UDim2.fromScale(0.5 + math.cos(a) * (r0 + 0.35), 0.5 + math.sin(a) * (r0 + 0.35)), BackgroundTransparency = 1 }):Play()
end

-- Big center text (countdown) and result card
local bigLabel = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(500, 150), Text = "", Visible = false, StrokeThickness = 6, ZIndex = 20 })
make("UIScale", { Parent = bigLabel })
local flash = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 60, 60), BackgroundTransparency = 1, ZIndex = 1 })

local resultCard = make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.44),
	Size = UDim2.fromOffset(420, 300),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
	ZIndex = 20,
}, { UIKit.corner(28), UIKit.stroke(5), make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 228, 255)) }), make("UIScale", {}) })
local ribbon = make("Frame", { Parent = resultCard, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(330, 66), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22 }, { UIKit.corner(20), UIKit.stroke(4), UIKit.gloss(Color3.fromRGB(255, 190, 40)) })
local ribbonText = label({ Parent = ribbon, Position = UDim2.fromScale(0.05, 0.1), Size = UDim2.fromScale(0.9, 0.8), Text = "", ZIndex = 23, StrokeThickness = 3.5 })
local resDistance = label({ Parent = resultCard, Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 60), Text = "", TextColor3 = Color3.fromRGB(70, 140, 255), ZIndex = 21, StrokeThickness = 3 })
local resMoney = label({ Parent = resultCard, Position = UDim2.fromOffset(20, 118), Size = UDim2.new(1, -40, 0, 54), Text = "", TextColor3 = Color3.fromRGB(80, 210, 90), ZIndex = 21, StrokeThickness = 3 })
local resCoins = label({ Parent = resultCard, Position = UDim2.fromOffset(20, 176), Size = UDim2.new(1, -40, 0, 32), Text = "", TextColor3 = Color3.fromRGB(255, 190, 40), ZIndex = 21 })
local resHint = label({ Parent = resultCard, Position = UDim2.fromOffset(20, 222), Size = UDim2.new(1, -40, 0, 56), Text = "", TextColor3 = Color3.fromRGB(90, 90, 120), ZIndex = 21, StrokeThickness = 0 })

-- Stats / stage card ----------------------------------------------------------------------------
local shownMoney = 0
local moneyTween
local function refreshMoney()
	local target = player:GetAttribute("Money") or 0
	if moneyTween then
		moneyTween:Disconnect()
	end
	local from, t0 = shownMoney, os.clock()
	moneyTween = RunService.RenderStepped:Connect(function()
		local a = math.min(1, (os.clock() - t0) / 0.6)
		shownMoney = from + (target - from) * (1 - (1 - a) ^ 3)
		moneyText.Text = "$" .. abbreviate(shownMoney)
		if a >= 1 then
			moneyTween:Disconnect()
			moneyTween = nil
		end
	end)
	if target > from then
		UIKit.bounce(moneyPill)
	end
end

local function refreshGates()
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	local unlocked = player:GetAttribute("UnlockedStage") or 1
	for _, gate in ipairs(world:GetDescendants()) do
		if gate:IsA("Model") and gate.Name == "Gate" then
			local open = (gate:GetAttribute("Stage") or 99) <= unlocked
			for _, barrier in ipairs(gate:GetChildren()) do
				if barrier.Name == "Barrier" and barrier:IsA("BasePart") then
					barrier.Transparency = open and 1 or 0.55
					local surface = barrier:FindFirstChildOfClass("SurfaceGui")
					if surface then
						surface.Enabled = not open
					end
				end
			end
		end
	end
end

local function refreshStage()
	local money = player:GetAttribute("Money") or 0
	local best = player:GetAttribute("BestDistance") or 0
	local unlocked = player:GetAttribute("UnlockedStage") or 1
	bestText.Text = meters(best)
	stageTitle.Text = "STAGE " .. unlocked .. " / " .. Config.NUM_STAGES
	stageName.Text = Config.Stages[unlocked].name
	if unlocked >= Config.NUM_STAGES then
		barFill.Size = UDim2.fromScale(1, 1)
		barText.Text = "ALL STAGES OPEN!"
		unlockBtn.Instance.Visible = false
		return
	end
	local goal = Config.stageEndX(unlocked) - Config.LAUNCH_X
	local progress = math.clamp((best - (goal - Config.STAGE_LENGTH)) / Config.STAGE_LENGTH, 0, 1)
	TweenService:Create(barFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.max(progress, 0.04), 1) }):Play()
	barText.Text = meters(math.min(best, goal)) .. " / " .. meters(goal)
	local cost = Config.stageCost(unlocked + 1)
	if best < goal - 5 then
		unlockBtn.setText("Reach " .. meters(goal) .. "!")
		unlockBtn.setColor(Color3.fromRGB(150, 155, 180))
	elseif money < cost then
		unlockBtn.setText("Stage " .. (unlocked + 1) .. ": $" .. abbreviate(cost))
		unlockBtn.setColor(Color3.fromRGB(230, 120, 80))
	else
		unlockBtn.setText("UNLOCK $" .. abbreviate(cost))
		unlockBtn.setColor(Color3.fromRGB(80, 200, 90))
	end
end

player:GetAttributeChangedSignal("Money"):Connect(function()
	refreshMoney()
	refreshStage()
end)
player:GetAttributeChangedSignal("BestDistance"):Connect(refreshStage)
player:GetAttributeChangedSignal("UnlockedStage"):Connect(function()
	refreshStage()
	refreshGates()
end)
task.spawn(function()
	repeat
		task.wait(0.2)
	until player:GetAttribute("DataLoaded")
	shownMoney = player:GetAttribute("Money") or 0
	moneyText.Text = "$" .. abbreviate(shownMoney)
	refreshStage()
	refreshGates()
end)

unlockBtn.Instance.Activated:Connect(function()
	local ok, msg = UnlockStage:InvokeServer()
	UIKit.result(ok, msg)
	if ok then
		UIKit.sound("Win", 0.6)
	end
end)

remotes:WaitForChild("Notify").OnClientEvent:Connect(UIKit.toast)

-- Launching ---------------------------------------------------------------------------------
local function requestLaunch()
	if player:GetAttribute("Flying") then
		return
	end
	resultCard.Visible = false
	UIKit.closeAll()
	LaunchRemote:FireServer()
end
launchBtn.Instance.Activated:Connect(requestLaunch)

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

local lobbyUi = { moneyPill, bestPill, stageCard, bottomBar, UIKit.sideBar() }
player:GetAttributeChangedSignal("Flying"):Connect(function()
	local flying = player:GetAttribute("Flying")
	for _, f in ipairs(lobbyUi) do
		f.Visible = not flying
	end
	if flying then
		UIKit.closeAll()
	end
end)

-- Music ---------------------------------------------------------------------------------------
local music = {}
for _, name in ipairs({ "LobbyMusic", "FlightMusic" }) do
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = Config.Sounds[name]
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	music[name] = s
end
local function playMusic(name)
	for n, s in pairs(music) do
		TweenService:Create(s, TweenInfo.new(1.2), { Volume = n == name and 0.3 or 0 }):Play()
	end
end
playMusic("LobbyMusic")

-- Camera shake ----------------------------------------------------------------------------------
local shake = 0
local function addShake(amount)
	shake = math.max(shake, amount)
end

-- Pickups (coins, gems, rings, obstacles) ---------------------------------------------------
local pickupList = {}
local function loadPickups()
	local folder = workspace:WaitForChild("World"):WaitForChild("Pickups", 20)
	if not folder then
		return
	end
	for _, m in ipairs(folder:GetChildren()) do
		local parts = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, { part = d, t = d.Transparency })
			end
		end
		local pos = m:GetAttribute("Pos") or m:GetPivot().Position
		table.insert(pickupList, { model = m, id = m:GetAttribute("Id"), kind = m:GetAttribute("Kind"), pos = pos, base = CFrame.new(pos), parts = parts, alive = true, phase = math.random() * 6 })
	end
	table.sort(pickupList, function(a, b)
		return a.pos.X < b.pos.X
	end)
end
task.spawn(loadPickups)

local function setPickupVisible(p, visible)
	p.alive = visible
	for _, e in ipairs(p.parts) do
		e.part.Transparency = visible and e.t or 1
	end
end

local function resetPickups()
	for _, p in ipairs(pickupList) do
		if not p.alive then
			setPickupVisible(p, true)
		end
	end
end

-- Index of the first pickup with pos.X >= x (binary search).
local function firstAtOrAfter(x)
	local lo, hi = 1, #pickupList + 1
	while lo < hi do
		local mid = (lo + hi) // 2
		if pickupList[mid].pos.X < x then
			lo = mid + 1
		else
			hi = mid
		end
	end
	return lo
end

local function popText(text, color)
	local l = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.1, 0.45), Size = UDim2.fromOffset(220, 44), Text = text, TextColor3 = color, ZIndex = 15, StrokeThickness = 3 })
	UIKit.bounce(l)
	TweenService:Create(l, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = l.Position - UDim2.fromOffset(0, 90), TextTransparency = 1 }):Play()
	local st = l:FindFirstChildOfClass("UIStroke")
	TweenService:Create(st, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	task.delay(1, function()
		l:Destroy()
	end)
end

-- Flight ---------------------------------------------------------------------------------------
local flight = nil
local combo = 0

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

-- Steering input: mouse / finger position (default) or keys.
local pointer = nil -- Vector2 screen position, or nil before the first move
local useKeys = false
local GuiService = game:GetService("GuiService")
local pointerIsMouse = true
-- Screen position in the same space as our IgnoreGuiInset ScreenGui.
local function touchPoint(input)
	local inset = GuiService:GetGuiInset()
	return Vector2.new(input.Position.X, input.Position.Y) + inset
end
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		pointer = UserInputService:GetMouseLocation()
		pointerIsMouse = true
		useKeys = false
	elseif input.UserInputType == Enum.UserInputType.Touch then
		pointer = touchPoint(input)
		pointerIsMouse = false
		useKeys = false
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch then
		pointer = touchPoint(input)
		pointerIsMouse = false
		useKeys = false
	elseif not processed and input.UserInputType == Enum.UserInputType.Keyboard then
		local K = Enum.KeyCode
		if table.find({ K.W, K.A, K.S, K.D, K.Up, K.Down, K.Left, K.Right }, input.KeyCode) then
			useKeys = true
		end
	end
end)

local function keySteer()
	local function down(...)
		for _, k in ipairs({ ... }) do
			if UserInputService:IsKeyDown(k) then
				return true
			end
		end
		return false
	end
	local K = Enum.KeyCode
	local side = (down(K.D, K.Right) and 1 or 0) - (down(K.A, K.Left) and 1 or 0)
	local up = (down(K.W, K.Up, K.Space) and 1 or 0) - (down(K.S, K.Down, K.LeftShift) and 1 or 0)
	return side, up
end

local launchFx -- smoke at the pad during countdown

local function makeLaunchSmoke(at)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(16, 1, 16)
	p.CFrame = CFrame.new(at)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 210, 220))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 14) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Rate = 30
	e.Parent = p
	return p, e
end

local function stopFlightFx()
	flightHud.Visible = false
	flightMoney.Visible = false
	hintLabel.Visible = false
	reticle.Visible = false
	linesFrame.Visible = false
	UserInputService.MouseIconEnabled = true
	setJumpBlocked(false)
	if flight and flight.engine then
		flight.engine:Destroy()
	end
end

local function coinBurst(count)
	local target = moneyPill.AbsolutePosition + moneyPill.AbsoluteSize / 2
	for i = 1, count do
		local c = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(40, 40), Text = "💰", ZIndex = 25, StrokeThickness = 0 })
		local spread = UDim2.fromOffset(math.random(-160, 160), math.random(-120, 80))
		local t1 = TweenService:Create(c, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Position = c.Position + spread })
		t1:Play()
		task.delay(0.35 + i * 0.03, function()
			local t2 = TweenService:Create(c, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(20, 20) })
			t2:Play()
			t2.Completed:Wait()
			c:Destroy()
			UIKit.sound("Coin", 0.25, 1 + i * 0.03)
		end)
	end
end

FlightEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "countdown" then
		setJumpBlocked(true)
		resultCard.Visible = false
		resetPickups()
		combo = 0
		local body = info.rocket and info.rocket.PrimaryPart
		camera.CameraType = Enum.CameraType.Scriptable
		if body then
			camera.CFrame = CFrame.lookAt(body.Position + Vector3.new(-18, 7, 20), body.Position + Vector3.new(2, 2, 0))
			launchFx = makeLaunchSmoke(body.Position - Vector3.new(0, 3, 0))
		end
		playMusic("FlightMusic")
		bigLabel.Visible = true
		for i = info.seconds, 1, -1 do
			bigLabel.Text = tostring(i)
			bigLabel.TextColor3 = ({ Color3.fromRGB(120, 255, 120), Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 110, 80) })[i] or Color3.new(1, 1, 1)
			UIKit.bounce(bigLabel)
			UIKit.sound("Beep", 0.5, 1 + (3 - i) * 0.1)
			addShake(0.15 * (4 - i))
			task.wait(1)
		end
		bigLabel.Text = "LIFTOFF!"
		bigLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
		UIKit.bounce(bigLabel)
		task.delay(0.9, function()
			bigLabel.Visible = false
		end)
	elseif kind == "start" then
		local body = info.rocket and info.rocket.PrimaryPart
		if not body then
			return
		end
		UIKit.sound("Launch", 0.7)
		addShake(1.2)
		if launchFx then
			local e = launchFx:FindFirstChildOfClass("ParticleEmitter")
			e:Emit(60)
			e.Rate = 0
			game:GetService("Debris"):AddItem(launchFx, 4)
			launchFx = nil
		end
		local engine = Instance.new("Sound")
		engine.SoundId = Config.Sounds.Engine
		engine.Looped = true
		engine.Volume = 0.35
		engine.Parent = body
		engine:Play()
		flight = {
			body = body,
			thrust = body:WaitForChild("Thrust"),
			aim = body:WaitForChild("Aim"),
			speed = info.speed,
			fuel = info.fuel,
			startX = info.startX,
			launchedAt = os.clock(),
			offY = 12,
			offZ = 0,
			stage = 0,
			engine = engine,
			boostUntil = 0,
			slowUntil = 0,
			bonus = 0,
			scan = 1,
		}
		flightHud.Visible = true
		linesFrame.Visible = true
		if UserInputService.TouchEnabled then
			hintLabel.Text = "Drag your finger to steer!"
		else
			hintLabel.Text = "Move your mouse to steer!  (or WASD)"
			UserInputService.MouseIconEnabled = false
		end
		hintLabel.Visible = true
		task.delay(3, function()
			hintLabel.Visible = false
		end)
	elseif kind == "pickup" then
		if flight and info.fuel then
			flight.fuel = info.fuel
		end
		if info.money and flight then
			flight.bonus += info.money
			flightMoney.Text = "+$" .. abbreviate(flight.bonus) .. " bonus"
			flightMoney.Visible = true
			popText("+$" .. abbreviate(info.money), info.kind == "Gem" and Color3.fromRGB(120, 230, 255) or Color3.fromRGB(255, 220, 60))
		end
	elseif kind == "outOfFuel" then
		if flight then
			flight.outOfFuel = os.clock()
			if flight.engine then
				TweenService:Create(flight.engine, TweenInfo.new(0.5), { Volume = 0 }):Play()
			end
			bigLabel.Text = "OUT OF FUEL!"
			bigLabel.TextColor3 = Color3.fromRGB(255, 140, 80)
			bigLabel.Visible = true
			UIKit.bounce(bigLabel)
			task.delay(1.2, function()
				if bigLabel.Text == "OUT OF FUEL!" then
					bigLabel.Visible = false
				end
			end)
		end
	elseif kind == "result" then
		stopFlightFx()
		if flight then
			flight.landed = true
		end
		bigLabel.Visible = false
		ribbonText.Text = info.newBest and "NEW BEST!" or "FLIGHT OVER"
		ribbon.Visible = true
		resDistance.Text = "🚀 " .. meters(info.distance)
		resMoney.Text = "+$" .. abbreviate(info.money)
		resCoins.Text = (info.bonus or 0) > 0 and ("💰 " .. info.coins .. (info.coins == 1 and " coin: +$" or " coins: +$") .. abbreviate(info.bonus)) or ""
		resHint.Text = ({
			fuel = "Out of fuel! Upgrade your Fuel Tank to fly farther.",
			gate = "Stage locked! Unlock the next stage to keep going.",
			jumped = "You fell off your rocket!",
			finish = "You reached the end of the galaxy!",
		})[info.reason] or ""
		resultCard.Visible = true
		local s = resultCard:FindFirstChildOfClass("UIScale")
		s.Scale = 0.3
		TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		UIKit.sound("Win", 0.6)
		task.delay(0.5, function()
			coinBurst(info.newBest and 16 or 10)
		end)
		task.delay(5, function()
			if not player:GetAttribute("Flying") then
				resultCard.Visible = false
			end
		end)
	end
end)

resultCard.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resultCard.Visible = false
	end
end)

player:GetAttributeChangedSignal("Flying"):Connect(function()
	if not player:GetAttribute("Flying") then
		flight = nil
		stopFlightFx()
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		playMusic("LobbyMusic")
	end
end)

local function hitTest(p, rp)
	local d = p.pos - rp
	if p.kind == "Ring" then
		return math.abs(d.X) < 3.5 and Vector2.new(d.Y, d.Z).Magnitude < 7.5
	elseif p.kind == "Obstacle" then
		return d.Magnitude < 6
	end
	return d.Magnitude < Config.PICKUP_RADIUS
end

local function collect(p)
	setPickupVisible(p, false)
	CollectRemote:FireServer(p.id)
	local f = flight
	if p.kind == "Coin" or p.kind == "Gem" then
		combo += 1
		UIKit.sound("Coin", 0.45, math.min(1.6, 1 + combo * 0.04))
	elseif p.kind == "Ring" then
		f.boostUntil = os.clock() + Config.Pickups.Ring.boostTime
		UIKit.sound("Boost", 0.6)
		popText("BOOST! +FUEL", Color3.fromRGB(255, 180, 40))
		addShake(0.4)
	elseif p.kind == "Obstacle" then
		f.slowUntil = os.clock() + Config.Pickups.Obstacle.slowTime
		combo = 0
		UIKit.sound("Hit", 0.5)
		popText("OUCH! -FUEL", Color3.fromRGB(255, 90, 90))
		addShake(1)
		flash.BackgroundTransparency = 0.55
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end
end

local lineTimer = 0
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	-- spin coins / gems / rings near the camera (cheap: only a window around the camera)
	if #pickupList > 0 then
		local cx = camera.CFrame.Position.X
		local i = firstAtOrAfter(cx - 60)
		while i <= #pickupList and pickupList[i].pos.X < cx + 320 do
			local p = pickupList[i]
			if p.alive then
				if p.kind == "Coin" then
					p.model:PivotTo(CFrame.new(p.pos) * CFrame.Angles(0, now * 3 + p.phase, 0))
				elseif p.kind == "Gem" then
					p.model:PivotTo(CFrame.new(p.pos + Vector3.new(0, math.sin(now * 2 + p.phase) * 0.6, 0)) * CFrame.Angles(math.rad(45), now * 2, math.rad(45)))
				elseif p.kind == "Ring" then
					p.model:PivotTo(CFrame.new(p.pos) * CFrame.Angles(now * 1.2 + p.phase, 0, 0))
				elseif p.kind == "Obstacle" then
					p.model:PivotTo(p.base + Vector3.new(0, math.sin(now * 2.5 + p.phase) * 1.2, 0))
				end
			end
			i += 1
		end
	end

	-- camera shake decay
	local shakeOffset = CFrame.new()
	if shake > 0.01 then
		shakeOffset = CFrame.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * shake * 0.03)
		shake *= math.exp(-dt * 5)
	end

	local f = flight
	if not f then
		if shake > 0.01 and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CFrame *= shakeOffset
		end
		return
	end
	if not f.body.Parent then
		return
	end
	local pos = f.body.Position

	-- Landed (server anchored the rocket): slow orbit around it until we're sent home.
	if f.landed then
		local a = now * 0.5
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(pos + Vector3.new(math.cos(a) * 18, 8, math.sin(a) * 18), pos), math.min(1, dt * 3))
		return
	end

	-- The flight camera sits behind the path (not behind the rocket), so the rocket visibly
	-- moves around the screen and flies to wherever you point.
	local CAM_BACK, CAM_UP = 44, 36
	local camBase = Vector3.new(pos.X - CAM_BACK, Config.pathY(pos.X) + CAM_UP, 0)

	-- Steering target from the pointer (or keys)
	if useKeys or not pointer then
		local side, up = keySteer()
		f.offY = math.clamp(f.offY + up * Config.STEER_SPEED * dt, Config.FLY_MIN_HEIGHT, Config.FLY_MAX_HEIGHT)
		f.offZ = math.clamp(f.offZ + side * Config.STEER_SPEED * dt, -Config.PATH_HALF_WIDTH, Config.PATH_HALF_WIDTH)
		reticle.Visible = false
	else
		if pointerIsMouse then
			pointer = UserInputService:GetMouseLocation()
		end
		-- where the pointer's ray crosses the rocket's flight plane
		local ray = camera:ViewportPointToRay(pointer.X, pointer.Y)
		local targetY, targetZ = f.offY, f.offZ
		if ray.Direction.X > 0.05 then
			local hit = ray.Origin + ray.Direction * ((pos.X - ray.Origin.X) / ray.Direction.X)
			targetY = math.clamp(hit.Y - Config.pathY(pos.X), Config.FLY_MIN_HEIGHT, Config.FLY_MAX_HEIGHT)
			targetZ = math.clamp(hit.Z, -Config.PATH_HALF_WIDTH, Config.PATH_HALF_WIDTH)
		end
		if now - f.launchedAt < 0.8 then
			targetY = math.max(targetY, 22) -- lift off the pad first
		end
		local k = math.min(1, dt * 5)
		f.offY += (targetY - f.offY) * k
		f.offZ += (targetZ - f.offZ) * k
		reticle.Position = UDim2.fromOffset(pointer.X, pointer.Y)
		reticle.Visible = not f.outOfFuel
	end

	local speedMul = 1
	if now < f.boostUntil then
		speedMul = Config.Pickups.Ring.boost
	elseif now < f.slowUntil then
		speedMul = Config.Pickups.Obstacle.slow
	end

	local vel
	if f.outOfFuel then
		-- slow-motion glide down to the path
		local t = now - f.outOfFuel
		local fall = pos.Y > Config.pathY(pos.X) + 2.5 and (-8 - t * 6) or 0
		vel = Vector3.new(f.speed * math.max(0.08, 0.3 - t * 0.1), fall, -pos.Z * 0.5)
	else
		local speed = f.speed * speedMul
		local slope = Config.pathY(pos.X + 1) - Config.pathY(pos.X)
		local targetY = Config.pathY(pos.X) + f.offY
		vel = Vector3.new(speed, slope * speed + (targetY - pos.Y) * 5, (f.offZ - pos.Z) * 5)
	end
	f.thrust.VectorVelocity = vel
	local roll = math.clamp((f.offZ - pos.Z) * 0.04, -0.6, 0.6)
	f.aim.CFrame = CFrame.lookAt(Vector3.zero, vel.Unit) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(roll, 0, 0)

	-- Camera: steady chase view over the path; FOV widens a little with speed.
	-- Slow-mo (out of fuel) swings in close beside the rocket.
	if f.outOfFuel then
		local camTarget = CFrame.lookAt(pos + Vector3.new(-10, 5, 14), pos + Vector3.new(4, 0, 0))
		camera.FieldOfView += (60 - camera.FieldOfView) * math.min(1, dt * 2)
		camera.CFrame = camera.CFrame:Lerp(camTarget, math.min(1, dt * 2)) * shakeOffset
	else
		local fov = 70 + math.min(12, f.speed * speedMul * 0.04)
		camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 3)
		local look = Vector3.new(pos.X + 30, Config.pathY(pos.X + 30) + CAM_UP - 4, 0)
		camera.CFrame = CFrame.lookAt(camBase, look) * shakeOffset
	end

	-- Speed lines
	if not f.outOfFuel then
		lineTimer += dt
		local interval = speedMul > 1 and 0.015 or 0.04
		while lineTimer > interval do
			lineTimer -= interval
			spawnSpeedLine(speedMul > 1 and 1 or 0.6)
		end
	end
	if f.engine then
		f.engine.PlaybackSpeed = 0.9 + speedMul * 0.2
	end

	-- Pickups near the rocket
	if not f.outOfFuel and #pickupList > 0 then
		local i = firstAtOrAfter(pos.X - 8)
		while i <= #pickupList and pickupList[i].pos.X <= pos.X + 8 do
			local p = pickupList[i]
			if p.alive and hitTest(p, pos) then
				collect(p)
			end
			i += 1
		end
	end

	-- HUD
	distanceLabel.Text = meters(math.max(0, pos.X - f.startX))
	local fuelLeft = f.outOfFuel and 0 or math.clamp(1 - (now - f.launchedAt) / f.fuel, 0, 1)
	fuelFill.Size = UDim2.fromScale(fuelLeft, 1)
	local stage = Config.stageAt(pos.X)
	if stage ~= f.stage then
		f.stage = stage
		zoneLabel.Text = "Stage " .. stage .. " - " .. Config.Stages[stage].name
		if stage > 1 then
			UIKit.toast("STAGE " .. stage .. ": " .. Config.Stages[stage].name, Color3.fromRGB(255, 220, 80))
		end
	end
end)

-- Name tags over other players' rockets ---------------------------------------------------
local flights = workspace:WaitForChild("Flights")
flights.ChildAdded:Connect(function(m)
	if m.Name == player.Name then
		return
	end
	local body = m:WaitForChild("Body", 5)
	if not body then
		return
	end
	local bb = make("BillboardGui", { Parent = body, Size = UDim2.fromOffset(160, 36), StudsOffset = Vector3.new(0, 6, 0), AlwaysOnTop = true, MaxDistance = 300 })
	label({ Parent = bb, Size = UDim2.fromScale(1, 1), Text = m.Name, TextColor3 = Color3.fromRGB(255, 230, 120) })
end)

-- Zone lighting: Earth -> Sky -> Space, plus a bright cartoon color grade ---------------------
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
local grade = Lighting:FindFirstChild("CartoonGrade") or Instance.new("ColorCorrectionEffect")
grade.Name = "CartoonGrade"
grade.Saturation = 0.25
grade.Contrast = 0.08
grade.Brightness = 0.02
grade.Parent = Lighting
local ZONES = {
	Earth = { lighting = { ClockTime = 14, Brightness = 2.2, Ambient = Color3.fromRGB(90, 90, 100), OutdoorAmbient = Color3.fromRGB(150, 150, 160) }, atmo = { Density = 0.25, Haze = 0, Glare = 0, Color = Color3.fromRGB(210, 225, 255) } },
	Sky = { lighting = { ClockTime = 16.5, Brightness = 2.6, Ambient = Color3.fromRGB(120, 120, 140), OutdoorAmbient = Color3.fromRGB(170, 170, 200) }, atmo = { Density = 0.32, Haze = 1.2, Glare = 0, Color = Color3.fromRGB(210, 230, 255) } },
	Space = { lighting = { ClockTime = 0, Brightness = 1, Ambient = Color3.fromRGB(130, 120, 160), OutdoorAmbient = Color3.fromRGB(150, 140, 180) }, atmo = { Density = 0, Haze = 0, Glare = 0, Color = Color3.fromRGB(0, 0, 0) } },
}
-- Some worlds get their own mood on top of the zone lighting.
local STAGE_MOODS = {
	["Dusty Desert"] = { lighting = { ClockTime = 13, Brightness = 2.6 }, atmo = { Color = Color3.fromRGB(255, 225, 180), Density = 0.3, Haze = 0.6 } },
	["Red Canyon"] = { lighting = { ClockTime = 15.5 }, atmo = { Color = Color3.fromRGB(255, 200, 170), Density = 0.3, Haze = 0.8 } },
	["Misty Swamp"] = { lighting = { Brightness = 1.7 }, atmo = { Color = Color3.fromRGB(190, 225, 190), Density = 0.42, Haze = 2.2 } },
	["Volcano"] = { lighting = { ClockTime = 17.4, Brightness = 2, OutdoorAmbient = Color3.fromRGB(170, 120, 110) }, atmo = { Color = Color3.fromRGB(255, 150, 110), Density = 0.38, Haze = 2 } },
	["Snowy Tundra"] = { lighting = { Brightness = 2.5 }, atmo = { Color = Color3.fromRGB(225, 240, 255), Density = 0.3, Haze = 0.8 } },
	["Sunset Sky"] = { lighting = { ClockTime = 16.9, Brightness = 2.8 }, atmo = { Color = Color3.fromRGB(255, 175, 110), Density = 0.3, Haze = 2.2, Glare = 0.4 } },
	["Thunder Storm"] = { lighting = { Brightness = 1.3, OutdoorAmbient = Color3.fromRGB(120, 120, 145) }, atmo = { Color = Color3.fromRGB(150, 155, 180), Density = 0.45, Haze = 2.5 } },
	["Aurora Lights"] = { lighting = { ClockTime = 20.5, Brightness = 1.4 }, atmo = { Color = Color3.fromRGB(150, 220, 210), Density = 0.25, Haze = 1 } },
	["Edge of Space"] = { lighting = { ClockTime = 19.6, Brightness = 1.5 }, atmo = { Color = Color3.fromRGB(120, 130, 200), Density = 0.18, Haze = 0.5 } },
}

local function moodFor(x)
	local stage = x < Config.LAUNCH_X and nil or Config.Stages[Config.stageAt(x)]
	local zone = stage and stage.zone or "Earth"
	local lighting, atmo = table.clone(ZONES[zone].lighting), table.clone(ZONES[zone].atmo)
	local mood = stage and STAGE_MOODS[stage.name]
	if mood then
		for k, v in pairs(mood.lighting) do
			lighting[k] = v
		end
		for k, v in pairs(mood.atmo) do
			atmo[k] = v
		end
	end
	return (stage and stage.name or "Lobby"), lighting, atmo
end

local currentMood = nil
RunService.Heartbeat:Connect(function()
	local name, lighting, atmo = moodFor(camera.CFrame.Position.X)
	if name ~= currentMood then
		currentMood = name
		local info = TweenInfo.new(2)
		TweenService:Create(Lighting, info, lighting):Play()
		TweenService:Create(atmosphere, info, atmo):Play()
	end
end)
