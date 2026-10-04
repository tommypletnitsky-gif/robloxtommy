-- The starting area: a cartoon space-center park.
--   spawn plaza -> flower avenue + entrance arch -> round flower-garden plaza -> launch apron
--   Rocket Shop hangar (north) and Upgrade Lab dome (south) open onto the central plaza.
-- Radar dishes are tagged LobbySpin for LobbyClient. Nothing in the lobby glows or emits light.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local RocketModel = require(ReplicatedStorage.Shared.RocketModel)
local Kit = require(ServerScriptService.BuildKit)
local Foliage = require(ServerScriptService.Foliage)
local LobbyLayout = require(ServerScriptService.LobbyLayout)

local part, ball, cyl, column, beam, sign = Kit.part, Kit.ball, Kit.cyl, Kit.column, Kit.beam, Kit.sign
local darker, lighter = Kit.darker, Kit.lighter
local UP = Kit.UP
local C = Color3.fromRGB
local M = Enum.Material

local Lobby = {}

local WHITE = C(255, 255, 255)
local CREAM = C(250, 244, 230)
local STONE = C(225, 228, 238)
local BLUE = C(70, 140, 255)
local PURPLE = C(170, 80, 240)
local ORANGE = C(255, 150, 40)
local YELLOW = C(255, 210, 50)
local PINK = C(255, 110, 170)
local GREEN = C(90, 190, 90)
local SIGN = C(53, 139, 204) -- #358bcc, every sign in the lobby
local LAWN = C(119, 221, 119) -- #77dd77, the lobby grass
local APRON = C(196, 208, 217) -- #c4d0d9, the launch area floor
local FLOWERS = { C(255, 120, 180), YELLOW, WHITE, C(255, 90, 90), C(190, 120, 255) }

local SPAWN = LobbyLayout.SPAWN
local PLAZA = LobbyLayout.PLAZA
local PAD_X = Config.LAUNCH_X - 8

local function tag(inst, name)
	CollectionService:AddTag(inst, name)
	return inst
end

-- A flat disc lying on the ground (y = top surface height).
local function disc(parent, diameter, center, top, color, props)
	local t = { Material = M.SmoothPlastic, CastShadow = false }
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return cyl(parent, 0.3, diameter, CFrame.new(center.X, top - 0.15, center.Z) * UP, color, t)
end

