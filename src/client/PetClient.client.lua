-- Pets (client):
--   * PETS button: your pets. Modes: 🐾 Equip (tap = equip / unequip), 🔒 Lock (locked pets can't be
--     deleted, fused or traded), 🗑 Delete (tap pets to pick them, then Delete). Equip Best, Pet
--     Index, Trade, and storage / slot upgrades (money).
--   * Golden pets: a "⭐ n/5" tag shows how many copies you have; with 5 it turns gold: press it
--     twice to fuse 5 copies into one Golden pet (2.5x the bonus), with its own reveal show.
--   * Pets follow every player (drawn on each client, so they move smoothly) with their effects
--     (PetFx): they hop behind you when you walk (they stay behind while you fly).
--   * (The egg window + hatching: EggClient. The boards above the eggs: HatcheryClient.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PetAction = remotes:WaitForChild("PetAction")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local abbreviate, multText = Config.abbreviate, Config.multText

local INK_SOFT = Color3.fromRGB(70, 70, 100)
local GREEN, BLUE, GREY, RED = Color3.fromRGB(80, 200, 90), Color3.fromRGB(70, 140, 255), Color3.fromRGB(160, 165, 185), Color3.fromRGB(235, 90, 90)
local PINK = Color3.fromRGB(255, 120, 190)
local modules = script.Parent:WaitForChild("ClientModules")
local PetFx = require(modules:WaitForChild("PetFx"))

-- rarity colour for UI (Secret is black in the game: draw it a deep purple-black with white text)
local function rarityColor(rarity)
	return Config.Rarities[rarity].color
end

-- Models (shared helpers: PetView) -------------------------------------------------------------
local PetView = require(modules:WaitForChild("PetView"))
local petFolder = PetView.petFolder
local petModel, viewport = PetView.petModel, PetView.viewport
local GOLD = PetView.GOLD
local hatching = false -- (a golden reveal is running)

-- Hatch show --------------------------------------------------------------------------------------
local gui = UIKit.gui()
local overlay = make("TextButton", { Parent = gui, Name = "HatchShow", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 50 })
local slotsHolder = make("Frame", { Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(900, 420), BackgroundTransparency = 1, ZIndex = 51 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 16) }),
	make("UISizeConstraint", { MaxSize = Vector2.new(900, 420) }),
	make("UIAspectRatioConstraint", { AspectRatio = 900 / 420 }),
})
local hint = label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(500, 34), Text = "Click to continue", TextColor3 = Color3.fromRGB(230, 230, 240), ZIndex = 52, Visible = false })
local flash = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 60, Active = false })

local function makeSlot(count)
	local w = count == 1 and 0.42 or 0.31
	local slot = make("Frame", { Parent = slotsHolder, Size = UDim2.fromScale(w, 1), BackgroundTransparency = 1, ZIndex = 51 })
	-- a sparkle burst behind the pet, tinted with its rarity color
	local rays = make("ImageLabel", { Parent = slot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(1.15, 0.85), BackgroundTransparency = 1, Image = "rbxasset://textures/particles/sparkles_main.dds", ImageTransparency = 1, ZIndex = 51 })
	make("UIAspectRatioConstraint", { Parent = rays, AspectRatio = 1 })
	local holder = make("Frame", { Parent = slot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(0.9, 0.7), BackgroundTransparency = 1, ZIndex = 52 }, {
		make("UIAspectRatioConstraint", { AspectRatio = 1 }),
	})
	local roll = label({ Parent = slot, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromScale(1, 0.11), Text = "", ZIndex = 53 })
	local sub = label({ Parent = slot, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.88), Size = UDim2.fromScale(1, 0.09), Text = "", ZIndex = 53 })
	local new = label({ Parent = slot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.78, 0.1), Size = UDim2.fromScale(0.4, 0.1), Rotation = 12, Text = "NEW!", TextColor3 = Color3.fromRGB(255, 230, 60), Visible = false, ZIndex = 54 })
	return { slot = slot, rays = rays, holder = holder, roll = roll, sub = sub, new = new }
end

local spinning = {} -- models spinning in the show
RunService.RenderStepped:Connect(function(dt)
	if not overlay.Visible then
		return
	end
	for _, s in ipairs(spinning) do
		if s.rays then
			s.rays.Rotation += dt * 40
		end
		if s.model and s.spin then
			s.model:PivotTo(CFrame.Angles(0, math.sin(os.clock() * 1.5) * 0.6, 0))
		end
	end
end)

