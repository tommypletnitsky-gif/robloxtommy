-- Hitting a locked gate: the barrier flashes white-red, its lock sign pops, a red hoop bursts out
-- around the rocket, the camera shakes and one thud plays. (Its own script: RocketClient is near
-- Luau's 200-local limit.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local modules = script.Parent:WaitForChild("ClientModules")
local UIKit = require(modules:WaitForChild("UIKit"))
local Report = require(modules:WaitForChild("FlightReport")) -- RocketClient sets Report.shake

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RED = Color3.fromRGB(255, 70, 90) -- the barrier's own colour (Scenery)
local REST = 0.55 -- a locked barrier's transparency (RocketClient refreshGates)

-- [stage] = Gate model, found on first use (rescanned if the world was rebuilt)
local gates = {}
local function gateFor(stage)
	local g = gates[stage]
	if g and g.Parent then
		return g
	end
	gates = {}
	local world = workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	for _, m in ipairs(world:GetDescendants()) do
		if m:IsA("Model") and m.Name == "Gate" and m:GetAttribute("Stage") then
			gates[m:GetAttribute("Stage")] = m
		end
	end
	return gates[stage]
end

local function flashBarrier(g)
	local stage = g:GetAttribute("Stage") or 99
	for _, b in ipairs(g:GetChildren()) do
		if b.Name == "Barrier" and b:IsA("BasePart") then
			b.Transparency = 0.05
			b.Color = Color3.new(1, 1, 1)
			local t = TweenService:Create(b, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = REST, Color = RED })
			t.Completed:Connect(function()
				-- unlocked meanwhile: stay hidden like refreshGates does
				if stage <= (player:GetAttribute("UnlockedStage") or 1) then
					b.Transparency = 1
				end
			end)
			t:Play()
		end
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
