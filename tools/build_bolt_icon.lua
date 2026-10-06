-- Builds ReplicatedStorage.UIIcons.Bolt: a chunky yellow lightning bolt out of parts (the AI mesh
-- came out as a beige blob). Run in Edit mode with execute_luau, then save + publish the place.
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:34873/tools/build_bolt_icon.lua"))()
local icons = game:GetService("ReplicatedStorage"):WaitForChild("UIIcons")
local YELLOW = Color3.fromRGB(255, 232, 60)
local DEPTH = 0.55

local m = Instance.new("Model")
m.Name = "Bolt"
local function part(class, size, cf)
	local p = Instance.new(class)
	p.Size = size
	p.CFrame = cf
	p.Color = YELLOW
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

-- upper slab, leaning, and the bar across the middle
part("Part", Vector3.new(0.8, 1.8, DEPTH), CFrame.new(-0.1, 0.8, 0) * CFrame.Angles(0, 0, math.rad(22)))
part("Part", Vector3.new(1.35, 0.5, DEPTH), CFrame.new(0.05, 0, 0))
-- lower part: a down-pointing triangle (two wedges), tilted so the tip lands down and across
local W, H = 0.95, 1.9
local base = CFrame.new(-0.25, 0.22, 0) * CFrame.Angles(0, 0, math.rad(21))
for _, side in ipairs({ -1, 1 }) do
	-- local Z of the wedge runs across the screen; its right-angle corner sits on the middle line
	local vX = Vector3.new(0, 0, -side)
	local vY = Vector3.new(0, -1, 0)
	local cf = CFrame.fromMatrix(Vector3.zero, vX, vY)
	part("WedgePart", Vector3.new(DEPTH, H, W / 2), base * CFrame.new(side * W / 4, -H / 2, 0) * cf)
end

local old = icons:FindFirstChild("Bolt")
if old then
	old:Destroy()
end
m.Parent = icons
return "built Bolt (" .. #m:GetChildren() .. " parts)"
