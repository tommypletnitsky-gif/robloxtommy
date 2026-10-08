-- Trading pets (server). Everything is checked here; the clients only ask.
--   TradeRequest(userId)          -> ok, message   ask a player in this server to trade
--   TradeRespond(userId, accept)  -> ok, message   answer an invite
--   TradeAction(action, arg)      -> ok, message   "add" uid | "remove" uid | "ready" | "unready" | "cancel"
--   TradeInvite (to the asked player): fromUserId, fromName
--   TradeState  (to both): state table, or nil + message when the trade is over
-- Rules: up to MAX_OFFER pets each; locked pets can't be offered; any change un-readies both; when
-- both are ready a COUNTDOWN runs, then everything is checked again (owned, not locked, room in
-- storage) and the pets move in one go (new ids on the receiving side), and both saves are written.
-- While a trade is open the attribute Trading is set: PetServer won't delete or fuse pets then.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(ServerScriptService.PlayerData)

local MAX_OFFER = 8
local COUNTDOWN = 3
local INVITE_TIME = 20
local REQUEST_GAP = 4

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(className, name)
	local r = remotes:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local TradeRequest = remote("RemoteFunction", "TradeRequest")
local TradeRespond = remote("RemoteFunction", "TradeRespond")
local TradeAction = remote("RemoteFunction", "TradeAction")
local TradeInvite = remote("RemoteEvent", "TradeInvite")
local TradeState = remote("RemoteEvent", "TradeState")

local invites = {} -- [target] = { from = player, at = os.clock() }
local lastRequest = {} -- [player] = os.clock()
local sessions = {} -- [player] = session { a, b, offers = { [p] = { uid... } }, ready = { [p] = bool }, version, endsAt }

-- Paid pets (from Robux eggs) can only change hands when both players' regions allow trading paid
-- items (PolicyService.IsPaidItemTradingAllowed). Unknown policy = not allowed.
local PolicyService = game:GetService("PolicyService")
local paidTradeOk = {} -- [player] = bool
local function canTradePaid(player)
	if paidTradeOk[player] == nil then
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		paidTradeOk[player] = ok and info.IsPaidItemTradingAllowed == true
	end
	return paidTradeOk[player]
end
local function isPaidPet(kind)
	local pet = Config.Pets[kind]
	local egg = pet and Config.getEgg(pet.egg)
	return egg ~= nil and egg.robux == true
end

local function ready(player)
	return player.Parent == Players and player:GetAttribute("DataLoaded") and PlayerData.isActive(player)
end

local function petsOf(player)
	local byUid = {}
	local list = Config.parsePets(player:GetAttribute("Pets"))
	for _, p in ipairs(list) do
		byUid[p.uid] = p
	end
	return list, byUid
end

local function other(s, player)
	return s.a == player and s.b or s.a
end

-- what each side sees
local function send(s)
	for _, p in ipairs({ s.a, s.b }) do
		local o = other(s, p)
		local function describe(owner)
			local _, byUid = petsOf(owner)
			local list = {}
			for _, uid in ipairs(s.offers[owner]) do
				local pet = byUid[uid]
				if pet then
					table.insert(list, { uid = uid, kind = pet.kind, golden = pet.golden, rainbow = pet.rainbow })
				end
			end
			return list
		end
		TradeState:FireClient(p, {
			partner = o.DisplayName,
			partnerTier = Config.playerTier(o),
			you = describe(p),
			them = describe(o),
			youReady = s.ready[p],
			themReady = s.ready[o],
			countdown = s.endsAt and math.max(0, s.endsAt - os.clock()) or nil,
		})
	end
end

local function finish(s, message)
	for _, p in ipairs({ s.a, s.b }) do
		if sessions[p] == s then
			sessions[p] = nil
			if p.Parent then
				p:SetAttribute("Trading", nil)
				TradeState:FireClient(p, nil, message)
			end
		end
	end
end

