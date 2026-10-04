-- The starting area: a cheerful launch park.
--   spawn plaza -> lantern-lined stone path (the two shops on either side) -> launch pad + launcher.
--   Groves, blue rocks and grass-topped simulator hills frame the edges; the middle stays open so the
--   shops and the launcher are what you see first.
--   Props: Creator Store packs (scripts/lights stripped) in ServerStorage.LobbyProps, see their
--   Source attribute. Shops: ServerStorage.ShopModels. Launcher: ServerStorage.LauncherModel.
--   Paths / pad use generated MaterialVariants when the place has them (LobbyPathTiles,
--   LaunchPadPanels) and plain materials otherwise.
-- Nothing in the lobby glows or emits light.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(ServerScriptService.BuildKit)
local Foliage = require(ServerScriptService.Foliage)
local LobbyLayout = require(ServerScriptService.LobbyLayout)

local part, cyl, sign = Kit.part, Kit.cyl, Kit.sign
local darker = Kit.darker
local UP = Kit.UP
local C = Color3.fromRGB
local M = Enum.Material

local Lobby = {}

local WHITE = C(255, 255, 255)
local SIGN = C(53, 139, 204) -- #358bcc, every sign in the lobby
local GRASS = C(128, 186, 96) -- soft lawn green (built-in Grass texture, no blades on parts)
local TILE = C(244, 230, 204) -- warm cream stone
local BORDER = C(196, 150, 104) -- warm brown edging
local PAD = C(214, 220, 230)
local DARK = C(45, 45, 52)
local YELLOW = C(255, 205, 60)
local LEAF = {
	green = C(120, 200, 80),
	gold = C(250, 200, 70),
	orange = C(245, 140, 60),
	pink = C(250, 150, 190),
}

local SPAWN = LobbyLayout.SPAWN
local PAD_X = Config.LAUNCH_X - 8
local LAWN_TOP = 0.08 -- just above the flat terrain under it
local EDGE_TOP = 0.2 -- borders
local PAVE_TOP = 0.3 -- paths, pad (just above the runway's 0.2)

-- Trees + bushes (used by the path scenery).
function Lobby.tree(parent, pos, rng, height, palette)
	Foliage.tree(parent, pos, rng, height, palette or "park")
end

function Lobby.bush(parent, pos, rng, size, palette)
	Foliage.bush(parent, pos, rng, size, palette or "park")
end

-- Ground ---------------------------------------------------------------------------------------
-- material + MaterialVariant name for a surface: the generated variant if the place has it
local function surface(name, fallback)
	local v = MaterialService:FindFirstChild(name, true)
	if v and v:IsA("MaterialVariant") then
		return v.BaseMaterial, v.Name
	end
	return fallback, ""
end

local function flat(parent, props)
	props.Material = props.Material or M.SmoothPlastic
	props.CastShadow = false
	return part(parent, props)
end

local function disc(parent, r, x, z, top, color, mat, var)
	return flat(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, r * 2, r * 2), CFrame = CFrame.new(x, top - 0.2, z) * UP, Color = color, Material = mat, MaterialVariant = var or "" })
end

local function box(parent, x0, z0, x1, z1, top, color, mat, var)
	return flat(parent, { Size = Vector3.new(x1 - x0, 0.4, z1 - z0), CFrame = CFrame.new((x0 + x1) / 2, top - 0.2, (z0 + z1) / 2), Color = color, Material = mat, MaterialVariant = var or "" })
end

-- A stone path with a brown edge on both sides (edge = 1.2 studs).
local function path(parent, x0, z0, x1, z1, alongX)
	if alongX then
		box(parent, x0, z0 - 1.2, x1, z1 + 1.2, EDGE_TOP, BORDER)
	else
		box(parent, x0 - 1.2, z0, x1 + 1.2, z1, EDGE_TOP, BORDER)
	end
	box(parent, x0, z0, x1, z1, PAVE_TOP, TILE, surface("LobbyPathTiles", M.Cobblestone))
end

