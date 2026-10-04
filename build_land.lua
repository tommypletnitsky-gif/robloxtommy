--[[
	Simulator Land Builder
	-------------------------------------------------------------
	HOW TO RUN:
	  1. In Roblox Studio: View tab > Command Bar (if not already shown).
	  2. Paste this ENTIRE script into the Command Bar and press Enter.
	  3. It builds everything under Workspace > "SimulatorLand".

	Safe to re-run: it deletes the previous "SimulatorLand" folder first,
	so you can tweak values and run again without piling up duplicates.

	Builds (LAND ONLY, no gameplay):
	  - One 500x500 bright-green grass island, top surface at y = 0
	  - A SpawnLocation in the dead center
	  - 8 fenced dirt plots in two rows (Plots 1-4 front, 5-8 back),
	    center kept open around spawn, each with a floating "Plot N" sign
--]]

local Workspace = game:GetService("Workspace")

-- ---------- Clean previous build (safe re-runs) ----------
local existing = Workspace:FindFirstChild("SimulatorLand")
if existing then
	existing:Destroy()
end

local root = Instance.new("Folder")
root.Name = "SimulatorLand"
root.Parent = Workspace

-- ---------- Tunable constants ----------
local ISLAND_SIZE      = 500
local ISLAND_THICKNESS = 4

local PLOT_SIZE        = 60   -- each dirt plot is 60 x 60 studs
local PLOT_THICKNESS   = 1
local FENCE_HEIGHT     = 4    -- "low" wooden fence
local FENCE_THICKNESS  = 0.6

local DIRT_COLOR  = Color3.fromRGB(121, 85, 58)
local WOOD_COLOR  = Color3.fromRGB(110, 70, 45)
local BOARD_COLOR = Color3.fromRGB(150, 105, 65)

-- ---------- Island ----------
local island = Instance.new("Part")
island.Name = "GrassIsland"
island.Anchored = true
island.Size = Vector3.new(ISLAND_SIZE, ISLAND_THICKNESS, ISLAND_SIZE)
island.Position = Vector3.new(0, -ISLAND_THICKNESS / 2, 0) -- top face sits at y = 0
island.Material = Enum.Material.Grass
island.Color = Color3.fromRGB(126, 206, 84)
island.TopSurface = Enum.SurfaceType.Smooth
island.BottomSurface = Enum.SurfaceType.Smooth
island.Parent = root

-- ---------- Center spawn ----------
local spawn = Instance.new("SpawnLocation")
spawn.Name = "CenterSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 0.5, 0) -- rests on island top
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.BottomSurface = Enum.SurfaceType.Smooth
spawn.Parent = root

-- ---------- Helpers ----------
local function buildFence(parent, x, z)
	local half = PLOT_SIZE / 2
	local railY = FENCE_HEIGHT / 2 -- fence base at island top (y = 0)
	local sides = {
		{ pos = Vector3.new(x,        railY, z - half), size = Vector3.new(PLOT_SIZE, FENCE_HEIGHT, FENCE_THICKNESS) },
		{ pos = Vector3.new(x,        railY, z + half), size = Vector3.new(PLOT_SIZE, FENCE_HEIGHT, FENCE_THICKNESS) },
		{ pos = Vector3.new(x - half, railY, z),        size = Vector3.new(FENCE_THICKNESS, FENCE_HEIGHT, PLOT_SIZE) },
		{ pos = Vector3.new(x + half, railY, z),        size = Vector3.new(FENCE_THICKNESS, FENCE_HEIGHT, PLOT_SIZE) },
	}
	for _, s in ipairs(sides) do
		local rail = Instance.new("Part")
		rail.Name = "Fence"
		rail.Anchored = true
		rail.Size = s.size
		rail.Position = s.pos
		rail.Material = Enum.Material.Wood
		rail.Color = WOOD_COLOR
		rail.TopSurface = Enum.SurfaceType.Smooth
		rail.BottomSurface = Enum.SurfaceType.Smooth
		rail.Parent = parent
	end
end

local function buildSign(parent, x, z, number)
	local board = Instance.new("Part")
	board.Name = "Sign"
	board.Anchored = true
	board.CanCollide = false
	board.Size = Vector3.new(8, 3, 0.5)
	board.Position = Vector3.new(x, 12, z) -- floats above the plot
	board.Material = Enum.Material.WoodPlanks
	board.Color = BOARD_COLOR
	board.Parent = parent

	local bb = Instance.new("BillboardGui")
	bb.Name = "SignGui"
	bb.Adornee = board
	bb.Size = UDim2.new(0, 200, 0, 70)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.MaxDistance = 500
	bb.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Plot " .. number
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.4
	label.Parent = bb
end

-- ---------- Plots: two symmetrical rows, center kept open ----------
-- X columns leave a clear lane through the middle (gap around x = 0).
-- Z rows leave the spawn area open (gap between z = -120 and z = 120).
local xs = { -195, -65, 65, 195 }
local zs = { -120, 120 } -- front row first, then back row

local plotNumber = 0
for _, z in ipairs(zs) do
	for _, x in ipairs(xs) do
		plotNumber += 1
		local plot = Instance.new("Folder")
		plot.Name = "Plot" .. plotNumber
		plot.Parent = root

		local dirt = Instance.new("Part")
		dirt.Name = "Dirt"
		dirt.Anchored = true
		dirt.Size = Vector3.new(PLOT_SIZE, PLOT_THICKNESS, PLOT_SIZE)
		dirt.Position = Vector3.new(x, PLOT_THICKNESS / 2, z) -- rests on island top
		dirt.Material = Enum.Material.Ground
		dirt.Color = DIRT_COLOR
		dirt.TopSurface = Enum.SurfaceType.Smooth
		dirt.BottomSurface = Enum.SurfaceType.Smooth
		dirt.Parent = plot

		buildFence(plot, x, z)
		buildSign(plot, x, z, plotNumber)
	end
end

print(("[SimulatorLand] Built island + spawn + %d plots."):format(plotNumber))
