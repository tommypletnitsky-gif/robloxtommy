-- All game tuning lives here. Distances are in studs (shown to players as "m").
local Config = {}

Config.STAGE_LENGTH = 500
Config.NUM_STAGES = 30
Config.PATH_HALF_WIDTH = 40 -- how far left/right you can steer
Config.FLY_MIN_HEIGHT = 6 -- lowest you can fly above the path
Config.FLY_MAX_HEIGHT = 70 -- highest you can fly above the path
Config.STEER_SPEED = 30 -- studs/sec you move up/down/sideways

Config.HUB_CENTER = Vector3.new(-95, 0, 0)
Config.LAUNCH_X = 0 -- start line; stage 1 begins here

Config.SKY_RISE = 600 -- how high the path climbs through the Sky zone

-- Money
Config.MONEY_PER_STUD = 1 -- in stage 1
Config.STAGE_MONEY_GROWTH = 1.7 -- each stage pays this much more per stud
Config.STAGE_COST_BASE = 500 -- price of stage 2
Config.STAGE_COST_GROWTH = 2.2

-- Stages: Earth (1-10) -> Sky (11-20) -> Space (21-30)
Config.Stages = {
	{ name = "Grassy Meadow", zone = "Earth", ground = Color3.fromRGB(106, 176, 76), decor = "tree" },
	{ name = "Sunny Farm", zone = "Earth", ground = Color3.fromRGB(156, 190, 80), decor = "hay" },
	{ name = "Dusty Desert", zone = "Earth", ground = Color3.fromRGB(226, 196, 132), decor = "cactus" },
	{ name = "Red Canyon", zone = "Earth", ground = Color3.fromRGB(196, 110, 70), decor = "rock" },
	{ name = "Deep Jungle", zone = "Earth", ground = Color3.fromRGB(46, 120, 60), decor = "palm" },
	{ name = "Misty Swamp", zone = "Earth", ground = Color3.fromRGB(84, 100, 70), decor = "tree" },
	{ name = "Snowy Tundra", zone = "Earth", ground = Color3.fromRGB(235, 240, 245), decor = "pine" },
	{ name = "Icy Peaks", zone = "Earth", ground = Color3.fromRGB(170, 215, 240), decor = "crystal" },
	{ name = "Volcano", zone = "Earth", ground = Color3.fromRGB(60, 45, 45), decor = "lava" },
	{ name = "Mountain Top", zone = "Earth", ground = Color3.fromRGB(130, 130, 140), decor = "rock" },

	{ name = "Low Clouds", zone = "Sky", ground = Color3.fromRGB(245, 245, 255), decor = "cloud" },
	{ name = "Cloud Kingdom", zone = "Sky", ground = Color3.fromRGB(255, 250, 235), decor = "cloud" },
	{ name = "Rainbow Bridge", zone = "Sky", ground = Color3.fromRGB(255, 200, 230), decor = "rainbow" },
	{ name = "Thunder Storm", zone = "Sky", ground = Color3.fromRGB(120, 125, 140), decor = "storm" },
	{ name = "Sunset Sky", zone = "Sky", ground = Color3.fromRGB(255, 170, 110), decor = "cloud" },
	{ name = "Floating Islands", zone = "Sky", ground = Color3.fromRGB(150, 210, 120), decor = "island" },
	{ name = "Aurora Lights", zone = "Sky", ground = Color3.fromRGB(120, 230, 200), decor = "crystal" },
	{ name = "Stratosphere", zone = "Sky", ground = Color3.fromRGB(150, 180, 240), decor = "cloud" },
	{ name = "Jet Stream", zone = "Sky", ground = Color3.fromRGB(110, 150, 230), decor = "storm" },
	{ name = "Edge of Space", zone = "Sky", ground = Color3.fromRGB(60, 70, 140), decor = "star" },

	{ name = "Low Orbit", zone = "Space", ground = Color3.fromRGB(70, 90, 160), decor = "star" },
	{ name = "The Moon", zone = "Space", ground = Color3.fromRGB(200, 200, 200), decor = "asteroid" },
	{ name = "Asteroid Belt", zone = "Space", ground = Color3.fromRGB(120, 100, 85), decor = "asteroid" },
	{ name = "Mars", zone = "Space", ground = Color3.fromRGB(200, 90, 50), decor = "planet" },
	{ name = "Jupiter", zone = "Space", ground = Color3.fromRGB(210, 160, 110), decor = "planet" },
	{ name = "Saturn Rings", zone = "Space", ground = Color3.fromRGB(230, 210, 150), decor = "planet" },
	{ name = "Purple Nebula", zone = "Space", ground = Color3.fromRGB(160, 80, 220), decor = "star" },
	{ name = "Ice Giant", zone = "Space", ground = Color3.fromRGB(110, 200, 230), decor = "planet" },
	{ name = "Black Hole", zone = "Space", ground = Color3.fromRGB(40, 20, 60), decor = "asteroid" },
	{ name = "Galaxy Core", zone = "Space", ground = Color3.fromRGB(255, 220, 120), decor = "star" },
}

