-- Flight effects (client-only looks):
--   * Wind streaks: two thin white trails off the sides of every flying rocket (yours and other
--     players'), stronger the faster it goes - turning draws curves in the air.
--   * Sonic boom: when you start boosting, a ring bursts out around your rocket with a whoosh.
--   * Stage beat: entering a new stage bursts a big gold ring around your rocket (silent).
--   * Thruster cars: white cold-gas jets that grow the longer the car keeps moving one way.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))

local player = Players.LocalPlayer
local flights = workspace:WaitForChild("Flights")

local streaks = {} -- [rocket model] = { body, trails = { Trail, Trail } }

local function addStreaks(model)
	local body = model:WaitForChild("Body", 5)
	if not body or streaks[model] then
		return
	end
	local half = body.Size.Y * 0.5 + 0.9 -- just outside the hull
	local back = -body.Size.X * 0.3
	local trails = {}
	for _, side in ipairs({ -1, 1 }) do
		local a0 = Instance.new("Attachment")
		a0.Name = "StreakA"
		a0.Position = Vector3.new(back, 0.3, side * half)
		a0.Parent = body
		local a1 = Instance.new("Attachment")
		a1.Name = "StreakB"
		a1.Position = Vector3.new(back, -0.3, side * half)
		a1.Parent = body
		local t = Instance.new("Trail")
		t.Attachment0, t.Attachment1 = a0, a1
		t.Lifetime = 0.55
		t.MinLength = 0.2
		t.FaceCamera = true
		t.LightEmission = 0.3
		t.LightInfluence = 0
		t.Color = ColorSequence.new(Color3.new(1, 1, 1))
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
		t.Enabled = false
		t.Parent = body
		table.insert(trails, t)
	end
	streaks[model] = { body = body, trails = trails }
end

flights.ChildAdded:Connect(function(m)
	task.spawn(addStreaks, m)
end)
for _, m in ipairs(flights:GetChildren()) do
	task.spawn(addStreaks, m)
end
flights.ChildRemoved:Connect(function(m)
	streaks[m] = nil
end)

-- streaks only show at speed (and never while a rocket waits inside the cannon)
RunService.Heartbeat:Connect(function()
	for m, s in pairs(streaks) do
		if not m.Parent or not s.body.Parent then
			streaks[m] = nil
		else
			local speed = s.body.AssemblyLinearVelocity.Magnitude
			local on = speed > 35 and m:GetAttribute("InCannon") ~= true
			local fade = math.clamp((speed - 35) / 120, 0, 1)
			for _, t in ipairs(s.trails) do
				t.Enabled = on
				if on then
					t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75 - fade * 0.45), NumberSequenceKeypoint.new(1, 1) })
				end
			end
		end
	end
end)

-- Thruster cars (Config rocket `thrusters`): white cold-gas jets that push the car the way it's
-- moving. A jet starts as a small puff and grows into a long blast the longer the car keeps going
-- that way (RocketClient also makes the turn itself stronger the longer you hold it). Read from
-- every car's velocity, so you see other players' jets too.
local jetCars = {} -- [model] = { body, flame, jets = { {emitter, dir} }, hold = {L=,R=,U=,D=} }
local function addJets(model)
	local body = model:WaitForChild("Body", 5)
	if not body or jetCars[model] then
		return
	end
	task.wait(0.2) -- (let the rest of the model replicate)
	local jets = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == "Thruster" and d:GetAttribute("Dir") then
			local e = d:FindFirstChild("Gas")
			if e then
				table.insert(jets, { emitter = e, dir = d:GetAttribute("Dir") })
			end
		end
	end
	if #jets > 0 then
		jetCars[model] = { body = body, flame = model:FindFirstChild("Flame", true), jets = jets, hold = { L = 0, R = 0, U = 0, D = 0 } }
	end
end
flights.ChildAdded:Connect(function(m)
	task.spawn(addJets, m)
end)
for _, m in ipairs(flights:GetChildren()) do
	task.spawn(addJets, m)
end
flights.ChildRemoved:Connect(function(m)
	jetCars[m] = nil
end)

