-- Quest Board (side-bar QUESTS button) and Settings window (gear button: music, sounds, codes).
--   Quest Board: two tabs.
--     DAILY  - 3 daily missions as big cards (icon on sun rays, progress, reward, CLAIM / CLAIMED
--              stamp) + a bonus track: claim all 3 for a free Lucky Spin. New set every day.
--     QUESTS - goal chains: progress bar, a pip per goal in the chain, reward, CLAIM.
--   Claimable buttons pulse with a shine; tabs + the QUESTS button show a red dot.
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
local TEAL = Color3.fromRGB(40, 185, 205)
local GREEN, GREY = Color3.fromRGB(80, 200, 90), Color3.fromRGB(160, 165, 185)
local GOLD = Color3.fromRGB(255, 190, 40)
local SLATE = Color3.fromRGB(80, 150, 230)
local INK_SOFT = Color3.fromRGB(70, 70, 100)

-- Quest Board window -----------------------------------------------------------------------------
local questBtn = UIKit.button({ Parent = UIKit.sideBar(), LayoutOrder = 0, Icon3D = "Scroll", Icon = "📜", Text = "QUESTS", Color = ORANGE, Size = UDim2.fromOffset(92, 98), Radius = 22 })
local questBadge = UIKit.badge(questBtn.Instance)
local questWindow, questList = UIKit.window("Quest Board", ORANGE, UDim2.fromOffset(780, 550), "Scroll")
local tabs = UIKit.tabs(questWindow, questList, {
	{ key = "daily", text = "📅 DAILY", color = TEAL },
	{ key = "quests", text = "📜 QUESTS", color = ORANGE },
})
local dailyTab, questsTab = tabs.frames.daily, tabs.frames.quests

local function questIcon(name)
	if name == "Rocket" then
		return RocketModel.build(Config.getRocket("Turbo"), 1, false, CFrame.new())
	end
	return name
end