-- Rockets: speed = studs/sec, fuel = seconds of thrust. Bought in the shop (step 2).
Config.Rockets = {
	{ id = "Starter", name = "Starter Rocket", speed = 40, fuel = 5, price = 0, color = Color3.fromRGB(230, 230, 235), accent = Color3.fromRGB(220, 50, 50) },
	{ id = "Bottle", name = "Bottle Rocket", speed = 50, fuel = 6, price = 1000, color = Color3.fromRGB(120, 200, 255), accent = Color3.fromRGB(40, 90, 200) },
	{ id = "Firework", name = "Firework", speed = 60, fuel = 7.5, price = 6000, color = Color3.fromRGB(255, 80, 80), accent = Color3.fromRGB(255, 220, 60) },
	{ id = "Turbo", name = "Turbo Rocket", speed = 75, fuel = 9, price = 40000, color = Color3.fromRGB(255, 150, 30), accent = Color3.fromRGB(40, 40, 40) },
	{ id = "Jet", name = "Jet Rocket", speed = 90, fuel = 11, price = 250000, color = Color3.fromRGB(80, 80, 90), accent = Color3.fromRGB(0, 200, 255) },
	{ id = "Shuttle", name = "Space Shuttle", speed = 110, fuel = 13, price = 1500000, color = Color3.fromRGB(245, 245, 245), accent = Color3.fromRGB(30, 30, 30) },
	{ id = "Plasma", name = "Plasma Rocket", speed = 135, fuel = 15, price = 10000000, color = Color3.fromRGB(170, 60, 255), accent = Color3.fromRGB(255, 120, 255) },
	{ id = "Galaxy", name = "Galaxy Rocket", speed = 165, fuel = 18, price = 80000000, color = Color3.fromRGB(20, 20, 60), accent = Color3.fromRGB(120, 200, 255) },
	{ id = "Quantum", name = "Quantum Rocket", speed = 200, fuel = 21, price = 700000000, color = Color3.fromRGB(0, 255, 170), accent = Color3.fromRGB(255, 255, 255) },
	{ id = "Nova", name = "Nova Rocket", speed = 250, fuel = 25, price = 6000000000, color = Color3.fromRGB(255, 215, 0), accent = Color3.fromRGB(255, 80, 0) },
}

-- Upgrades (shop, step 2). Each level adds `perLevel` (as a fraction) to that stat.
Config.Upgrades = {
	Fuel = { name = "Fuel Tank", perLevel = 0.08, baseCost = 100, costGrowth = 1.45, maxLevel = 30 },
	Speed = { name = "Engine", perLevel = 0.05, baseCost = 150, costGrowth = 1.45, maxLevel = 30 },
	Money = { name = "Money Boost", perLevel = 0.10, baseCost = 200, costGrowth = 1.5, maxLevel = 30 },
}

-- Trails behind your rocket (bought with money in the Rockets window).
Config.Trails = {
	{ id = "None", name = "No Trail", price = 0, colors = { Color3.fromRGB(255, 255, 255) } },
	{ id = "Smoke", name = "Puffy Smoke", price = 500, colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 210) } },
	{ id = "Fire", name = "Fire", price = 3000, colors = { Color3.fromRGB(255, 240, 80), Color3.fromRGB(255, 120, 20), Color3.fromRGB(200, 30, 10) }, glow = 1 },
	{ id = "Ocean", name = "Ocean", price = 15000, colors = { Color3.fromRGB(120, 240, 255), Color3.fromRGB(30, 120, 255) }, glow = 0.6 },
	{ id = "Candy", name = "Candy", price = 75000, colors = { Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 220, 255) }, glow = 0.4 },
	{ id = "Toxic", name = "Toxic", price = 400000, colors = { Color3.fromRGB(180, 255, 60), Color3.fromRGB(40, 200, 40) }, glow = 1 },
	{ id = "Galaxy", name = "Galaxy", price = 3000000, colors = { Color3.fromRGB(80, 40, 200), Color3.fromRGB(200, 80, 255), Color3.fromRGB(255, 255, 255) }, glow = 1 },
	{ id = "Rainbow", name = "Rainbow", price = 25000000, colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 200, 40), Color3.fromRGB(80, 230, 80), Color3.fromRGB(60, 160, 255), Color3.fromRGB(200, 80, 255) }, glow = 1 },
}

function Config.getTrail(id)
	for _, t in ipairs(Config.Trails) do
		if t.id == id then
			return t
		end
	end
	return Config.Trails[1]
