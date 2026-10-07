-- Free timed gifts, daily login reward, global leaderboards (farthest, most earned, rebirths, top donators), Robux donations.
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
	if not player:GetAttribute("DataLoaded") then
		return false, "Loading your save..."
	end
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
	if not player:GetAttribute("DataLoaded") then
		return false, "Loading your save..."
	end
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
	player:SetAttribute("Spins", (player:GetAttribute("Spins") or 0) + 1) -- + a Lucky Spin
	local extra = " and a LUCKY SPIN!"
	if streak % 7 == 0 then -- every Day 7: a free pet (owner: no extra spins, keep balance v3)
		local give = game:GetService("ServerStorage"):FindFirstChild("GivePet") -- PetServer
		local ok, kind = false, nil
		if give then
			ok, kind = pcall(give.Invoke, give, player)
		end
		kind = ok and Config.Pets[kind] and kind or nil
		extra = kind and (", a LUCKY SPIN and a FREE " .. Config.Pets[kind].name .. "!") or " and a LUCKY SPIN! (pets full!)"
	end
	PlayerData.save(player)
	-- named like the calendar: day 8 is Week 2 Day 1
	local week, day = (streak - 1) // 7 + 1, (streak - 1) % 7 + 1
	return true, (week > 1 and ("Week " .. week .. " Day ") or "Day ") .. day .. " reward: +$" .. Config.abbreviate(reward) .. extra
end

-- Donations ---------------------------------------------------------------------------
local function donationFor(productId)
	for _, d in ipairs(Config.Donations) do
		if d.id ~= 0 and d.id == productId then
			return d
		end
	end
end

local function productFor(productId)
	for _, p in ipairs(Config.Products) do
		if p.id ~= 0 and p.id == productId then
			return p
		end
	end
end

