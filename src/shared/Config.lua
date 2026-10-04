-- All game tuning lives here. Distances are in studs (shown to players as "m").
local Config = {}

Config.STAGE_LENGTH = 500
Config.NUM_STAGES = 30
Config.PATH_HALF_WIDTH = 40 -- how far left/right you can steer
Config.FLY_MIN_HEIGHT = 6 -- lowest you can fly above the path
Config.FLY_MAX_HEIGHT = 70 -- highest you can fly above the path
Config.LAND_HEIGHT = 3 -- dive below this (rocket center above the path) and the flight ends

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
	Cannon = { name = "Cannon Power", perLevel = 0.15, baseCost = 250, costGrowth = 1.5, maxLevel = 30 },
}

-- The launch cannon shoots you out with a blast of extra speed that fades back to your rocket's
-- normal speed. Upgrading Cannon Power makes the blast stronger and longer = you fly farther.
function Config.cannonBlast(level)
	level = level or 0
	return 2 + level * Config.Upgrades.Cannon.perLevel, 1.6 + level * 0.06 -- speed x, seconds
end
-- The cannon's look by level: a new cannon every 3 levels (models in ReplicatedStorage.CannonSkins).
Config.CannonTiers = {
	{ from = 0, name = "Wooden Cannon", skin = "Wooden" },
	{ from = 3, name = "Stone Cannon", skin = "Stone" },
	{ from = 6, name = "Iron Cannon", skin = "Iron" },
	{ from = 9, name = "Pirate Cannon", skin = "Pirate" },
	{ from = 12, name = "Golden Cannon", skin = "Golden" },
	{ from = 15, name = "Candy Cannon", skin = "Candy" },
	{ from = 18, name = "Ice Cannon", skin = "Ice" },
	{ from = 21, name = "Lava Cannon", skin = "Lava" },
	{ from = 24, name = "Diamond Cannon", skin = "Diamond" },
	{ from = 27, name = "Galaxy Cannon", skin = "Galaxy" },
}
-- tier table for a level, and the next tier (nil at the top)
function Config.cannonTierInfo(level)
	local tier, nextTier = Config.CannonTiers[1], nil
	for i, t in ipairs(Config.CannonTiers) do
		if (level or 0) >= t.from then
			tier, nextTier = t, Config.CannonTiers[i + 1]
		end
	end
	return tier, nextTier
end
function Config.cannonTier(level)
	return (Config.cannonTierInfo(level)).name
end

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

-- Rebirth: unlock far enough, then start over (money, stages, rockets and upgrades reset; pets and
-- trails stay) for a permanent money bonus and an extra pet slot.
Config.REBIRTH_BONUS = 0.5 -- +50% money per rebirth (added up: 2 rebirths = x2)
Config.REBIRTH_SLOTS = 3 -- each rebirth adds a pet slot, up to this many extra
function Config.rebirthStage(rebirths) -- stage you must unlock for your next rebirth
	return math.min(Config.NUM_STAGES, 8 + rebirths * 2)
end
function Config.rebirthMultiplier(rebirths)
	return 1 + rebirths * Config.REBIRTH_BONUS
end
function Config.petSlots(rebirths)
	return (Config.MAX_EQUIPPED or 3) + math.min(rebirths or 0, Config.REBIRTH_SLOTS)
end

-- Eggs + pets. Each egg stands in the lobby's Egg Garden and opens once you've unlocked its stage.
-- A pet's `mult` is its money multiplier; equipped pets add up: total = 1 + sum(mult - 1).
-- Pet models live in ReplicatedStorage.PetModels / EggModels (place-only, generated meshes).
Config.MAX_EQUIPPED = 3 -- pet slots before rebirths (Config.petSlots adds one per rebirth)
Config.MAX_PETS = 60
Config.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(170, 175, 190) },
	Rare = { order = 2, color = Color3.fromRGB(70, 150, 255) },
	Epic = { order = 3, color = Color3.fromRGB(180, 80, 255) },
	Legendary = { order = 4, color = Color3.fromRGB(255, 190, 40) },
}
-- chance (%) of each rarity inside every egg
Config.RARITY_CHANCE = { Common = 60, Rare = 30, Epic = 8.5, Legendary = 1.5 }
-- multiplier = 1 + egg.bonus * RARITY_POWER[rarity]
Config.RARITY_POWER = { Common = 1, Rare = 2, Epic = 4, Legendary = 10 }

