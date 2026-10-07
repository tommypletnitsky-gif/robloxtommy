-- The starting area: a cheerful launch park.
--   spawn plaza -> lantern-lined stone path (the two shops on either side) -> launch pad + cannon.
--   Groves, blue rocks and grass-topped simulator hills frame the edges; the middle stays open so the
--   shops and the cannon are what you see first.
--   Props: Creator Store packs (scripts/lights stripped) in ServerStorage.LobbyProps, see their
--   Source attribute. Shops: ServerStorage.ShopModels. Launch cannon: ServerStorage.CannonModel.
--   Paths / pad use generated MaterialVariants when the place has them (LobbyPathTiles,
--   LaunchPadPanels) and plain materials otherwise.
-- Nothing in the lobby glows or emits light.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local CollectionService = game:GetService("CollectionService")

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
local GRASS = C(112, 200, 76) -- bright lawn green, matches the terrain (built-in Grass texture)
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
local PROPS = ServerStorage:FindFirstChild("LobbyProps") -- Creator Store props (see their Source attribute)
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

-- Launch cannon: generated cartoon cannon (ServerStorage.CannonModel.Cannon, pivot = ground under
-- its middle, muzzle +X; attributes MuzzleLocal / LoadLocal / Tilt). Placed so the muzzle sits just
-- before the start line. The world attributes set here are read by GameServer (LoadX / LoadY /
-- Tilt = where the rocket is loaded) and RocketClient (Muzzle / Aim = smoke + recoil).
local function launchArea(hub)
	local folder = ServerStorage:FindFirstChild("CannonModel")
	local template = folder and folder:FindFirstChild("Cannon")
	local m
	local muzzle, load, tilt
	if template then
		m = template:Clone()
		local pivot = CFrame.new(Config.LAUNCH_X + 2 - template:GetAttribute("MuzzleLocal").X, 0, 0)
		m:PivotTo(pivot)
		muzzle = pivot * template:GetAttribute("MuzzleLocal")
		load = pivot * template:GetAttribute("LoadLocal")
		tilt = template:GetAttribute("Tilt")
	else
		m = Instance.new("Model")
		tilt = math.rad(8)
		cyl(m, 24, 9, CFrame.new(PAD_X, 10, 0) * CFrame.Angles(0, 0, tilt), C(220, 60, 60), { Name = "Barrel", CanCollide = false })
		muzzle = Vector3.new(PAD_X + 12, 11.7, 0)
		load = Vector3.new(PAD_X + 3, 10.4, 0)
	end
	m.Name = "Cannon"
	m:SetAttribute("LoadX", load.X)
	m:SetAttribute("LoadY", load.Y)
	m:SetAttribute("Tilt", tilt)
	m:SetAttribute("Muzzle", muzzle)
	m:SetAttribute("Aim", Vector3.new(math.cos(tilt), math.sin(tilt), 0))
	m.Parent = hub
end

-- Egg Garden ---------------------------------------------------------------------------------------
-- A round plaza beside the spawn with one stand per egg (Config.Eggs) in an arc: pedestal, the egg
-- (ReplicatedStorage.EggModels, spun + bobbed by LobbyClient), a name/price board (PetClient marks
-- locked eggs per player) and an E prompt with attribute Egg = id (PetClient opens the egg window).
local function fallbackEgg(color)
	local m = Instance.new("Model")
	local p = part(m, { Name = "Shell", Size = Vector3.new(3.6, 4.6, 3.6), CFrame = CFrame.new(0, 2.3, 0), Color = color })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	m.WorldPivot = CFrame.new()
	return m
end

