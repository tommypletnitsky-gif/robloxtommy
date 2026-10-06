-- Side bar: free timed gifts and the daily reward. (Donations live in the Store window: StoreClient.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClaimGift = remotes:WaitForChild("ClaimGift")
local ClaimDaily = remotes:WaitForChild("ClaimDaily")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local abbreviate = Config.abbreviate
local side = UIKit.sideBar()

local PINK, GOLD = Color3.fromRGB(255, 110, 170), Color3.fromRGB(255, 180, 40)
local giftsBtn = UIKit.button({ Parent = side, LayoutOrder = 1, Icon3D = "Gift", Text = "GIFTS", Color = PINK, Size = UDim2.fromOffset(92, 98), Radius = 22 })
local dailyBtn = UIKit.button({ Parent = side, LayoutOrder = 2, Icon3D = "Calendar", Text = "DAILY", Color = GOLD, Size = UDim2.fromOffset(92, 98), Radius = 22 })
local giftBadge = UIKit.badge(giftsBtn.Instance)
local dailyBadge = UIKit.badge(dailyBtn.Instance)

-- server clock (JoinedAt / LastDaily are the server's os.time()), so a wrong PC clock can't skew the timers
local function now()
	return math.floor(workspace:GetServerTimeNow())
end

local function stage()
	return player:GetAttribute("UnlockedStage") or 1
end

-- Gifts --------------------------------------------------------------------------------------
-- A grid of presents. Ready ones sit on turning sun rays with a pulsing OPEN! button; waiting
-- ones show a grey timer; opened ones get a green check stamp.
local GREEN, GREY = Color3.fromRGB(80, 200, 90), Color3.fromRGB(160, 165, 185)
local giftsWindow, giftsList = UIKit.window("Free Gifts", PINK, UDim2.fromOffset(680, 530), "Gift")
local giftHead = make("Frame", { Parent = giftsList, LayoutOrder = 0, Size = UDim2.new(1, -12, 0, 40), BackgroundTransparency = 1, ZIndex = 11 })
local _, giftHeadText = UIKit.pill(giftHead, { Text = "", Color = UIKit.darker(PINK, 0.1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(470, 36), ZIndex = 12 })
local grid = make("Frame", { Parent = giftsList, LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIGridLayout", { CellSize = UDim2.fromOffset(116, 170), CellPadding = UDim2.fromOffset(10, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local giftCells = {}
for i, minutes in ipairs(Config.GiftMinutes) do
	local cell = UIKit.card(grid, { LayoutOrder = i, ZIndex = 11, Tint = Color3.fromRGB(255, 228, 242) })
	local rays = UIKit.rays(cell, { Position = UDim2.fromOffset(58, 42), Size = UDim2.fromOffset(130, 130), Color = Color3.fromRGB(255, 200, 80), ZIndex = 11 })
	local iconBox = make("Frame", { Parent = cell, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 72), BackgroundTransparency = 1, ZIndex = 12 })
	local vp = UIKit.icon3D(iconBox, "Gift", { ZIndex = 12 })
	local reward = label({ Parent = cell, Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 0, 26), Text = "", TextColor3 = Color3.fromRGB(60, 170, 80), StrokeThickness = 0, ZIndex = 12 })
	local btn = UIKit.button({ Parent = cell, Text = "", Color = GREY, Position = UDim2.fromOffset(8, 110), Size = UDim2.new(1, -16, 0, 50), ZIndex = 12, Radius = 14 })
	btn.Instance.Name = "Gift" .. i
	local opened = UIKit.pill(cell, { Text = "OPENED", Color = GREEN, Position = UDim2.fromOffset(12, 116), Size = UDim2.new(1, -24, 0, 34), ZIndex = 12 })
	local check = make("Frame", { Parent = cell, Name = "Check", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(58, 42), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = GREEN, Rotation = -10, ZIndex = 14 }, { UIKit.corner(26), UIKit.stroke(3.5) })
	label({ Parent = check, Size = UDim2.fromScale(1, 1), Text = "✔", ZIndex = 15 })
	btn.Instance.Activated:Connect(function()
		local ok, msg = ClaimGift:InvokeServer(i)
		UIKit.result(ok, msg)
	end)
	giftCells[i] = { minutes = minutes, reward = reward, btn = btn, rays = rays, vp = vp, opened = opened, check = check, stroke = cell:FindFirstChildOfClass("UIStroke") }
end

local function refreshGifts()
	local played = now() - (player:GetAttribute("JoinedAt") or now())
	local claimed = string.split(player:GetAttribute("GiftsClaimed") or "", ",")
	local anyReady, openedCount, nextLeft = false, 0, nil
	for i, c in ipairs(giftCells) do
		c.reward.Text = "$" .. abbreviate(Config.giftReward(stage(), i))
		local isOpened = table.find(claimed, tostring(i)) ~= nil
		local left = c.minutes * 60 - played
		local ready = not isOpened and left <= 0
		c.btn.Instance.Visible = not isOpened
		c.opened.Visible = isOpened
		c.check.Visible = isOpened
		c.vp.ImageTransparency = isOpened and 0.55 or 0
		c.rays.Visible = ready
		c.stroke.Color = ready and Color3.fromRGB(255, 170, 30) or Color3.fromRGB(190, 200, 225)
		c.stroke.Thickness = ready and 4.5 or 3
		UIKit.claimable(c.btn, ready)
		if isOpened then
			openedCount += 1
		elseif ready then
			anyReady = true
			c.btn.setText("OPEN!")
		else
			c.btn.setText(string.format("⏰ %d:%02d", left // 60, left % 60))
			c.btn.setColor(GREY)
			nextLeft = nextLeft and math.min(nextLeft, left) or left
		end
	end
	if anyReady then
		giftHeadText.Text = "🎁 A gift is ready! Open it!   (" .. openedCount .. "/" .. #giftCells .. ")"
	elseif nextLeft then
		giftHeadText.Text = string.format("⏰ Next gift in %d:%02d  •  stay in the game!   (%d/%d)", nextLeft // 60, nextLeft % 60, openedCount, #giftCells)
	else
		giftHeadText.Text = "⭐ All gifts opened! New ones next time you join"
	end
	giftBadge.Visible = anyReady
	-- the side button counts down to the next gift
	giftsBtn.setText((not anyReady and nextLeft) and string.format("%d:%02d", nextLeft // 60, nextLeft % 60) or "GIFTS")
end

-- Daily reward --------------------------------------------------------------------------------
-- 7 day cards (one week; the streak keeps going into Week 2, 3...): claimed days dimmed with a
-- green check, today's card bigger on turning gold rays with a TODAY tag, day 7 a big gift with a
-- free pet. Streak pill on top; the button pulses when it's ready.
local dailyWindow, dailyList = UIKit.window("Daily Reward", GOLD, UDim2.fromOffset(720, 430), "Calendar")
local streakRow = make("Frame", { Parent = dailyList, LayoutOrder = 0, Size = UDim2.new(1, -12, 0, 40), BackgroundTransparency = 1, ZIndex = 11 })
local _, streakText = UIKit.pill(streakRow, { Text = "", Color = Color3.fromRGB(255, 120, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(540, 36), ZIndex = 12 })
local dayRow = make("Frame", { Parent = dailyList, LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 190), BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local dayCells = {}
for d = 1, 7 do
	local big = d == 7
	local cell = UIKit.card(dayRow, { LayoutOrder = d, Size = UDim2.fromOffset(big and 104 or 82, big and 164 or 144), ZIndex = 11, Tint = big and Color3.fromRGB(255, 236, 190) or Color3.fromRGB(240, 244, 255) })
	local scale = make("UIScale", { Parent = cell })
	local rays = UIKit.rays(cell, { Position = UDim2.new(0.5, 0, 0, big and 66 or 60), Size = UDim2.fromOffset(150, 150), Color = Color3.fromRGB(255, 190, 40), ZIndex = 11 })
	label({ Parent = cell, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 24), Text = "Day " .. d, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local iconBox = make("Frame", { Parent = cell, Position = UDim2.fromOffset(4, 32), Size = UDim2.new(1, -8, 0, big and 78 or 62), BackgroundTransparency = 1, ZIndex = 12 })
	local vp = UIKit.icon3D(iconBox, big and "Gift" or "Coin", { ZIndex = 12 })
	local amount = label({ Parent = cell, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 2, 1, -10), Size = UDim2.new(1, -4, 0, 26), Text = "", TextColor3 = Color3.fromRGB(60, 170, 80), StrokeThickness = 0, ZIndex = 12 })
	local today = UIKit.pill(cell, { Text = "TODAY", Color = Color3.fromRGB(255, 120, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -11), Size = UDim2.fromOffset(78, 26), ZIndex = 14 })
	local check = make("Frame", { Parent = cell, Name = "Check", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = GREEN, Rotation = -10, ZIndex = 14 }, { UIKit.corner(24), UIKit.stroke(3.5) })
	label({ Parent = check, Size = UDim2.fromScale(1, 1), Text = "✔", ZIndex = 15 })
	dayCells[d] = { cell = cell, scale = scale, rays = rays, vp = vp, amount = amount, today = today, check = check, stroke = cell:FindFirstChildOfClass("UIStroke"), grad = cell:FindFirstChildOfClass("UIGradient"), big = big }
end
local dailyClaim = UIKit.button({ Parent = dailyList, LayoutOrder = 2, Text = "CLAIM!", Color = GREEN, Size = UDim2.fromOffset(330, 72), Radius = 24 })
dailyClaim.Instance.Name = "DailyClaim"
dailyClaim.Instance.Activated:Connect(function()
	local ok, msg = ClaimDaily:InvokeServer()
	UIKit.result(ok, msg)
	if ok then
		UIKit.sound("Win", 0.6)
	end
end)

local function dailyReady()
	return now() - (player:GetAttribute("LastDaily") or 0) >= 20 * 3600
end

local function refreshDaily()
	local last = player:GetAttribute("LastDaily") or 0
	local streak = player:GetAttribute("DailyStreak") or 0
	local ready = dailyReady()
	local nextDay = ready and ((now() - last < 48 * 3600) and streak + 1 or 1) or streak
	-- the calendar cycles by week: day 8 is Week 2 Day 1 (cards show what the server pays)
	local week = math.floor((math.max(nextDay, 1) - 1) / 7) + 1
	local today = ((math.max(nextDay, 1) - 1) % 7) + 1
	for d, c in ipairs(dayCells) do
		c.amount.Text = "$" .. abbreviate(Config.dailyReward(stage(), (week - 1) * 7 + d)) .. (c.big and " + 🥚" or "")
		local isToday = d == today
		-- claimed days: everything before today, and today itself once it's been claimed
		local claimed = d < today or (not ready and d == today)
		local glowing = isToday and ready
		c.check.Visible = claimed
		c.vp.ImageTransparency = claimed and 0.5 or 0
		c.today.Visible = isToday
		c.rays.Visible = glowing
		c.scale.Scale = glowing and 1.08 or 1
		c.stroke.Color = glowing and Color3.fromRGB(255, 150, 20) or claimed and Color3.fromRGB(110, 200, 120) or Color3.fromRGB(190, 200, 225)
		c.stroke.Thickness = glowing and 5 or 3
		c.grad.Color = ColorSequence.new(Color3.new(1, 1, 1), claimed and Color3.fromRGB(215, 245, 215) or c.big and Color3.fromRGB(255, 236, 190) or Color3.fromRGB(240, 244, 255))
	end
	local shown = ready and nextDay - 1 or streak
	streakText.Text = shown > 0 and ("🔥 " .. shown .. " day streak • WEEK " .. week .. "  •  Day 7 = FREE PET") or "🔥 Come back every day: Day 7 = FREE PET"
	UIKit.claimable(dailyClaim, ready)
	if ready then
		dailyClaim.setText("CLAIM DAY " .. today .. "!")
	else
		local left = 20 * 3600 - (now() - last)
		dailyClaim.setText(string.format("⏰ Next in %d:%02d:%02d", left // 3600, (left // 60) % 60, left % 60))
		dailyClaim.setColor(GREY)
	end
	dailyBadge.Visible = ready
	local wait = 20 * 3600 - (now() - last)
	dailyBtn.setText(ready and "DAILY" or wait >= 3600 and string.format("%dh %02dm", wait // 3600, (wait // 60) % 60) or string.format("%d:%02d", wait // 60, wait % 60))
end

giftsBtn.Instance.Activated:Connect(function()
	refreshGifts()
	UIKit.toggle(giftsWindow)
end)
dailyBtn.Instance.Activated:Connect(function()
	refreshDaily()
	UIKit.toggle(dailyWindow)
end)

-- Tick timers once a second; pop the daily window on join if it's ready.
task.spawn(function()
	repeat
		task.wait(0.3)
	until player:GetAttribute("DataLoaded")
	task.wait(2)
	refreshDaily()
	-- returning players see their daily reward right away; brand-new players fly first (the "!"
	-- badge on DAILY is enough until then)
	if dailyReady() and not player:GetAttribute("Flying") and (player:GetAttribute("StatFlights") or 0) > 0 then
		UIKit.toggle(dailyWindow)
	end
	while true do
		refreshGifts()
		refreshDaily()
		task.wait(1)
	end
end)
