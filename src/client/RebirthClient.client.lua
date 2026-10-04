-- Rebirth (client): the window at the Rebirth Portal (walk up, press E), a rebirth badge on the HUD
-- and the celebration when you rebirth. The server does the actual reset (GameServer "Rebirth").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local RebirthRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local PURPLE = Color3.fromRGB(165, 105, 245)
local GOLD = Color3.fromRGB(255, 190, 40)
local GREEN = Color3.fromRGB(80, 200, 90)
local GREY = Color3.fromRGB(160, 165, 185)
local INK_SOFT = Color3.fromRGB(70, 70, 100)

local function rebirths()
	return player:GetAttribute("Rebirths") or 0
end

-- Window ------------------------------------------------------------------------------------------
local window, list = UIKit.window("Rebirth", PURPLE, UDim2.fromOffset(640, 460), "Trophy")

local headRow = UIKit.row(list, 1, 52)
local headText = label({ Parent = headRow, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 1, -12), Text = "", TextColor3 = UIKit.darker(PURPLE, 0.25), StrokeThickness = 0, ZIndex = 12 })

local needRow = UIKit.row(list, 2, 64)
local needText = label({ Parent = needRow, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 26), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
local barBack = make("Frame", { Parent = needRow, Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 16), BackgroundColor3 = Color3.fromRGB(220, 225, 240), ZIndex = 12 }, { UIKit.corner(8) })
local barFill = make("Frame", { Parent = barBack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = PURPLE, ZIndex = 13 }, { UIKit.corner(8) })

local getRow = UIKit.row(list, 3, 58)
label({ Parent = getRow, Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "You get:", TextColor3 = Color3.fromRGB(40, 170, 70), StrokeThickness = 0, ZIndex = 12 })
local getText = label({ Parent = getRow, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })

local keepRow = UIKit.row(list, 4, 58)
label({ Parent = keepRow, Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "Starts over: money, stages, rockets, upgrades", TextColor3 = Color3.fromRGB(220, 90, 90), StrokeThickness = 0, ZIndex = 12 })
label({ Parent = keepRow, Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "You keep: your pets and trails", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })

local buttonRow = make("Frame", { Parent = list, LayoutOrder = 5, Size = UDim2.new(1, -12, 0, 66), BackgroundTransparency = 1, ZIndex = 11 })
local rebirthBtn = UIKit.button({ Parent = buttonRow, Text = "", Color = GREEN, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.7, 0, 0, 60), ZIndex = 12 })

local armedAt = 0 -- first click arms, second click (within 3 s) rebirths

local function refresh()
	local n = rebirths()
	local need = Config.rebirthStage(n)
	local stage = player:GetAttribute("UnlockedStage") or 1
	local ready = stage >= need
	headText.Text = "Rebirth " .. n .. "  →  " .. (n + 1)
	needText.Text = (ready and "✅ " or "🔒 ") .. "Unlock Stage " .. need .. "   (you're on Stage " .. stage .. ")"
	barFill.Size = UDim2.fromScale(math.clamp(stage / need, 0.03, 1), 1)
	local slotsNow, slotsNext = Config.petSlots(n), Config.petSlots(n + 1)
	getText.Text = "💰 x" .. Config.rebirthMultiplier(n + 1) .. " money forever (now x" .. Config.rebirthMultiplier(n) .. ")"
		.. (slotsNext > slotsNow and ("   🐾 " .. slotsNow .. " → " .. slotsNext .. " pet slots") or "")
	if not ready then
		rebirthBtn.setText("Unlock Stage " .. need .. " first")
		rebirthBtn.setColor(GREY)
	elseif os.clock() - armedAt < 3 then
		rebirthBtn.setText("Sure? Click again!")
		rebirthBtn.setColor(Color3.fromRGB(255, 150, 40))
	else
		rebirthBtn.setText("🌟 REBIRTH!")
		rebirthBtn.setColor(GREEN)
	end
end

