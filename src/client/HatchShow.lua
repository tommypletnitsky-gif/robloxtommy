-- The hatch show (Eggs v2): a real 3D scene, so the egg's orbiting props, particles, beams and the
-- pet's flames / sparkles all show (the old show drew models in 2D viewports, which can't).
--   HatchShow.play(egg, results, { petModel = fn(kind) -> Model, eggModel = fn(egg) -> Model,
--                                  isNew = fn(kind) -> bool, fast = bool, tier = number })
-- results: { kind, golden?, deleted? } (deleted = auto-deleted: shown, then marked). 1, 3 or 8 eggs
-- (8 stand in two rows, a bit smaller). fast = a short show (no wait for a tap).
-- The stage is built far away from the world (nothing else in view): a backdrop with spinning rays
-- in the egg's colour, 1 or 3 eggs that drop in, shake harder and harder (the orbiters speed up,
-- an Epic-or-better result makes the egg glow in its rarity colour first), crack into flying shell
-- pieces with a flash, and the pets spring out spinning with their effects + name / rarity /
-- multiplier. Click (or wait) to go back.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local EggLooks = require(script.Parent:WaitForChild("EggLooks"))
local PetFx = require(script.Parent:WaitForChild("PetFx"))

local HatchShow = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local STAGE = Vector3.new(-2400, 700, 0) -- far from everything
local RAYS = "rbxassetid://124716479109747"
local C = Color3.fromRGB

local function newPart(parent, t)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(t) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function prep(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	return m
end

-- screen pieces (their own ScreenGui above the HUD, which is hidden during the show)
local screen = Instance.new("ScreenGui")
screen.Name = "HatchGui"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 50
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Enabled = false
screen.Parent = player:WaitForChild("PlayerGui")
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BackgroundTransparency = 1
fade.ZIndex = 20
fade.Parent = screen
local click = Instance.new("TextButton")
click.Size = UDim2.fromScale(1, 1)
click.BackgroundTransparency = 1
click.Text = ""
click.ZIndex = 5
click.Parent = screen
local hint = UIKit.label({ Parent = screen, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.fromOffset(460, 32), Text = "Tap to continue", TextColor3 = C(235, 235, 245), ZIndex = 10, Visible = false })

local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- text size for this screen: full size on a monitor, about half on a phone in landscape (the
-- three captions would overlap otherwise)
local function textScale()
	return math.clamp(camera.ViewportSize.Y / 700, 0.55, 1)
end

-- name / rarity / multiplier under a pet (screen labels following its spot)
local function caption(pet, golden, tier, deleted, small)
	local k = textScale() * (small and 0.72 or 1)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Size = UDim2.fromOffset(300 * k, 86 * k)
	f.BackgroundTransparency = 1
	f.ZIndex = 8
	f.Parent = screen
	local color = Config.Rarities[pet.rarity].color
	UIKit.label({ Parent = f, Size = UDim2.fromScale(1, 0.465), Text = (golden and "⭐ Golden " or "") .. pet.name, ZIndex = 9, StrokeThickness = 3.5 * k })
	local r = UIKit.label({ Parent = f, Position = UDim2.fromScale(0, 0.465), Size = UDim2.fromScale(1, 0.326), Text = deleted and "🗑 AUTO-DELETED" or (string.upper(pet.rarity) .. "  •  " .. Config.multText(Config.petMult(pet.id, golden, tier)) .. " 💰"), TextColor3 = deleted and C(190, 190, 200) or pet.rarity == "Secret" and C(255, 255, 255) or color, ZIndex = 9, StrokeThickness = 3 * k })
	if pet.rarity == "Secret" and not deleted then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C(255, 90, 90)),
			ColorSequenceKeypoint.new(0.33, C(255, 230, 80)),
			ColorSequenceKeypoint.new(0.66, C(90, 220, 255)),
			ColorSequenceKeypoint.new(1, C(220, 110, 255)),
		})
		g.Parent = r
	end
	UIKit.bounce(f)
	return f
end

local running = false
function HatchShow.busy()
	return running
end

