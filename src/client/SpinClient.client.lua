-- Lucky Spin (client): the SPIN side button (with how many spins you have), the prize-roll window
-- and the active-boost pills at the top of the screen.
--   Roll: a strip of prize cards races past the center marker, ticking card by card, slows down and
--   lands on the prize the server picked; then the reveal (coins / celebration).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpinRemote = remotes:WaitForChild("Spin")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local abbreviate = Config.abbreviate
local PURPLE = Color3.fromRGB(190, 90, 255)
local GREEN, GREY = Color3.fromRGB(80, 200, 90), Color3.fromRGB(160, 165, 185)
local PRIZES = Config.Spin.prizes
local ROLL_TIME = 4.2

local function stage()
	return player:GetAttribute("UnlockedStage") or 1
end

local function prizeValue(prize)
	if prize.kind == "money" then
		return "$" .. abbreviate(Config.spinMoney(prize, stage()))
	elseif prize.kind == "boostMoney" then
		return "5 min"
	elseif prize.kind == "boostLuck" then
		return "5 min"
	elseif prize.kind == "fullBoost" then
		return "next flight"
	elseif prize.kind == "pet" then
		return "best egg"
	end
	return ""
end

-- Side button -----------------------------------------------------------------------------------
local spinBtn = UIKit.button({ Parent = UIKit.sideBar(), LayoutOrder = 3, Icon3D = "Crown", Icon = "🎰", Text = "SPIN", Color = PURPLE, Size = UDim2.fromOffset(92, 98), Radius = 22 })
spinBtn.Instance.Name = "SpinButton"
local spinBadge = UIKit.badge(spinBtn.Instance)

-- Window ------------------------------------------------------------------------------------------
local window, list = UIKit.window("Lucky Spin", PURPLE, UDim2.fromOffset(660, 470), "Crown")
local head = UIKit.row(list, 0, 46)
label({ Parent = head, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 1, -12), Text = "Spin for money, boosts, free pets... or the JACKPOT! 🎰", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })

local TRACK_W, CARD_W, CARD_GAP = 600, 118, 10
local STEP = CARD_W + CARD_GAP
local track = make("Frame", { Parent = list, Name = "Track", LayoutOrder = 1, Size = UDim2.fromOffset(TRACK_W, 176), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, ZIndex = 11 }, { UIKit.corner(22), UIKit.stroke(4) })
make("UIGradient", { Parent = track, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 105, 235), Color3.fromRGB(95, 60, 175)) })
local strip = make("Frame", { Parent = track, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(0, 0, 0, 140), BackgroundTransparency = 1, ZIndex = 12 })
-- the marker: a glowing frame in the middle + arrows top and bottom
make("Frame", { Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(CARD_W + 10, 156), BackgroundTransparency = 1, ZIndex = 16 }, { UIKit.corner(18), make("UIStroke", { Thickness = 5, Color = Color3.fromRGB(255, 220, 70) }) })
label({ Parent = track, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(40, 30), Text = "▼", TextColor3 = Color3.fromRGB(255, 220, 70), StrokeThickness = 3, ZIndex = 17 })
label({ Parent = track, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.fromOffset(40, 30), Text = "▲", TextColor3 = Color3.fromRGB(255, 220, 70), StrokeThickness = 3, ZIndex = 17 })

local actions = make("Frame", { Parent = list, Name = "Actions", LayoutOrder = 2, Size = UDim2.new(1, -12, 0, 120), BackgroundTransparency = 1, ZIndex = 11 })
local goBtn = UIKit.button({ Parent = actions, Text = "SPIN!", Color = GREEN, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(300, 74), Radius = 26, ZIndex = 12 })
goBtn.Instance.Name = "SpinGo"
local nextText = label({ Parent = actions, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.new(1, -40, 0, 26), Text = "", TextColor3 = Color3.fromRGB(90, 90, 120), StrokeThickness = 0, ZIndex = 12 })

