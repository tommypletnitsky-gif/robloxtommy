-- Rebirth (client): the window at the Rebirth Portal (walk up, press E), a rebirth badge on the HUD
-- (gold + one toast when you can rebirth) and the celebration when you rebirth. The server does the
-- actual reset (GameServer "Rebirth").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))
local RebirthRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local PURPLE = Color3.fromRGB(165, 105, 245)
local GOLD = Color3.fromRGB(255, 190, 40)
local GREEN = Color3.fromRGB(80, 200, 90)
local GREY = Color3.fromRGB(160, 165, 185)

local function rebirths()
	return player:GetAttribute("Rebirths") or 0
end

-- Window ------------------------------------------------------------------------------------------
-- NOW → NEXT hero tiles (the next one glowing gold on rays), the stage you need with a bar,
-- KEEP vs STARTS OVER side by side, then the big button.
local window, list = UIKit.window("Rebirth", PURPLE, UDim2.fromOffset(640, 520), "Trophy")
local RED = Color3.fromRGB(235, 85, 85)

local hero = make("Frame", { Parent = list, LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 136), BackgroundTransparency = 1, ZIndex = 11 })
local function heroTile(x, color, tag)
	local tile = make("Frame", { Parent = hero, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, 0), Size = UDim2.fromOffset(220, 120), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(22), UIKit.stroke(4), UIKit.gloss(color) })
	UIKit.pill(tile, { Text = tag, Color = UIKit.darker(color, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(84, 28), ZIndex = 14 })
	local title = label({ Parent = tile, Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -20, 0, 44), Text = "", ZIndex = 14, StrokeThickness = 3.5 })
	local sub = label({ Parent = tile, Position = UDim2.fromOffset(10, 68), Size = UDim2.new(1, -20, 0, 34), Text = "", ZIndex = 14, StrokeThickness = 3 })
	return tile, title, sub
end
local _, nowTitle, nowSub = heroTile(-150, Color3.fromRGB(150, 140, 200), "NOW")
UIKit.rays(hero, { Position = UDim2.new(0.5, 150, 0.5, 0), Size = UDim2.fromOffset(250, 250), Color = Color3.fromRGB(255, 220, 90), Transparency = 0.25, ZIndex = 11 })
local _, nextTitle, nextSub = heroTile(150, GOLD, "NEXT")
local arrow = make("Frame", { Parent = hero, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 15 }, { UIKit.corner(28), UIKit.stroke(4), UIKit.gloss(GREEN) })
label({ Parent = arrow, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), Text = "→", ZIndex = 16 })

local needRow = UIKit.row(list, 2, 70)
local needText = label({ Parent = needRow, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 26), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
local _, setNeed = UIKit.bar(needRow, { Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 22), Color = PURPLE, ShowText = true, ZIndex = 12 })

local sides = make("Frame", { Parent = list, LayoutOrder = 3, Size = UDim2.new(1, -12, 0, 114), BackgroundTransparency = 1, ZIndex = 11 })
local function sideCard(x, color, title)
	local c = UIKit.card(sides, { Size = UDim2.new(0.5, -6, 1, 0), ZIndex = 11, Border = color, Tint = UIKit.lighter(color, 0.82) })
	c.Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0)
	c:FindFirstChildOfClass("UIStroke").Thickness = 4
	local head = make("Frame", { Parent = c, Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(20), UIKit.gloss(color) })
	label({ Parent = head, Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -20, 1, -10), Text = title, ZIndex = 13, StrokeThickness = 3 })
	local body = label({ Parent = c, Position = UDim2.fromOffset(14, 44), Size = UDim2.new(1, -28, 1, -50), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, TextScaled = false, TextSize = 25, TextWrapped = true, LineHeight = 1.15, ZIndex = 12 })
	return body
end
local keepText = sideCard(0, GREEN, "✅ YOU KEEP")
local loseText = sideCard(0.5, RED, "🔄 STARTS OVER")
loseText.Text = "💰 Money   🗺️ Stages\n🚀 Rockets   ⬆️ Upgrades"

local buttonRow = make("Frame", { Parent = list, LayoutOrder = 5, Size = UDim2.new(1, -12, 0, 72), BackgroundTransparency = 1, ZIndex = 11 })
local rebirthBtn = UIKit.button({ Parent = buttonRow, Text = "", Color = GREEN, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.7, 0, 0, 64), Radius = 24, ZIndex = 12 })
rebirthBtn.Instance.Name = "RebirthGo"

local armedAt = 0 -- first click arms, second click (within 3 s) rebirths