function HatchShow.play(egg, results, fns)
	running = true
	player:SetAttribute("HatchShow", true)
	local hud = UIKit.gui()
	local folder = Instance.new("Folder")
	folder.Name = "HatchStage"
	folder.Parent = workspace
	local n = #results
	local fast = fns.fast == true
	-- where each egg stands: one row (1-3) or two rows of 4 (8), and how far the camera is
	local spots, dist, aimY, scale = {}, 12.5, 1.8, 1
	if n > 3 then
		dist, aimY, scale = 25, 2.3, 0.7
		for i = 1, n do
			local col, row = (i - 1) % 4, (i - 1) // 4
			spots[i] = Vector3.new((col - 1.5) * 6.4, row == 0 and 4.6 or -1, row == 0 and -1.5 or 0)
		end
	else
		dist = n > 1 and 19 or 12.5
		for i = 1, n do
			spots[i] = Vector3.new((i - (n + 1) / 2) * 7.5, 0, 0)
		end
	end

	-- best rarity in this hatch (the tease + the sound)
	local best = "Common"
	for _, r in ipairs(results) do
		local rar = Config.Pets[r.kind].rarity
		if Config.Rarities[rar].order > Config.Rarities[best].order then
			best = rar
		end
	end
	local bestColor = best == "Secret" and C(255, 255, 255) or Config.Rarities[best].color
	local order = Config.Rarities[best].order

	-- fade to black, build the stage, swap the camera
	screen.Enabled = true
	hint.Visible = false
	local hk = textScale()
	hint.Size = UDim2.fromOffset(460 * hk, 32 * hk)
	hint.Position = UDim2.new(0.5, 0, 1, -14 - 12 * hk)
	fade.BackgroundTransparency = 1
	tween(fade, 0.18, { BackgroundTransparency = 0 }).Completed:Wait()
	hud.Enabled = false
	-- (and the phone joystick / jump button)
	local touch = player.PlayerGui:FindFirstChild("TouchGui")
	local touchWas = touch and touch.Enabled
	if touch then
		touch.Enabled = false
	end
	-- you stand still while the show runs
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local savedSpeed, savedJump = hum and hum.WalkSpeed, hum and hum.JumpPower
	if hum then
		hum.WalkSpeed, hum.JumpPower = 0, 0
	end
	local savedType, savedCF, savedFov = camera.CameraType, camera.CFrame, camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	local camCF = CFrame.lookAt(STAGE + Vector3.new(0, aimY + 0.4, dist), STAGE + Vector3.new(0, aimY, 0))
	camera.CFrame = camCF
	camera.FieldOfView = 50

	-- backdrop: a dark panel in the egg's colour with spinning rays
	local back = newPart(folder, { Size = Vector3.new(160, 100, 1), CFrame = CFrame.lookAt(STAGE + Vector3.new(0, 2, -26), STAGE + Vector3.new(0, 2, 10)), Color = egg.color:Lerp(Color3.new(0, 0, 0), 0.72), Material = Enum.Material.SmoothPlastic })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 8
	sg.Parent = back
	local grad = Instance.new("Frame")
	grad.Size = UDim2.fromScale(1, 1)
	grad.BackgroundColor3 = Color3.new(1, 1, 1)
	grad.Parent = sg
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(egg.color:Lerp(Color3.new(0, 0, 0), 0.45), egg.color:Lerp(Color3.new(0, 0, 0), 0.85))
	g.Rotation = 90
	g.Parent = grad
	local rays = Instance.new("ImageLabel")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(0.85, 0.85)
	rays.BackgroundTransparency = 1
	rays.Image = RAYS
	rays.ImageColor3 = (egg.accent or egg.color)
	rays.ImageTransparency = 0.55
	rays.Parent = grad
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = rays

	-- the pets are made now and wait behind the backdrop while the eggs shake, so their meshes are
	-- downloaded and drawn once already (a pet seen for the first time would pop out invisible)
	local petModels = {}
	for i, r in ipairs(results) do
		local m = prep(fns.petModel(r.kind, r.golden))
		if scale ~= 1 then
			m:ScaleTo(m:GetScale() * scale)
		end
		m:PivotTo(CFrame.new(STAGE + Vector3.new(i * 6, 0, -40)))
		m.Parent = folder
		petModels[i] = m
	end
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, petModels)
	end)

	-- the eggs: drop in from above
	local slots = {}
	for i, r in ipairs(results) do
		local at = STAGE + spots[i]
		local x = spots[i].X
		local home = CFrame.lookAt(at, at + Vector3.new(0, 0, 10))
		local e = prep(fns.eggModel(egg))
		if scale ~= 1 then
			e:ScaleTo(e:GetScale() * scale)
		end
		e:PivotTo(home * CFrame.new(0, 9, 0))
		e.Parent = folder
		local rig = EggLooks.attach(e, egg.id, { hatch = true, parent = folder, home = home })
		local hl = Instance.new("Highlight")
		hl.FillColor = bestColor
		hl.OutlineColor = bestColor
		hl.FillTransparency = 1
		hl.OutlineTransparency = 1
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = e
		slots[i] = { egg = e, rig = rig, home = home, hl = hl, result = r, x = x }
	end
	tween(fade, 0.25, { BackgroundTransparency = 1 })
	UIKit.sound("Whoosh", 0.45, 0.9)

	-- the build-up
	local t0 = os.clock()
	local DROP, DUR = fast and 0.25 or 0.45, fast and 0.9 or 2.6
	local last = os.clock()
	local shakeT = 0
	while true do
		local now = os.clock()
		local dt = now - last
		last = now
		local t = now - t0
		if t > DROP + DUR then
			break
		end
		rays.Rotation += dt * (20 + t * 25)
		for i, s in ipairs(slots) do
			local cf
			if t < DROP then
				local a = t / DROP
				local y = 9 * (1 - a) ^ 2 -- falls in, eases onto its spot
				cf = s.home * CFrame.new(0, y, 0)
			else
				local p = (t - DROP) / DUR
				local amp = math.rad(3 + 24 * p * p)
				local wob = math.sin((t - DROP) * (10 + 22 * p) + i) * amp
				local hop = (p > 0.55) and math.abs(math.sin((t - DROP) * 9 + i)) * 0.35 * (p - 0.55) * 2 or 0
				cf = s.home * CFrame.new(0, hop, 0) * CFrame.Angles(0, math.sin(t * 0.8) * 0.3, wob)
				-- Epic and better: the egg glows in its rarity colour at the end
				if order >= Config.Rarities.Epic.order and p > 0.7 then
					local gl = (p - 0.7) / 0.3
					s.hl.FillTransparency = 1 - gl * 0.55
					s.hl.OutlineTransparency = 1 - gl
				end
			end
			s.egg:PivotTo(cf)
			s.rig.update(dt, t, math.max(0, (t - DROP) / DUR) * 2.6, cf)
		end
		-- rarer = more camera shake in the last moments
		if t > DROP + DUR * 0.6 then
			shakeT += dt
			local k = (order >= 6 and 0.18 or order >= 4 and 0.1 or 0.04) * (t - DROP - DUR * 0.6) / (DUR * 0.4)
			camera.CFrame = camCF * CFrame.new(math.noise(shakeT * 18, 1) * k, math.noise(shakeT * 18, 2) * k, 0)
		end
		RunService.RenderStepped:Wait()
	end
	camera.CFrame = camCF

	-- crack!
	fade.BackgroundColor3 = best == "Common" and Color3.new(1, 1, 1) or bestColor:Lerp(Color3.new(1, 1, 1), 0.45)
	fade.BackgroundTransparency = 0
	tween(fade, 0.55, { BackgroundTransparency = 1 })
	UIKit.sound("Boom", 0.4, 1.5)
	rays.ImageColor3 = best == "Common" and (egg.accent or egg.color) or bestColor
	rays.ImageTransparency = 0.25
	local pieces = {}
	local pets = {}
	local tagged = {} -- NEW! once per kind, not on every copy
	for i, s in ipairs(slots) do
		local _, size = s.egg:GetBoundingBox()
		local center = s.home.Position + Vector3.new(0, size.Y * 0.5, 0)
		-- shell pieces fly out
		for k = 1, 14 do
			local dir = (Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5)).Unit
			local sz = Vector3.new(0.7 + math.random() * 0.5, 0.5 + math.random() * 0.4, 0.18) * (size.Y / 5)
			local accent = k % 3 == 0
			local p = newPart(folder, { Size = sz, CFrame = CFrame.new(center + dir * 0.8) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Color = accent and (egg.accent or Color3.new(1, 1, 1)) or egg.color, Material = accent and Enum.Material.Neon or Enum.Material.SmoothPlastic })
			table.insert(pieces, { p = p, v = dir * (9 + math.random() * 6) + Vector3.new(0, 4, 0), spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14, age = 0 })
		end
		-- a burst of rarity sparkles
		local pet = Config.Pets[s.result.kind]
		local color = pet.rarity == "Secret" and C(255, 255, 255) or Config.Rarities[pet.rarity].color
		local burst = newPart(folder, { Size = Vector3.one, CFrame = CFrame.new(center), Transparency = 1 })
		local em = PetFx.emitter(burst, { Color = ColorSequence.new(color, Color3.new(1, 1, 1)), Size = NumberSequence.new(0.6, 0), Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(8, 16), Rate = 0, LightEmission = 1, Drag = 3 })
		em:Emit(30 + Config.Rarities[pet.rarity].order * 10)
		s.rig.destroy()
		s.egg:Destroy()

		-- the pet springs out
		local m = petModels[i]
		local _, psize = m:GetBoundingBox()
		local pcf = CFrame.lookAt(s.home.Position, s.home.Position + Vector3.new(0, 0, 10)) * CFrame.new(0, math.max(0, 2.6 * scale - psize.Y * 0.35), 0)
		m:PivotTo(pcf)
		m.Parent = folder
		PetFx.apply(m, s.result.kind, { strength = 1.6 })
		local base = m:GetScale()
		m:ScaleTo(base * 0.2)
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Brightness = 2
		glow.Range = 12
		glow.Parent = burst
		local cap = caption(pet, s.result.golden, fns.tier, s.result.deleted, n > 3)
		local new = fns.isNew and fns.isNew(s.result.kind) and not tagged[s.result.kind]
		if new then
			tagged[s.result.kind] = true
			local k = textScale()
			local tag = UIKit.label({ Parent = cap, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.85, 0, 0, -6 * k), Size = UDim2.fromOffset(84 * k, 30 * k), Rotation = 12, Text = "NEW!", TextColor3 = C(255, 230, 60), ZIndex = 10, StrokeThickness = 2.5 * k })
			UIKit.bounce(tag)
		end
		table.insert(pets, { m = m, base = base, pcf = pcf, size = psize, cap = cap, born = os.clock() })
	end
	if order >= Config.Rarities.Legendary.order then
		UIKit.sound("Fanfare", 0.7)
	elseif order >= Config.Rarities.Epic.order then
		UIKit.sound("Jingle", 0.6, 1)
	else
		task.delay(0.08, UIKit.sound, "Gem", 0.55, 1.05)
	end

	-- the reveal: pets pop to full size, spin gently; captions follow them
	local closed = false
	local conn = click.Activated:Connect(function()
		if os.clock() - t0 > DROP + DUR + 0.5 then
			closed = true
		end
	end)
	local tEnd = os.clock() + (fast and 1.5 or 4.5)
	local shown = false
	while not closed and os.clock() < tEnd do
		local now = os.clock()
		local dt = now - last
		last = now
		rays.Rotation += dt * 30
		for _, pc in ipairs(pieces) do
			if pc.p.Parent then
				pc.v += Vector3.new(0, -30, 0) * dt
				pc.p.CFrame = (pc.p.CFrame + pc.v * dt) * CFrame.Angles(pc.spin.X * dt, pc.spin.Y * dt, pc.spin.Z * dt)
				pc.age += dt
				pc.p.Transparency = math.clamp((pc.age - 0.45) * 1.6, 0, 1)
			end
		end
		for _, p in ipairs(pets) do
			local a = math.min(1, (now - p.born) / 0.45)
			if not p.grown then
				local spring = 1 + math.sin(a * math.pi * 1.5) * (1 - a) * 0.35 -- overshoot, settle
				p.m:ScaleTo(p.base * math.max(0.2, a * spring))
				p.grown = a >= 1
			end
			p.m:PivotTo(p.pcf * CFrame.new(0, math.sin(now * 2) * 0.15, 0) * CFrame.Angles(0, math.sin(now * 1.2) * 0.45, 0))
			local sp, on = camera:WorldToViewportPoint(p.pcf.Position + Vector3.new(0, -1.1 * scale, 0))
			p.cap.Visible = on
			p.cap.Position = UDim2.fromOffset(sp.X, sp.Y + 6)
		end
		if not shown and now - t0 > DROP + DUR + 0.6 then
			shown = true
			hint.Visible = true
		end
		RunService.RenderStepped:Wait()
	end
	conn:Disconnect()

	-- back to the game
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	tween(fade, 0.18, { BackgroundTransparency = 0 }).Completed:Wait()
	for _, p in ipairs(pets) do
		p.cap:Destroy()
	end
	folder:Destroy()
	camera.CameraType = savedType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or savedType
	camera.FieldOfView = savedFov
	camera.CFrame = savedCF
	hud.Enabled = true
	if touch and touch.Parent then
		touch.Enabled = touchWas
	end
	hint.Visible = false
	if hum and hum.Parent then
		hum.WalkSpeed, hum.JumpPower = savedSpeed, savedJump
	end
	tween(fade, 0.25, { BackgroundTransparency = 1 }).Completed:Wait()
	screen.Enabled = false
	player:SetAttribute("HatchShow", nil)
	running = false
end

return HatchShow
