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
--   /season winter preview a season event in this server (winter | halloween | none | auto)
-- "Admin abuse" (a big banner on everyone's screen; text goes through Roblox's filter):
--   /bb HI EVERYONE   banner to this server        /gbb HI EVERYONE   banner to every server
--   /luckyhour 30     Lucky Hour (x2 luck) now     /boost 2 10        x2 money for 10 minutes
--   /rain             money rain at the spawn      /giveall 50k       everyone gets $50K
--   /spin all         everyone gets a free spin
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local MessagingService = game:GetService("MessagingService")
local Announce = remote("RemoteEvent", "Announce") -- (title, text, color)
local RainCoin = remote("RemoteEvent", "RainCoin") -- (amount) you picked up a money-rain coin

local function isOwner(player)
	return RunService:IsStudio() or player.UserId == game.CreatorId
end

-- Everything other players read must be filtered (Roblox rule), the owner's text too.
local function filtered(player, text)
	local ok, res = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	return ok and res or nil
end

local function announce(title, text, color)
	Announce:FireAllClients(title, text, color)
end

-- the owner's "/..." commands aren't delivered as chat (no "/bb HI" in the chat box or over your
-- head): players only see the result. (Player.Chatted still fires, so the commands still run.)
task.spawn(function()
	local channels = game:GetService("TextChatService"):WaitForChild("TextChannels", 60)
	local general = channels and channels:WaitForChild("RBXGeneral", 60)
	if general then
		general.ShouldDeliverCallback = function(message)
			local source = message.TextSource
			local sender = source and Players:GetPlayerByUserId(source.UserId)
			if sender and isOwner(sender) and string.sub(message.Text or "", 1, 1) == "/" then
				return false
			end
			return true
		end
	end
end)

-- /gbb: every server listens and shows the banner
task.spawn(function()
	pcall(function()
		MessagingService:SubscribeAsync("AdminAnnounce", function(message)
			local d = message.Data
			if type(d) == "table" and type(d.title) == "string" and type(d.text) == "string" then
				announce(d.title, d.text, Color3.fromRGB(255, 120, 60))
			end
		end)
	end)
end)

-- "50k" / "2.5m" / "1b" -> number
local function parseAmount(s)
	local n, suffix = string.match(s or "", "^(%d+%.?%d*)(%a?)")
	n = tonumber(n)
	if not n then
		return nil
	end
	local mult = ({ k = 1e3, m = 1e6, b = 1e9, t = 1e12 })[string.lower(suffix or "")] or 1
	return math.floor(n * mult)
end

-- Money rain: gold coins fall around the spawn; touch one to grab it (worth more the more
-- you've earned, so it's exciting at every stage).
local raining = false
local function moneyRain(owner, seconds)
	if raining then
		return
	end
	raining = true
	local hub = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Hub")
	local spawn = hub and hub:FindFirstChild("Spawn", true)
	local center = spawn and spawn.Position or Vector3.new(0, 5, 0)
	local folder = Instance.new("Folder")
	folder.Name = "MoneyRain"
	folder.Parent = workspace
	announce("💸 MONEY RAIN!", owner.DisplayName .. " made it rain! Grab the coins at the spawn!", Color3.fromRGB(90, 220, 110))
	local stopAt = os.clock() + seconds
	task.spawn(function()
		while os.clock() < stopAt do
			for _ = 1, 3 do
				local c = Instance.new("Part")
				c.Name = "RainCoin"
				c.Shape = Enum.PartType.Cylinder
				c.Size = Vector3.new(0.4, 2.4, 2.4)
				c.Color = Color3.fromRGB(255, 205, 60)
				c.Material = Enum.Material.Metal
				c.Reflectance = 0.2
				c.CFrame = CFrame.new(center + Vector3.new(math.random(-45, 45), 40 + math.random() * 15, math.random(-45, 45)))
					* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
				c.Parent = folder
				c:SetNetworkOwner(nil)
				local taken = false
				c.Touched:Connect(function(hit)
					if taken then
						return
					end
					local p = Players:GetPlayerFromCharacter(hit.Parent)
					if p and p:GetAttribute("DataLoaded") then
						taken = true
						local value = math.max(250, math.floor((p:GetAttribute("TotalEarned") or 0) * 0.002))
						addMoney(p, value)
						RainCoin:FireClient(p, value)
						c:Destroy()
					end
				end)
				game:GetService("Debris"):AddItem(c, 14)
			end
			task.wait(0.3)
		end
		task.wait(14)
		folder:Destroy()
		raining = false
	end)
end

