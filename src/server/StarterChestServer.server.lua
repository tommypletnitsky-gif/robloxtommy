-- Starter chest (server): a free gift chest right next to the spawn. Every player can open it once
-- in their lifetime for Config.STARTER_CHEST money (saved: attribute StarterChest).
--   ClaimStarterChest() -> ok, message   (must be standing near the chest)
-- (Roblox doesn't allow rewards for liking / favoriting, so the client only *asks* nicely after.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(ServerScriptService.PlayerData)

local C = Color3.fromRGB
local INK = C(30, 30, 50)
local WOOD, WOOD_DARK, GOLD = C(150, 90, 45), C(110, 62, 30), C(255, 196, 60)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Claim = remotes:FindFirstChild("ClaimStarterChest") or Instance.new("RemoteFunction")
Claim.Name = "ClaimStarterChest"
Claim.Parent = remotes

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function build(hub)
	local pos = Config.STARTER_CHEST_POS
	local params = RaycastParams.new()
	local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), params)
	local y = hit and hit.Position.Y or 0.3
	local base = CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(Config.STARTER_CHEST_FACE.X, y, Config.STARTER_CHEST_FACE.Z))
	local m = Instance.new("Model")
	m.Name = "StarterChest"
	m.Parent = hub
	-- a gold plinth with a glowing ring
	part(m, { Name = "Plinth", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 9, 9), CFrame = base * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = C(255, 240, 200), Material = Enum.Material.Marble, CanCollide = true })
	part(m, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 9.4, 9.4), CFrame = base * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = GOLD, Material = Enum.Material.Neon })
	-- the chest: body, gold bands, lid (on a hinge part the client tilts open)
	local body = base * CFrame.new(0, 0.8, 0)
	part(m, { Name = "Body", Size = Vector3.new(4.4, 2.4, 3), CFrame = body * CFrame.new(0, 1.2, 0), Color = WOOD, Material = Enum.Material.Wood, CanCollide = true })
	for _, x in ipairs({ -1.6, 1.6 }) do
		part(m, { Name = "Band", Size = Vector3.new(0.35, 2.45, 3.05), CFrame = body * CFrame.new(x, 1.2, 0), Color = GOLD, Material = Enum.Material.Metal })
	end
	part(m, { Name = "Trim", Size = Vector3.new(4.45, 0.3, 3.05), CFrame = body * CFrame.new(0, 2.3, 0), Color = GOLD, Material = Enum.Material.Metal })
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = m
	local hinge = part(lid, { Name = "Hinge", Size = Vector3.new(4.4, 0.2, 0.2), CFrame = body * CFrame.new(0, 2.45, 1.5), Transparency = 1 })
	lid.PrimaryPart = hinge
	part(lid, { Name = "Top", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.4, 3, 3), CFrame = body * CFrame.new(0, 2.45, 0) * CFrame.Angles(0, 0, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
	for _, x in ipairs({ -1.6, 1.6 }) do
		part(lid, { Name = "LidBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.36, 3.05, 3.05), CFrame = body * CFrame.new(x, 2.45, 0), Color = GOLD, Material = Enum.Material.Metal })
	end
	part(lid, { Name = "Lock", Size = Vector3.new(0.7, 0.8, 0.25), CFrame = body * CFrame.new(0, 2.2, -1.55), Color = GOLD, Material = Enum.Material.Neon })
	-- treasure glow inside (visible when the lid opens) + sparkles
	local glow = part(m, { Name = "Glow", Size = Vector3.new(3.8, 0.3, 2.4), CFrame = body * CFrame.new(0, 2.35, 0), Color = C(255, 220, 90), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = C(255, 210, 100)
	light.Brightness = 1.4
	light.Range = 12
	light.Parent = glow
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparkles"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(C(255, 230, 120), C(255, 170, 40))
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Speed = NumberRange.new(1, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 8
	sparks.LightEmission = 0.6
	sparks.Parent = glow
	-- board (the client fills it in for you: FREE / OPENED)
	local anchor = part(m, { Name = "Board", Size = Vector3.one, CFrame = base * CFrame.new(0, 8.6, 0), Transparency = 1 })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(9, 3)
	bb.MaxDistance = 70
	bb.LightInfluence = 0
	bb.Parent = anchor
	for i, l in ipairs({ { "Title", "🎁 FREE STARTER CHEST", C(255, 220, 90) }, { "Info", "$" .. Config.abbreviate(Config.STARTER_CHEST) .. " for new pilots!", C(130, 255, 130) } }) do
		local t = Instance.new("TextLabel")
		t.Name = l[1]
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0, (i - 1) * 0.55)
		t.Size = UDim2.fromScale(1, i == 1 and 0.55 or 0.45)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = l[2]
		t.TextColor3 = l[3]
		local st = Instance.new("UIStroke")
		st.Thickness = 2.5
		st.Color = INK
		st.Parent = t
		t.Parent = bb
	end
	local hitbox = part(m, { Name = "PromptPart", Size = Vector3.new(5, 5, 5), CFrame = body * CFrame.new(0, 1.5, 0), Transparency = 1, CanQuery = true })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChestPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Starter Chest"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("StarterChest", true)
	prompt.Parent = hitbox
	return m
end

local chest
Claim.OnServerInvoke = function(player)
	if not player:GetAttribute("DataLoaded") then
		return false, "Loading your save..."
	end
	if player:GetAttribute("StarterChest") then
		return false, "You already opened your starter chest!"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not chest or (root.Position - Config.STARTER_CHEST_POS).Magnitude > 20 then
		return false, "Walk up to the chest first!"
	end
	player:SetAttribute("StarterChest", true)
	player:SetAttribute("Money", (player:GetAttribute("Money") or 0) + Config.STARTER_CHEST)
	player:SetAttribute("TotalEarned", (player:GetAttribute("TotalEarned") or 0) + Config.STARTER_CHEST)
	PlayerData.save(player)
	return true, Config.STARTER_CHEST
end

task.spawn(function()
	local hub = workspace:WaitForChild("World"):WaitForChild("Hub")
	chest = build(hub)
end)