-- one prize card on the strip
local function card(prize, index)
	local c = make("Frame", { Parent = strip, Position = UDim2.fromOffset((index - 1) * STEP, 0), Size = UDim2.fromOffset(CARD_W, 140), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(18), UIKit.stroke(3.5), UIKit.gloss(prize.color), make("UIScale", {}) })
	make("Frame", { Parent = c, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, Position = UDim2.new(0.08, 0, 0.05, 0), Size = UDim2.new(0.84, 0, 0.22, 0), ZIndex = 12 }, { UIKit.corner(10) })
	local iconBox = make("Frame", { Parent = c, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 74), BackgroundTransparency = 1, ZIndex = 13 })
	if ReplicatedStorage:FindFirstChild("UIIcons") and ReplicatedStorage.UIIcons:FindFirstChild(prize.icon) then
		UIKit.icon3D(iconBox, prize.icon, { ZIndex = 13, Still = true })
	end
	if prize.tag then -- e.g. a big "x2" on the boost cards
		label({ Parent = c, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(46, 34), Rotation = 12, Text = prize.tag, TextColor3 = Color3.fromRGB(255, 240, 90), StrokeThickness = 3, ZIndex = 15 })
	end
	label({ Parent = c, Position = UDim2.fromOffset(6, 80), Size = UDim2.new(1, -12, 0, 26), Text = prize.name, StrokeThickness = 2.5, ZIndex = 14 })
	label({ Parent = c, Position = UDim2.fromOffset(6, 106), Size = UDim2.new(1, -12, 0, 24), Text = prizeValue(prize), TextColor3 = Color3.fromRGB(255, 250, 200), StrokeThickness = 2.5, ZIndex = 14 })
	return c
end

local function weightedPick()
	local total = 0
	for _, p in ipairs(PRIZES) do
		total += p.weight
	end
	local r = math.random() * total
	for _, p in ipairs(PRIZES) do
		r -= p.weight
		if r <= 0 then
			return p
		end
	end
	return PRIZES[1]
end

