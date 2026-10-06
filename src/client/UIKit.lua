-- Shared "glossy bubbly" UI pieces: chunky outlined buttons with gradients and bounce,
-- bright windows, toasts, and sounds. Every client script uses the same ScreenGui ("RocketHUD").
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local spr = require(script.Parent:WaitForChild("spr")) -- spring animations (Fraktality/spr, MIT)

local UIKit = {}
UIKit.FONT = Enum.Font.FredokaOne
UIKit.INK = Color3.fromRGB(30, 30, 50) -- outline color

local player = Players.LocalPlayer

function UIKit.gui()
	local pg = player:WaitForChild("PlayerGui")
	local g = pg:FindFirstChild("RocketHUD")
	if not g then
		g = Instance.new("ScreenGui")
		g.Name = "RocketHUD"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		g.Parent = pg
	end
	return g
end

-- GuiObject.AbsolutePosition is measured from just below Roblox's top bar, but our ScreenGui
-- ignores that inset (it covers the whole screen). Convert an absolute point to an offset you
-- can use as a Position inside UIKit.gui().
function UIKit.toGui(absolute)
	return absolute - UIKit.gui().AbsolutePosition
end

function UIKit.make(className, props, children)
	local o = Instance.new(className)
	local parent = props.Parent
	for k, v in pairs(props) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	o.Parent = parent
	return o
end
local make = UIKit.make

function UIKit.corner(r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 14) })
end

function UIKit.stroke(t, c)
	return make("UIStroke", { Thickness = t or 3, Color = c or UIKit.INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UIKit.lighter(c, f)
	return c:Lerp(Color3.new(1, 1, 1), f or 0.35)
end
function UIKit.darker(c, f)
	return c:Lerp(Color3.new(0, 0, 0), f or 0.3)
end

-- Vertical gloss gradient: light on top, deeper at the bottom.
function UIKit.gloss(color)
	return make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, UIKit.lighter(color, 0.35)),
			ColorSequenceKeypoint.new(0.5, color),
			ColorSequenceKeypoint.new(1, UIKit.darker(color, 0.18)),
		}),
	})
end

-- Text with a dark outline (the cartoon look).
function UIKit.label(props)
	local base = { BackgroundTransparency = 1, Font = UIKit.FONT, TextColor3 = Color3.new(1, 1, 1), TextScaled = true }
	for k, v in pairs(props) do
		base[k] = v
	end
	local strokeT = base.StrokeThickness or 2.5
	base.StrokeThickness = nil
	local l = make("TextLabel", base)
	make("UIStroke", { Parent = l, Thickness = strokeT, Color = UIKit.INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	return l
end

-- Sounds ------------------------------------------------------------------------------
-- Sound rules (owner: "too much sound on almost everything"):
--   * everything plays at MASTER volume
--   * button clicks and window pops are silent
--   * the same sound can't repeat faster than its cooldown (coin bursts, ticks...)
--   * small sounds don't stack: if one just started, another small one is skipped
--     (big moments - BIG - always play)
local soundCache = {}
local MASTER = 0.6
local MUTED = { Click = true, Pop = true }
local COOLDOWN = { Tick = 0.16, Coin = 0.15, Gem = 0.25, Whoosh = 0.3, Boost = 0.3, Beep = 0.2 }
local BIG = { Hit = true, Boom = true, Jingle = true, Fanfare = true, Win = true, Launch = true, PowerDown = true }
local lastPlayed = {}
local lastAny = 0
function UIKit.sound(name, volume, pitch)
	local id = Config.Sounds[name]
	if not id or MUTED[name] or player:GetAttribute("SoundOn") == false then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < (COOLDOWN[name] or 0.1) then
		return
	end
	if not BIG[name] and now - lastAny < 0.06 then
		return
	end
	lastPlayed[name] = now
	lastAny = now
	local s = soundCache[name]
	if not s then
		s = Instance.new("Sound")
		s.SoundId = id
		s.Parent = SoundService
		soundCache[name] = s
	end
	s.Volume = (volume or 0.5) * MASTER
	s.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(s)
	return s
end

-- Buttons -----------------------------------------------------------------------------
local function bounce(target)
	local scale = target:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = target })
	scale.Scale = 0.75
	spr.target(scale, 0.4, 4, { Scale = 1 }) -- wobbly pop
end
UIKit.bounce = bounce
UIKit.spr = spr

-- 3D icons --------------------------------------------------------------------------------
-- A ViewportFrame showing a model (ReplicatedStorage.UIIcons[name], or any Model) that bobs and
-- turns gently, and spins once when you hover / press its button. Models pivot at their feet and
-- face -Z (like the pets) or +X (rockets: pass Yaw = -90).
local icons = {} -- live icons, animated below
local iconFolder = nil
local function iconTemplate(source)
	if typeof(source) == "Instance" then
		return source
	end
	iconFolder = iconFolder or ReplicatedStorage:WaitForChild("UIIcons", 5)
	return iconFolder and iconFolder:FindFirstChild(source)
end

local function pose(info, spinAngle)
	info.model:PivotTo(CFrame.Angles(info.tilt, info.yaw + spinAngle, 0) * info.home)
end

