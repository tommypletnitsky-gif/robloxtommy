-- Halloween event (client): a pumpkin pill in the event bar at the top with your candy and the
-- time left ("🎃 🍬 120  •  26d 4h left"). It bounces and shows "+🍬" as you collect candy.
-- Tap it for a quick explanation. Only exists while Config.halloweenActive().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label

local bar = UIKit.gui():WaitForChild("EventBar", 15)
if not bar then
	return
end

local ORANGE = Color3.fromRGB(255, 140, 30)
local pill = make("TextButton", { Parent = bar, Name = "HalloweenPill", LayoutOrder = 0, Size = UDim2.fromOffset(270, 46), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, Visible = false }, { UIKit.corner(23), UIKit.stroke(3.5), UIKit.gloss(ORANGE) })
make("Frame", { Parent = pill, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, Position = UDim2.fromScale(0.06, 0.1), Size = UDim2.fromScale(0.88, 0.32) }, { UIKit.corner(10) })
local text = label({ Parent = pill, Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 1, -14), Text = "", StrokeThickness = 2.5 })

pill.Activated:Connect(function()
	UIKit.bounce(pill)
	UIKit.toast("🎃 HALLOWEEN! Grab coins, gems and rings in flight to collect 🍬 candy.", Color3.fromRGB(255, 190, 90))
	UIKit.toast("Spend candy on the SPOOKY EGG in the Egg Garden: 4 limited Halloween pets!", Color3.fromRGB(220, 160, 255))
end)

local function timeLeft()
	local left = math.max(0, Config.Halloween.ends - workspace:GetServerTimeNow())
	local d, h = math.floor(left / 86400), math.floor(left / 3600) % 24
	if d > 0 then
		return d .. "d " .. h .. "h"
	end
	return h .. "h " .. math.floor(left / 60) % 60 .. "m"
end

local lastCandy = nil
local function refresh()
	local active = Config.halloweenActive()
	pill.Visible = active
	if active then
		text.Text = "🎃 🍬 " .. Config.abbreviate(player:GetAttribute("Candy") or 0) .. "  •  " .. timeLeft() .. " left"
	end
end

player:GetAttributeChangedSignal("Candy"):Connect(function()
	local candy = player:GetAttribute("Candy") or 0
	if lastCandy and candy > lastCandy and pill.Visible then
		UIKit.bounce(pill)
		-- "+🍬 3" floating up under the pill
		local p = UIKit.toGui(pill.AbsolutePosition + Vector2.new(pill.AbsoluteSize.X / 2, pill.AbsoluteSize.Y + 4))
		local l = label({ Parent = UIKit.gui(), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(120, 28), Text = "+🍬 " .. (candy - lastCandy), TextColor3 = Color3.fromRGB(255, 170, 230), StrokeThickness = 2.5, ZIndex = 30 })
		game:GetService("TweenService"):Create(l, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Position = l.Position + UDim2.fromOffset(0, 26), TextTransparency = 1 }):Play()
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			game:GetService("TweenService"):Create(st, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		end
		game:GetService("Debris"):AddItem(l, 0.85)
	end
	lastCandy = candy
	refresh()
end)

task.spawn(function()
	repeat
		task.wait(0.3)
	until player:GetAttribute("DataLoaded")
	lastCandy = player:GetAttribute("Candy") or 0
	while true do
		refresh()
		task.wait(20)
	end
end)
