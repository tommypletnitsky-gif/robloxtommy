-- Trees + bushes from Yasu's Stylized Tree Pack (original by mvyasu, audited: no scripts).
-- The models live in ServerStorage.TreeModels (pivot at the base, attributes Height + Kind).
-- Leaves are tinted per palette; falls back to simple part trees if the models are missing.
local ServerStorage = game:GetService("ServerStorage")

local Foliage = {}

local C = Color3.fromRGB
local BARK = C(150, 105, 75)

Foliage.PALETTES = {
	park = { C(255, 165, 200), C(255, 190, 215), C(255, 170, 80), C(250, 205, 90), C(235, 120, 90), C(140, 185, 110), C(120, 175, 120) },
	meadow = { C(140, 185, 110), C(120, 175, 120), C(150, 190, 100), C(250, 205, 90), C(255, 175, 205) },
	orchard = { C(140, 185, 110), C(255, 175, 205), C(255, 170, 80), C(150, 190, 100) },
	jungle = { C(95, 160, 95), C(80, 150, 90), C(115, 170, 95) },
	island = { C(255, 165, 200), C(255, 190, 215), C(140, 190, 115) },
	blossom = { C(255, 160, 200) },
}

local function models(kind)
	local folder = ServerStorage:FindFirstChild("TreeModels")
	local list = {}
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:GetAttribute("Kind") == kind then
				table.insert(list, m)
			end
		end
	end
	return list
end

-- Simple part tree, only used if the tree models are missing from the place.
local function fallbackTree(parent, pos, height, tint)
	local function p(props)
		local x = Instance.new("Part")
		x.Anchored = true
		x.TopSurface = Enum.SurfaceType.Smooth
		x.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in pairs(props) do
			x[k] = v
		end
		x.Parent = parent
	end
	p({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height * 0.6, 1.6, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, height * 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = BARK, Material = Enum.Material.Wood })
	p({ Shape = Enum.PartType.Ball, Size = Vector3.one * height * 0.55, CFrame = CFrame.new(pos + Vector3.new(0, height * 0.75, 0)), Color = tint, Material = Enum.Material.Grass })
end

local function plant(parent, kind, pos, rng, height, tint)
	local list = models(kind)
	if #list == 0 then
		return false
	end
	local m = list[rng:NextInteger(1, #list)]:Clone()
	m:ScaleTo(m:GetScale() * height / m:GetAttribute("Height"))
	m:PivotTo(CFrame.new(pos - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("SurfaceAppearance") then
			pcall(function()
				d.Color = d.AlphaMode == Enum.AlphaMode.Transparency and tint or BARK
			end)
		end
	end
	m.Parent = parent
	return true
end

-- palette: a name from Foliage.PALETTES or a Color3.
local function pickTint(rng, palette)
	if typeof(palette) == "Color3" then
		return palette
	end
	local list = Foliage.PALETTES[palette or "park"] or Foliage.PALETTES.park
	return list[rng:NextInteger(1, #list)]
end

function Foliage.tree(parent, pos, rng, height, palette)
	height = height or rng:NextNumber(24, 34)
	local tint = pickTint(rng, palette)
	if not plant(parent, "Tree", pos, rng, height, tint) then
		fallbackTree(parent, pos, height * 0.6, tint)
	end
end

function Foliage.bush(parent, pos, rng, size, palette)
	size = size or rng:NextNumber(4, 6.5)
	local tint = pickTint(rng, palette)
	if not plant(parent, "Bush", pos, rng, size, tint) then
		fallbackTree(parent, pos, size, tint)
	end
end

return Foliage
