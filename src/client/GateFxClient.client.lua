-- Gates, on your screen only (its own script: RocketClient is near Luau's 200-local limit).
-- * Locked gates show a red barrier with the lock sign, open ones none. A gate you bought this
--   session waits green "OPEN!" and its barrier shatters as you fly up to it.
-- * Your first pass through a gate (your best at launch never got past it): sparkles burst from
--   its crowns and the arch glows. Plays again after a rebirth, which resets BestDistance.
-- * Hitting a locked gate: the barrier flashes white-red, its lock sign pops, a red hoop bursts
--   out around the rocket, the camera shakes and one thud plays.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local modules = script.Parent:WaitForChild("ClientModules")
local UIKit = require(modules:WaitForChild("UIKit"))
local Report = require(modules:WaitForChild("FlightReport")) -- RocketClient sets Report.shake

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RED = Color3.fromRGB(255, 70, 90) -- the barrier's own colour (Scenery)
local REST = 0.55 -- a locked barrier's transparency (Scenery)
local LOCK_STROKE = Color3.fromRGB(120, 0, 30) -- the lock sign's outline (Scenery)
local GREEN = Color3.fromRGB(80, 220, 120) -- a gate bought this session, before you reach it
local GOLD = Color3.fromRGB(255, 215, 60)
local SHATTER_AHEAD = 60 -- studs before a green gate where its barrier bursts

-- [stage] = Gate model (the gate into that stage)
local gates = {}
local function scan()
	gates = {}
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	for _, m in ipairs(world:GetDescendants()) do
		if m:IsA("Model") and m.Name == "Gate" and m:GetAttribute("Stage") then
			gates[m:GetAttribute("Stage")] = m
		end
	end
end

-- found on first use (rescanned if the world was rebuilt)
local function gateFor(stage)
	local g = gates[stage]
	if g and g.Parent then
		return g
	end
	scan()
	return gates[stage]
end

local pending = {} -- [stage] = true: bought this session, green until you fly up to it
-- (plain tables: an Instance key in a weak table can drop out while the part still exists)
local home = {} -- [barrier part] = where Scenery built it
local lockText = {} -- [LockText label] = its "locked" text

-- the gate's barrier parts (remembering where they were built, so a shatter can be undone)
local function barriers(g)
	local list = {}
	for _, b in ipairs(g:GetChildren()) do
		if b.Name == "Barrier" and b:IsA("BasePart") then
			home[b] = home[b] or b.CFrame
			table.insert(list, b)
		end
	end
	return list
end

-- Locked: red barrier + lock sign. Open: no barrier. Bought this session: green barrier, "OPEN!".
local function showGate(g)
	local stage = g:GetAttribute("Stage") or 99
	local open = stage <= (player:GetAttribute("UnlockedStage") or 1)
	local fresh = open and pending[stage] == true
	for _, b in ipairs(barriers(g)) do
		b.CFrame = home[b]
		b.Color = fresh and GREEN or RED
		b.Transparency = fresh and 0.5 or open and 1 or REST
		local surface = b:FindFirstChildOfClass("SurfaceGui")
		if surface then
			surface.Enabled = fresh or not open
		end
	end
	local lock = g:FindFirstChild("LockText", true)
	if lock and lock:IsA("TextLabel") then
		lockText[lock] = lockText[lock] or lock.Text
		lock.Text = fresh and "OPEN! ✅" or lockText[lock]
		local stroke = lock:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = fresh and Color3.fromRGB(20, 100, 50) or LOCK_STROKE
		end
	end
end

local function refreshGates()
	scan()
	for _, g in pairs(gates) do
		showGate(g)
	end
end

-- Unlocking: the newest gate turns green until you reach it. A rebirth (or /stage down) closes
-- gates again, so they drop out of pending.
local lastUnlocked -- nil until the save has loaded (loading isn't an unlock)
player:GetAttributeChangedSignal("UnlockedStage"):Connect(function()
	local unlocked = player:GetAttribute("UnlockedStage") or 1
	if lastUnlocked then
		if unlocked > lastUnlocked then
			pending[unlocked] = true
		end
		for stage in pairs(pending) do
			if stage > unlocked then
				pending[stage] = nil
			end
		end
		lastUnlocked = unlocked
	end
	refreshGates()
end)
task.spawn(function()
	repeat
		task.wait(0.2)
	until player:GetAttribute("DataLoaded")
	lastUnlocked = player:GetAttribute("UnlockedStage") or 1
	refreshGates()
end)

-- The green barrier bursts as you fly up to it: its pieces fly out to the sides, spinning and fading.
local function shatter(stage)
	pending[stage] = nil
	local g = gateFor(stage)
	if not g then
		return
	end
	local rng = Random.new()
	local list = barriers(g)
	for i, b in ipairs(list) do
		local surface = b:FindFirstChildOfClass("SurfaceGui")
		if surface then
			surface.Enabled = false
		end
		-- side pieces go their own way, the centered ones alternate
		local z = b.Position.Z
		local side = math.abs(z) > 1 and math.sign(z) or (i % 2 == 0 and 1 or -1)
		local spin = CFrame.Angles(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.5, 1.5))
		local t = TweenService:Create(b, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = (b.CFrame + Vector3.new(0, 0, side * 30)) * spin, Transparency = 1 })
		if i == #list then
			t.Completed:Connect(function()
				showGate(g) -- back where it was built, hidden like any open gate
			end)
		end
		t:Play()
	end
