-- Quests window (side-bar QUESTS button) and Settings window (gear button: music, sounds, codes).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local RocketModel = require(ReplicatedStorage.Shared:WaitForChild("RocketModel"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClaimQuest = remotes:WaitForChild("ClaimQuest")
local RedeemCode = remotes:WaitForChild("RedeemCode")
local SetSetting = remotes:WaitForChild("SetSetting")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local abbreviate = Config.abbreviate

local ORANGE = Color3.fromRGB(255, 140, 50)
local GREEN, GREY = Color3.fromRGB(80, 200, 90), Color3.fromRGB(160, 165, 185)
local SLATE = Color3.fromRGB(80, 150, 230)
local INK_SOFT = Color3.fromRGB(70, 70, 100)

-- Quests ---------------------------------------------------------------------------------------
local questBtn = UIKit.button({ Parent = UIKit.sideBar(), LayoutOrder = 0, Icon3D = "Scroll", Icon = "📜", Text = "QUESTS", Color = ORANGE, Size = UDim2.fromOffset(92, 98), Radius = 22 })
local questBadge = UIKit.badge(questBtn.Instance)
local questWindow, questList = UIKit.window("Quests", ORANGE, UDim2.fromOffset(700, 500), "Scroll")

local function questIcon(name)
	if name == "Rocket" then
		return RocketModel.build(Config.getRocket("Turbo"), 1, false, CFrame.new())
	end
	return name
end

local cards = {}
for i, q in ipairs(Config.Quests) do
	local card = UIKit.card(questList, { LayoutOrder = i, Size = UDim2.new(1, -12, 0, 98), ZIndex = 11, Tint = Color3.fromRGB(255, 240, 222) })
	local iconBox = make("Frame", { Parent = card, Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(80, 80), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(20), UIKit.stroke(3), UIKit.gloss(Color3.fromRGB(255, 220, 160)) })
	UIKit.icon3D(iconBox, questIcon(q.icon), { ZIndex = 13, Yaw = q.icon == "Rocket" and 145 or 0 })
	local title = label({ Parent = card, Position = UDim2.fromOffset(102, 10), Size = UDim2.new(1, -300, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local _, setBar = UIKit.bar(card, { Position = UDim2.fromOffset(102, 46), Size = UDim2.new(1, -300, 0, 22), Color = ORANGE, ShowText = true, ZIndex = 12 })
	local tierText = label({ Parent = card, Position = UDim2.fromOffset(102, 70), Size = UDim2.new(1, -300, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
	local rewardPill, rewardText = UIKit.pill(card, { Text = "", Color = GREEN, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(160, 28), ZIndex = 12 })
	local button = UIKit.button({ Parent = card, Text = "", Color = GREY, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -8), Size = UDim2.fromOffset(160, 50), ZIndex = 12 })
	button.Instance.Activated:Connect(function()
		local ok, msg = ClaimQuest:InvokeServer(q.id)
		UIKit.result(ok, msg)
		if ok then
			UIKit.sound("Win", 0.5, 1.2)
			UIKit.bounce(card)
		end
	end)
	cards[q.id] = { q = q, card = card, title = title, setBar = setBar, tierText = tierText, rewardPill = rewardPill, rewardText = rewardText, button = button, order = i }
end

-- distances read best with commas (1,000m), counts abbreviated (2.5K)
local function fmt(q, n)
	if q.text:find("%%sm") then
		return (Config.meters(n):gsub("m$", ""))
	end
	return abbreviate(n)
end

local function refreshQuests()
	local tiers = Config.parseQuestTiers(player:GetAttribute("QuestTiers"))
	local stage = player:GetAttribute("UnlockedStage") or 1
	local any = false
	for id, c in pairs(cards) do
		local q = c.q
		local done = tiers[id] or 0
		local goal = q.goals[done + 1]
		local have = player:GetAttribute(q.stat) or 0
		c.tierText.Text = "Goal " .. math.min(done + 1, #q.goals) .. " of " .. #q.goals
		if not goal then
			c.title.Text = string.format(q.text, fmt(q, q.goals[#q.goals]))
			c.setBar(1, "COMPLETE!")
			c.rewardPill.Visible = false
			c.button.setText("ALL DONE ⭐")
			c.button.setColor(GREY)
			c.card.LayoutOrder = 100 + c.order
		else
			c.title.Text = string.format(q.text, fmt(q, goal))
			c.setBar(have / goal, abbreviate(math.min(have, goal)) .. " / " .. abbreviate(goal))
			c.rewardPill.Visible = true
			c.rewardText.Text = "💰 $" .. abbreviate(Config.questReward(stage, done + 1))
			local ready = have >= goal
			any = any or ready
			c.button.setText(ready and "CLAIM!" or "keep going...")
			c.button.setColor(ready and GREEN or GREY)
			c.card.LayoutOrder = (ready and 0 or 50) + c.order
		end
	end
	questBadge.Visible = any
end

local watched = { "QuestTiers", "UnlockedStage" }
for _, q in ipairs(Config.Quests) do
	table.insert(watched, q.stat)
end
for _, attr in ipairs(watched) do
	player:GetAttributeChangedSignal(attr):Connect(refreshQuests)
end
refreshQuests()
questBtn.Instance.Activated:Connect(function()
	refreshQuests()
	UIKit.toggle(questWindow)
end)

-- Settings -------------------------------------------------------------------------------------
local gearBtn = UIKit.button({ Parent = UIKit.gui(), Icon3D = "Gear", Icon = "⚙️", Text = "", Color = SLATE, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 256), Size = UDim2.fromOffset(70, 70), Radius = 35 })
gearBtn.Instance.Name = "SettingsButton"
UIKit.hudScale(gearBtn.Instance)
local settingsWindow, settingsList = UIKit.window("Settings", SLATE, UDim2.fromOffset(560, 470), "Gear")

local function toggleRow(order, text, attr)
	local r = UIKit.row(settingsList, order, 76)
	label({ Parent = r, Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -220, 1, -28), TextXAlignment = Enum.TextXAlignment.Left, Text = text, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local b = UIKit.button({ Parent = r, Text = "", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(150, 54), ZIndex = 12, Radius = 27 })
	local function refresh()
		local on = player:GetAttribute(attr) ~= false
		b.setText(on and "ON" or "OFF")
		b.setColor(on and GREEN or Color3.fromRGB(235, 90, 90))
	end
	b.Instance.Activated:Connect(function()
		local on = player:GetAttribute(attr) == false
		SetSetting:FireServer(attr, on)
	end)
	player:GetAttributeChangedSignal(attr):Connect(refresh)
	refresh()
end
toggleRow(1, "🎵 Music", "MusicOn")
toggleRow(2, "🔊 Sound effects", "SoundOn")

local codeRow = UIKit.row(settingsList, 3, 150)
label({ Parent = codeRow, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Text = "🎟️ Codes", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
local box = make("TextBox", { Parent = codeRow, Position = UDim2.fromOffset(18, 52), Size = UDim2.new(1, -210, 0, 60), BackgroundColor3 = Color3.fromRGB(240, 244, 255), Font = UIKit.FONT, TextScaled = true, PlaceholderText = "Type a code...", PlaceholderColor3 = Color3.fromRGB(150, 155, 180), Text = "", TextColor3 = UIKit.INK, ClearTextOnFocus = false, ZIndex = 12 }, { UIKit.corner(16), UIKit.stroke(3, Color3.fromRGB(170, 180, 210)), make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }) })
local redeem = UIKit.button({ Parent = codeRow, Text = "REDEEM", Color = GREEN, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 52), Size = UDim2.fromOffset(170, 64), ZIndex = 12 })
local codeHint = label({ Parent = codeRow, Position = UDim2.fromOffset(18, 118), Size = UDim2.new(1, -36, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "Try ROCKET or BLASTOFF!", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
local function redeemCode()
	if box.Text == "" then
		return
	end
	local ok, msg = RedeemCode:InvokeServer(box.Text)
	UIKit.result(ok, msg)
	codeHint.Text = msg
	codeHint.TextColor3 = ok and Color3.fromRGB(40, 160, 70) or Color3.fromRGB(220, 80, 80)
	if ok then
		box.Text = ""
		UIKit.sound("Win", 0.5)
	end
end
redeem.Instance.Activated:Connect(redeemCode)
box.FocusLost:Connect(function(enter)
	if enter then
		redeemCode()
	end
end)

local controls = UIKit.row(settingsList, 4, 118)
label({ Parent = controls, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 1, -20), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 20, TextWrapped = true, Text = "Flying: WASD or hold left-click + drag to steer.  Right-click + move to look around (C = back).  Mouse wheel or I / O to zoom.  On phones: drag to steer, pinch to zoom.", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })

gearBtn.Instance.Activated:Connect(function()
	UIKit.toggle(settingsWindow)
end)

-- the gear hides while flying (like the rest of the lobby buttons)
player:GetAttributeChangedSignal("Flying"):Connect(function()
	gearBtn.Instance.Visible = not player:GetAttribute("Flying")
end)
