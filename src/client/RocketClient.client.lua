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
local Rider = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("RiderAnimator"))
local RocketModel = require(ReplicatedStorage.Shared:WaitForChild("RocketModel"))
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

-- Bottom bar: LAUNCH (PetClient adds PETS beside it) ------------------------------------------
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
local reticleRing = reticle:FindFirstChildOfClass("UIStroke")
local landLabel = label({ Parent = reticle, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.fromOffset(150, 30), Text = "▼ LAND", TextColor3 = Color3.fromRGB(255, 90, 90), Visible = false, ZIndex = 6 })

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

-- No tools in this game: hide Roblox's hotbar / inventory bar.
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

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
local myRider = nil -- RiderAnimator for your own avatar while you're on the rocket

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

-- Steering input -----------------------------------------------------------------------------
-- You steer an aim point across the lane (sideways = studs from the path's center line, up = studs
-- above the path) and the rocket glides after it.
--   PC: while flying the mouse is locked and hidden; any small move slides the aim, so you never
--       have to reach for the edges of the screen. Roblox's own mouse sensitivity setting scales it.
--   Touch: drag anywhere.   Keys: WASD / arrows.   Gamepad: left stick.
--   To land early, pull the aim all the way down and keep pulling (the ring fills up red first).
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local STEER = {
	mouse = 0.11, -- studs per pixel of mouse movement (x Roblox mouse sensitivity): ~4 cm of mouse = edge of the lane
	touch = 110, -- studs per screen height dragged
	keys = 34, -- studs per second while a key is held
	diveCharge = 14, -- extra pull below the lowest height that starts a landing (studs, ~1 cm of mouse)
	keyDive = 11, -- dive charge per second while holding a down key at the lowest height
}
local mouseDelta = Vector2.zero -- pixels moved since the last frame (+X right, +Y down)
local touchDelta = Vector2.zero
local steerTouch = nil -- the finger that steers
local touchCount = 0
local padStick = Vector2.zero
local lastMousePos = nil -- for input that only reports positions (no movement delta)
local lookHeld, lookYaw, lookPitch = false, 0, 0 -- right mouse button: look around (stays where you leave it)
local steerHeld = false -- left mouse button held: drag to steer

UserInputService.InputChanged:Connect(function(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseMovement then
		local d = Vector2.new(input.Delta.X, input.Delta.Y)
		local p = Vector2.new(input.Position.X, input.Position.Y)
		if d.Magnitude == 0 and lastMousePos and UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
			d = p - lastMousePos
		end
		lastMousePos = p
		mouseDelta += d
	elseif t == Enum.UserInputType.Touch then
		if input == steerTouch and touchCount < 2 then -- two fingers = pinch zoom, not steering
			touchDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		end
	elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
		padStick = Vector2.new(input.Position.X, input.Position.Y)
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch then
		touchCount += 1
		if not processed and not steerTouch then
			steerTouch = input
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and flight and not processed then
		lookHeld = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and flight and not processed then
		steerHeld = true
	elseif input.KeyCode == Enum.KeyCode.C and flight and not processed then
		lookYaw, lookPitch = 0, 0 -- snap the camera back behind the rocket
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		touchCount = math.max(0, touchCount - 1)
		if input == steerTouch then
			steerTouch = nil
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		lookHeld = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		steerHeld = false
	end
end)

-- Flight camera zoom: mouse wheel, I / O keys or a two-finger pinch while flying. The camera glides
-- to the new distance instead of jumping; your zoom is kept between flights.
local CAM_DIST = 17 -- default distance behind the rocket
local ZOOM_MIN, ZOOM_MAX = 0.55, 2.4
local camZoom, camZoomTarget = 1, 1
local function zoomBy(factor)
	camZoomTarget = math.clamp(camZoomTarget * factor, ZOOM_MIN, ZOOM_MAX)
end
UserInputService.InputChanged:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not processed and player:GetAttribute("Flying") then
		zoomBy(1.15 ^ -input.Position.Z)
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not player:GetAttribute("Flying") then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		zoomBy(1 / 1.3)
	elseif input.KeyCode == Enum.KeyCode.O then
		zoomBy(1.3)
	end
end)
local lastPinch = nil
UserInputService.TouchPinch:Connect(function(_, scale, _, state)
	if not player:GetAttribute("Flying") then
		return
	end
	if state == Enum.UserInputState.Begin then
		lastPinch = scale
	elseif lastPinch and scale > 0 then
		zoomBy(lastPinch / scale)
		lastPinch = scale
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

-- Cinematic letterbox bars for the launch cutscene.
local bars = {}
for i, anchor in ipairs({ 0, 1 }) do
	bars[i] = make("Frame", { Parent = gui, AnchorPoint = Vector2.new(0, anchor), Position = UDim2.fromScale(0, anchor), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 40 })
end
local function setLetterbox(on)
	for _, b in ipairs(bars) do
		TweenService:Create(b, TweenInfo.new(on and 0.5 or 0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, on and 0.11 or 0) }):Play()
	end
