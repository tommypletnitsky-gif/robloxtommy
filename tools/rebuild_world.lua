-- Rebuilds Workspace.World in edit mode with the latest WorldBuilder/Scenery/Config.
-- ModuleScripts are swapped for fresh clones so require() doesn't return a cached old version.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local function fresh(m)
	local c = m:Clone()
	c.Parent = m.Parent
	m:Destroy()
	return c
end
fresh(RS.Shared.Config)
fresh(RS.Shared.RocketModel)
fresh(SSS.BuildKit)
fresh(SSS.TerrainBuilder)
fresh(SSS.Scenery)
fresh(SSS.Lobby)
local wb = fresh(SSS.WorldBuilder)
local t0 = os.clock()
local world = require(wb).build()
local n = 0
for _, d in ipairs(world:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return string.format("world rebuilt: %d parts in %.1fs", n, os.clock() - t0)