local function changed(s)
	s.version += 1
	s.ready[s.a], s.ready[s.b] = false, false
	s.endsAt = nil
	send(s)
end

-- the actual swap: everything checked again, then both inventories are written at once
local function execute(s)
	local a, b = s.a, s.b
	if not (ready(a) and ready(b)) then
		finish(s, "Trade cancelled.")
		return
	end
	local listA, byA = petsOf(a)
	local listB, byB = petsOf(b)
	for _, side in ipairs({ { a, byA }, { b, byB } }) do
		for _, uid in ipairs(s.offers[side[1]]) do
			local pet = side[2][uid]
			if not pet or pet.locked then
				finish(s, "Trade cancelled: a pet in it changed.")
				return
			end
			if isPaidPet(pet.kind) and not (canTradePaid(a) and canTradePaid(b)) then
				finish(s, "Trade cancelled: Robux pets can't be traded here.")
				return
			end
		end
	end
	local nA, nB = #s.offers[a], #s.offers[b]
	if #listA - nA + nB > Config.maxPetsFor(a) then
		finish(s, a.DisplayName .. " doesn't have room for those pets.")
		return
	end
	if #listB - nB + nA > Config.maxPetsFor(b) then
		finish(s, b.DisplayName .. " doesn't have room for those pets.")
		return
	end
	local function give(from, fromList, to, toList, uids)
		local gone = {}
		for _, uid in ipairs(uids) do
			gone[uid] = true
		end
		local kept, moving = {}, {}
		for _, p in ipairs(fromList) do
			if gone[p.uid] then
				table.insert(moving, p)
			else
				table.insert(kept, p)
			end
		end
		local nextId = to:GetAttribute("NextPetId") or 1
		for _, p in ipairs(moving) do
			table.insert(toList, { uid = nextId, kind = p.kind, golden = p.golden, rainbow = p.rainbow })
			nextId += 1
		end
		to:SetAttribute("NextPetId", nextId)
		-- equipped pets that left are unequipped
		local eq = {}
		for uid in string.gmatch(from:GetAttribute("EquippedPets") or "", "%d+") do
			if not gone[tonumber(uid)] then
				table.insert(eq, uid)
			end
		end
		from:SetAttribute("EquippedPets", table.concat(eq, ","))
		return kept
	end
	s.done = true -- (the Pets watcher below ignores the changes we make now)
	local offA, offB = table.clone(s.offers[a]), table.clone(s.offers[b])
	local keptA = give(a, listA, b, listB, offA) -- (adds A's pets to listB)
	local keptB = give(b, listB, a, keptA, offB) -- (listB now also holds A's pets, under new ids that
	-- can't clash with B's offered ones; B's offered pets go to keptA)
	a:SetAttribute("Pets", Config.serializePets(keptA))
	b:SetAttribute("Pets", Config.serializePets(keptB))
	PlayerData.save(a)
	PlayerData.save(b)
	print(string.format("[Trade] %s (%d pets) <-> %s (%d pets)", a.Name, nA, b.Name, nB))
	finish(s, "Trade complete! 🎉")
end

TradeRequest.OnServerInvoke = function(player, userId)
	if typeof(userId) ~= "number" then
		return false, "?"
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == player then
		return false, "That player isn't here."
	end
	if not ready(player) or not ready(target) then
		return false, "Trading isn't available right now (saves still loading)."
	end
	if sessions[player] or sessions[target] then
		return false, sessions[player] and "You're already trading." or (target.DisplayName .. " is already trading.")
	end
	if target:GetAttribute("TradesOff") then
		return false, target.DisplayName .. " has trade requests turned off."
	end
	if os.clock() - (lastRequest[player] or 0) < REQUEST_GAP then
		return false, "Wait a moment before asking again."
	end
	lastRequest[player] = os.clock()
	invites[target] = { from = player, at = os.clock() }
	TradeInvite:FireClient(target, player.UserId, player.DisplayName)
	return true, "Trade request sent to " .. target.DisplayName .. "!"
end

TradeRespond.OnServerInvoke = function(player, userId, accept)
	local inv = invites[player]
	if not inv or typeof(userId) ~= "number" or inv.from.UserId ~= userId then
		return false, "That trade request is gone."
	end
	invites[player] = nil
	local from = inv.from
	if os.clock() - inv.at > INVITE_TIME or from.Parent ~= Players then
		return false, "That trade request ran out."
	end
	if accept ~= true then
		return true, ""
	end
	if sessions[player] or sessions[from] or not ready(player) or not ready(from) then
		return false, "Can't start the trade right now."
	end
	local s = { a = from, b = player, offers = { [from] = {}, [player] = {} }, ready = { [from] = false, [player] = false }, version = 0 }
	sessions[from], sessions[player] = s, s
	from:SetAttribute("Trading", true)
	player:SetAttribute("Trading", true)
	send(s)
	return true, ""
end

TradeAction.OnServerInvoke = function(player, action, arg)
	local s = sessions[player]
	if not s then
		return false, "You're not trading."
	end
	if action == "cancel" then
		finish(s, player.DisplayName .. " cancelled the trade.")
		return true, ""
	end
	if s.endsAt and action ~= "unready" then
		return false, "The trade is about to happen!"
	end
	local offer = s.offers[player]
	if action == "add" then
		local _, byUid = petsOf(player)
		local pet = typeof(arg) == "number" and byUid[arg]
		if not pet then
			return false, "You don't have that pet."
		end
		if pet.locked then
			return false, "🔒 That pet is locked."
		end
		if isPaidPet(pet.kind) and not (canTradePaid(player) and canTradePaid(other(s, player))) then
			return false, "Pets from Robux eggs can't be traded in your or your partner's region."
		end
		if table.find(offer, arg) then
			return true, ""
		end
		if #offer >= MAX_OFFER then
			return false, "Up to " .. MAX_OFFER .. " pets per trade."
		end
		table.insert(offer, arg)
		changed(s)
		return true, ""
	elseif action == "remove" then
		local i = table.find(offer, arg)
		if i then
			table.remove(offer, i)
			changed(s)
		end
		return true, ""
	elseif action == "ready" then
		if #s.offers[s.a] + #s.offers[s.b] == 0 then
			return false, "Add some pets first!"
		end
		s.ready[player] = true
		if s.ready[s.a] and s.ready[s.b] then
			s.endsAt = os.clock() + COUNTDOWN
			local version = s.version
			task.delay(COUNTDOWN, function()
				if sessions[s.a] == s and s.version == version and s.endsAt then
					execute(s)
				end
			end)
		end
		send(s)
		return true, ""
	elseif action == "unready" then
		s.ready[player] = false
		if s.endsAt then
			s.endsAt = nil
			s.version += 1
		end
		send(s)
		return true, ""
	end
	return false, "?"
end

-- leaving, starting a flight or a pet in the offer disappearing cancels the trade
local function watch(player)
	player:GetAttributeChangedSignal("Flying"):Connect(function()
		local s = sessions[player]
		if s and player:GetAttribute("Flying") then
			finish(s, "Trade cancelled.")
		end
	end)
	player:GetAttributeChangedSignal("Pets"):Connect(function()
		local s = sessions[player]
		if not s or s.done then
			return
		end
		local _, byUid = petsOf(player)
		local offer = s.offers[player]
		local before = #offer
		for i = #offer, 1, -1 do
			local pet = byUid[offer[i]]
			if not pet or pet.locked then
				table.remove(offer, i)
			end
		end
		if #offer ~= before then
			changed(s)
		end
	end)
end
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end
Players.PlayerRemoving:Connect(function(player)
	paidTradeOk[player] = nil
	local s = sessions[player]
	if s then
		finish(s, player.DisplayName .. " left the game.")
	end
	invites[player] = nil
	lastRequest[player] = nil
	for target, inv in pairs(invites) do
		if inv.from == player then
			invites[target] = nil
		end
	end
end)
