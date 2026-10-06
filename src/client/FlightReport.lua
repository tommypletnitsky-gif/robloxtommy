-- Flight Report: the landing screen.
--   The distance counts up, each earning line pops in (distance money, money boost, coins, best
--   combo), then the TOTAL slams in and coins fly into your money counter. A "next goal" line
--   tells you what to do next, with FLY AGAIN (queues an instant relaunch if you're still
--   landing) and UPGRADE (opens the Upgrades window) buttons. It stays until you press its X.
-- RocketClient sets Report.launch (start a flight) and Report.shake (camera shake).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local Report = {}
Report.launch = nil
Report.shake = nil

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local abbreviate, meters = Config.abbreviate, Config.meters
local gui = UIKit.gui()
local camera = workspace.CurrentCamera

local W, H = 470, 430
local card = make("Frame", {
	Parent = gui,
	Name = "FlightReport",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.47),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
	ZIndex = 20,
}, { UIKit.corner(28), UIKit.stroke(5), make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 228, 255)) }), make("UIScale", {}) })
local ribbon = make("Frame", { Parent = card, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(330, 66), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22 }, { UIKit.corner(20), UIKit.stroke(4), UIKit.gloss(Color3.fromRGB(255, 190, 40)) })
local ribbonText = label({ Parent = ribbon, Position = UDim2.fromScale(0.05, 0.1), Size = UDim2.fromScale(0.9, 0.8), Text = "", ZIndex = 23, StrokeThickness = 3.5 })
local distanceText = label({ Parent = card, Position = UDim2.fromOffset(20, 44), Size = UDim2.new(1, -40, 0, 62), Text = "", TextColor3 = Color3.fromRGB(70, 140, 255), ZIndex = 21, StrokeThickness = 3.5 })
local bestStamp = label({ Parent = card, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -62, 0, 66), Size = UDim2.fromOffset(120, 40), Rotation = 14, Text = "NEW BEST!", TextColor3 = Color3.fromRGB(255, 80, 80), StrokeThickness = 3, ZIndex = 24, Visible = false })
make("UIScale", { Parent = bestStamp })
local rows = make("Frame", { Parent = card, Position = UDim2.fromOffset(28, 112), Size = UDim2.new(1, -56, 0, 150), BackgroundTransparency = 1, ZIndex = 21 }, {
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})
make("Frame", { Parent = card, Position = UDim2.fromOffset(28, 266), Size = UDim2.new(1, -56, 0, 3), BackgroundColor3 = Color3.fromRGB(190, 200, 225), BorderSizePixel = 0, ZIndex = 21 })
local totalText = label({ Parent = card, Position = UDim2.fromOffset(20, 272), Size = UDim2.new(1, -40, 0, 56), Text = "", TextColor3 = Color3.fromRGB(80, 210, 90), ZIndex = 21, StrokeThickness = 3.5 })
make("UIScale", { Parent = totalText })
local hintText = label({ Parent = card, Position = UDim2.fromOffset(24, 330), Size = UDim2.new(1, -48, 0, 26), Text = "", TextColor3 = Color3.fromRGB(90, 90, 120), ZIndex = 21, StrokeThickness = 0 })
local againBtn = UIKit.button({ Parent = card, Text = "🚀 FLY AGAIN", Color = Color3.fromRGB(255, 130, 30), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -14), Size = UDim2.fromOffset(210, 58), ZIndex = 22, Radius = 20 })
local upgradeBtn = UIKit.button({ Parent = card, Text = "⬆ UPGRADE", Color = Color3.fromRGB(170, 80, 240), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -14), Size = UDim2.fromOffset(210, 58), ZIndex = 22, Radius = 20 })

againBtn.Instance.Name = "FlyAgain"
upgradeBtn.Instance.Name = "Upgrade"

local token = 0
local queued = false -- FLY AGAIN pressed while still landing

-- one "label ... value" line
local function row(order, left, right, color)
	local r = make("Frame", { Parent = rows, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, ZIndex = 21 })
	label({ Parent = r, Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Text = left, TextColor3 = Color3.fromRGB(80, 85, 115), StrokeThickness = 0, ZIndex = 21 })
	label({ Parent = r, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.45, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Text = right, TextColor3 = color or UIKit.INK, StrokeThickness = 2, ZIndex = 21 })
	UIKit.bounce(r)
	UIKit.sound("Pop", 0.45, 1 + order * 0.08)
end

-- counts a label up from 0 with ticks; fmt(n) -> text
local function countUp(lbl, to, dur, fmt)
	local t0 = os.clock()
	while true do
		local a = math.min(1, (os.clock() - t0) / dur)
		lbl.Text = fmt(to * (1 - (1 - a) ^ 3))
		if a >= 1 then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

