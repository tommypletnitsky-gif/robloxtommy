-- Top-of-screen bar for things that happen to the whole server (EventServer):
--   server event pill (x2 Money / Lucky Eggs / Fuel Frenzy + time left), friend / group boost pill,
--   race pill with a JOIN button, live race standings while you race, and the race results.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RaceJoin = remotes:WaitForChild("RaceJoin")
local RaceResult = remotes:WaitForChild("RaceResult")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local GOLD = Color3.fromRGB(255, 190, 40)
local GREEN = Color3.fromRGB(80, 200, 90)
local SKY = Color3.fromRGB(90, 190, 255)

-- (kept to the middle of the screen, clear of Roblox's own top-corner buttons; extra pills wrap
-- into a second row instead of running off the edges)
local bar = make("Frame", { Parent = UIKit.gui(), Name = "EventBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0.62, 0, 0, 110), BackgroundTransparency = 1 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Top, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
UIKit.hudScale(bar)

-- a glossy rounded pill with text (and room for a button on the right)
local function pill(order, color, width)
	local f = make("Frame", { Parent = bar, LayoutOrder = order, Size = UDim2.fromOffset(width, 46), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, { UIKit.corner(23), UIKit.stroke(3.5), UIKit.gloss(color) })
	make("Frame", { Parent = f, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, Position = UDim2.fromScale(0.06, 0.1), Size = UDim2.fromScale(0.88, 0.32) }, { UIKit.corner(10) })
	local text = label({ Parent = f, Position = UDim2.fromOffset(14, 7), Size = UDim2.new(1, -28, 1, -14), Text = "", StrokeThickness = 2.5 })
	return f, text
end

local eventPill, eventText = pill(1, GREEN, 290)
local boostPill, boostText = pill(2, SKY, 200)
local racePill, raceText = pill(3, GOLD, 330)
raceText.Size = UDim2.new(1, -140, 1, -14)
raceText.TextXAlignment = Enum.TextXAlignment.Left
local joinBtn = UIKit.button({ Parent = racePill, Text = "JOIN!", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(118, 40), Radius = 20, ZIndex = 3 })
joinBtn.Instance.Activated:Connect(function()
	local ok, msg = RaceJoin:InvokeServer()
	UIKit.result(ok, msg)
end)

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Live race standings (left side, only while you're racing) ------------------------------------
local standings = make("Frame", { Parent = UIKit.gui(), Name = "RaceStandings", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.45, 0), Size = UDim2.fromOffset(250, 230), BackgroundColor3 = Color3.fromRGB(30, 30, 50), BackgroundTransparency = 0.35, Visible = false }, { UIKit.corner(18), UIKit.stroke(3) })
UIKit.hudScale(standings)
label({ Parent = standings, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 32), Text = "🏁 RACE", TextColor3 = GOLD, StrokeThickness = 3 })
local rows = {}
for i = 1, 6 do
	rows[i] = label({ Parent = standings, Position = UDim2.fromOffset(12, 40 + (i - 1) * 30), Size = UDim2.new(1, -24, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Text = "", StrokeThickness = 2 })
end

local function refreshStandings()
	local flights = workspace:FindFirstChild("Flights")
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRace") then
			local m = flights and flights:FindFirstChild(p.Name)
			local body = m and m.PrimaryPart
			local d = body and math.max(0, body.Position.X - Config.LAUNCH_X) or 0
			table.insert(list, { p = p, d = d })
		end
	end
	table.sort(list, function(a, b)
		return a.d > b.d
	end)
	for i, row in ipairs(rows) do
		local e = list[i]
		row.Text = e and (i .. ". " .. e.p.DisplayName .. "  " .. Config.meters(e.d)) or ""
		row.TextColor3 = (e and e.p == player) and Color3.fromRGB(255, 230, 90) or Color3.new(1, 1, 1)
	end
end

-- Refresh everything a few times a second --------------------------------------------------------
task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		-- event
		local key = Config.activeEvent()
		if key then
			local ev = Config.Events[key]
			eventPill.Visible = true
			eventText.Text = "⚡ " .. ev.name .. "  " .. clock((workspace:GetAttribute("EventEnds") or now) - now)
			local grad = eventPill:FindFirstChildOfClass("UIGradient")
			if eventPill:GetAttribute("Key") ~= key then
				eventPill:SetAttribute("Key", key)
				grad:Destroy()
				UIKit.gloss(ev.color).Parent = eventPill
			end
		else
			eventPill.Visible = false
		end
		-- friends / group
		local friends = math.min(player:GetAttribute("Friends") or 0, Config.FRIEND_BOOST_MAX)
		local pct = friends * Config.FRIEND_BOOST + (player:GetAttribute("InGroup") and Config.GROUP_BOOST or 0)
		boostPill.Visible = pct > 0
		boostText.Text = "👥 +" .. math.floor(pct * 100 + 0.5) .. "% money"
		-- race
		local state = workspace:GetAttribute("RaceState")
		local inRace = player:GetAttribute("InRace") == true
		if state == "join" then
			racePill.Visible = true
			raceText.Text = "🏁 RACE in " .. clock((workspace:GetAttribute("RaceStartsAt") or now) - now)
			joinBtn.Instance.Visible = true
			if inRace ~= (joinBtn.Label.Text == "✔ IN") then
				joinBtn.setText(inRace and "✔ IN" or "JOIN!")
				joinBtn.setColor(inRace and Color3.fromRGB(150, 160, 185) or GREEN)
			end
		elseif state == "running" then
			racePill.Visible = true
			raceText.Text = "🏁 RACE ON!"
			joinBtn.Instance.Visible = false
		else
			racePill.Visible = false
		end
		standings.Visible = state == "running" and inRace and player:GetAttribute("Flying") == true
		if standings.Visible then
			refreshStandings()
		end
		task.wait(0.25)
	end
end)

-- Results -----------------------------------------------------------------------------------------
local window, list = UIKit.window("Race Results", GOLD, UDim2.fromOffset(560, 470), "Trophy")
local PLACE_COLOR = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 215, 230), Color3.fromRGB(225, 150, 90) }