-- Trees + bushes: Foliage (Yasu's Stylized Tree Pack), colorful "park" palette.
local BLOSSOM = Foliage.PALETTES.blossom[1]

function Lobby.tree(parent, pos, rng, height, palette)
	Foliage.tree(parent, pos, rng, height, palette or "park")
end

function Lobby.bush(parent, pos, rng, size, palette)
	Foliage.bush(parent, pos, rng, size, palette or "park")
end

-- Ground: lawn, spawn plaza, avenues, statue plaza, launch apron, hedges ------------------------
local function ground(hub, rng)

	-- spawn plaza: concentric rings
	disc(hub, 44, SPAWN, 0.45, STONE, { Material = M.Marble })
	disc(hub, 38, SPAWN, 0.5, BLUE)
	disc(hub, 32, SPAWN, 0.55, CREAM, { Material = M.CeramicTiles })
	disc(hub, 16, SPAWN, 0.7, C(150, 200, 235))
	disc(hub, 13, SPAWN, 0.8, CREAM, { Material = M.CeramicTiles })

	-- avenue spawn -> statue plaza, and statue plaza -> launch apron
	local function avenue(x0, x1)
		local len, mid = x1 - x0, (x0 + x1) / 2
		part(hub, { Size = Vector3.new(len, 0.4, 18), CFrame = CFrame.new(mid, 0.4, 0), Color = C(215, 205, 190), Material = M.Cobblestone, CastShadow = false })
		for _, side in ipairs({ -1, 1 }) do
			part(hub, { Size = Vector3.new(len, 0.45, 1.4), CFrame = CFrame.new(mid, 0.42, side * 8.3), Color = ORANGE, CastShadow = false })
		end
	end
	avenue(-131, -104)
	avenue(-56, -38)

	-- statue plaza: rings + star rays
	disc(hub, 56, PLAZA, 0.45, STONE, { Material = M.Marble })
	disc(hub, 50, PLAZA, 0.5, ORANGE)
	disc(hub, 46, PLAZA, 0.55, CREAM, { Material = M.CeramicTiles })

	-- side paths to the two buildings
	for _, side in ipairs({ -1, 1 }) do
		part(hub, { Size = Vector3.new(12, 0.4, 16), CFrame = CFrame.new(PLAZA.X, 0.4, side * 33), Color = C(215, 205, 190), Material = M.Cobblestone, CastShadow = false })
	end

	-- launch apron: dark concrete with hazard stripes along the edges
	local ax0, ax1, az = -40, 4, 32
	part(hub, { Name = "Apron", Size = Vector3.new(ax1 - ax0, 0.4, az * 2), CFrame = CFrame.new((ax0 + ax1) / 2, 0.4, 0), Color = APRON, CastShadow = false })
	for x = ax0, ax1 - 4, 4 do
		for _, side in ipairs({ -1, 1 }) do
			part(hub, { Size = Vector3.new(4, 0.45, 1.6), CFrame = CFrame.new(x + 2, 0.43, side * (az - 0.8)), Color = (x / 4) % 2 == 0 and YELLOW or C(40, 40, 45), CastShadow = false })
		end
	end

	-- white picket fence around the park (open at the launch side)
	local function fence(a, b)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		for d = 0, len, 4 do
			local q = a + dir * d
			part(hub, { Size = Vector3.new(0.8, 3.4, 0.8), CFrame = CFrame.lookAt(q + Vector3.new(0, 1.7, 0), q + Vector3.new(0, 1.7, 0) + dir), Color = WHITE })
			part(hub, { Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.lookAt(q + Vector3.new(0, 3.55, 0), q + Vector3.new(0, 3.55, 0) + dir) * CFrame.Angles(0, 0, math.rad(45)), Color = WHITE })
		end
		for _, y in ipairs({ 1.2, 2.6 }) do
			beam(hub, a + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0), 0.4, WHITE)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		fence(Vector3.new(-185, 0.3, side * 84), Vector3.new(-15, 0.3, side * 84))
	end
	fence(Vector3.new(-185, 0.3, -84), Vector3.new(-185, 0.3, 84))
end

-- Spawn: invisible SpawnLocation on the glowing pad, title arch ---------------------------------
local function spawnArea(hub, rng)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.lookAt(SPAWN + Vector3.new(0, 0.9, 0), SPAWN + Vector3.new(1, 0.9, 0))
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = hub

	-- entrance arch over the avenue
	local ax = -118
	for _, side in ipairs({ -1, 1 }) do
		local foot = Vector3.new(ax, 0, side * 12)
		column(hub, 22, 4.4, foot, WHITE)
		for i = 0, 3 do
			column(hub, 2.2, 4.7, foot + Vector3.new(0, 3 + i * 5, 0), i % 2 == 0 and ORANGE or BLUE)
		end
		column(hub, 1.5, 6, foot, darker(BLUE, 0.2))
		ball(hub, 5.5, foot + Vector3.new(0, 23.5, 0), YELLOW)
	end
	local banner = part(hub, { Name = "TitleBanner", Size = Vector3.new(2, 8, 30), CFrame = CFrame.new(ax, 19, 0), Color = SIGN })
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		local l = sign(banner, face, "ROCKET SIMULATOR", YELLOW, SIGN, darker(SIGN, 0.5))
		l.Parent.PixelsPerStud = 20
	end

end

-- Central plaza: a low round grass island (keeps the view to the launch pad open) -------------
local function statuePlaza(hub, rng)
	-- stone curb + grass island
	cyl(hub, 1.2, 26, CFrame.new(PLAZA + Vector3.new(0, 0.9, 0)) * UP, STONE)
	cyl(hub, 1.3, 23, CFrame.new(PLAZA + Vector3.new(0, 0.95, 0)) * UP, LAWN, { Material = M.Grass })
