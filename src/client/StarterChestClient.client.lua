-- Starter chest (client): the free chest by the spawn (StarterChestServer). Shows "FREE" or
-- "OPENED ✔" for you, opens the lid with a coin burst when you claim it, then asks nicely for a 👍.
-- (No reward is tied to liking - Roblox doesn't allow that.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local Claim = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimStarterChest")

local player = Players.LocalPlayer
local chest = workspace:WaitForChild("World"):WaitForChild("Hub"):WaitForChild("StarterChest", 60)
if not chest then
	return
end

local lid = chest:WaitForChild("Lid")
local hinge = lid:WaitForChild("Hinge")
local closedCF = lid:GetPivot()
local glow = chest:WaitForChild("Glow")
local prompt = chest:WaitForChild("PromptPart"):WaitForChild("ChestPrompt")
local board = chest:WaitForChild("Board"):WaitForChild("BillboardGui")

local function setLid(angle)
	lid:PivotTo(closedCF * CFrame.Angles(angle, 0, 0))
end

local function refresh()
	local opened = player:GetAttribute("StarterChest") == true
	prompt.Enabled = not opened
	glow:FindFirstChild("Sparkles").Enabled = not opened
	board.Title.Text = opened and "🎁 STARTER CHEST" or "🎁 FREE STARTER CHEST"
	board.Info.Text = opened and "OPENED ✔" or ("$" .. Config.abbreviate(Config.STARTER_CHEST) .. " for new pilots!")
	board.Info.TextColor3 = opened and Color3.fromRGB(200, 200, 210) or Color3.fromRGB(130, 255, 130)
	setLid(opened and math.rad(70) or 0)
end
player:GetAttributeChangedSignal("StarterChest"):Connect(refresh)
refresh()

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
	-- the lid swings open, coins burst out
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		setLid(a)
	end)
	TweenService:Create(v, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = math.rad(70) }):Play()
	game:GetService("Debris"):AddItem(v, 1)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 170, 30))
	e.Size = NumberSequence.new(0.9, 0)
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(10, 18)
	e.SpreadAngle = Vector2.new(35, 35)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -25, 0)
	e.Rate = 0
	e.LightEmission = 0.8
	e.Parent = glow
	e:Emit(60)
	game:GetService("Debris"):AddItem(e, 3)
	UIKit.sound("Jingle", 0.6, 1.1)
	UIKit.celebrate("🎁 STARTER CHEST!", "+$" .. Config.abbreviate(result), Color3.fromRGB(255, 200, 60))
	-- a friendly ask (nothing depends on it)
	task.delay(3, function()
		UIKit.toast("Enjoying the game? Give it a 👍 and ⭐ on the game page - it really helps!", Color3.fromRGB(255, 220, 140))
	end)
	busy = false
end)