function UIKit.icon3D(parent, source, props)
	props = props or {}
	local template = iconTemplate(source)
	local vp = make("ViewportFrame", {
		Parent = parent,
		Name = "Icon3D",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or (parent:IsA("GuiObject") and parent.ZIndex + 1 or 1),
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	})
	if not template then
		return vp
	end
	local model = template:Clone()
	if model:IsA("BasePart") then
		local m = Instance.new("Model")
		model.Parent = m
		model = m
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("LuaSourceContainer") or d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Light") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	local cf, size = model:GetBoundingBox()
	local center = cf.Position
	local base = CFrame.new(-center) -- model centered on the origin
	model:PivotTo(base * model:GetPivot())
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local d = size.Magnitude * (props.Zoom or 1.55)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, size.Magnitude * 0.18, -d), Vector3.zero) -- from the front (models face -Z)
	cam.Parent = vp
	vp.CurrentCamera = cam
	model.Parent = vp
	local info = { vp = vp, model = model, h = size.Y, home = model:GetPivot(), yaw = math.rad(props.Yaw or 0), tilt = math.rad(props.Tilt or 0), phase = math.random() * 6, spin = 0, still = props.Still }
	table.insert(icons, info)
	vp.Destroying:Connect(function()
		local i = table.find(icons, info)
		if i then
			table.remove(icons, i)
		end
	end)
	local api = {}
	function api.spin()
		info.spin = math.pi * 2
	end
	vp:SetAttribute("Icon", true)
	pose(info, 0)
	return vp, api
end

-- Only icons you can actually see are animated: every ancestor visible (a closed window hides
-- everything in it) and, inside a scrolling list, not scrolled out of view.
local function onScreen(vp)
	local node = vp
	local clip = nil
	while node do
		if node:IsA("ScreenGui") then
			if not node.Enabled then
				return false
			end
			break
		elseif node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
			if not clip and node:IsA("ScrollingFrame") then
				clip = node
			end
		elseif not node:IsA("Folder") then
			return false
		end
		node = node.Parent
	end
	if not node then
		return false
	end
	if clip then
		local a, as = vp.AbsolutePosition, vp.AbsoluteSize
		local c, cs = clip.AbsolutePosition, clip.AbsoluteSize
		if a.Y + as.Y < c.Y or a.Y > c.Y + cs.Y or a.X + as.X < c.X or a.X > c.X + cs.X then
			return false
		end
	end
	return true
end

-- Icons hold still (a ViewportFrame is only re-drawn when its model moves, so a still icon costs
-- nothing per frame). They spin once when you hover / press their button.
RunService.RenderStepped:Connect(function(dt)
	for _, info in ipairs(icons) do
		if info.spin > 0 then
			info.spin = math.max(0, info.spin - dt * 9)
			if onScreen(info.vp) then
				pose(info, (math.pi * 2 - info.spin) % (math.pi * 2))
			elseif info.spin <= 0 then
				pose(info, 0)
			end
		end
	end
end)

-- Meshes download after the icons are built; re-add them so the ViewportFrames draw them.
task.spawn(function()
	local f = ReplicatedStorage:WaitForChild("UIIcons", 10)
	if f then
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(f:GetChildren())
		end)
	end
	for _, info in ipairs(icons) do
		local p = info.model.Parent
		info.model.Parent = nil
		info.model.Parent = p
	end
end)