end

-- The launch cannon (Hub.Cannon, parts named by Lobby) animates on this player's screen only:
--   "load"   you climb in: the fuse starts sparking
--   "fire"   BOOM: the barrel kicks back, a puff of smoke from the muzzle, then it rolls home
--   "reset"  flight over: everything back in place, fuse out
local cannon = { model = nil, home = {}, fuse = nil }
local function cannonModel()
	if cannon.model and cannon.model.Parent then
		return cannon.model
	end
	local hub = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Hub")
	local m = hub and hub:FindFirstChild("Cannon")
	cannon.model = m
	cannon.home = {}
	if m then
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				cannon.home[p] = p.CFrame
			end
		end
	end
	return m
end

local function cannonPart(name)
	local m = cannonModel()
	return m and m:FindFirstChild(name, true)
end

local function muzzleSmoke(at, dir)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one
	p.CFrame = CFrame.lookAt(at, at + dir)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 220), Color3.fromRGB(200, 200, 210))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 16) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(10, 30)
	e.SpreadAngle = Vector2.new(35, 35)
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = 0
	e.Parent = p
	e:Emit(70)
	game:GetService("Debris"):AddItem(p, 3)
end

local function animateCannon(phase)
	local m = cannonModel()
	if not m then
		return
	end
	local barrel = cannonPart("Barrel")
	if phase == "load" then
		local fusePart = cannonPart("Fuse") or barrel
		if fusePart and not cannon.fuse then
			local e = Instance.new("ParticleEmitter")
			e.Name = "FuseSparks"
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 120, 40))
			e.Size = NumberSequence.new(0.6, 0.1)
			e.Lifetime = NumberRange.new(0.3, 0.6)
			e.Speed = NumberRange.new(4, 9)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Rate = 60
			e.Parent = fusePart
			cannon.fuse = e
		end
	elseif phase == "fire" then
		if cannon.fuse then
			cannon.fuse:Destroy()
			cannon.fuse = nil
		end
		local dir = m:GetAttribute("Aim") or Vector3.xAxis
		local muzzle = m:GetAttribute("Muzzle")
		if muzzle then
			muzzleSmoke(muzzle, dir)
		end
		if barrel then
			local home = cannon.home[barrel] or barrel.CFrame
			TweenService:Create(barrel, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = home - dir * 3 }):Play()
			task.delay(0.15, function()
				TweenService:Create(barrel, TweenInfo.new(1.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = home }):Play()
			end)
		end
	elseif phase == "reset" then
		if cannon.fuse then
			cannon.fuse:Destroy()
			cannon.fuse = nil
		end
		for p, cf in pairs(cannon.home) do
			if p.Parent then
				p.CFrame = cf
			end
		end
	end
end

-- Rockets loaded in the cannon (attribute InCannon) are hidden with their riders on every screen.
local hiddenModels = {} -- [rocket model] = true while hidden
local function setHidden(model, hidden)
	local plr = Players:FindFirstChild(model.Name)
	local list = { model }
	if plr and plr.Character then
		table.insert(list, plr.Character)
	end
	for _, root in ipairs(list) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
end
RunService.RenderStepped:Connect(function()
	local flightsFolder = workspace:FindFirstChild("Flights")
	if not flightsFolder then
		return
	end
	for _, m in ipairs(flightsFolder:GetChildren()) do
		local inside = m:GetAttribute("InCannon") == true
		if inside ~= (hiddenModels[m] or false) then
			hiddenModels[m] = inside or nil
			setHidden(m, inside)
		end
	end
	for m in pairs(hiddenModels) do
		if not m.Parent then
			hiddenModels[m] = nil
		end
	end
end)