-- Celebration -------------------------------------------------------------------------------------
local gui = UIKit.gui()
local function celebrate(n)
	local flash = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 240, 255), BackgroundTransparency = 0, ZIndex = 70 })
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(flash, 1)
	local title = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(640, 110), Text = "🌟 REBIRTH " .. n .. "! 🌟", TextColor3 = GOLD, StrokeThickness = 5, ZIndex = 72 })
	local sub = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(560, 44), Text = "Money x" .. Config.rebirthMultiplier(n) .. " forever!", TextColor3 = Color3.fromRGB(150, 255, 150), StrokeThickness = 3, ZIndex = 72 })
	UIKit.bounce(title)
	UIKit.sound("Win", 0.9, 1.1)
	-- confetti
	local colors = { GOLD, PURPLE, Color3.fromRGB(255, 120, 190), Color3.fromRGB(90, 200, 255), Color3.fromRGB(130, 230, 110) }
	for i = 1, 60 do
		local c = make("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(math.random(), -0.05), Size = UDim2.fromOffset(math.random(10, 18), math.random(6, 10)), BackgroundColor3 = colors[i % #colors + 1], Rotation = math.random(0, 360), BorderSizePixel = 0, ZIndex = 71 })
		local t = 1.6 + math.random() * 1.4
		TweenService:Create(c, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(c.Position.X.Scale + (math.random() - 0.5) * 0.3, 1.1),
			Rotation = c.Rotation + math.random(-540, 540),
		}):Play()
		game:GetService("Debris"):AddItem(c, t + 0.1)
	end
	task.delay(2.6, function()
		for _, l in ipairs({ title, sub }) do
			TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			local st = l:FindFirstChildOfClass("UIStroke")
			if st then
				TweenService:Create(st, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.6)
		title:Destroy()
		sub:Destroy()
	end)
end

rebirthBtn.Instance.Activated:Connect(function()
	local n = rebirths()
	if (player:GetAttribute("UnlockedStage") or 1) < Config.rebirthStage(n) then
		UIKit.result(false, "Unlock Stage " .. Config.rebirthStage(n) .. " to rebirth!")
		return
	end
	if os.clock() - armedAt > 3 then
		armedAt = os.clock()
		refresh()
		task.delay(3.1, refresh)
		return
	end
	armedAt = 0
	local ok, msg = RebirthRemote:InvokeServer()
	if ok then
		window.Visible = false
		celebrate(n + 1) -- (the attribute may not have arrived yet)
	else
		UIKit.result(false, msg)
	end
	refresh()
end)

-- HUD badge (lobby only): your rebirths and their money bonus ------------------------------------
local badge = make("Frame", { Parent = gui, Name = "RebirthBadge", Position = UDim2.fromOffset(256, 139), Size = UDim2.fromOffset(170, 44), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, { UIKit.corner(22), UIKit.stroke(3.5), UIKit.gloss(PURPLE) })
local badgeText = label({ Parent = badge, Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -24, 1, -10), Text = "", StrokeThickness = 3 })
local function refreshBadge()
	local n = rebirths()
	badge.Visible = n > 0 and not player:GetAttribute("Flying")
	badgeText.Text = "🌟 " .. n .. "  •  x" .. Config.rebirthMultiplier(n)
end

for _, attr in ipairs({ "Rebirths", "UnlockedStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		refresh()
		refreshBadge()
	end)
end
player:GetAttributeChangedSignal("Flying"):Connect(refreshBadge)
refresh()
refreshBadge()

-- Open at the portal, close when you walk away -----------------------------------------------------
local openedAt = nil
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute("OpenWindow") == "Rebirth" and not window.Visible then
		refresh()
		UIKit.toggle(window)
		openedAt = prompt.Parent
	end
end)
RunService.Heartbeat:Connect(function()
	if not openedAt then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not window.Visible then
		openedAt = nil
	elseif root and openedAt.Parent and (root.Position - openedAt.Position).Magnitude > 24 then
		window.Visible = false
		openedAt = nil
	end
end)
