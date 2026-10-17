-- First flight only: a big "how to steer" panel near the top of the screen, because new players
-- either only tap W / A / S / D or don't steer at all. It shows a mouse with the left button held
-- sliding left / right (or a finger dragging on phones, the stick on a gamepad), stays until you've
-- actually steered that way for a moment (or the flight ends), then says "Nice!" and goes away.
-- StatFlights is saved, so it never shows again after the first flight.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local gui = UIKit.gui()

local function device()
	if UserInputService.GamepadEnabled and not UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		return "pad"
	elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return "touch"
	end
	return "mouse"
end

-- the panel ----------------------------------------------------------------------------------
local panel = make("Frame", { Parent = gui, Name = "SteerTutorial", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 250), Size = UDim2.fromOffset(560, 150), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 60 }, {
	UIKit.corner(26),
	UIKit.stroke(5),
	UIKit.gloss(Color3.fromRGB(60, 140, 255)),
})
UIKit.hudScale(panel)
local title = label({ Parent = panel, Position = UDim2.fromOffset(170, 18), Size = UDim2.new(1, -190, 0, 56), Text = "", TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 4, ZIndex = 62 })
local sub = label({ Parent = panel, Position = UDim2.fromOffset(170, 78), Size = UDim2.new(1, -190, 0, 54), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 240, 150), StrokeThickness = 3, ZIndex = 62 })

-- the animated picture: a mouse (left button lit) / a finger / a stick, sliding left and right
local pic = make("Frame", { Parent = panel, Position = UDim2.fromOffset(18, 15), Size = UDim2.fromOffset(140, 120), BackgroundColor3 = Color3.fromRGB(25, 45, 100), BackgroundTransparency = 0.35, ZIndex = 61 }, { UIKit.corner(20) })
local arrows = label({ Parent = pic, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.85), Size = UDim2.fromOffset(130, 30), Text = "◀          ▶", TextColor3 = Color3.fromRGB(255, 230, 90), StrokeThickness = 2.5, ZIndex = 62 })
local mouse = make("Frame", { Parent = pic, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(46, 66), BackgroundColor3 = Color3.fromRGB(245, 245, 250), ZIndex = 63 }, {
	UIKit.corner(23),
	UIKit.stroke(3),
})
local leftButton = make("Frame", { Parent = mouse, Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(19, 26), BackgroundColor3 = Color3.fromRGB(255, 90, 60), ZIndex = 64 }, { UIKit.corner(10) })
make("Frame", { Parent = mouse, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(3, 22), BackgroundColor3 = Color3.fromRGB(60, 60, 70), BorderSizePixel = 0, ZIndex = 65 })
local finger = label({ Parent = pic, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(64, 64), Text = "👆", StrokeThickness = 0, ZIndex = 63, Visible = false })
local stick = label({ Parent = pic, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(64, 64), Text = "🕹️", StrokeThickness = 0, ZIndex = 63, Visible = false })

-- state ----------------------------------------------------------------------------------------
local active = false
local steered = 0 -- seconds of real steering seen
local holding = false -- left mouse button down (during the tutorial)

local function hide(nice)
	if not active then
		return
	end
	active = false
	if nice then
		title.Text = "NICE! 🎉"
		sub.Text = "You've got it - keep steering like that!"
		UIKit.sound("Gem", 0.5, 1.2)
		UIKit.bounce(panel)
		task.wait(1.6)
	end
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -200) }):Play()
	task.wait(0.4)
	panel.Visible = false
end

local function show()
	local kind = device()
	mouse.Visible = kind == "mouse"
	finger.Visible = kind == "touch"
	stick.Visible = kind == "pad"
	if kind == "touch" then
		title.Text = "DRAG YOUR FINGER TO STEER!"
		sub.Text = "Keep your finger on the screen and slide it around"
	elseif kind == "pad" then
		title.Text = "USE THE LEFT STICK TO STEER!"
		sub.Text = "Push it left, right, up and down"
	else
		title.Text = "HOLD LEFT-CLICK + MOVE YOUR MOUSE!"
		sub.Text = "That's how you steer - it's much smoother than W A S D"
	end
	steered = 0
	active = true
	panel.Position = UDim2.new(0.5, 0, 0, -200)
	panel.Visible = true
	TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 250) }):Play()
	UIKit.sound("Pop", 0.5, 1)
end

-- count real steering: mouse moved while the left button is held, a finger dragging, or the stick
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = false
	end
end)
local moved = 0 -- movement this frame
local lastPos = nil -- (some mice / trackpads only report positions, not movement)
UserInputService.InputChanged:Connect(function(input)
	local t = input.UserInputType
	local d = Vector2.new(input.Delta.X, input.Delta.Y)
	if t == Enum.UserInputType.MouseMovement then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if d.Magnitude == 0 and lastPos then
			d = pos - lastPos
		end
		lastPos = pos
	end
	if not active then
		return
	end
	if t == Enum.UserInputType.MouseMovement and holding then
		moved += d.Magnitude
	elseif t == Enum.UserInputType.Touch then
		moved += Vector2.new(input.Delta.X, input.Delta.Y).Magnitude
	elseif input.KeyCode == Enum.KeyCode.Thumbstick1 and Vector2.new(input.Position.X, input.Position.Y).Magnitude > 0.4 then
		moved += 5
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not active then
		moved = 0
		return
	end
	-- the picture slides left and right, the left button glows while "held"
	local t = os.clock()
	local x = math.sin(t * 2.6) * 0.22
	mouse.Position = UDim2.fromScale(0.5 + x, 0.42)
	finger.Position = UDim2.fromScale(0.5 + x, 0.42)
	stick.Position = UDim2.fromScale(0.5 + x * 0.4, 0.42)
	leftButton.BackgroundTransparency = 0.15 + math.abs(math.sin(t * 5)) * 0.35
	arrows.TextTransparency = 0.2 + math.abs(math.sin(t * 2.6)) * 0.5
	if moved > 2 then
		steered += dt
	end
	moved = 0
	if steered > 1.2 then
		task.spawn(hide, true)
	end
end)

-- first flight only: show it right after liftoff, hide when the flight ends
player:GetAttributeChangedSignal("Flying"):Connect(function()
	if player:GetAttribute("Flying") then
		if (player:GetAttribute("StatFlights") or 0) == 0 then
			task.delay(3.8, function() -- (after the 3-2-1 countdown and the cannon blast)
				if player:GetAttribute("Flying") and (player:GetAttribute("StatFlights") or 0) == 0 then
					show()
				end
			end)
		end
	else
		task.spawn(hide, false)
	end
end)