local JET_RAMP = 1.2 -- seconds of holding a direction until its jets are at full blast
RunService.Heartbeat:Connect(function(dt)
	for m, c in pairs(jetCars) do
		if not m.Parent or not c.body.Parent then
			jetCars[m] = nil
			continue
		end
		local rear = c.flame and c.flame:FindFirstChild("Trail")
		local flying = rear and rear.Enabled and m:GetAttribute("InCannon") ~= true
		local v = c.body.AssemblyLinearVelocity
		-- how hard the car is being pushed each way (sideways speed 0..32+, up / down speed)
		local push = {
			L = math.clamp(v.Z / 30, 0, 1), -- moving right (+Z): the LEFT jets fire (they point left)
			R = math.clamp(-v.Z / 30, 0, 1),
			D = math.clamp(0.35 + v.Y / 40, 0, 1), -- under the car: always a little (it hovers), more going up
			U = math.clamp(-v.Y / 40, 0, 1),
		}
		for dir, p in pairs(push) do
			local h = c.hold[dir]
			c.hold[dir] = (flying and p > 0.12) and math.min(h + dt, JET_RAMP) or math.max(0, h - dt * 3)
		end
		for _, j in ipairs(c.jets) do
			local p = flying and push[j.dir] or 0
			local grow = c.hold[j.dir] / JET_RAMP -- 0 = just started, 1 = held long
			local power = p * (0.3 + 0.7 * grow) -- starts as a little puff, builds up the longer you hold
			if j.dir == "D" then
				power = flying and math.max(power, 0.25) or 0
			end
			j.emitter.Rate = power > 0.03 and (25 + 140 * power) or 0
			j.emitter.Speed = NumberRange.new(14 + 34 * power, 22 + 46 * power)
		end
	end
end)

-- Drivers of thruster cars sit inside behind the tinted glass: hide their bodies (on every screen)
-- while their character has the InCar attribute (GameServer sets it at liftoff, clears on landing).
local hidden = {} -- [character] = true
RunService.Heartbeat:Connect(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char then
			local inCar = char:GetAttribute("InCar") == true
			if inCar or hidden[char] then
				for _, d in ipairs(char:GetDescendants()) do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.LocalTransparencyModifier = inCar and 1 or 0
					end
				end
				hidden[char] = inCar or nil
			end
		end
	end
end)

-- A hoop of glowing pieces that bursts outward around `center` (a solid disc would cover the whole
-- screen: the camera sits right behind the rocket). Every other piece is white.
local function hoop(center, forward, r0, r1, color, n, life)
	local frame = CFrame.lookAt(center, center + forward)
	local k = r1 / 17 -- bigger hoops get longer pieces so they don't look dotted
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local dir = frame.RightVector * math.cos(a) + frame.UpVector * math.sin(a)
		local piece = Instance.new("Part")
		piece.Name = "SonicBoom"
		piece.Anchored, piece.CanCollide, piece.CanQuery, piece.CanTouch, piece.CastShadow = true, false, false, false, false
		piece.Material = Enum.Material.Neon
		piece.Color = (i % 2 == 0) and color or Color3.new(1, 1, 1)
		piece.Transparency = 0.15
		piece.Size = Vector3.new(0.5, 0.5, 2.2 * k)
		local from = center + dir * r0
		piece.CFrame = CFrame.lookAt(from, from + frame.LookVector:Cross(dir)) -- lies along the hoop
		piece.Parent = workspace
		local to = center + dir * r1 + forward * 4
		TweenService:Create(piece, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(to, to + frame.LookVector:Cross(dir)), Transparency = 1, Size = Vector3.new(0.25, 0.25, 4 * k) }):Play()
		game:GetService("Debris"):AddItem(piece, life + 0.03)
	end
end

local function myBody()
	local m = flights:FindFirstChild(player.Name)
	return m and m.PrimaryPart
end

-- Sonic boom when your boost kicks in
local function sonicBoom()
	local body = myBody()
	if not body then
		return
	end
	hoop(body.Position, body.CFrame.XVector, 3.5, 17, Color3.fromRGB(150, 230, 255), 18, 0.42) -- rockets point along their +X
	UIKit.sound("Whoosh", 0.55, 1.35)
end

player:GetAttributeChangedSignal("BoostFx"):Connect(function()
	if player:GetAttribute("BoostFx") then
		sonicBoom()
	end
end)

-- Stage beat: a big gold hoop (no sound) when you fly into a new stage (RocketClient sets StageFx)
player:GetAttributeChangedSignal("StageFx"):Connect(function()
	local stage = player:GetAttribute("StageFx")
	local body = myBody()
	if stage and stage > 1 and body then
		hoop(body.Position, Vector3.xAxis, 8, 34, Color3.fromRGB(255, 200, 60), 24, 0.55)
	end
end)