-- Pets window ---------------------------------------------------------------------------------------
local petsWindow, petsList = UIKit.window("Pets", PINK, UDim2.fromOffset(700, 520), "Paw")
local topRow = UIKit.row(petsList, 0, 66)
local summary = label({ Parent = topRow, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -470, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
local summary2 = label({ Parent = topRow, Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -470, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = Color3.fromRGB(40, 170, 70), StrokeThickness = 0, ZIndex = 12 })
local equipBest = UIKit.button({ Parent = topRow, Text = "Equip Best", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(160, 50), ZIndex = 12 })
local indexBtn = UIKit.button({ Parent = topRow, Text = "📖 Index", Color = Color3.fromRGB(110, 140, 240), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -180, 0.5, 0), Size = UDim2.fromOffset(130, 50), ZIndex = 12 })
local tradeBtn = UIKit.button({ Parent = topRow, Text = "🔁 Trade", Color = Color3.fromRGB(255, 160, 50), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -320, 0.5, 0), Size = UDim2.fromOffset(130, 50), ZIndex = 12 })
-- (TradeClient listens for this)
local openTrade = script.Parent:FindFirstChild("OpenTradeList") or Instance.new("BindableEvent")
openTrade.Name = "OpenTradeList"
openTrade.Parent = script.Parent
tradeBtn.Instance.Activated:Connect(function()
	openTrade:Fire()
end)

-- tools: what a tap on a pet does (🐾 equip / 🔒 lock / 🗑 pick to delete) + upgrades (money)
local toolsRow = UIKit.row(petsList, 1, 58)
local mode = "equip"
local selected = {} -- [uid] = true (delete mode)
local modeButtons = {}
for i, m in ipairs({ { "equip", "🐾 Equip" }, { "lock", "🔒 Lock" }, { "delete", "🗑 Delete" } }) do
	local b = make("TextButton", { Parent = toolsRow, Position = UDim2.fromOffset(10 + (i - 1) * 92, 9), Size = UDim2.fromOffset(86, 40), BackgroundColor3 = Color3.fromRGB(150, 155, 175), Text = "", AutoButtonColor = false, ZIndex = 12 }, { UIKit.corner(12), UIKit.stroke(2.5) })
	label({ Parent = b, Size = UDim2.fromScale(1, 1), Text = m[2], ZIndex = 13, StrokeThickness = 2 })
	modeButtons[m[1]] = b
end
local storageBtn = UIKit.button({ Parent = toolsRow, Text = "", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -164, 0.5, 0), Size = UDim2.fromOffset(150, 44), ZIndex = 12 })
local slotBtn = UIKit.button({ Parent = toolsRow, Text = "", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(150, 44), ZIndex = 12 })
local deleteBtn = UIKit.button({ Parent = toolsRow, Text = "", Color = RED, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(200, 44), ZIndex = 12 })
local clearBtn = UIKit.button({ Parent = toolsRow, Text = "Clear", Color = Color3.fromRGB(150, 155, 175), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -216, 0.5, 0), Size = UDim2.fromOffset(110, 44), ZIndex = 12 })

