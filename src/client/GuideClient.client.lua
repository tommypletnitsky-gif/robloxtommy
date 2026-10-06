-- New-player guide: one hint at a time, only until you've done it.
--   1. never launched           -> bouncing arrow on LAUNCH: "Press LAUNCH to fly!"
--   2. no upgrades yet + money  -> arrow on the UPGRADE button
--   3. can unlock the next stage -> arrow on the UNLOCK button
--   4. no pets yet + money      -> path + arrow to the Meadow egg
-- Hidden while flying, while a window is open and while the landing report shows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local gui = UIKit.gui()

-- screen hint: speech bubble + bouncing arrow over a GUI button
local bubble = make("Frame", { Parent = gui, Name = "GuideBubble", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(300, 54), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 25 }, { UIKit.corner(18), UIKit.stroke(3.5), make("UIScale", {}) })
local bubbleText = label({ Parent = bubble, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 26 })
local arrow = label({ Parent = gui, Name = "GuideArrow", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(60, 60), Text = "⬇", TextColor3 = Color3.fromRGB(255, 220, 60), StrokeThickness = 4, Visible = false, ZIndex = 25 })

-- world hint: a sparkly line on the ground from you to the target + a bouncing arrow above it
local beamFolder = Instance.new("Folder")
beamFolder.Name = "GuideBeam"
beamFolder.Parent = workspace
local anchor = Instance.new("Part")
anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.Transparency = true, false, false, false, 1
anchor.Size = Vector3.one
anchor.Parent = beamFolder
local a0 = Instance.new("Attachment")
a0.Parent = anchor
local a1 = Instance.new("Attachment")
a1.Parent = anchor
local beam = Instance.new("Beam")
beam.Attachment0, beam.Attachment1 = a0, a1
beam.Width0, beam.Width1 = 3, 3
beam.FaceCamera = true
beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
beam.TextureMode = Enum.TextureMode.Wrap
beam.TextureLength = 3
beam.TextureSpeed = 2.5
beam.LightEmission = 0.6
beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90))
beam.Transparency = NumberSequence.new(0.15)
beam.Enabled = false
beam.Parent = anchor
local marker = Instance.new("BillboardGui")
marker.Size = UDim2.fromOffset(120, 120)
marker.AlwaysOnTop = true
marker.LightInfluence = 0
marker.Enabled = false
marker.Parent = beamFolder
local markerArrow = label({ Parent = marker, Size = UDim2.fromScale(1, 1), Text = "⬇", TextColor3 = Color3.fromRGB(255, 220, 60), StrokeThickness = 5 })

local function hub()
	return workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Hub")
end

local function findButton(text)
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "Label" and d.Text:find(text, 1, true) then
			local b = d:FindFirstAncestorOfClass("TextButton")
			if b and UIKit.shown(b) and b.AbsoluteSize.X > 0 then
				return b
			end
		end
	end
end

-- which hint to show right now: returns kind ("button" / "world"), target, text
local function currentStep()
	local money = player:GetAttribute("Money") or 0
	local flights = player:GetAttribute("StatFlights") or 0
	if flights == 0 then
		return "button", findButton("LAUNCH"), "Press LAUNCH to fly! 🚀"
	end
	local unlocked = player:GetAttribute("UnlockedStage") or 1
	if unlocked < Config.NUM_STAGES then
		local goal = Config.stageEndX(unlocked) - Config.LAUNCH_X
		if (player:GetAttribute("BestDistance") or 0) >= goal - 5 and money >= Config.stageCost(unlocked + 1) then
			return "button", findButton("UNLOCK"), "Unlock the next stage! 🌍"
		end
	end
	local anyUpgrade = false
	for key in pairs(Config.Upgrades) do
		if (player:GetAttribute(key .. "Level") or 0) > 0 then
			anyUpgrade = true
		end
	end
	if not anyUpgrade and money >= Config.upgradeCost("Fuel", 0) then
		return "button", findButton("UPGRADE"), "Upgrade your rocket! ⬆️"
	end
	local egg = Config.Eggs[1]
	if (player:GetAttribute("StatEggs") or 0) == 0 and flights >= 2 and money >= egg.price then
		local garden = hub() and hub():FindFirstChild("EggGarden")
		local stand = garden and garden:FindFirstChild("Egg_" .. egg.id)
		return "world", stand and stand:FindFirstChild("PromptPart"), "Hatch your first pet in the Egg Garden! 🥚"
	end
	return nil
