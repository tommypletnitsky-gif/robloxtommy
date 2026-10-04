-- Free timed gifts, daily login reward, global leaderboards (richest + top donators), Robux donations.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(game:GetService("ServerScriptService").PlayerData)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(className, name)
	local r = remotes:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local ClaimGift = remote("RemoteFunction", "ClaimGift") -- (index)
local ClaimDaily = remote("RemoteFunction", "ClaimDaily")
local Notify = remote("RemoteEvent", "Notify")

local function addMoney(player, amount)
	amount = math.floor(amount)
	player:SetAttribute("Money", (player:GetAttribute("Money") or 0) + amount)
	player:SetAttribute("TotalEarned", (player:GetAttribute("TotalEarned") or 0) + amount)
end

-- Free gifts --------------------------------------------------------------------------
ClaimGift.OnServerInvoke = function(player, index)
	local minutes = typeof(index) == "number" and Config.GiftMinutes[index]
	if not minutes then
		return false, "Unknown gift."
	end
	local claimed = string.split(player:GetAttribute("GiftsClaimed") or "", ",")
	if table.find(claimed, tostring(index)) then
		return false, "Already claimed!"
	end
	local played = os.time() - (player:GetAttribute("JoinedAt") or os.time())
	if played < minutes * 60 then
		return false, "Not ready yet!"
	end
	local reward = Config.giftReward(player:GetAttribute("UnlockedStage") or 1, index)
	addMoney(player, reward)
	table.insert(claimed, tostring(index))
	player:SetAttribute("GiftsClaimed", table.concat(claimed, ","))
	return true, "Gift opened: +$" .. Config.abbreviate(reward) .. "!"
end

-- Daily reward ------------------------------------------------------------------------
local DAY = 20 * 3600 -- can claim again 20h after the last claim
ClaimDaily.OnServerInvoke = function(player)
	local now = os.time()
	local last = player:GetAttribute("LastDaily") or 0
	if now - last < DAY then
		return false, "Come back later!"
	end
	local streak = (now - last < 48 * 3600) and (player:GetAttribute("DailyStreak") or 0) + 1 or 1
	local reward = Config.dailyReward(player:GetAttribute("UnlockedStage") or 1, streak)
	addMoney(player, reward)
	player:SetAttribute("DailyStreak", streak)
	player:SetAttribute("LastDaily", now)
	PlayerData.save(player)
	return true, "Day " .. streak .. " reward: +$" .. Config.abbreviate(reward) .. "!"
end

-- Donations ---------------------------------------------------------------------------
local function donationFor(productId)
	for _, d in ipairs(Config.Donations) do
		if d.id ~= 0 and d.id == productId then
			return d
		end
	end
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local donation = donationFor(receipt.ProductId)
	if not donation then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not player or not player:GetAttribute("DataLoaded") then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	player:SetAttribute("Donated", (player:GetAttribute("Donated") or 0) + donation.robux)
	PlayerData.save(player)
	Notify:FireAllClients(player.DisplayName .. " donated " .. donation.robux .. " Robux! Thank you! ❤", Color3.fromRGB(255, 150, 220))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Owner test commands (type in chat) -----------------------------------------------------
--   /money 20000   add money        /stage 5   unlock up to stage 5
--   /reset         wipe your progress back to the start
local RunService = game:GetService("RunService")
local function isOwner(player)
	return RunService:IsStudio() or player.UserId == game.CreatorId
end

