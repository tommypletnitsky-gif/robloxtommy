-- Real Roblox terrain for the lobby + Earth stages (1-10): a flat corridor for the runway,
-- rolling hills, mountain ranges with snow caps, a river, swamp pools, dunes, mesas, volcanoes,
-- and a coastline where the path lifts off into the Sky zone.
-- TerrainBuilder.height(x, z) is shared with WorldBuilder so scenery sits on the ground.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local LobbyLayout = require(game:GetService("ServerScriptService").LobbyLayout)

local TerrainBuilder = {}

local M = Enum.Material
local L = Config.STAGE_LENGTH
local RES = 4
local Y_MIN = -24
-- Smooth terrain draws its surface about 2 studs above where the solid voxels end,
-- so we write everything 2 studs lower to land surfaces at the intended height.
local SURFACE_OFFSET = 2

TerrainBuilder.X_MIN, TerrainBuilder.X_MAX = -440, 5640
TerrainBuilder.Z_MAX = 440
TerrainBuilder.WATER_LEVEL = -1.2

-- Landscape per stage (index 0 = lobby). hills/mountains are heights in studs.
local LAND = {
	[0] = { mat = M.Ground, hills = 8, mountains = 70 }, -- lobby: flat turf, no grass blades (FPS)
	{ mat = M.Grass, hills = 10, mountains = 80, river = true }, -- Grassy Meadow
	{ mat = M.LeafyGrass, hills = 6, mountains = 55, river = true }, -- Sunny Farm
	{ mat = M.Sand, hills = 9, mountains = 45, dunes = true }, -- Dusty Desert
	{ mat = M.Sandstone, hills = 8, mountains = 95, terrace = true }, -- Red Canyon
	{ mat = M.Grass, hills = 16, mountains = 120, river = true }, -- Deep Jungle
	{ mat = M.Mud, hills = 5, mountains = 55, swamp = true }, -- Misty Swamp
	{ mat = M.Snow, hills = 12, mountains = 120 }, -- Snowy Tundra
	{ mat = M.Glacier, hills = 12, mountains = 150 }, -- Icy Peaks
	{ mat = M.Basalt, hills = 8, mountains = 110, volcano = true }, -- Volcano
	{ mat = M.Grass, hills = 14, mountains = 170, alpine = true }, -- Mountain Top
}
TerrainBuilder.LAND = LAND