end

-- Things along the path. Coins/gems pay like flying `studs` extra studs in that stage.
Config.Pickups = {
	Coin = { studs = 20, perStage = 14 },
	Gem = { studs = 120, perStage = 2 },
	Ring = { perStage = 3, fuel = 1.5, boost = 1.6, boostTime = 1.5 }, -- +fuel seconds, speed x1.6
	Obstacle = { perStage = 4, fuelLoss = 1, slow = 0.45, slowTime = 0.9 },
}
Config.PICKUP_RADIUS = 9 -- generous on purpose: it should feel easy to grab coins

-- Free gifts: unlock after this many minutes of play in one session.
Config.GiftMinutes = { 1, 3, 5, 8, 12, 16, 20, 25, 30, 40 }
function Config.giftReward(stage, index)
	return math.floor(Config.moneyPerStud(stage) * (120 + index * 60))
end
-- Daily login reward (streak day 1..7, then repeats at day 7 value).
function Config.dailyReward(stage, day)
	return math.floor(Config.moneyPerStud(stage) * 400 * math.min(day, 7))
end

-- Robux donations. Create Developer Products on the Creator Dashboard, then paste their ids here.
-- id = 0 means "not set up yet" and the button shows as coming soon.
Config.Donations = {
	{ robux = 10, id = 0 },
	{ robux = 50, id = 0 },
	{ robux = 100, id = 0 },
	{ robux = 500, id = 0 },
	{ robux = 1000, id = 0 },
}

-- Sounds (Creator Store audio)
Config.Sounds = {
	Launch = "rbxassetid://12222065",
	Engine = "rbxassetid://12222095",
	Coin = "rbxassetid://1169806635",
	Beep = "rbxassetid://117751546358455",
	Boost = "rbxassetid://3406813517",
	Click = "rbxassetid://100836780668038",
	Win = "rbxassetid://1840076509",
	Hit = "rbxasset://sounds/impact_explosion_03.mp3",
	LobbyMusic = "rbxassetid://9047876673",
	FlightMusic = "rbxassetid://82132213006755",
}

function Config.getRocket(id)
	for _, r in ipairs(Config.Rockets) do
		if r.id == id then
			return r
		end
	end
	return Config.Rockets[1]
end

-- Stage number (1..NUM_STAGES) for a distance along the path.
function Config.stageAt(x)
	local s = math.floor((x - Config.LAUNCH_X) / Config.STAGE_LENGTH) + 1
	return math.clamp(s, 1, Config.NUM_STAGES)
end

-- Height of the path at distance x: flat on Earth, climbs through the Sky, flat in Space.
function Config.pathY(x)
	local d = x - Config.LAUNCH_X
	local skyStart = 10 * Config.STAGE_LENGTH
	local skyEnd = 20 * Config.STAGE_LENGTH
	if d <= skyStart then
		return 0
	elseif d >= skyEnd then
		return Config.SKY_RISE
	end
	return (d - skyStart) / (skyEnd - skyStart) * Config.SKY_RISE
end

function Config.stageEndX(stage)
	return Config.LAUNCH_X + stage * Config.STAGE_LENGTH
end

function Config.moneyPerStud(stage)
	return Config.MONEY_PER_STUD * Config.STAGE_MONEY_GROWTH ^ (stage - 1)
end

-- Money for flying `distance` studs from the start line (before multipliers).
function Config.moneyForDistance(distance)
	local total = 0
	for s = 1, Config.NUM_STAGES do
		local a = (s - 1) * Config.STAGE_LENGTH
		local b = s * Config.STAGE_LENGTH
		if distance <= a then
			break
		end
		total += (math.min(distance, b) - a) * Config.moneyPerStud(s)
	end
	return total
end

function Config.stageCost(stage)
	if stage <= 1 then
		return 0
	end
	return math.floor(Config.STAGE_COST_BASE * Config.STAGE_COST_GROWTH ^ (stage - 2))
end

function Config.upgradeCost(key, level)
	local u = Config.Upgrades[key]
	return math.floor(u.baseCost * u.costGrowth ^ level)
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
function Config.abbreviate(n)
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local i = 1
	local v = n
	while v >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local num
	if v < 10 then
		num = string.format("%.2f", math.floor(v * 100) / 100)
	elseif v < 100 then
		num = string.format("%.1f", math.floor(v * 10) / 10)
	else
		num = tostring(math.floor(v))
	end
	num = num:find("%.") and num:gsub("0+$", ""):gsub("%.$", "") or num -- 1.50 -> 1.5, 1.00 -> 1
	return num .. SUFFIXES[i]
end

-- Distances read best as full meters with commas: 12,500m
function Config.meters(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", "")) .. "m"
end

return Config
