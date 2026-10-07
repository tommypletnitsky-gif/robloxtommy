-- Quests (claim the money for a finished goal), daily missions, codes, and saved settings.
--   ClaimQuest(questId)  -> ok, message
--   ClaimMission(id)     -> ok, message   (daily missions: 3 a day, all 3 = a Lucky Spin)
--   RedeemCode(text)     -> ok, message
--   SetSetting(name, on) -> (MusicOn / SoundOn, saved with your progress)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(ServerScriptService.PlayerData)

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function remote(className, name)
	local r = remotes:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local ClaimQuest = remote("RemoteFunction", "ClaimQuest")
local ClaimMission = remote("RemoteFunction", "ClaimMission")
local RedeemCode = remote("RemoteFunction", "RedeemCode")
local SetSetting = remote("RemoteEvent", "SetSetting")

local function addMoney(player, amount)
	amount = math.floor(amount)
	player:SetAttribute("Money", (player:GetAttribute("Money") or 0) + amount)
	player:SetAttribute("TotalEarned", (player:GetAttribute("TotalEarned") or 0) + amount)
end

local function questById(id)
	for _, q in ipairs(Config.Quests) do
		if q.id == id then
			return q
		end
	end
end

local busy = {}
ClaimQuest.OnServerInvoke = function(player, id)
	local q = typeof(id) == "string" and questById(id)
	if not q or busy[player] or not player:GetAttribute("DataLoaded") then
		return false, "Unknown quest."
	end
	local tiers = Config.parseQuestTiers(player:GetAttribute("QuestTiers"))
	local done = tiers[q.id] or 0
	local goal = q.goals[done + 1]
	if not goal then
		return false, "All done!"
	end
	if (player:GetAttribute(q.stat) or 0) < goal then
		return false, "Not finished yet!"
	end
	busy[player] = true
	tiers[q.id] = done + 1
	local parts = {}
	for qid, n in pairs(tiers) do
		table.insert(parts, qid .. ":" .. n)
	end
	player:SetAttribute("QuestTiers", table.concat(parts, ","))
	local reward = Config.questReward(player:GetAttribute("UnlockedStage") or 1, done + 1)
	addMoney(player, reward)
	busy[player] = nil
	return true, "Quest complete! +$" .. Config.abbreviate(reward)
end