-- A chunky 3D-looking button: glossy face sitting on a darker "lip" that it presses down into.
-- opts: Text, Color, Size, Position, AnchorPoint, Parent, LayoutOrder, ZIndex, Radius,
--       Icon (emoji above the text) or Icon3D (UIIcons name / Model, above the text; IconYaw),
--       TextStroke, StrokeThickness
function UIKit.button(opts)
	local color = opts.Color or Color3.fromRGB(80, 200, 90)
	local radius = opts.Radius or 16
	local z = opts.ZIndex or 1
	local LIP = 5
	local b = make("TextButton", {
		Parent = opts.Parent,
		Size = opts.Size or UDim2.fromOffset(140, 52),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LayoutOrder = opts.LayoutOrder or 0,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = z,
	})
	local lip = make("Frame", { Parent = b, Name = "Lip", BackgroundColor3 = UIKit.darker(color, 0.35), Position = UDim2.fromOffset(0, LIP), Size = UDim2.new(1, 0, 1, -LIP), ZIndex = z }, { UIKit.corner(radius), UIKit.stroke(opts.StrokeThickness or 3.5) })
	local face = make("Frame", { Parent = b, Name = "Face", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 1, -LIP), ZIndex = z + 1 }, { UIKit.corner(radius), UIKit.stroke(opts.StrokeThickness or 3.5) })
	local grad = UIKit.gloss(color)
	grad.Parent = face
	-- soft shine on the top half and a thin highlight line
	make("Frame", { Parent = face, Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, Position = UDim2.new(0.06, 0, 0.07, 0), Size = UDim2.new(0.88, 0, 0.3, 0), ZIndex = z + 1 }, { UIKit.corner(radius - 4) })
	local text, iconApi
	if opts.Icon3D and not iconTemplate(opts.Icon3D) then
		opts.Icon3D = nil -- 3D icon missing: fall back to the emoji
	end
	if (opts.Icon3D or opts.Icon) and opts.IconSide then
		-- wide button: big icon on the left, text on the right
		local iconBox = make("Frame", { Parent = face, Name = "IconBox", BackgroundTransparency = 1, Position = UDim2.fromScale(0.0, -0.25), Size = UDim2.fromScale(0.4, 1.4), ZIndex = z + 2 })
		if opts.Icon3D then
			local _, api = UIKit.icon3D(iconBox, opts.Icon3D, { ZIndex = z + 2, Yaw = opts.IconYaw, Zoom = opts.IconZoom })
			iconApi = api
		else
			UIKit.label({ Parent = iconBox, Name = "Icon", Size = UDim2.fromScale(1, 1), Text = opts.Icon, ZIndex = z + 2 })
		end
		text = UIKit.label({ Parent = face, Name = "Label", Position = UDim2.fromScale(0.38, 0.16), Size = UDim2.fromScale(0.58, 0.68), Text = opts.Text or "", ZIndex = z + 3, StrokeThickness = opts.TextStroke })
	elseif opts.Icon3D or opts.Icon then
		-- (icon-only buttons, like the settings gear: the icon fills the face)
		local iconOnly = (opts.Text or "") == ""
		local iconBox = make("Frame", { Parent = face, Name = "IconBox", BackgroundTransparency = 1, Position = iconOnly and UDim2.fromScale(0.08, 0.06) or UDim2.fromScale(0.08, -0.02), Size = iconOnly and UDim2.fromScale(0.84, 0.84) or UDim2.fromScale(0.84, 0.68), ZIndex = z + 2 })
		if opts.Icon3D then
			local _, api = UIKit.icon3D(iconBox, opts.Icon3D, { ZIndex = z + 2, Yaw = opts.IconYaw, Zoom = opts.IconZoom })
			iconApi = api
		else
			UIKit.label({ Parent = iconBox, Name = "Icon", Size = UDim2.fromScale(1, 1), Text = opts.Icon, ZIndex = z + 2 })
		end
		text = UIKit.label({ Parent = face, Name = "Label", Position = UDim2.fromScale(0.04, 0.66), Size = UDim2.fromScale(0.92, 0.28), Text = opts.Text or "", ZIndex = z + 3 })
	else
		text = UIKit.label({ Parent = face, Name = "Label", Position = UDim2.fromScale(0.06, 0.14), Size = UDim2.fromScale(0.88, 0.72), Text = opts.Text or "", ZIndex = z + 3, StrokeThickness = opts.TextStroke })
	end
	local hoverScale = make("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		spr.target(hoverScale, 0.5, 5, { Scale = 1.06 })
		if iconApi then
			iconApi.spin()
		end
	end)
	b.MouseLeave:Connect(function()
		spr.target(hoverScale, 0.6, 5, { Scale = 1 })
	end)
	-- press: the face sinks onto its lip
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			face.Position = UDim2.fromOffset(0, LIP - 1)
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			face.Position = UDim2.new()
		end
	end)
	b.Activated:Connect(function()
		UIKit.sound("Click", 0.4)
		spr.stop(hoverScale)
		hoverScale.Scale = 0.88
		spr.target(hoverScale, 0.35, 5, { Scale = 1 }) -- squish then spring back
		if iconApi then
			iconApi.spin()
		end
	end)
	local api = { Instance = b, Label = text, Face = face }
	-- swap the 3D icon (e.g. the LAUNCH button shows your equipped rocket)
	function api.setIcon3D(source, yaw)
		local box = face:FindFirstChild("IconBox")
		if box then
			box:ClearAllChildren()
			local _, a = UIKit.icon3D(box, source, { ZIndex = z + 2, Yaw = yaw, Zoom = opts.IconZoom })
			iconApi = a
		end
	end
	function api.setColor(c)
		grad:Destroy()
		grad = UIKit.gloss(c)
		grad.Parent = face
		lip.BackgroundColor3 = UIKit.darker(c, 0.35)
	end
	function api.setText(t)
		text.Text = t
	end
	return api
end

-- Small rounded label with a colored background (prices, tags, "EQUIPPED"...).
function UIKit.pill(parent, props)
	local p = make("Frame", { Parent = parent, Name = props.Name or "Pill", AnchorPoint = props.AnchorPoint or Vector2.zero, Position = props.Position or UDim2.new(), Size = props.Size or UDim2.fromOffset(90, 26), BackgroundColor3 = props.Color or Color3.fromRGB(80, 200, 90), ZIndex = props.ZIndex or 12 }, { UIKit.corner(40), UIKit.stroke(2.5) })
	local l = UIKit.label({ Parent = p, Name = "Text", Position = UDim2.fromScale(0.06, 0.1), Size = UDim2.fromScale(0.88, 0.8), Text = props.Text or "", ZIndex = (props.ZIndex or 12) + 1, StrokeThickness = 2 })
	return p, l
end

-- A rounded progress bar. Returns frame, set(fraction, text?)
function UIKit.bar(parent, props)
	local back = make("Frame", { Parent = parent, Name = props.Name or "Bar", Position = props.Position or UDim2.new(), Size = props.Size or UDim2.new(1, 0, 0, 16), BackgroundColor3 = Color3.fromRGB(225, 228, 240), ZIndex = props.ZIndex or 12 }, { UIKit.corner(40), UIKit.stroke(2, Color3.fromRGB(170, 175, 200)) })
	local fill = make("Frame", { Parent = back, Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = (props.ZIndex or 12) + 1 }, { UIKit.corner(40), UIKit.gloss(props.Color or Color3.fromRGB(90, 180, 255)) })
	local l = props.ShowText and UIKit.label({ Parent = back, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = (props.ZIndex or 12) + 2, StrokeThickness = 2 }) or nil
	return back, function(fraction, text)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		fill.Visible = fraction > 0.005
		if l and text then
			l.Text = text
		end
	end
end

-- A white card for grids / lists with an optional colored top band.
function UIKit.card(parent, props)
	local c = make("Frame", { Parent = parent, Name = props.Name or "Card", LayoutOrder = props.LayoutOrder or 0, Size = props.Size or UDim2.fromOffset(180, 220), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = props.ZIndex or 11 }, { UIKit.corner(20), UIKit.stroke(3, props.Border or Color3.fromRGB(190, 200, 225)) })
	make("UIGradient", { Parent = c, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), props.Tint or Color3.fromRGB(232, 238, 252)) })
	return c
