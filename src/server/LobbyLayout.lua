-- Where things are in the lobby, shared by Lobby (builds it) and TerrainBuilder (keeps grass
-- blades off paved areas). Circles: { x, z, radius }. Boxes: { x0, z0, x1, z1 }.
local LobbyLayout = {}

LobbyLayout.SPAWN = Vector3.new(-150, 0, 0)

-- The two shops face the main path from either side.
LobbyLayout.ROCKET_SHOP = { pos = Vector3.new(-95, 0, -46), facing = Vector3.new(0, 0, 1) }
LobbyLayout.UPGRADE_LAB = { pos = Vector3.new(-95, 0, 46), facing = Vector3.new(0, 0, -1) }

-- The Hatchery: the meadow behind the spawn (-X). A walk runs west from the spawn plaza through
-- three areas (Earth eggs 1-5, Sky 6-10, Space 11-15); the eggs stand on dioramas on both sides,
-- alternating left and right, facing the walk.
LobbyLayout.HATCHERY = {
	x0 = -167, x1 = -405, -- the walk (spawn plaza edge -> far end)
	half = 6, -- walk half width
	firstX = -192, step = 14.5, -- egg i stands at x = firstX - (i - 1) * step
	side = 20, -- ... and z = +/-side
	zones = { -- arches over the walk where each area starts
		{ x = -180, name = "EARTH EGGS", color = Color3.fromRGB(110, 200, 90) },
		{ x = -253, name = "SKY EGGS", color = Color3.fromRGB(110, 190, 255) },
		{ x = -325.5, name = "SPACE EGGS", color = Color3.fromRGB(170, 100, 255) },
	},
	flat = { -420, -150, -96, 96 }, -- x0, x1, z0, z1 of the flattened ground
}

-- Where egg stand i stands, and the way its front faces (toward the walk).
function LobbyLayout.eggStand(i)
	local h = LobbyLayout.HATCHERY
	local z = (i % 2 == 1) and h.side or -h.side
	local pos = Vector3.new(h.firstX - (i - 1) * h.step, 0, z)
	return pos, Vector3.new(0, 0, -math.sign(z))
end

-- True inside the Hatchery's flat ground.
function LobbyLayout.inHatchery(x, z)
	local f = LobbyLayout.HATCHERY.flat
	return x >= f[1] and x <= f[2] and z >= f[3] and z <= f[4]
end

-- Rebirth Portal: a round plaza on the other side of the spawn, the portal at its back.
LobbyLayout.REBIRTH = { center = Vector3.new(-150, 0, -48), radius = 15, portal = Vector3.new(-150, 0, -57) }

-- Park area (flat lawn).
LobbyLayout.PARK = { -186, -86, 6, 86 }

LobbyLayout.PAVED_CIRCLES = {
	{ -150, 0, 17 }, -- spawn plaza
	{ -8, 0, 24 }, -- launch pad
	{ -150, -48, 15 }, -- Rebirth Portal plaza
}

LobbyLayout.PAVED_BOXES = {
	{ -136, -8.2, -29, 8.2 }, -- main path: spawn -> launch pad
	{ -102.2, -34, -87.8, -7 }, -- path to the Rocket Shop
	{ -114, -35, -76, -25 }, -- Rocket Shop porch
	{ -102.2, 7, -87.8, 27 }, -- path to the Upgrade shop
	{ -405, -6, -165, 6 }, -- the Hatchery walk
	{ -156.2, -35, -143.8, -15 }, -- path to the Rebirth Portal
}

-- Building footprints (decor stays out of these).
LobbyLayout.BUILDINGS = {
	{ -114, -66, -76, -26 }, -- Rocket Shop
	{ -119, 25, -71, 67 }, -- Upgrade shop
	{ -74, -26, -54, -20 }, -- leaderboard
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
