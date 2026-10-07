-- Your best distance, marked on the path: two flag poles with a checkered banner across the lane
-- and a "BEST 442m" sign (only on your screen). Flying past it pops "NEW BEST!" right away:
-- the banner breaks apart, gold sparkles burst and the camera kicks (RocketClient, via BestFx).
-- Rival flags: slim poles on the left of the lane for up to 4 other players' bests that are
-- ahead of yours and inside your gate. Flying past one pops a silent toast.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))

local player = Players.LocalPlayer
local HALF = Config.PATH_HALF_WIDTH + 4

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- built once around the origin, moved with PivotTo
local marker = Instance.new("Model")
marker.Name = "MyBestMarker"
local GOLD = Color3.fromRGB(255, 200, 50)
for _, side in ipairs({ -1, 1 }) do
	part(marker, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(26, 1.2, 1.2), CFrame = CFrame.new(0, 13, side * HALF) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.new(1, 1, 1) })
	part(marker, { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = CFrame.new(0, 26.5, side * HALF), Color = GOLD })
end
-- checkered banner across the top (its squares scatter when you fly through your old best)
local COLS = 16
local squares = {} -- { part = Part, home = CFrame relative to the marker's pivot }
for i = 0, COLS - 1 do
	local z = -HALF + (i + 0.5) * (HALF * 2 / COLS)
	for row = 0, 1 do
		local home = CFrame.new(0, 23.4 + row * 1.6, z)
		local sq = part(marker, { Size = Vector3.new(0.3, 1.6, HALF * 2 / COLS), CFrame = home, Color = ((i + row) % 2 == 0) and Color3.new(1, 1, 1) or Color3.fromRGB(30, 30, 40), CastShadow = false })
		table.insert(squares, { part = sq, home = home })
	end
end
local signPart = part(marker, { Name = "Sign", Size = Vector3.new(0.4, 3, 12), CFrame = CFrame.new(0, 28.5, 0), Transparency = 1 })
-- one emitter for the gold burst when the banner breaks (Rate 0: only :Emit)
local sparkles = Instance.new("ParticleEmitter")
sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), GOLD)
sparkles.Size = NumberSequence.new(2.2, 0)
sparkles.Lifetime = NumberRange.new(0.8, 1.4)
sparkles.Speed = NumberRange.new(10, 26)
sparkles.SpreadAngle = Vector2.new(180, 180)
sparkles.Acceleration = Vector3.new(0, -18, 0)
sparkles.Drag = 1.5
sparkles.LightEmission = 1
sparkles.LightInfluence = 0
sparkles.Rate = 0
sparkles.Parent = signPart
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromScale(14, 3.6)
bb.LightInfluence = 0
bb.MaxDistance = 1200
bb.Parent = signPart
local text = UIKit.label({ Parent = bb, Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = GOLD, StrokeThickness = 4 })
marker.WorldPivot = CFrame.new()

-- put the banner back together (after a break, or when the marker moves)
local tweens = {}
local function mend()
	for _, t in ipairs(tweens) do
		t:Cancel()
	end
	table.clear(tweens)
	local pivot = marker:GetPivot()
	for _, s in ipairs(squares) do
		s.part.CFrame = pivot * s.home
		s.part.Transparency = 0
	end
end

-- the squares fly out to the sides (spinning, up, fading) like a broken finish tape
local function breakTape()
	local pivot = marker:GetPivot()
	local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, s in ipairs(squares) do
		local side = s.home.Position.Z >= 0 and 1 or -1
		local to = CFrame.new(s.home.Position + Vector3.new(0, 8, side * (6 + math.random() * 10)))
			* CFrame.Angles((math.random() - 0.5) * 6, (math.random() - 0.5) * 6, (math.random() - 0.5) * 6)
		local t = TweenService:Create(s.part, info, { CFrame = pivot * to, Transparency = 1 })
		t:Play()
		table.insert(tweens, t)
	end
	sparkles:Emit(60)
end

local shownBest = -1
local function place()
	local best = player:GetAttribute("BestDistance") or 0
	if best < 30 then
		marker.Parent = nil
		return
	end
	local x = Config.LAUNCH_X + best
	marker:PivotTo(CFrame.new(x, Config.pathY(x), 0))
	mend()
	text.Text = "🏆 BEST " .. Config.meters(best)
	marker.Parent = workspace
	shownBest = best
end
player:GetAttributeChangedSignal("BestDistance"):Connect(place)

