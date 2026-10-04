--!strict
--[[
	WorldBuild.lua  —  RUN-ONCE idempotent world construction script (Pet Fusion Simulator v2)
	Implementer: WorldBuilder. Sections C + D of the unified contract.

	WHAT THIS DOES (and ONLY this — NO gameplay logic):
	  1. Ensures ReplicatedStorage.Remotes exists with EXACT children from Section C.
	  2. Ensures ReplicatedStorage.PetData / ReplicatedStorage.FXData placeholders exist (left to DataAuthor if absent).
	  3. Destroys any prior generated workspace.World folder, then rebuilds:
	       Spawn, Zones/ (5 zones each with Ground, TravelPad+prompt, Arrival, OrbField/24 orbs,
	       Pedestals/ per egg, Billboard_NextZone), Hub/ (CoinCrystal, FusionMachine, RebirthStatue,
	       DailyChest, PlaytimePillar, QuestBoard, IndexKiosk, ShopKiosk), PetFollowers/.
	  4. Pure geometry + named instances + attributes + ProximityPrompts/ClickDetectors/BillboardGuis.
	     No scripts, no remote handlers, no coin logic — ServerDev/ClientDev wire behavior to these names.

	Run once via execute_luau (Edit datamodel). Re-running is safe (clears workspace.World first
	and reuses/repairs the Remotes folder).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")

--==================================================================================================
-- CONTRACT DATA (mirrored locally so this build script has NO dependency on PetData load order).
-- These names/numbers are copied verbatim from Section B6 (Zones) and B5 (Eggs) of the contract.
--==================================================================================================

-- Section B6 — Zones {name, gate, clickBase, orbValue, eggs}
local ZONES = {
	[1] = {name = "Meadow",    gate = {coins = 0,          rebirths = 0}, clickBase = 1,    orbValue = 5,     eggs = {"basic", "meadow_deluxe"}},
	[2] = {name = "Forest",    gate = {coins = 5000,       rebirths = 0}, clickBase = 8,    orbValue = 40,    eggs = {"forest", "forest_deluxe"}},
	[3] = {name = "Frostpeak", gate = {coins = 250000,     rebirths = 0}, clickBase = 60,   orbValue = 300,   eggs = {"frost", "frost_deluxe"}},
	[4] = {name = "Volcano",   gate = {coins = 10000000,   rebirths = 1}, clickBase = 500,  orbValue = 2500,  eggs = {"ember", "ember_deluxe"}},
	[5] = {name = "Skyhaven",  gate = {coins = 2000000000, rebirths = 5}, clickBase = 5000, orbValue = 30000, eggs = {"celestial", "celestial_deluxe"}},
}

-- Section B5 — Eggs (only the fields the world needs: cost + pool, for pedestal billboards/attributes)
local EGGS = {
	basic            = {cost = 50,          pool = "Meadow"},
	meadow_deluxe    = {cost = 2500,        pool = "Meadow"},
	forest           = {cost = 1500,        pool = "Forest"},
	forest_deluxe    = {cost = 60000,       pool = "Forest"},
	frost            = {cost = 40000,       pool = "Frost"},
	frost_deluxe     = {cost = 1500000,     pool = "Frost"},
	ember            = {cost = 5000000,     pool = "Volcano"},
	ember_deluxe     = {cost = 120000000,   pool = "Volcano"},
	celestial        = {cost = 750000000,   pool = "Sky"},
	celestial_deluxe = {cost = 25000000000, pool = "Sky"},
}

-- Section C — Remotes. {name, className}. className is RemoteEvent or RemoteFunction.
local REMOTES = {
	-- client -> server (RemoteEvent)
	{"ClickCoin",        "RemoteEvent"},
	{"HatchRequest",     "RemoteEvent"},
	{"EquipPet",         "RemoteEvent"},
	{"UnequipPet",       "RemoteEvent"},
	{"FuseRequest",      "RemoteEvent"},
	{"FuseAll",          "RemoteEvent"},
	{"SellPets",         "RemoteEvent"},
	{"SellBulk",         "RemoteEvent"},
	{"LockPet",          "RemoteEvent"},
	{"RebirthRequest",   "RemoteEvent"},
	{"TravelTo",         "RemoteEvent"},
	{"ClaimDaily",       "RemoteEvent"},
	{"ClaimQuest",       "RemoteEvent"},
	{"ClaimPlaytime",    "RemoteEvent"},
	{"ClaimIndexTier",   "RemoteEvent"},
	{"UseBoostItem",     "RemoteEvent"},
	{"SetSetting",       "RemoteEvent"},
	{"SetTutorialStep",  "RemoteEvent"},
	-- server -> client (RemoteEvent)
	{"StateSync",        "RemoteEvent"},
	{"HatchResult",      "RemoteEvent"},
	{"Notify",           "RemoteEvent"},
	{"BoostUpdate",      "RemoteEvent"},
	{"BigHatch",         "RemoteEvent"},
	{"FXEvent",          "RemoteEvent"},
	-- request/response (RemoteFunction)
	{"GetDropTable",     "RemoteFunction"},
}

--==================================================================================================
-- LAYOUT CONSTANTS
--==================================================================================================
local ZONE_SPACING   = 320          -- studs between zone centers along +X
local GROUND_SIZE    = Vector3.new(240, 4, 240)
local GROUND_Y       = 0            -- top of ground at y = GROUND_Y + size.Y/2
local SPAWN_Y_OFFSET = 3            -- HRP rest height above ground top

-- Per-zone visual tint (decor only; ZoneColor attribute carries the contract tint).
local ZONE_TINT = {
	[1] = Color3.fromRGB(120, 200, 110),   -- Meadow green
	[2] = Color3.fromRGB(46, 120, 60),     -- Forest deep green
	[3] = Color3.fromRGB(180, 220, 245),   -- Frostpeak icy
	[4] = Color3.fromRGB(70, 35, 30),      -- Volcano dark
	[5] = Color3.fromRGB(190, 205, 255),   -- Skyhaven pale
}
local ZONE_MATERIAL = {
	[1] = Enum.Material.Grass,
	[2] = Enum.Material.LeafyGrass,
	[3] = Enum.Material.Snow,
	[4] = Enum.Material.Basalt,
	[5] = Enum.Material.Sand,
}
local ZONE_ACCENT = {
	[1] = Color3.fromRGB(255, 235, 130),
	[2] = Color3.fromRGB(150, 255, 170),
	[3] = Color3.fromRGB(120, 200, 255),
	[4] = Color3.fromRGB(255, 120, 40),
	[5] = Color3.fromRGB(255, 255, 255),
}

local function zoneCenter(i: number): Vector3
	return Vector3.new((i - 1) * ZONE_SPACING, GROUND_Y, 0)
end

--==================================================================================================
-- SMALL BUILDER HELPERS
--==================================================================================================
local function newPart(props: {[string]: any}, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.NormalId.Top
	p.BottomSurface = Enum.NormalId.Bottom
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	if parent then p.Parent = parent end
	return p
end

local function makeFolder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function makeModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Number formatting for billboards (mirror of PetData.format short form; build-time only).
local function fmt(n: number): string
	local abs = math.abs(n)
	local suffixes = {"", "K", "M", "B", "T", "aa", "ab", "ac", "ad", "ae"}
	if abs < 1000 then
		return tostring(math.floor(n))
	end
	local tier = math.floor(math.log(abs, 1000))
	tier = math.clamp(tier, 1, #suffixes - 1)
	local scaled = n / (1000 ^ tier)
	local s = string.format("%.2f", scaled)
	s = (s:gsub("%.?0+$", ""))
	return s .. suffixes[tier + 1]
end

-- Billboard label helper. Returns the BillboardGui (with a child TextLabel "Text").
local function makeBillboard(adornee: BasePart, text: string, color: Color3, size: Vector2, studsOffset: number): BillboardGui
	local bg = Instance.new("BillboardGui")
	bg.Name = "BillboardGui"
	bg.Adornee = adornee
	bg.Size = UDim2.fromOffset(size.X, size.Y)
	bg.StudsOffset = Vector3.new(0, studsOffset, 0)
	bg.MaxDistance = 220
	bg.AlwaysOnTop = false
	bg.LightInfluence = 0

	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.25
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = text
	label.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = frame

	bg.Parent = adornee
	return bg
end

local function makePrompt(parent: BasePart, actionText: string, objectText: string, keyword: string): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = keyword
	pp.ActionText = actionText
	pp.ObjectText = objectText
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

local function makeClickDetector(parent: BasePart, distance: number): ClickDetector
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = distance
	cd.Parent = parent
	return cd
end

local function addPointLight(parent: BasePart, color: Color3, brightness: number, range: number)
	local pl = Instance.new("PointLight")
	pl.Color = color
	pl.Brightness = brightness
	pl.Range = range
	pl.Parent = parent
end

--==================================================================================================
-- STEP 1 — REMOTES (idempotent: create folder + any missing remote of the correct class)
--==================================================================================================
local function ensureRemotes()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		remotesFolder = f
	end
	for _, spec in ipairs(REMOTES) do
		local name, className = spec[1], spec[2]
		local existing = remotesFolder:FindFirstChild(name)
		if existing and not existing:IsA(className) then
			-- wrong class left by an earlier layout: replace it with the contract type
			existing:Destroy()
			existing = nil
		end
		if not existing then
			local r = Instance.new(className)
			r.Name = name
			r.Parent = remotesFolder
		end
	end
end

--==================================================================================================
-- STEP 2 — PetData / FXData placeholders (do NOT overwrite if DataAuthor already authored them)
--==================================================================================================
local function ensureModulePlaceholder(name: string, comment: string)
	if ReplicatedStorage:FindFirstChild(name) then
		return -- authored module exists; leave it alone
	end
	local m = Instance.new("ModuleScript")
	m.Name = name
	m.Source = "-- " .. comment .. "\n-- Placeholder created by WorldBuild; DataAuthor replaces this module.\nreturn {}\n"
	m.Parent = ReplicatedStorage
end

--==================================================================================================
-- STEP 3 — WORLD
--==================================================================================================

-- An orb part for an OrbField. Anchored, no collision (server uses Touched + debounce).
local function makeOrb(index: number, center: Vector3, accent: Color3, orbValue: number, zoneIndex: number, parent: Instance)
	-- ring distribution: 24 orbs in two rings around the zone center
	local ringCount = 12
	local ring = (index <= ringCount) and 0 or 1
	local idxInRing = (ring == 0) and index or (index - ringCount)
	local radius = (ring == 0) and 70 or 95
	local angle = (idxInRing / ringCount) * math.pi * 2 + (ring * 0.26)
	local pos = center + Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)

	local orb = newPart({
		Name = "Orb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Position = pos,
		CanCollide = false,
		CanTouch = true,
		Material = Enum.Material.Neon,
		Color = accent,
	}, parent)
	orb:SetAttribute("OrbValue", orbValue)
	orb:SetAttribute("Zone", zoneIndex)
	orb:SetAttribute("RespawnSeconds", 4)
	addPointLight(orb, accent, 2, 8)
	return orb
end

-- One egg pedestal model: base column + floating egg mesh + prompt + price billboard.
local function makeEggPedestal(eggId: string, center: Vector3, slot: number, zoneIndex: number, accent: Color3, parent: Instance)
	local egg = EGGS[eggId]
	if not egg then
		warn("[WorldBuild] Unknown eggId in zone build: " .. tostring(eggId))
		return
	end
	local model = makeModel("EggPedestal_" .. eggId, parent)
	model:SetAttribute("EggId", eggId)
	model:SetAttribute("Zone", zoneIndex)

	-- pedestals arranged along -Z edge of the zone, spaced by slot
	local offsetX = (slot - 1.5) * 26
	local base = center + Vector3.new(offsetX, GROUND_Y + GROUND_SIZE.Y / 2, -86)

	local column = newPart({
		Name = "Column",
		Size = Vector3.new(8, 6, 8),
		Position = base + Vector3.new(0, 3, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(225, 225, 235),
	}, model)
	-- Cylinder column via SpecialMesh (Enum.MeshType has no "Cylinder"; use the Cylinder PART shape instead).
	column.Shape = Enum.PartType.Cylinder
	-- Cylinder part's circular face is on the X axis; rotate so it stands upright on Y.
	column.Orientation = Vector3.new(0, 0, 90)

	local eggMesh = newPart({
		Name = "EggMesh",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 9, 7),
		Position = base + Vector3.new(0, 11, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = accent,
		CanCollide = false,
	}, model)
	addPointLight(eggMesh, accent, 1.5, 12)

	model.PrimaryPart = eggMesh

	makePrompt(eggMesh, "Hatch", eggId, "Hatch")
	makeBillboard(eggMesh, string.format("%s\n%s coins", eggId, fmt(egg.cost)), accent, Vector2.new(150, 60), 7)
end

local function buildTravelPad(zoneIndex: number, center: Vector3, accent: Color3, parent: Instance): Part
	-- TravelPad sends to NEXT zone (or wraps to previous at last zone for convenience).
	local targetIndex = (zoneIndex < #ZONES) and (zoneIndex + 1) or 1
	local target = ZONES[targetIndex]

	local pad = newPart({
		Name = "TravelPad",
		Size = Vector3.new(16, 1, 16),
		Position = center + Vector3.new(86, GROUND_Y + GROUND_SIZE.Y / 2 + 0.5, 0),
		Material = Enum.Material.Neon,
		Color = accent,
		CanCollide = false,
	}, parent)
	pad:SetAttribute("FromZone", zoneIndex)
	pad:SetAttribute("TargetZone", targetIndex)

	local prompt = makePrompt(pad, "Travel", "To " .. target.name, "Travel")
	prompt.MaxActivationDistance = 14

	makeBillboard(pad, "Travel -> " .. target.name, accent, Vector2.new(160, 44), 4)
	return pad
end

local function buildArrival(zoneIndex: number, center: Vector3, parent: Instance): Part
	local arrival = newPart({
		Name = "Arrival",
		Size = Vector3.new(12, 1, 12),
		Position = center + Vector3.new(-86, GROUND_Y + GROUND_SIZE.Y / 2 + 0.5, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.4,
		CanCollide = false,
	}, parent)
	arrival:SetAttribute("Zone", zoneIndex)
	return arrival
end

local function buildNextZoneBillboard(zoneIndex: number, center: Vector3, accent: Color3, parent: Instance)
	local nextIndex = (zoneIndex < #ZONES) and (zoneIndex + 1) or zoneIndex
	local nextZone = ZONES[nextIndex]
	local gateText
	if nextIndex == zoneIndex then
		gateText = "Final Zone"
	else
		gateText = string.format("Next: %s\n%s coins | %d rebirth", nextZone.name, fmt(nextZone.gate.coins), nextZone.gate.rebirths)
	end

	local post = newPart({
		Name = "Billboard_NextZone",
		Size = Vector3.new(2, 14, 2),
		Position = center + Vector3.new(0, GROUND_Y + GROUND_SIZE.Y / 2 + 7, 70),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 60, 70),
	}, parent)
	post:SetAttribute("Zone", zoneIndex)
	post:SetAttribute("NextZone", nextIndex)

	local bg = makeBillboard(post, gateText, accent, Vector2.new(220, 90), 9)
	-- progress bar that ClientDev fills (named "Progress" + "Fill")
	local card = bg:FindFirstChild("Card") :: Frame
	local bar = Instance.new("Frame")
	bar.Name = "Progress"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromScale(0.5, 0.97)
	bar.Size = UDim2.new(0.9, 0, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
	bar.BorderSizePixel = 0
	bar.Parent = card
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
end

local function buildDecor(zoneIndex: number, center: Vector3, tint: Color3, accent: Color3, parent: Instance)
	local decor = makeFolder("Decor", parent)
	-- corner pillars
	local groundTop = GROUND_Y + GROUND_SIZE.Y / 2
	local corners = {
		Vector3.new(-100, 0, -100), Vector3.new(100, 0, -100),
		Vector3.new(-100, 0, 100),  Vector3.new(100, 0, 100),
	}
	for i, c in ipairs(corners) do
		newPart({
			Name = "Pillar" .. i,
			Size = Vector3.new(6, 24, 6),
			Position = center + c + Vector3.new(0, groundTop + 12, 0),
			Material = Enum.Material.Slate,
			Color = tint,
		}, decor)
		local cap = newPart({
			Name = "PillarCap" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7, 7, 7),
			Position = center + c + Vector3.new(0, groundTop + 25, 0),
			Material = Enum.Material.Neon,
			Color = accent,
			CanCollide = false,
		}, decor)
		addPointLight(cap, accent, 2, 18)
	end
	-- biome-specific scatter props (anchored, cosmetic)
	if zoneIndex == 1 then
		for i = 1, 10 do
			newPart({
				Name = "Flower" .. i,
				Size = Vector3.new(1, 3, 1),
				Position = center + Vector3.new(math.random(-70, 70), groundTop + 1.5, math.random(-40, 60)),
				Material = Enum.Material.Grass,
				Color = ((i % 2 == 0) and Color3.fromRGB(255, 120, 160)) or Color3.fromRGB(255, 220, 90),
				CanCollide = false,
			}, decor)
		end
	elseif zoneIndex == 2 then
		for i = 1, 8 do
			local trunk = newPart({
				Name = "Tree" .. i,
				Size = Vector3.new(3, 16, 3),
				Position = center + Vector3.new(math.random(-80, 80), groundTop + 8, math.random(-30, 60)),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(95, 65, 40),
				CanCollide = false,
			}, decor)
			newPart({
				Name = "Leaves" .. i,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(14, 12, 14),
				Position = trunk.Position + Vector3.new(0, 11, 0),
				Material = Enum.Material.Grass,
				Color = Color3.fromRGB(40, 130, 55),
				CanCollide = false,
			}, decor)
		end
	elseif zoneIndex == 3 then
		for i = 1, 8 do
			newPart({
				Name = "IceSpike" .. i,
				Size = Vector3.new(4, math.random(10, 22), 4),
				Position = center + Vector3.new(math.random(-80, 80), groundTop + 8, math.random(-30, 60)),
				Material = Enum.Material.Glacier,
				Color = Color3.fromRGB(200, 235, 255),
				Transparency = 0.2,
				CanCollide = false,
			}, decor)
		end
	elseif zoneIndex == 4 then
		for i = 1, 8 do
			newPart({
				Name = "LavaRock" .. i,
				Size = Vector3.new(math.random(5, 10), math.random(4, 8), math.random(5, 10)),
				Position = center + Vector3.new(math.random(-80, 80), groundTop + 2, math.random(-30, 60)),
				Material = Enum.Material.CrackedLava,
				Color = Color3.fromRGB(120, 40, 20),
			}, decor)
		end
		-- glowing lava pool accent
		local lava = newPart({
			Name = "LavaPool",
			Size = Vector3.new(40, 1, 40),
			Position = center + Vector3.new(0, groundTop + 0.6, 30),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 90, 20),
			CanCollide = false,
		}, decor)
		addPointLight(lava, Color3.fromRGB(255, 110, 30), 3, 40)
	elseif zoneIndex == 5 then
		for i = 1, 8 do
			newPart({
				Name = "Cloud" .. i,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(math.random(12, 22), 8, math.random(12, 22)),
				Position = center + Vector3.new(math.random(-80, 80), groundTop + math.random(14, 28), math.random(-30, 60)),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(245, 248, 255),
				Transparency = 0.35,
				CanCollide = false,
			}, decor)
		end
	end
end

local function buildZone(zoneIndex: number, zonesFolder: Folder)
	local z = ZONES[zoneIndex]
	local center = zoneCenter(zoneIndex)
	local tint = ZONE_TINT[zoneIndex]
	local accent = ZONE_ACCENT[zoneIndex]

	local folderName = string.format("Zone%d_%s", zoneIndex, z.name)
	local zoneFolder = makeFolder(folderName, zonesFolder)
	zoneFolder:SetAttribute("ZoneIndex", zoneIndex)
	zoneFolder:SetAttribute("ZoneName", z.name)
	zoneFolder:SetAttribute("GateCoins", z.gate.coins)
	zoneFolder:SetAttribute("GateRebirths", z.gate.rebirths)
	zoneFolder:SetAttribute("ClickBase", z.clickBase)
	zoneFolder:SetAttribute("OrbValue", z.orbValue)

	-- Ground
	local ground = newPart({
		Name = "Ground",
		Size = GROUND_SIZE,
		Position = center + Vector3.new(0, GROUND_Y, 0),
		Material = ZONE_MATERIAL[zoneIndex],
		Color = tint,
	}, zoneFolder)
	ground:SetAttribute("Zone", zoneIndex)
	ground:SetAttribute("ZoneColor", tint)

	-- Arrival + TravelPad + Next-zone billboard
	buildArrival(zoneIndex, center, zoneFolder)
	buildTravelPad(zoneIndex, center, accent, zoneFolder)
	buildNextZoneBillboard(zoneIndex, center, accent, zoneFolder)

	-- OrbField (24 orbs)
	local orbField = makeFolder("OrbField", zoneFolder)
	for i = 1, 24 do
		makeOrb(i, center, accent, z.orbValue, zoneIndex, orbField)
	end

	-- Pedestals (one per egg in this zone)
	local pedestals = makeFolder("Pedestals", zoneFolder)
	for slot, eggId in ipairs(z.eggs) do
		makeEggPedestal(eggId, center, slot, zoneIndex, accent, pedestals)
	end

	-- Decor
	buildDecor(zoneIndex, center, tint, accent, zoneFolder)
end

-- Hub interactables (placed in Zone 1 plaza, near center).
local function buildHub(worldFolder: Folder)
	local hub = makeFolder("Hub", worldFolder)
	local center = zoneCenter(1)
	local groundTop = GROUND_Y + GROUND_SIZE.Y / 2

	-- Plaza floor accent under the hub
	local plaza = newPart({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 60, 60),
		Position = center + Vector3.new(0, groundTop + 0.6, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(235, 230, 245),
		CanCollide = false,
	}, hub)
	plaza.Orientation = Vector3.new(0, 0, 90)

	-- CoinCrystal (Model with ClickDetector + named Part "Crystal")
	local crystalModel = makeModel("CoinCrystal", hub)
	local crystal = newPart({
		Name = "Crystal",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8, 12, 8),
		Position = center + Vector3.new(0, groundTop + 8, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 215, 70),
		CanCollide = false,
	}, crystalModel)
	crystalModel.PrimaryPart = crystal
	makeClickDetector(crystal, 32)
	addPointLight(crystal, Color3.fromRGB(255, 220, 90), 3, 24)
	makeBillboard(crystal, "Tap for Coins!", Color3.fromRGB(255, 215, 70), Vector2.new(150, 44), 9)

	-- FusionMachine (Model, named Part "MachineCore")
	local fusionModel = makeModel("FusionMachine", hub)
	local fusionBase = newPart({
		Name = "Base",
		Size = Vector3.new(14, 4, 14),
		Position = center + Vector3.new(-30, groundTop + 2, -20),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(70, 75, 90),
	}, fusionModel)
	local core = newPart({
		Name = "MachineCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		Position = fusionBase.Position + Vector3.new(0, 8, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(176, 92, 255),
		CanCollide = false,
	}, fusionModel)
	fusionModel.PrimaryPart = core
	addPointLight(core, Color3.fromRGB(176, 92, 255), 3, 22)
	makeBillboard(core, "Fusion Machine", Color3.fromRGB(176, 92, 255), Vector2.new(160, 44), 7)

	-- RebirthStatue (Model with ClickDetector + BillboardGui rebirth count)
	local rebirthModel = makeModel("RebirthStatue", hub)
	local rbBase = newPart({
		Name = "Base",
		Size = Vector3.new(10, 4, 10),
		Position = center + Vector3.new(30, groundTop + 2, -20),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(230, 225, 240),
	}, rebirthModel)
	local rbFigure = newPart({
		Name = "Figure",
		Size = Vector3.new(5, 12, 3),
		Position = rbBase.Position + Vector3.new(0, 8, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(255, 235, 150),
	}, rebirthModel)
	rebirthModel.PrimaryPart = rbFigure
	makeClickDetector(rbFigure, 24)
	addPointLight(rbFigure, Color3.fromRGB(255, 230, 120), 2, 18)
	makeBillboard(rbFigure, "Rebirths: 0", Color3.fromRGB(255, 215, 70), Vector2.new(150, 44), 9)

	-- Kiosk-style ClickDetector interactables, arranged in an arc behind the crystal.
	local function buildKiosk(name: string, offset: Vector3, color: Color3, label: string)
		local model = makeModel(name, hub)
		local body = newPart({
			Name = "Body",
			Size = Vector3.new(8, 10, 4),
			Position = center + offset + Vector3.new(0, groundTop + 5, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = color,
		}, model)
		model.PrimaryPart = body
		makeClickDetector(body, 24)
		makeBillboard(body, label, color, Vector2.new(150, 44), 7)
		addPointLight(body, color, 1.5, 14)
		return model
	end

	buildKiosk("DailyChest",     Vector3.new(-60, 0, 25),  Color3.fromRGB(255, 180, 60),  "Daily Reward")
	buildKiosk("PlaytimePillar", Vector3.new(-40, 0, 35),  Color3.fromRGB(120, 220, 255), "Playtime")
	buildKiosk("QuestBoard",     Vector3.new(-20, 0, 42),  Color3.fromRGB(150, 255, 150),  "Quests")
	buildKiosk("IndexKiosk",     Vector3.new(20, 0, 42),   Color3.fromRGB(180, 120, 255),  "Pet Index")
	buildKiosk("ShopKiosk",      Vector3.new(40, 0, 35),   Color3.fromRGB(255, 120, 200),  "Shop")
end

local function buildWorld()
	-- idempotent: wipe prior generated world
	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end

	local world = makeFolder("World", Workspace)

	-- Spawn (in Zone 1, on its Arrival side / plaza)
	local center1 = zoneCenter(1)
	local groundTop = GROUND_Y + GROUND_SIZE.Y / 2
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = center1 + Vector3.new(0, groundTop + SPAWN_Y_OFFSET, 40)
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(120, 200, 110)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = world

	-- Zones
	local zonesFolder = makeFolder("Zones", world)
	for i = 1, #ZONES do
		buildZone(i, zonesFolder)
	end

	-- Hub (interactables in Zone 1 plaza)
	buildHub(world)

	-- PetFollowers runtime container (empty; client/server populate at runtime)
	makeFolder("PetFollowers", world)

	return world
end

--==================================================================================================
-- LIGHTING (ambient pass — cosmetic, world-wide; safe to set on rebuild)
--==================================================================================================
local function applyLighting()
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(120, 120, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 30

	-- Ensure an Atmosphere for soft depth (replace prior generated one)
	local oldAtmo = Lighting:FindFirstChild("WorldAtmosphere")
	if oldAtmo then oldAtmo:Destroy() end
	local atmo = Instance.new("Atmosphere")
	atmo.Name = "WorldAtmosphere"
	atmo.Density = 0.32
	atmo.Offset = 0.25
	atmo.Color = Color3.fromRGB(199, 209, 224)
	atmo.Decay = Color3.fromRGB(106, 112, 125)
	atmo.Glare = 0.2
	atmo.Haze = 1.4
	atmo.Parent = Lighting

	local oldSky = Lighting:FindFirstChild("WorldSky")
	if oldSky then oldSky:Destroy() end
	local sky = Instance.new("Sky")
	sky.Name = "WorldSky"
	sky.Parent = Lighting
end

--==================================================================================================
-- RUN
--==================================================================================================
ensureRemotes()
ensureModulePlaceholder("PetData", "ReplicatedStorage.PetData (Section B)")
ensureModulePlaceholder("FXData",  "ReplicatedStorage.FXData (Section J1)")
local builtWorld = buildWorld()
applyLighting()

print("[WorldBuild] Complete.")
print("  - Remotes ensured under ReplicatedStorage.Remotes (" .. tostring(#REMOTES) .. " contract remotes).")
print("  - workspace.World rebuilt: " .. tostring(#ZONES) .. " zones, hub, spawn, PetFollowers.")
print("  - World children: " .. table.concat((function()
	local names = {}
	for _, c in ipairs(builtWorld:GetChildren()) do table.insert(names, c.Name) end
	return names
end)(), ", "))

return builtWorld