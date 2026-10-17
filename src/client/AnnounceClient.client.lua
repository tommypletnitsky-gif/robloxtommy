-- Owner "admin abuse" on your screen (ExtrasServer chat commands):
--   * Announce (/bb, /gbb, /luckyhour, /boost, /rain, /giveall, /spin all): a big banner slides
--     down from the top - who sent it + the (filtered) message - holds, then slides away.
--     Banners queue up so none are missed.
--   * a "x2 MONEY 9:59" pill while the owner's money boost runs (workspace AdminMoneyUntil)
--   * RainCoin: you grabbed a money-rain coin -> coin sound + "+$..." pop
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Announce = remotes:WaitForChild("Announce")
local RainCoin = remotes:WaitForChild("RainCoin")

local make = UIKit.make
local gui = UIKit.gui()

-- Banner -------------------------------------------------------------------------------------
local holder = make("Frame", { Parent = gui, Name = "AdminBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(760, 132), BackgroundTransparency = 1, ZIndex = 80 })
UIKit.hudScale(holder)
local HIDDEN = UDim2.new(0.5, 0, 0, -500) -- (well above the screen at every size; phones shrink the HUD)
local card = make("Frame", { Parent = holder, AnchorPoint = Vector2.new(0.5, 0), Position = HIDDEN, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 80 }, {
	UIKit.corner(26),
	UIKit.stroke(5),
})
local grad = UIKit.gloss(Color3.fromRGB(255, 190, 40))
grad.Parent = card
local titlePill = make("Frame", { Parent = card, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(380, 44), BackgroundColor3 = Color3.fromRGB(40, 25, 70), ZIndex = 82 }, {
	UIKit.corner(22),
	UIKit.stroke(3.5),
})
local title = UIKit.label({ Parent = titlePill, Position = UDim2.fromOffset(14, 5), Size = UDim2.new(1, -28, 1, -10), Text = "", ZIndex = 83, StrokeThickness = 2.5 })
local body = UIKit.label({ Parent = card, Position = UDim2.fromOffset(24, 32), Size = UDim2.new(1, -48, 1, -44), Text = "", TextWrapped = true, ZIndex = 82, StrokeThickness = 4 })

local queue, showing = {}, false
local function showNext()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local item = table.remove(queue, 1)
	local color = typeof(item.color) == "Color3" and item.color or Color3.fromRGB(255, 190, 40)
	grad.Color = UIKit.gloss(color).Color
	title.Text = item.title
	body.Text = item.text
	card.Position = HIDDEN
	card.Visible = true
	TweenService:Create(card, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 0) }):Play()
	UIKit.bounce(titlePill)
	UIKit.sound("Fanfare", 0.7, 1)
	local hold = math.clamp(3.5 + #item.text / 18, 4, 9)
	task.delay(0.55 + hold, function()
		TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = HIDDEN }):Play()
		task.wait(0.45)
		card.Visible = false
		showing = false
		showNext()
	end)
end

Announce.OnClientEvent:Connect(function(t, text, color)
	if typeof(t) ~= "string" or typeof(text) ~= "string" then
		return
	end
	table.insert(queue, { title = t, text = text, color = color })
	showNext()
end)

-- Money boost pill -----------------------------------------------------------------------------
local pill = make("Frame", { Parent = gui, Name = "AdminBoostPill", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(250, 38), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 40 }, {
	UIKit.corner(19),
	UIKit.stroke(3.5),
	UIKit.gloss(Color3.fromRGB(255, 190, 40)),
})
UIKit.hudScale(pill)
local pillText = UIKit.label({ Parent = pill, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), Text = "", ZIndex = 41 })
-- (also shows the new pilot boost: x2 money until Stage 3 in your first life)
local player = Players.LocalPlayer
task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		local untilT = workspace:GetAttribute("AdminMoneyUntil") or 0
		local beginner = player:GetAttribute("DataLoaded") and Config.beginnerBoost(player) or 1
		local busy = UIKit.busy()
		if untilT > now and not busy then
			local left = math.floor(untilT - now)
			pill.Size = UDim2.fromOffset(250, 38)
			pillText.Text = string.format("💰 x%s MONEY  %d:%02d", tostring(workspace:GetAttribute("AdminMoneyMult") or 2), left // 60, left % 60)
			pill.Visible = true
		elseif beginner > 1 and not busy then
			pill.Size = UDim2.fromOffset(360, 38)
			pillText.Text = "🚀 NEW PILOT x" .. beginner .. " MONEY until Stage " .. Config.BEGINNER_BOOST.untilStage
			pill.Visible = true
		else
			pill.Visible = false
		end
		task.wait(0.5)
	end
end)

-- Money rain pickups ---------------------------------------------------------------------------
RainCoin.OnClientEvent:Connect(function(amount)
	if typeof(amount) ~= "number" then
		return
	end
	UIKit.sound("Coin", 0.6, 1 + math.random() * 0.2)
	UIKit.popSum("rain", amount, Color3.fromRGB(130, 255, 130))
end)

-- Phones: Roblox's chat window is huge by default and covers the game - make it smaller there.
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	local TextChatService = game:GetService("TextChatService")
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if window then
		window.HeightScale = 0.6
		window.WidthScale = 0.75
		window.TextSize = 12
		window.BackgroundTransparency = 0.45
	end
	local bar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if bar then
		bar.TextSize = 12
	end
end
