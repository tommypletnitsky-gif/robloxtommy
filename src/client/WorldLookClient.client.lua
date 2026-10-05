-- World look (client): the bright cartoon color grade, per-zone / per-stage lighting moods, soft
-- clouds over Earth and the Sky zone, and the galaxy skybox in Space. Follows the camera.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local camera = workspace.CurrentCamera

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
local grade = Lighting:FindFirstChild("CartoonGrade") or Instance.new("ColorCorrectionEffect")
grade.Name = "CartoonGrade"
grade.Saturation = 0.08
grade.Contrast = 0.08
grade.Brightness = 0.02
grade.Parent = Lighting
-- Softer glow: full-strength bloom made white paving and bright parts blinding.
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	bloom.Intensity = 0.35
	bloom.Threshold = 2.4
end
local ZONES = {
	Earth = { lighting = { ClockTime = 14, Brightness = 2.2, Ambient = Color3.fromRGB(90, 90, 100), OutdoorAmbient = Color3.fromRGB(150, 150, 160) }, atmo = { Density = 0.25, Haze = 0, Glare = 0, Color = Color3.fromRGB(210, 225, 255) } },
	Sky = { lighting = { ClockTime = 16.5, Brightness = 2.6, Ambient = Color3.fromRGB(120, 120, 140), OutdoorAmbient = Color3.fromRGB(170, 170, 200) }, atmo = { Density = 0.32, Haze = 1.2, Glare = 0, Color = Color3.fromRGB(210, 230, 255) } },
	Space = { lighting = { ClockTime = 13, Brightness = 1.4, Ambient = Color3.fromRGB(110, 100, 150), OutdoorAmbient = Color3.fromRGB(130, 120, 170) }, atmo = { Density = 0, Haze = 0, Glare = 0, Color = Color3.fromRGB(0, 0, 0) } },
}
-- Some worlds get their own mood on top of the zone lighting.
local STAGE_MOODS = {
	["Dusty Desert"] = { lighting = { ClockTime = 13, Brightness = 2.6 }, atmo = { Color = Color3.fromRGB(255, 225, 180), Density = 0.3, Haze = 0.6 } },
	["Red Canyon"] = { lighting = { ClockTime = 15.5 }, atmo = { Color = Color3.fromRGB(255, 200, 170), Density = 0.3, Haze = 0.8 } },
	["Misty Swamp"] = { lighting = { Brightness = 1.7 }, atmo = { Color = Color3.fromRGB(190, 225, 190), Density = 0.42, Haze = 2.2 } },
	["Volcano"] = { lighting = { ClockTime = 17.4, Brightness = 2, OutdoorAmbient = Color3.fromRGB(170, 120, 110) }, atmo = { Color = Color3.fromRGB(255, 150, 110), Density = 0.38, Haze = 2 } },
	["Snowy Tundra"] = { lighting = { Brightness = 2.5 }, atmo = { Color = Color3.fromRGB(225, 240, 255), Density = 0.3, Haze = 0.8 } },
	["Sunset Sky"] = { lighting = { ClockTime = 16.9, Brightness = 2.8 }, atmo = { Color = Color3.fromRGB(255, 175, 110), Density = 0.3, Haze = 2.2, Glare = 0.4 } },
	["Thunder Storm"] = { lighting = { Brightness = 1.3, OutdoorAmbient = Color3.fromRGB(120, 120, 145) }, atmo = { Color = Color3.fromRGB(150, 155, 180), Density = 0.45, Haze = 2.5 } },
	["Aurora Lights"] = { lighting = { ClockTime = 20.5, Brightness = 1.4 }, atmo = { Color = Color3.fromRGB(150, 220, 210), Density = 0.25, Haze = 1 } },
	["Edge of Space"] = { lighting = { ClockTime = 19.6, Brightness = 1.5 }, atmo = { Color = Color3.fromRGB(120, 130, 200), Density = 0.18, Haze = 0.5 } },
}

local function moodFor(x)
	local stage = x < Config.LAUNCH_X and nil or Config.Stages[Config.stageAt(x)]
	local zone = stage and stage.zone or "Earth"
	local lighting, atmo = table.clone(ZONES[zone].lighting), table.clone(ZONES[zone].atmo)
	local mood = stage and STAGE_MOODS[stage.name]
	if mood then
		for k, v in pairs(mood.lighting) do
			lighting[k] = v
		end
		for k, v in pairs(mood.atmo) do
			atmo[k] = v
		end
	end
	return (stage and stage.name or "Lobby"), lighting, atmo
end

-- Sky: soft cartoon clouds over Earth and the Sky zone (thicker / greyer for some stages), and a
-- starry galaxy skybox once you're in Space.
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
clouds.Parent = workspace.Terrain
local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky", Lighting)
local SKYBOX_FACES = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
local DAY_SKY = {}
for _, face in ipairs(SKYBOX_FACES) do
	DAY_SKY[face] = sky[face]
end
local function asset(id)
	return "rbxassetid://" .. id
end
local SPACE_SKY = { SkyboxBk = asset(159454299), SkyboxDn = asset(159454296), SkyboxFt = asset(159454293), SkyboxLf = asset(159454286), SkyboxRt = asset(159454300), SkyboxUp = asset(159454288) }
local CLOUDS = {
	Earth = { Cover = 0.6, Density = 0.45, Color = Color3.fromRGB(255, 255, 255) },
	Sky = { Cover = 0.78, Density = 0.55, Color = Color3.fromRGB(255, 250, 255) },
	Space = { Cover = 0, Density = 0, Color = Color3.fromRGB(255, 255, 255) },
}
local STAGE_CLOUDS = {
	["Dusty Desert"] = { Cover = 0.3 },
	["Red Canyon"] = { Cover = 0.35 },
	["Volcano"] = { Cover = 0.75, Color = Color3.fromRGB(200, 170, 165) },
	["Misty Swamp"] = { Cover = 0.8, Color = Color3.fromRGB(225, 235, 225) },
	["Thunder Storm"] = { Cover = 0.95, Density = 0.8, Color = Color3.fromRGB(140, 145, 165) },
	["Sunset Sky"] = { Color = Color3.fromRGB(255, 205, 175) },
	["Edge of Space"] = { Cover = 0.4 },
}
local currentSky = "day"
local function setSky(kind)
	if kind == currentSky then
		return
	end
	currentSky = kind
	local faces = kind == "space" and SPACE_SKY or DAY_SKY
	for face, id in pairs(faces) do
		sky[face] = id
	end
	sky.StarCount = kind == "space" and 5000 or 3000
	sky.CelestialBodiesShown = kind ~= "space"
end

local currentMood = nil
RunService.Heartbeat:Connect(function()
	local name, lighting, atmo = moodFor(camera.CFrame.Position.X)
	if name ~= currentMood then
		currentMood = name
		local info = TweenInfo.new(2)
		TweenService:Create(Lighting, info, lighting):Play()
		TweenService:Create(atmosphere, info, atmo):Play()
		local stage = camera.CFrame.Position.X >= Config.LAUNCH_X and Config.Stages[Config.stageAt(camera.CFrame.Position.X)] or nil
		local zone = stage and stage.zone or "Earth"
		local c = table.clone(CLOUDS[zone])
		for k, v in pairs(stage and STAGE_CLOUDS[stage.name] or {}) do
			c[k] = v
		end
		TweenService:Create(clouds, info, c):Play()
		setSky(zone == "Space" and "space" or "day")
	end
end)
