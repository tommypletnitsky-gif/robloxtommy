-- Side bar: free timed gifts, daily reward, and the "support the game" donation window.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClaimGift = remotes:WaitForChild("ClaimGift")
local ClaimDaily = remotes:WaitForChild("ClaimDaily")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local abbreviate = Config.abbreviate
local side = UIKit.sideBar()

local PINK, GOLD, TEAL = Color3.fromRGB(255, 110, 170), Color3.fromRGB(255, 180, 40), Color3.fromRGB(40, 190, 200)
local giftsBtn = UIKit.button({ Parent = side, LayoutOrder = 1, Icon3D = "Gift", Text = "GIFTS", Color = PINK, Size = UDim2.fromOffset(92, 98), Radius = 22 })
local dailyBtn = UIKit.button({ Parent = side, LayoutOrder = 2, Icon3D = "Calendar", Text = "DAILY", Color = GOLD, Size = UDim2.fromOffset(92, 98), Radius = 22 })
local donateBtn = UIKit.button({ Parent = side, LayoutOrder = 3, Icon3D = "Heart", Text = "SUPPORT", Color = TEAL, Size = UDim2.fromOffset(92, 98), Radius = 22 })
local giftBadge = UIKit.badge(giftsBtn.Instance)
local dailyBadge = UIKit.badge(dailyBtn.Instance)

local function stage()
	return player:GetAttribute("UnlockedStage") or 1
end

-- Gifts --------------------------------------------------------------------------------------
local giftsWindow, giftsList = UIKit.window("Free Gifts", PINK, UDim2.fromOffset(680, 500), "Gift")
local grid = make("Frame", { Parent = giftsList, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIGridLayout", { CellSize = UDim2.fromOffset(116, 170), CellPadding = UDim2.fromOffset(10, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local giftCells = {}
for i, minutes in ipairs(Config.GiftMinutes) do
	local cell = UIKit.card(grid, { LayoutOrder = i, ZIndex = 11, Tint = Color3.fromRGB(255, 228, 242) })
	local iconBox = make("Frame", { Parent = cell, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 72), BackgroundTransparency = 1, ZIndex = 12 })
	UIKit.icon3D(iconBox, "Gift", { ZIndex = 12 })
	local reward = label({ Parent = cell, Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 0, 26), Text = "", TextColor3 = Color3.fromRGB(60, 170, 80), StrokeThickness = 0, ZIndex = 12 })
	local btn = UIKit.button({ Parent = cell, Text = "", Color = GOLD, Position = UDim2.fromOffset(8, 110), Size = UDim2.new(1, -16, 0, 50), ZIndex = 12, Radius = 14 })
	btn.Instance.Activated:Connect(function()
		local ok, msg = ClaimGift:InvokeServer(i)
		UIKit.result(ok, msg)
	end)
	giftCells[i] = { minutes = minutes, reward = reward, btn = btn }
end