-- Pet Index: every pet by egg (event eggs too); ones you've never had are black silhouettes. A full egg set
-- gives +10% money forever (server: PetServer / GameServer).
local indexWindow, indexList = UIKit.window("Pet Index", Color3.fromRGB(110, 140, 240), UDim2.fromOffset(700, 520), "Paw")
local indexHead = UIKit.row(indexList, 0, 56)
local indexHeadText = label({ Parent = indexHead, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
local indexCards = {} -- [kind] = { vp, name }
local eggHeads = {} -- [egg.id] = { label, card }
for i, egg in ipairs(Config.allEggs()) do
	local rows = math.ceil(#egg.pets / 5)
	local section = UIKit.card(indexList, { LayoutOrder = i, Size = UDim2.new(1, -12, 0, 52 + rows * 148), ZIndex = 11, Tint = UIKit.lighter(egg.color, 0.7) })
	local head = label({ Parent = section, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	local row = make("Frame", { Parent = section, Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, rows * 148), BackgroundTransparency = 1, ZIndex = 12 }, {
		make("UIGridLayout", { CellSize = UDim2.fromOffset(118, 140), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for j, kind in ipairs(egg.pets) do
		local rarity = Config.Pets[kind].rarity
		local color = rarityColor(rarity)
		local card = make("Frame", { Parent = row, LayoutOrder = j, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(16), UIKit.stroke(3.5, color) })
		local vp = viewport(card, petModel(kind), { Position = UDim2.fromOffset(9, 4), Size = UDim2.fromOffset(100, 88), ZIndex = 13 })
		local name = label({ Parent = card, Position = UDim2.fromOffset(4, 92), Size = UDim2.new(1, -8, 0, 22), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 13 })
		label({ Parent = card, Position = UDim2.fromOffset(4, 114), Size = UDim2.new(1, -8, 0, 18), Text = rarity, TextColor3 = rarity == "Secret" and Color3.fromRGB(40, 20, 60) or color, StrokeThickness = 1.5, ZIndex = 13 })
		indexCards[kind] = { vp = vp, name = name }
	end
	eggHeads[egg.id] = { label = head, egg = egg }
end

local function refreshIndex()
	local have = {}
	for kind in string.gmatch(player:GetAttribute("PetIndex") or "", "%w+") do
		have[kind] = true
	end
	local found = 0
	for kind, c in pairs(indexCards) do
		local got = have[kind] == true
		found += got and 1 or 0
		c.vp.ImageColor3 = got and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		c.vp.ImageTransparency = got and 0 or 0.35
		c.name.Text = got and Config.Pets[kind].name or "???"
	end
	for _, h in pairs(eggHeads) do
		local n = 0
		for _, kind in ipairs(h.egg.pets) do
			n += have[kind] and 1 or 0
		end
		local total = #h.egg.pets
		local bonus = math.floor(Config.INDEX_SET_BONUS * 100 + 0.5)
		local done = n == total
		h.label.Text = h.egg.name .. "   " .. n .. " / " .. total .. (done and ("   ✔ +" .. bonus .. "% money!") or ("   (find all " .. total .. ": +" .. bonus .. "% money)"))
		h.label.TextColor3 = done and Color3.fromRGB(40, 160, 70) or UIKit.INK
	end
	local total = 0
	for _ in pairs(indexCards) do
		total += 1
	end
	local sets = player:GetAttribute("IndexSets") or 0
	indexHeadText.Text = "📖 Found " .. found .. " / " .. total .. " pets   •   Money bonus: +" .. math.floor(sets * Config.INDEX_SET_BONUS * 100 + 0.5) .. "%"
end
player:GetAttributeChangedSignal("PetIndex"):Connect(refreshIndex)
player:GetAttributeChangedSignal("IndexSets"):Connect(refreshIndex)
refreshIndex()
indexBtn.Instance.Activated:Connect(function()
	refreshIndex()
	UIKit.toggle(indexWindow)
end)

equipBest.Instance.Activated:Connect(function()
	UIKit.result(PetAction:InvokeServer("equipBest"))
end)
-- empty state: a puppy on rays, "No pets yet!" and where to get one
local emptyLabel = UIKit.row(petsList, 2, 210)
emptyLabel.Name = "NoPets"
local emptyIcon = make("Frame", { Parent = emptyLabel, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(120, 110), BackgroundTransparency = 1, ZIndex = 13 })
UIKit.rays(emptyLabel, { Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(170, 170), Color = Color3.fromRGB(255, 160, 210), ZIndex = 12 })
UIKit.icon3D(emptyIcon, petFolder and petFolder:FindFirstChild("Puppy") or "Paw", { ZIndex = 13 })
label({ Parent = emptyLabel, Position = UDim2.fromOffset(14, 120), Size = UDim2.new(1, -28, 0, 40), Text = "No pets yet!", TextColor3 = UIKit.darker(PINK, 0.15), StrokeThickness = 0, ZIndex = 13 })
label({ Parent = emptyLabel, Position = UDim2.fromOffset(14, 162), Size = UDim2.new(1, -28, 0, 30), Text = "🥚 Hatch eggs in the Hatchery behind the spawn", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 13 })
local grid = make("Frame", { Parent = petsList, LayoutOrder = 3, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIGridLayout", { CellSize = UDim2.fromOffset(100, 126), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- Golden reveal: the new Golden pet springs in over spinning gold rays.
local function playGolden(kind, uid)
	hatching = true
	for _, c in ipairs(slotsHolder:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	table.clear(spinning)
	hint.Visible = false
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.3 }):Play()
	local wasOpen = petsWindow.Visible
	petsWindow.Visible = false
	local s = makeSlot(1)
	local pet = Config.Pets[kind]
	UIKit.sound("Whoosh", 0.5, 0.9)
	task.wait(0.25)
	flash.BackgroundColor3 = Color3.new(1, 1, 1) -- (a hatch may have tinted it)
	flash.BackgroundTransparency = 0
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	UIKit.sound("Boom", 0.35, 1.5)
	local m = petModel(kind, true)
	viewport(s.holder, m, { Size = UDim2.fromScale(1, 1), ZIndex = 52 })
	local pop = make("UIScale", { Parent = s.holder, Scale = 0.2 })
	UIKit.spr.target(pop, 0.45, 4, { Scale = 1 })
	s.rays.ImageColor3 = GOLD
	s.rays.ImageTransparency = 0.05
	s.roll.Text = "⭐ GOLDEN " .. string.upper(pet.name) .. "!"
	s.roll.TextColor3 = Color3.fromRGB(255, 220, 80)
	s.sub.Text = multText(pet.mult) .. "  →  " .. multText(Config.petMult(kind, true)) .. " 💰"
	s.sub.TextColor3 = Color3.fromRGB(140, 255, 140)
	UIKit.bounce(s.roll)
	table.insert(spinning, { rays = s.rays, model = m, spin = true })
	UIKit.sound("Jingle", 0.6, 1.1)
	UIKit.sound("Gem", 0.5, 1.3)
	task.wait(0.6)
	hint.Visible = true
	local closed = false
	local conn = overlay.Activated:Connect(function()
		closed = true
	end)
	local tEnd = os.clock() + 3.5
	while not closed and os.clock() < tEnd do
		task.wait(0.05)
	end
	conn:Disconnect()
	overlay.Visible = false
	table.clear(spinning)
	hatching = false
	if wasOpen then
		UIKit.toggle(petsWindow)
	end
end

local cards = {} -- [uid] = card info
local refreshTools -- (below)
local function makeCard(p)
	local pet = Config.Pets[p.kind]
	local color = p.golden and GOLD or rarityColor(pet.rarity)
	local card = make("TextButton", { Parent = grid, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(14) })
	local stroke = UIKit.stroke(3.5, color)
	stroke.Parent = card
	make("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), UIKit.lighter(color, 0.72)) })
	local holder = make("Frame", { Parent = card, Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(88, 78), BackgroundTransparency = 1, ZIndex = 13 })
	viewport(holder, petModel(p.kind, p.golden), { Size = UDim2.fromScale(1, 1), ZIndex = 13 })
	label({ Parent = card, Position = UDim2.fromOffset(3, 82), Size = UDim2.new(1, -6, 0, 20), Text = (p.golden and "⭐ Golden " or "") .. pet.name, TextColor3 = p.golden and Color3.fromRGB(210, 140, 0) or UIKit.INK, StrokeThickness = 0, ZIndex = 13 })
	local multLabel = label({ Parent = card, Position = UDim2.fromOffset(3, 102), Size = UDim2.new(1, -6, 0, 20), Text = "", TextColor3 = Color3.fromRGB(40, 170, 70), StrokeThickness = 0, ZIndex = 13 })
	-- golden tag: "⭐ 3/5" while collecting copies, a gold button once you have 5
	local fuse = make("TextButton", { Parent = card, Name = "Fuse", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(44, 22), BackgroundColor3 = Color3.fromRGB(235, 235, 245), Text = "", AutoButtonColor = false, Visible = false, ZIndex = 16 }, { UIKit.corner(11), UIKit.stroke(2) })
	local fuseText = label({ Parent = fuse, Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 17 })
	local check = label({ Parent = card, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0, BackgroundColor3 = GREEN, Text = "✔", ZIndex = 15, Visible = false }, nil)
	make("UICorner", { Parent = check, CornerRadius = UDim.new(1, 0) })
	local lockTag = make("TextLabel", { Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Color3.fromRGB(255, 225, 120), Text = "🔒", TextScaled = true, Font = UIKit.FONT, Visible = false, ZIndex = 15 }, { UIKit.corner(8) })
	-- delete mode: picked pets get a red cover with a ✖
	local pick = make("Frame", { Parent = card, Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BackgroundTransparency = 0.45, Visible = false, ZIndex = 18 }, { UIKit.corner(14) })
	label({ Parent = pick, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(44, 44), Text = "✖", ZIndex = 19 })
	local info = { card = card, check = check, lockTag = lockTag, pick = pick, multLabel = multLabel, kind = p.kind, uid = p.uid, golden = p.golden, fuse = fuse, fuseText = fuseText, fuseArmed = 0, copies = 0 }
	fuse.Activated:Connect(function()
		if info.copies < Config.GOLDEN_COST then
			UIKit.toast("Collect " .. (Config.GOLDEN_COST - info.copies) .. " more " .. pet.name .. " to make a GOLDEN " .. pet.name .. "! ⭐", Color3.fromRGB(255, 220, 120))
			return
		end
		if os.clock() - info.fuseArmed > 2.5 then
			info.fuseArmed = os.clock()
			fuseText.Text = "SURE?"
			UIKit.bounce(fuse)
			UIKit.toast("Press again: " .. Config.GOLDEN_COST .. " " .. pet.name .. " → 1 GOLDEN " .. pet.name .. " (" .. multText(Config.petMult(p.kind, true, Config.playerTier(player))) .. ")", Color3.fromRGB(255, 215, 80))
			task.delay(2.5, function()
				if fuse.Parent and os.clock() - info.fuseArmed >= 2.4 and info.copies >= Config.GOLDEN_COST then
					fuseText.Text = "⭐ GOLD"
				end
			end)
			return
		end
		if hatching then
			return -- (a golden show is already running or a request is on its way)
		end
		hatching = true
		info.fuseArmed = 0
		local ok, result = PetAction:InvokeServer("golden", p.uid)
		if ok then
			task.spawn(playGolden, p.kind, result)
		else
			hatching = false
			UIKit.result(false, result)
		end
	end)
	card.Activated:Connect(function()
		UIKit.sound("Click", 0.4)
		UIKit.bounce(card)
		if mode == "delete" then
			if info.locked then
				UIKit.toast("🔒 Locked pets can't be deleted. Unlock it in 🔒 Lock mode.", Color3.fromRGB(255, 200, 150))
				return
			end
			selected[p.uid] = not selected[p.uid] or nil
			pick.Visible = selected[p.uid] == true
			refreshTools()
			return
		end
		local ok, msg = PetAction:InvokeServer(mode == "lock" and "lock" or (info.equipped and "unequip" or "equip"), p.uid)
		if not ok or mode == "lock" then
			UIKit.result(ok, msg)
		end
	end)
	return info
end

local deleteArmed = 0
function refreshTools()
	for key, b in pairs(modeButtons) do
		b.BackgroundColor3 = key == mode and (key == "delete" and RED or key == "lock" and Color3.fromRGB(240, 170, 40) or GREEN) or Color3.fromRGB(150, 155, 175)
	end
	local n = 0
	for uid in pairs(selected) do
		if cards[uid] then
			n += 1
		else
			selected[uid] = nil
		end
	end
	local deleting = mode == "delete"
	deleteBtn.Instance.Visible = deleting
	clearBtn.Instance.Visible = deleting
	storageBtn.Instance.Visible = not deleting
	slotBtn.Instance.Visible = not deleting
	if os.clock() - deleteArmed > 2.5 then
		deleteBtn.setText(n == 0 and "Tap pets to pick" or ("🗑 Delete " .. n))
	end
	deleteBtn.setColor(n > 0 and RED or Color3.fromRGB(150, 155, 175))
	local money = player:GetAttribute("Money") or 0
	local sLevel = player:GetAttribute("StorageLevel") or 0
	local sPrice = Config.STORAGE.prices[sLevel + 1]
	storageBtn.setText(sPrice and ("📦 +" .. Config.STORAGE.step .. "  $" .. abbreviate(sPrice)) or "📦 Storage MAX")
	storageBtn.setColor(sPrice and money >= sPrice and GREEN or Color3.fromRGB(150, 155, 175))
	local slLevel = player:GetAttribute("SlotLevel") or 0
	local slPrice = Config.SLOT_PRICES[slLevel + 1]
	slotBtn.setText(slPrice and ("🐾 +1 Slot  $" .. abbreviate(slPrice)) or "🐾 Slots MAX")
	slotBtn.setColor(slPrice and money >= slPrice and GREEN or Color3.fromRGB(150, 155, 175))
end

local function setMode(m)
	mode = m
	if m ~= "delete" then
		table.clear(selected)
		for _, c in pairs(cards) do
			c.pick.Visible = false
		end
	end
	refreshTools()
	local tips = { equip = "Tap a pet to equip / unequip it.", lock = "🔒 Tap pets to lock / unlock them. Locked pets can't be deleted or traded.", delete = "🗑 Tap pets to pick them, then press Delete." }
	UIKit.toast(tips[m], Color3.fromRGB(255, 200, 230))
end
for key, b in pairs(modeButtons) do
	b.Activated:Connect(function()
		UIKit.sound("Click", 0.4)
		setMode(key)
	end)
end
clearBtn.Instance.Activated:Connect(function()
	table.clear(selected)
	for _, c in pairs(cards) do
		c.pick.Visible = false
	end
	refreshTools()
end)
deleteBtn.Instance.Activated:Connect(function()
	local list = {}
	for uid in pairs(selected) do
		table.insert(list, uid)
	end
	if #list == 0 then
		return
	end
	if os.clock() - deleteArmed > 2.5 then
		deleteArmed = os.clock()
		deleteBtn.setText("Sure? Delete " .. #list)
		UIKit.bounce(deleteBtn.Instance)
		task.delay(2.6, refreshTools)
		return
	end
	deleteArmed = 0
	local ok, msg = PetAction:InvokeServer("deleteMany", list)
	UIKit.result(ok, msg)
	if ok then
		table.clear(selected)
	end
	refreshTools()
end)
storageBtn.Instance.Activated:Connect(function()
	UIKit.result(PetAction:InvokeServer("upgradeStorage"))
end)
slotBtn.Instance.Activated:Connect(function()
	UIKit.result(PetAction:InvokeServer("upgradeSlots"))
end)

local function refreshPets()
	local pets = Config.parsePets(player:GetAttribute("Pets"))
	local equipped = Config.parseEquipped(player:GetAttribute("EquippedPets"))
	local tier = Config.playerTier(player)
	local seen = {}
	for _, p in ipairs(pets) do
		seen[p.uid] = true
		if not cards[p.uid] then
			cards[p.uid] = makeCard(p)
		end
	end
	for uid, c in pairs(cards) do
		if not seen[uid] then
			c.card:Destroy()
			cards[uid] = nil
		end
	end
	-- equipped first, then strongest
	table.sort(pets, function(a, b)
		local ea, eb = equipped[a.uid] and 1 or 0, equipped[b.uid] and 1 or 0
		if ea ~= eb then
			return ea > eb
		end
		local ma, mb = Config.petMult(a.kind, a.golden, tier), Config.petMult(b.kind, b.golden, tier)
		if ma ~= mb then
			return ma > mb
		end
		return a.uid > b.uid
	end)
	-- copies of each pet (not golden, not locked) for the golden tags
	local copies = {}
	for _, p in ipairs(pets) do
		if not p.golden and not p.locked then
			copies[p.kind] = (copies[p.kind] or 0) + 1
		end
	end
	for _, c in pairs(cards) do
		local n = c.golden and 0 or (copies[c.kind] or 0)
		c.copies = n
		c.fuse.Visible = n >= 2
		if n >= Config.GOLDEN_COST then
			c.fuse.BackgroundColor3 = GOLD
			if os.clock() - c.fuseArmed > 2.5 then
				c.fuseText.Text = "⭐ GOLD"
			end
			c.fuseText.TextColor3 = Color3.new(1, 1, 1)
		else
			c.fuse.BackgroundColor3 = Color3.fromRGB(235, 235, 245)
			c.fuseText.Text = "⭐ " .. n .. "/" .. Config.GOLDEN_COST
			c.fuseText.TextColor3 = UIKit.INK
		end
	end
	local nEquipped = 0
	for i, p in ipairs(pets) do
		local c = cards[p.uid]
		c.card.LayoutOrder = i
		c.equipped = equipped[p.uid] == true
		c.locked = p.locked
		c.check.Visible = c.equipped
		c.lockTag.Visible = p.locked
		c.pick.Visible = selected[p.uid] == true and not p.locked
		if p.locked then
			selected[p.uid] = nil
		end
		c.multLabel.Text = multText(Config.petMult(p.kind, p.golden, tier)) .. (Config.Pets[p.kind].scales and " 📈" or " 💰")
		if c.equipped then
			nEquipped += 1
		end
	end
	emptyLabel.Visible = #pets == 0
	summary.Text = string.format("🐾 %d / %d pets", #pets, Config.maxPetsFor(player))
	summary2.Text = string.format("Equipped %d/%d  •  ", nEquipped, Config.petSlotsFor(player)) .. multText(player:GetAttribute("PetMultiplier") or 1) .. " 💰"
	refreshTools()
end
for _, attr in ipairs({ "Pets", "EquippedPets", "PetMultiplier", "Rebirths", "UnlockedStage", "StorageLevel", "SlotLevel", "Pass_VIP", "Pass_PetSlots", "Pass_PetStorage" }) do
	player:GetAttributeChangedSignal(attr):Connect(refreshPets)
end
player:GetAttributeChangedSignal("Money"):Connect(refreshTools)
refreshPets()

-- PETS button in the bottom bar
local petsBtn = UIKit.button({ Parent = UIKit.bottomBar(), LayoutOrder = 5, Icon3D = "Paw", Icon = "🐾", Text = "PETS", Color = PINK, Size = UDim2.fromOffset(104, 104), Radius = 24 })
petsBtn.Instance.Activated:Connect(function()
	UIKit.toggle(petsWindow)
end)

-- Following pets -------------------------------------------------------------------------------
local followFolder = Instance.new("Folder")
followFolder.Name = "PetFollowers"
followFolder.Parent = workspace

-- spots around you, in your own space (+Z = behind you)
local WALK_SLOTS = { Vector3.new(-3.6, 0, 4), Vector3.new(3.6, 0, 4), Vector3.new(0, 0, 6.5), Vector3.new(-6, 0, 7.5), Vector3.new(6, 0, 7.5), Vector3.new(0, 0, 10),
	Vector3.new(-9, 0, 10.5), Vector3.new(9, 0, 10.5), Vector3.new(-4, 0, 12.5), Vector3.new(4, 0, 12.5), Vector3.new(-8, 0, 14.5), Vector3.new(8, 0, 14.5) }
-- in flight the pets fly beside the rocket (never between it and the camera)
local FLY_SLOTS = { Vector3.new(-5.5, 0.5, 0.5), Vector3.new(5.5, 0.5, 0.5), Vector3.new(-9.5, 2, 1.5), Vector3.new(9.5, 2, 1.5), Vector3.new(-13.5, 3.5, 3), Vector3.new(13.5, 3.5, 3),
	Vector3.new(-7.5, -2.5, 2.5), Vector3.new(7.5, -2.5, 2.5), Vector3.new(-11.5, -1, 4), Vector3.new(11.5, -1, 4), Vector3.new(-15.5, 0.5, 5.5), Vector3.new(15.5, 0.5, 5.5) }
local followers = {} -- [player] = { kinds = string, pets = { { model, pos } } }

local function rebuildFollowers(plr)
	local f = followers[plr]
	if f then
		for _, p in ipairs(f.pets) do
			p.model:Destroy()
		end
	end
	local kindsStr = plr:GetAttribute("PetKinds") or ""
	f = { kinds = kindsStr, pets = {} }
	followers[plr] = f
	for entry in string.gmatch(kindsStr, "[^,]+") do
		local kind, flag = string.match(entry, "^(%w+):?(%a?)$")
		if kind and Config.Pets[kind] then
			local golden = flag == "G"
			local m = petModel(kind, golden)
			PetFx.apply(m, kind)
			local _, size = m:GetBoundingBox()
			f.spread = math.max(f.spread or 1, math.clamp(math.max(size.X, size.Z) / 3, 1, 1.9))
			if golden then
				-- golden pets glitter
				local e = Instance.new("ParticleEmitter")
				e.Name = "Gold"
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				e.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 170, 30))
				e.Size = NumberSequence.new(0.45, 0)
				e.Lifetime = NumberRange.new(0.5, 0.9)
				e.Speed = NumberRange.new(0.5, 2)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Rate = 10
				e.LightEmission = 0.6
				e.Parent = m:FindFirstChildWhichIsA("BasePart", true)
			end
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CastShadow = true
				end
			end
			if Config.hasPass(plr, "RainbowPets") then
				-- Rainbow Pets pass: rainbow sparkles around the pet
				local main = m:FindFirstChildWhichIsA("BasePart", true)
				local e = Instance.new("ParticleEmitter")
				e.Name = "Rainbow"
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				e.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
					ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 60)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 110)),
					ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 160, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
				})
				e.Size = NumberSequence.new(0.5, 0)
				e.Lifetime = NumberRange.new(0.6, 1)
				e.Speed = NumberRange.new(1, 3)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Rate = 14
				e.LightEmission = 0.5
				e.Parent = main
			end
			m.Parent = followFolder
			table.insert(f.pets, { model = m, pos = nil })
		end
	end
end

local function watchPlayer(plr)
	plr:GetAttributeChangedSignal("Pass_RainbowPets"):Connect(function()
		rebuildFollowers(plr)
	end)
	plr:GetAttributeChangedSignal("PetKinds"):Connect(function()
		rebuildFollowers(plr)
	end)
	rebuildFollowers(plr)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, plr in ipairs(Players:GetPlayers()) do
	watchPlayer(plr)
end
Players.PlayerRemoving:Connect(function(plr)
	local f = followers[plr]
	if f then
		for _, p in ipairs(f.pets) do
			p.model:Destroy()
		end
	end
	followers[plr] = nil
end)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local camera = workspace.CurrentCamera

RunService.RenderStepped:Connect(function(dt)
	local ignore = { followFolder }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	local flights = workspace:FindFirstChild("Flights")
	if flights then
		table.insert(ignore, flights)
	end
	rayParams.FilterDescendantsInstances = ignore
	local now = os.clock()
	local camPos = camera.CFrame.Position

	for plr, f in pairs(followers) do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		-- pets wait in the lobby while their owner is flying (they'd only clutter the view)
		local near = root and not plr:GetAttribute("Flying") and (root.Position - camPos).Magnitude < 350
		for i, p in ipairs(f.pets) do
			if not near then
				p.model.Parent = nil
				p.pos = nil
				continue
			end
			p.model.Parent = followFolder
			local flying = plr:GetAttribute("Flying")
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			look = look.Magnitude > 0.01 and look.Unit or Vector3.new(1, 0, 0)
			local yaw = CFrame.lookAt(Vector3.zero, look)
			local slot = ((flying and FLY_SLOTS or WALK_SLOTS)[i] or Vector3.new(0, 0, 4 + i * 2)) * (f.spread or 1)
			local target = root.Position + yaw:VectorToWorldSpace(slot)
			local lift = 0
			if flying then
				-- glide into place in the rocket's own space, so going fast never leaves them behind
				local rel = slot + Vector3.new(0, math.sin(now * 3 + i) * 0.6, 0)
				p.rel = p.rel and p.rel:Lerp(rel, 1 - math.exp(-dt * 6)) or rel
				p.pos = nil
				p.model:PivotTo(CFrame.new(root.Position + yaw:VectorToWorldSpace(p.rel)) * yaw)
				continue
			else
				p.rel = nil
				local hit = workspace:Raycast(target + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), rayParams)
				target = Vector3.new(target.X, hit and hit.Position.Y or root.Position.Y - 3, target.Z)
				local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
				lift = speed > 1.5 and math.abs(math.sin(now * 9 + i * 1.3)) * 1.1 or (math.sin(now * 2 + i) + 1) * 0.12
			end
			if not p.pos or (p.pos - target).Magnitude > 80 then
				p.pos = target
			end
			local k = 1 - math.exp(-dt * (flying and 18 or 10))
			p.pos = p.pos:Lerp(target, k)
			p.model:PivotTo(CFrame.new(p.pos + Vector3.new(0, lift, 0)) * yaw)
		end
	end
end)
