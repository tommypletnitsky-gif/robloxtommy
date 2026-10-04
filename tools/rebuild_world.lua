-- Rebuilds Workspace.World in edit mode with the latest WorldBuilder/Config.
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
local wb = fresh(SSS.WorldBuilder)
local world = require(wb).build()
local n = 0
for _, d in ipairs(world:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return "world rebuilt: " .. n .. " parts"
