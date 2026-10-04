-- Shared "glossy bubbly" UI pieces: chunky outlined buttons with gradients and bounce,
-- bright windows, toasts, and sounds. Every client script uses the same ScreenGui ("RocketHUD").
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

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
local soundCache = {}
function UIKit.sound(name, volume, pitch)
	local id = Config.Sounds[name]
	if not id then
		return
	end
	local s = soundCache[name]
	if not s then
		s = Instance.new("Sound")
		s.SoundId = id
		s.Parent = SoundService
		soundCache[name] = s
	end
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(s)
	return s
end

-- Buttons -----------------------------------------------------------------------------
local function bounce(target)
	local scale = target:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = target })
	scale.Scale = 0.86
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
UIKit.bounce = bounce

-- A glossy chunky button. opts: Text, Color, Size, Position, AnchorPoint, Parent, LayoutOrder, Icon (emoji above text)
function UIKit.button(opts)
	local color = opts.Color or Color3.fromRGB(80, 200, 90)
	local b = make("TextButton", {
		Parent = opts.Parent,
		Size = opts.Size or UDim2.fromOffset(140, 52),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LayoutOrder = opts.LayoutOrder or 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		ZIndex = opts.ZIndex or 1,
	}, { UIKit.corner(opts.Radius or 16), UIKit.stroke(opts.StrokeThickness or 3.5) })
	local grad = UIKit.gloss(color)
	grad.Parent = b
	-- shine strip on the top half
	make("Frame", { Parent = b, Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, Position = UDim2.new(0.08, 0, 0.08, 0), Size = UDim2.new(0.84, 0, 0.28, 0), ZIndex = b.ZIndex }, { UIKit.corner(10) })
	local text
	if opts.Icon then
		UIKit.label({ Parent = b, Name = "Icon", Position = UDim2.fromScale(0.1, 0.04), Size = UDim2.fromScale(0.8, 0.6), Text = opts.Icon, ZIndex = b.ZIndex + 1 })
		text = UIKit.label({ Parent = b, Name = "Label", Position = UDim2.fromScale(0.05, 0.64), Size = UDim2.fromScale(0.9, 0.3), Text = opts.Text or "", ZIndex = b.ZIndex + 1 })
	else
		text = UIKit.label({ Parent = b, Name = "Label", Position = UDim2.fromScale(0.06, 0.14), Size = UDim2.fromScale(0.88, 0.72), Text = opts.Text or "", ZIndex = b.ZIndex + 1, StrokeThickness = opts.TextStroke })
	end
	local hoverScale = make("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(hoverScale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(hoverScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		UIKit.sound("Click", 0.4)
		hoverScale.Scale = 0.88
		TweenService:Create(hoverScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	local api = { Instance = b, Label = text }
	function api.setColor(c)
		grad:Destroy()
		grad = UIKit.gloss(c)
		grad.Parent = b
	end
	function api.setText(t)
		text.Text = t
	end
	return api
end

-- Windows -----------------------------------------------------------------------------
local windows = {}
UIKit.windows = windows

-- A bright window with a colored header, a red X, and a scrolling list. Returns window, list.
function UIKit.window(title, color, size)
	local w = make("Frame", {
		Parent = UIKit.gui(),
		Name = "Window_" .. title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = size or UDim2.fromOffset(600, 440),
		BackgroundColor3 = Color3.fromRGB(250, 250, 255),
		Visible = false,
		ZIndex = 10,
	}, { UIKit.corner(24), UIKit.stroke(5), make("UISizeConstraint", { MaxSize = Vector2.new(600, 460) }), make("UIScale", {}) })
	make("UIGradient", { Parent = w, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(225, 232, 250)) })
	local header = make("Frame", { Parent = w, Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, { UIKit.corner(24), UIKit.gloss(color) })
	-- square off the header's bottom corners
	make("Frame", { Parent = header, Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 11 }, { make("UIGradient", { Rotation = 90, Color = ColorSequence.new(color, UIKit.darker(color, 0.18)) }) })
	UIKit.label({ Parent = header, Position = UDim2.fromOffset(22, 8), Size = UDim2.new(1, -100, 1, -16), TextXAlignment = Enum.TextXAlignment.Left, Text = title, ZIndex = 12, StrokeThickness = 3 })
	local close = UIKit.button({ Parent = header, Text = "X", Color = Color3.fromRGB(240, 70, 70), Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), ZIndex = 13, Radius = 14 })
	close.Instance.Activated:Connect(function()
		UIKit.closeAll()
	end)
	local list = make("ScrollingFrame", {
		Parent = w,
		Name = "List",
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 1, -88),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UIKit.darker(color, 0.1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
	}, { make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }), make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }) })
	table.insert(windows, w)
	return w, list
end

function UIKit.closeAll()
	for _, w in ipairs(windows) do
		w.Visible = false
	end
end

function UIKit.toggle(w)
	local open = not w.Visible
	UIKit.closeAll()
	w.Visible = open
	if open then
		local s = w:FindFirstChildOfClass("UIScale")
		s.Scale = 0.6
		TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

-- A white rounded row card for lists.
function UIKit.row(list, order, height)
	return make("Frame", { Parent = list, LayoutOrder = order, Size = UDim2.new(1, -12, 0, height), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, { UIKit.corner(18), UIKit.stroke(3, Color3.fromRGB(190, 200, 225)) })
end

-- Shared bars (created on first use so scripts can load in any order) -------------------
local bars = {}
function UIKit.bottomBar()
	if not bars.bottom then
		bars.bottom = make("Frame", { Parent = UIKit.gui(), Name = "BottomBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(700, 110), BackgroundTransparency = 1 }, {
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end
	return bars.bottom
end

function UIKit.sideBar()
	if not bars.side then
		bars.side = make("Frame", { Parent = UIKit.gui(), Name = "SideBar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.58, 0), Size = UDim2.fromOffset(84, 300), BackgroundTransparency = 1 }, {
			make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end
	return bars.side
end

-- A little red "!" bubble on a button (for things you can claim).
function UIKit.badge(button)
	local b = make("TextLabel", { Parent = button, Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Color3.fromRGB(255, 60, 60), Font = UIKit.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "!", Visible = false, ZIndex = 20 }, { UIKit.corner(14), UIKit.stroke(2.5) })
	return b
end

-- Toasts ------------------------------------------------------------------------------
local toastHolder
function UIKit.toast(text, color)
	if not toastHolder then
		toastHolder = make("Frame", { Parent = UIKit.gui(), Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(620, 200), BackgroundTransparency = 1, ZIndex = 30 }, {
			make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end
	local l = UIKit.label({ Parent = toastHolder, Size = UDim2.fromOffset(600, 40), Text = text, TextColor3 = color or Color3.new(1, 1, 1), ZIndex = 31, StrokeThickness = 3 })
	bounce(l)
	task.delay(3, function()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		l:Destroy()
	end)
end

function UIKit.result(ok, msg)
	UIKit.toast(msg, ok and Color3.fromRGB(130, 255, 130) or Color3.fromRGB(255, 140, 140))
	if ok then
		UIKit.sound("Coin", 0.5, 1.2)
	end
end

return UIKit
