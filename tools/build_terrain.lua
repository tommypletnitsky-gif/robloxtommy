-- Generates terrain for one slice of the map: loadstring(src)(xFrom, xTo, clearFirst)
-- Run several slices (each call stays short) from execute_luau in Edit mode.
local xFrom, xTo, clearFirst = ...
local SSS = game:GetService("ServerScriptService")
local oldLayout = SSS.LobbyLayout -- swap in a fresh copy so require() picks up edits
local lay = oldLayout:Clone()
oldLayout:Destroy()
lay.Parent = SSS
local m = SSS.TerrainBuilder:Clone() -- fresh require
m.Parent = SSS.TerrainBuilder.Parent
local TB = require(m)
m:Destroy()
if clearFirst then
	TB.clear()
	TB.applyColors()
end
local t0 = os.clock()
local cells = TB.build(xFrom or TB.X_MIN, xTo or TB.X_MAX)
return string.format("terrain %d..%d: %d voxels in %.1fs", xFrom or TB.X_MIN, xTo or TB.X_MAX, cells, os.clock() - t0)