-- Daily missions ---------------------------------------------------------------------------------
local missionRng = Random.new()
local function rollMissions(player)
	local day = Config.missionDay()
	if player:GetAttribute("MissionDay") == day and (player:GetAttribute("Missions") or "") ~= "" then
		return
	end
	local stage = player:GetAttribute("UnlockedStage") or 1
	local pool = {}
	for _, m in ipairs(Config.Missions) do
		if stage >= (m.minStage or 1) then
			table.insert(pool, m)
		end
	end
	local list = {}
	for _ = 1, math.min(Config.MISSIONS_PER_DAY, #pool) do
		local m = table.remove(pool, missionRng:NextInteger(1, #pool))
		table.insert(list, { id = m.id, goal = m.amount(stage), start = math.floor(player:GetAttribute(m.stat) or 0), stage = stage })
	end
	player:SetAttribute("Missions", Config.joinMissions(list))
	player:SetAttribute("MissionsClaimed", "")
	player:SetAttribute("MissionBonus", false)
	player:SetAttribute("MissionDay", day)
end

ClaimMission.OnServerInvoke = function(player, id)
	if typeof(id) ~= "string" or busy[player] or not player:GetAttribute("DataLoaded") then
		return false, "Unknown mission."
	end
	rollMissions(player) -- (a new day may have started)
	local entry
	for _, e in ipairs(Config.parseMissions(player:GetAttribute("Missions"))) do
		if e.id == id then
			entry = e
		end
	end
	local m = entry and Config.getMission(id)
	if not m then
		return false, "That mission is gone - check today's missions!"
	end
	local claimed = string.split(player:GetAttribute("MissionsClaimed") or "", ",")
	if table.find(claimed, id) then
		return false, "Already claimed!"
	end
	if (player:GetAttribute(m.stat) or 0) - entry.start < entry.goal then
		return false, "Not finished yet!"
	end
	busy[player] = true
	table.insert(claimed, id)
	player:SetAttribute("MissionsClaimed", table.concat(claimed, ","))
	local reward = Config.missionReward(entry.stage or player:GetAttribute("UnlockedStage") or 1)
	addMoney(player, reward)
	local msg = "Mission complete! +$" .. Config.abbreviate(reward)
	local currency = Config.seasonCurrency()
	if currency then
		player:SetAttribute(currency, (player:GetAttribute(currency) or 0) + Config.Candy.Mission)
		msg ..= " +" .. Config.Candy.Mission .. (currency == "Candy" and " 🍬" or " ❄")
	end
	local all = true
	for _, e in ipairs(Config.parseMissions(player:GetAttribute("Missions"))) do
		if not table.find(claimed, e.id) then
			all = false
		end
	end
	if all and not player:GetAttribute("MissionBonus") then
		player:SetAttribute("MissionBonus", true)
		player:SetAttribute("Spins", (player:GetAttribute("Spins") or 0) + 1)
		msg ..= "  •  All 3 done: +1 LUCKY SPIN!"
	end
	PlayerData.save(player)
	busy[player] = nil
	return true, msg
end

-- pick missions on join, and again when a new day starts while you play
local function missionsFor(player)
	repeat
		task.wait(0.5)
	until not player.Parent or player:GetAttribute("DataLoaded")
	if player.Parent then
		rollMissions(player)
	end
end
-- After a rebirth (back to stage 1) unclaimed goals shrink to what a new stage-1 set would ask
-- (progress made today still counts; the reward stays at the stage they were picked at).
local function easeMissions(player)
	local list = Config.parseMissions(player:GetAttribute("Missions"))
	local claimed = string.split(player:GetAttribute("MissionsClaimed") or "", ",")
	local stage = player:GetAttribute("UnlockedStage") or 1
	local changed = false
	for _, e in ipairs(list) do
		local m = Config.getMission(e.id)
		if m and not table.find(claimed, e.id) then
			local goal = m.amount(stage)
			if goal < e.goal then
				e.goal = goal
				changed = true
			end
		end
	end
	if changed then
		player:SetAttribute("Missions", Config.joinMissions(list))
	end
end
Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		easeMissions(player)
	end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	p:GetAttributeChangedSignal("Rebirths"):Connect(function()
		easeMissions(p)
	end)
end
Players.PlayerAdded:Connect(missionsFor)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(missionsFor, p)
end
task.spawn(function()
	while true do
		task.wait(30)
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("DataLoaded") then
				rollMissions(p)
			end
		end
	end
end)

RedeemCode.OnServerInvoke = function(player, text)
	if typeof(text) ~= "string" or #text > 30 or not player:GetAttribute("DataLoaded") then
		return false, "That code doesn't work."
	end
	local code = string.upper((text:gsub("%s", "")))
	local base = Config.Codes[code]
	if not base then
		return false, "That code doesn't work."
	end
	local used = string.split(player:GetAttribute("Codes") or "", ",")
	if table.find(used, code) then
		return false, "You already used that code!"
	end
	table.insert(used, code)
	player:SetAttribute("Codes", table.concat(used, ","))
	local reward = math.floor(base * Config.moneyPerStud(player:GetAttribute("UnlockedStage") or 1))
	addMoney(player, reward)
	PlayerData.save(player)
	return true, "Code " .. code .. ": +$" .. Config.abbreviate(reward) .. "!"
end

SetSetting.OnServerEvent:Connect(function(player, name, on)
	if (name == "MusicOn" or name == "SoundOn") and typeof(on) == "boolean" then
		player:SetAttribute(name, on)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