end

-- Buildings -----------------------------------------------------------------------------------
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

local function radarDish(parent, pos)
	local m = Instance.new("Model")
	m.Name = "Radar"
	m.Parent = parent
	column(m, 4, 1, pos, C(200, 200, 210))
	local head = pos + Vector3.new(0, 5, 0)
	cyl(m, 0.8, 7, CFrame.new(head) * CFrame.Angles(0, 0, math.rad(55)), WHITE)
	beam(m, head, head + Vector3.new(2.5, 2, 0), 0.3, C(200, 200, 210))
	ball(m, 0.9, head + Vector3.new(2.6, 2.1, 0), C(255, 80, 80), {})
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	m:SetAttribute("SpinSpeed", 1.2)
	tag(m, "LobbySpin")
end

-- Detailed shop buildings generated in Studio (generate_mesh), stored in ServerStorage.ShopModels:
-- pivot at the bottom center, doorway facing -Z, attributes Width/Height/Depth.
-- Returns false if the model is missing so the part-built version is used instead.
local SHOP_LAYOUT = {
	RocketShop = { signY = 0.52, title = "🚀 ROCKET SHOP", window = "Rockets" },
	UpgradeLab = { signY = 0.36, title = "⬆️ UPGRADE LAB", window = "Upgrades" },
}
local function placeShop(hub, name, center, facing)
	local folder = game:GetService("ServerStorage"):FindFirstChild("ShopModels")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return false
	end
	local info = SHOP_LAYOUT[name]
	local m = template:Clone()
	m:PivotTo(CFrame.lookAt(center, center + facing))
	m.Parent = hub
	local depth, height = template:GetAttribute("Depth"), template:GetAttribute("Height")
	local front = center + facing * (depth / 2)
	local signCF = CFrame.lookAt(front + facing * 1.2 + Vector3.new(0, height * info.signY, 0), front + facing * 5 + Vector3.new(0, height * info.signY, 0))
	local signPart = part(m, { Name = "Sign", Size = Vector3.new(22, 5, 0.6), CFrame = signCF, Color = SIGN })
	local l = sign(signPart, Enum.NormalId.Front, info.title, WHITE, SIGN, darker(SIGN, 0.5))
	l.Parent.PixelsPerStud = 24
	prompt(m, CFrame.lookAt(front + facing * 2 + Vector3.new(0, 5, 0), front + facing * 5 + Vector3.new(0, 5, 0)), info.title:sub(info.title:find(" ") + 1), info.window)
	return true
end

