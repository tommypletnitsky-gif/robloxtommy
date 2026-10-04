-- Where things are in the lobby, shared by Lobby (builds it) and TerrainBuilder (keeps grass
-- blades off paved areas). Circles: { x, z, radius }. Boxes: { x0, z0, x1, z1 }.
local LobbyLayout = {}

LobbyLayout.SPAWN = Vector3.new(-150, 0, 0)

-- The two shops face the main path from either side.
LobbyLayout.ROCKET_SHOP = { pos = Vector3.new(-95, 0, -46), facing = Vector3.new(0, 0, 1) }
LobbyLayout.UPGRADE_LAB = { pos = Vector3.new(-95, 0, 46), facing = Vector3.new(0, 0, -1) }

-- Park area (flat lawn). Inside it the ground is one flat #77dd77 part.
LobbyLayout.PARK = { -186, -86, 6, 86 }

LobbyLayout.PAVED_CIRCLES = {
	{ -150, 0, 12 }, -- spawn pad
	{ -8, 0, 22 }, -- launch apron
}

LobbyLayout.PAVED_BOXES = {
	{ -150, -7, -26, 7 }, -- main path: spawn -> launcher
	{ -101, -28, -89, -7 }, -- path to the Rocket Shop
	{ -101, 7, -89, 27 }, -- path to the Upgrade Lab
}

function LobbyLayout.inPark(x, z)
	local b = LobbyLayout.PARK
	return x >= b[1] and x <= b[3] and z >= b[2] and z <= b[4]
end

function LobbyLayout.isPaved(x, z)
	for _, c in ipairs(LobbyLayout.PAVED_CIRCLES) do
		if (x - c[1]) ^ 2 + (z - c[2]) ^ 2 <= c[3] ^ 2 then
			return true
		end
	end
	for _, b in ipairs(LobbyLayout.PAVED_BOXES) do
		if x >= b[1] and x <= b[3] and z >= b[2] and z <= b[4] then
			return true
		end
	end
	return false
end

return LobbyLayout
