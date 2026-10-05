-- Quests window (side-bar QUESTS button) and Settings window (gear button: music, sounds, codes).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local RocketModel = require(ReplicatedStorage.Shared:WaitForChild("RocketModel"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClaimQuest = remotes:WaitForChild("ClaimQuest")
local ClaimMission = remotes:WaitForChild("ClaimMission")
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

-- Daily missions (top of the window): 3 a day, all 3 = a Lucky Spin --------------------------------
local TEAL = Color3.fromRGB(40, 185, 205)
local missionHead = UIKit.row(questList, 0, 52)
make("UIGradient", { Parent = missionHead, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(225, 250, 255), Color3.fromRGB(190, 235, 245)) })
local missionTitle = label({ Parent = missionHead, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(0.55, 0, 1, -12), TextXAlignment = Enum.TextXAlignment.Left, Text = "📅 DAILY MISSIONS", TextColor3 = Color3.fromRGB(20, 120, 140), StrokeThickness = 0, ZIndex = 12 })
local missionTimer = label({ Parent = missionHead, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), Size = UDim2.new(0.42, 0, 1, -20), TextXAlignment = Enum.TextXAlignment.Right, Text = "", TextColor3 = Color3.fromRGB(70, 110, 130), StrokeThickness = 0, ZIndex = 12 })
local missionCards = {}
for i = 1, Config.MISSIONS_PER_DAY do
	local card = UIKit.card(questList, { LayoutOrder = i, Size = UDim2.new(1, -12, 0, 84), ZIndex = 11, Tint = Color3.fromRGB(220, 246, 252), Border = Color3.fromRGB(120, 205, 225) })
	local iconBox = make("Frame", { Parent = card, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(68, 68), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(18), UIKit.stroke(3), UIKit.gloss(Color3.fromRGB(150, 225, 240)) })
	local title = label({ Parent = card, Position = UDim2.fromOffset(90, 8), Size = UDim2.new(1, -290, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local _, setBar = UIKit.bar(card, { Position = UDim2.fromOffset(90, 44), Size = UDim2.new(1, -290, 0, 22), Color = TEAL, ShowText = true, ZIndex = 12 })
	local rewardPill, rewardText = UIKit.pill(card, { Text = "", Color = GREEN, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 6), Size = UDim2.fromOffset(160, 26), ZIndex = 12 })
	local button = UIKit.button({ Parent = card, Text = "", Color = GREY, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -6), Size = UDim2.fromOffset(160, 44), ZIndex = 12 })
	local mc = { card = card, iconBox = iconBox, title = title, setBar = setBar, rewardPill = rewardPill, rewardText = rewardText, button = button, id = nil, icon = nil }
	button.Instance.Activated:Connect(function()
		if not mc.id then
			return
		end
		local ok, msg = ClaimMission:InvokeServer(mc.id)
		UIKit.result(ok, msg)
		if ok then
			UIKit.sound("Jingle", 0.45, 1.25)
			UIKit.bounce(card)
			UIKit.coinBurst(10, button.Instance.AbsolutePosition + button.Instance.AbsoluteSize / 2)
		end
	end)
	missionCards[i] = mc
end
-- time until the next set of missions (new set at 00:00 UTC)
task.spawn(function()
	while true do
		local left = 86400 - (workspace:GetServerTimeNow() % 86400)
		missionTimer.Text = string.format("new in %d:%02d:%02d", left // 3600, (left // 60) % 60, left % 60)
		task.wait(1)
	end
end)
local bonusRow = UIKit.row(questList, 4, 40)
local bonusText = label({ Parent = bonusRow, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 1, -12), Text = "", TextColor3 = Color3.fromRGB(150, 80, 220), StrokeThickness = 0, ZIndex = 12 })
local questHead = UIKit.row(questList, 5, 40)
label({ Parent = questHead, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 1, -12), TextXAlignment = Enum.TextXAlignment.Left, Text = "📜 QUESTS", TextColor3 = Color3.fromRGB(200, 110, 30), StrokeThickness = 0, ZIndex = 12 })

