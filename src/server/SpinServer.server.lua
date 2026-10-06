-- Lucky Spin (server): who has spins, what you win, and the boosts it gives.
--   Spin() -> ok, prizeIndex | message. The prize is decided and handed out here right away (so
--   leaving mid-roll never loses it); the client holds the money display until its roll lands.
-- Free spins: 1 welcome spin, +1 per Config.Spin.every seconds played (max Config.Spin.max),
-- +1 with every daily reward (ExtrasServer). Boost attributes are read by GameServer / PetServer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(game:GetService("ServerScriptService").PlayerData)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(className, name)
	local r = remotes:FindFirstChild(name) or Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local SpinRemote = remote("RemoteFunction", "Spin")
local Notify = remote("RemoteEvent", "Notify")

local ROLL_TIME = 4.4 -- matches the client's roll animation
local rng = Random.new()
local busy = {} -- [player] = true while a roll is landing

local function addMoney(player, amount)
	amount = math.floor(amount)
	player:SetAttribute("Money", (player:GetAttribute("Money") or 0) + amount)
	player:SetAttribute("TotalEarned", (player:GetAttribute("TotalEarned") or 0) + amount)
end

local function roll()
	local total = 0
	for _, p in ipairs(Config.Spin.prizes) do
		total += p.weight
	end
	local r = rng:NextNumber(0, total)
	for i, p in ipairs(Config.Spin.prizes) do
		r -= p.weight
		if r <= 0 then
			return i
		end
	end
	return 1
end

local function extend(player, attr, seconds)
	local now = os.time()
	player:SetAttribute(attr, math.max(now, player:GetAttribute(attr) or 0) + seconds)
end

local function grant(player, prize)
	if not player.Parent then
		return
	end
	local stage = player:GetAttribute("UnlockedStage") or 1
	if prize.kind == "money" then
		addMoney(player, Config.spinMoney(prize, stage))
		if prize.jackpot then
			Notify:FireAllClients("🎰 " .. player.DisplayName .. " hit the JACKPOT on the Lucky Spin!", Color3.fromRGB(255, 215, 60))
		end
	elseif prize.kind == "boostMoney" then
		extend(player, "BoostMoneyUntil", Config.Spin.boostTime)
	elseif prize.kind == "boostLuck" then
		extend(player, "BoostLuckUntil", Config.Spin.boostTime)
	elseif prize.kind == "fullBoost" then
		player:SetAttribute("FullBoost", true)
	elseif prize.kind == "pet" then
		local give = ServerStorage:FindFirstChild("GivePet")
		local kind = give and give:Invoke(player)
		if not kind then -- pets full: money instead
			addMoney(player, Config.moneyPerStud(stage) * 800)
		end
	end
	PlayerData.save(player)
end

SpinRemote.OnServerInvoke = function(player)
	if not player:GetAttribute("DataLoaded") then
		return false, "Loading your save..."
	end
	if busy[player] then
		return false, "Wait for the roll to finish!"
	end
	local spins = player:GetAttribute("Spins") or 0
	if spins <= 0 then
		return false, "No spins yet! You get one every " .. math.floor(Config.Spin.every / 60) .. " minutes you play."
	end
	busy[player] = true
	player:SetAttribute("Spins", spins - 1)
	local index = roll()
	grant(player, Config.Spin.prizes[index])
	task.delay(ROLL_TIME, function()
		busy[player] = nil -- one roll at a time
	end)
	return true, index
end

-- free spins over time --------------------------------------------------------------------------
local function welcome(player)
	repeat
		task.wait(0.5)
	until not player.Parent or player:GetAttribute("DataLoaded")
	if player.Parent and not player:GetAttribute("FirstSpin") then
		player:SetAttribute("FirstSpin", true)
		player:SetAttribute("Spins", (player:GetAttribute("Spins") or 0) + 1)
	end
end
Players.PlayerAdded:Connect(welcome)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(welcome, p)
end
Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(10)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("DataLoaded") then
				local spins = player:GetAttribute("Spins") or 0
				if spins < Config.Spin.max then
					local progress = (player:GetAttribute("SpinProgress") or 0) + 10
					if progress >= Config.Spin.every then
						progress = 0
						player:SetAttribute("Spins", spins + 1)
						Notify:FireClient(player, "🎰 You got a free LUCKY SPIN!", Color3.fromRGB(255, 215, 90))
					end
					player:SetAttribute("SpinProgress", progress)
				end
			end
		end
	end
end)
