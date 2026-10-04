-- Lobby life (client-only visuals): spinning radar dishes, blinking beacons, bobbing balloons,
-- and toy rockets that blast off from the little pads every few seconds and pop into sparkles.
-- Only runs while the camera is near the lobby, so it costs nothing out on the flight path.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RocketModel = require(ReplicatedStorage.Shared:WaitForChild("RocketModel"))

local camera = workspace.CurrentCamera
local LOBBY = Vector3.new(-95, 0, 0)

local function tracked(tagName, onAdd)
	local list = {}
	local function add(inst)
		list[inst] = onAdd(inst)
	end
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(inst)
		list[inst] = nil
	end)
	return list
end

local spinners = tracked("LobbySpin", function(m)
	return { base = m:GetPivot(), speed = m:GetAttribute("SpinSpeed") or 1 }
end)
local bobbers = tracked("LobbyBob", function(m)
	return { base = m:GetPivot(), phase = m:GetAttribute("Phase") or 0 }
end)
local blinkers = tracked("LobbyBlink", function(p)
	return { phase = math.random() * 2 }
end)
local pads = tracked("MiniPad", function(p)
	return true
end)

-- Toy rocket: climbs with a smoke trail, then bursts into colored sparkles.
local BURST_COLORS = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 200, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(120, 255, 150) }
local function launchToy(pad)
	local ids = { "Starter", "Bottle", "Firework", "Turbo" }
	local start = pad.Position + Vector3.new(0, 2.5, 0)
	local rocket = RocketModel.build(Config.getRocket(ids[math.random(1, #ids)]), 0.45, false, CFrame.new(start) * CFrame.Angles(0, 0, math.pi / 2))
	for _, d in ipairs(rocket:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CastShadow = false
		end
	end
	rocket.Parent = workspace
	RocketModel.setThrust(rocket, true)
	local height = math.random(70, 110)
	local drift = Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - t0) / 2.2
		if t >= 1 or not rocket.Parent then
			conn:Disconnect()
			if rocket.Parent then
				local pos = rocket:GetPivot().Position
				local burst = Instance.new("Part")
				burst.Anchored = true
				burst.CanCollide = false
				burst.CanQuery = false
				burst.Transparency = 1
				burst.Size = Vector3.one
				burst.CFrame = CFrame.new(pos)
				burst.Parent = workspace
				local e = Instance.new("ParticleEmitter")
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				local c = BURST_COLORS[math.random(1, #BURST_COLORS)]
				e.Color = ColorSequence.new(c, Color3.new(1, 1, 1))
				e.LightEmission = 1
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.2) })
				e.Lifetime = NumberRange.new(0.8, 1.3)
				e.Speed = NumberRange.new(18, 30)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Acceleration = Vector3.new(0, -12, 0)
				e.Rate = 0
				e.Parent = burst
				e:Emit(70)
				rocket:Destroy()
				Debris:AddItem(burst, 2)
			end
			return
		end
		local ease = t * t -- accelerates upward
		local pos = start + Vector3.new(0, ease * height, 0) + drift * ease
		-- nose up (+X turned to +Y), spinning around its long axis as it climbs
		rocket:PivotTo(CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(t * 9, 0, 0))
	end)
end

local nextToy = os.clock() + 2
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if (camera.CFrame.Position - LOBBY).Magnitude > 450 then
		return
	end
	for m, s in pairs(spinners) do
		m:PivotTo(s.base * CFrame.Angles(0, now * s.speed, 0))
	end
	for m, s in pairs(bobbers) do
		m:PivotTo(s.base + Vector3.new(0, math.sin(now * 1.4 + s.phase) * 0.8, 0))
	end
	for p, s in pairs(blinkers) do
		p.Transparency = ((now + s.phase) % 1.2) < 0.6 and 0 or 0.85
	end
	if now >= nextToy then
		nextToy = now + math.random(30, 70) / 10
		local list = {}
		for p in pairs(pads) do
			table.insert(list, p)
		end
		if #list > 0 then
			launchToy(list[math.random(1, #list)])
		end
	end
end)
