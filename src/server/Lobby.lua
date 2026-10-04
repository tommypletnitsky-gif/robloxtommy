-- The starting area, kept deliberately empty: one flat lawn, a path from the spawn pad to the
-- launcher, the two shops beside it and the launcher itself. Nothing else.
--   lawn #77dd77, paving #c4d0d9, signs #358bcc: flat SmoothPlastic so the colors show as picked.
--   Shops: Creator Store models in ServerStorage.ShopModels (scripts stripped, see their Source
--   attribute). Launcher: generated model in ServerStorage.LauncherModel; RocketClient animates it.
-- Nothing in the lobby glows or emits light.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(ServerScriptService.BuildKit)
local Foliage = require(ServerScriptService.Foliage)
local LobbyLayout = require(ServerScriptService.LobbyLayout)

local part, cyl, sign = Kit.part, Kit.cyl, Kit.sign
local darker = Kit.darker
local UP = Kit.UP
local C = Color3.fromRGB

local Lobby = {}

local WHITE = C(255, 255, 255)
local SIGN = C(53, 139, 204) -- #358bcc, every sign in the lobby
local LAWN = C(119, 221, 119) -- #77dd77, the lobby grass
local PAVE = C(196, 208, 217) -- #c4d0d9, every path / pad in the lobby

local SPAWN = LobbyLayout.SPAWN
local PAD_X = Config.LAUNCH_X - 8
local LAWN_TOP = 0.08 -- just above the flat terrain under it
local PAVE_TOP = 0.14 -- just above the lawn, below the runway (0.2)

-- Trees + bushes (used by the path scenery).
function Lobby.tree(parent, pos, rng, height, palette)
	Foliage.tree(parent, pos, rng, height, palette or "park")
end

function Lobby.bush(parent, pos, rng, size, palette)
	Foliage.bush(parent, pos, rng, size, palette or "park")
end

local function flat(parent, props)
	props.Material = Enum.Material.SmoothPlastic
	props.CastShadow = false
	return part(parent, props)
end

-- Ground: lawn, spawn pad, paths, launch apron (all flat parts, exact colors) ------------------
local function ground(hub)
	local x0, x1, z = LobbyLayout.PARK[1] - 1, Config.LAUNCH_X, LobbyLayout.PARK[4] + 2
	flat(hub, { Name = "Lawn", Size = Vector3.new(x1 - x0, 2, z * 2), CFrame = CFrame.new((x0 + x1) / 2, LAWN_TOP - 1, 0), Color = LAWN })

	for _, c in ipairs(LobbyLayout.PAVED_CIRCLES) do
		flat(hub, { Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, c[3] * 2, c[3] * 2), CFrame = CFrame.new(c[1], PAVE_TOP - 0.2, c[2]) * UP, Color = PAVE })
	end
	for _, b in ipairs(LobbyLayout.PAVED_BOXES) do
		flat(hub, { Name = "Path", Size = Vector3.new(b[3] - b[1], 0.4, b[4] - b[2]), CFrame = CFrame.new((b[1] + b[3]) / 2, PAVE_TOP - 0.2, (b[2] + b[4]) / 2), Color = PAVE })
	end
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

function Lobby.build(hub)
	ground(hub)
	spawnArea(hub)
	for _, info in ipairs(SHOPS) do
		placeShop(hub, info)
	end
	launchArea(hub)
end

return Lobby
