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
	-- a three-tier pedestal: wide marble base with a glowing gold ring, a deep-red velvet drum with
	-- gold bands, a gold top; four gold posts with glowing gems around it; a soft beam of light
	local function cyl(name, h, d, y0, color, mat, extra)
		local c = part(m, { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = base * CFrame.new(0, y0 + h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = mat or Enum.Material.SmoothPlastic, CanCollide = true })
		for k, v in pairs(extra or {}) do
			c[k] = v
		end
		return c
	end
	cyl("Step1", 0.6, 12, 0, C(245, 240, 232), Enum.Material.Marble)
	cyl("Ring1", 0.3, 12.3, 0.15, GOLD, Enum.Material.Neon, { CanCollide = false })
	cyl("Step2", 0.9, 9.4, 0.6, C(150, 25, 45), Enum.Material.Fabric)
	cyl("Band2a", 0.18, 9.6, 0.62, GOLD, Enum.Material.Metal, { CanCollide = false })
	cyl("Band2b", 0.18, 9.6, 1.32, GOLD, Enum.Material.Metal, { CanCollide = false })
	cyl("Top", 0.35, 7.6, 1.5, C(235, 170, 45), Enum.Material.Metal)
	cyl("TopRing", 0.16, 7.8, 1.6, C(255, 225, 120), Enum.Material.Neon, { CanCollide = false })
	local topY = 1.85
	local gems = { C(255, 70, 110), C(70, 170, 255), C(90, 230, 140), C(190, 100, 255) }
	for i = 1, 4 do
		local ang = (i - 0.5) / 4 * math.pi * 2
		local at = base * CFrame.new(math.cos(ang) * 5.3, 0, math.sin(ang) * 5.3)
		part(m, { Name = "Post", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.2, 0.55, 0.55), CFrame = at * CFrame.new(0, 0.6 + 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = GOLD, Material = Enum.Material.Metal })
		part(m, { Name = "PostCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.9, 0.9), CFrame = at * CFrame.new(0, 3.9, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = GOLD, Material = Enum.Material.Metal })
		local gem = part(m, { Name = "PostGem", Size = Vector3.new(0.7, 0.7, 0.7), CFrame = at * CFrame.new(0, 4.45, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = gems[i], Material = Enum.Material.Neon })
		gem:SetAttribute("Spin", true)
	end
	local beam = part(m, { Name = "LightBeam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 3.4, 3.4), CFrame = base * CFrame.new(0, topY + 5.2 + 7, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = C(255, 230, 140), Material = Enum.Material.Neon, Transparency = 0.88, CastShadow = false })
	beam.Name = "LightBeam"

	-- the chest (built from parts so the lid really opens): dark wooden planks, shiny gold bands,
	-- corners and rivets, a curved plank lid with gold straps, a big gold lock with a glowing ruby,
	-- and a pile of gold inside. Model "Chest" (the client floats it) with a "Lid" model (hinge =
	-- PrimaryPart, the client swings it open).
	local home = base * CFrame.new(0, topY + 0.25, 0)
	m:SetAttribute("ChestHome", home)
	local chest = Instance.new("Model")
	chest.Name = "Chest"
	chest.Parent = m
	local W, H, D = 4.6, 2.3, 3.1 -- body width / height / depth
	local R = D / 2 -- lid radius (a half-cylinder over the depth)
	local GOLDM = Enum.Material.Metal
	local function cp(parent, props)
		local q = part(parent, props)
		if props.Material == GOLDM then
			q.Reflectance = 0.18
		end
		return q
	end
	local woods = { C(122, 72, 38), C(108, 62, 32), C(132, 80, 42) }
	-- body planks (front/back/sides) + a dark inside
	for i = 0, 3 do
		local h = H / 4
		cp(chest, { Name = "Plank", Size = Vector3.new(W, h - 0.05, D), CFrame = home * CFrame.new(0, h * i + h / 2, 0), Color = woods[i % 3 + 1], Material = Enum.Material.WoodPlanks })
	end
	-- gold rims, corners, bands with rivets
	cp(chest, { Name = "RimBottom", Size = Vector3.new(W + 0.2, 0.28, D + 0.2), CFrame = home * CFrame.new(0, 0.14, 0), Color = GOLD, Material = GOLDM })
	cp(chest, { Name = "RimTop", Size = Vector3.new(W + 0.2, 0.28, D + 0.2), CFrame = home * CFrame.new(0, H - 0.14, 0), Color = GOLD, Material = GOLDM })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			cp(chest, { Name = "Corner", Size = Vector3.new(0.34, H, 0.34), CFrame = home * CFrame.new(sx * (W / 2 + 0.02), H / 2, sz * (D / 2 + 0.02)), Color = GOLD, Material = GOLDM })
		end
		local bx = sx * W * 0.28
		cp(chest, { Name = "Band", Size = Vector3.new(0.36, H, D + 0.12), CFrame = home * CFrame.new(bx, H / 2, 0), Color = GOLD, Material = GOLDM })
		for k = 1, 3 do
			cp(chest, { Name = "Rivet", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.18, CFrame = home * CFrame.new(bx, H * k / 4, -(D / 2 + 0.08)), Color = C(255, 235, 150), Material = GOLDM })
		end
	end
	-- gold pile inside (shows when the lid opens)
	cp(chest, { Name = "GoldPile", Shape = Enum.PartType.Ball, Size = Vector3.new(W * 0.9, 1.1, D * 0.85), CFrame = home * CFrame.new(0, H - 0.15, 0), Color = C(255, 200, 50), Material = Enum.Material.Neon })
	for k = 1, 7 do
		local x, z = (k % 4 - 1.5) * 0.9, (k % 2 == 0 and 0.4 or -0.4)
		cp(chest, { Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 0.7, 0.7), CFrame = home * CFrame.new(x, H + 0.3 + (k % 3) * 0.08, z) * CFrame.Angles(0.3 * k, 0, math.pi / 2 + 0.4 * (k % 2)), Color = C(255, 215, 70), Material = GOLDM })
	end
	cp(chest, { Name = "Ruby2", Size = Vector3.new(0.45, 0.45, 0.45), CFrame = home * CFrame.new(-0.9, H + 0.35, 0.2) * CFrame.Angles(0.6, 0.6, 0), Color = C(255, 60, 90), Material = Enum.Material.Neon })
	cp(chest, { Name = "Sapphire", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = home * CFrame.new(1.1, H + 0.3, -0.2) * CFrame.Angles(0.6, 0.2, 0.6), Color = C(70, 160, 255), Material = Enum.Material.Neon })
	-- the lid: planks along an arc + gold straps, hinged at the back top edge
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = chest
	local hinge = part(lid, { Name = "Hinge", Size = Vector3.new(W, 0.15, 0.15), CFrame = home * CFrame.new(0, H, R), Transparency = 1 })
	lid.PrimaryPart = hinge
	local center = home * CFrame.new(0, H, 0)
	local steps = 7
	for k = 0, steps - 1 do
		local a0 = k / steps * math.pi
		local a1 = (k + 1) / steps * math.pi
		local am = (a0 + a1) / 2
		local seg = 2 * R * math.sin((a1 - a0) / 2) + 0.06
		-- a plank on the arc (angle 0 = front edge, pi = back edge)
		local at = center * CFrame.new(0, math.sin(am) * R, -math.cos(am) * R) * CFrame.Angles(-(am - math.pi / 2), 0, 0)
		cp(lid, { Name = "LidPlank", Size = Vector3.new(W, 0.22, seg), CFrame = at, Color = woods[k % 3 + 1], Material = Enum.Material.WoodPlanks })
		for _, bx in ipairs({ -W * 0.28, W * 0.28, -(W / 2 + 0.02), W / 2 + 0.02 }) do
			cp(lid, { Name = "LidStrap", Size = Vector3.new(0.36, 0.26, seg), CFrame = at * CFrame.new(bx, 0.03, 0), Color = GOLD, Material = GOLDM })
		end
	end
	for _, sx in ipairs({ -1, 1 }) do -- half-disc ends, from stacked slats
		local rows = 6
		for j = 0, rows - 1 do
			local y = (j + 0.5) / rows * R
			local w = 2 * math.sqrt(math.max(0, R * R - y * y))
			cp(lid, { Name = "LidEnd", Size = Vector3.new(0.2, R / rows + 0.02, w), CFrame = center * CFrame.new(sx * (W / 2 - 0.12), y, 0), Color = woods[2], Material = Enum.Material.WoodPlanks })
		end
	end
	-- the lock: gold plate, keyhole, glowing ruby
	cp(lid, { Name = "LockPlate", Size = Vector3.new(0.9, 1.0, 0.18), CFrame = home * CFrame.new(0, H - 0.1, -(D / 2 + 0.12)), Color = GOLD, Material = GOLDM })
	cp(lid, { Name = "Ruby", Size = Vector3.new(0.38, 0.38, 0.12), CFrame = home * CFrame.new(0, H + 0.12, -(D / 2 + 0.23)) * CFrame.Angles(0, 0, math.rad(45)), Color = C(255, 40, 80), Material = Enum.Material.Neon })
	cp(lid, { Name = "Keyhole", Size = Vector3.new(0.12, 0.3, 0.05), CFrame = home * CFrame.new(0, H - 0.3, -(D / 2 + 0.22)), Color = C(40, 25, 15) })
	chest.PrimaryPart = nil
	chest.WorldPivot = home
	local body = home
	-- treasure glow + sparkles (above the chest)
	local glow = part(m, { Name = "Glow", Size = Vector3.new(3.8, 0.3, 2.4), CFrame = body * CFrame.new(0, 2.9, 0), Color = C(255, 220, 90), Material = Enum.Material.Neon, Transparency = 1 })
	local light = Instance.new("PointLight")
	light.Color = C(255, 210, 100)
	light.Brightness = 0.9
	light.Range = 14
	light.Parent = glow
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparkles"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(C(255, 230, 120), C(255, 170, 40))
	sparks.Size = NumberSequence.new(0.55, 0)
	sparks.Lifetime = NumberRange.new(1, 1.8)
	sparks.Speed = NumberRange.new(0.5, 2)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 12
	sparks.LightEmission = 0.7
	sparks.Parent = glow
	-- board (the client fills it in for you: FREE / OPENED)
	local anchor = part(m, { Name = "Board", Size = Vector3.one, CFrame = base * CFrame.new(0, 9.4, 0), Transparency = 1 })
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
	local hitbox = part(m, { Name = "PromptPart", Size = Vector3.new(6, 6, 6), CFrame = body * CFrame.new(0, 1.8, 0), Transparency = 1, CanQuery = true })
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
