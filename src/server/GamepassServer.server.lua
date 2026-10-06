-- Gamepasses (Config.Gamepasses): checks what each player owns, gives it right after a purchase,
-- and puts the rank tag (rebirths, stage, VIP) over players' heads.
-- Owning a pass = attribute "Pass_<key>" = true; the effects live where they apply
-- (GameServer money / fuel, PetServer slots / luck / rainbow).
-- Studio / owner test command in chat:  /pass all   /pass VIP   /pass none
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = remotes:WaitForChild("Notify")

local function passByKey(key)
	for _, p in ipairs(Config.Gamepasses) do
		if string.lower(p.key) == string.lower(key) then
			return p
		end
	end
end

local function passById(id)
	for _, p in ipairs(Config.Gamepasses) do
		if p.id ~= 0 and p.id == id then
			return p
		end
	end
end

-- tag over the head: rebirth stars + stage, and a gold VIP pill under it.
-- New players (stage 1-2, no rebirths, no VIP) get no tag, so the lobby isn't cluttered.
local INK = Color3.fromRGB(30, 30, 50)

local function headTag(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local legacy = head:FindFirstChild("VIPTag") -- (the old VIP-only tag)
	if legacy then
		legacy:Destroy()
	end
	local r = player:GetAttribute("Rebirths") or 0
	local stage = player:GetAttribute("UnlockedStage") or 1
	local vip = Config.hasPass(player, "VIP")
	local bb = head:FindFirstChild("RankTag")
	if not (r > 0 or stage >= 3 or vip) then
		if bb then
			bb:Destroy()
		end
		return
	end
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "RankTag"
		bb.Size = UDim2.fromOffset(150, 48)
		bb.StudsOffset = Vector3.new(0, 2.8, 0)
		bb.MaxDistance = 120
		bb.LightInfluence = 0
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom -- the rank line drops down to the head when there's no VIP line
		list.Padding = UDim.new(0, 2)
		list.Parent = bb
		-- line 1: rebirths + stage
		local rank = Instance.new("TextLabel")
		rank.Name = "Rank"
		rank.LayoutOrder = 1
		rank.Size = UDim2.new(1, 0, 0.5, -1)
		rank.BackgroundTransparency = 1
		rank.Font = Enum.Font.FredokaOne
		rank.TextScaled = true
		rank.TextColor3 = Color3.new(1, 1, 1)
		local rs = Instance.new("UIStroke")
		rs.Thickness = 2.5
		rs.Color = INK
		rs.Parent = rank
		rank.Parent = bb
		-- line 2: gold VIP pill
		local l = Instance.new("TextLabel")
		l.Name = "VIP"
		l.LayoutOrder = 2
		l.Size = UDim2.new(0.72, 0, 0.5, -1)
		l.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Text = "👑 VIP"
		l.TextColor3 = Color3.new(1, 1, 1)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = l
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = INK
		s.Parent = l
		local ts = Instance.new("UIStroke")
		ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ts.Thickness = 3
		ts.Color = INK
		ts.Parent = l
		l.Parent = bb
		bb.Parent = head
	end
	bb.Enabled = not player:GetAttribute("Flying") -- hidden while flying (it would sit in front of the rocket)
	bb.Rank.Text = (r > 0 and ("🌟" .. r .. " • ") or "") .. "Stage " .. stage
	bb.VIP.Visible = vip
end

local function give(player, pass, announce)
	if Config.hasPass(player, pass.key) then
		return
	end
	player:SetAttribute("Pass_" .. pass.key, true)
	if announce then
		Notify:FireAllClients("🎉 " .. player.DisplayName .. " got " .. pass.name .. "!", Color3.fromRGB(255, 210, 90))
	end
end

-- ownership check with retries (2 s, then 4 s); returns ok, owned
local function owns(player, id)
	for i = 1, 3 do
		local ok, res = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
		if ok then
			return true, res
		end
		if not player.Parent or i == 3 then
			return false
		end
		task.wait(2 ^ i)
	end
	return false
end

local function check(player)
	if player.UserId == game.CreatorId and not Config.OWNER_GETS_PASSES then
		headTag(player)
		return -- (the owner plays without the free creator passes; /pass all to test them)
	end
	local pending = {} -- passes whose check failed every time
	for _, pass in ipairs(Config.Gamepasses) do
		if pass.id ~= 0 then
			local ok, owned = owns(player, pass.id)
			if not ok then
				table.insert(pending, pass)
			elseif owned then
				give(player, pass, false)
			end
		end
	end
	if #pending > 0 and player.Parent then
		warn("Gamepass check failed for " .. player.Name .. ", retrying every 60 s")
		task.spawn(function()
			while player.Parent and #pending > 0 do
				task.wait(60)
				for i = #pending, 1, -1 do
					if not player.Parent then
						return
					end
					local ok, owned = owns(player, pending[i].id)
					if ok then
						if owned then
							give(player, pending[i], false)
						end
						table.remove(pending, i)
					end
				end
			end
		end)
	end
	headTag(player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, bought)
	local pass = bought and passById(id)
	if pass then
		give(player, pass, true)
		headTag(player)
	end
end)

local function onChat(player, msg)
	if not (RunService:IsStudio() or player.UserId == game.CreatorId) then
		return
	end
	local arg = string.match(string.lower(msg), "^/pass%s+(%w+)")
	if not arg then
		return
	end
	for _, pass in ipairs(Config.Gamepasses) do
		if arg == "all" or arg == string.lower(pass.key) then
			player:SetAttribute("Pass_" .. pass.key, true)
		elseif arg == "none" then
			player:SetAttribute("Pass_" .. pass.key, nil)
		end
	end
	headTag(player)
	Notify:FireClient(player, "Test passes: " .. arg, Color3.fromRGB(130, 255, 130))
end

local function setup(player)
	player.Chatted:Connect(function(msg)
		onChat(player, msg)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		headTag(player)
	end)
	player:GetAttributeChangedSignal("Pass_VIP"):Connect(function()
		headTag(player)
	end)
	for _, attr in ipairs({ "Flying", "Rebirths", "UnlockedStage", "DataLoaded" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			headTag(player)
		end)
	end
	task.spawn(check, player)
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do
	setup(p)
end