local function ground(hub)
	local g = Instance.new("Model")
	g.Name = "Ground"
	g.Parent = hub
	local tileMat, tileVar = surface("LobbyPathTiles", M.Cobblestone)

	local x0, x1, z = LobbyLayout.PARK[1] - 1, Config.LAUNCH_X, LobbyLayout.PARK[4] + 2
	flat(g, { Name = "Lawn", Size = Vector3.new(x1 - x0, 2, z * 2), CFrame = CFrame.new((x0 + x1) / 2, LAWN_TOP - 1, 0), Color = GRASS, Material = M.Grass })

	-- spawn plaza: brown rim, cream stone, a small brown ring in the middle
	disc(g, 17, SPAWN.X, SPAWN.Z, EDGE_TOP + 0.04, BORDER)
	disc(g, 15.6, SPAWN.X, SPAWN.Z, PAVE_TOP + 0.04, TILE, tileMat, tileVar)
	disc(g, 6.5, SPAWN.X, SPAWN.Z, PAVE_TOP + 0.08, BORDER)
	disc(g, 5.3, SPAWN.X, SPAWN.Z, PAVE_TOP + 0.12, TILE, tileMat, tileVar)

	-- main path, side paths to both shops, porch in front of the Rocket Shop
	path(g, -136, -7, -29, 7, true)
	path(g, -101, -34, -89, -7, false)
	path(g, -114, -35, -76, -26, true)
	path(g, -101, 7, -89, 27, false)

	-- launch pad: dark rim with yellow hazard blocks, light panelled floor
	disc(g, 24, PAD_X, 0, EDGE_TOP + 0.04, DARK)
	for i = 0, 23 do
		if i % 2 == 0 then
			local a = i / 24 * math.pi * 2
			flat(g, { Size = Vector3.new(5.6, 0.4, 1.7), CFrame = CFrame.new(PAD_X, EDGE_TOP + 0.06 - 0.2, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 23.15), Color = YELLOW })
		end
	end
	disc(g, 22.3, PAD_X, 0, PAVE_TOP + 0.04, PAD, surface("LaunchPadPanels", M.Concrete))
end

-- Spawn: an invisible SpawnLocation facing the launcher ----------------------------------------
local function spawnArea(hub)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.lookAt(SPAWN + Vector3.new(0, 0.9, 0), SPAWN + Vector3.new(1, 0.9, 0))
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = hub
end

-- Shops -----------------------------------------------------------------------------------------
local function prompt(parent, cf, title, windowName)
	local door = part(parent, { Name = "Door", Size = Vector3.new(12, 10, 1), CFrame = cf, Transparency = 1, CanCollide = false })
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Open"
	p.ObjectText = title
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = 16
	p.RequiresLineOfSight = false
	p:SetAttribute("OpenWindow", windowName)
	p.Parent = door
end