-- What a developer product gives (Config.Products). Returns true when it's done.
local function grantProduct(player, product)
	if product.key == "SuperLuck" then
		local now = workspace:GetServerTimeNow()
		player:SetAttribute("SuperLuckUntil", math.max(now, player:GetAttribute("SuperLuckUntil") or 0) + Config.SUPER_LUCK_TIME)
		Notify:FireClient(player, "🍀 Super Luck: x" .. Config.SUPER_LUCK .. " luck for " .. (Config.SUPER_LUCK_TIME // 60) .. " minutes!", Color3.fromRGB(120, 255, 140))
		return true
	elseif product.egg then
		local results = game:GetService("ServerStorage").HatchFor:Invoke(player, product.egg, product.count)
		if not results then
			return false
		end
		remote("RemoteEvent", "PaidHatch"):FireClient(player, product.egg, results)
		return true
	end
	return false
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local donation = donationFor(receipt.ProductId)
	local product = not donation and productFor(receipt.ProductId)
	if not donation and not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not player or not player:GetAttribute("DataLoaded") then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not PlayerData.isActive(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- no save (off or ended): Roblox retries later
	end
	local done = string.split(player:GetAttribute("Receipts") or "", ",")
	if table.find(done, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already counted (Roblox retried)
	end
	table.insert(done, receipt.PurchaseId)
	while #done > 30 do
		table.remove(done, 1)
	end
	if product then
		if not grantProduct(player, product) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		player:SetAttribute("Receipts", table.concat(done, ","))
		PlayerData.save(player) -- (the receipt id is saved with what it gave)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	player:SetAttribute("Receipts", table.concat(done, ","))
	player:SetAttribute("Donated", (player:GetAttribute("Donated") or 0) + donation.robux)
	if not PlayerData.save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- not saving right now: Roblox retries later
	end
	Notify:FireAllClients(player.DisplayName .. " donated " .. donation.robux .. " Robux! Thank you! ❤", Color3.fromRGB(255, 150, 220))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Owner test commands (type in chat) -----------------------------------------------------
--   /money 20000   add money        /stage 5   unlock up to stage 5
--   /reset         wipe your progress back to the start
--   /event winter  preview an event in this server (winter | halloween | none | auto)
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
	local ev = string.match(string.lower(msg), "^/event%s+(%a+)")
	if ev then
		-- preview an event in this server: /event winter | halloween | none | auto (= by the dates)
		local names = { winter = "Winter", halloween = "Halloween", none = "None" }
		workspace:SetAttribute("ForceEvent", names[ev])
		Notify:FireClient(player, "Event: " .. (names[ev] or "by date") .. " (takes a few seconds)", Color3.fromRGB(130, 255, 130))
	elseif cmd == "money" then
		addMoney(player, n or 20000)
		Notify:FireClient(player, "Added $" .. Config.abbreviate(n or 20000), Color3.fromRGB(130, 255, 130))
	elseif cmd == "stage" then
		local s = math.clamp(n or (player:GetAttribute("UnlockedStage") or 1) + 1, 1, Config.NUM_STAGES)
		player:SetAttribute("UnlockedStage", s)
		player:SetAttribute("BestDistance", math.max(player:GetAttribute("BestDistance") or 0, (s - 1) * Config.STAGE_LENGTH))
		Notify:FireClient(player, "Unlocked up to Stage " .. s, Color3.fromRGB(130, 255, 130))
	elseif cmd == "spins" then
		player:SetAttribute("Spins", n or 3)
		Notify:FireClient(player, "Spins: " .. (n or 3), Color3.fromRGB(130, 255, 130))
	elseif cmd == "reset" then
		for k, v in pairs(PlayerData.DEFAULTS) do
			if k ~= "Migrated" then -- don't re-import the old save on next join
				player:SetAttribute(k, v)
			end
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

-- Leaderboard -------------------------------------------------------------------------
-- One board in the lobby (Hub.TopBoard) flips between four pages every few seconds.
-- keepMax: the stored record only goes up (BestDistance itself resets on rebirth).
local boards = {
	{ title = "🚀 FARTHEST FLIGHTS", attr = "BestDistance", store = "BestDistance_v1", keepMax = true, format = Config.meters },
	{ title = "💰 MOST EARNED", attr = "TotalEarned", store = "TotalEarned_v1", format = function(v)
		return "$" .. Config.abbreviate(v)
	end },
	{ title = "🌟 MOST REBIRTHS", attr = "Rebirths", store = "Rebirths_v1", format = function(v)
		return tostring(v) .. " 🌟"
	end },
	{ title = "❤ TOP SUPPORTERS", attr = "Donated", store = "Donated_v1", format = function(v)
		return "R$ " .. Config.abbreviate(v)
	end },
}
for _, b in ipairs(boards) do
	pcall(function()
		b.ordered = DataStoreService:GetOrderedDataStore(PlayerData.storeName(b.store)) -- (Studio: its own boards)
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

-- last value sent to each store, so unchanged values aren't written again: [store][userId]
local lastWritten = {}
-- keepMax boards: the best value seen this session, so a rebirth doesn't lower the
-- "This server" list either (or a record set just before it): [store][userId]
local sessionBest = {}
Players.PlayerRemoving:Connect(function(player)
	for _, written in pairs(lastWritten) do
		written[player.UserId] = nil
	end
	for _, best in pairs(sessionBest) do
		best[player.UserId] = nil
	end
end)
local function watchBest(player)
	for _, b in ipairs(boards) do
		if b.keepMax then
			sessionBest[b.store] = sessionBest[b.store] or {}
			local best = sessionBest[b.store]
			local function seen()
				best[player.UserId] = math.max(best[player.UserId] or 0, player:GetAttribute(b.attr) or 0)
			end
			player:GetAttributeChangedSignal(b.attr):Connect(seen)
			seen()
		end
	end
end
Players.PlayerAdded:Connect(watchBest)
for _, player in ipairs(Players:GetPlayers()) do
	watchBest(player)
end

-- a player's value for a board (keepMax boards: the session best)
local function valueOf(b, p)
	local v = p:GetAttribute(b.attr) or 0
	if b.keepMax then
		v = math.max(v, sessionBest[b.store] and sessionBest[b.store][p.UserId] or 0)
	end
	return v
end

-- Returns { {name=, value=}, ... } top 10, global if DataStores work, else this server.
local function topList(b)
	if b.ordered then
		local written = lastWritten[b.store]
		if not written then
			written = {}
			lastWritten[b.store] = written
		end
		for _, p in ipairs(Players:GetPlayers()) do
			local uid = p.UserId
			local v = math.floor(valueOf(b, p))
			local last = written[uid]
			-- records only need a write when beaten, other boards when the value changed
			local changed = if b.keepMax then v > (last or 0) else v ~= last
			if v > 0 and changed and p:GetAttribute("DataLoaded") then
				pcall(function()
					if b.keepMax then
						local best = v
						b.ordered:UpdateAsync(tostring(uid), function(old)
							best = math.max(old or 0, v)
							if old and old >= v then
								return nil -- stored record is already higher: no write
							end
							return v
						end)
						written[uid] = best
					else
						b.ordered:SetAsync(tostring(uid), v)
						written[uid] = v
					end
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
		local v = valueOf(b, p)
		if v > 0 then
			table.insert(list, { name = p.DisplayName, value = v })
		end
	end
	table.sort(list, function(a, c)
		return a.value > c.value
	end)
	return list, false
end

local MEDALS = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 215, 230), Color3.fromRGB(225, 150, 90) }

-- The board's parts are looked up once (the World search walks hundreds of pickups) and the
-- 10 rows are built once; a page flip only changes their text.
local board, rows, title, sub
local rowLabels = {} -- [i] = { rank =, name =, value = }

local function buildRows()
	for _, c in ipairs(rows:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	table.clear(rowLabels)
	for i = 1, 10 do
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
		rowLabels[i] = {
			rank = text("#" .. i, 0.03, 0.12, Enum.TextXAlignment.Left, MEDALS[i] and MEDALS[i]:Lerp(Color3.new(0, 0, 0), 0.25)),
			name = text("---", 0.16, 0.5, Enum.TextXAlignment.Left),
			value = text("", 0.62, 0.35, Enum.TextXAlignment.Right, Color3.fromRGB(40, 150, 60)),
		}
	end
end

local function renderBoard(b)
	if board == nil or board.Parent == nil or not rows:IsDescendantOf(workspace) then
		-- first render (or the board was rebuilt): find it again and build the rows
		local world = workspace:FindFirstChild("World")
		board = world and world:FindFirstChild("TopBoard", true)
		rows = board and board:FindFirstChild("Rows", true)
		if not rows then
			board = nil
			return
		end
		title = board:FindFirstChild("Title", true)
		sub = board:FindFirstChild("Subtitle", true)
		buildRows()
	end
	if title then
		title.Text = b.title
	end
	if sub then
		sub.Text = b.global and "All servers" or "This server"
	end
	local list = b.list or {}
	for i, labels in ipairs(rowLabels) do
		local entry = list[i]
		labels.name.Text = entry and entry.name or "---"
		labels.value.Text = entry and b.format(entry.value) or ""
	end
end

-- refresh the lists once a minute, flip the page every 8 seconds
task.spawn(function()
	task.wait(5)
	while true do
		for _, b in ipairs(boards) do
			local ok, err = pcall(function()
				b.list, b.global = topList(b)
			end)
			if not ok then
				warn("[Leaderboard] " .. tostring(err))
			end
		end
		task.wait(60)
	end
end)
task.spawn(function()
	task.wait(6)
	local page = 0
	while true do
		page = page % #boards + 1
		pcall(renderBoard, boards[page])
		task.wait(8)
	end
end)
