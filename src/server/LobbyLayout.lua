-- Where things are in the lobby, shared by Lobby (builds it) and TerrainBuilder (keeps grass
-- blades off paved areas). Circles: { x, z, radius }. Boxes: { x0, z0, x1, z1 }.
local LobbyLayout = {}

LobbyLayout.SPAWN = Vector3.new(-150, 0, 0)

-- The two shops face the main path from either side.
LobbyLayout.ROCKET_SHOP = { pos = Vector3.new(-95, 0, -46), facing = Vector3.new(0, 0, 1) }
LobbyLayout.UPGRADE_LAB = { pos = Vector3.new(-95, 0, 46), facing = Vector3.new(0, 0, -1) }

-- Egg Garden: a round plaza beside the spawn with one stand per egg in an arc around its back.
LobbyLayout.EGG_GARDEN = { center = Vector3.new(-150, 0, 50), radius = 21, standRadius = 16 }

-- Where egg stand i (of n) stands, and the way its front faces (toward the garden's center).
function LobbyLayout.eggStand(i, n)
	local g = LobbyLayout.EGG_GARDEN
	local a = math.rad(-10 + (i - 1) * (200 / math.max(1, n - 1))) -- wide arc, open toward the spawn
	local pos = g.center + Vector3.new(math.cos(a), 0, math.sin(a)) * g.standRadius
	return pos, (g.center - pos).Unit
end

-- Park area (flat lawn).
LobbyLayout.PARK = { -186, -86, 6, 86 }

LobbyLayout.PAVED_CIRCLES = {
	{ -150, 0, 17 }, -- spawn plaza
	{ -8, 0, 24 }, -- launch pad
	{ -150, 50, 21 }, -- Egg Garden
}

LobbyLayout.PAVED_BOXES = {
	{ -136, -8.2, -29, 8.2 }, -- main path: spawn -> launch pad
	{ -102.2, -34, -87.8, -7 }, -- path to the Rocket Shop
	{ -114, -35, -76, -25 }, -- Rocket Shop porch
	{ -102.2, 7, -87.8, 27 }, -- path to the Upgrade shop
	{ -156.2, 15, -143.8, 31 }, -- path to the Egg Garden
}

-- Building footprints (decor stays out of these).
LobbyLayout.BUILDINGS = {
	{ -114, -66, -76, -26 }, -- Rocket Shop
	{ -119, 25, -71, 67 }, -- Upgrade shop
}

function LobbyLayout.inPark(x, z)
	local b = LobbyLayout.PARK
	return x >= b[1] and x <= b[3] and z >= b[2] and z <= b[4]
end

function LobbyLayout.isPaved(x, z, margin)
	margin = margin or 0
	for _, c in ipairs(LobbyLayout.PAVED_CIRCLES) do
		if (x - c[1]) ^ 2 + (z - c[2]) ^ 2 <= (c[3] + margin) ^ 2 then
			return true
		end
	end
	for _, b in ipairs(LobbyLayout.PAVED_BOXES) do
		if x >= b[1] - margin and x <= b[3] + margin and z >= b[2] - margin and z <= b[4] + margin then
			return true
		end
	end
	return false
end

-- True where decoration must not go: paths, pads, buildings (plus a margin).
function LobbyLayout.isBlocked(x, z, margin)
	if LobbyLayout.isPaved(x, z, margin) then
		return true
	end
	margin = margin or 0
	for _, b in ipairs(LobbyLayout.BUILDINGS) do
		if x >= b[1] - margin and x <= b[3] + margin and z >= b[2] - margin and z <= b[4] + margin then
			return true
		end
	end
	return false
end

return LobbyLayout