local function refresh()
	local n = rebirths()
	local need = Config.rebirthStage(n)
	local stage = player:GetAttribute("UnlockedStage") or 1
	local ready = stage >= need
	nowTitle.Text = "Rebirth " .. n
	nowSub.Text = "💰 x" .. Config.rebirthMultiplier(n) .. " money"
	nextTitle.Text = "Rebirth " .. (n + 1)
	nextSub.Text = "💰 x" .. Config.rebirthMultiplier(n + 1) .. " money"
	needText.Text = ready and "✅ You can rebirth!" or ("🔒 Unlock Stage " .. need .. " to rebirth")
	setNeed(math.clamp(stage / need, 0.03, 1), "Stage " .. math.min(stage, need) .. " / " .. need)
	local slotsNow, slotsNext = Config.petSlots(n), Config.petSlots(n + 1)
	keepText.Text = "🐾 Pets   ✨ Trails"
		.. (slotsNext > slotsNow and ("\n➕ Pet slots " .. slotsNow .. " → " .. slotsNext) or "\n📖 Pet Index")
	UIKit.claimable(rebirthBtn, ready and os.clock() - armedAt >= 3)
	if not ready then
		rebirthBtn.setText("🔒 Unlock Stage " .. need .. " first")
		rebirthBtn.setColor(GREY)
	elseif os.clock() - armedAt < 3 then
		rebirthBtn.setText("Sure? Click again!")
		rebirthBtn.setColor(Color3.fromRGB(255, 150, 40))
	else
		rebirthBtn.setText("🌟 REBIRTH!")
	end
end

-- Celebration -------------------------------------------------------------------------------------
local gui = UIKit.gui()
local function celebrate(n)
	UIKit.celebrate("🌟 REBIRTH " .. n .. "! 🌟", "Money x" .. Config.rebirthMultiplier(n) .. " forever!", GOLD)
end

rebirthBtn.Instance.Activated:Connect(function()
	local n = rebirths()
	if (player:GetAttribute("UnlockedStage") or 1) < Config.rebirthStage(n) then
		UIKit.result(false, "Unlock Stage " .. Config.rebirthStage(n) .. " to rebirth!")
		return
	end
	if os.clock() - armedAt > 3 then
		armedAt = os.clock()
		refresh()
		task.delay(3.1, refresh)
		return
	end
	armedAt = 0
	local ok, msg = RebirthRemote:InvokeServer()
	if ok then
		UIKit.close(window)
		celebrate(n + 1) -- (the attribute may not have arrived yet)
	else
		UIKit.result(false, msg)
	end
	refresh()
end)

-- HUD badge (lobby only): your rebirths and their money bonus, gold once you can rebirth -----------
local badge = make("Frame", { Parent = gui, Name = "RebirthBadge", Position = UDim2.fromOffset(256, 139), Size = UDim2.fromOffset(170, 44), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, { UIKit.corner(22), UIKit.stroke(3.5), UIKit.gloss(PURPLE) })
local badgeText = label({ Parent = badge, Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -24, 1, -10), Text = "", StrokeThickness = 3 })
local badgeScale = UIKit.hudScale(badge) -- (RocketClient places it beside the best pill)
local badgeGloss = badge:FindFirstChildOfClass("UIGradient")
local PURPLE_GLOSS, GOLD_GLOSS = badgeGloss.Color, UIKit.gloss(GOLD).Color
local wasReady = nil -- (nil until your save has loaded: a save that loads ready gets no cue)

-- just became ready: once the screen is free, pop the badge and say it once (silent toast)
local function readyCue(n)
	UIKit.whenFree(function()
		if rebirths() ~= n or (player:GetAttribute("UnlockedStage") or 1) < Config.rebirthStage(n) then
			return -- (rebirthed or reset meanwhile)
		end
		badgeScale.Scale = UIKit.hudFactor() * 0.75 -- (bounce the HudScale: it is the badge's only UIScale)
		UIKit.spr.target(badgeScale, 0.4, 4, { Scale = UIKit.hudFactor() })
		UIKit.toast("🌟 REBIRTH unlocked! Visit the portal by the spawn: money x" .. Config.rebirthMultiplier(n + 1) .. " forever", GOLD)
	end)
end

local function refreshBadge()
	local n = rebirths()
	local ready = (player:GetAttribute("UnlockedStage") or 1) >= Config.rebirthStage(n)
	badge.Visible = (n > 0 or ready) and not player:GetAttribute("Flying")
	badgeText.Text = n == 0 and "🌟 REBIRTH READY" or ("🌟 " .. n .. "  •  x" .. Config.rebirthMultiplier(n) .. (ready and " ✨" or ""))
	badgeGloss.Color = ready and GOLD_GLOSS or PURPLE_GLOSS
	-- (only a real change after your save loaded; the stage drops back to 1 when you rebirth)
	if ready and wasReady == false then
		readyCue(n)
	end
	if wasReady ~= nil then
		wasReady = ready
	end
end

for _, attr in ipairs({ "Rebirths", "UnlockedStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		refresh()
		refreshBadge()
	end)
end
player:GetAttributeChangedSignal("Flying"):Connect(refreshBadge)
refresh()
refreshBadge()
-- the loaded save is the baseline (its values and DataLoaded arrive together, so no join cue)
task.spawn(function()
	repeat
		task.wait(0.2)
	until player:GetAttribute("DataLoaded")
	wasReady = (player:GetAttribute("UnlockedStage") or 1) >= Config.rebirthStage(rebirths())
end)

-- Open at the portal, close when you walk away -----------------------------------------------------
local openedAt = nil
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute("OpenWindow") == "Rebirth" and not window.Visible then
		refresh()
		UIKit.toggle(window)
		openedAt = prompt.Parent
	end
end)
RunService.Heartbeat:Connect(function()
	if not openedAt then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not window.Visible then
		openedAt = nil
	elseif root and openedAt.Parent and (root.Position - openedAt.Position).Magnitude > 24 then
		UIKit.close(window)
		openedAt = nil
	end
end)
