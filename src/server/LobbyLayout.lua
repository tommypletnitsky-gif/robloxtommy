-- Where things are in the lobby, shared by Lobby (builds it) and TerrainBuilder (keeps grass
-- blades off paved areas). Circles: { x, z, radius }. Boxes: { x0, z0, x1, z1 }.
local LobbyLayout = {}

LobbyLayout.SPAWN = Vector3.new(-150, 0, 0)
LobbyLayout.PLAZA = Vector3.new(-80, 0, 0)

-- Park area (fenced). Inside it the ground is flat grass.
LobbyLayout.PARK = { -186, -86, 6, 86 }

LobbyLayout.PAVED_CIRCLES = {
	{ -150, 0, 23 }, -- spawn plaza
	{ -80, 0, 29 }, -- central plaza
	{ -80, 56, 17.5 }, -- Upgrade Lab dome
}

LobbyLayout.PAVED_BOXES = {
	{ -132, -10, -103, 10 }, -- avenue: spawn -> plaza
	{ -57, -10, -37, 10 }, -- avenue: plaza -> launch apron
	{ -87, -42, -73, 42 }, -- side paths to the buildings
	{ -99, -68, -61, -40 }, -- Rocket Shop floor
	{ -88, 34, -72, 44 }, -- Upgrade Lab porch
	{ -41, -33, 8, 33 }, -- launch apron + pad
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