local questsLoaded = false -- (set once your saved data is in: goals done before that don't toast)
local missionReadySeen = {} -- "day:id" already announced
local missionsAny = false
local function refreshMissions()
	local list = Config.parseMissions(player:GetAttribute("Missions"))
	local claimed = string.split(player:GetAttribute("MissionsClaimed") or "", ",")
	local stage = player:GetAttribute("UnlockedStage") or 1
	local day = player:GetAttribute("MissionDay") or 0
	local any, doneCount = false, 0
	for i, mc in ipairs(missionCards) do
		local e = list[i]
		local m = e and Config.getMission(e.id)
		mc.card.Visible = m ~= nil
		if m then
			mc.id = e.id
			if mc.icon ~= m.icon then
				mc.icon = m.icon
				mc.iconBox:ClearAllChildren()
				UIKit.corner(18).Parent = mc.iconBox
				UIKit.stroke(3).Parent = mc.iconBox
				UIKit.gloss(Color3.fromRGB(150, 225, 240)).Parent = mc.iconBox
				UIKit.icon3D(mc.iconBox, questIcon(m.icon), { ZIndex = 13, Yaw = m.icon == "Rocket" and 145 or 0 })
			end
			local have = math.max(0, (player:GetAttribute(m.stat) or 0) - e.start)
			local goalText = m.id == "distance" and (Config.meters(e.goal):gsub("m$", "")) or abbreviate(e.goal)
			mc.title.Text = string.format(m.text, goalText)
			mc.setBar(have / e.goal, abbreviate(math.min(have, e.goal)) .. " / " .. abbreviate(e.goal))
			mc.rewardText.Text = "💰 $" .. abbreviate(Config.missionReward(e.stage or stage))
			local isClaimed = table.find(claimed, e.id) ~= nil
			local ready = not isClaimed and have >= e.goal
			if isClaimed then
				doneCount += 1
				mc.button.setText("✔ DONE")
				mc.button.setColor(GREY)
			elseif ready then
				any = true
				mc.button.setText("CLAIM!")
				mc.button.setColor(GREEN)
				local key = day .. ":" .. e.id
				if not missionReadySeen[key] then
					missionReadySeen[key] = true
					if questsLoaded then
						local text = mc.title.Text
						UIKit.whenFree(function()
							UIKit.toast("📅 Daily mission done: " .. text .. "! Claim it in QUESTS", Color3.fromRGB(120, 230, 255))
							UIKit.sound("Gem", 0.45, 1.3)
							UIKit.bounce(questBtn.Instance)
						end, 0.8)
					end
				end
			else
				mc.button.setText("keep going...")
				mc.button.setColor(GREY)
			end
		end
	end
	bonusText.Text = (doneCount >= #list and #list > 0) and "✔ All 3 missions done: you got a LUCKY SPIN! New missions tomorrow." or ("🎰 Finish all 3 missions for a free LUCKY SPIN!   (" .. doneCount .. " / " .. #list .. ")")
	missionsAny = any
end

local cards = {}
for i, q in ipairs(Config.Quests) do
	local card = UIKit.card(questList, { LayoutOrder = 10 + i, Size = UDim2.new(1, -12, 0, 98), ZIndex = 11, Tint = Color3.fromRGB(255, 240, 222) })
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

local readyBefore = {} -- quest ids that were already claimable (so each one only cheers once)
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
			c.card.LayoutOrder = 300 + c.order
		else
			local text = string.format(q.text, fmt(q, goal))
			if goal == 1 then -- "Launch 1 time", "Hatch 1 egg"
				text = text:gsub("1 times", "1 time"):gsub("1 eggs", "1 egg"):gsub("1 coins", "1 coin"):gsub("1 boost rings", "1 boost ring")
			end
			c.title.Text = text
			c.setBar(have / goal, abbreviate(math.min(have, goal)) .. " / " .. abbreviate(goal))
			c.rewardPill.Visible = true
			c.rewardText.Text = "💰 $" .. abbreviate(Config.questReward(stage, done + 1))
			local ready = have >= goal
			any = any or ready
			-- a goal just got done: say so right away (after a flight, not on top of it)
			local key = id .. ":" .. done
			if ready and not readyBefore[key] then
				readyBefore[key] = true
				if questsLoaded then
					local text = c.title.Text
					UIKit.whenFree(function()
						UIKit.toast("📜 Quest done: " .. text .. "! Claim it in QUESTS", Color3.fromRGB(255, 200, 110))
						UIKit.sound("Gem", 0.45, 1.25)
						UIKit.bounce(questBtn.Instance)
					end, 0.8)
				end
			end
			c.button.setText(ready and "CLAIM!" or "keep going...")
			c.button.setColor(ready and GREEN or GREY)
			c.card.LayoutOrder = (ready and 100 or 200) + c.order
		end
	end
	refreshMissions()
	any = any or missionsAny
	if any and not questBadge.Visible then
		UIKit.bounce(questBadge)
	end
	questBadge.Visible = any
end

local watched = { "QuestTiers", "UnlockedStage", "Missions", "MissionsClaimed", "MissionDay", "StatPerfect" }
for _, q in ipairs(Config.Quests) do
	table.insert(watched, q.stat)
end
for _, attr in ipairs(watched) do
	player:GetAttributeChangedSignal(attr):Connect(refreshQuests)
end
task.spawn(function()
	repeat
		task.wait(0.3)
	until player:GetAttribute("DataLoaded")
	refreshQuests()
	questsLoaded = true -- quests that were already done when you joined don't pop toasts
end)
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
local codeHint = label({ Parent = codeRow, Position = UDim2.fromOffset(18, 118), Size = UDim2.new(1, -36, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "Try ROCKET!  👍 Like the game: new codes at 100 and 500 likes!", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
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

local controls = UIKit.row(settingsList, 4, 150)
label({ Parent = controls, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 1, -20), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 20, TextWrapped = true, Text = "Launch: click / tap in the green for a POWER LAUNCH.  Flying: WASD or hold left-click + drag to steer, hold SPACE to boost (grab coins to charge it).  Right-click + move to look around (C = back).  Mouse wheel or I / O to zoom.  Phones: drag to steer, hold BOOST, pinch to zoom.", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })

gearBtn.Instance.Activated:Connect(function()
	UIKit.toggle(settingsWindow)
end)

-- the gear hides while flying (like the rest of the lobby buttons)
player:GetAttributeChangedSignal("Flying"):Connect(function()
	gearBtn.Instance.Visible = not player:GetAttribute("Flying")
end)