-- Rocket Shop: a hangar with an arched roof and rockets on display inside (door faces the plaza).
local function rocketShop(hub)
	if placeShop(hub, "RocketShop", Vector3.new(PLAZA.X, 0, -54), Vector3.new(0, 0, 1)) then
		return
	end
	local center = Vector3.new(PLAZA.X, 0, -54)
	local face = CFrame.lookAt(center, center + Vector3.new(0, 0, 1)) -- local -Z = door side (toward plaza)
	local function at(x, y, z)
		return face * CFrame.new(x, y, z)
	end
	local m = Instance.new("Model")
	m.Name = "RocketShop"
	m.Parent = hub
	local W, D, H = 36, 26, 11
	local wall = lighter(BLUE, 0.1)
	part(m, { Name = "Floor", Size = Vector3.new(W, 0.6, D), CFrame = at(0, 0.5, 0), Color = C(235, 240, 250), Reflectance = 0.15 })
	part(m, { Size = Vector3.new(W, H, 1.2), CFrame = at(0, H / 2, D / 2), Color = wall })
	for _, sx in ipairs({ -1, 1 }) do
		part(m, { Size = Vector3.new(1.2, H, D), CFrame = at(sx * W / 2, H / 2, 0), Color = wall })
		part(m, { Size = Vector3.new(8, H, 1.2), CFrame = at(sx * (W / 2 - 4), H / 2, -D / 2), Color = wall })
		part(m, { Size = Vector3.new(0.4, 6, 4), CFrame = at(sx * (W / 2 + 0.3), 6, 0), Color = C(150, 220, 255), Material = M.Glass, Transparency = 0.3 })
	end
	part(m, { Size = Vector3.new(W - 16, 2, 1.2), CFrame = at(0, H - 1, -D / 2), Color = wall })
	-- arched roof made of curved slats (hollow inside)
	local R = W / 2 + 0.6
	for k = 0, 11 do
		local a1, a2 = k / 12 * math.pi, (k + 1) / 12 * math.pi
		local p1 = (at(math.cos(a1) * R, H + math.sin(a1) * R * 0.55, 0)).Position
		local p2 = (at(math.cos(a2) * R, H + math.sin(a2) * R * 0.55, 0)).Position
		local mid = (p1 + p2) / 2
		local across = p2 - p1
		-- slat: X along the curve, Z running front-to-back through the building
		part(m, { Size = Vector3.new(across.Magnitude + 0.4, 1.2, D + 3), CFrame = CFrame.fromMatrix(mid, across.Unit, face.LookVector:Cross(across.Unit).Unit), Color = k % 2 == 0 and BLUE or WHITE })
	end
	-- front + back arch faces (stacked strips so the curve reads from the plaza)
	for _, z in ipairs({ -D / 2 - 1.4, D / 2 + 1.4 }) do
		for i = 0, 4 do
			local y0 = i * (R * 0.55) / 5
			local half = R * math.sqrt(math.max(0, 1 - ((y0 + R * 0.11) / (R * 0.55)) ^ 2))
			part(m, { Size = Vector3.new(half * 2, R * 0.55 / 5 + 0.1, 1), CFrame = at(0, H + y0 + R * 0.055, z), Color = z < 0 and C(40, 60, 120) or wall })
		end
	end
	local signPart = part(m, { Name = "Sign", Size = Vector3.new(22, 5, 0.6), CFrame = at(0, H + 3.4, -D / 2 - 2.1), Color = SIGN })
	local l = sign(signPart, Enum.NormalId.Front, "🚀 ROCKET SHOP", WHITE, SIGN, darker(SIGN, 0.5))
	l.Parent.PixelsPerStud = 24
	-- neon trim around the doorway
	part(m, { Size = Vector3.new(W - 15, 0.6, 0.6), CFrame = at(0, H - 2.2, -D / 2 - 0.7), Color = C(120, 220, 255), CastShadow = false })
	-- rockets on display inside, noses up
	for i, id in ipairs({ "Turbo", "Galaxy", "Shuttle" }) do
		local x = (i - 2) * 10
		column(m, 1.6, 6, (at(x, 0.8, 4)).Position, WHITE)
		column(m, 0.3, 6.4, (at(x, 2.3, 4)).Position, C(120, 220, 255), {})
		local r = RocketModel.build(Config.getRocket(id), 0.9, false, at(x, 7.3, 4) * CFrame.Angles(0, 0, math.pi / 2))
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			elseif d:IsA("Fire") or d:IsA("ParticleEmitter") or d:IsA("Light") then
				d:Destroy() -- display rockets: no flame / light
			end
		end
		r.Parent = m
	end
	radarDish(m, (at(W / 2 - 5, H + R * 0.4, D / 2 - 5)).Position)
	prompt(m, at(0, 5, -D / 2 - 1), "ROCKET SHOP", "Rockets")
end