local function eggGarden(hub)
	local g = LobbyLayout.EGG_GARDEN
	local cx, cz = g.center.X, g.center.Z
	local m = Instance.new("Model")
	m.Name = "EggGarden"
	m.Parent = hub
	local tileMat, tileVar = surface("LobbyPathTiles", M.Cobblestone)
	path(m, -155, 15, -145, 31, false)
	disc(m, g.radius, cx, cz, EDGE_TOP + 0.04, BORDER)
	disc(m, g.radius - 1.4, cx, cz, PAVE_TOP + 0.04, TILE, tileMat, tileVar)
	disc(m, 5, cx, cz, PAVE_TOP + 0.08, BORDER)
	disc(m, 3.8, cx, cz, PAVE_TOP + 0.12, TILE, tileMat, tileVar)

	local eggModels = ReplicatedStorage:FindFirstChild("EggModels")
	for i, egg in ipairs(Config.Eggs) do
		local pos = LobbyLayout.eggStand(i, #Config.Eggs)
		local stand = Instance.new("Model")
		stand.Name = "Egg_" .. egg.id
		stand:SetAttribute("Egg", egg.id)
		stand.Parent = m
		cyl(stand, 1.2, 7, CFrame.new(pos + Vector3.new(0, PAVE_TOP + 0.6, 0)) * UP, BORDER)
		cyl(stand, 1, 6, CFrame.new(pos + Vector3.new(0, PAVE_TOP + 1.7, 0)) * UP, TILE)
		cyl(stand, 0.4, 6.4, CFrame.new(pos + Vector3.new(0, PAVE_TOP + 2.3, 0)) * UP, egg.color)
		local top = PAVE_TOP + 2.5

		local template = eggModels and eggModels:FindFirstChild(egg.id)
		local e = template and template:Clone() or fallbackEgg(egg.color)
		e.Name = "Egg"
		e:PivotTo(CFrame.new(pos + Vector3.new(0, top, 0)))
		for _, p in ipairs(e:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
			end
		end
		e:SetAttribute("SpinSpeed", 0.7)
		e:SetAttribute("Bob", 0.35)
		e.Parent = stand
		CollectionService:AddTag(e, "LobbySpin")

		-- name / price board floating above the egg
		local anchor = part(stand, { Name = "Board", Size = Vector3.one, CFrame = CFrame.new(pos + Vector3.new(0, top + 7, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(8, 3.5) -- in studs, so far-away boards shrink and don't overlap
		bb.MaxDistance = 44 -- only boards near you (from the spawn they stacked into a pile)
		bb.LightInfluence = 0
		bb.Parent = anchor
		local function line(name, y, h, text, color)
			local l = Instance.new("TextLabel")
			l.Name = name
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0, y)
			l.Size = UDim2.fromScale(1, h)
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.Text = text
			l.TextColor3 = color
			local st = Instance.new("UIStroke")
			st.Thickness = 2.5
			st.Color = Color3.fromRGB(30, 30, 50)
			st.Parent = l
			l.Parent = bb
			return l
		end
		line("Title", 0, 0.42, egg.name, WHITE)
		line("Price", 0.42, 0.32, "$" .. Config.abbreviate(egg.price), C(130, 255, 130))
		line("Lock", 0.74, 0.26, "Stage " .. egg.stage, C(255, 220, 120))

		local hit = part(stand, { Name = "PromptPart", Size = Vector3.new(5, 6, 5), CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0)), Transparency = 1, CanCollide = false, CanTouch = false })
		local p = Instance.new("ProximityPrompt")
		p.ActionText = "Open"
		p.ObjectText = egg.name
		p.KeyboardKeyCode = Enum.KeyCode.E
		p.MaxActivationDistance = 11
		p.RequiresLineOfSight = false
		p:SetAttribute("Egg", egg.id)
		p.Parent = hit
	end
end

-- Rebirth Portal ------------------------------------------------------------------------------------
-- A round plaza on the other side of the spawn with the stone portal at its back, a sign and an
-- E prompt (attribute OpenWindow = "Rebirth"; RebirthClient opens the window).
local function rebirthPortal(hub)
	local r = LobbyLayout.REBIRTH
	local cx, cz = r.center.X, r.center.Z
	local m = Instance.new("Model")
	m.Name = "RebirthPortal"
	m.Parent = hub
	local tileMat, tileVar = surface("LobbyPathTiles", M.Cobblestone)
	path(m, -155, -35, -145, -15, false)
	disc(m, r.radius, cx, cz, EDGE_TOP + 0.04, BORDER)
	disc(m, r.radius - 1.4, cx, cz, PAVE_TOP + 0.04, TILE, tileMat, tileVar)
	disc(m, 5, cx, cz, PAVE_TOP + 0.08, C(165, 105, 245))
	disc(m, 3.8, cx, cz, PAVE_TOP + 0.12, TILE, tileMat, tileVar)

	local at = r.portal
	local face = CFrame.lookAt(at, at + Vector3.new(0, 0, 1)) -- opening toward the spawn
	local template = PROPS and PROPS:FindFirstChild("Portal")
	local h = 20
	if template then
		local p = template:Clone()
		p:PivotTo(CFrame.new(at.X, PAVE_TOP, at.Z) * CFrame.Angles(0, math.rad(90), 0))
		p.Parent = m
		h = template:GetAttribute("Height") or h
	else
		part(m, { Size = Vector3.new(18, h, 3), CFrame = CFrame.new(at.X, h / 2, at.Z), Color = C(150, 150, 165) })
	end
	local signPart = part(m, { Name = "Sign", Size = Vector3.new(16, 3.6, 0.6), CFrame = face * CFrame.new(0, h + 2.4, 0), Color = SIGN })
	local l = sign(signPart, Enum.NormalId.Front, "🌟 REBIRTH", WHITE, SIGN, darker(SIGN, 0.5))
	l.Parent.PixelsPerStud = 24
	prompt(m, face * CFrame.new(0, 5, 3), "Rebirth", "Rebirth")
end

-- Decoration --------------------------------------------------------------------------------------

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
	{ "OakBig", -178, 26, 200, LEAF.gold },
	{ "Pine", -128, -48, 0 },
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
	{ "Hill3", -180, 76, 90, 0.9, { "Pine" } },
	{ "Hill2", -88, -86, 30, 0.95, { "Oak", LEAF.orange } },
	{ "Hill4", -88, 86, 200, 1.0, { "OakBig", LEAF.green } },
	{ "Hill1", -150, -86, 140, 0.7 },
	{ "Hill2", -150, 86, 250, 0.75 },
}

local ROCKS = {
	{ "RockA", -182, -50, 30 },
	{ "RockB", -182, 52, 100 },
	{ "RockC", -134, -66, 0 },
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
	-- flower ring around the spawn plaza (open toward the main path and the Egg Garden path; the
	-- signpost stands in the gap at 40 degrees)
	for i, deg in ipairs({ 128, 160, 200, 232, 312 }) do
		local a = math.rad(deg)
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

	-- welcome board behind the spawn plaza, facing down the path to the launcher
	local bx, bz = -176, 0
	local toward = Vector3.new(1, 0, 0)
	local board = prop(d, "Board", bx, bz, math.deg(math.atan2(-toward.Z, toward.X)), { scale = 0.8 })
	if board then
		local cf = board:GetPivot()
		local h, w = board:GetAttribute("Height") * 0.8, board:GetAttribute("Width") * 0.8
		local s = part(board, { Name = "Title", Size = Vector3.new(15, 7.5, 0.4), CFrame = cf * CFrame.new(w / 2 + 0.25, h * 0.6, 0) * CFrame.Angles(0, -math.pi / 2, 0), Color = SIGN })
		local l = sign(s, Enum.NormalId.Front, "🚀 ROCKET\nSIMULATOR", WHITE, SIGN, darker(SIGN, 0.5))
		l.Parent.PixelsPerStud = 20
	end
end

-- Wayfinding ------------------------------------------------------------------------------------------
-- A wooden fingerpost at the plaza's edge (in the flower ring's gap toward the main path) with an
-- arrow board per place in its landmark colour, and pink / purple stepping stones across the plaza
-- to the Egg Garden and Rebirth paths (the plaza already reaches both path entrances).
local POST_AT = SPAWN + Vector3.new(math.cos(math.rad(40)), 0, math.sin(math.rad(40))) * 20.5 -- ~(-134.3, 13.2), clear of the lamp at (-128, 10.2)
local ARROWS = { -- { text, colour, direction, height of the board's middle }
	{ "🥚 EGGS", C(255, 120, 190), Vector3.new(0, 0, 1), 8 },
	{ "🌟 REBIRTH", C(170, 105, 245), Vector3.new(0, 0, -1), 6.5 },
	{ "🚀 LAUNCH", C(255, 150, 40), Vector3.new(1, 0, 0), 5 },
}

local function wayfinding(hub)
	local m = Instance.new("Model")
	m.Name = "Wayfinding"
	m.Parent = hub
	local wood = darker(BORDER, 0.2)
	local x, z = POST_AT.X, POST_AT.Z
	part(m, { Name = "Post", Size = Vector3.new(0.9, 9, 0.9), CFrame = CFrame.new(x, LAWN_TOP + 4.5, z), Color = wood, Material = M.Wood })
	part(m, { Name = "Cap", Size = Vector3.new(1.3, 0.4, 1.3), CFrame = CFrame.new(x, LAWN_TOP + 9.2, z), Color = darker(wood, 0.25), Material = M.Wood })

	-- boards start just behind the post and stick out 4 studs (+ the point), so the REBIRTH one
	-- stays off the main path and the LAUNCH one short of the lamp; no collision (they're at head height)
	local L, H, BACK = 4.4, 1.3, 0.35
	for _, a in ipairs(ARROWS) do
		local color, dir = a[2], a[3]
		local at = Vector3.new(x, LAWN_TOP + a[4], z)
		local base = CFrame.lookAt(at, at + dir)
		local board = part(m, { Name = "Arrow", Size = Vector3.new(0.3, H, L), CFrame = base * CFrame.new(0, 0, BACK - L / 2), Color = color, CanCollide = false })
		-- the point: a diamond centred on the board's end, its front half sticking out
		part(m, { Name = "Point", Size = Vector3.new(0.28, H / math.sqrt(2), H / math.sqrt(2)), CFrame = base * CFrame.new(0, 0, BACK - L) * CFrame.Angles(math.pi / 4, 0, 0), Color = color, CanCollide = false })
		for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
			local l = sign(board, face, a[1], WHITE, color, darker(color, 0.5))
			l.Parent.PixelsPerStud = 40
		end
	end

	-- stepping stones from the plaza's middle ring to each path entrance, zig-zagging a little
	for _, t in ipairs({ { 1, ARROWS[1][2] }, { -1, ARROWS[2][2] } }) do
		for k = 0, 3 do
			disc(m, 1.25, SPAWN.X + (k % 2 == 0 and -0.9 or 0.9), SPAWN.Z + t[1] * (8.6 + k * 2.6), PAVE_TOP + 0.1, t[2])
		end
	end
end

-- Leaderboard beside the main path (ExtrasServer fills in the rows and flips between
-- Farthest Flights / Most Earned / Most Rebirths / Top Supporters).
local function topBoard(hub)
	local m = Instance.new("Model")
	m.Name = "TopBoard"
	m.Parent = hub
	local W, H, BOTTOM = 17, 13, 3.2
	local x, z = -67, -24
	local face = Vector3.new(-0.35, 0, 1).Unit -- looks at the path, turned a bit toward the spawn
	local center = Vector3.new(x, LAWN_TOP + BOTTOM + H / 2, z)
	local cf = CFrame.lookAt(center, center + face)
	for _, side in ipairs({ -1, 1 }) do
		local base = (cf * CFrame.new(side * (W / 2 - 0.6), 0, 0.5)).Position
		cyl(m, BOTTOM + H + 0.6, 1.1, CFrame.new(base.X, LAWN_TOP + (BOTTOM + H + 0.6) / 2, base.Z) * UP, darker(BORDER, 0.2))
	end
	part(m, { Name = "Frame", Size = Vector3.new(W + 1, H + 1, 0.8), CFrame = cf * CFrame.new(0, 0, 0.45), Color = darker(SIGN, 0.35) })
	local panel = part(m, { Name = "Panel", Size = Vector3.new(W, H, 0.4), CFrame = cf, Color = WHITE })
	local roof = part(m, { Name = "Roof", Size = Vector3.new(W + 2, 1, 2), CFrame = cf * CFrame.new(0, H / 2 + 0.9, 0.3), Color = SIGN })
	roof.Material = M.SmoothPlastic
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = panel
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = WHITE
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(C(255, 255, 255), C(214, 230, 255))
	grad.Parent = bg
	local function text(name, y, h, color, stroke)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.04, y)
		l.Size = UDim2.fromScale(0.92, h)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = ""
		l.Parent = bg
		if stroke then
			local s = Instance.new("UIStroke")
			s.Thickness = 4
			s.Color = C(30, 30, 50)
			s.Parent = l
		end
		return l
	end
	local title = text("Title", 0.02, 0.14, C(255, 200, 50), true)
	title.Text = "🚀 FARTHEST FLIGHTS"
	text("Subtitle", 0.16, 0.06, C(90, 100, 140), false)
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0.04, 0.24)
	rows.Size = UDim2.fromScale(0.92, 0.74)
	rows.Parent = bg
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.005, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows
end

-- Landmarks: a soft light pillar + a big floating label over the places that matter (cannon,
-- Egg Garden, Rebirth Portal), so you can find them from anywhere in the lobby.
local function landmark(hub, name, pos, color, text, height, labelWidth)
	local m = Instance.new("Model")
	m.Name = "Landmark_" .. name
	m.Parent = hub
	local base = part(m, { Name = "Base", Size = Vector3.one, CFrame = CFrame.new(pos), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local a0 = Instance.new("Attachment")
	a0.Parent = base
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, height, 0)
	a1.Parent = base
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = 4.5, 6.5
	beam.FaceCamera = true
	beam.LightEmission = 0.35
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(color, color:Lerp(WHITE, 0.4))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1) })
	beam.Segments = 2
	beam.Parent = base
	-- the label: sized in studs, so it shrinks with distance instead of covering the screen
	local labelPart = part(m, { Name = "Label", Size = Vector3.one, CFrame = CFrame.new(pos + Vector3.new(0, height * 0.75, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(labelWidth or 16, (labelWidth or 16) / 4)
	bb.MaxDistance = 400
	bb.LightInfluence = 0
	bb.Parent = labelPart
	local bg = Instance.new("Frame")
	bg.AnchorPoint = Vector2.new(0.5, 0.5)
	bg.Position = UDim2.fromScale(0.5, 0.5)
	bg.Size = UDim2.fromScale(1, 0.8)
	bg.BackgroundColor3 = WHITE
	bg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = C(30, 30, 50)
	stroke.Parent = bg
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(color:Lerp(WHITE, 0.35), darker(color, 0.15))
	grad.Parent = bg
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(0.92, 0.8)
	l.Position = UDim2.fromScale(0.04, 0.1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = WHITE
	l.Text = text
	l.Parent = bg
	local ts = Instance.new("UIStroke")
	ts.Thickness = 3
	ts.Color = C(30, 30, 50)
	ts.Parent = l
	-- gentle bob (LobbyClient animates everything tagged LobbySpin)
	labelPart:SetAttribute("SpinSpeed", 0)
	labelPart:SetAttribute("Bob", 0.7)
	CollectionService:AddTag(labelPart, "LobbySpin")
end

function Lobby.build(hub)
	topBoard(hub)
	landmark(hub, "Cannon", Vector3.new(PAD_X, LAWN_TOP, 0), C(255, 150, 40), "🚀 LAUNCH PAD", 50, 36)
	landmark(hub, "Eggs", LobbyLayout.EGG_GARDEN.center + Vector3.new(0, LAWN_TOP, 0), C(255, 120, 190), "🥚 EGGS", 36, 15)
	landmark(hub, "Rebirth", LobbyLayout.REBIRTH.portal + Vector3.new(0, LAWN_TOP, 0), C(170, 105, 245), "🌟 REBIRTH", 36, 16)
	ground(hub)
	spawnArea(hub)
	for _, info in ipairs(SHOPS) do
		placeShop(hub, info)
	end
	launchArea(hub)
	eggGarden(hub)
	rebirthPortal(hub)
	wayfinding(hub)
	decor(hub)
end

return Lobby
