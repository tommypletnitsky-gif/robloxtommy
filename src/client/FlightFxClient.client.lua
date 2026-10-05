-- Flight effects (client-only looks):
--   * Wind streaks: two thin white trails off the sides of every flying rocket (yours and other
--     players'), stronger the faster it goes - turning draws curves in the air.
--   * Sonic boom: when you start boosting, a ring bursts out around your rocket with a whoosh.
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

-- Sonic boom when your boost kicks in
local function sonicBoom()
	local m = flights:FindFirstChild(player.Name)
	local body = m and m.PrimaryPart
	if not body then
		return
	end
	-- a hoop of glowing pieces that bursts outward around the rocket (a solid disc would cover the
	-- whole screen: the camera sits right behind the rocket)
	local forward = body.CFrame.XVector -- rockets point along their +X
	local frame = CFrame.lookAt(body.Position, body.Position + forward)
	local N = 18
	for i = 1, N do
		local a = (i / N) * math.pi * 2
		local dir = frame.RightVector * math.cos(a) + frame.UpVector * math.sin(a)
		local piece = Instance.new("Part")
		piece.Name = "SonicBoom"
		piece.Anchored, piece.CanCollide, piece.CanQuery, piece.CanTouch, piece.CastShadow = true, false, false, false, false
		piece.Material = Enum.Material.Neon
		piece.Color = (i % 2 == 0) and Color3.fromRGB(150, 230, 255) or Color3.new(1, 1, 1)
		piece.Transparency = 0.15
		piece.Size = Vector3.new(0.5, 0.5, 2.2)
		local from = body.Position + dir * 3.5
		piece.CFrame = CFrame.lookAt(from, from + frame.LookVector:Cross(dir)) -- lies along the hoop
		piece.Parent = workspace
		local to = body.Position + dir * 17 + forward * 4
		TweenService:Create(piece, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(to, to + frame.LookVector:Cross(dir)), Transparency = 1, Size = Vector3.new(0.25, 0.25, 4) }):Play()
		game:GetService("Debris"):AddItem(piece, 0.45)
	end
	UIKit.sound("Whoosh", 0.55, 1.35)
end

player:GetAttributeChangedSignal("BoostFx"):Connect(function()
	if player:GetAttribute("BoostFx") then
		sonicBoom()
	end
end)