local function onChat(player, msg)
	if not isOwner(player) then
		return
	end
	local cmd, arg = string.match(string.lower(msg), "^/(%a+)%s*(%-?%d*)")
	local n = tonumber(arg)
	if cmd == "money" then
		addMoney(player, n or 20000)
		Notify:FireClient(player, "Added $" .. Config.abbreviate(n or 20000), Color3.fromRGB(130, 255, 130))
	elseif cmd == "stage" then
		local s = math.clamp(n or (player:GetAttribute("UnlockedStage") or 1) + 1, 1, Config.NUM_STAGES)
		player:SetAttribute("UnlockedStage", s)
		player:SetAttribute("BestDistance", math.max(player:GetAttribute("BestDistance") or 0, (s - 1) * Config.STAGE_LENGTH))
		Notify:FireClient(player, "Unlocked up to Stage " .. s, Color3.fromRGB(130, 255, 130))
	elseif cmd == "reset" then
		for k, v in pairs(PlayerData.DEFAULTS) do
			player:SetAttribute(k, v)
		end
		Notify:FireClient(player, "Progress reset", Color3.fromRGB(255, 200, 120))
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		onChat(player, msg)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(msg)
		onChat(player, msg)
	end)
end

-- Leaderboards ------------------------------------------------------------------------
local boards = {
	{ name = "RichestBoard", attr = "Money", store = "Richest_v1", prefix = "$" },
	{ name = "DonorBoard", attr = "Donated", store = "Donated_v1", prefix = "R$ " },
}
for _, b in ipairs(boards) do
	pcall(function()
		b.ordered = DataStoreService:GetOrderedDataStore(b.store)
	end)
end

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = ok and name or ("Player " .. userId)
	return nameCache[userId]
end

-- Returns { {name=, value=}, ... } top 10, global if DataStores work, else this server.
local function topList(b)
	if b.ordered then
		for _, p in ipairs(Players:GetPlayers()) do
			local v = math.floor(p:GetAttribute(b.attr) or 0)
			if v > 0 and p:GetAttribute("DataLoaded") then
				pcall(function()
					b.ordered:SetAsync(tostring(p.UserId), v)
				end)
			end
		end
		local ok, pages = pcall(function()
			return b.ordered:GetSortedAsync(false, 10)
		end)
		if ok then
			local list = {}
			for _, entry in ipairs(pages:GetCurrentPage()) do
				table.insert(list, { name = nameOf(tonumber(entry.key)), value = entry.value })
			end
			return list, true
		end
	end
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, { name = p.DisplayName, value = p:GetAttribute(b.attr) or 0 })
	end
	table.sort(list, function(a, c)
		return a.value > c.value
	end)
	return list, false
end

local MEDALS = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 215, 230), Color3.fromRGB(225, 150, 90) }

local function renderBoard(b, list, global)
	local board = workspace.World:FindFirstChild(b.name, true)
	local rows = board and board:FindFirstChild("Rows", true)
	if not rows then
		return
	end
	for _, c in ipairs(rows:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local sub = board:FindFirstChild("Subtitle", true)
	if sub then
		sub.Text = global and "All servers" or "This server"
	end
	for i = 1, 10 do
		local entry = list[i]
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0.095, 0)
		row.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(235, 240, 255) or Color3.fromRGB(255, 255, 255)
		row.Parent = rows
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = row
		local function text(t, x, w, align, color)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(x, 0.1)
			l.Size = UDim2.fromScale(w, 0.8)
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.TextXAlignment = align
			l.TextColor3 = color or Color3.fromRGB(40, 40, 70)
			l.Text = t
			l.Parent = row
			return l
		end
		text("#" .. i, 0.03, 0.12, Enum.TextXAlignment.Left, MEDALS[i] and MEDALS[i]:Lerp(Color3.new(0, 0, 0), 0.25))
		text(entry and entry.name or "---", 0.16, 0.5, Enum.TextXAlignment.Left)
		text(entry and (b.prefix .. Config.abbreviate(entry.value)) or "", 0.62, 0.35, Enum.TextXAlignment.Right, Color3.fromRGB(40, 150, 60))
	end
end

task.spawn(function()
	task.wait(5)
	while true do
		for _, b in ipairs(boards) do
			local ok, err = pcall(function()
				local list, global = topList(b)
				renderBoard(b, list, global)
			end)
			if not ok then
				warn("[Leaderboards] " .. tostring(err))
			end
		end
		task.wait(60)
	end
end)
