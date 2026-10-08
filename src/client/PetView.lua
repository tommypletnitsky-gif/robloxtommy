-- Drawing pets and eggs in the UI (shared by PetClient, EggClient and TradeClient):
--   PetView.petModel(kind, golden, rainbow) / PetView.eggModel(egg) -> a fresh anchored Model
--   PetView.rainbowStroke(uiStroke) -> rainbow card border
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

-- Golden / Rainbow pets: the same mesh + texture re-drawn as a SpecialMesh, whose VertexColor tints
-- it while keeping every detail of the texture. Golden = a fixed gold tint; Rainbow = a tint that
-- cycles through the rainbow (all rainbow meshes are updated together, in the world and in
-- viewports). Golden Rainbow = the rainbow cycle, brighter.
local RunService = game:GetService("RunService")
local rainbowMeshes = setmetatable({}, { __mode = "k" }) -- [SpecialMesh or BasePart] = brightness
local function tinted(m, golden, rainbow)
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
			sm.VertexColor = golden and not rainbow and Config.GOLDEN_TINT or Vector3.one
			sm.Parent = p
			p.Parent = mp.Parent
			if rainbow then
				rainbowMeshes[sm] = golden and 1.9 or 1.45
			end
			if m.PrimaryPart == mp then
				m.PrimaryPart = p
			end
			mp:Destroy()
		elseif mp:IsA("BasePart") then
			-- (the plain fallback model)
			mp.Color = golden and PetView.GOLD or mp.Color
			if rainbow then
				rainbowMeshes[mp] = 1
			end
		end
	end
	return m
end
-- one loop for every rainbow pet on screen: a smooth hue cycle
RunService.RenderStepped:Connect(function()
	local hue = (os.clock() * 0.18) % 1
	local c = Color3.fromHSV(hue, 0.6, 1)
	for obj, bright in pairs(rainbowMeshes) do
		if obj.Parent == nil then
			rainbowMeshes[obj] = nil
		elseif obj:IsA("SpecialMesh") then
			obj.VertexColor = Vector3.new(c.R, c.G, c.B) * bright
		else
			obj.Color = c
		end
	end
end)

function PetView.petModel(kind, golden, rainbow)
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
	if golden or rainbow then
		tinted(m, golden, rainbow)
	end
	return m
end

-- a rainbow border for UI cards of Rainbow pets (a UIStroke gets a rainbow UIGradient)
function PetView.rainbowStroke(stroke)
	stroke.Color = Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 110)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
	})
	g.Parent = stroke
	return g
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