-- rival flags: a pool of 4, built once around the origin, moved with PivotTo
local RIVAL_COLORS = { Color3.fromRGB(255, 95, 115), Color3.fromRGB(80, 170, 255), Color3.fromRGB(110, 220, 120), Color3.fromRGB(190, 125, 255) }
local flags = {} -- { model, bb, label, id = UserId or nil, name, best }
for i, color in ipairs(RIVAL_COLORS) do
	local m = Instance.new("Model")
	m.Name = "RivalFlag" .. i
	part(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(18, 0.6, 0.6), CFrame = CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.new(1, 1, 1) })
	local flag = part(m, { Size = Vector3.new(0.2, 2.6, 4), CFrame = CFrame.new(0, 16.4, 2.1), Color = color, CastShadow = false })
	m.WorldPivot = CFrame.new()
	local fb = Instance.new("BillboardGui")
	fb.Size = UDim2.fromScale(16, 2.6)
	fb.LightInfluence = 0
	fb.MaxDistance = 600
	fb.Parent = flag
	local l = UIKit.label({ Parent = fb, Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = color, StrokeThickness = 3 })
	table.insert(flags, { model = m, bb = fb, label = l })
end

-- distance to your gate (the finish once all is unlocked). A flight held there saves exactly this
-- as its distance, though your rocket flies a bit past it on your screen.
local function gateDistance()
	return Config.stageEndX(math.min(player:GetAttribute("UnlockedStage") or 1, Config.NUM_STAGES)) - Config.LAUNCH_X
end

-- other players' bests ahead of yours that you can still pass (short of your gate), nearest first
local function rebuildRivals(leaving)
	local list = {}
	if player:GetAttribute("DataLoaded") then
		local myBest = player:GetAttribute("BestDistance") or 0
		local gate = gateDistance()
		for _, p in ipairs(Players:GetPlayers()) do
			local best = p:GetAttribute("BestDistance") or 0
			-- (the same 5-stud tolerance GameServer uses for "reached the gate")
			if p ~= player and p ~= leaving and best >= 30 and best > myBest and best < gate - 5 then
				table.insert(list, { id = p.UserId, name = p.DisplayName, best = best })
			end
		end
		table.sort(list, function(a, b)
			return a.best < b.best
		end)
	end
	local prev, lift = -math.huge, 0
	for i, f in ipairs(flags) do
		local r = list[i]
		if r then
			local x = Config.LAUNCH_X + r.best
			f.model:PivotTo(CFrame.new(x, Config.pathY(x), -HALF + 6))
			-- flags close together: stack their signs so the names stay readable
			lift = (r.best - prev < 40) and lift + 2.8 or 0
			prev = r.best
			f.bb.StudsOffset = Vector3.new(0, 3.2 + lift, 0)
			f.label.Text = "🏁 " .. r.name .. " " .. Config.meters(r.best)
			f.id, f.name, f.best = r.id, r.name, r.best
			f.model.Parent = workspace
		else
			f.id = nil
			f.model.Parent = nil
		end
	end
end

local watched = {} -- [Player] = their BestDistance connection
local function watch(p)
	if p ~= player and not watched[p] then
		watched[p] = p:GetAttributeChangedSignal("BestDistance"):Connect(function()
			rebuildRivals()
		end)
	end
	rebuildRivals()
end
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end
Players.PlayerRemoving:Connect(function(p)
	if watched[p] then
		watched[p]:Disconnect()
		watched[p] = nil
	end
	rebuildRivals(p) -- still in GetPlayers() while it leaves
end)
for _, attr in ipairs({ "BestDistance", "UnlockedStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		rebuildRivals()
	end)
end

task.spawn(function()
	repeat
		task.wait(0.5)
	until player:GetAttribute("DataLoaded")
	place()
	rebuildRivals()
end)

-- passing your old best (and rivals' flags) while flying
local celebrated = false
local passed = {} -- [UserId] = true: rival flags already toasted this flight
player:GetAttributeChangedSignal("Flying"):Connect(function()
	celebrated = false
	table.clear(passed)
	mend() -- whole again even if the flight didn't end up as a new best
end)
RunService.Heartbeat:Connect(function()
	if not player:GetAttribute("Flying") then
		return
	end
	local flights = workspace:FindFirstChild("Flights")
	local m = flights and flights:FindFirstChild(player.Name)
	local body = m and m.PrimaryPart
	if not body then
		return
	end
	local dist = body.Position.X - Config.LAUNCH_X
	-- a best that already sits at your gate can't be beaten (the flight is held there)
	if not celebrated and shownBest >= 30 and dist > shownBest and shownBest < gateDistance() - 5 then
		celebrated = true
		breakTape()
		UIKit.toast("🏆 NEW BEST! Keep going!", GOLD)
		UIKit.sound("Jingle", 0.5, 1.2)
		player:SetAttribute("BestFx", os.clock()) -- (client-only, like StageFx) RocketClient: camera beat
	end
	for _, f in ipairs(flags) do
		if f.id and not passed[f.id] and dist > f.best then
			passed[f.id] = true
			UIKit.toast("You passed " .. f.name .. "'s best! 🏁") -- no sound
		end
	end
end)
