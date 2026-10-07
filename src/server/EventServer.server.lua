-- Things that happen to the whole server:
--   Races: every Config.Race.every seconds a race opens for Config.Race.joinTime seconds; everyone who
--          joined is shot out of the cannon together. Ranked by how much of your OWN track (cannon to
--          your stage gate) you flew, so new players can beat veterans; the share of coins / gems /
--          rings you grabbed breaks ties. Prizes for the top 3, a little something for everyone else.
--   Events: every Config.EVENT_EVERY seconds a random event (x2 Money / Lucky Eggs / Fuel Frenzy)
--           runs for Config.EVENT_LENGTH seconds. Effects live where they apply (GameServer, PetServer).
--   Friend boost: +10% money per friend in the server. Group boost when Config.GROUP_ID is set.
-- State for the UI lives in attributes:
--   workspace: Event, EventEnds, RaceState ("join" | "running" | nil), RaceStartsAt, RaceEndsAt
--   player:    Friends (count), InGroup, InRace
-- Owner test commands (Studio or the game's owner):  /race   /event money|luck|fuel|off   /golden
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(className, name)
	local r = remotes:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local RaceJoin = remote("RemoteFunction", "RaceJoin") -- () -> ok, message
local RaceResult = remote("RemoteEvent", "RaceResult") -- server -> all: (list of { name, userId, distance, pct, score, place, prize })
local Notify = remote("RemoteEvent", "Notify")
local StartFlight = ServerStorage:WaitForChild("StartFlight")
local FlightEnded = ServerStorage:WaitForChild("FlightEnded")

local function now()
	return workspace:GetServerTimeNow()
end

local function addMoney(player, amount)
	amount = math.floor(amount)
	player:SetAttribute("Money", (player:GetAttribute("Money") or 0) + amount)
	player:SetAttribute("TotalEarned", (player:GetAttribute("TotalEarned") or 0) + amount)
end

-- Races -------------------------------------------------------------------------------------------
local race = nil -- { joined = {[player]=true}, racers = {[player]=true}, results = {[player]={ distance, pct, score }} }
local nextRaceAt = now() + 180 -- the first race comes a few minutes after the server starts

local function setInRace(player, on)
	player:SetAttribute("InRace", on or nil)
end

RaceJoin.OnServerInvoke = function(player)
	if not player:GetAttribute("DataLoaded") then
		return false, "Loading your save..."
	end
	if not race or workspace:GetAttribute("RaceState") ~= "join" then
		return false, "No race to join right now."
	end
	if race.joined[player] then
		return true, "You're in the race!"
	end
	race.joined[player] = true
	setInRace(player, true)
	return true, "You're in! The race starts soon 🏁"
end

local function finishRace()
	if not race or race.finished then
		return
	end
	race.finished = true
	local list = {}
	for player in pairs(race.racers or {}) do
		if player.Parent then
			local r = (race.results or {})[player] or { distance = 0, pct = 0, score = 0 }
			table.insert(list, { player = player, distance = r.distance, pct = r.pct, score = r.score })
		end
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.distance > b.distance
	end)
	local out = {}
	for place, e in ipairs(list) do
		local studs = (#list >= 2 and Config.Race.prizes[place]) or Config.Race.joinPrize -- (racing alone: join prize)
		local prize = math.floor(Config.moneyPerStud(e.player:GetAttribute("UnlockedStage") or 1) * studs)
		addMoney(e.player, prize)
		if place == 1 and #list >= 2 then
			e.player:SetAttribute("RaceWins", (e.player:GetAttribute("RaceWins") or 0) + 1)
		end
		table.insert(out, { name = e.player.DisplayName, userId = e.player.UserId, distance = e.distance, pct = e.pct, score = e.score, place = place, prize = prize })
		setInRace(e.player, false)
	end
	for player in pairs(race.joined) do
		setInRace(player, false)
	end
	if #out > 0 then
		RaceResult:FireAllClients(out)
		Notify:FireAllClients("🏁 " .. out[1].name .. " won the race (" .. out[1].pct .. "% of their track)!", Color3.fromRGB(255, 215, 80))
	end
	workspace:SetAttribute("RaceState", nil)
	race = nil
	nextRaceAt = now() + Config.Race.every
end

local function startRace()
	local joined = race.joined
	race.racers = {}
	race.results = {}
	for player in pairs(joined) do
		if player.Parent then
			if StartFlight:Invoke(player) then
				race.racers[player] = true
			else
				setInRace(player, false)
				Notify:FireClient(player, "You were still flying - catch the next race!", Color3.fromRGB(255, 200, 120))
			end
		end
	end
	if next(race.racers) == nil then
		workspace:SetAttribute("RaceState", nil)
		race = nil
		nextRaceAt = now() + Config.Race.every
		return
	end
	workspace:SetAttribute("RaceState", "running")
	workspace:SetAttribute("RaceEndsAt", now() + Config.Race.maxTime)
	local this = race
	task.delay(Config.Race.maxTime, function()
		if race == this then
			finishRace()
		end
	end)
end

local function openRace(joinTime)
	if race then
		return
	end
	race = { joined = {} }
	workspace:SetAttribute("RaceState", "join")
	workspace:SetAttribute("RaceStartsAt", now() + joinTime)
	Notify:FireAllClients("🏁 A RACE starts in " .. joinTime .. " seconds! Press JOIN at the top.", Color3.fromRGB(255, 215, 80))
	local this = race
	task.delay(joinTime, function()
		if race ~= this then
			return
		end
		if next(race.joined) == nil then
			workspace:SetAttribute("RaceState", nil)
			race = nil
			nextRaceAt = now() + Config.Race.every
			return
		end
		startRace()
	end)
end

FlightEnded.Event:Connect(function(player, distance, _reason, extra) -- extra: { track, grabbed, available } (GameServer)
	if race and race.racers and race.racers[player] and not race.results[player] then
		local pct = math.floor(math.min(1, distance / math.max(1, extra.track)) * 100)
		local share = extra.available > 0 and math.min(1, extra.grabbed / extra.available) or 0
		-- whole number: % of your own track (what everyone sees); the fraction: pickup share, so it
		-- only decides between racers on the same %
		race.results[player] = { distance = distance, pct = pct, score = pct + share * 0.99 }
		for p in pairs(race.racers) do
			if p.Parent and not race.results[p] then
				return
			end
		end
		finishRace() -- everyone has landed
	end
end)

-- Server events -------------------------------------------------------------------------------------
local nextEventAt = now() + 300
local function startEvent(key)
	if not Config.Events[key] then
		return
	end
	workspace:SetAttribute("Event", key)
	workspace:SetAttribute("EventEnds", now() + Config.EVENT_LENGTH)
	Notify:FireAllClients("⚡ SERVER EVENT: " .. Config.Events[key].name .. " for 5 minutes! " .. Config.Events[key].desc, Config.Events[key].color)
end
local function stopEvent()
	workspace:SetAttribute("Event", nil)
	workspace:SetAttribute("EventEnds", nil)
end

task.spawn(function()
	local keys = {}
	for k in pairs(Config.Events) do
		table.insert(keys, k)
	end
	table.sort(keys)
	while true do
		task.wait(1)
		local t = now()
		if not race and t >= nextRaceAt and #Players:GetPlayers() > 0 then
			openRace(Config.Race.joinTime)
		end
		if t >= nextEventAt then
			nextEventAt = t + Config.EVENT_EVERY
			startEvent(keys[math.random(1, #keys)])
		end
		if workspace:GetAttribute("Event") and t >= (workspace:GetAttribute("EventEnds") or 0) then
			stopEvent()
		end
	end
end)

-- Friend + group boosts ------------------------------------------------------------------------------
local friendCache = {} -- [a.UserId .. ":" .. b.UserId] = bool
local function areFriends(a, b)
	local key = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
	if friendCache[key] == nil then
		local ok, res = pcall(a.IsFriendsWith, a, b.UserId)
		friendCache[key] = ok and res or false
	end
	return friendCache[key]
end

local function recountFriends()
	local list = Players:GetPlayers()
	for _, p in ipairs(list) do
		local n = 0
		for _, q in ipairs(list) do
			if q ~= p and areFriends(p, q) then
				n += 1
			end
		end
		p:SetAttribute("Friends", n)
	end
end

Players.PlayerAdded:Connect(function(player)
	recountFriends()
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and areFriends(player, other) then
			Notify:FireClient(other, "👥 Your friend " .. player.DisplayName .. " joined: +10% money!", Color3.fromRGB(120, 220, 255))
		end
	end
	if Config.GROUP_ID ~= 0 then
		local ok, inGroup = pcall(player.IsInGroup, player, Config.GROUP_ID)
		player:SetAttribute("InGroup", ok and inGroup or nil)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	if race then
		race.joined[player] = nil
		if race.racers and race.racers[player] then
			race.racers[player] = nil
			local waiting = false
			for p in pairs(race.racers) do
				if p.Parent and not race.results[p] then
					waiting = true
				end
			end
			if not waiting then
				finishRace() -- (no one left, or everyone left has landed)
			end
		end
	end
	task.defer(recountFriends)
end)
task.spawn(recountFriends)

-- Owner test commands ---------------------------------------------------------------------------------
local function onChat(player, msg)
	if not (RunService:IsStudio() or player.UserId == game.CreatorId) then
		return
	end
	local cmd, arg = string.match(string.lower(msg), "^/(%a+)%s*(%a*)")
	if cmd == "race" then
		if race then
			finishRace()
		end
		openRace(15)
	elseif cmd == "event" then
		if arg == "off" then
			stopEvent()
		else
			startEvent(({ money = "Money", luck = "Luck", fuel = "Fuel" })[arg] or "Money")
		end
	elseif cmd == "golden" then
		player:SetAttribute("ForceGolden", true)
		Notify:FireClient(player, "A golden coin will appear in your next flight", Color3.fromRGB(255, 215, 60))
	end
end
local function hookChat(player)
	player.Chatted:Connect(function(msg)
		onChat(player, msg)
	end)
end
Players.PlayerAdded:Connect(hookChat)
for _, p in ipairs(Players:GetPlayers()) do
	hookChat(p)
end
