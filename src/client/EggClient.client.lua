-- Eggs (client): the egg window and hatching.
--   * Walk up to an egg in the Hatchery and press E: its 4-7 pets (rarity, money boost, chance).
--     Tap a pet below Legendary to auto-delete it whenever you hatch it (red AUTO-DELETE).
--   * Hatch 1 / 3 / 8 (8: Hatch 8 pass). ⚡ Fast = a short show. 🔁 Auto (Auto Hatch pass) keeps
--     hatching until you stop, walk away, run out of money or fill your storage.
--   * Limited egg: price follows your best egg, a timer in the title. Royal egg: bought with Robux
--     (not where paid random items aren't allowed) - the server hatches it (PaidHatch).
--   * Rare hatches by anyone: one plain line in chat (HatchNews).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local modules = script.Parent:WaitForChild("ClientModules")
local UIKit = require(modules:WaitForChild("UIKit"))
local PetView = require(modules:WaitForChild("PetView"))
local HatchShow = require(modules:WaitForChild("HatchShow"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local HatchEgg = remotes:WaitForChild("HatchEgg")
local PetAction = remotes:WaitForChild("PetAction")
local PaidHatch = remotes:WaitForChild("PaidHatch")
local HatchNews = remotes:WaitForChild("HatchNews")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local abbreviate, multText = Config.abbreviate, Config.multText
local INK_SOFT = Color3.fromRGB(70, 70, 100)
local GREEN, BLUE, RED = Color3.fromRGB(80, 200, 90), Color3.fromRGB(70, 140, 255), Color3.fromRGB(235, 90, 90)
local PURPLE, GOLD = Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 190, 40)
local OFF = Color3.fromRGB(150, 155, 175)

-- Egg window --------------------------------------------------------------------------------------
local eggWindow, eggList = UIKit.window("Egg", GREEN, UDim2.fromOffset(700, 398))
local eggTitle = UIKit.windowTitle(eggWindow)
local state = { egg = nil, prompt = nil, hatching = false, auto = false, count = 1, restricted = true }

-- the cards wrap into centered rows; `cards` is narrowed to force 3+3 / 4+3 for the big eggs
-- (both have a layout, so the window's opening animation still pops the cards one by one)
local cardsRow = make("Frame", { Parent = eggList, LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center }),
})
local cards = make("Frame", { Parent = cardsRow, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local cardRefs = {} -- [kind] = { mark, chip } for the auto-delete look

local function autoSet()
	local set = {}
	for kind in string.gmatch(player:GetAttribute("AutoDelete") or "", "%w+") do
		set[kind] = true
	end
	return set
end

local function canAutoDelete(kind)
	return Config.Rarities[Config.Pets[kind].rarity].order < Config.Rarities[Config.AUTO_DELETE_BELOW].order
end

local function refreshAutoDelete()
	local set = autoSet()
	for kind, r in pairs(cardRefs) do
		local on = set[kind] == true
		r.mark.Visible = on
		r.chip.BackgroundColor3 = on and RED or Color3.fromRGB(235, 235, 245)
	end
end

-- one card per pet of the egg: picture, name, rarity, money multiplier, chance
local function eggCard(egg, rank, kind, chance, tier)
	local pet = Config.Pets[kind]
	local color = PetView.rarityColor(pet.rarity)
	local card = make("TextButton", { Parent = cards, LayoutOrder = rank, Size = UDim2.fromOffset(118, 178), Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(16), UIKit.stroke(pet.top and 5 or 3.5, color) })
	make("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), UIKit.lighter(color, pet.rarity == "Secret" and 0.35 or 0.7)) })
	if Config.Rarities[pet.rarity].order >= Config.Rarities.Legendary.order then
		UIKit.rays(card, { Position = UDim2.fromOffset(59, 50), Size = UDim2.fromOffset(118, 118), Color = pet.rarity == "Secret" and Color3.fromRGB(200, 120, 255) or color, Transparency = 0.2, ZIndex = 12 })
	end
	local holder = make("Frame", { Parent = card, Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(106, 90), BackgroundTransparency = 1, ZIndex = 13 })
	PetView.viewport(holder, PetView.petModel(kind), { Size = UDim2.fromScale(1, 1), ZIndex = 13 })
	label({ Parent = card, Position = UDim2.fromOffset(4, 94), Size = UDim2.new(1, -8, 0, 24), Text = pet.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 13 })
	local r = label({ Parent = card, Position = UDim2.fromOffset(4, 118), Size = UDim2.new(1, -8, 0, 18), Text = pet.rarity, TextColor3 = pet.rarity == "Secret" and Color3.new(1, 1, 1) or color, StrokeThickness = pet.rarity == "Secret" and 2.5 or 1.5, ZIndex = 13 })
	if pet.rarity == "Secret" then
		r.TextColor3 = Color3.fromRGB(40, 20, 60)
		r:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(200, 120, 255)
	end
	-- (scaling pets: their bonus at your tier, and 📈 - it grows as you unlock eggs)
	label({ Parent = card, Position = UDim2.fromOffset(4, 137), Size = UDim2.new(1, -8, 0, 20), Text = multText(Config.petMult(kind, false, tier)) .. (pet.scales and " 📈" or " 💰"), TextColor3 = Color3.fromRGB(40, 170, 70), StrokeThickness = 0, ZIndex = 13 })
	local lucky = Config.luckFactor(player) > 1
	local pct = chance >= 1 and string.format("%.4g%%", chance) or string.format("%.2g%%", chance)
	label({ Parent = card, Position = UDim2.fromOffset(4, 157), Size = UDim2.new(1, -8, 0, 17), Text = (lucky and Config.Rarities[pet.rarity].order >= Config.Rarities.Epic.order and "🍀 " or "") .. pct, TextColor3 = lucky and Color3.fromRGB(40, 160, 70) or INK_SOFT, StrokeThickness = 0, ZIndex = 13 })
	if egg.robux or not canAutoDelete(kind) then
		return -- (paid pets are never auto-deleted)
	end
	-- auto-delete: a little 🗑 chip, and a red band over the picture while it's on
	local chip = make("TextLabel", { Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Color3.fromRGB(235, 235, 245), Text = "🗑", TextScaled = true, Font = UIKit.FONT, ZIndex = 15 }, { UIKit.corner(8) })
	local mark = make("Frame", { Parent = card, Position = UDim2.fromOffset(4, 36), Size = UDim2.new(1, -8, 0, 26), BackgroundColor3 = RED, BackgroundTransparency = 0.1, Visible = false, ZIndex = 15 }, { UIKit.corner(8) })
	label({ Parent = mark, Size = UDim2.fromScale(1, 1), Text = "AUTO-DELETE", ZIndex = 16, StrokeThickness = 2 })
	cardRefs[kind] = { mark = mark, chip = chip }
	card.Activated:Connect(function()
		UIKit.bounce(card)
		UIKit.result(PetAction:InvokeServer("autoDelete", kind))
	end)
end

-- the hatch bar sits pinned under the scrolling cards, so it never scrolls out of sight (phones):
-- toggles (⚡ Fast, 🔁 Auto, the luck you have now) over Hatch 1 / 3 / 8
local hatchRow = UIKit.row(eggWindow, 0, 112)
hatchRow.AnchorPoint = Vector2.new(0.5, 1)
hatchRow.Position = UDim2.new(0.5, 0, 1, -14)
hatchRow.Size = UDim2.new(1, -44, 0, 112)
eggList.Size = UDim2.new(1, -32, 1, -196)
local function pill(text, x)
	local b = make("TextButton", { Parent = hatchRow, Position = UDim2.fromOffset(x, 7), Size = UDim2.fromOffset(150, 30), BackgroundColor3 = OFF, Text = "", AutoButtonColor = false, ZIndex = 12 }, { UIKit.corner(15), UIKit.stroke(2.5) })
	local t = label({ Parent = b, Size = UDim2.fromScale(1, 1), Text = text, ZIndex = 13, StrokeThickness = 2 })
	return b, t
end
local fastBtn, fastText = pill("⚡ Fast: OFF", 14)
local autoBtn, autoText = pill("🔁 Auto: OFF", 172)
local luckLabel = label({ Parent = hatchRow, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 7), Size = UDim2.fromOffset(318, 30), TextXAlignment = Enum.TextXAlignment.Right, Text = "", TextColor3 = Color3.fromRGB(40, 160, 70), StrokeThickness = 0, ZIndex = 12 })
local lockLabel = label({ Parent = hatchRow, Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -32, 0, 58), Text = "", TextColor3 = RED, StrokeThickness = 0, ZIndex = 12, Visible = false })
local function hatchButton(color, i)
	return UIKit.button({ Parent = hatchRow, Text = "", Color = color, Position = UDim2.new((i - 1) / 3, i == 1 and 14 or 5, 0, 44), Size = UDim2.new(1 / 3, i == 2 and -10 or -19, 0, 60), ZIndex = 12 })
end
local hatch1 = hatchButton(GREEN, 1)
local hatch3 = hatchButton(BLUE, 2)
local hatch8 = hatchButton(PURPLE, 3)
local POS1, POS3 = hatch1.Instance.Position, hatch3.Instance.Position

local function currencyText(egg, n)
	if egg.currency == "Candy" then
		return "🍬 " .. abbreviate(n)
	elseif egg.currency == "Snowflakes" then
		return "❄ " .. abbreviate(n)
	end
	return "$" .. abbreviate(n)
end

local function timeLeft(sec)
	sec = math.max(0, math.floor(sec))
	local d, h, m = sec // 86400, (sec % 86400) // 3600, (sec % 3600) // 60
	if d > 0 then
		return string.format("%dd %02dh", d, h)
	end
	return string.format("%dh %02dm", h, m)
end

local function titleFor(egg)
	local t = egg.name
	if egg.currency then
		t ..= "   (you have " .. currencyText(egg, player:GetAttribute(egg.currency) or 0) .. ")"
	end
	if egg.limited then
		local _, ends = Config.limitedEgg()
		t ..= "   ⏳ " .. timeLeft(ends - workspace:GetServerTimeNow())
	end
	return t
end

local function refreshEggWindow()
	local egg = state.egg
	if not egg then
		return
	end
	local unlocked = (player:GetAttribute("UnlockedStage") or 1) >= egg.stage
	local fast = player:GetAttribute("FastHatch") == true
	fastBtn.BackgroundColor3 = fast and GOLD or OFF
	fastText.Text = fast and "⚡ Fast: ON" or "⚡ Fast: OFF"
	autoBtn.BackgroundColor3 = state.auto and GREEN or OFF
	autoText.Text = state.auto and "🔁 Auto: ON" or "🔁 Auto: OFF"
	autoBtn.Visible = not egg.robux
	local luck = Config.luckFactor(player)
	local lucky = Config.luckyHour()
	local parts = {}
	if Config.hasPass(player, "RainbowPets") then
		table.insert(parts, "🌈 " .. math.floor(Config.RAINBOW_CHANCE * 100) .. "% Rainbow")
	end
	if luck > 1 then
		table.insert(parts, "🍀 Luck x" .. (math.floor(luck * 10 + 0.5) / 10) .. (lucky and " (Lucky Hour!)" or ""))
	end
	luckLabel.Text = table.concat(parts, "  •  ")
	eggTitle.Text = titleFor(egg)
	if egg.robux then
		local p1, p3 = Config.getProduct("RoyalEgg1"), Config.getProduct("RoyalEgg3")
		lockLabel.Visible = state.restricted
		lockLabel.Text = "This egg isn't available where you live."
		hatch1.Instance.Visible = not state.restricted
		hatch3.Instance.Visible = not state.restricted
		hatch8.Instance.Visible = false
		hatch1.setText("Hatch 1  R$ " .. p1.robux)
		hatch3.setText("Hatch 3  R$ " .. p3.robux)
		hatch1.setColor(GOLD)
		hatch3.setColor(Color3.fromRGB(255, 150, 40))
		-- (two buttons: centered)
		hatch1.Instance.Position = UDim2.new(1 / 6, 5, 0, 44)
		hatch3.Instance.Position = UDim2.new(1 / 2, 5, 0, 44)
		return
	end
	hatch1.Instance.Position, hatch3.Instance.Position = POS1, POS3
	local price = Config.eggPrice(egg, player)
	local have = player:GetAttribute(egg.currency or "Money") or 0
	lockLabel.Visible = not unlocked
	lockLabel.Text = "🔒 Unlock Stage " .. egg.stage .. " to hatch this egg!"
	for _, b in ipairs({ hatch1, hatch3, hatch8 }) do
		b.Instance.Visible = unlocked
	end
	hatch1.setText("Hatch 1  " .. currencyText(egg, price))
	hatch3.setText("Hatch 3  " .. currencyText(egg, price * 3))
	local has8 = Config.hasPass(player, "Hatch8")
	hatch8.setText((has8 and "Hatch 8  " or "🔒 Hatch 8  ") .. currencyText(egg, price * 8))
	hatch1.setColor(have >= price and GREEN or RED)
	hatch3.setColor(have >= price * 3 and BLUE or RED)
	hatch8.setColor((not has8 or have >= price * 8) and PURPLE or RED)
end

local function openEgg(egg, promptPart)
	if egg.limited and Config.limitedEgg() ~= egg then
		egg = Config.limitedEgg() -- (the stand switched eggs while you walked up)
	end
	if state.egg ~= egg then
		state.auto = false
	end
	state.egg = egg
	state.prompt = promptPart
	local template = PetView.eggFolder and PetView.eggFolder:FindFirstChild(egg.id)
	UIKit.setWindowIcon(eggWindow, template and template:IsA("Model") and template or nil)
	for _, c in ipairs(cards:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(cardRefs)
	local tier = Config.playerTier(player)
	local chances = Config.eggChances(egg, Config.luckFactor(player))
	for rank, kind in ipairs(egg.pets) do
		eggCard(egg, rank, kind, chances[rank], tier)
	end
	refreshAutoDelete()
	-- 6-7 pets: two rows (3+3 / 4+3) in a taller window, so the hatch buttons stay in view
	local n = #egg.pets
	cards.Size = n == 6 and UDim2.fromOffset(380, 0) or n == 7 and UDim2.fromOffset(504, 0) or UDim2.new(1, 0, 0, 0)
	local design = Vector2.new(700, n > 5 and 582 or 398)
	local reopen = false
	if eggWindow:GetAttribute("DesignSize") ~= design then
		eggWindow:SetAttribute("DesignSize", design)
		if eggWindow.Visible then
			UIKit.close(eggWindow) -- (opens again below at the new size)
			reopen = true
		end
	end
	refreshEggWindow()
	if reopen or not eggWindow.Visible then
		UIKit.toggle(eggWindow)
	end
end

-- Hatching ---------------------------------------------------------------------------------------
local function indexSet()
	local set = {}
	for kind in string.gmatch(player:GetAttribute("PetIndex") or "", "%w+") do
		set[kind] = true
	end
	return set
end

-- the show; NEW! = a kind that wasn't in your Index before this hatch
local function playHatch(egg, results, before)
	state.hatching = true
	local eggWasOpen = eggWindow.Visible
	eggWindow.Visible = false -- the show gets the whole screen
	HatchShow.play(egg, results, {
		petModel = PetView.petModel,
		eggModel = PetView.eggModel,
		fast = player:GetAttribute("FastHatch") == true,
		tier = Config.playerTier(player),
		isNew = function(kind)
			return not before[kind]
		end,
	})
	eggWindow.Visible = eggWasOpen and state.egg == egg
	state.hatching = false
	refreshEggWindow()
end

local function doHatch(count)
	local egg = state.egg
	if not egg or state.hatching or HatchShow.busy() then
		return false
	end
	state.hatching = true
	state.count = count
	local before = indexSet()
	local ok, results = HatchEgg:InvokeServer(egg.id, count)
	if ok then
		playHatch(egg, results, before)
		return true
	end
	state.hatching = false
	if state.auto then
		state.auto = false
		refreshEggWindow()
		UIKit.result(false, results .. " (Auto stopped)")
	else
		UIKit.result(false, results)
	end
	return false
end

-- 🔁 Auto: hatch again after each show while the window is open
local function autoLoop()
	while state.auto and state.egg and eggWindow.Visible do
		if not doHatch(state.count) then
			break
		end
		task.wait(0.15)
	end
	state.auto = false
	refreshEggWindow()
end

local function promptPass(key, what)
	for _, p in ipairs(Config.Gamepasses) do
		if p.key == key then
			if p.id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, p.id)
			else
				UIKit.toast(what .. " is coming soon!", Color3.fromRGB(255, 220, 120))
			end
			return
		end
	end
end

local function buyRoyal(key)
	local product = Config.getProduct(key)
	if state.restricted then
		return
	end
	if not product or product.id == 0 then
		UIKit.toast("The Royal Treasure Egg is coming soon!", Color3.fromRGB(255, 220, 120))
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
end

hatch1.Instance.Activated:Connect(function()
	if state.egg and state.egg.robux then
		buyRoyal("RoyalEgg1")
	else
		doHatch(1)
	end
end)
hatch3.Instance.Activated:Connect(function()
	if state.egg and state.egg.robux then
		buyRoyal("RoyalEgg3")
	else
		doHatch(3)
	end
end)
hatch8.Instance.Activated:Connect(function()
	if not Config.hasPass(player, "Hatch8") then
		promptPass("Hatch8", "The Hatch 8 pass")
		return
	end
	doHatch(8)
end)
fastBtn.Activated:Connect(function()
	UIKit.sound("Click", 0.4)
	PetAction:InvokeServer("fastHatch", not (player:GetAttribute("FastHatch") == true))
	refreshEggWindow()
end)
autoBtn.Activated:Connect(function()
	UIKit.sound("Click", 0.4)
	if not Config.hasPass(player, "AutoHatch") then
		promptPass("AutoHatch", "The Auto Hatch pass")
		return
	end
	state.auto = not state.auto
	refreshEggWindow()
	if state.auto then
		task.spawn(autoLoop)
	end
end)

-- Royal egg: the server hatched it after the purchase
local paidQueue = {}
PaidHatch.OnClientEvent:Connect(function(eggId, results)
	table.insert(paidQueue, { egg = Config.getEgg(eggId), results = results })
	if #paidQueue > 1 then
		return
	end
	while #paidQueue > 0 do
		while state.hatching or HatchShow.busy() do
			task.wait(0.2)
		end
		local job = paidQueue[1]
		if job.egg then
			-- (the server already added them to the Index: everything Legendary+ counts as new-looking)
			playHatch(job.egg, job.results, {})
		end
		table.remove(paidQueue, 1)
	end
end)

task.spawn(function()
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	state.restricted = not ok or info.ArePaidRandomItemsRestricted == true
	refreshEggWindow()
end)

-- Egg prompts + walking away -------------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local id = prompt:GetAttribute("Egg")
	local egg = id and Config.getEgg(id)
	if egg then
		openEgg(egg, prompt.Parent)
	end
end)

local titleClock = 0
RunService.Heartbeat:Connect(function(dt)
	if not state.prompt or state.hatching then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not eggWindow.Visible then
		state.prompt = nil
		state.egg = nil
		state.auto = false
	elseif root and state.prompt.Parent and (root.Position - state.prompt.Position).Magnitude > 22 then
		UIKit.close(eggWindow)
		state.prompt = nil
		state.egg = nil
		state.auto = false
	else
		titleClock += dt
		if titleClock > 1 then -- (timers in the title, Lucky Hour)
			titleClock = 0
			refreshEggWindow()
		end
	end
end)

for _, attr in ipairs({ "Money", "UnlockedStage", "Candy", "Snowflakes", "Pass_Hatch8", "Pass_AutoHatch", "Pass_LuckyEggs", "Pass_RainbowPets", "FastHatch" }) do
	player:GetAttributeChangedSignal(attr):Connect(refreshEggWindow)
end
player:GetAttributeChangedSignal("AutoDelete"):Connect(refreshAutoDelete)

-- Rare hatches: one plain line in chat ------------------------------------------------------------
HatchNews.OnClientEvent:Connect(function(text)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(text)
		end
	end)
end)
