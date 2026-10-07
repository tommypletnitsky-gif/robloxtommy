-- Drawing pets and eggs in the UI (shared by PetClient, EggClient and TradeClient):
--   PetView.petModel(kind, golden) / PetView.eggModel(egg) -> a fresh anchored Model
--   PetView.viewport(parent, model, props) -> a ViewportFrame showing the model from the front
--   PetView.rarityColor(rarity), PetView.GOLD
-- All pet / egg meshes are preloaded once; viewports made before that are refreshed when it's done.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local make = UIKit.make

local PetView = {}
PetView.GOLD = Color3.fromRGB(255, 190, 40)
local GREY = Color3.fromRGB(160, 165, 185)

local petFolder = ReplicatedStorage:WaitForChild("PetModels", 10)
local eggFolder = ReplicatedStorage:WaitForChild("EggModels", 10)
PetView.petFolder = petFolder
PetView.eggFolder = eggFolder

function PetView.rarityColor(rarity)
	return Config.Rarities[rarity].color
end

local function prep(m)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	return m
end
PetView.prep = prep

-- Golden pets: the same mesh + texture re-drawn with a gold tint (SpecialMesh.VertexColor keeps
-- every detail of the texture, just golden).
local function makeGolden(m)
	for _, mp in ipairs(m:GetDescendants()) do
		if mp:IsA("MeshPart") then
			local okSize, meshSize = pcall(function()
				return mp.MeshSize
			end)
			local p = Instance.new("Part")
			p.Name = mp.Name
			p.Size = mp.Size
			p.CFrame = mp.CFrame
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			local sm = Instance.new("SpecialMesh")
			sm.MeshType = Enum.MeshType.FileMesh
			sm.MeshId = mp.MeshId
			sm.TextureId = mp.TextureID
			sm.Scale = (okSize and meshSize.Magnitude > 0) and (mp.Size / meshSize) or Vector3.one
			sm.VertexColor = Config.GOLDEN_TINT
			sm.Parent = p
			p.Parent = mp.Parent
			if m.PrimaryPart == mp then
				m.PrimaryPart = p
			end
			mp:Destroy()
		elseif mp:IsA("BasePart") then
			mp.Color = PetView.GOLD -- (the plain fallback model)
		end
	end
	return m
end

function PetView.petModel(kind, golden)
	local t = petFolder and petFolder:FindFirstChild(kind)
	local m
	if t then
		m = prep(t:Clone())
	else
		local pet = Config.Pets[kind]
		m = Instance.new("Model")
		make("Part", { Parent = m, Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = CFrame.new(0, 1.3, 0), Color = pet and Config.Rarities[pet.rarity].color or GREY, Material = Enum.Material.SmoothPlastic })
		m.WorldPivot = CFrame.new()
		prep(m)
	end
	if golden then
		makeGolden(m)
	end
	return m
end

function PetView.eggModel(egg)
	local t = eggFolder and eggFolder:FindFirstChild(egg.id)
	if t then
		return prep(t:Clone())
	end
	local m = Instance.new("Model")
	local p = make("Part", { Parent = m, Size = Vector3.new(3.6, 4.6, 3.6), CFrame = CFrame.new(0, 2.3, 0), Color = egg.color, Material = Enum.Material.SmoothPlastic })
	make("SpecialMesh", { Parent = p, MeshType = Enum.MeshType.Sphere })
	m.WorldPivot = CFrame.new()
	return prep(m)
end

-- A ViewportFrame showing `model` from the front (models face -Z, pivot at their feet).
local viewports = {} -- re-parented once the meshes have downloaded
local preloadDone = false -- after that, new viewports aren't tracked (no leak)
function PetView.viewport(parent, model, props)
	local vp = make("ViewportFrame", props)
	vp.Parent = parent
	vp.BackgroundTransparency = props.BackgroundTransparency or 1
	vp.Ambient = Color3.fromRGB(190, 190, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-0.5, -1, 0.8)
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	local d = size.Magnitude * 1.75
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(d * 0.28, d * 0.18, -d), cf.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
	if not preloadDone then
		table.insert(viewports, { vp = vp, model = model })
	end
	return vp
end

task.spawn(function()
	local list = {}
	for _, f in ipairs({ petFolder, eggFolder }) do
		if f then
			for _, m in ipairs(f:GetChildren()) do
				table.insert(list, m)
			end
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
	for _, v in ipairs(viewports) do
		if v.model.Parent == v.vp then
			v.model.Parent = nil
			v.model.Parent = v.vp
		end
	end
	preloadDone = true
	table.clear(viewports)
end)

return PetView