-- Upgrade Lab: a glass dome on a striped base, glowing tubes, blinking antenna (door faces the plaza).
local function upgradeLab(hub)
	if placeShop(hub, "UpgradeLab", Vector3.new(PLAZA.X, 0, 56), Vector3.new(0, 0, -1)) then
		return
	end
	local center = Vector3.new(PLAZA.X, 0, 56)
	local m = Instance.new("Model")
	m.Name = "UpgradeLab"
	m.Parent = hub
	column(m, 10, 32, center, WHITE)
	column(m, 2, 32.6, center + Vector3.new(0, 3, 0), PURPLE)
	column(m, 1, 32.6, center + Vector3.new(0, 7, 0), PINK)
	ball(m, 31, center + Vector3.new(0, 10, 0), C(200, 170, 255), { Material = M.Glass, Transparency = 0.25, Reflectance = 0.2 })
	ball(m, 6, center + Vector3.new(0, 12, 0), C(150, 255, 200), {})
	-- antenna
	column(m, 12, 0.8, center + Vector3.new(0, 24, 0), C(200, 200, 210))
	ball(m, 1.6, center + Vector3.new(0, 36.5, 0), C(255, 60, 90), {})
	-- entrance porch toward the plaza (-Z)
	local porch = center + Vector3.new(0, 0, -17)
	part(m, { Size = Vector3.new(14, 10, 8), CFrame = CFrame.new(porch + Vector3.new(0, 5, 0)), Color = lighter(PURPLE, 0.2) })
	part(m, { Size = Vector3.new(8, 7, 0.4), CFrame = CFrame.new(porch + Vector3.new(0, 3.5, -4.1)), Color = C(40, 20, 70) })
	part(m, { Size = Vector3.new(8.6, 0.5, 0.5), CFrame = CFrame.new(porch + Vector3.new(0, 7.2, -4.3)), Color = C(150, 255, 200), CastShadow = false })
	local signPart = part(m, { Name = "Sign", Size = Vector3.new(20, 4.5, 0.6), CFrame = CFrame.new(porch + Vector3.new(0, 12.6, -2)), Color = SIGN })
	local l = sign(signPart, Enum.NormalId.Front, "⬆️ UPGRADE LAB", WHITE, SIGN, darker(SIGN, 0.5))
	l.Parent.PixelsPerStud = 24
	-- glowing tubes
	for i, col in ipairs({ C(120, 255, 170), C(120, 220, 255), C(255, 120, 220) }) do
		local p = center + Vector3.new(-14 + (i - 1) * 14, 0, -14 + (i == 2 and -4 or 0))
		if i == 2 then
			p = center + Vector3.new(15, 0, -6)
		end
		column(m, 1, 4, p, C(60, 60, 80))
		column(m, 8, 2.6, p + Vector3.new(0, 1, 0), col, { Transparency = 0.25 })
		ball(m, 3, p + Vector3.new(0, 9.5, 0), col, { Material = M.Glass, Transparency = 0.3 })
	end
	prompt(m, CFrame.new(porch + Vector3.new(0, 5, -4.5)), "UPGRADE LAB", "Upgrades")
end

-- Leaderboard frame (ExtrasServer fills Rows/Subtitle). `cf` faces its text side (+X) at the viewer.
local function leaderboard(parent, name, cf, title, color)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	for _, side in ipairs({ -1, 1 }) do
		column(m, 20, 1.8, (cf * CFrame.new(0, -17, side * 12.5)).Position, darker(color, 0.25))
	end
	part(m, { Size = Vector3.new(1.4, 32, 27), CFrame = cf * CFrame.new(-0.2, 3, 0), Color = darker(color, 0.25) })
	local board = part(m, { Name = "Board", Size = Vector3.new(1.2, 30, 25), CFrame = cf * CFrame.new(0.1, 3, 0), Color = color })
	part(m, { Size = Vector3.new(3, 3, 29), CFrame = cf * CFrame.new(0, 19.5, 0), Color = YELLOW })
	ball(m, 5, (cf * CFrame.new(0, 22.5, 0)).Position, YELLOW)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = color
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(lighter(color, 0.3), darker(color, 0.15))
	grad.Rotation = 90
	grad.Parent = bg
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.05, 0.02)
	t.Size = UDim2.fromScale(0.9, 0.11)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = WHITE
	t.Text = title
	t.Parent = bg
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Parent = t
	local sub = t:Clone()
	sub.Name = "Subtitle"
	sub.Position = UDim2.fromScale(0.1, 0.13)
	sub.Size = UDim2.fromScale(0.8, 0.05)
	sub.Text = "Loading..."
	sub.Parent = bg
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0.05, 0.2)
	rows.Size = UDim2.fromScale(0.9, 0.77)
	rows.Parent = bg
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0.006, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rows
end

