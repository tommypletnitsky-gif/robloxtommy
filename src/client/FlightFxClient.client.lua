-- Flight effects (client-only looks):
--   * Wind streaks: two thin white trails off the sides of every flying rocket (yours and other
--     players'), stronger the faster it goes - turning draws curves in the air.
--   * Sonic boom: when you start boosting, a ring bursts out around your rocket with a whoosh.
--   * Stage beat: entering a new stage bursts a big gold ring around your rocket (silent).
--   * Thruster cars: layered cold-gas jets (core blast, billowing cloud, cone) that build up the
--     longer the car keeps pushing one way, and a vapour blast off the road when flying low.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local flights = workspace:WaitForChild("Flights")

local streaks = {} -- [rocket model] = { body, trails = { Trail, Trail } }

local function addStreaks(model)
	local body = model:WaitForChild("Body", 5)
	task.wait(0.1) -- (the Car attribute arrives with the model)
	if not body or streaks[model] or model:GetAttribute("Car") then -- (cars: no streaks)
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

-- Thruster cars (Config rocket `thrusters`): realistic cold-gas jets. Each jet's power (0..1)
-- drives three layers (RocketModel._gasJet): the bright Core blast, the billowing Gas cloud and
-- the Cone beam. A jet starts as a short hiss and builds into a full blast the longer the car keeps
-- pushing that way. Your own car reads your steering directly (RocketClient puts it in the model's
-- local Jet* attributes); other players' cars are read from how they move.
-- Flying low, the lift jets blast a cloud of dust / vapour off the road under the car.
local jetCars = {} -- [model] = { body, flame, jets, hold, ground }
local function addJets(model)
	local body = model:WaitForChild("Body", 5)
	if not body or jetCars[model] then
		return
	end
	task.wait(0.2) -- (let the rest of the model replicate)
	local jets = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == "Thruster" and d:GetAttribute("Dir") then
			local coneB = d:FindFirstChild("ConeB")
			table.insert(jets, {
				dir = d:GetAttribute("Dir"),
				holder = d,
				gas = d:FindFirstChild("Gas"),
				cone = d:FindFirstChild("Cone"),
				glow = d:FindFirstChild("Glow"),
				glowB = d:FindFirstChild("GlowB"),
				tail = coneB and coneB:FindFirstChild("Tail"),
				light = d:FindFirstChild("Light"),
				coneB = coneB,
				axis = coneB and coneB:GetAttribute("Axis") or Vector3.new(0, -1, 0),
				power = 0,
				seed = math.random() * 10,
			})
		end
	end
	if #jets == 0 then
		return
	end
	-- road blast: an invisible point under the car that puffs vapour out sideways along the road
	local ground = Instance.new("Part")
	ground.Name = "JetGroundFx"
	ground.Anchored, ground.CanCollide, ground.CanQuery, ground.CanTouch = true, false, false, false
	ground.Transparency = 1
	ground.Size = Vector3.new(6, 0.2, 4)
	ground.Parent = workspace
	local billow = Instance.new("ParticleEmitter")
	billow.Texture = "rbxasset://textures/particles/smoke_main.dds"
	billow.Color = ColorSequence.new(Color3.fromRGB(250, 250, 252), Color3.fromRGB(205, 210, 220))
	billow.LightInfluence = 0.7
	billow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(0.4, 5), NumberSequenceKeypoint.new(1, 9) })
	billow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1) })
	billow.Lifetime = NumberRange.new(0.8, 1.6)
	billow.Speed = NumberRange.new(10, 22)
	billow.Drag = 2.5
	billow.SpreadAngle = Vector2.new(80, 80) -- (Top + wide spread = rolls out along the ground)
	billow.Acceleration = Vector3.new(0, 1.5, 0)
	billow.EmissionDirection = Enum.NormalId.Top
	billow.Rotation = NumberRange.new(0, 360)
	billow.RotSpeed = NumberRange.new(-30, 30)
	billow.Rate = 0
	billow.Parent = ground
	jetCars[model] = { body = body, model = model, flame = model:FindFirstChild("Flame", true), jets = jets, hold = { L = 0, R = 0, U = 0, D = 0, B = 0 }, ground = ground, billow = billow }
end
flights.ChildAdded:Connect(function(m)
	task.spawn(addJets, m)
end)
for _, m in ipairs(flights:GetChildren()) do
	task.spawn(addJets, m)
end
local function dropCar(m)
	local c = jetCars[m]
	if c then
		c.ground:Destroy()
		jetCars[m] = nil
	end