end

local step = { kind = nil, target = nil, text = nil }
task.spawn(function()
	repeat
		task.wait(0.5)
	until player:GetAttribute("DataLoaded")
	task.wait(1)
	while true do
		if UIKit.busy() then -- flying, a window or the landing report on screen
			step.kind = nil
		else
			local kind, target, text = currentStep()
			if text ~= step.text and kind then
				UIKit.bounce(bubble)
			end
			step.kind, step.target, step.text = kind, target, text
		end
		task.wait(0.5)
	end
end)

RunService.RenderStepped:Connect(function()
	if step.kind and UIKit.busy() then
		step.kind = nil -- (hide at once when a show / window / flight starts)
	end
	local t = os.clock()
	local f = UIKit.hudFactor() -- (smaller on phones, like the rest of the HUD)
	bubble.Size = UDim2.fromOffset(300 * f, 54 * f)
	arrow.Size = UDim2.fromOffset(60 * f, 60 * f)
	local bob = math.abs(math.sin(t * 4)) * 14 * f
	local kind, target = step.kind, step.target
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	-- screen hint over a button
	if kind == "button" and target and target.Parent then
		local p, s = UIKit.toGui(target.AbsolutePosition), target.AbsoluteSize
		if p.Y < 260 then
			-- button near the top: point at it from the left
			arrow.Text = "➡"
			arrow.AnchorPoint = Vector2.new(1, 0.5)
			arrow.Position = UDim2.fromOffset(p.X + 6 * f - bob, p.Y + s.Y / 2)
			bubble.AnchorPoint = Vector2.new(1, 0.5)
			bubble.Position = UDim2.fromOffset(p.X - 64 * f, p.Y + s.Y / 2)
		else
			arrow.Text = "⬇"
			arrow.AnchorPoint = Vector2.new(0.5, 1)
			arrow.Position = UDim2.fromOffset(p.X + s.X / 2, p.Y + 10 * f - bob)
			bubble.AnchorPoint = Vector2.new(0.5, 1)
			-- (above the progress bar when it sits over the bottom buttons)
			local progress = gui:FindFirstChild("ProgressBar")
			local lift = (progress and progress.Visible and progress.AbsolutePosition.Y < target.AbsolutePosition.Y) and 40 or 0
			bubble.Position = UDim2.fromOffset(math.clamp(p.X + s.X / 2, 160 * f, gui.AbsoluteSize.X - 160 * f), p.Y - (52 + lift) * f)
		end
		arrow.Visible = true
	else
		arrow.Visible = false
	end
	-- world hint: path on the ground + arrow above the target
	local world = kind == "world" and target and target.Parent and root
	beam.Enabled = world and true or false
	marker.Enabled = world and true or false
	if world then
		local from = root.Position - Vector3.new(0, 2.6, 0)
		local to = Vector3.new(target.Position.X, from.Y, target.Position.Z)
		a0.WorldPosition, a1.WorldPosition = from + (to - from).Unit * 3, to
		marker.Adornee = target
		marker.StudsOffsetWorldSpace = Vector3.new(0, 8 + bob * 0.15, 0)
		bubble.AnchorPoint = Vector2.new(0.5, 1)
		bubble.Position = UDim2.new(0.5, 0, 0, 290)
	end
	bubble.Visible = kind ~= nil and (arrow.Visible or world) and true or false
	bubbleText.Text = step.text or ""
end)