local countdown = nil -- { body, base, t0, dur } while sitting on the pad

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
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
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
		if body then
			launchFx = makeLaunchSmoke(body.Position - Vector3.new(0, 3, 0))
			countdown = { body = body, rocket = info.rocket, base = body.CFrame, t0 = os.clock(), dur = info.seconds }
			-- cutscene: wide shot from straight behind, slowly pushing in to the rider
			camera.CameraType = Enum.CameraType.Scriptable
			camera.FieldOfView = 56
			setLetterbox(true)
			animateCannon("load")
		end
		if myRider then
			myRider:destroy()
		end
		myRider = Rider.new(player.Character)
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
		if countdown and countdown.body == body then
			body.CFrame = countdown.base
		end
		countdown = nil
		local camFrom = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
		setLetterbox(false)
		animateCannon("fire")
		UIKit.sound("Launch", 0.8)
		UIKit.sound("Hit", 0.9, 0.55) -- the cannon's BOOM
		addShake(2)
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
			align = body:WaitForChild("Aim"),
			speed = info.speed,
			fuel = info.fuel,
			startX = info.startX,
			launchedAt = os.clock(),
			-- steering: the aim point you move, and the rocket's smoothed position / speed in lane space
			-- shot out of the cannon: aim a bit above the muzzle so the rocket arcs up out of the barrel
			aim = { z = 0, y = math.max(16, body.Position.Y - Config.pathY(body.Position.X) + 5), dive = 0 },
			simZ = body.Position.Z,
			simY = body.Position.Y - Config.pathY(body.Position.X), -- starts at the cannon's muzzle
			vz = 0,
			vy = 10, -- the cannon throws you upward a little
			lastVz = 0,
			diving = false,
			cancelDive = 0,
			diveHint = false,
			-- camera follow state
			camZ = body.Position.Z,
			camVZ = 0,
			camY = body.Position.Y,
			camVY = 0,
			boostCam = 0,
			stage = 0,
			engine = engine,
			boostUntil = 0,
			slowUntil = 0,
			bonus = 0,
			blastPower = info.blastPower or 1, -- cannon blast: extra speed fading over blastTime
			blastTime = info.blastTime or 0,
			pull = 6 + (info.blastPower or 1) * 2.5, -- launch: a zoom-out kick that eases back in
			pullHold = os.clock() + 0.35,
			bank = 0,
			spin = 0,
			camFrom = camFrom, -- blend from wherever you were looking into the chase camera
			camBlend = 0,
			aimCF = CFrame.new(),
			focus = nil,
			flameFx = nil,
		}
		local flame = body.Parent:FindFirstChild("Flame", true)
		flight.flameFx = flame and flame:FindFirstChildOfClass("Fire")
		flightHud.Visible = true
		linesFrame.Visible = true
		mouseDelta, touchDelta = Vector2.zero, Vector2.zero
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			hintLabel.Text = "Drag anywhere to steer!  Keep dragging down to land."
		else
			hintLabel.Text = "WASD or hold left-click + drag to steer.  Right-click to look around (C = back).  Scroll to zoom."
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
			local flame = flight.body.Parent and flight.body.Parent:FindFirstChild("Flame", true)
			local smoke = flame and flame:FindFirstChildOfClass("ParticleEmitter")
			if smoke then
				smoke:Emit(30)
			end
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
			if info.reason == "landed" or info.reason == "fuel" then
				local dust, e = makeLaunchSmoke(flight.body.Position - Vector3.new(0, 1.5, 0))
				e.Rate = 0
				e:Emit(35)
				game:GetService("Debris"):AddItem(dust, 3)
				addShake(info.reason == "landed" and 1.2 or 0.5)
			end
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
			landed = "You landed! Upgrade to fly even farther.",
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
		countdown = nil
		setLetterbox(false)
		animateCannon("reset")
		if myRider then
			myRider:destroy()
			myRider = nil
		end
		lookHeld, lookYaw, lookPitch = false, 0, 0
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
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
		f.pull = math.max(f.pull, 7)
		f.pullHold = os.clock() + 0.2
		f.spin = math.max(f.spin, math.pi * 2)
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
		local camPos = camera.CFrame.Position
		local cx = camPos.X
		local i = firstAtOrAfter(cx - 60)
		while i <= #pickupList and pickupList[i].pos.X < cx + 320 do
			local p = pickupList[i]
			-- don't let the chase camera fly through a ring / coin you passed beside
			local near = (p.pos - camPos).Magnitude < 10
			if near ~= (p.nearCam or false) then
				p.nearCam = near
				for _, e in ipairs(p.parts) do
					e.part.LocalTransparencyModifier = near and 1 or 0
				end
			end
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
		local n = now * 14
		shakeOffset = CFrame.new(math.noise(n, 0.3) * shake * 1.4, math.noise(n, 5.7) * shake * 1.4, 0) * CFrame.Angles(0, 0, math.noise(n, 9.1) * shake * 0.05)
		shake *= math.exp(-dt * 5)
	end

	if countdown and countdown.body.Parent then
		-- the rocket rumbles harder each second and its nose lifts, ready to launch
		local p = math.clamp((now - countdown.t0) / countdown.dur, 0, 1)
		local j = 0.05 + p * 0.25
		countdown.body.CFrame = countdown.base * CFrame.new((math.random() - 0.5) * j, (math.random() - 0.5) * j, (math.random() - 0.5) * j)
		if myRider then
			myRider:update(dt, { lean = -0.1, pitch = 0.1, shake = 0.5 + p })
		end
		-- camera: straight behind, easing in from a wide shot to just behind the rider
		local e = 1 - (1 - p) ^ 3
		local base = countdown.base.Position
		-- wide shot behind the cannon pushing in over it, looking down the barrel at the path ahead
		local camPos = (base + Vector3.new(-60, 28, 0)):Lerp(base + Vector3.new(-30, 16, 0), e)
		camera.CFrame = CFrame.lookAt(camPos, base + Vector3.new(30, 2, 0)) * shakeOffset
		camera.FieldOfView = 56 + 14 * e
		-- engines light up for the last second
		if p > 0.67 and not countdown.ignited then
			countdown.ignited = true
			RocketModel.setThrust(countdown.rocket, true)
			if launchFx then
				local em = launchFx:FindFirstChildOfClass("ParticleEmitter")
				em.Rate = 90
				em:Emit(40)
			end
			addShake(0.8)
		end
	end

	local f = flight
	if not f then
		mouseDelta, touchDelta = Vector2.zero, Vector2.zero -- only steering moves count
		if shake > 0.01 and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CFrame *= shakeOffset
		end
		return
	end
	if not f.body.Parent then
		return
	end
	local pos = f.body.Position
	camZoom += (camZoomTarget - camZoom) * (1 - math.exp(-dt * 8))

	-- Landed (server anchored the rocket): stay straight behind it, drifting a little closer.
	if f.landed then
		local dist = CAM_DIST * camZoom * 0.9
		local focus = f.focus or pos
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(focus + Vector3.new(-dist, dist * 0.25 + 1, 0), focus + Vector3.new(dist * 0.8, 0, 0)), math.min(1, dt * 2))
		if myRider then
			myRider:update(dt, { lean = -0.15, shake = 0 })
		end
		return
	end

	-- Your cursor stays free and visible while you fly. Hold the right button and move the mouse to
	-- look anywhere (even backwards; it stays there, C snaps it back). Hold the left button and drag
	-- to steer, or use WASD / arrows.
	UserInputService.MouseBehavior = lookHeld and Enum.MouseBehavior.LockCurrentPosition or Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	-- Steering: slide the aim point ---------------------------------------------------------------
	local aim = f.aim
	local W = Config.PATH_HALF_WIDTH
	local floor, ceiling = Config.FLY_MIN_HEIGHT, Config.FLY_MAX_HEIGHT
	local launching = now - f.launchedAt < 0.6 -- liftoff always goes straight
	local dz, dy = 0, 0
	-- a locked mouse reports its movement through GetMouseDelta (the input events are the backup)
	local md = UserInputService:GetMouseDelta()
	if md.Magnitude == 0 then
		md = mouseDelta
	end
	local backwards = math.cos(lookYaw) < 0 -- looking back: left / right swap so steering matches the screen
	if lookHeld then
		lookYaw = (lookYaw - md.X * 0.006 + math.pi) % (2 * math.pi) - math.pi
		lookPitch = math.clamp(lookPitch - md.Y * 0.004, -0.5, 1.2)
	elseif steerHeld then
		local sens = STEER.mouse * math.clamp(UserGameSettings.MouseSensitivity, 0.2, 4)
		dz += md.X * sens * (backwards and -1 or 1)
		dy -= md.Y * sens
	end
	local touchK = STEER.touch / math.max(300, camera.ViewportSize.Y)
	dz += touchDelta.X * touchK
	dy -= touchDelta.Y * touchK
	mouseDelta, touchDelta = Vector2.zero, Vector2.zero
	local side, up = keySteer()
	if padStick.Magnitude > 0.15 then
		side += padStick.X
		up += padStick.Y
	end
	side, up = math.clamp(side, -1, 1), math.clamp(up, -1, 1)
	if backwards then
		side = -side
	end
	local keyDz, keyDy = side * STEER.keys * dt, up * STEER.keys * dt
	if launching or f.outOfFuel then
		dz, dy, keyDz, keyDy, up = 0, 0, 0, 0, 0
	end
	aim.z = math.clamp(aim.z + dz + keyDz, -W, W)
	local newY = aim.y + dy
	if newY < floor then
		aim.dive += floor - newY -- pulling the mouse / finger past the bottom charges a landing
		newY = floor
	elseif dy > 0 then
		aim.dive = math.max(0, aim.dive - dy * 1.5)
	end
	newY = math.max(floor, newY + keyDy)
	if up < 0 and newY <= floor + 0.01 then
		aim.dive += STEER.keyDive * dt -- holding down at the bottom charges slowly
	end
	dy += keyDy
	if dy >= 0 and up >= 0 and not f.diving then
		aim.dive = math.max(0, aim.dive - dt * 6) -- stop pulling and the charge drains away
	end
	aim.y = math.min(newY, ceiling)
	if f.diving then
		if dy > 0 then
			f.cancelDive += dy
			if f.cancelDive > 4 then -- changed your mind: pull up
				f.diving, aim.dive = false, 0
			end
		end
	elseif aim.dive >= STEER.diveCharge then
		f.diving, f.cancelDive = true, 0
		UIKit.sound("Beep", 0.4, 0.7)
	end
	if aim.dive > STEER.diveCharge * 0.25 and not f.diveHint then
		f.diveHint = true
		hintLabel.Text = "Keep pulling down to land!"
		hintLabel.Visible = true
		task.delay(2.5, function()
			if hintLabel.Text == "Keep pulling down to land!" then
				hintLabel.Visible = false
			end
		end)
	end

	-- The rocket glides after the aim on a smooth spring: quick to answer, no wobble. -------------
	local targetZ, targetY = aim.z, f.diving and -4 or aim.y
	local steps = math.max(1, math.ceil(dt * 120))
	local h = dt / steps
	local w, zeta = 3.6, 0.9 -- how quickly the rocket glides after your aim (calm, no overshoot)
	for _ = 1, steps do
		f.vz = math.clamp(f.vz + (w * w * (targetZ - f.simZ) - 2 * zeta * w * f.vz) * h, -32, 32)
		f.vy = math.clamp(f.vy + (w * w * (targetY - f.simY) - 2 * zeta * w * f.vy) * h, -50, 45)
		f.simZ += f.vz * h
		f.simY += f.vy * h
	end

	local bt = now - f.launchedAt
	local blast = bt < f.blastTime and 1 + (f.blastPower - 1) * (1 - bt / f.blastTime) ^ 1.4 or 1
	local speedMul = 1
	if now < f.boostUntil then
		speedMul = Config.Pickups.Ring.boost
	elseif now < f.slowUntil then
		speedMul = Config.Pickups.Obstacle.slow
	end
	local pathY = Config.pathY(pos.X)
	local slope = Config.pathY(pos.X + 1) - pathY
	local vel
	if f.outOfFuel then
		-- slow-motion glide down to the path
		local t = now - f.outOfFuel
		local fall = pos.Y > pathY + 2.5 and (-8 - t * 6) or 0
		f.vz *= math.exp(-dt * 1.5) -- keep drifting the way you were going, slowing down
		vel = Vector3.new(f.speed * math.max(0.08, 0.3 - t * 0.1 + 0.7 * math.exp(-t * 3)), fall, f.vz)
	else
		local speed = f.speed * speedMul * blast
		-- follow the smoothed path exactly (the correction terms pull back any physics drift)
		vel = Vector3.new(speed, slope * speed + f.vy + (pathY + f.simY - pos.Y) * 8, f.vz + (f.simZ - pos.Z) * 8)
	end
	f.thrust.VectorVelocity = vel

	-- Rocket attitude: the nose points where it's heading, it banks into turns (a bit more while the
	-- turn builds up), a gentle cruise wobble, and a full barrel roll on launch / boost rings.
	local accZ = (f.vz - f.lastVz) / math.max(dt, 1 / 240)
	f.lastVz = f.vz
	local targetBank = f.outOfFuel and 0 or math.clamp(f.vz * 0.014 + accZ * 0.003, -0.7, 0.7)
	f.bank += (targetBank - f.bank) * (1 - math.exp(-dt * 8))
	local spinAngle = 0
	if f.spin > 0 then
		f.spin = math.max(0, f.spin - dt * (math.pi * 2 / 0.6))
		spinAngle = (math.pi * 2 - f.spin) % (math.pi * 2)
	end
	local fwd = math.max(20, vel.X)
	local climb = f.outOfFuel and vel.Y * 0.6 or (f.vy + slope * fwd)
	local heading = Vector3.new(fwd, climb * 0.8, vel.Z * 0.6)
	local wobble = f.outOfFuel and 0 or math.sin(now * 3.1) * 0.04
	local targetAim = CFrame.lookAt(Vector3.zero, heading.Unit) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(f.bank + wobble + spinAngle, 0, math.sin(now * 2.3) * 0.025)
	f.aimCF = spinAngle > 0 and targetAim or f.aimCF:Lerp(targetAim, 1 - math.exp(-dt * 12))
	f.align.CFrame = f.aimCF

	-- Flame grows while boosting
	if f.flameFx then
		f.flameFx.Size = (speedMul > 1 or blast > 1.3) and 11 or 6
	end

	-- Rider: holds the handlebar, leans into turns, tucks low on boosts, fist pump through rings,
	-- flails when the engine dies, looks where you steer.
	local boosting = speedMul > 1 or blast > 1.3
	f.boostCam += ((boosting and 1 or 0) - f.boostCam) * (1 - math.exp(-dt * 3))
	if myRider then
		myRider:update(dt, {
			lean = f.outOfFuel and -0.15 or (now - f.launchedAt < 0.9 and -0.25 or f.boostCam * 0.3),
			side = f.bank * 0.45,
			cheer = (boosting and f.spin > 0) and 1 or 0,
			flail = f.outOfFuel and 1 or 0,
			yaw = -math.clamp((aim.z - pos.Z) * 0.03, -0.5, 0.5),
			pitch = math.clamp(f.vy * 0.01, -0.3, 0.3),
			shake = f.outOfFuel and 0.15 or (boosting and 1.6 or 1),
		})
	end

	-- Chase camera: straight behind and a little above, never rolls. It follows only part of your
	-- sideways / up-down moves and eases after them, so the rocket swings across the screen as you
	-- steer while the view stays calm. Distance = your zoom (eased) + a stretch on boosts + launch kick.
	if now > f.pullHold then
		f.pull += (0 - f.pull) * (1 - math.exp(-dt * 1.4))
	end
	local dist = CAM_DIST * camZoom * (f.outOfFuel and 0.9 or 1) * (1 + f.boostCam * 0.15) + f.pull
	local function follow(x, v, target, k)
		local n = math.max(1, math.ceil(dt * 120))
		local hh = dt / n
		for _ = 1, n do
			v += (k * k * (target - x) - 2 * k * v) * hh -- critically damped
			x += v * hh
		end
		return x, v
	end
	local CAM_FOLLOW_SIDE, CAM_FOLLOW_UP, CAM_EASE = 0.85, 0.92, 3.8 -- share of your moves it follows, ease speed
	f.camZ, f.camVZ = follow(f.camZ, f.camVZ, pos.Z * CAM_FOLLOW_SIDE, CAM_EASE)
	f.camY, f.camVY = follow(f.camY, f.camVY, pathY + (pos.Y - pathY) * CAM_FOLLOW_UP, CAM_EASE)
	local base = Vector3.new(pos.X, f.camY + 2, f.camZ)
	f.focus = pos + Vector3.new(0, 2, 0)
	local el = math.atan(0.27) + lookPitch
	local offset = Vector3.new(-math.cos(el) * math.cos(lookYaw), math.sin(el), math.cos(el) * math.sin(lookYaw)) * dist
	local camPos = base + offset
	camPos = Vector3.new(camPos.X, math.max(camPos.Y, Config.pathY(camPos.X) + 2), camPos.Z)
	local ahead = dist * 0.9 * math.max(0, 1 - math.abs(lookYaw))
	-- look mostly straight ahead, turned just a little toward the rocket (and where you steer)
	local lookZ = f.camZ + (pos.Z - f.camZ) * 0.45 + (f.outOfFuel and 0 or (aim.z - pos.Z) * 0.08)
	local lookY = f.camY + 2 + (pos.Y - f.camY) * 0.5 + (f.outOfFuel and 0 or ((f.diving and -4 or aim.y) - (pos.Y - pathY)) * 0.04)
	local chase = CFrame.lookAt(camPos, Vector3.new(pos.X + ahead, lookY, lookZ))
	local fov = (f.outOfFuel and 66 or 70 + math.min(8, f.speed * speedMul * 0.025)) + f.boostCam * 6 + f.pull * 0.4
	camera.FieldOfView += (fov - camera.FieldOfView) * (1 - math.exp(-dt * 4))
	if f.camBlend < 1 then
		f.camBlend = math.min(1, f.camBlend + dt / 0.6)
		local e = 1 - (1 - f.camBlend) ^ 3
		chase = f.camFrom:Lerp(chase, e)
	end
	camera.CFrame = chase * shakeOffset

	-- Landing marker: while you pull down past the bottom, a ring under the nose fills up red with
	-- "LAND" (the rocket itself shows where you steer, so there's no crosshair otherwise).
	if f.outOfFuel then
		reticle.Visible = false
	else
		local ax = pos.X + 8
		local ay = Config.pathY(ax) + (f.diving and 0.5 or math.min(aim.y, f.simY) - 2)
		local sp, onScreen = camera:WorldToViewportPoint(Vector3.new(ax, ay, aim.z))
		reticle.Position = UDim2.fromOffset(sp.X, sp.Y)
		local charge = f.diving and 1 or math.clamp(aim.dive / STEER.diveCharge, 0, 1)
		local show = charge > 0.05 and 1 or 0
		f.reticleAlpha = (f.reticleAlpha or 0) + (show - (f.reticleAlpha or 0)) * (1 - math.exp(-dt * (show > (f.reticleAlpha or 0) and 14 or 3)))
		reticle.Visible = onScreen and f.reticleAlpha > 0.03
		if reticleRing then
			reticleRing.Color = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 70, 70), charge)
			reticleRing.Transparency = 1 - f.reticleAlpha
		end
		local dot = reticle:FindFirstChildOfClass("Frame")
		if dot then
			dot.BackgroundTransparency = 1 - f.reticleAlpha
			local st = dot:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = 1 - f.reticleAlpha
			end
		end
		landLabel.Visible = charge > 0.05
		landLabel.Text = f.diving and "LANDING..." or "▼ LAND"
		landLabel.TextTransparency = 1 - math.max(0.35, charge)
	end

	-- Speed lines
	if not f.outOfFuel then
		lineTimer += dt
		local fast = speedMul > 1 or blast > 1.3
		local interval = fast and 0.015 or 0.04
		while lineTimer > interval do
			lineTimer -= interval
			spawnSpeedLine(fast and 1 or 0.6)
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

-- Other players' riders: the same holding-on pose on your screen, leaning as their rocket swerves.
local otherRiders = {} -- [player] = rider
RunService.RenderStepped:Connect(function(dt)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local r = otherRiders[plr]
			if root and root:FindFirstChild("RideWeld") then
				if r and r.character ~= char then
					r:destroy()
					r = nil
				end
				if not r then
					r = Rider.new(char)
					otherRiders[plr] = r
				end
				if r then
					r:update(dt, { side = math.clamp(root.AssemblyLinearVelocity.Z * 0.008, -0.35, 0.35), shake = 1 })
				end
			elseif r then
				r:destroy()
				otherRiders[plr] = nil
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	if otherRiders[plr] then
		otherRiders[plr]:destroy()
		otherRiders[plr] = nil
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
grade.Saturation = 0.08
grade.Contrast = 0.08
grade.Brightness = 0.02
grade.Parent = Lighting
-- Softer glow: full-strength bloom made white paving and bright parts blinding.
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	bloom.Intensity = 0.35
	bloom.Threshold = 2.4
end
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