-- ServerStorage.ShopModels templates: pivot at the bottom center, doorway facing -Z, attributes
-- Width/Height/Depth and the sign spot SignY/SignZ/SignW/SignH (in the model's own space).
local SHOPS = {
	{ name = "RocketShop", spot = LobbyLayout.ROCKET_SHOP, title = "🚀 ROCKET SHOP", window = "Rockets", color = C(220, 60, 60) },
	{ name = "UpgradeLab", spot = LobbyLayout.UPGRADE_LAB, title = "⬆️ UPGRADES", window = "Upgrades", color = C(150, 90, 220) },
}
local function placeShop(hub, info)
	local center = info.spot.pos
	local face = CFrame.lookAt(center, center + info.spot.facing) -- local -Z = door side
	local folder = ServerStorage:FindFirstChild("ShopModels")
	local template = folder and folder:FindFirstChild(info.name)
	local m, depth
	local signY, signZ, signW, signH
	if template then
		m = template:Clone()
		m:PivotTo(face)
		depth = template:GetAttribute("Depth")
		signY, signZ = template:GetAttribute("SignY"), template:GetAttribute("SignZ")
		signW, signH = template:GetAttribute("SignW"), template:GetAttribute("SignH")
	else
		-- fallback if the place has no shop models: a plain colored block
		m = Instance.new("Model")
		depth = 24
		part(m, { Size = Vector3.new(30, 16, depth), CFrame = face * CFrame.new(0, 8, 0), Color = info.color })
		part(m, { Size = Vector3.new(32, 1, depth + 2), CFrame = face * CFrame.new(0, 16.5, 0), Color = WHITE })
		signY, signZ, signW, signH = 12.5, -depth / 2 - 0.35, 22, 4.4
	end
	m.Name = info.name
	m.Parent = hub
	local signPart = part(m, { Name = "Sign", Size = Vector3.new(signW, signH, 0.6), CFrame = face * CFrame.new(0, signY, signZ), Color = SIGN })
	local l = sign(signPart, Enum.NormalId.Front, info.title, WHITE, SIGN, darker(SIGN, 0.5))
	l.Parent.PixelsPerStud = 24
	prompt(m, face * CFrame.new(0, 5, -depth / 2 - 1.5), info.title:sub(info.title:find(" ") + 1), info.window)
end

-- Launcher: generated pad + tower + clamps (ServerStorage.LauncherModel.Launcher, pivot = ground
-- under the cradle). RestY = height the rocket's belly rests at; GameServer reads it.
local function launchArea(hub)
	local folder = ServerStorage:FindFirstChild("LauncherModel")
	local template = folder and folder:FindFirstChild("Launcher")
	local at = Vector3.new(PAD_X, 0, 0)
	if template then
		local m = template:Clone()
		m:PivotTo(CFrame.new(at))
		m:SetAttribute("RestY", at.Y + template:GetAttribute("RestTop"))
		m.Parent = hub
	else
		local m = Instance.new("Model")
		m.Name = "Launcher"
		cyl(m, 3, 26, CFrame.new(at + Vector3.new(0, 1.5, 0)) * UP, C(230, 235, 245), { Name = "PadBase" })
		m:SetAttribute("RestY", at.Y + 3)
		m.Parent = hub
	end
end

-- Decoration --------------------------------------------------------------------------------------
local PROPS = ServerStorage:FindFirstChild("LobbyProps")

local function prop(parent, name, x, z, yaw, opts)
	local template = PROPS and PROPS:FindFirstChild(name)
	if not template then
		return nil
	end
	opts = opts or {}
	local m = template:Clone()
	if opts.scale then
		m:ScaleTo(m:GetScale() * opts.scale)
	end
	m:PivotTo(CFrame.new(x, opts.y or LAWN_TOP, z) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	if opts.leaf then
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Name == "LeafPart" then
				p.Color = opts.leaf
			end
		end
	end
	m.Parent = parent
	return m
end

-- small plants around a tree or rock, never on paths / in front of doors
local COVER = { "Fern1", "Fern2", "Grass1", "Grass3", "Mushroom1", "Mushroom2", "Bush", "Plant", "Grass1", "Fern1" }
local function scatter(parent, rng, x, z, n, r0, r1)
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(r0, r1)
		local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
		if LobbyLayout.inPark(px, pz) and not LobbyLayout.isBlocked(px, pz, 3) then
			prop(parent, COVER[rng:NextInteger(1, #COVER)], px, pz, rng:NextNumber(0, 360))
		end
	end
end

-- { prop, x, z, yaw, leaf color }
local TREES = {
	{ "Oak", -172, -34, 20, LEAF.green },
	{ "OakBig", -174, 36, 200, LEAF.gold },
	{ "Pine", -136, -42, 0 },
	{ "Pine", -134, 44, 70 },
	{ "Oak", -130, -76, 90, LEAF.pink },
	{ "Oak", -130, 78, 0, LEAF.orange },
	{ "OakBig", -60, -50, 45, LEAF.green },
	{ "Oak", -58, 52, 160, LEAF.pink },
	{ "Pine", -40, -66, 10 },
	{ "Pine", -38, 70, 40 },
	{ "Oak", -16, -60, 300, LEAF.orange },
	{ "Oak", -14, 62, 120, LEAF.gold },
}

-- grass-topped simulator hills along the back edges, each with a tree on top
local HILLS = {
	{ "Hill1", -176, -70, 0, 1.0, { "Oak", LEAF.gold } },
	{ "Hill3", -176, 70, 90, 0.9, { "Pine" } },
	{ "Hill2", -88, -86, 30, 0.95, { "Oak", LEAF.orange } },
	{ "Hill4", -88, 86, 200, 1.0, { "OakBig", LEAF.green } },
	{ "Hill1", -150, -86, 140, 0.7 },
	{ "Hill2", -150, 86, 250, 0.75 },
}

local ROCKS = {
	{ "RockA", -182, -50, 30 },
	{ "RockB", -182, 52, 100 },
	{ "RockC", -146, -62, 0 },
	{ "RockC", -148, 62, 45 },
	{ "RockA", -46, -36, 200 },
	{ "RockB", -44, 38, 10 },
	{ "RockC", -68, -30, 0 },
	{ "RockC", -66, 32, 120 },
}

local function decor(hub)
	if not PROPS then
		return
	end
	local d = Instance.new("Model")
	d.Name = "Decor"
	d.Parent = hub
	local rng = Random.new(2026)

	for _, t in ipairs(TREES) do
		prop(d, t[1], t[2], t[3], t[4], { leaf = t[5] })
		scatter(d, rng, t[2], t[3], 3, 6, 12)
	end
	for _, h in ipairs(HILLS) do
		local hill = prop(d, h[1], h[2], h[3], h[4], { scale = h[5] })
		if hill and h[6] then
			local top = hill:GetBoundingBox().Position.Y + select(2, hill:GetBoundingBox()).Y / 2
			prop(d, h[6][1], h[2] + 2, h[3], rng:NextNumber(0, 360), { y = top - 1, leaf = h[6][2], scale = 0.8 })
		end
	end
	for _, r in ipairs(ROCKS) do
		prop(d, r[1], r[2], r[3], r[4])
		scatter(d, rng, r[2], r[3], 2, 4, 9)
	end

	-- lanterns along the main path (the lantern hangs over the path), flowers between them
	for i, x in ipairs({ -128, -112, -76, -58, -40 }) do
		prop(d, "Lamp", x, 10.2, 0)
		prop(d, "Lamp", x, -10.2, 180)
		local fx = x + 9
		if not LobbyLayout.isBlocked(fx, 11.5, 0.5) then
			prop(d, i % 2 == 0 and "FlowerRed" or "FlowerYellow", fx, 11.8, rng:NextNumber(0, 360))
			prop(d, i % 2 == 0 and "FlowerYellow" or "FlowerRed", fx, -11.8, rng:NextNumber(0, 360))
		end
	end
	-- flower ring around the spawn plaza (open toward the path)
	for i = 1, 9 do
		local a = math.rad(40 + (i - 1) * 35)
		prop(d, ({ "FlowerRed", "FlowerYellow", "FlowerGreen" })[i % 3 + 1], SPAWN.X + math.cos(a) * 20.5, SPAWN.Z + math.sin(a) * 20.5, rng:NextNumber(0, 360))
	end

	-- cargo beside the launch pad
	prop(d, "Crate", -34, -28, 10)
	prop(d, "Crate", -29, -29, 35)
	prop(d, "Crate", -31.5, -28.5, 20, { y = LAWN_TOP + 4.9 })
	prop(d, "Barrel", -37, -21, 0)
	prop(d, "Barrel", -33, -22, 0)
	prop(d, "Barrel", -34, 25, 0)
	prop(d, "Crate", -30, 28, -15)
	prop(d, "Barrel", -38, 29, 0)

	-- wooden fence around the lawn (open on the launch side), with gaps where the hills stand
	local function blockedByHill(x, z)
		for _, h in ipairs(HILLS) do
			if (x - h[2]) ^ 2 + (z - h[3]) ^ 2 < (17 * h[5]) ^ 2 then
				return true
			end
		end
		return false
	end
	local FENCE = 11.5
	local px0, pz0, px1, pz1 = LobbyLayout.PARK[1] + 1, LobbyLayout.PARK[2] - 0.5, Config.LAUNCH_X - 30, LobbyLayout.PARK[4] + 0.5
	for x = px0 + FENCE / 2, px1, FENCE do
		for _, z in ipairs({ pz0, pz1 }) do
			if not blockedByHill(x, z) then
				prop(d, "Fence", x, z, 0)
			end
		end
	end
	for z = pz0 + FENCE / 2, pz1 - FENCE / 2, FENCE do
		if not blockedByHill(px0, z) then
			prop(d, "Fence", px0, z, 90)
		end
	end

	-- welcome board at the edge of the spawn plaza, its +X face turned toward where players spawn
	local bx, bz = -150, -25
	local toward = Vector3.new(SPAWN.X - 18, 0, 0) - Vector3.new(bx, 0, bz)
	local board = prop(d, "Board", bx, bz, math.deg(math.atan2(-toward.Z, toward.X)), { scale = 0.8 })
	if board then
		local cf = board:GetPivot()
		local h, w = board:GetAttribute("Height") * 0.8, board:GetAttribute("Width") * 0.8
		local s = part(board, { Name = "Title", Size = Vector3.new(15, 7.5, 0.4), CFrame = cf * CFrame.new(w / 2 + 0.25, h * 0.6, 0) * CFrame.Angles(0, -math.pi / 2, 0), Color = SIGN })
		local l = sign(s, Enum.NormalId.Front, "🚀 ROCKET\nSIMULATOR", WHITE, SIGN, darker(SIGN, 0.5))
		l.Parent.PixelsPerStud = 20
	end
end

function Lobby.build(hub)
	ground(hub)
	spawnArea(hub)
	for _, info in ipairs(SHOPS) do
		placeShop(hub, info)
	end
	launchArea(hub)
	decor(hub)
end

return Lobby
