-- Trading pets (client). The server (TradeServer) decides everything; this only shows it.
--   * PETS -> 🔁 Trade: the players in this server, a Trade button each, and trade requests on / off.
--   * An invite pops up at the top: Accept / Decline.
--   * Trade window: your offer and theirs (up to 8 pets each), your pets below (tap to add, tap an
--     offered pet to take it back), Ready. When both are ready a 3 second countdown runs; any change
--     un-readies both. Closing the window cancels the trade.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local modules = script.Parent:WaitForChild("ClientModules")
local UIKit = require(modules:WaitForChild("UIKit"))
local PetView = require(modules:WaitForChild("PetView"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local TradeRequest = remotes:WaitForChild("TradeRequest")
local TradeRespond = remotes:WaitForChild("TradeRespond")
local TradeAction = remotes:WaitForChild("TradeAction")
local TradeInvite = remotes:WaitForChild("TradeInvite")
local TradeState = remotes:WaitForChild("TradeState")
local PetAction = remotes:WaitForChild("PetAction")

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local ORANGE = Color3.fromRGB(255, 160, 50)
local GREEN, RED, GREY = Color3.fromRGB(80, 200, 90), Color3.fromRGB(235, 90, 90), Color3.fromRGB(150, 155, 175)
local INK_SOFT = Color3.fromRGB(70, 70, 100)

-- a small pet card (picture + bonus), optionally tappable
local function miniCard(parent, pet, order, tier, onTap)
	local info = Config.Pets[pet.kind]
	local color = pet.golden and PetView.GOLD or PetView.rarityColor(info.rarity)
	local card = make("TextButton", { Parent = parent, LayoutOrder = order, Size = UDim2.fromOffset(78, 96), Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 13 }, { UIKit.corner(12), UIKit.stroke(3, color) })
	make("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), UIKit.lighter(color, 0.72)) })
	local holder = make("Frame", { Parent = card, Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(70, 62), BackgroundTransparency = 1, ZIndex = 14 })
	PetView.viewport(holder, PetView.petModel(pet.kind, pet.golden), { Size = UDim2.fromScale(1, 1), ZIndex = 14 })
	label({ Parent = card, Position = UDim2.fromOffset(2, 64), Size = UDim2.new(1, -4, 0, 15), Text = (pet.golden and "⭐ " or "") .. info.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 14 })
	label({ Parent = card, Position = UDim2.fromOffset(2, 79), Size = UDim2.new(1, -4, 0, 14), Text = Config.multText(Config.petMult(pet.kind, pet.golden, tier)) .. (info.scales and " 📈" or ""), TextColor3 = Color3.fromRGB(40, 170, 70), StrokeThickness = 0, ZIndex = 14 })
	if onTap then
		card.Activated:Connect(function()
			UIKit.sound("Click", 0.4)
			UIKit.bounce(card)
			onTap()
		end)
	end
	return card
end

local function grid(parent, props, cell)
	return make("Frame", props, {
		make("UIGridLayout", { CellSize = cell or UDim2.fromOffset(78, 96), CellPadding = UDim2.fromOffset(6, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- Player list ------------------------------------------------------------------------------------
local listWindow, listList = UIKit.window("Trade Pets", ORANGE, UDim2.fromOffset(560, 470), "Paw")
local optRow = UIKit.row(listList, 0, 62)
label({ Parent = optRow, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -220, 1, -16), TextXAlignment = Enum.TextXAlignment.Left, Text = "Trade pets with players in this server!", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
local optBtn = UIKit.button({ Parent = optRow, Text = "", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(196, 46), ZIndex = 12 })
local playerRows = {}

local function refreshOpt()
	local off = player:GetAttribute("TradesOff") == true
	optBtn.setText(off and "Requests: OFF" or "Requests: ON")
	optBtn.setColor(off and GREY or GREEN)
end
optBtn.Instance.Activated:Connect(function()
	PetAction:InvokeServer("tradesOff", not (player:GetAttribute("TradesOff") == true))
end)
player:GetAttributeChangedSignal("TradesOff"):Connect(refreshOpt)
refreshOpt()

local function refreshPlayers()
	for _, r in pairs(playerRows) do
		r:Destroy()
	end
	table.clear(playerRows)
	local others = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			table.insert(others, p)
		end
	end
	table.sort(others, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	if #others == 0 then
		local r = UIKit.row(listList, 1, 90)
		label({ Parent = r, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 1, -20), Text = "Nobody else is here yet - invite a friend! 👥", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
		table.insert(playerRows, r)
		return
	end
	for i, p in ipairs(others) do
		local r = UIKit.row(listList, i, 62)
		label({ Parent = r, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -200, 1, -16), TextXAlignment = Enum.TextXAlignment.Left, Text = p.DisplayName .. "   •  Stage " .. (p:GetAttribute("UnlockedStage") or 1), TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
		local b = UIKit.button({ Parent = r, Text = p:GetAttribute("TradesOff") and "Off" or "Trade", Color = p:GetAttribute("TradesOff") and GREY or ORANGE, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 46), ZIndex = 12 })
		b.Instance.Activated:Connect(function()
			UIKit.result(TradeRequest:InvokeServer(p.UserId))
		end)
		table.insert(playerRows, r)
	end
end
Players.PlayerAdded:Connect(function()
	if listWindow.Visible then
		refreshPlayers()
	end
end)
Players.PlayerRemoving:Connect(function()
	task.defer(function()
		if listWindow.Visible then
			refreshPlayers()
		end
	end)
end)
script.Parent:WaitForChild("OpenTradeList").Event:Connect(function()
	refreshPlayers()
	if not listWindow.Visible then
		UIKit.toggle(listWindow)
	end
end)

-- Invite popup -------------------------------------------------------------------------------------
local invite = make("Frame", { Parent = UIKit.gui(), Name = "TradeInvite", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(440, 118), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 40 }, { UIKit.corner(20), UIKit.stroke(4) })
UIKit.hudScale(invite)
make("UIGradient", { Parent = invite, Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), UIKit.lighter(ORANGE, 0.6)) })
local inviteText = label({ Parent = invite, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 40), Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 41 })
local acceptBtn = UIKit.button({ Parent = invite, Text = "Accept", Color = GREEN, Position = UDim2.fromOffset(14, 56), Size = UDim2.new(0.5, -20, 0, 50), ZIndex = 41 })
local declineBtn = UIKit.button({ Parent = invite, Text = "Decline", Color = RED, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 56), Size = UDim2.new(0.5, -20, 0, 50), ZIndex = 41 })
local inviteFrom, inviteSeq = nil, 0

local function answer(accept)
	invite.Visible = false
	if inviteFrom then
		local from = inviteFrom
		inviteFrom = nil
		local ok, msg = TradeRespond:InvokeServer(from, accept)
		if not ok then
			UIKit.result(false, msg)
		end
	end
end
acceptBtn.Instance.Activated:Connect(function()
	answer(true)
end)
declineBtn.Instance.Activated:Connect(function()
	answer(false)
end)
TradeInvite.OnClientEvent:Connect(function(fromUserId, fromName)
	inviteFrom = fromUserId
	inviteSeq += 1
	local seq = inviteSeq
	inviteText.Text = "🔁 " .. fromName .. " wants to trade!"
	invite.Visible = true
	UIKit.bounce(invite)
	UIKit.sound("Pop", 0.5)
	task.delay(18, function()
		if inviteSeq == seq and invite.Visible then
			answer(false)
		end
	end)
end)

-- Trade window -------------------------------------------------------------------------------------
local tradeWindow, tradeList = UIKit.window("Trade", ORANGE, UDim2.fromOffset(760, 600), "Paw")
local tradeTitle = UIKit.windowTitle(tradeWindow)
local offersRow = UIKit.row(tradeList, 0, 268)
local function side(x, title)
	local panel = make("Frame", { Parent = offersRow, Position = UDim2.new(x, x == 0 and 8 or 4, 0, 8), Size = UDim2.new(0.5, -12, 1, -16), BackgroundColor3 = Color3.fromRGB(245, 247, 255), ZIndex = 12 }, { UIKit.corner(14), UIKit.stroke(2.5, Color3.fromRGB(190, 200, 225)) })
	local head = label({ Parent = panel, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Text = title, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 13 })
	local status = label({ Parent = panel, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4), Size = UDim2.fromOffset(130, 28), TextXAlignment = Enum.TextXAlignment.Right, Text = "", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 13 })
	local g = grid(panel, { Parent = panel, Position = UDim2.fromOffset(6, 36), Size = UDim2.new(1, -12, 1, -42), BackgroundTransparency = 1, ZIndex = 13 })
	return { head = head, status = status, grid = g }
end
local mine = side(0, "Your offer")
local theirs = side(0.5, "Their offer")
local pickRow = UIKit.row(tradeList, 1, 40)
label({ Parent = pickRow, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 1, -12), TextXAlignment = Enum.TextXAlignment.Left, Text = "Your pets: tap to add (🔒 locked pets can't be traded)", TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
local myPets = grid(tradeList, { Parent = tradeList, LayoutOrder = 2, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 12 })
-- pinned bottom bar: countdown / status, Ready, Cancel
local bar = UIKit.row(tradeWindow, 0, 74)
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -14)
bar.Size = UDim2.new(1, -44, 0, 74)
tradeList.Size = UDim2.new(1, -32, 1, -164)
local statusText = label({ Parent = bar, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -380, 1, -20), TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
local readyBtn = UIKit.button({ Parent = bar, Text = "Ready", Color = GREEN, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -184, 0.5, 0), Size = UDim2.fromOffset(170, 54), ZIndex = 12 })
local cancelBtn = UIKit.button({ Parent = bar, Text = "Cancel", Color = RED, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(160, 54), ZIndex = 12 })

local current = nil -- the last state from the server (nil = not trading)
local countdownEnds = nil

local function refreshMyPets()
	clear(myPets)
	if not current then
		return
	end
	local offered = {}
	for _, p in ipairs(current.you) do
		offered[p.uid] = true
	end
	local tier = Config.playerTier(player)
	local list = Config.parsePets(player:GetAttribute("Pets"))
	table.sort(list, function(a, b)
		local ma, mb = Config.petMult(a.kind, a.golden, tier), Config.petMult(b.kind, b.golden, tier)
		if ma ~= mb then
			return ma > mb
		end
		return a.uid < b.uid
	end)
	for i, p in ipairs(list) do
		local card = miniCard(myPets, p, i, tier, function()
			if p.locked then
				UIKit.toast("🔒 Locked pets can't be traded. Unlock it in PETS first.", Color3.fromRGB(255, 200, 150))
				return
			end
			local ok, msg = TradeAction:InvokeServer(offered[p.uid] and "remove" or "add", p.uid)
			if not ok then
				UIKit.result(false, msg)
			end
		end)
		if p.locked or offered[p.uid] then
			card.BackgroundTransparency = 0.5
			label({ Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(22, 22), Text = p.locked and "🔒" or "✔", TextColor3 = GREEN, ZIndex = 16 })
		end
	end
end

local function refreshTrade()
	if not current then
		return
	end
	tradeTitle.Text = "Trade with " .. current.partner
	theirs.head.Text = current.partner .. "'s offer"
	local tier = Config.playerTier(player)
	clear(mine.grid)
	for i, p in ipairs(current.you) do
		miniCard(mine.grid, p, i, tier, function()
			TradeAction:InvokeServer("remove", p.uid)
		end)
	end
	clear(theirs.grid)
	for i, p in ipairs(current.them) do
		miniCard(theirs.grid, p, i, tier, nil)
	end
	mine.status.Text = current.youReady and "✔ Ready" or ""
	mine.status.TextColor3 = GREEN
	theirs.status.Text = current.themReady and "✔ Ready" or "Not ready"
	theirs.status.TextColor3 = current.themReady and GREEN or INK_SOFT
	readyBtn.setText(current.youReady and "Not ready" or "Ready")
	readyBtn.setColor(current.youReady and GREY or GREEN)
	countdownEnds = current.countdown and (os.clock() + current.countdown) or nil
	if not countdownEnds then
		statusText.Text = (#current.you + #current.them == 0) and "Add pets, then both press Ready." or (current.youReady and ("Waiting for " .. current.partner .. "...") or "Changing the offer un-readies both.")
	end
	refreshMyPets()
end

task.spawn(function()
	while true do
		if countdownEnds and current then
			statusText.Text = "Trading in " .. math.max(0, math.ceil(countdownEnds - os.clock())) .. "..."
		end
		task.wait(0.2)
	end
end)

TradeState.OnClientEvent:Connect(function(state, message)
	if not state then
		current = nil
		countdownEnds = nil
		if tradeWindow.Visible then
			UIKit.close(tradeWindow)
		end
		if message and message ~= "" then
			UIKit.toast(message, Color3.fromRGB(255, 210, 140))
		end
		return
	end
	local opening = current == nil
	current = state
	invite.Visible = false
	refreshTrade()
	if opening and not tradeWindow.Visible then
		UIKit.toggle(tradeWindow)
	end
end)

readyBtn.Instance.Activated:Connect(function()
	if not current then
		return
	end
	local ok, msg = TradeAction:InvokeServer(current.youReady and "unready" or "ready")
	if not ok then
		UIKit.result(false, msg)
	end
end)
cancelBtn.Instance.Activated:Connect(function()
	TradeAction:InvokeServer("cancel")
end)
-- closing the window (X, or opening another window) cancels the trade
tradeWindow:GetPropertyChangedSignal("Visible"):Connect(function()
	if not tradeWindow.Visible and current then
		TradeAction:InvokeServer("cancel")
	end
end)
player:GetAttributeChangedSignal("Pets"):Connect(function()
	if current then
		refreshMyPets()
	end
end)
