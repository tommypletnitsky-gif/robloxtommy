-- The Hatchery (client): brings the eggs on their dioramas to life - each bobs and turns a little,
-- and eggs near you get their orbiting props, particles and light (EggLooks). Far eggs stay still
-- and cost nothing. Also keeps the boards above the eggs up to date for you (locked / press E).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local modules = script.Parent:WaitForChild("ClientModules")
local EggLooks = require(modules:WaitForChild("EggLooks"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local NEAR, FAR = 70, 85 -- rigs start within NEAR studs of the camera, stop beyond FAR
-- phones / low graphics: fewer eggs come alive at once (each rig is ~20-60 parts + particles + a light)
do
	local UserInputService = game:GetService("UserInputService")
	local okQ, quality = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if phone or (okQ and quality > 0 and quality <= 3) then
		NEAR, FAR = 46, 56
	end
end

local eggs = {} -- [egg model] = { home, id, rig, phase }

local function add(e)
	if eggs[e] then
		return
	end
	local home = e:GetAttribute("Home")
	if typeof(home) ~= "CFrame" then
		home = e:GetPivot()
	end
	eggs[e] = { home = home, id = e:GetAttribute("EggId"), phase = math.random() * 6, rig = nil }
end
local function remove(e)
	local info = eggs[e]
	if info and info.rig then
		info.rig.destroy()
	end
	eggs[e] = nil
end
CollectionService:GetInstanceAddedSignal("HatcheryEgg"):Connect(add)
CollectionService:GetInstanceRemovedSignal("HatcheryEgg"):Connect(remove)
for _, e in ipairs(CollectionService:GetTagged("HatcheryEgg")) do
	add(e)
end

local fxFolder = Instance.new("Folder")
fxFolder.Name = "HatcheryFx"
fxFolder.Parent = workspace

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local camPos = camera.CFrame.Position
	local flying = player:GetAttribute("Flying")
	for e, info in pairs(eggs) do
		if not e.Parent then
			remove(e)
			continue
		end
		local d = (info.home.Position - camPos).Magnitude
		local active = not flying and d < (info.rig and FAR or NEAR)
		if active and not info.rig then
			info.rig = EggLooks.attach(e, info.id, { parent = fxFolder, home = info.home })
		elseif not active and info.rig then
			info.rig.destroy()
			info.rig = nil
			e:PivotTo(info.home)
		end
		if info.rig then
			-- bob + a slow look round (the egg's front stays toward the walk most of the time)
			local cf = info.home * CFrame.new(0, 0.35 + math.sin(t * 1.6 + info.phase) * 0.3, 0) * CFrame.Angles(0, math.sin(t * 0.5 + info.phase) * 0.45, math.sin(t * 1.1 + info.phase) * 0.04)
			e:PivotTo(cf)
			info.rig.update(dt, t, 0, cf)
		end
	end
end)

-- Mood: the light shifts as you walk through the areas (Sky: bright and airy, Space: darker and
-- purple). Only while you're walking around the Hatchery.
local Lighting = game:GetService("Lighting")
local mood = Instance.new("ColorCorrectionEffect")
mood.Name = "HatcheryMood"
mood.Parent = Lighting
local SKY_X, SPACE_X = -253, -325.5
local function smooth(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
RunService.Heartbeat:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local x = (root and not player:GetAttribute("Flying")) and root.Position.X or 0
	local sky = smooth(SKY_X + 8, SKY_X - 8, x) * (1 - smooth(SPACE_X + 8, SPACE_X - 8, x))
	local space = smooth(SPACE_X + 8, SPACE_X - 8, x)
	mood.Brightness = sky * 0.04 - space * 0.08
	mood.Contrast = space * 0.12
	mood.Saturation = sky * 0.05 + space * 0.15
	mood.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(240, 248, 255), sky):Lerp(Color3.fromRGB(205, 195, 255), space)
end)

-- Boards above the eggs: locked until you unlock the egg's stage
local function refreshBoards()
	local hub = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Hub")
	local hatchery = hub and hub:FindFirstChild("Hatchery")
	if not hatchery then
		return
	end
	local stage = player:GetAttribute("UnlockedStage") or 1
	for _, stand in ipairs(hatchery:GetChildren()) do
		local egg = Config.getEgg(stand:GetAttribute("Egg") or "")
		local board = stand:FindFirstChild("Board")
		local lock = board and board:FindFirstChild("Lock", true)
		if egg and lock and stand:GetAttribute("Limited") then
			-- the limited egg: your price (it follows your best egg) and the time left
			local _, ends = Config.limitedEgg()
			local left = math.max(0, ends - workspace:GetServerTimeNow())
			local d, h, m = left // 86400, (left % 86400) // 3600, (left % 3600) // 60
			lock.Text = "⏳ " .. (d > 0 and string.format("%dd %02dh left", d, h) or string.format("%dh %02dm left", h, m))
			lock.TextColor3 = Color3.fromRGB(255, 200, 120)
			local price = board:FindFirstChild("Price", true)
			if price then
				price.Text = "$" .. Config.abbreviate(Config.eggPrice(egg, player))
			end
		elseif egg and lock then
			if stage >= egg.stage then
				lock.Text = "Press E to hatch!"
				lock.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				lock.Text = "🔒 Unlock Stage " .. egg.stage
				lock.TextColor3 = Color3.fromRGB(255, 120, 120)
			end
		end
	end
end
player:GetAttributeChangedSignal("UnlockedStage"):Connect(refreshBoards)
task.spawn(function()
	while true do
		task.wait(20) -- (the limited egg's timer)
		refreshBoards()
	end
end)
task.spawn(function()
	local hatchery = workspace:WaitForChild("World"):WaitForChild("Hub"):WaitForChild("Hatchery", 30)
	refreshBoards()
	if hatchery then
		hatchery.ChildAdded:Connect(function()
			task.defer(refreshBoards) -- (event eggs arrive later)
		end)
	end
end)