end

-- pooled sparkle emitters, one per crown
local sparklers = {}
local function sparkle(i, pos)
	local e = sparklers[i]
	if not (e and e.Parent and e.Parent.Parent) then
		local p = Instance.new("Part")
		p.Name = "GateSparkles"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
		p.Size = Vector3.one
		p.Parent = workspace
		e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 245, 190), GOLD)
		e.Size = NumberSequence.new(2.6, 0)
		e.Lifetime = NumberRange.new(0.7, 1.3)
		e.Speed = NumberRange.new(14, 32)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 2
		e.Acceleration = Vector3.new(0, -12, 0)
		e.LightEmission = 1
		e.Rate = 0
		e.Parent = p
		sparklers[i] = e
	end
	e.Parent.CFrame = CFrame.new(pos)
	e:Emit(40)
end

-- First pass through a gate: sparkles burst from its crowns and the arch glows neon for a moment.
local glowing = {} -- [gate] = true while its arch glows
local function firstPass(stage)
	local g = gateFor(stage)
	if not g then
		return
	end
	local arch, n = {}, 0
	for _, p in ipairs(g:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "Crown" or p.Name == "Arch") then
			if p.Name == "Crown" then
				n += 1
				sparkle(n, p.Position)
			end
			table.insert(arch, p)
		end
	end
	if glowing[g] then
		return
	end
	glowing[g] = true
	local was = {}
	for i, p in ipairs(arch) do
		was[i] = { p.Material, p.Color }
		p.Material = Enum.Material.Neon
		-- 0.6 s up and 0.6 s back
		TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true), { Color = p.Color:Lerp(Color3.new(1, 1, 1), 0.5) }):Play()
	end
	task.delay(1.2, function()
		for i, p in ipairs(arch) do
			p.Material, p.Color = was[i][1], was[i][2]
		end
		glowing[g] = nil
	end)
end

-- this flight: your best at launch and the gates passed so far
local flight = { best = 0, passed = {} }
player:GetAttributeChangedSignal("Flying"):Connect(function()
	if player:GetAttribute("Flying") then
		flight.best = player:GetAttribute("BestDistance") or 0
		flight.passed = {}
	end
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
	local x = body.Position.X
	-- (the gate into stage s stands at the end of stage s - 1)
	for stage in pairs(pending) do
		if x >= Config.stageEndX(stage - 1) - SHATTER_AHEAD then
			shatter(stage)
		end
	end
	for stage = 2, math.min(player:GetAttribute("UnlockedStage") or 1, Config.NUM_STAGES) do
		local gx = Config.stageEndX(stage - 1)
		if x >= gx and not flight.passed[stage] then
			flight.passed[stage] = true
			if flight.best <= gx - Config.LAUNCH_X + 1 then
				firstPass(stage)
			end
		end
	end
end)

local function flashBarrier(g)
	local stage = g:GetAttribute("Stage") or 99
	for _, b in ipairs(barriers(g)) do
		b.Transparency = 0.05
		b.Color = Color3.new(1, 1, 1)
		local t = TweenService:Create(b, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = REST, Color = RED })
		t.Completed:Connect(function()
			-- unlocked meanwhile: show it as open / green
			if stage <= (player:GetAttribute("UnlockedStage") or 1) then
				showGate(g)
			end
		end)
		t:Play()
	end
	local lock = g:FindFirstChild("LockText", true)
	if lock and lock:IsA("GuiObject") then
		UIKit.bounce(lock)
	end
end

-- a red hoop of glowing pieces bursting out around the rocket, flat on the gate (same build as the
-- sonic boom in FlightFxClient)
local function hoop(pos)
	local frame = CFrame.lookAt(pos, pos + Vector3.xAxis) -- gates face along the path (+X)
	local N = 18
	for i = 1, N do
		local a = (i / N) * math.pi * 2
		local dir = frame.RightVector * math.cos(a) + frame.UpVector * math.sin(a)
		local along = frame.LookVector:Cross(dir)
		local piece = Instance.new("Part")
		piece.Name = "GateHit"
		piece.Anchored, piece.CanCollide, piece.CanQuery, piece.CanTouch, piece.CastShadow = true, false, false, false, false
		piece.Material = Enum.Material.Neon
		piece.Color = (i % 2 == 0) and Color3.fromRGB(255, 160, 170) or RED
		piece.Transparency = 0.1
		piece.Size = Vector3.new(0.6, 0.6, 2.2)
		local from = pos + dir * 4
		piece.CFrame = CFrame.lookAt(from, from + along)
		piece.Parent = workspace
		local to = pos + dir * 20
		TweenService:Create(piece, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(to, to + along), Transparency = 1, Size = Vector3.new(0.3, 0.3, 5) }):Play()
		Debris:AddItem(piece, 0.5)
	end
end

remotes:WaitForChild("Flight").OnClientEvent:Connect(function(kind, info)
	if kind ~= "result" or type(info) ~= "table" or info.reason ~= "gate" then
		return
	end
	local g = gateFor((player:GetAttribute("UnlockedStage") or 1) + 1)
	if g then
		flashBarrier(g)
	end
	local flights = workspace:FindFirstChild("Flights")
	local m = flights and flights:FindFirstChild(player.Name)
	local body = m and m.PrimaryPart
	if body then
		hoop(body.Position)
	end
	if Report.shake then
		Report.shake(1.4)
	end
	UIKit.sound("Hit", 0.6, 0.8)
end)