-- the big-banner commands (they keep the text's capital letters)
local function adminBanner(player, msg)
	local kind, text = string.match(msg, "^/(%a+)%s+(.+)$")
	kind = kind and string.lower(kind)
	if kind ~= "bb" and kind ~= "gbb" then
		return false
	end
	text = string.sub(text, 1, 150)
	local clean = filtered(player, text)
	if not clean then
		Notify:FireClient(player, "Couldn't send that (chat filter is busy) - try again", Color3.fromRGB(255, 120, 120))
		return true
	end
	local title = "📢 " .. player.DisplayName
	if kind == "gbb" then
		local ok = pcall(MessagingService.PublishAsync, MessagingService, "AdminAnnounce", { title = title, text = clean })
		if not ok then -- (Studio / messaging down: at least this server)
			announce(title, clean, Color3.fromRGB(255, 120, 60))
		end
	else
		announce(title, clean, Color3.fromRGB(255, 190, 40))
	end
	return true
end

-- the other admin-abuse commands; true if `lower` was one of them
local function adminEvent(player, lower)
	if string.match(lower, "^/spin%s+all") then
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("DataLoaded") then
				p:SetAttribute("Spins", (p:GetAttribute("Spins") or 0) + 1)
			end
		end
		announce("🎡 FREE SPIN!", player.DisplayName .. " gave everyone a free Lucky Spin!", Color3.fromRGB(190, 110, 255))
		return true
	end
	local giveArg = string.match(lower, "^/giveall%s+(%S+)")
	if giveArg then
		local amount = parseAmount(giveArg)
		if amount and amount > 0 then
			for _, p in ipairs(Players:GetPlayers()) do
				if p:GetAttribute("DataLoaded") then
					addMoney(p, amount)
				end
			end
			announce("💰 FREE MONEY!", player.DisplayName .. " gave everyone $" .. Config.abbreviate(amount) .. "!", Color3.fromRGB(90, 220, 110))
		end
		return true
	end
	local bMult, bMin = string.match(lower, "^/boost%s*(%d*%.?%d*)%s*(%d*)")
	if bMult then
		local mult = math.clamp(tonumber(bMult) or 2, 1.5, 10)
		local minutes = math.clamp(tonumber(bMin) or 10, 1, 60)
		workspace:SetAttribute("AdminMoneyMult", mult)
		workspace:SetAttribute("AdminMoneyUntil", workspace:GetServerTimeNow() + minutes * 60)
		announce("💰 x" .. mult .. " MONEY!", player.DisplayName .. " boosted everyone's money for " .. minutes .. " minutes!", Color3.fromRGB(255, 205, 60))
		return true
	end
	local lhMin = string.match(lower, "^/luckyhour%s*(%d*)")
	if lhMin then
		local minutes = math.clamp(tonumber(lhMin) or 30, 1, 120)
		workspace:SetAttribute("AdminLuckyUntil", workspace:GetServerTimeNow() + minutes * 60)
		announce("🍀 LUCKY HOUR!", "x" .. Config.LUCKY_HOUR.mult .. " luck on every egg for " .. minutes .. " minutes!", Color3.fromRGB(90, 220, 110))
		return true
	end
	if string.match(lower, "^/rain") then
		moneyRain(player, 30)
		return true
	end
	return false
end

local refreshBoards -- (the leaderboard, below)
local function onChat(player, msg)
	if not isOwner(player) then
		return
	end
	if adminBanner(player, msg) or adminEvent(player, string.lower(msg)) then
		return
	end
	local cmd, arg = string.match(string.lower(msg), "^/(%a+)%s*(%-?%d*)")
	local n = tonumber(arg)
	local ev = string.match(string.lower(msg), "^/season%s+(%a+)")
	if ev then
		-- preview a season event in this server: /season winter | halloween | none | auto (= by the dates)
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
		PlayerData.save(player)
		task.spawn(refreshBoards) -- the leaderboard drops your old numbers right away
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
-- Live: each board shows players' current values (a /reset or a rebirth lowers them too;
-- a value of 0 takes the player off the board).
local boards = {
	{ title = "🚀 FARTHEST FLIGHTS", attr = "BestDistance", store = "BestDistance_v1", format = Config.meters },
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
Players.PlayerRemoving:Connect(function(player)
	for _, written in pairs(lastWritten) do
		written[player.UserId] = nil
	end
end)

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
			local v = math.max(0, math.floor(p:GetAttribute(b.attr) or 0))
			if p:GetAttribute("DataLoaded") and v ~= written[uid] then
				pcall(function()
					if v > 0 then
						b.ordered:SetAsync(tostring(uid), v)
					else
						b.ordered:RemoveAsync(tostring(uid)) -- 0 (e.g. after /reset): off the board
					end
					written[uid] = v
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
		local v = p:GetAttribute(b.attr) or 0
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

-- refresh the lists once a minute (and right away after a /reset), flip the page every 8 seconds
local refreshing = false
refreshBoards = function()
	if refreshing then
		return
	end
	refreshing = true
	for _, b in ipairs(boards) do
		local ok, err = pcall(function()
			b.list, b.global = topList(b)
		end)
		if not ok then
			warn("[Leaderboard] " .. tostring(err))
		end
	end
	refreshing = false
end
task.spawn(function()
	task.wait(5)
	while true do
		refreshBoards()
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
