-- Progress bar (bottom center): the whole trip from the cannon to your next locked gate.
--   Lobby: your best distance, a tick per stage, and "UNLOCK" once you've reached the gate.
--   Flying: a rocket slides along it live, with a trophy at your best so you see a record coming.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local GREEN, GOLD, BLUE = Color3.fromRGB(80, 210, 90), Color3.fromRGB(255, 190, 40), Color3.fromRGB(90, 180, 255)

local LOBBY_POS = UDim2.new(0.5, 0, 1, -142) -- just above the LAUNCH / PETS / STORE buttons
local FLY_POS = UDim2.new(0.5, 0, 1, -64)

local gui = UIKit.gui()
local holder = make("Frame", { Parent = gui, Name = "ProgressBar", AnchorPoint = Vector2.new(0.5, 1), Position = LOBBY_POS, Size = UDim2.fromOffset(560, 62), BackgroundTransparency = 1 })
UIKit.hudScale(holder)

-- the bar itself
local back = make("Frame", { Parent = holder, Name = "Back", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, -120, 0, 30), BackgroundColor3 = Color3.fromRGB(45, 50, 75) }, { UIKit.corner(15), UIKit.stroke(3.5) })
local fill = make("Frame", { Parent = back, Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2 }, { UIKit.corner(15), UIKit.gloss(GREEN) })
make("Frame", { Parent = fill, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.65, Position = UDim2.new(0, 6, 0.12, 0), Size = UDim2.new(1, -12, 0.3, 0), ZIndex = 3 }, { UIKit.corner(6) })
local text = label({ Parent = back, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 6, StrokeThickness = 2.5 })
local ticks = make("Frame", { Parent = back, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 })

-- ends: the cannon on the left, the next gate on the right
local function endBadge(anchorX, posX, color, txt)
	local b = make("Frame", { Parent = holder, AnchorPoint = Vector2.new(anchorX, 1), Position = UDim2.new(posX, 0, 1, 4), Size = UDim2.fromOffset(64, 40), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5 }, { UIKit.corner(14), UIKit.stroke(3.5), UIKit.gloss(color) })
	local l = label({ Parent = b, Position = UDim2.fromScale(0.06, 0.1), Size = UDim2.fromScale(0.88, 0.8), Text = txt, ZIndex = 6, StrokeThickness = 2.5 })
	return b, l
end
endBadge(0, 0, BLUE, "🚀")
local gateBadge, gateText = endBadge(1, 1, GOLD, "S2")

-- markers riding on the bar
local function marker(icon, size)
	local m = make("Frame", { Parent = back, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0, 0), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = 7 })
	label({ Parent = m, Size = UDim2.fromScale(1, 1), Text = icon, ZIndex = 7, StrokeThickness = 0 })
	return m
end
local bestMarker = marker("🏆", 34)
local rocketMarker = marker("🚀", 32)
rocketMarker.Visible = false

local function goal()
	local unlocked = player:GetAttribute("UnlockedStage") or 1
	return Config.stageEndX(math.min(unlocked, Config.NUM_STAGES)) - Config.LAUNCH_X, unlocked
end

local function rebuildTicks()
	ticks:ClearAllChildren()
	local g, unlocked = goal()
	for s = 1, math.min(unlocked, Config.NUM_STAGES) - 1 do
		local x = (s * Config.STAGE_LENGTH) / g
		make("Frame", { Parent = ticks, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.new(0, 4, 1, 6), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 5 }, { UIKit.stroke(1.5) })
	end
	gateText.Text = unlocked >= Config.NUM_STAGES and "🏁" or ("S" .. (unlocked + 1))
end

local shown = 0 -- fill fraction on screen (eased)
local lastDistance = 0
local lastState = nil
local function lobbyText(best, g, unlocked)
	if unlocked >= Config.NUM_STAGES then
		return best >= g - 5 and "🏁 You reached the end of the galaxy!" or ("🏆 Best " .. Config.meters(best) .. " / " .. Config.meters(g))
	end
	if best >= g - 5 then
		return "✅ Gate reached! Stage " .. (unlocked + 1) .. ": $" .. Config.abbreviate(Config.stageCost(unlocked + 1))
	end
	return "🏆 Best " .. Config.meters(best) .. "  •  " .. Config.meters(g - best) .. " to Stage " .. (unlocked + 1)
end

-- in the lobby the bar sits just above the bottom buttons, wherever they are (phones scale them)
local bottomBar = UIKit.bottomBar()
local function lobbyPos()
	local top = UIKit.toGui(bottomBar.AbsolutePosition).Y
	return UDim2.new(0.5, 0, 1, -(gui.AbsoluteSize.Y - top + 10))
end

RunService.RenderStepped:Connect(function(dt)
	local flying = player:GetAttribute("Flying") == true
	-- brand-new players see just the LAUNCH hint first; the bar appears with the first flight
	holder.Visible = flying or (player:GetAttribute("StatFlights") or 0) > 0
	if not holder.Visible then
		return
	end
	local g, unlocked = goal()
	local best = player:GetAttribute("BestDistance") or 0
	local frac
	if flying then
		local flights = workspace:FindFirstChild("Flights")
		local m = flights and flights:FindFirstChild(player.Name)
		local body = m and m.PrimaryPart
		-- (after landing the rocket is removed: keep showing where you got to)
		local d = body and math.clamp(body.Position.X - Config.LAUNCH_X, 0, g) or lastDistance -- (stops at the locked gate, like the payout)
		lastDistance = d
		frac = math.clamp(d / g, 0, 1)
		text.Text = Config.meters(d) .. " / " .. Config.meters(g)
		rocketMarker.Visible = true
		rocketMarker.Position = UDim2.new(frac, 0, 0, 4)
		-- the fill turns gold once you pass your best
		local state = d > best and "record" or "fly"
		if state ~= lastState then
			lastState = state
			fill:FindFirstChildOfClass("UIGradient"):Destroy()
			UIKit.gloss(state == "record" and GOLD or BLUE).Parent = fill
			if state == "record" and best > 0 then
				UIKit.bounce(gateBadge)
			end
		end
	else
		frac = math.clamp(best / g, 0, 1)
		text.Text = lobbyText(best, g, unlocked)
		rocketMarker.Visible = false
		local state = best >= g - 5 and "ready" or "lobby"
		if state ~= lastState then
			lastState = state
			fill:FindFirstChildOfClass("UIGradient"):Destroy()
			UIKit.gloss(state == "ready" and GOLD or GREEN).Parent = fill
		end
	end
	shown += (frac - shown) * (1 - math.exp(-dt * (flying and 20 or 6)))
	fill.Size = UDim2.fromScale(math.max(shown, 0.02), 1)
	bestMarker.Visible = best > 0 and best < g
	bestMarker.Position = UDim2.new(math.clamp(best / g, 0, 1), 0, 0, flying and -2 or 4)
end)

-- move between the lobby spot and the flying spot
player:GetAttributeChangedSignal("Flying"):Connect(function()
	local flying = player:GetAttribute("Flying") == true
	TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Position = flying and FLY_POS or lobbyPos() }):Play()
	if flying then
		lastDistance = 0
	end
	lastState = nil
end)
player:GetAttributeChangedSignal("UnlockedStage"):Connect(function()
	rebuildTicks()
	UIKit.bounce(gateBadge)
end)
task.spawn(function()
	repeat
		task.wait(0.2)
	until player:GetAttribute("DataLoaded")
	rebuildTicks()
	if not player:GetAttribute("Flying") then
		holder.Position = lobbyPos()
	end
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if not player:GetAttribute("Flying") then
		holder.Position = lobbyPos()
	end
end)