end

-- Windows -----------------------------------------------------------------------------
local windows = {}
UIKit.windows = windows
local windowTitles = {} -- [window] = its title label
local windowIcons = {} -- [window] = function(source) that swaps its ribbon icon

-- Patterns (uploaded images, assets/ui/*.png in the repo): tiled on window panels / headers.
UIKit.PATTERN = {
	dots = "rbxassetid://104522712949109",
	stripes = "rbxassetid://115102900411200",
	rays = "rbxassetid://124716479109747",
	glow = "rbxassetid://83385000925606",
}

-- A tiled pattern over a rounded frame (UICorner on the image clips it to the same shape).
function UIKit.pattern(parent, name, props)
	props = props or {}
	return make("ImageLabel", {
		Parent = parent,
		Name = "Pattern",
		BackgroundTransparency = 1,
		Image = UIKit.PATTERN[name],
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(props.Tile or 48, props.Tile or 48),
		ImageColor3 = props.Color or Color3.new(1, 1, 1),
		ImageTransparency = props.Transparency or 0.6,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		ZIndex = props.ZIndex or (parent.ZIndex or 1),
	}, { UIKit.corner(props.Radius or 28) })
end

-- A big bright window: patterned panel in the window's color, a glossy title ribbon sticking out
-- above the top edge with the 3D icon breaking out of it, a round red X on the corner, and a
-- scrolling list. Returns window, list.   UIKit.window(title, color, size, icon3D)
function UIKit.window(title, color, size, icon)
	local w = make("Frame", {
		Parent = UIKit.gui(),
		Name = "Window_" .. title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 14),
		Size = size or UDim2.fromOffset(620, 450),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
	}, { make("UIScale", { Name = "OpenScale" }) })
	-- drop shadow, then the panel (siblings, so the shadow stays behind)
	make("Frame", { Parent = w, Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromScale(1, 1), ZIndex = 9 }, { UIKit.corner(30) })
	local panel = make("Frame", { Parent = w, Name = "Panel", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 10 }, { UIKit.corner(30), UIKit.stroke(5) })
	make("UIGradient", { Parent = panel, Rotation = 90, Color = ColorSequence.new(UIKit.lighter(color, 0.72), UIKit.lighter(color, 0.5)) })
	UIKit.pattern(panel, "dots", { Tile = 44, Transparency = 0.55, ZIndex = 10, Radius = 30 })
	-- colored band along the top, with stripes
	local band = make("Frame", { Parent = panel, Name = "Band", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 58), ZIndex = 10 }, { UIKit.corner(30), UIKit.gloss(color) })
	make("Frame", { Parent = band, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 30), ZIndex = 10 }, { make("UIGradient", { Rotation = 90, Color = ColorSequence.new(color, UIKit.darker(color, 0.15)) }) })
	UIKit.pattern(band, "stripes", { Tile = 40, Transparency = 0.86, ZIndex = 10, Radius = 30 })
	make("Frame", { Parent = band, BackgroundColor3 = UIKit.darker(color, 0.4), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 4), ZIndex = 10 })

	-- the title ribbon: two darker tails behind a glossy banner, centered over the top edge
	local TextService = game:GetService("TextService")
	local ribbon = make("Frame", { Parent = w, Name = "Ribbon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(300, 64), BackgroundTransparency = 1, ZIndex = 13 })
	for _, side in ipairs({ -1, 1 }) do
		make("Frame", { Parent = ribbon, Name = "Tail", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(side < 0 and 0 or 1, side * 6, 0.5, 10), Size = UDim2.fromOffset(60, 46), Rotation = side * -8, BackgroundColor3 = UIKit.darker(color, 0.35), ZIndex = 13 }, { UIKit.corner(12), UIKit.stroke(4) })
	end
	local banner = make("Frame", { Parent = ribbon, Name = "Banner", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 14 }, { UIKit.corner(22), UIKit.stroke(4.5), UIKit.gloss(UIKit.lighter(color, 0.12)) })
	make("Frame", { Parent = banner, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.68, Position = UDim2.new(0.05, 0, 0.1, 0), Size = UDim2.new(0.9, 0, 0.32, 0), ZIndex = 14 }, { UIKit.corner(10) })
	local titleLabel = UIKit.label({ Parent = banner, Name = "Title", Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 1, -16), Text = title, ZIndex = 15, StrokeThickness = 3.5 })
	windowTitles[w] = titleLabel
	local hasIcon = icon ~= nil
	local function fitRibbon()
		local t = TextService:GetTextSize(titleLabel.Text, 40, UIKit.FONT, Vector2.new(2000, 100))
		local width = math.clamp(t.X + (hasIcon and 112 or 60), 220, math.max(240, w.Size.X.Offset - 150))
		ribbon.Size = UDim2.fromOffset(width, 64)
		titleLabel.Position = UDim2.fromOffset(hasIcon and 78 or 18, 8)
		titleLabel.Size = UDim2.new(1, hasIcon and -96 or -36, 1, -16)
	end
	titleLabel:GetPropertyChangedSignal("Text"):Connect(fitRibbon)
	local holder = nil
	windowIcons[w] = function(source)
		if holder then
			holder:Destroy()
			holder = nil
		end
		hasIcon = source ~= nil
		if source then
			holder = make("Frame", { Parent = ribbon, Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 26, 0.5, -4), Size = UDim2.fromOffset(90, 90), BackgroundTransparency = 1, ZIndex = 16 })
			UIKit.icon3D(holder, source, { ZIndex = 16 })
		end
		fitRibbon()
	end
	windowIcons[w](icon)
	local close = UIKit.button({ Parent = w, Text = "X", Color = Color3.fromRGB(240, 70, 70), Size = UDim2.fromOffset(58, 58), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -16, 0, 16), ZIndex = 17, Radius = 29 })
	close.Instance.Name = "Close"
	close.Instance.Activated:Connect(function()
		UIKit.closeAll()
	end)
	local list = make("ScrollingFrame", {
		Parent = w,
		Name = "List",
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UIKit.darker(color, 0.2),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
	}, { make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }), make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }) })
	table.insert(windows, w)
	return w, list
end

function UIKit.windowTitle(w)
	return windowTitles[w]
end

-- Swap a window's ribbon icon (UIIcons name / Model / nil), e.g. the egg you're looking at.
function UIKit.setWindowIcon(w, source)
	windowIcons[w](source)
end

-- Pill tabs under a window's top band. tabs = { { key, text, color } }. Each tab gets its own
-- content frame inside the list (auto height); only the selected tab's frame shows.
-- api.frames[key], api.select(key), api.badge(key, on), api.current, api.changed (callback)
function UIKit.tabs(w, list, tabs)
	local bar = make("Frame", { Parent = w, Name = "Tabs", Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 0, 54), BackgroundTransparency = 1, ZIndex = 12 }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	list.Position = UDim2.fromOffset(16, 120)
	list.Size = UDim2.new(1, -32, 1, -134)
	local api = { frames = {}, buttons = {}, badges = {}, current = nil, changed = nil }
	local OFF = Color3.fromRGB(175, 180, 200)
	for i, t in ipairs(tabs) do
		local b = UIKit.button({ Parent = bar, LayoutOrder = i, Text = t.text, Color = OFF, Size = UDim2.fromOffset(t.width or 210, 50), Radius = 25, ZIndex = 13 })
		b.Instance.Name = "Tab_" .. t.key
		api.buttons[t.key] = b
		api.badges[t.key] = UIKit.badge(b.Instance)
		local frame = make("Frame", { Parent = list, Name = "Tab_" .. t.key, LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, ZIndex = 11 }, {
			make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		})
		api.frames[t.key] = frame
		b.Instance.Activated:Connect(function()
			api.select(t.key)
		end)
	end
	function api.select(key)
		api.current = key
		for _, t in ipairs(tabs) do
			local on = t.key == key
			api.frames[t.key].Visible = on
			api.buttons[t.key].setColor(on and t.color or OFF)
		end
		list.CanvasPosition = Vector2.zero
		if api.changed then
			api.changed(key)
		end
	end
	function api.badge(key, on)
		local b = api.badges[key]
		if on and not b.Visible then
			bounce(b)
		end
		b.Visible = on
	end
	api.select(tabs[1].key)
	return api
end

-- A reward chip: white pill with a 3D icon (Coin by default) and an amount.
-- Returns frame, setText(text)
function UIKit.rewardChip(parent, props)
	local z = props.ZIndex or 12
	local chip = make("Frame", { Parent = parent, Name = "Reward", AnchorPoint = props.AnchorPoint or Vector2.zero, Position = props.Position or UDim2.new(), Size = props.Size or UDim2.fromOffset(150, 40), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z }, { UIKit.corner(20), UIKit.stroke(3, props.Border or Color3.fromRGB(70, 170, 80)) })
	make("UIGradient", { Parent = chip, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 250, 225)) })
	local h = (props.Size and props.Size.Y.Offset > 0) and props.Size.Y.Offset or 40
	local iconBox = make("Frame", { Parent = chip, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -10, 0.5, 0), Size = UDim2.fromOffset(h * 1.45, h * 1.45), BackgroundTransparency = 1, ZIndex = z + 1 })
	if iconTemplate(props.Icon or "Coin") then
		UIKit.icon3D(iconBox, props.Icon or "Coin", { ZIndex = z + 1 })
	else
		UIKit.label({ Parent = iconBox, Size = UDim2.fromScale(1, 1), Text = "💰", ZIndex = z + 1, StrokeThickness = 0 })
	end
	local text = UIKit.label({ Parent = chip, Name = "Amount", Position = UDim2.new(0.34, 0, 0.12, 0), Size = UDim2.new(0.62, 0, 0.76, 0), Text = props.Text or "", TextColor3 = Color3.fromRGB(50, 160, 60), StrokeThickness = 0, ZIndex = z + 1 })
	return chip, function(t)
		text.Text = t
	end
end

-- A rotated stamp ("CLAIMED", "DONE") over a card.
function UIKit.stamp(parent, text, color, props)
	props = props or {}
	color = color or Color3.fromRGB(70, 180, 80)
	local z = props.ZIndex or 20
	local st = make("Frame", { Parent = parent, Name = "Stamp", AnchorPoint = Vector2.new(0.5, 0.5), Position = props.Position or UDim2.fromScale(0.5, 0.45), Size = props.Size or UDim2.fromOffset(170, 52), Rotation = props.Rotation or -12, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.15, Visible = false, ZIndex = z }, { UIKit.corner(12), make("UIStroke", { Thickness = 5, Color = color }) })
	UIKit.label({ Parent = st, Position = UDim2.fromScale(0.06, 0.1), Size = UDim2.fromScale(0.88, 0.8), Text = text, TextColor3 = color, StrokeThickness = 0, ZIndex = z + 1 })
	return st
end

-- Sun rays behind something special (today's reward, a ready gift); they turn slowly.
local spinningRays = {}
function UIKit.rays(parent, props)
	props = props or {}
	local r = make("ImageLabel", { Parent = parent, Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = props.Position or UDim2.fromScale(0.5, 0.5), Size = props.Size or UDim2.fromScale(1.3, 1.3), BackgroundTransparency = 1, Image = UIKit.PATTERN.rays, ImageColor3 = props.Color or Color3.new(1, 1, 1), ImageTransparency = props.Transparency or 0.3, ZIndex = props.ZIndex or 12 }, { make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	table.insert(spinningRays, r)
	r.Destroying:Connect(function()
		local i = table.find(spinningRays, r)
		if i then
			table.remove(spinningRays, i)
		end
	end)
	return r
end

-- "Claimable" look on a UIKit.button: green, gently pulsing, with a shine sweeping across.
local claimables = {}
function UIKit.claimable(btn, on)
	local face = btn.Face
	local info = claimables[btn]
	if not info then
		local pulse = make("UIScale", { Parent = face, Name = "Pulse" })
		face.ClipsDescendants = true
		local shine = make("Frame", { Parent = face, Name = "ShineSweep", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(0.28, 0, 1.4, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.5), Rotation = 18, Visible = false, ZIndex = face.ZIndex + 1 }, {
			make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		info = { pulse = pulse, shine = shine, on = false, phase = math.random() * 3 }
		claimables[btn] = info
		btn.Instance.Destroying:Connect(function()
			claimables[btn] = nil
		end)
	end
	info.on = on
	info.shine.Visible = on
	if on then
		btn.setColor(Color3.fromRGB(70, 205, 85))
	else
		info.pulse.Scale = 1
	end
end
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, r in ipairs(spinningRays) do
		if r.Visible then
			r.Rotation = (t * 24) % 360
		end
	end
	for btn, info in pairs(claimables) do
		if info.on and btn.Instance.Parent and btn.Instance.AbsoluteSize.X > 0 then
			local p = (t + info.phase) % 2.2
			info.pulse.Scale = 1 + math.sin((t + info.phase) * 5) * 0.035
			info.shine.Position = UDim2.fromScale(-0.3 + (p / 0.9) * 1.6, 0.5)
		end
	end
end)

-- the event pills at the top hide while a window is open (the title ribbon sits there)
local function topBar(show)
	local bar = UIKit.gui():FindFirstChild("EventBar")
	if bar then
		bar.Visible = show
	end
end

function UIKit.closeAll()
	for _, w in ipairs(windows) do
		w.Visible = false
	end
	topBar(true)
end

function UIKit.toggle(w)
	local open = not w.Visible
	UIKit.closeAll()
	w.Visible = open
	topBar(not open)
	if open then
		UIKit.sound("Pop", 0.5, 1.05)
		local s = w:FindFirstChild("OpenScale") or w:FindFirstChildOfClass("UIScale")
		local fit = 1
		local view = workspace.CurrentCamera.ViewportSize
		local size = w.Size
		local px = Vector2.new(size.X.Offset + size.X.Scale * view.X, size.Y.Offset + size.Y.Scale * view.Y)
		if px.X > 10 and view.X > 300 and view.Y > 200 then -- (right after joining the screen size can still read 1x1)
			fit = math.clamp(math.min((view.X - 24) / px.X, (view.Y - 110) / px.Y), 0.45, 1.15)
		end
		s.Scale = 0.6 * fit
		spr.target(s, 0.55, 3.5, { Scale = fit }) -- windows spring open
	end
end

-- A white rounded row card for lists.
function UIKit.row(list, order, height)
	local r = make("Frame", { Parent = list, LayoutOrder = order, Size = UDim2.new(1, -12, 0, height), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, { UIKit.corner(18), UIKit.stroke(3, Color3.fromRGB(190, 200, 225)) })
	make("UIGradient", { Parent = r, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(236, 240, 252)) })
	return r
end

-- Shared bars (created on first use so scripts can load in any order) -------------------
local bars = {}
-- HUD pieces shrink on small (phone) screens: add UIKit.hudScale(frame) to any HUD container.
-- (Only size changes, so anchors / positions keep them in their corners.)
local hudScales = {}
local function hudFactor()
	local v = workspace.CurrentCamera.ViewportSize
	if v.X < 300 or v.Y < 200 then
		return 1 -- not measured yet right after joining
	end
	return math.clamp(math.min(v.Y / 640, v.X / 1000), 0.55, 1)
end
function UIKit.hudScale(frame)
	local s = frame:FindFirstChild("HudScale") or make("UIScale", { Name = "HudScale", Parent = frame })
	s.Scale = hudFactor()
	table.insert(hudScales, s)
	return s
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	local f = hudFactor()
	for _, s in ipairs(hudScales) do
		s.Scale = f
	end
end)

function UIKit.bottomBar()
	if not bars.bottom then
		bars.bottom = make("Frame", { Parent = UIKit.gui(), Name = "BottomBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(820, 110), BackgroundTransparency = 1 }, {
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		UIKit.hudScale(bars.bottom)
	end
	return bars.bottom
end

function UIKit.sideBar()
	if not bars.side then
		-- under the money pills, buttons in a 2-wide grid so it never runs off the bottom
		bars.side = make("Frame", { Parent = UIKit.gui(), Name = "SideBar", Position = UDim2.fromOffset(14, 200), Size = UDim2.fromOffset(196, 220), BackgroundTransparency = 1 }, {
			make("UIGridLayout", { CellSize = UDim2.fromOffset(92, 98), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		UIKit.hudScale(bars.side)
	end
	return bars.side
end

-- A little red "!" bubble on a button (for things you can claim).
function UIKit.badge(button)
	local b = make("TextLabel", { Parent = button, Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Color3.fromRGB(255, 60, 60), Font = UIKit.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "!", Visible = false, ZIndex = 20 }, { UIKit.corner(14), UIKit.stroke(2.5) })
	-- while the badge shows, its button gives a little wiggle every few seconds
	task.spawn(function()
		while button.Parent do
			task.wait(3.5 + math.random() * 1.5)
			if b.Visible and UIKit.shown(button) and not player:GetAttribute("Flying") then
				for _, r in ipairs({ -8, 7, -5, 3, 0 }) do
					TweenService:Create(button, TweenInfo.new(0.07, Enum.EasingStyle.Sine), { Rotation = r }):Play()
					task.wait(0.07)
				end
			end
		end
	end)
	return b
end

-- Toasts ------------------------------------------------------------------------------
local toastHolder
local hookedBar = nil
-- Lobby: near the top, under the event pills (however many rows they take right now).
-- Flying: at the bottom, above the progress bar (the flight HUD uses the top of the screen).
local function placeToasts()
	if not toastHolder then
		return
	end
	local flying = player:GetAttribute("Flying") == true
	local top = 70
	local bar = UIKit.gui():FindFirstChild("EventBar")
	local layout = bar and bar:FindFirstChildOfClass("UIListLayout")
	if layout then
		if hookedBar ~= bar then -- follow the pills as they come and go
			hookedBar = bar
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(placeToasts)
		end
		if layout.AbsoluteContentSize.Y > 0 then
			top = math.max(top, UIKit.toGui(bar.AbsolutePosition).Y + layout.AbsoluteContentSize.Y + 8)
		end
	end
	toastHolder.AnchorPoint = Vector2.new(0.5, flying and 1 or 0)
	toastHolder.Position = flying and UDim2.new(0.5, 0, 1, -140) or UDim2.new(0.5, 0, 0, top)
	toastHolder:FindFirstChildOfClass("UIListLayout").VerticalAlignment = flying and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
end
player:GetAttributeChangedSignal("Flying"):Connect(placeToasts)

-- Toasts are dark pills with colored text; at most 3 show at once, the rest wait their turn.
local MAX_TOASTS = 3
local toastQueue = {}
local toastsShown = 0
local function showToast(text, color)
	color = color or Color3.new(1, 1, 1)
	toastsShown += 1
	local width = math.min(game:GetService("TextService"):GetTextSize(text, 27, UIKit.FONT, Vector2.new(2000, 100)).X + 48, 640)
	local pill = make("Frame", { Parent = toastHolder, Name = "Toast", Size = UDim2.fromOffset(width, 42), BackgroundColor3 = Color3.fromRGB(28, 26, 48), BackgroundTransparency = 0.2, ZIndex = 30 }, { UIKit.corner(21), UIKit.stroke(3, color) })
	local l = UIKit.label({ Parent = pill, Position = UDim2.fromOffset(18, 5), Size = UDim2.new(1, -36, 1, -10), Text = text, TextColor3 = color, ZIndex = 31, StrokeThickness = 2.5 })
	bounce(pill)
	task.delay(3, function()
		local fade = TweenInfo.new(0.35)
		TweenService:Create(pill, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(l, fade, { TextTransparency = 1 }):Play()
		for _, st in ipairs({ pill:FindFirstChildOfClass("UIStroke"), l:FindFirstChildOfClass("UIStroke") }) do
			TweenService:Create(st, fade, { Transparency = 1 }):Play()
		end
		task.wait(0.4)
		if pill.Parent then
			pill:Destroy()
			toastsShown -= 1
		end
		local nextToast = table.remove(toastQueue, 1)
		if nextToast then
			showToast(nextToast[1], nextToast[2])
		end
	end)
end

function UIKit.toast(text, color)
	if not toastHolder then
		toastHolder = make("Frame", { Parent = UIKit.gui(), Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(660, 160), BackgroundTransparency = 1, ZIndex = 30 }, {
			make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end
	placeToasts()
	if toastsShown >= MAX_TOASTS then
		table.insert(toastQueue, { text, color })
		return
	end
	showToast(text, color)
end

-- Money display hold: while true the money counter waits (e.g. a Lucky Spin roll that was
-- already paid); releaseMoney() lets it catch up. RocketClient sets UIKit.onMoneyRelease.
UIKit.moneyHold = false
UIKit.onMoneyRelease = nil
function UIKit.releaseMoney()
	UIKit.moneyHold = false
	if UIKit.onMoneyRelease then
		UIKit.onMoneyRelease()
	end
end

-- True while something important is on screen: flying, an open window, the landing report.
function UIKit.busy()
	if player:GetAttribute("Flying") then
		return true
	end
	for _, w in ipairs(windows) do
		if w.Visible then
			return true
		end
	end
	local g = UIKit.gui()
	for _, name in ipairs({ "FlightReport", "HatchShow" }) do -- (full-screen moments)
		local f = g:FindFirstChild(name)
		if f and f.Visible then
			return true
		end
	end
	return false
end

-- Run fn once nothing important has been on screen for `quiet` seconds (hints, "quest done"...).
function UIKit.whenFree(fn, quiet)
	task.spawn(function()
		local since = os.clock()
		while os.clock() - since < (quiet or 1.5) do
			if UIKit.busy() then
				since = os.clock()
			end
			task.wait(0.25)
		end
		fn()
	end)
end

-- True if a GuiObject and every GuiObject above it is visible.
function UIKit.shown(g)
	while g and g:IsA("GuiObject") do
		if not g.Visible then
			return false
		end
		g = g.Parent
	end
	return true
end

-- Clear all toasts at once (e.g. flight hints when you land).
function UIKit.clearToasts()
	if toastHolder then
		table.clear(toastQueue)
		for _, c in ipairs(toastHolder:GetChildren()) do
			if c.Name == "Toast" then
				c:Destroy()
				toastsShown -= 1
			end
		end
	end
end

-- Big moment: white flash, confetti, a bouncing title and subtitle (rebirth, stage unlock...).
function UIKit.celebrate(title, sub, color, subColor)
	local gui = UIKit.gui()
	local flash = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 250, 240), BackgroundTransparency = 0.1, ZIndex = 70 })
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(flash, 1)
	local t = UIKit.label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(700, 100), Text = title, TextColor3 = color or Color3.fromRGB(255, 200, 50), StrokeThickness = 5, ZIndex = 72 })
	local st = UIKit.label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 44), Text = sub or "", TextColor3 = subColor or Color3.fromRGB(150, 255, 150), StrokeThickness = 3, ZIndex = 72 })
	bounce(t)
	UIKit.sound("Win", 0.9, 1.1)
	local colors = { Color3.fromRGB(255, 190, 40), Color3.fromRGB(165, 105, 245), Color3.fromRGB(255, 120, 190), Color3.fromRGB(90, 200, 255), Color3.fromRGB(130, 230, 110) }
	for i = 1, 60 do
		local c = make("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(math.random(), -0.05), Size = UDim2.fromOffset(math.random(10, 18), math.random(6, 10)), BackgroundColor3 = colors[i % #colors + 1], Rotation = math.random(0, 360), BorderSizePixel = 0, ZIndex = 71 })
		local dur = 1.6 + math.random() * 1.4
		TweenService:Create(c, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(c.Position.X.Scale + (math.random() - 0.5) * 0.3, 1.1), Rotation = c.Rotation + math.random(-540, 540) }):Play()
		game:GetService("Debris"):AddItem(c, dur + 0.1)
	end
	task.delay(2.6, function()
		for _, l in ipairs({ t, st }) do
			TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			local s2 = l:FindFirstChildOfClass("UIStroke")
			if s2 then
				TweenService:Create(s2, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.6)
		t:Destroy()
		st:Destroy()
	end)
end

-- A cartoon coin made of frames (no images): gold disc, lighter face, a star. size in pixels.
function UIKit.coin(props)
	props = props or {}
	local size = props.Size or 40
	local z = props.ZIndex or 30
	local c = make("Frame", { Parent = props.Parent, Name = "Coin", AnchorPoint = Vector2.new(0.5, 0.5), Position = props.Position or UDim2.new(), Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z }, {
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		make("UIStroke", { Thickness = math.max(1.5, size / 16), Color = UIKit.INK }),
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 235, 120), Color3.fromRGB(240, 150, 20)) }),
	})
	local face = make("Frame", { Parent = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.68, 0.68), BackgroundColor3 = Color3.fromRGB(255, 215, 70), ZIndex = z }, {
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		make("UIStroke", { Thickness = math.max(1, size / 30), Color = Color3.fromRGB(205, 120, 10) }),
	})
	make("TextLabel", { Parent = face, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = UIKit.FONT, Text = "★", TextScaled = true, TextColor3 = Color3.fromRGB(235, 140, 15), ZIndex = z })
	return c
end

-- Coins burst out from a screen point and fly into the money counter (a HUD frame named
-- "MoneyPill"), each landing with a rising little "ding". Used for every money reward.
function UIKit.coinBurst(count, from)
	local gui = UIKit.gui()
	local pill = gui:FindFirstChild("MoneyPill")
	local view = workspace.CurrentCamera.ViewportSize
	from = from and UIKit.toGui(from) or Vector2.new(view.X / 2, view.Y * 0.45) -- (from: an AbsolutePosition)
	local target = pill and pill.Visible and UIKit.toGui(pill.AbsolutePosition + Vector2.new(30, pill.AbsoluteSize.Y / 2)) or Vector2.new(60, 90)
	count = math.clamp(count or 10, 1, 24)
	for i = 1, count do
		local c = UIKit.coin({ Parent = gui, Size = math.random(30, 44), Position = UDim2.fromOffset(from.X, from.Y), ZIndex = 60 })
		local a = math.random() * math.pi * 2
		local r = math.random(50, 170)
		local mid = from + Vector2.new(math.cos(a) * r, math.sin(a) * r * 0.7 - 30)
		TweenService:Create(c, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(mid.X, mid.Y), Rotation = math.random(-40, 40) }):Play()
		task.delay(0.32 + i * 0.035, function()
			local t = TweenService:Create(c, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(22, 22) })
			t:Play()
			t.Completed:Wait()
			c:Destroy()
			UIKit.sound("Coin", 0.22, 0.95 + i * 0.035)
			local amount = pill and pill:FindFirstChild("Amount")
			if amount then
				bounce(amount)
			end
		end)
	end
end

function UIKit.result(ok, msg)
	UIKit.toast(msg, ok and Color3.fromRGB(130, 255, 130) or Color3.fromRGB(255, 140, 140))
	if ok then
		UIKit.sound("Coin", 0.5, 1.2)
	end
end

return UIKit