local function refreshGifts()
	local played = os.time() - (player:GetAttribute("JoinedAt") or os.time())
	local claimed = string.split(player:GetAttribute("GiftsClaimed") or "", ",")
	local anyReady = false
	for i, c in ipairs(giftCells) do
		c.reward.Text = "$" .. abbreviate(Config.giftReward(stage(), i))
		if table.find(claimed, tostring(i)) then
			c.btn.setText("✓")
			c.btn.setColor(Color3.fromRGB(160, 165, 185))
		else
			local left = c.minutes * 60 - played
			if left <= 0 then
				c.btn.setText("OPEN!")
				c.btn.setColor(Color3.fromRGB(80, 200, 90))
				anyReady = true
			else
				c.btn.setText(string.format("%d:%02d", left // 60, left % 60))
				c.btn.setColor(GOLD)
			end
		end
	end
	giftBadge.Visible = anyReady
end

-- Daily reward --------------------------------------------------------------------------------
local dailyWindow, dailyList = UIKit.window("Daily Reward", GOLD, UDim2.fromOffset(700, 400), "Calendar")
local dayRow = make("Frame", { Parent = dailyList, Size = UDim2.new(1, -12, 0, 170), BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local dayCells = {}
for d = 1, 7 do
	local big = d == 7
	local cell = UIKit.card(dayRow, { LayoutOrder = d, Size = UDim2.fromOffset(big and 100 or 82, big and 160 or 140), ZIndex = 11, Tint = big and Color3.fromRGB(255, 236, 190) or Color3.fromRGB(240, 244, 255) })
	label({ Parent = cell, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 24), Text = "Day " .. d, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local iconBox = make("Frame", { Parent = cell, Position = UDim2.fromOffset(4, 30), Size = UDim2.new(1, -8, 0, big and 74 or 60), BackgroundTransparency = 1, ZIndex = 12 })
	UIKit.icon3D(iconBox, big and "Gift" or "Coin", { ZIndex = 12 })
	local amount = label({ Parent = cell, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 2, 1, -10), Size = UDim2.new(1, -4, 0, 26), Text = "", TextColor3 = Color3.fromRGB(60, 170, 80), StrokeThickness = 0, ZIndex = 12 })
	local check = UIKit.pill(cell, { Text = "✔", Color = Color3.fromRGB(80, 200, 90), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(30, 30), ZIndex = 14 })
	dayCells[d] = { cell = cell, amount = amount, check = check, stroke = cell:FindFirstChildOfClass("UIStroke") }
end
local dailyClaim = UIKit.button({ Parent = dailyList, LayoutOrder = 2, Text = "CLAIM!", Color = Color3.fromRGB(80, 200, 90), Size = UDim2.fromOffset(300, 76), Radius = 24 })
dailyClaim.Instance.Activated:Connect(function()
	local ok, msg = ClaimDaily:InvokeServer()
	UIKit.result(ok, msg)
	if ok then
		UIKit.sound("Win", 0.6)
	end
end)

local function dailyReady()
	return os.time() - (player:GetAttribute("LastDaily") or 0) >= 20 * 3600
end

local function refreshDaily()
	local last = player:GetAttribute("LastDaily") or 0
	local streak = player:GetAttribute("DailyStreak") or 0
	local ready = dailyReady()
	local nextDay = ready and ((os.time() - last < 48 * 3600) and streak + 1 or 1) or streak
	for d, c in ipairs(dayCells) do
		c.amount.Text = "$" .. abbreviate(Config.dailyReward(stage(), d))
		local today = math.min(nextDay, 7)
		local highlight = d == today
		c.check.Visible = d < today
		if c.stroke then
			c.stroke.Color = highlight and Color3.fromRGB(255, 170, 30) or Color3.fromRGB(190, 200, 225)
			c.stroke.Thickness = highlight and 5 or 3
		end
	end
	if ready then
		dailyClaim.setText("CLAIM!")
		dailyClaim.setColor(Color3.fromRGB(80, 200, 90))
	else
		local left = 20 * 3600 - (os.time() - last)
		dailyClaim.setText(string.format("Next in %d:%02d:%02d", left // 3600, (left // 60) % 60, left % 60))
		dailyClaim.setColor(Color3.fromRGB(160, 165, 185))
	end
	dailyBadge.Visible = ready
end

-- Donations ----------------------------------------------------------------------------------
local donateWindow, donateList = UIKit.window("Support the Game", TEAL, UDim2.fromOffset(620, 500), "Heart")
local thanks = UIKit.row(donateList, 0, 70)
label({ Parent = thanks, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), Text = "Donations help us add new rockets & worlds!\nTop donators get shown on the board in the lobby.", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
for i, d in ipairs(Config.Donations) do
	local r = UIKit.row(donateList, i, 80)
	local iconBox = make("Frame", { Parent = r, Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, ZIndex = 12 })
	UIKit.icon3D(iconBox, "Heart", { ZIndex = 12 })
	label({ Parent = r, Position = UDim2.fromOffset(88, 14), Size = UDim2.new(1, -250, 1, -28), TextXAlignment = Enum.TextXAlignment.Left, Text = "Donate " .. d.robux .. " Robux", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local btn = UIKit.button({ Parent = r, Text = d.id ~= 0 and ("R$ " .. d.robux) or "SOON", Color = d.id ~= 0 and TEAL or Color3.fromRGB(160, 165, 185), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 54), ZIndex = 12 })
	btn.Instance.Activated:Connect(function()
		if d.id == 0 then
			UIKit.toast("Donations open soon!", Color3.fromRGB(255, 230, 120))
			return
		end
		MarketplaceService:PromptProductPurchase(player, d.id)
	end)
end

giftsBtn.Instance.Activated:Connect(function()
	refreshGifts()
	UIKit.toggle(giftsWindow)
end)
dailyBtn.Instance.Activated:Connect(function()
	refreshDaily()
	UIKit.toggle(dailyWindow)
end)
donateBtn.Instance.Activated:Connect(function()
	UIKit.toggle(donateWindow)
end)

-- Tick timers once a second; pop the daily window on join if it's ready.
task.spawn(function()
	repeat
		task.wait(0.3)
	until player:GetAttribute("DataLoaded")
	task.wait(2)
	refreshDaily()
	if dailyReady() and not player:GetAttribute("Flying") then
		UIKit.toggle(dailyWindow)
	end
	while true do
		refreshGifts()
		refreshDaily()
		task.wait(1)
	end
end)