local function nextGoal()
	local money = player:GetAttribute("Money") or 0
	local unlocked = player:GetAttribute("UnlockedStage") or 1
	local best = player:GetAttribute("BestDistance") or 0
	if unlocked >= Config.NUM_STAGES then
		return "🌌 You've unlocked every stage!"
	end
	local goal = Config.stageEndX(unlocked) - Config.LAUNCH_X
	local cost = Config.stageCost(unlocked + 1)
	if best >= goal - 5 then
		if money >= cost then
			return "✅ You can unlock Stage " .. (unlocked + 1) .. " now!"
		end
		return "🎯 Stage " .. (unlocked + 1) .. " costs $" .. abbreviate(cost) .. ": keep flying!"
	end
	for key, u in pairs(Config.Upgrades) do
		local lvl = player:GetAttribute(key .. "Level") or 0
		if lvl < u.maxLevel and money >= Config.upgradeCost(key, lvl) then
			return "⬆ You can afford an upgrade: fly even farther!"
		end
	end
	return "🎯 " .. meters(goal - best) .. " more to reach Stage " .. (unlocked + 1)
end

function Report.hide()
	card.Visible = false
end

function Report.show(info)
	token += 1
	local mine = token
	queued = false
	againBtn.setText("🚀 FLY AGAIN")
	for _, c in ipairs(rows:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	ribbonText.Text = "FLIGHT REPORT"
	distanceText.Text = "🚀 0m"
	totalText.Text = ""
	hintText.Text = ""
	bestStamp.Visible = false
	UIKit.clearToasts()
	local banner = gui:FindFirstChild("StageBanner")
	if banner then
		banner.Visible = false
	end
	card.Visible = true
	-- fit small screens, then spring open
	local view = camera.ViewportSize
	local fit = (view.X > 300 and view.Y > 200) and math.min(1, (view.X - 20) / W, (view.Y - 40) / H) or 1
	local scale = card:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.3 * fit
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
	UIKit.sound("Pop", 0.6, 0.9)

	task.spawn(function()
		local function alive()
			return token == mine and card.Visible
		end
		countUp(distanceText, info.distance, 0.6, function(n)
			return "🚀 " .. meters(n)
		end)
		if not alive() then
			return
		end
		if info.newBest then
			bestStamp.Visible = true
			local st = bestStamp:FindFirstChildOfClass("UIScale")
			st.Scale = 2.2
			TweenService:Create(st, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			UIKit.sound("Jingle", 0.55)
			if Report.shake then
				Report.shake(0.5)
			end
		end
		task.wait(0.15)
		local order = 0
		local function line(left, right, color)
			if alive() then
				order += 1
				row(order, left, right, color)
				task.wait(0.22)
			end
		end
		line("Distance " .. meters(info.distance), "$" .. abbreviate(info.base or info.money), Color3.fromRGB(70, 140, 255))
		if (info.mult or 1) > 1.01 then
			line("Money boost", Config.multText(info.mult), Color3.fromRGB(170, 80, 240))
		end
		if (info.coins or 0) > 0 then
			line("Coins x" .. info.coins, "+$" .. abbreviate(info.bonus or 0), Color3.fromRGB(230, 160, 20))
		end
		if (info.bestCombo or 0) >= 5 then
			line("Best combo", "🔥 " .. info.bestCombo, Color3.fromRGB(255, 120, 40))
		end
		if not alive() then
			return
		end
		countUp(totalText, (info.money or 0) + (info.bonus or 0), 0.7, function(n)
			return "+$" .. abbreviate(n)
		end)
		if not alive() then
			return
		end
		local ts = totalText:FindFirstChildOfClass("UIScale")
		ts.Scale = 1.35
		UIKit.spr.target(ts, 0.35, 4, { Scale = 1 })
		UIKit.sound("Gem", 0.6, 1)
		UIKit.coinBurst(info.newBest and 18 or 12, totalText.AbsolutePosition + totalText.AbsoluteSize / 2)
		hintText.Text = nextGoal()
		UIKit.bounce(hintText)
	end)
end

-- called when you're back in the lobby after a flight
function Report.backHome()
	if queued then
		queued = false
		task.delay(0.35, function()
			if Report.launch then
				Report.launch()
			end
		end)
		return
	end
	-- otherwise the report stays up until you press X (or launch again)
end

-- the report only goes away with its X (top-left corner), FLY AGAIN, UPGRADE or a new launch
local closeBtn = UIKit.button({ Parent = card, Text = "X", Color = Color3.fromRGB(240, 70, 70), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(54, 54), Radius = 27, ZIndex = 26 })
closeBtn.Instance.Name = "Close"
closeBtn.Instance.Activated:Connect(function()
	card.Visible = false
	queued = false
	againBtn.setText("🚀 FLY AGAIN")
end)
againBtn.Instance.Activated:Connect(function()
	if player:GetAttribute("Flying") then
		queued = true
		againBtn.setText("⏳ GET READY...")
	elseif Report.launch then
		Report.launch()
	end
end)
upgradeBtn.Instance.Activated:Connect(function()
	card.Visible = false
	queued = false
	local w = gui:FindFirstChild("Window_Upgrades")
	if w and not w.Visible then
		UIKit.toggle(w)
	end
end)

return Report