-- an icon tile: glossy rounded square, sun rays behind a 3D icon
local function iconTile(parent, color, props)
	local tile = make("Frame", { Parent = parent, Name = "IconTile", AnchorPoint = props.AnchorPoint or Vector2.zero, Position = props.Position, Size = props.Size, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(props.Radius or 20), UIKit.stroke(3.5), UIKit.gloss(color) })
	local rays = make("ImageLabel", { Parent = tile, Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.15, 1.15), BackgroundTransparency = 1, Image = UIKit.PATTERN.rays, ImageTransparency = 0.45, ZIndex = 12 }, { make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local holder = make("Frame", { Parent = tile, Name = "Holder", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 13 })
	return tile, holder, rays
end

local function fmtGoal(id, n)
	if id == "distance" or id == "best" then
		return (Config.meters(n):gsub("m$", ""))
	end
	return abbreviate(n)
end

local function plural(text, goal)
	if goal == 1 then -- "Launch 1 time", "Hatch 1 egg"
		text = text:gsub("1 times", "1 time"):gsub("1 eggs", "1 egg"):gsub("1 coins", "1 coin"):gsub("1 boost rings", "1 boost ring"):gsub("1 PERFECT launches", "1 PERFECT launch")
	end
	return text
end

-- in-progress button text: how far along, as a percent
local function percent(have, goal)
	return math.floor(math.clamp(have / goal, 0, 0.99) * 100) .. "%"
end

-- DAILY tab ------------------------------------------------------------------------------------------
local timerRow = make("Frame", { Parent = dailyTab, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 11 })
local timerChip = make("Frame", { Parent = timerRow, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 38), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(19), UIKit.stroke(3, TEAL) })
local timerText = label({ Parent = timerChip, Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -24, 1, -10), Text = "", TextColor3 = Color3.fromRGB(30, 120, 140), StrokeThickness = 0, ZIndex = 13 })
task.spawn(function()
	while true do
		local left = 86400 - (workspace:GetServerTimeNow() % 86400)
		timerText.Text = string.format("⏰ New missions in %d:%02d:%02d", left // 3600, (left // 60) % 60, left % 60)
		task.wait(1)
	end
end)

local emptyDaily = label({ Parent = dailyTab, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 60), Text = "Getting today's missions...", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12, Visible = false })
local cardRow = make("Frame", { Parent = dailyTab, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 266), BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local missionCards = {}
for i = 1, Config.MISSIONS_PER_DAY do
	local card = UIKit.card(cardRow, { LayoutOrder = i, Size = UDim2.fromOffset(226, 262), ZIndex = 11, Tint = Color3.fromRGB(215, 245, 252), Border = Color3.fromRGB(110, 200, 220) })
	local stroke = card:FindFirstChildOfClass("UIStroke")
	local num = UIKit.pill(card, { Text = "#" .. i, Color = TEAL, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(44, 26), ZIndex = 15 })
	local tile, holder = iconTile(card, Color3.fromRGB(140, 220, 240), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(120, 98), Radius = 24 })
	-- the reward sits on the bottom edge of the icon tile
	local chip, setChip = UIKit.rewardChip(card, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 8, 0, 112), Size = UDim2.fromOffset(140, 34), ZIndex = 14 })
	local title = label({ Parent = card, Position = UDim2.fromOffset(10, 132), Size = UDim2.new(1, -20, 0, 44), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, TextScaled = false, TextSize = 21, TextWrapped = true, ZIndex = 12 })
	local _, setBar = UIKit.bar(card, { Position = UDim2.fromOffset(14, 180), Size = UDim2.new(1, -28, 0, 22), Color = TEAL, ShowText = true, ZIndex = 12 })
	local button = UIKit.button({ Parent = card, Text = "", Color = GREY, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 44), ZIndex = 12, Radius = 18 })
	local stamp = UIKit.stamp(card, "CLAIMED ✔", Color3.fromRGB(60, 175, 75), { Position = UDim2.fromScale(0.5, 0.4), ZIndex = 22 })
	local mc = { card = card, stroke = stroke, num = num, tile = tile, holder = holder, title = title, setBar = setBar, chip = chip, setChip = setChip, button = button, stamp = stamp, id = nil, icon = nil }
	button.Instance.Activated:Connect(function()
		if not mc.id or not mc.ready then
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

-- bonus track: three checkpoints -> Lucky Spin
local bonus = UIKit.card(dailyTab, { LayoutOrder = 3, Size = UDim2.new(1, -8, 0, 84), ZIndex = 11, Tint = Color3.fromRGB(240, 225, 255), Border = Color3.fromRGB(170, 120, 230) })
local bonusText = label({ Parent = bonus, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(0.4, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Text = "🎰 Finish all 3!", TextColor3 = Color3.fromRGB(140, 70, 210), StrokeThickness = 0, ZIndex = 12 })
local bonusSub = label({ Parent = bonus, Position = UDim2.fromOffset(16, 40), Size = UDim2.new(0.4, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 17, TextWrapped = true, Text = "", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
local track = make("Frame", { Parent = bonus, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.44, 0, 0.5, 0), Size = UDim2.new(0.38, 0, 0, 14), BackgroundColor3 = Color3.fromRGB(215, 205, 235), ZIndex = 12 }, { UIKit.corner(7), UIKit.stroke(2.5) })
local trackFill = make("Frame", { Parent = track, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 13 }, { UIKit.corner(7), UIKit.gloss(Color3.fromRGB(170, 100, 240)) })
local checkpoints = {}
for i = 1, 3 do
	local dot = make("Frame", { Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((i - 1) / 2, 0.5), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = Color3.fromRGB(235, 230, 245), ZIndex = 14 }, { UIKit.corner(18), UIKit.stroke(3) })
	checkpoints[i] = { dot = dot, text = label({ Parent = dot, Size = UDim2.fromScale(1, 1), Text = tostring(i), TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 15 }) }
end
local prize, prizeHolder, prizeRays = iconTile(bonus, Color3.fromRGB(200, 150, 255), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(76, 76), Radius = 20 })
UIKit.icon3D(prizeHolder, "Crown", { ZIndex = 13 })

-- QUESTS tab -----------------------------------------------------------------------------------------
local cards = {}
for i, q in ipairs(Config.Quests) do
	local card = UIKit.card(questsTab, { LayoutOrder = 200 + i, Size = UDim2.new(1, -8, 0, 108), ZIndex = 11, Tint = Color3.fromRGB(255, 238, 215), Border = Color3.fromRGB(235, 185, 130) })
	local stroke = card:FindFirstChildOfClass("UIStroke")
	local _, holder = iconTile(card, Color3.fromRGB(255, 210, 150), { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(88, 88) })
	UIKit.icon3D(holder, questIcon(q.icon), { ZIndex = 13, Yaw = q.icon == "Rocket" and 145 or 0 })
	local title = label({ Parent = card, Position = UDim2.fromOffset(110, 8), Size = UDim2.new(1, -310, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local _, setBar = UIKit.bar(card, { Position = UDim2.fromOffset(110, 46), Size = UDim2.new(1, -310, 0, 24), Color = ORANGE, ShowText = true, ZIndex = 12 })
	-- a pip per goal in the chain: done = gold star, current = orange ring, later = grey
	local pipRow = make("Frame", { Parent = card, Position = UDim2.fromOffset(110, 78), Size = UDim2.new(1, -310, 0, 20), BackgroundTransparency = 1, ZIndex = 12 }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local pips = {}
	for g = 1, #q.goals do
		pips[g] = make("Frame", { Parent = pipRow, LayoutOrder = g, Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 13 }, { UIKit.corner(9), UIKit.stroke(2.5) })
	end
	local pipText = label({ Parent = pipRow, LayoutOrder = 99, Size = UDim2.fromOffset(90, 20), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 13 })
	local chip, setChip = UIKit.rewardChip(card, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(160, 36), ZIndex = 12 })
	local button = UIKit.button({ Parent = card, Text = "", Color = GREY, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -8), Size = UDim2.fromOffset(170, 50), ZIndex = 12, Radius = 18 })
	local c = { q = q, card = card, stroke = stroke, title = title, setBar = setBar, pips = pips, pipText = pipText, chip = chip, setChip = setChip, button = button, order = i, ready = false }
	button.Instance.Activated:Connect(function()
		if not c.ready then
			return
		end
		local ok, msg = ClaimQuest:InvokeServer(q.id)
		UIKit.result(ok, msg)
		if ok then
			UIKit.sound("Win", 0.5, 1.2)
			UIKit.bounce(card)
			UIKit.coinBurst(8, button.Instance.AbsolutePosition + button.Instance.AbsoluteSize / 2)
		end
	end)
	cards[q.id] = c
end

-- Refresh ----------------------------------------------------------------------------------------------
local questsLoaded = false -- (set once your saved data is in: goals done before that don't toast)
local missionReadySeen = {} -- "day:id" already announced
local readyBefore = {} -- "quest:tier" already announced
local anyMission, anyQuest = false, false

local function announce(text, color)
	if questsLoaded then
		UIKit.whenFree(function()
			UIKit.toast(text, color)
			UIKit.sound("Gem", 0.45, 1.3)
			UIKit.bounce(questBtn.Instance)
		end, 0.8)
	end
end

local function refreshMissions()
	local list = Config.parseMissions(player:GetAttribute("Missions"))
	local claimed = string.split(player:GetAttribute("MissionsClaimed") or "", ",")
	local stage = player:GetAttribute("UnlockedStage") or 1
	local day = player:GetAttribute("MissionDay") or 0
	local any, doneCount = false, 0
	emptyDaily.Visible = #list == 0
	cardRow.Visible = #list > 0
	for i, mc in ipairs(missionCards) do
		local e = list[i]
		local m = e and Config.getMission(e.id)
		mc.card.Visible = m ~= nil
		if m then
			mc.id = e.id
			if mc.icon ~= m.icon then
				mc.icon = m.icon
				mc.holder:ClearAllChildren()
				UIKit.icon3D(mc.holder, questIcon(m.icon), { ZIndex = 13, Yaw = m.icon == "Rocket" and 145 or 0 })
			end
			local have = math.max(0, (player:GetAttribute(m.stat) or 0) - e.start)
			mc.title.Text = plural(string.format(m.text, fmtGoal(m.id, e.goal)), e.goal)
			mc.setBar(have / e.goal, abbreviate(math.min(have, e.goal)) .. " / " .. abbreviate(e.goal))
			mc.setChip("$" .. abbreviate(Config.missionReward(e.stage or stage)))
			local isClaimed = table.find(claimed, e.id) ~= nil
			local ready = not isClaimed and have >= e.goal
			mc.ready = ready
			mc.stamp.Visible = isClaimed
			mc.chip.Visible = not isClaimed
			UIKit.claimable(mc.button, ready)
			mc.stroke.Color = ready and GOLD or (isClaimed and Color3.fromRGB(120, 200, 130) or Color3.fromRGB(110, 200, 220))
			mc.stroke.Thickness = ready and 5 or 3
			if isClaimed then
				doneCount += 1
				mc.button.setText("✔ DONE")
				mc.button.setColor(Color3.fromRGB(120, 200, 130))
			elseif ready then
				any = true
				mc.button.setText("CLAIM!")
				local key = day .. ":" .. e.id
				if not missionReadySeen[key] then
					missionReadySeen[key] = true
					announce("📅 Daily mission done: " .. mc.title.Text .. "! Claim it in QUESTS", Color3.fromRGB(120, 230, 255))
				end
			else
				mc.button.setText(percent(have, e.goal))
				mc.button.setColor(GREY)
			end
		end
	end
	-- bonus track
	local total = math.max(1, #list)
	trackFill.Size = UDim2.fromScale(math.clamp((doneCount - 1) / 2, 0, 1), 1)
	trackFill.Visible = doneCount >= 2
	for i, cp in ipairs(checkpoints) do
		local done = i <= doneCount
		cp.dot.BackgroundColor3 = done and Color3.fromRGB(170, 100, 240) or Color3.fromRGB(235, 230, 245)
		cp.text.Text = done and "✔" or tostring(i)
		cp.text.TextColor3 = done and Color3.new(1, 1, 1) or INK_SOFT
	end
	local allDone = #list > 0 and doneCount >= total
	bonusText.Text = allDone and "🎰 Bonus won!" or "🎰 Finish all 3!"
	bonusSub.Text = allDone and "Your spin is waiting in SPIN!" or ("All 3 = a free LUCKY SPIN  (" .. doneCount .. "/" .. #list .. ")")
	prizeRays.ImageTransparency = allDone and 0.1 or 0.6
	anyMission = any
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
		for g, pip in ipairs(c.pips) do
			local isDone, isCurrent = g <= done, g == done + 1
			pip.BackgroundColor3 = isDone and GOLD or (isCurrent and Color3.fromRGB(255, 225, 180) or Color3.fromRGB(225, 225, 235))
			pip:FindFirstChildOfClass("UIStroke").Color = isCurrent and ORANGE or UIKit.INK
		end
		if not goal then
			c.title.Text = string.format(q.text, fmtGoal(q.id, q.goals[#q.goals]))
			c.setBar(1, "MAXED!")
			c.pipText.Text = "all " .. #q.goals .. " done"
			c.chip.Visible = false
			c.ready = false
			UIKit.claimable(c.button, false)
			c.button.setText("⭐ COMPLETE")
			c.button.setColor(GOLD)
			c.stroke.Color = GOLD
			c.stroke.Thickness = 3
			c.card.LayoutOrder = 300 + c.order
		else
			c.title.Text = plural(string.format(q.text, fmtGoal(q.id, goal)), goal)
			c.setBar(have / goal, abbreviate(math.min(have, goal)) .. " / " .. abbreviate(goal))
			c.pipText.Text = "goal " .. (done + 1) .. " of " .. #q.goals
			c.chip.Visible = true
			c.setChip("$" .. abbreviate(Config.questReward(stage, done + 1)))
			local ready = have >= goal
			c.ready = ready
			any = any or ready
			UIKit.claimable(c.button, ready)
			c.button.setText(ready and "CLAIM!" or percent(have, goal))
			if not ready then
				c.button.setColor(GREY)
			end
			c.stroke.Color = ready and GOLD or Color3.fromRGB(235, 185, 130)
			c.stroke.Thickness = ready and 5 or 3
			c.card.LayoutOrder = (ready and 100 or 200) + c.order
			local key = id .. ":" .. done
			if ready and not readyBefore[key] then
				readyBefore[key] = true
				announce("📜 Quest done: " .. c.title.Text .. "! Claim it in QUESTS", Color3.fromRGB(255, 200, 110))
			end
		end
	end
	anyQuest = any
end

local function refreshAll()
	refreshQuests()
	refreshMissions()
	tabs.badge("daily", anyMission)
	tabs.badge("quests", anyQuest)
	local any = anyMission or anyQuest
	if any and not questBadge.Visible then
		UIKit.bounce(questBadge)
	end
	questBadge.Visible = any
end

local watched = { "QuestTiers", "UnlockedStage", "Missions", "MissionsClaimed", "MissionDay", "StatPerfect" }
for _, q in ipairs(Config.Quests) do
	table.insert(watched, q.stat)
end
for _, m in ipairs(Config.Missions) do
	if not table.find(watched, m.stat) then
		table.insert(watched, m.stat)
	end
end
for _, attr in ipairs(watched) do
	player:GetAttributeChangedSignal(attr):Connect(refreshAll)
end
task.spawn(function()
	repeat
		task.wait(0.3)
	until player:GetAttribute("DataLoaded")
	refreshAll()
	questsLoaded = true -- quests that were already done when you joined don't pop toasts
end)
refreshAll()
questBtn.Instance.Activated:Connect(function()
	refreshAll()
	-- open on the tab with something to claim
	if not questWindow.Visible then
		tabs.select((anyMission or not anyQuest) and "daily" or "quests")
	end
	UIKit.toggle(questWindow)
end)

-- Settings -------------------------------------------------------------------------------------
-- the gear sits just left of the stage card (it scales with it, and stays clear of the phone jump button)
local stageCard = UIKit.gui():WaitForChild("StageCard", 10)
local gearBtn = UIKit.button({ Parent = stageCard or UIKit.gui(), Icon3D = "Gear", Icon = "⚙️", Text = "", Color = SLATE, AnchorPoint = Vector2.new(1, 0), Position = stageCard and UDim2.fromOffset(-8, 0) or UDim2.new(1, -14, 0, 264), Size = UDim2.fromOffset(64, 64), Radius = 32 })
gearBtn.Instance.Name = "SettingsButton"
if not stageCard then
	UIKit.hudScale(gearBtn.Instance)
end
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