RaceResult.OnClientEvent:Connect(function(results)
	local mine = nil
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, r in ipairs(results) do
		local row = UIKit.row(list, i, 64)
		local medal = make("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = PLACE_COLOR[r.place] or Color3.fromRGB(170, 180, 205), ZIndex = 12 }, { UIKit.corner(24), UIKit.stroke(3) })
		label({ Parent = medal, Size = UDim2.fromScale(1, 1), Text = tostring(r.place), ZIndex = 13 })
		label({ Parent = row, Position = UDim2.fromOffset(70, 8), Size = UDim2.new(0.5, -70, 1, -16), TextXAlignment = Enum.TextXAlignment.Left, Text = r.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
		label({ Parent = row, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.new(0.5, -20, 1, -16), TextXAlignment = Enum.TextXAlignment.Right, Text = Config.meters(r.distance) .. "  •  +$" .. Config.abbreviate(r.prize), TextColor3 = Color3.fromRGB(40, 150, 60), StrokeThickness = 0, ZIndex = 12 })
		if r.userId == player.UserId then
			mine = r
			local st = row:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = GOLD
				st.Thickness = 5
			end
		end
	end
	if not mine then
		return
	end
	-- let the landing screen finish and get back to the lobby first
	local t0 = os.clock()
	repeat
		task.wait(0.25)
	until not player:GetAttribute("Flying") or os.clock() - t0 > 10
	task.wait(0.5)
	if mine.place == 1 and #results >= 2 then
		UIKit.celebrate("🏆 YOU WON THE RACE!", "+$" .. Config.abbreviate(mine.prize), GOLD)
	else
		UIKit.toast("🏁 You finished #" .. mine.place .. ": +$" .. Config.abbreviate(mine.prize), Color3.fromRGB(255, 220, 120))
	end
	if not player:GetAttribute("Flying") and not window.Visible then
		UIKit.toggle(window)
	end
end)