Config.Eggs = {
	{ id = "Meadow", name = "Meadow Egg", stage = 1, price = 300, bonus = 0.1, color = Color3.fromRGB(140, 220, 110),
		pets = { Common = "Puppy", Rare = "Kitty", Epic = "Bunny", Legendary = "RocketCorgi" } },
	{ id = "Jungle", name = "Jungle Egg", stage = 5, price = 2500, bonus = 0.25, color = Color3.fromRGB(60, 170, 90),
		pets = { Common = "Monkey", Rare = "Parrot", Epic = "TigerCub", Legendary = "GoldenJaguar" } },
	{ id = "Frost", name = "Frost Egg", stage = 8, price = 12000, bonus = 0.5, color = Color3.fromRGB(150, 215, 255),
		pets = { Common = "Penguin", Rare = "PolarBear", Epic = "SnowFox", Legendary = "IceDragon" } },
	{ id = "Cloud", name = "Cloud Egg", stage = 13, price = 175000, bonus = 1.2, color = Color3.fromRGB(255, 200, 235),
		pets = { Common = "CloudSheep", Rare = "Owl", Epic = "Pegasus", Legendary = "ThunderBird" } },
	{ id = "Moon", name = "Moon Egg", stage = 22, price = 21000000, bonus = 4, color = Color3.fromRGB(200, 205, 220),
		pets = { Common = "MoonBunny", Rare = "Alien", Epic = "RoboDog", Legendary = "UFOCat" } },
	{ id = "Galaxy", name = "Galaxy Egg", stage = 27, price = 290000000, bonus = 10, color = Color3.fromRGB(140, 80, 230),
		pets = { Common = "StarPuppy", Rare = "CometFox", Epic = "NebulaDragon", Legendary = "GalaxyUnicorn" } },
}

Config.PET_NAMES = {
	Puppy = "Puppy", Kitty = "Kitty", Bunny = "Bunny", RocketCorgi = "Rocket Corgi",
	Monkey = "Monkey", Parrot = "Parrot", TigerCub = "Tiger Cub", GoldenJaguar = "Golden Jaguar",
	Penguin = "Penguin", PolarBear = "Polar Bear", SnowFox = "Snow Fox", IceDragon = "Ice Dragon",
	CloudSheep = "Cloud Sheep", Owl = "Owl", Pegasus = "Pegasus", ThunderBird = "Thunder Bird",
	MoonBunny = "Moon Bunny", Alien = "Alien", RoboDog = "Robo Dog", UFOCat = "UFO Cat",
	StarPuppy = "Star Puppy", CometFox = "Comet Fox", NebulaDragon = "Nebula Dragon", GalaxyUnicorn = "Galaxy Unicorn",
}

-- Pets[kind] = { id, name, egg, rarity, mult } (built from the eggs above)
Config.Pets = {}
for _, egg in ipairs(Config.Eggs) do
	for rarity, kind in pairs(egg.pets) do
		Config.Pets[kind] = {
			id = kind,
			name = Config.PET_NAMES[kind] or kind,
			egg = egg.id,
			rarity = rarity,
			mult = math.floor((1 + egg.bonus * Config.RARITY_POWER[rarity]) * 100 + 0.5) / 100,
		}
	end
end

function Config.getEgg(id)
	for _, e in ipairs(Config.Eggs) do
		if e.id == id then
			return e
		end
	end
end

-- Saved pet list format (player attribute "Pets"): "uid:Kind;uid:Kind". Equipped: "uid,uid".
function Config.parsePets(s)
	local list = {}
	for entry in string.gmatch(s or "", "[^;]+") do
		local uid, kind = entry:match("^(%d+):(%w+)$")
		if uid and Config.Pets[kind] then
			table.insert(list, { uid = tonumber(uid), kind = kind })
		end
	end
	return list
end

function Config.parseEquipped(s)
	local set = {}
	for uid in string.gmatch(s or "", "%d+") do
		set[tonumber(uid)] = true
	end
	return set
end

-- Total money multiplier from a list of pet kinds.
function Config.petMultiplier(kinds)
	local m = 1
	for _, kind in ipairs(kinds) do
		local p = Config.Pets[kind]
		if p then
			m += p.mult - 1
		end
	end
	return m
end

-- "x1.25" style text for a multiplier
function Config.multText(m)
	if m >= 100 then
		return "x" .. Config.abbreviate(m)
	end
	local s = string.format("%.2f", m):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. s
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
