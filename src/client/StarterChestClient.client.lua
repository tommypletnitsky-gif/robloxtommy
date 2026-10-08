-- Starter chest (client): the free chest by the spawn (StarterChestServer). Shows "FREE" or
-- "OPENED ✔" for you; the chest floats and turns slowly with gold coins orbiting it and the post
-- gems spinning. Opening it: a flash, the closed chest swaps to the open one overflowing with gold,
-- a coin fountain, then a friendly ask for a 👍. (No reward is tied to liking - Roblox doesn't allow it.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local Claim = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimStarterChest")

local player = Players.LocalPlayer
local chest = workspace:WaitForChild("World"):WaitForChild("Hub"):WaitForChild("StarterChest", 60)
if not chest then
	return
end

local home = chest:GetAttribute("ChestHome") or chest:GetPivot()
local box = chest:WaitForChild("Chest") -- the chest itself (floats); its Lid swings open
local lid = box:WaitForChild("Lid")
local lidOffset = home:ToObjectSpace(lid:GetPivot()) -- (the hinge, relative to the chest)
local lidAngle = 0 -- radians, 0 = closed
local floatCF = home
local glow = chest:WaitForChild("Glow")
local prompt = chest:WaitForChild("PromptPart"):WaitForChild("ChestPrompt")
local board = chest:WaitForChild("Board"):WaitForChild("BillboardGui")
local beam = chest:FindFirstChild("LightBeam")

local function place()
	box:PivotTo(floatCF)
	lid:PivotTo(floatCF * lidOffset * CFrame.Angles(lidAngle, 0, 0))
end

-- gold coins orbiting the chest (only on your screen)
local coins = {}
local fx = Instance.new("Folder")
fx.Name = "StarterChestFx"
fx.Parent = workspace
for i = 1, 6 do
	local c = Instance.new("Part")
	c.Shape = Enum.PartType.Cylinder
	c.Size = Vector3.new(0.18, 0.9, 0.9)
	c.Color = Color3.fromRGB(255, 205, 60)
	c.Material = Enum.Material.Metal
	c.Reflectance = 0.25
	c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
	c.Parent = fx
	coins[i] = c
end
local gems = {}
for _, d in ipairs(chest:GetChildren()) do
	if d:IsA("BasePart") and d:GetAttribute("Spin") then
		table.insert(gems, { p = d, cf = d.CFrame })
	end
end

local opened = false
local function refresh()
	opened = player:GetAttribute("StarterChest") == true
	prompt.Enabled = not opened
	glow:FindFirstChild("Sparkles").Enabled = not opened
	board.Title.Text = opened and "🎁 STARTER CHEST" or "🎁 FREE STARTER CHEST"
	board.Info.Text = opened and "OPENED ✔" or ("$" .. Config.abbreviate(Config.STARTER_CHEST) .. " for new pilots!")
	board.Info.TextColor3 = opened and Color3.fromRGB(200, 200, 210) or Color3.fromRGB(130, 255, 130)
	if opened then
		lidAngle = math.rad(105)
		floatCF = home
	end
	place()
	if beam then
		beam.LocalTransparencyModifier = opened and 1 or 0
	end
	for _, c in ipairs(coins) do
		c.LocalTransparencyModifier = opened and 1 or 0
	end
end
player:GetAttributeChangedSignal("StarterChest"):Connect(refresh)
refresh()

-- float + slow turn (closed chest only), orbiting coins, spinning gems, pulsing beam
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if (cam.CFrame.Position - home.Position).Magnitude > 120 then
		return
	end
	local t = os.clock()
	if not opened then
		-- floats and looks around; the lid rattles now and then as if something's inside
		floatCF = home * CFrame.new(0, 0.35 + math.sin(t * 2) * 0.3, 0) * CFrame.Angles(0, math.sin(t * 0.7) * 0.35, 0)
		local rattle = (t % 4 < 0.5) and math.abs(math.sin(t * 30)) * math.rad(8) or 0
		lidAngle = rattle
		place()
	end
	if not opened then
		for i, c in ipairs(coins) do
			local a = t * 1.2 + i / #coins * math.pi * 2
			local pos = home.Position + Vector3.new(math.cos(a) * 3.6, 2 + math.sin(t * 2 + i) * 0.5, math.sin(a) * 3.6)
			c.CFrame = CFrame.new(pos) * CFrame.Angles(0, -a + t * 3, 0)
		end
	end
	for _, g in ipairs(gems) do
		g.p.CFrame = g.cf * CFrame.new(0, math.sin(t * 2.4) * 0.15, 0) * CFrame.Angles(0, t * 2, 0)
	end
	if beam and not opened then
		beam.Transparency = 0.86 + math.sin(t * 2) * 0.04
	end
end)

local busy = false
ProximityPromptService.PromptTriggered:Connect(function(p)
	if p ~= prompt or busy then
		return
	end
	busy = true
	local ok, result = Claim:InvokeServer()
	if not ok then
		UIKit.result(false, result)
		busy = false
		return
	end
	-- a white flash on the chest, then the open chest with a fountain of coins
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 2
	flash.CFrame = home * CFrame.new(0, 2, 0)
	flash.Color = Color3.fromRGB(255, 240, 180)
	flash.Material = Enum.Material.Neon
	flash.Anchored, flash.CanCollide, flash.CanQuery, flash.CanTouch = true, false, false, false
	flash.Parent = fx
	TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = Vector3.one * 10, Transparency = 1 }):Play()
	game:GetService("Debris"):AddItem(flash, 0.5)
	-- the lid bursts open (a springy swing back)
	opened = true
	local from = lidAngle
	local t0 = os.clock()
	while os.clock() - t0 < 0.6 do
		local a = (os.clock() - t0) / 0.6
		local spring = 1 - math.cos(a * math.pi * 2.5) * (1 - a) -- overshoot, settle
		lidAngle = from + (math.rad(105) - from) * spring
		floatCF = floatCF:Lerp(home, 0.25)
		place()
		RunService.RenderStepped:Wait()
	end
	refresh()
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 170, 30))
	e.Size = NumberSequence.new(1, 0)
	e.Lifetime = NumberRange.new(1, 1.6)
	e.Speed = NumberRange.new(12, 20)
	e.SpreadAngle = Vector2.new(30, 30)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -28, 0)
	e.Rate = 0
	e.LightEmission = 0.8
	e.Parent = glow
	e:Emit(80)
	game:GetService("Debris"):AddItem(e, 3)
	-- real coins popping out and falling around the stand
	for i = 1, 14 do
		local c = coins[(i - 1) % #coins + 1]:Clone()
		c.LocalTransparencyModifier = 0
		c.Anchored = false
		c.CanCollide = true
		c.CFrame = home * CFrame.new(0, 2.5, 0)
		c.Parent = fx
		c.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(20, 30), math.random(-12, 12))
		c.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		game:GetService("Debris"):AddItem(c, 3)
	end
	UIKit.sound("Jingle", 0.6, 1.1)
	UIKit.celebrate("🎁 STARTER CHEST!", "+$" .. Config.abbreviate(result), Color3.fromRGB(255, 200, 60))
	-- a friendly ask (nothing depends on it)
	task.delay(3, function()
		UIKit.toast("Enjoying the game? Give it a 👍 and ⭐ on the game page - it really helps!", Color3.fromRGB(255, 220, 140))
	end)
	busy = false
end)
