-- Small helpers for building cartoon scenery out of parts.
local BuildKit = {}

function BuildKit.part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end
local part = BuildKit.part

BuildKit.UP = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's X axis to point up

function BuildKit.ball(parent, size, pos, color, props)
	local t = { Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(pos), Color = color }
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return part(parent, t)
end

-- A cylinder `length` long along its X axis (multiply cf by BuildKit.UP for an upright one).
function BuildKit.cyl(parent, length, diameter, cf, color, props)
	local t = { Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), CFrame = cf, Color = color }
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return part(parent, t)
end

-- Upright cylinder standing on `base` (a Vector3 on the ground).
function BuildKit.column(parent, height, diameter, base, color, props)
	return BuildKit.cyl(parent, height, diameter, CFrame.new(base + Vector3.new(0, height / 2, 0)) * BuildKit.UP, color, props)
end

-- A block stretched between two points (for beams, fences, ropes).
function BuildKit.beam(parent, a, b, thickness, color, props)
	local t = { Size = Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color }
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	return part(parent, t)
end

function BuildKit.sign(p, face, text, textColor, bg, strokeColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg or Color3.fromRGB(25, 25, 35)
	label.BackgroundTransparency = bg and 0 or 1
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = strokeColor or Color3.fromRGB(0, 0, 0)
	stroke.Parent = label
	return label
end

function BuildKit.darker(c, f)
	return c:Lerp(Color3.new(0, 0, 0), f or 0.3)
end
function BuildKit.lighter(c, f)
	return c:Lerp(Color3.new(1, 1, 1), f or 0.3)
end

return BuildKit