end
flights.ChildRemoved:Connect(dropCar)

local JET_RAMP = 1.2 -- seconds of pushing one way until those jets are at full blast
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for m, c in pairs(jetCars) do
		if not m.Parent or not c.body.Parent then
			dropCar(m)
			continue
		end
		local rear = c.flame and c.flame:FindFirstChild("Trail")
		local flying = rear and rear.Enabled and m:GetAttribute("InCannon") ~= true
		-- how hard each jet group is pushing: yours from RocketClient, others' from their motion
		local want = {}
		if m:GetAttribute("JetD") ~= nil then
			for _, k in ipairs({ "L", "R", "U", "D", "B" }) do
				want[k] = m:GetAttribute("Jet" .. k) or 0
			end
		else
			local v = c.body.AssemblyLinearVelocity
			local push = { L = math.clamp(v.Z / 30, 0, 1), R = math.clamp(-v.Z / 30, 0, 1), U = math.clamp(-v.Y / 40, 0, 1) }
			for dir, p in pairs(push) do
				c.hold[dir] = p > 0.12 and math.min(c.hold[dir] + dt, JET_RAMP) or math.max(0, c.hold[dir] - dt * 3)
				want[dir] = p * (0.3 + 0.7 * c.hold[dir] / JET_RAMP)
			end
			want.D = math.clamp(0.3 + v.Y / 40, 0.25, 1)
			want.B = m:GetAttribute("Boosting") and 1 or 0.2
			-- puffs like the owner sees them (short bursts, faster and merging the harder it pushes)
			c.puff = c.puff or {}
			for dir, d in pairs(want) do
				local st = c.puff[dir] or { nextAt = 0, untilT = 0 }
				c.puff[dir] = st
				if d > 0.05 and d <= 0.85 then
					if now >= st.nextAt then
						st.untilT = now + 0.11 + 0.08 * d
						st.nextAt = now + 0.42 - 0.35 * d
					end
					want[dir] = now < st.untilT and math.max(0.35, d) or 0
				end
			end
		end
		local lowest = math.huge
		for _, j in ipairs(c.jets) do
			local target = flying and (want[j.dir] or 0) or 0
			-- a jet opens with a sharp kick and closes a little slower (valves)
			j.power += (target - j.power) * (1 - math.exp(-dt * (target > j.power and 30 or 16))) -- (valves: snap open, close fast)
			-- turbulence: real jets flutter a little
			local flutter = 1 + math.sin(now * 37 + j.seed) * 0.06 + math.sin(now * 23.3 + j.seed * 2) * 0.05
			local p = j.power * flutter
			local on = p > 0.04
			-- column length: lift jets reach down toward the road (and stop at it), side / top /
			-- rear jets are shorter
			local len
			if j.dir == "D" then
				local reach = j.holder.Position.Y - Config.pathY(j.holder.Position.X) - 0.3
				len = math.clamp(1.8 + 3.4 * p, 0.5, math.max(0.5, reach))
			elseif j.dir == "B" then
				len = 2 + 4.5 * p
			elseif j.dir == "U" then
				len = 1.2 + 2.8 * p
			else
				len = 1.6 + 4.4 * p
			end
			if j.cone and j.coneB then
				j.cone.Enabled = on
				j.glow.Enabled = on
				if on then
					j.coneB.Position = j.axis * len
					j.glowB.Position = j.axis * len * (0.25 + 0.15 * p)
					j.cone.Width0 = 0.55 + 0.3 * p
					j.cone.Width1 = 0.7 + 0.55 * p
					j.cone.TextureLength = math.max(1, len * 0.6)
					j.glow.Width0 = 0.3 + 0.15 * p
					j.glow.Width1 = 0.38 + 0.2 * p
				end
			end
			if j.gas then
				j.gas.Rate = on and (30 + 150 * p) or 0
				j.gas.Lifetime = NumberRange.new(len / 58)
			end
			if j.tail then
				j.tail.Rate = on and (8 + 70 * p) or 0
			end
			if j.light then
				j.light.Brightness = on and 0.4 + 1.6 * p or 0
			end
		end
		-- road blast when low
		local pos = c.body.Position
		local road = Config.pathY(pos.X)
		local height = pos.Y - road
		local lift = flying and (want.D or 0) or 0
		local k = math.clamp(1 - (height - 3) / 6, 0, 1) * lift
		c.ground.CFrame = CFrame.new(pos.X, road + 0.3, pos.Z)
		c.billow.Rate = k > 0.05 and 30 + 90 * k or 0
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
