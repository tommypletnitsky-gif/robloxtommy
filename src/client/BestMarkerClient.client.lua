-- Your best distance, marked on the path: two flag poles with a checkered banner across the lane
-- and a "BEST 442m" sign (only on your screen). Flying past it pops "NEW BEST!" right away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
-- checkered banner across the top
local squares = 16
for i = 0, squares - 1 do
	local z = -HALF + (i + 0.5) * (HALF * 2 / squares)
	for row = 0, 1 do
		part(marker, { Size = Vector3.new(0.3, 1.6, HALF * 2 / squares), CFrame = CFrame.new(0, 23.4 + row * 1.6, z), Color = ((i + row) % 2 == 0) and Color3.new(1, 1, 1) or Color3.fromRGB(30, 30, 40), CastShadow = false })
	end
end
local signPart = part(marker, { Name = "Sign", Size = Vector3.new(0.4, 3, 12), CFrame = CFrame.new(0, 28.5, 0), Transparency = 1 })
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromScale(14, 3.6)
bb.LightInfluence = 0
bb.MaxDistance = 1200
bb.Parent = signPart
local text = UIKit.label({ Parent = bb, Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = GOLD, StrokeThickness = 4 })
marker.WorldPivot = CFrame.new()

local shownBest = -1
local function place()
	local best = player:GetAttribute("BestDistance") or 0
	if best < 30 then
		marker.Parent = nil
		return
	end
	local x = Config.LAUNCH_X + best
	marker:PivotTo(CFrame.new(x, Config.pathY(x), 0))
	text.Text = "🏆 BEST " .. Config.meters(best)
	marker.Parent = workspace
	shownBest = best
end
player:GetAttributeChangedSignal("BestDistance"):Connect(place)
task.spawn(function()
	repeat
		task.wait(0.5)
	until player:GetAttribute("DataLoaded")
	place()
end)

-- passing your old best while flying
local celebrated = false
player:GetAttributeChangedSignal("Flying"):Connect(function()
	celebrated = false
end)
RunService.Heartbeat:Connect(function()
	if celebrated or shownBest < 30 or not player:GetAttribute("Flying") then
		return
	end
	local flights = workspace:FindFirstChild("Flights")
	local m = flights and flights:FindFirstChild(player.Name)
	local body = m and m.PrimaryPart
	if body and body.Position.X - Config.LAUNCH_X > shownBest then
		celebrated = true
		UIKit.toast("🏆 NEW BEST! Keep going!", GOLD)
		UIKit.sound("Win", 0.5, 1.3)
	end
end)