-- fill the strip: random prizes (rare ones show up often enough to tease), the real one at `land`
local LAND = 26
local function buildStrip(winner)
	strip:ClearAllChildren()
	local cards = {}
	for i = 1, LAND + 3 do
		local p = (i == LAND) and winner or (math.random() < 0.18 and PRIZES[math.random(6, #PRIZES)] or weightedPick())
		cards[i] = card(p, i)
	end
	strip.Size = UDim2.fromOffset((LAND + 3) * STEP, 140)
	return cards
end

local function stripX(i, nudge)
	return TRACK_W / 2 - ((i - 1) * STEP + CARD_W / 2) - (nudge or 0)
end

local rolling = false
local function reveal(prize, landed)
	local sc = landed:FindFirstChildOfClass("UIScale")
	sc.Scale = 1.25
	UIKit.spr.target(sc, 0.35, 4, { Scale = 1.08 })
	local value = prizeValue(prize)
	if prize.jackpot then
		UIKit.celebrate("🎰 JACKPOT!!!", value .. "!", Color3.fromRGB(255, 215, 60))
		UIKit.sound("Fanfare", 0.7)
		UIKit.coinBurst(24)
	elseif prize.kind == "money" then
		UIKit.sound("Jingle", 0.5, prize.studs >= 3000 and 1 or 1.15)
		UIKit.toast("🎰 You won " .. value .. "!", Color3.fromRGB(140, 255, 140))
		UIKit.coinBurst(prize.studs >= 3000 and 18 or 10)
	elseif prize.kind == "pet" then
		UIKit.celebrate("🎰 FREE PET!", "A new pet from your best egg is following you!", Color3.fromRGB(255, 150, 210))
	else
		UIKit.sound("Jingle", 0.5, 1.2)
		local text = ({ boostMoney = "💰 x2 MONEY for 5 minutes!", boostLuck = "🍀 x2 EGG LUCK for 5 minutes!", fullBoost = "⚡ Your next flight starts with a FULL BOOST!" })[prize.kind]
		UIKit.toast(text or prize.name, Color3.fromRGB(255, 230, 120))
	end
end

local function refresh()
	local spins = player:GetAttribute("Spins") or 0
	spinBadge.Visible = spins > 0
	spinBadge.Text = tostring(spins)
	if rolling then
		goBtn.setText("ROLLING...")
		goBtn.setColor(GREY)
	elseif spins > 0 then
		goBtn.setText("SPIN!  (" .. spins .. ")")
		goBtn.setColor(GREEN)
	else
		goBtn.setText("NO SPINS")
		goBtn.setColor(GREY)
	end
	if spins >= Config.Spin.max then
		nextText.Text = "You have the most spins you can hold (" .. Config.Spin.max .. ") - use them!"
	else
		local left = math.max(0, Config.Spin.every - (player:GetAttribute("SpinProgress") or 0))
		nextText.Text = string.format("Next free spin in %d:%02d  •  +1 spin with every daily reward", left // 60, left % 60)
	end
end

local function spin()
	if rolling then
		return
	end
	local ok, result = SpinRemote:InvokeServer()
	if not ok then
		UIKit.result(false, result)
		return
	end
	rolling = true
	refresh()
	local winner = PRIZES[result]
	local cards = buildStrip(winner)
	local from = stripX(2)
	local to = stripX(LAND, math.random(-40, 40))
	strip.Position = UDim2.fromOffset(from, 18)
	UIKit.sound("Whoosh", 0.5, 0.8)
	local t0 = os.clock()
	local lastCard = 0
	while true do
		local a = math.min(1, (os.clock() - t0) / ROLL_TIME)
		local x = from + (to - from) * (1 - (1 - a) ^ 4)
		strip.Position = UDim2.fromOffset(x, 18)
		-- which card is under the marker: tick when it changes
		local under = math.floor((TRACK_W / 2 - x) / STEP) + 1
		if under ~= lastCard then
			lastCard = under
			UIKit.sound("Tick", 0.35, 0.9 + a * 0.5)
		end
		if a >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	reveal(winner, cards[LAND])
	task.wait(0.6)
	rolling = false
	refresh()
end

goBtn.Instance.Activated:Connect(spin)
spinBtn.Instance.Activated:Connect(function()
	refresh()
	if #strip:GetChildren() == 0 then
		buildStrip(weightedPick())
		strip.Position = UDim2.fromOffset(stripX(LAND - 2), 18)
	end
	UIKit.toggle(window)
end)
for _, attr in ipairs({ "Spins", "SpinProgress", "UnlockedStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
refresh()

-- New players: point out the welcome spin once, after their first flight (not before: the first
-- thing a new player should do is fly)
task.spawn(function()
	repeat
		task.wait(0.5)
	until player:GetAttribute("DataLoaded")
	if (player:GetAttribute("StatFlights") or 0) > 0 then
		return
	end
	repeat
		task.wait(0.5)
	until (player:GetAttribute("StatFlights") or 0) > 0
	UIKit.whenFree(function()
		if (player:GetAttribute("Spins") or 0) > 0 then
			UIKit.toast("🎰 You have a FREE LUCKY SPIN! Press SPIN on the left.", Color3.fromRGB(230, 180, 255))
			UIKit.bounce(spinBtn.Instance)
		end
	end, 2)
end)

-- Active boost pills (top of the screen, in the event bar) -------------------------------------
local bar = UIKit.gui():WaitForChild("EventBar", 10)
local function boostPill(order, color)
	local f = make("Frame", { Parent = bar, LayoutOrder = order, Size = UDim2.fromOffset(200, 46), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, { UIKit.corner(23), UIKit.stroke(3.5), UIKit.gloss(color) })
	local t = label({ Parent = f, Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 1, -14), Text = "", StrokeThickness = 2.5 })
	return f, t
end
if bar then
	local moneyPill, moneyText = boostPill(5, Color3.fromRGB(80, 200, 90))
	local luckPill, luckText = boostPill(6, Color3.fromRGB(60, 190, 130))
	local fullPill, fullText = boostPill(7, Color3.fromRGB(60, 200, 255))
	fullText.Text = "⚡ FULL BOOST ready"
	task.spawn(function()
		while true do
			local now = os.time()
			local m = (player:GetAttribute("BoostMoneyUntil") or 0) - now
			local l = (player:GetAttribute("BoostLuckUntil") or 0) - now
			moneyPill.Visible = m > 0
			luckPill.Visible = l > 0
			fullPill.Visible = player:GetAttribute("FullBoost") == true
			if m > 0 then
				moneyText.Text = string.format("💰 x2 MONEY %d:%02d", m // 60, m % 60)
			end
			if l > 0 then
				luckText.Text = string.format("🍀 x2 LUCK %d:%02d", l // 60, l % 60)
			end
			task.wait(0.5)
		end
	end)
end

-- the full-boost prize gets used up at launch: say so
player:GetAttributeChangedSignal("FullBoost"):Connect(function()
	if player:GetAttribute("FullBoost") == false and player:GetAttribute("Flying") then
		UIKit.toast("⚡ FULL BOOST! Hold SPACE (or BOOST) to use it", Color3.fromRGB(120, 220, 255))
	end
end)