-- Launch area: pad + tower ----------------------------------------------------------------------
local function launchArea(hub, rng)
	local HALF = Config.PATH_HALF_WIDTH
	cyl(hub, 1.2, 24, CFrame.new(PAD_X, 0.9, 0) * UP, C(150, 155, 170), { Name = "LaunchPad" })
	cyl(hub, 1.3, 14, CFrame.new(PAD_X, 0.95, 0) * UP, ORANGE, { Name = "PadCenter" })
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		part(hub, { Size = Vector3.new(4, 1.4, 1.4), CFrame = CFrame.new(PAD_X, 1, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 11.4), Color = i % 2 == 0 and YELLOW or C(40, 40, 45) })
	end
	part(hub, { Name = "StartLine", Size = Vector3.new(2, 0.3, HALF * 2 + 10), CFrame = CFrame.new(Config.LAUNCH_X + 4, 0.45, 0), Color = WHITE })

	-- launch tower (red/white truss) with a gantry arm and a blinking beacon
	local towerC = Vector3.new(PAD_X, 0, -17)
	local TH = 48
	for _, dx in ipairs({ -3, 3 }) do
		for _, dz in ipairs({ -3, 3 }) do
			part(hub, { Size = Vector3.new(1.2, TH, 1.2), CFrame = CFrame.new(towerC + Vector3.new(dx, TH / 2, dz)), Color = C(230, 60, 60), Material = M.Metal })
		end
	end
	for y = 4, TH, 6 do
		local col = (y / 6) % 2 < 1 and WHITE or C(230, 60, 60)
		for _, o in ipairs({ { 0, -3, 7.2, 0.8 }, { 0, 3, 7.2, 0.8 }, { -3, 0, 0.8, 7.2 }, { 3, 0, 0.8, 7.2 } }) do
			part(hub, { Size = Vector3.new(o[3], 0.8, o[4]), CFrame = CFrame.new(towerC + Vector3.new(o[1], y, o[2])), Color = col })
		end
	end
	part(hub, { Size = Vector3.new(9, 1, 9), CFrame = CFrame.new(towerC + Vector3.new(0, TH + 0.5, 0)), Color = WHITE })
	ball(hub, 3, towerC + Vector3.new(0, TH + 2.5, 0), C(255, 60, 60), {})
	part(hub, { Name = "Gantry", Size = Vector3.new(2, 1.4, 12), CFrame = CFrame.new(towerC + Vector3.new(0, 10, 8.5)), Color = WHITE })
end

-- A few trees: two blossoms framing spawn, four in the far corners ----------------------------
local function parkTrees(hub, rng)
	for _, z in ipairs({ -24, 24 }) do
		Lobby.tree(hub, Vector3.new(-132, 0.3, z), rng, 22, BLOSSOM)
	end
	for _, p in ipairs({ { -172, -68 }, { -172, 68 }, { -104, -72 }, { -104, 72 } }) do
		Lobby.tree(hub, Vector3.new(p[1], 0.3, p[2]), rng)
	end
end

function Lobby.build(hub)
	local rng = Random.new(2026)
	ground(hub, rng)
	spawnArea(hub, rng)
	statuePlaza(hub, rng)
	rocketShop(hub)
	upgradeLab(hub)
	launchArea(hub, rng)
	parkTrees(hub, rng)
	-- leaderboards beside the spawn plaza, angled toward the player
	local target = Vector3.new(-160, 17, 0)
	for _, info in ipairs({ { "RichestBoard", -34, "RICHEST", C(60, 190, 90) }, { "DonorBoard", 34, "TOP DONATORS", PINK } }) do
		local pos = Vector3.new(-140, 17, info[2] * 1.15)
		local cf = CFrame.lookAt(pos, target) * CFrame.Angles(0, math.pi / 2, 0)
		leaderboard(hub, info[1], cf, info[3], info[4])
	end
end

return Lobby
