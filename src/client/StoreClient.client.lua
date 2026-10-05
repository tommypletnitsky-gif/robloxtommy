-- Robux store: the gamepasses (Config.Gamepasses) as big cards, opened from the STORE button.
-- Also: the gold [VIP] tag in chat for VIP players.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UIKit = require(script.Parent:WaitForChild("ClientModules"):WaitForChild("UIKit"))

local player = Players.LocalPlayer
local make, label = UIKit.make, UIKit.label
local GOLD = Color3.fromRGB(255, 185, 40)
local GREEN, GREY = Color3.fromRGB(80, 200, 90), Color3.fromRGB(160, 165, 185)
local INK_SOFT = Color3.fromRGB(70, 70, 100)

local storeBtn = UIKit.button({ Parent = UIKit.bottomBar(), LayoutOrder = 6, Icon3D = "Crown", Icon = "👑", Text = "STORE", Color = GOLD, Size = UDim2.fromOffset(104, 104), Radius = 24 })
local window, list = UIKit.window("Store", GOLD, UDim2.fromOffset(760, 520), "Crown")

local head = UIKit.row(list, 0, 52)
label({ Parent = head, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), Text = "Gamepasses last forever and help us make the game bigger! ❤", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })

local grid = make("Frame", { Parent = list, LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIGridLayout", { CellSize = UDim2.fromOffset(340, 172), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})

local cards = {}
for i, pass in ipairs(Config.Gamepasses) do
	local card = UIKit.card(grid, { LayoutOrder = i, ZIndex = 11, Tint = UIKit.lighter(pass.color, 0.7), Border = pass.color })
	local iconBox = make("Frame", { Parent = card, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(100, 100), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, { UIKit.corner(24), UIKit.stroke(3.5), UIKit.gloss(pass.color) })
	make("Frame", { Parent = iconBox, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, Position = UDim2.new(0.1, 0, 0.07, 0), Size = UDim2.new(0.8, 0, 0.28, 0), ZIndex = 12 }, { UIKit.corner(14) })
	if ReplicatedStorage:FindFirstChild("UIIcons") and ReplicatedStorage.UIIcons:FindFirstChild(pass.icon) then
		UIKit.icon3D(iconBox, pass.icon, { ZIndex = 13 })
	end
	label({ Parent = card, Position = UDim2.fromOffset(124, 12), Size = UDim2.new(1, -136, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, Text = pass.name, TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
	label({ Parent = card, Position = UDim2.fromOffset(124, 46), Size = UDim2.new(1, -136, 0, 66), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 17, TextWrapped = true, Text = pass.desc, TextColor3 = INK_SOFT, StrokeThickness = 0, ZIndex = 12 })
	local button = UIKit.button({ Parent = card, Text = "", Color = GREEN, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 50), ZIndex = 12 })
	button.Instance.Activated:Connect(function()
		if Config.hasPass(player, pass.key) then
			UIKit.toast("You already own " .. pass.name .. "! ✔", Color3.fromRGB(130, 255, 130))
		elseif pass.id == 0 then
			UIKit.toast(pass.name .. " is coming soon!", Color3.fromRGB(255, 230, 120))
		else
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end
	end)
	cards[pass.key] = { pass = pass, button = button, price = pass.robux }
end

-- Support the game: Robux donations (developer products, Config.Donations). Top supporters show
-- on the leaderboard in the lobby.
local TEAL = Color3.fromRGB(40, 190, 200)
local supportHead = UIKit.row(list, 2, 70)
local heartBox = make("Frame", { Parent = supportHead, Position = UDim2.fromOffset(6, 2), Size = UDim2.fromOffset(66, 66), BackgroundTransparency = 1, ZIndex = 12 })
if ReplicatedStorage:FindFirstChild("UIIcons") and ReplicatedStorage.UIIcons:FindFirstChild("Heart") then
	UIKit.icon3D(heartBox, "Heart", { ZIndex = 13 })
end
label({ Parent = supportHead, Position = UDim2.fromOffset(80, 8), Size = UDim2.new(1, -96, 1, -16), TextXAlignment = Enum.TextXAlignment.Left, Text = "Support the game! Top supporters are shown on the board in the lobby.", TextColor3 = UIKit.INK, StrokeThickness = 0, ZIndex = 12 })
local donateRow = make("Frame", { Parent = list, LayoutOrder = 3, Size = UDim2.new(1, -12, 0, 66), BackgroundTransparency = 1, ZIndex = 11 }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})
for i, d in ipairs(Config.Donations) do
	local b = UIKit.button({ Parent = donateRow, LayoutOrder = i, Text = "❤ R$ " .. d.robux, Color = d.id ~= 0 and TEAL or GREY, Size = UDim2.fromOffset(128, 58), ZIndex = 12 })
	b.Instance.Activated:Connect(function()
		if d.id == 0 then
			UIKit.toast("Donations open soon!", Color3.fromRGB(255, 230, 120))
		else
			MarketplaceService:PromptProductPurchase(player, d.id)
		end
	end)
end

local function refresh()
	for key, c in pairs(cards) do
		if Config.hasPass(player, key) then
			c.button.setText("✔ OWNED")
			c.button.setColor(GREY)
		elseif c.pass.id == 0 then
			c.button.setText("R$ " .. c.price .. "  •  SOON")
			c.button.setColor(GREY)
		else
			c.button.setText("R$ " .. c.price)
			c.button.setColor(GREEN)
		end
	end
end
for _, pass in ipairs(Config.Gamepasses) do
	player:GetAttributeChangedSignal("Pass_" .. pass.key):Connect(refresh)
end
refresh()

-- real Robux prices once the passes exist
task.spawn(function()
	for _, c in pairs(cards) do
		if c.pass.id ~= 0 then
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, c.pass.id, Enum.InfoType.GamePass)
			if ok and info and info.PriceInRobux then
				c.price = info.PriceInRobux
			end
		end
	end
	refresh()
end)

storeBtn.Instance.Activated:Connect(function()
	refresh()
	UIKit.toggle(window)
end)

-- [VIP] in chat
pcall(function()
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local src = message.TextSource
		local who = src and Players:GetPlayerByUserId(src.UserId)
		if who and Config.hasPass(who, "VIP") then
			props.PrefixText = '<font color="#FFC832">[👑 VIP]</font> ' .. message.PrefixText
		end
		return props
	end
end)