local function smoothstep(a, b, v)
	local t = math.clamp((v - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
TerrainBuilder.smoothstep = smoothstep

local function stageIndex(x)
	if x < Config.LAUNCH_X then
		return 0
	end
	return math.min(10, math.floor((x - Config.LAUNCH_X) / L) + 1)
end
TerrainBuilder.stageIndex = stageIndex

-- hills/mountain amounts blend smoothly across stage borders
local function blended(x, key)
	local s = stageIndex(x)
	local within = (x - Config.LAUNCH_X) - (s - 1) * L
	local v = LAND[s][key]
	if s >= 1 and within < 60 then
		local prev = LAND[s - 1][key]
		v = prev + (v - prev) * smoothstep(-60, 60, within)
	elseif s >= 0 and s < 10 and within > L - 60 then
		local nextV = LAND[s + 1][key]
		v = v + (nextV - v) * smoothstep(L - 60, L + 60, within) * 0.5
	end
	return v
end

local VOLCANOES = {} -- {x, z, r} cones in the Volcano stage
do
	local x0 = Config.LAUNCH_X + 8 * L
	VOLCANOES = { { x0 + 140, 230, 150 }, { x0 + 380, -250, 170 }, { x0 + 260, 330, 110 } }
end
TerrainBuilder.VOLCANOES = VOLCANOES

local plazaMinX, plazaMaxX = Config.HUB_CENTER.X - 92, Config.HUB_CENTER.X + 92

-- Paved spots in the lobby park: the terrain sits a little lower there and has no grass blades.
local function underPaving(x, z)
	return (LobbyLayout.inPark(x, z) or LobbyLayout.inHatchery(x, z)) and LobbyLayout.isPaved(x, z)
end

-- Height of the ground (top surface) at (x, z), and whether water fills above it.
function TerrainBuilder.height(x, z)
	local d = math.abs(z)
	local s = stageIndex(x)
	local land = LAND[s]

	-- flat runway corridor (and the start area / lobby plaza)
	local flat = 1 - smoothstep(46, 74, d)
	if x < 30 and x > plazaMinX - 10 then
		local dx = math.max(0, plazaMinX - x, x - (Config.LAUNCH_X + 20))
		local plazaFlat = (1 - smoothstep(0, 40, dx)) * (1 - smoothstep(88, 140, d))
		flat = math.max(flat, plazaFlat)
	end
	-- the Hatchery behind the spawn: flat, easing back into the hills over 30 studs
	local hf = LobbyLayout.HATCHERY.flat
	local out = math.max(hf[1] - x, x - hf[2], hf[3] - z, z - hf[4], 0)
	flat = math.max(flat, 1 - smoothstep(0, 30, out))

	local hillsAmp = blended(x, "hills")
	local mountAmp = blended(x, "mountains")
	local n1 = math.noise(x / 95, z / 95, 1.37)
	local n2 = math.noise(x / 38, z / 38, 7.11)
	local hills = (n1 + 0.5 * n2 + 0.45) * hillsAmp
	if land.dunes then
		hills = (1 - math.abs(math.noise(x / 70, z / 140, 2.2))) * hillsAmp * 1.2 - hillsAmp * 0.2
	end
	local ridgeNoise = math.noise(x / 170, z / 170, 3.71) + 0.5
	local ridge = smoothstep(110, 270, d) * mountAmp * (0.45 + 0.75 * ridgeNoise)
	ridge *= 1 - smoothstep(370, 440, d) -- fall away behind the peaks
	local h = math.max(0, hills) + ridge
	if land.terrace then
		h = math.floor(h / 14) * 14 + math.clamp((h % 14) - 11, 0, 3) * 4.6
	end
	if land.volcano then
		for _, v in ipairs(VOLCANOES) do
			local dist = Vector2.new(x - v[1], z - v[2]).Magnitude
			local cone = math.max(0, v[3] - dist * 1.05)
			if dist < 22 then
				cone -= (22 - dist) * 1.6 -- crater
			end
			h = math.max(h, cone)
		end
	end

	h = h * (1 - flat)
	-- sink the ground a little under the runway so bumpy smooth terrain never pokes through it
	if x >= Config.LAUNCH_X - 6 then
		h -= 1.2 * (1 - smoothstep(19, 25, d))
	end
	if underPaving(x, z) then
		h -= 1.2
	end

	-- river beside the runway (right side) in green stages
	local river = false
	if land.river and z > 54 and z < 90 then
		local depth = 1 - math.abs(z - 72) / 18
		h = math.min(h, -1.5 - 4 * depth)
		river = true
	end
	if land.volcano and ((z > 54 and z < 90) or (z < -54 and z > -78)) then
		h = math.min(h, -1)
	end
	if land.swamp and d > 50 and math.noise(x / 45, z / 45, 9.3) < -0.05 then
		h = math.min(h, -2.5)
		river = true
	end

	-- coastline: land sinks into the ocean after Stage 10 where the path lifts into the sky
	local coastStart = Config.LAUNCH_X + 10 * L + 40
	if x > coastStart then
		h = h + (-26 - h) * smoothstep(coastStart, coastStart + 420, x)
		river = true
	end
	-- edges of the map fall away too
	h = h - 30 * smoothstep(400, 440, d)
	return h, river
end

-- Ground material at (x, z) with height h.
function TerrainBuilder.material(x, z, h)
	local s = stageIndex(x)
	local land = LAND[s]
	local mat = land.mat
	if LobbyLayout.inPark(x, z) then
		return M.Ground -- flat turf lawn: no grass blades (they cost FPS)
	end
	if x >= Config.LAUNCH_X - 4 and math.abs(z) < 21 and h < 0.1 and (mat == M.Grass or mat == M.LeafyGrass) then
		return M.Ground -- under the runway: no grass blades poking through the road
	end
	if land.volcano then
		for _, v in ipairs(VOLCANOES) do
			local dist = Vector2.new(x - v[1], z - v[2]).Magnitude
			if dist < 34 then
				return M.CrackedLava
			end
		end
		if (z > 54 and z < 90) or (z < -54 and z > -78) then
			return M.CrackedLava -- lava rivers on both sides of the runway
		end
		if math.abs(z) > 30 and math.abs(math.noise(x / 70, z / 70, 4.4)) < 0.13 then
			return M.CrackedLava -- glowing lava cracks running across the ground
		end
		return M.Basalt
	end
	if land.river and h < -0.8 then
		return M.Sand
	end
	if h > 105 and s ~= 3 and s ~= 4 then
		return M.Snow
	end
	if h > 52 then
		if mat == M.Sand or mat == M.Sandstone then
			return M.Sandstone
		elseif mat == M.Snow or mat == M.Glacier then
			return h > 80 and M.Snow or M.Rock
		end
		return M.Rock
	end
	return mat
end

-- Bright cartoon colors for each terrain material.
function TerrainBuilder.applyColors()
	local t = workspace.Terrain
	local colors = {
		[M.Grass] = Color3.fromRGB(105, 205, 70), -- bright toy green (like the top simulators)
		[M.LeafyGrass] = Color3.fromRGB(135, 210, 75),
		[M.Sand] = Color3.fromRGB(255, 205, 120),
		[M.Sandstone] = Color3.fromRGB(222, 128, 80),
		[M.Mud] = Color3.fromRGB(110, 140, 70),
		[M.Snow] = Color3.fromRGB(248, 251, 255),
		[M.Glacier] = Color3.fromRGB(160, 215, 245),
		[M.Basalt] = Color3.fromRGB(85, 62, 60),
		[M.CrackedLava] = Color3.fromRGB(255, 110, 40),
		[M.Rock] = Color3.fromRGB(178, 172, 205), -- soft lavender cliffs
		[M.Ground] = Color3.fromRGB(120, 200, 80), -- lobby hills, matches the lawn
	}
	for mat, c in pairs(colors) do
		t:SetMaterialColor(mat, c)
	end
	t.WaterColor = Color3.fromRGB(60, 170, 235)
	t.WaterTransparency = 0.45
	t.WaterReflectance = 0.6
	t.WaterWaveSize = 0.12
	t.WaterWaveSpeed = 8
end

-- Writes terrain for x in [xFrom, xTo). Call in slices to keep each call short.
function TerrainBuilder.build(xFrom, xTo)
	local terrain = workspace.Terrain
	local CH = 64 -- columns per chunk side
	local zMin, zMax = -TerrainBuilder.Z_MAX, TerrainBuilder.Z_MAX
	local written = 0
	for cx = xFrom, xTo - 1, CH * RES do
		for cz = zMin, zMax - 1, CH * RES do
			local nx = math.min(CH, math.ceil((xTo - cx) / RES))
			local nz = math.min(CH, math.ceil((zMax - cz) / RES))
			-- heights + materials per column first, so each chunk only spans the height it needs
			local hs, mats, wet = {}, {}, {}
			local top = Y_MIN + RES
			for i = 1, nx do
				hs[i], mats[i], wet[i] = {}, {}, {}
				for k = 1, nz do
					local x = cx + (i - 0.5) * RES
					local z = cz + (k - 0.5) * RES
					local h, water = TerrainBuilder.height(x, z)
					hs[i][k] = h - SURFACE_OFFSET
					mats[i][k] = TerrainBuilder.material(x, z, h)
					wet[i][k] = water
					top = math.max(top, h + RES)
				end
			end
			local waterTop = TerrainBuilder.WATER_LEVEL -- water has no surface offset
			top = math.max(top, waterTop + RES)
			local ny = math.ceil((top - Y_MIN) / RES)
			local materials, occupancy = {}, {}
			for i = 1, nx do
				materials[i], occupancy[i] = {}, {}
				for j = 1, ny do
					local mRow, oRow = {}, {}
					materials[i][j], occupancy[i][j] = mRow, oRow
					local yb = Y_MIN + (j - 1) * RES
					for k = 1, nz do
						local h = hs[i][k]
						local occ = math.clamp((h - yb) / RES, 0, 1)
						if occ > 0 then
							mRow[k] = mats[i][k] -- same material all the way down, so nothing odd bleeds through
							oRow[k] = occ
						elseif wet[i][k] and yb < waterTop then
							mRow[k] = M.Water
							oRow[k] = math.clamp((waterTop - yb) / RES, 0, 1)
						else
							mRow[k] = M.Air
							oRow[k] = 0
						end
					end
				end
			end
			local region = Region3.new(Vector3.new(cx, Y_MIN, cz), Vector3.new(cx + nx * RES, Y_MIN + ny * RES, cz + nz * RES))
			terrain:WriteVoxels(region, RES, materials, occupancy)
			written += nx * ny * nz
		end
	end
	return written
end

function TerrainBuilder.clear()
	workspace.Terrain:Clear()
end

return TerrainBuilder
