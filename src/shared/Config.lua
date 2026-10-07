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
Config.STAGE_COST_BASE = 2000 -- price of stage 2
Config.STAGE_COST_GROWTH = 2.9 -- grows much faster than income (x1.7): later stages take many flights (balance v3)

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
	{ id = "Bottle", name = "Bottle Rocket", speed = 50, fuel = 6, price = 3000, color = Color3.fromRGB(120, 200, 255), accent = Color3.fromRGB(40, 90, 200) },
	{ id = "Firework", name = "Firework", speed = 60, fuel = 7.5, price = 18000, color = Color3.fromRGB(255, 80, 80), accent = Color3.fromRGB(255, 220, 60) },
	{ id = "Turbo", name = "Turbo Rocket", speed = 75, fuel = 9, price = 120000, color = Color3.fromRGB(255, 150, 30), accent = Color3.fromRGB(40, 40, 40) },
	{ id = "Jet", name = "Jet Rocket", speed = 90, fuel = 11, price = 750000, color = Color3.fromRGB(80, 80, 90), accent = Color3.fromRGB(0, 200, 255) },
	{ id = "Shuttle", name = "Space Shuttle", speed = 110, fuel = 13, price = 4500000, color = Color3.fromRGB(245, 245, 245), accent = Color3.fromRGB(30, 30, 30) },
	{ id = "Plasma", name = "Plasma Rocket", speed = 135, fuel = 15, price = 30000000, color = Color3.fromRGB(170, 60, 255), accent = Color3.fromRGB(255, 120, 255) },
	{ id = "Galaxy", name = "Galaxy Rocket", speed = 165, fuel = 18, price = 240000000, color = Color3.fromRGB(20, 20, 60), accent = Color3.fromRGB(120, 200, 255) },
	{ id = "Quantum", name = "Quantum Rocket", speed = 200, fuel = 21, price = 2100000000, color = Color3.fromRGB(0, 255, 170), accent = Color3.fromRGB(255, 255, 255) },
	{ id = "Nova", name = "Nova Rocket", speed = 250, fuel = 25, price = 18000000000, color = Color3.fromRGB(255, 215, 0), accent = Color3.fromRGB(255, 80, 0) },
}

-- Upgrades (shop, step 2). Each level adds `perLevel` (as a fraction) to that stat.
Config.Upgrades = {
	Fuel = { name = "Fuel Tank", perLevel = 0.08, baseCost = 200, costGrowth = 1.75, maxLevel = 30 },
	Speed = { name = "Engine", perLevel = 0.05, baseCost = 300, costGrowth = 1.75, maxLevel = 30 },
	Money = { name = "Money Boost", perLevel = 0.07, baseCost = 400, costGrowth = 1.8, maxLevel = 30 },
	Cannon = { name = "Cannon Power", perLevel = 0.15, baseCost = 500, costGrowth = 1.75, maxLevel = 30 },
}

-- The launch cannon shoots you out with a blast of extra speed that fades back to your rocket's
-- normal speed. Upgrading Cannon Power makes the blast stronger and longer = you fly farther.
function Config.cannonBlast(level)
	level = level or 0
	return 2 + level * Config.Upgrades.Cannon.perLevel, 1.6 + level * 0.06 -- speed x, seconds
end
-- Speed x from the blast, t seconds after launch (fades from `power` back to 1 over `time`).
-- The client flies with it and the server's distance cap follows it.
function Config.blastMult(t, power, time)
	return (time > 0 and t < time) and 1 + (power - 1) * (1 - t / time) ^ 1.4 or 1
end
-- Forward speed x while gliding, t seconds after the fuel ran out (client flight + server cap).
function Config.glideMult(t)
	return math.max(0.08, 0.3 - t * 0.1 + 0.7 * math.exp(-t * 3))
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
-- rebirth = n: free, but only after n rebirths (one new trail to collect per rebirth).
Config.Trails = {
	{ id = "None", name = "No Trail", price = 0, colors = { Color3.fromRGB(255, 255, 255) } },
	{ id = "Smoke", name = "Puffy Smoke", price = 500, colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 210) } },
	{ id = "Fire", name = "Fire", price = 3000, colors = { Color3.fromRGB(255, 240, 80), Color3.fromRGB(255, 120, 20), Color3.fromRGB(200, 30, 10) }, glow = 1 },
	{ id = "Ocean", name = "Ocean", price = 15000, colors = { Color3.fromRGB(120, 240, 255), Color3.fromRGB(30, 120, 255) }, glow = 0.6 },
	{ id = "Candy", name = "Candy", price = 75000, colors = { Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 220, 255) }, glow = 0.4 },
	{ id = "Toxic", name = "Toxic", price = 400000, colors = { Color3.fromRGB(180, 255, 60), Color3.fromRGB(40, 200, 40) }, glow = 1 },
	{ id = "Galaxy", name = "Galaxy", price = 3000000, colors = { Color3.fromRGB(80, 40, 200), Color3.fromRGB(200, 80, 255), Color3.fromRGB(255, 255, 255) }, glow = 1 },
	{ id = "Rainbow", name = "Rainbow", price = 25000000, colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 200, 40), Color3.fromRGB(80, 230, 80), Color3.fromRGB(60, 160, 255), Color3.fromRGB(200, 80, 255) }, glow = 1 },
	{ id = "Stardust", name = "Stardust", rebirth = 1, price = 0, colors = { Color3.fromRGB(255, 250, 225), Color3.fromRGB(255, 215, 110), Color3.fromRGB(255, 170, 230) }, glow = 1 },
	{ id = "Comet", name = "Comet", rebirth = 2, price = 0, colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 220, 255), Color3.fromRGB(40, 90, 220) }, glow = 1 },
	{ id = "Aurora", name = "Aurora", rebirth = 3, price = 0, colors = { Color3.fromRGB(90, 255, 170), Color3.fromRGB(60, 200, 255), Color3.fromRGB(180, 90, 255) }, glow = 0.8 },
	{ id = "Supernova", name = "Supernova", rebirth = 5, price = 0, colors = { Color3.fromRGB(255, 255, 240), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 80, 40), Color3.fromRGB(220, 40, 160) }, glow = 1 },
	{ id = "BlackHole", name = "Black Hole", rebirth = 8, price = 0, colors = { Color3.fromRGB(255, 170, 60), Color3.fromRGB(130, 50, 210), Color3.fromRGB(25, 10, 45) }, glow = 0.3 },
}

function Config.getTrail(id)
	for _, t in ipairs(Config.Trails) do
		if t.id == id then
			return t
		end
	end
	return Config.Trails[1]
end

-- Quests: chains of goals; finish a goal, claim the money, the next (bigger) goal appears.
-- stat = which player attribute counts the progress. Claimed tiers are saved in "QuestTiers".
Config.Quests = {
	{ id = "flights", stat = "StatFlights", icon = "Rocket", text = "Launch %s times", goals = { 1, 5, 15, 40, 100, 250, 600 } },
	{ id = "best", stat = "BestDistance", icon = "Trophy", text = "Fly %sm in one flight", goals = { 300, 500, 1000, 2000, 3500, 5000, 8000, 12000, 15000 } },
	{ id = "distance", stat = "StatDistance", icon = "Bolt", text = "Fly %sm in total", goals = { 1000, 5000, 20000, 75000, 250000, 1000000, 4000000 } },
	{ id = "coins", stat = "StatCoins", icon = "Coin", text = "Collect %s coins in flight", goals = { 10, 50, 200, 750, 2500, 8000 } },
	{ id = "rings", stat = "StatRings", icon = "Bolt", text = "Fly through %s boost rings", goals = { 3, 15, 60, 200, 600 } },
	{ id = "eggs", stat = "StatEggs", icon = "Gift", text = "Hatch %s eggs", goals = { 1, 5, 20, 60, 150, 400 } },
	{ id = "stage", stat = "UnlockedStage", icon = "Calendar", text = "Unlock Stage %s", goals = { 2, 3, 5, 8, 11, 15, 20, 25, 30 } },
	{ id = "cannon", stat = "CannonLevel", icon = "MoneyBag", text = "Upgrade Cannon Power to %s", goals = { 1, 3, 6, 12, 18, 24, 30 } },
}
-- Daily missions: 3 a day (picked per player, new set every UTC day). Progress = stat now minus
-- the stat when the set was picked. `amount(stage)` is the goal; `minStage` hides early ones.
-- Rewards scale with your stage; finishing all 3 gives a Lucky Spin.
Config.Missions = {
	{ id = "launch", stat = "StatFlights", text = "Launch %s times", icon = "Rocket", amount = function(stage)
		return 8 + math.min(stage, 10)
	end },
	{ id = "coins", stat = "StatCoins", text = "Grab %s coins", icon = "Coin", amount = function(stage)
		return 25 + stage * 3
	end },
	{ id = "rings", stat = "StatRings", text = "Fly through %s boost rings", icon = "Bolt", amount = function(stage)
		return 6 + math.floor(stage / 2)
	end },
	{ id = "distance", stat = "StatDistance", text = "Fly %sm in total", icon = "Trophy", amount = function(stage)
		return math.floor(stage * Config.STAGE_LENGTH * 4 / 100 + 0.5) * 100
	end },
	{ id = "eggs", stat = "StatEggs", text = "Hatch %s eggs", icon = "Gift", minStage = 2, amount = function(stage)
		return 3 + math.floor(stage / 3)
	end },
	{ id = "perfect", stat = "StatPerfect", text = "Get %s PERFECT launches", icon = "Crown", amount = function(stage)
		return 3 + math.floor(stage / 6)
	end },
}
Config.MISSIONS_PER_DAY = 3
function Config.missionReward(stage)
	return math.floor(Config.moneyPerStud(stage or 1) * 200)
end
function Config.missionDay()
	return math.floor(workspace:GetServerTimeNow() / 86400)
end
-- "launch:12:40:3,coins:31:120:3" -> { { id, goal, start, stage }, ... }  (stage = the stage the
-- set was picked at: the reward is paid at that stage; old 3-field entries still parse)
function Config.parseMissions(s)
	local list = {}
	for id, goal, start, stage in string.gmatch(s or "", "(%w+):(%d+):(%d+):?(%d*)") do
		table.insert(list, { id = id, goal = tonumber(goal), start = tonumber(start), stage = tonumber(stage) })
	end
	return list
end
function Config.joinMissions(list)
	local parts = {}
	for _, e in ipairs(list) do
		table.insert(parts, e.id .. ":" .. e.goal .. ":" .. e.start .. ":" .. (e.stage or 1))
	end
	return table.concat(parts, ",")
end
function Config.getMission(id)
	for _, m in ipairs(Config.Missions) do
		if m.id == id then
			return m
		end
	end
end

function Config.questReward(stage, tier)
	return math.floor(Config.moneyPerStud(stage or 1) * 60 * 1.4 ^ (tier - 1))
end
function Config.parseQuestTiers(s)
	local t = {}
	for id, n in string.gmatch(s or "", "(%w+):(%d+)") do
		t[id] = tonumber(n)
	end
	return t
end

-- Codes (typed in Settings). Each works once per player. reward = money in Stage-1 dollars,
-- multiplied by how much your unlocked stage pays.
Config.Codes = {
	ROCKET = 500,
	BLASTOFF = 1000,
	TOTHEMOON = 2500,
	CANNON = 1500,
}

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

-- Eggs + pets (Eggs v2, design/features/eggs-v2): 15 eggs in the Hatchery behind the spawn, one per
-- pair of stages, each looking like where it comes from. Each egg opens once you've unlocked its
-- stage. Pet models live in ReplicatedStorage.PetModels / EggModels (place-only, generated meshes).
-- A pet's `mult` is its money multiplier; equipped pets add up: total = 1 + sum(mult - 1).
Config.MAX_EQUIPPED = 3 -- pet slots before rebirths (Config.petSlots adds one per rebirth)
Config.MAX_PETS = 60 -- pet storage before upgrades (Config.maxPetsFor adds them)
-- Storage upgrades (PETS window, paid with money): +step pets each. The Pet Storage pass adds more.
Config.STORAGE = { step = 20, prices = { 25000, 400000, 6000000, 100000000, 2000000000 } }
-- Equip slot upgrades (paid with money): +1 slot each.
Config.SLOT_PRICES = { 50000000, 20000000000 }
-- Auto-delete: only pets below this rarity can be auto-deleted (rare ones are always kept).
Config.AUTO_DELETE_BELOW = "Legendary"
Config.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(170, 175, 190) },
	Uncommon = { order = 2, color = Color3.fromRGB(90, 210, 110) },
	Rare = { order = 3, color = Color3.fromRGB(70, 150, 255) },
	Epic = { order = 4, color = Color3.fromRGB(180, 80, 255) },
	Legendary = { order = 5, color = Color3.fromRGB(255, 190, 40) },
	Mythic = { order = 6, color = Color3.fromRGB(255, 70, 120) },
	Secret = { order = 7, color = Color3.fromRGB(40, 30, 60) },
}
-- An egg with n pets (worst -> best): their rarities, chances (%) and powers.
-- multiplier = 1 + egg.base * power. Owner rule: an egg's worst pet is at least the previous egg's
-- second-best, so the second-best power (1.4) is also the step between eggs (EGG_STEP). The best pet
-- of each egg is the chase.
Config.EGG_STEP = 1.4
Config.EGG_SETS = {
	[4] = { rarity = { "Common", "Rare", "Epic", "Legendary" }, chance = { 60, 28, 10, 2 }, power = { 1, 1.2, 1.4, 3 } },
	[5] = { rarity = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }, chance = { 50, 28, 14, 6.5, 1.5 }, power = { 1, 1.1333, 1.2667, 1.4, 4 } },
	[6] = { rarity = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }, chance = { 45, 27, 15, 9.3, 3, 0.7 }, power = { 1, 1.1, 1.2, 1.3, 1.4, 6 } },
	[7] = { rarity = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }, chance = { 42, 26, 16, 10.2, 4.5, 1.1, 0.2 }, power = { 1, 1.08, 1.16, 1.24, 1.32, 1.4, 10 } },
}
-- pet height (studs) by rarity: the rarer, the bigger
Config.PET_HEIGHT = { Common = 3, Uncommon = 3.2, Rare = 3.4, Epic = 3.8, Legendary = 4.3, Mythic = 5, Secret = 5.8 }

-- id, name, stage, price, theme colors (color = main, accent = glow), pets worst -> best.
-- `base` (money bonus) is filled in below: 0.06 for the first egg, x EGG_STEP for each next one.
Config.Eggs = {
	{ id = "Meadow", name = "Meadow Egg", stage = 1, price = 2500, color = Color3.fromRGB(140, 220, 110), accent = Color3.fromRGB(255, 240, 120),
		pets = { "Puppy", "Kitty", "Bunny", "RocketCorgi" } },
	{ id = "Ancient", name = "Ancient Sands Egg", stage = 3, price = 8000, color = Color3.fromRGB(226, 190, 120), accent = Color3.fromRGB(190, 110, 255),
		pets = { "Fennec", "ScarabBeetle", "MummyCat", "PharaohSphinx" } },
	{ id = "Jungle", name = "Jungle Egg", stage = 5, price = 25000, color = Color3.fromRGB(60, 170, 90), accent = Color3.fromRGB(255, 120, 200),
		pets = { "Monkey", "Parrot", "TigerCub", "GoldenJaguar" } },
	{ id = "IceAge", name = "Ice Age Egg", stage = 7, price = 90000, color = Color3.fromRGB(150, 215, 255), accent = Color3.fromRGB(200, 245, 255),
		pets = { "Penguin", "SnowFox", "PolarBear", "WoollyMammoth", "IceDragon" } },
	{ id = "Magma", name = "Magma Egg", stage = 9, price = 300000, color = Color3.fromRGB(50, 35, 40), accent = Color3.fromRGB(255, 130, 30),
		pets = { "LavaSlime", "FireSalamander", "MagmaGolem", "Phoenix", "InfernoDragon" } },
	{ id = "Cloud", name = "Cloud Egg", stage = 11, price = 1000000, color = Color3.fromRGB(245, 245, 255), accent = Color3.fromRGB(255, 215, 90),
		pets = { "CloudSheep", "Owl", "Pegasus", "CloudWhale", "SkyGriffin" } },
	{ id = "Thunder", name = "Thunder Egg", stage = 13, price = 3500000, color = Color3.fromRGB(90, 95, 120), accent = Color3.fromRGB(255, 235, 60),
		pets = { "StaticHedgehog", "StormBat", "LightningWolf", "ThunderBird", "ThunderHydra" } },
	{ id = "SkyIsland", name = "Sky Island Egg", stage = 15, price = 11000000, color = Color3.fromRGB(150, 210, 120), accent = Color3.fromRGB(255, 170, 110),
		pets = { "SkySquirrel", "SunsetToucan", "IslandTurtle", "WindFox", "SunLion", "SkyLeviathan" } },
	{ id = "Aurora", name = "Aurora Egg", stage = 17, price = 36000000, color = Color3.fromRGB(120, 230, 200), accent = Color3.fromRGB(190, 110, 255),
		pets = { "AuroraHare", "CrystalOwl", "SpiritDeer", "AuroraWolf", "AuroraSerpent", "CelestialKirin" } },
	{ id = "JetStream", name = "Jet Stream Egg", stage = 19, price = 120000000, color = Color3.fromRGB(235, 240, 250), accent = Color3.fromRGB(80, 170, 255),
		pets = { "JetPenguin", "TurboHamster", "RocketHawk", "MechaShark", "TurboCheetah", "MechaDragon" } },
	{ id = "Moon", name = "Moon Egg", stage = 21, price = 400000000, color = Color3.fromRGB(200, 205, 220), accent = Color3.fromRGB(220, 230, 255),
		pets = { "MoonBunny", "Alien", "RoboDog", "UFOCat", "AstronautPup", "LunarWolf" } },
	{ id = "Mars", name = "Mars Egg", stage = 23, price = 1300000000, color = Color3.fromRGB(200, 90, 50), accent = Color3.fromRGB(255, 110, 180),
		pets = { "RockCrab", "MartianBlob", "RoverPup", "AsteroidGolem", "CrystalScorpion", "MarsDragon", "MarsCerberus" } },
	{ id = "GasGiant", name = "Gas Giant Egg", stage = 25, price = 4500000000, color = Color3.fromRGB(220, 160, 100), accent = Color3.fromRGB(255, 220, 120),
		pets = { "PuffCloudfish", "RingRay", "MoonTurtle", "JupiterJelly", "SaturnWhale", "CosmicKraken", "TwinRingDragon" } },
	{ id = "Nebula", name = "Nebula Egg", stage = 27, price = 15000000000, color = Color3.fromRGB(150, 80, 230), accent = Color3.fromRGB(255, 120, 220),
		pets = { "StarPuppy", "CometFox", "NebulaJelly", "NebulaDragon", "CosmicKitsune", "CrystalMammoth", "StarbornChimera" } },
	{ id = "BlackHole", name = "Black Hole Egg", stage = 29, price = 50000000000, color = Color3.fromRGB(25, 15, 40), accent = Color3.fromRGB(190, 90, 255),
		pets = { "VoidKitten", "QuasarBunny", "GalaxyUnicorn", "SingularitySerpent", "DarkMatterPanther", "VoidDragon", "GalaxyEmperor" } },
}
do
	local base = 0.06
	for i, egg in ipairs(Config.Eggs) do
		egg.index = i
		egg.base = base
		base *= Config.EGG_STEP
	end
end

-- Event eggs: hatched with an event currency, only while their event runs; built at runtime by
-- the event's server script (HalloweenServer). Their pets are kept forever and have an Index set.
Config.EventEggs = {
	{ id = "Spooky", name = "Spooky Egg", stage = 1, price = 150, currency = "Candy", event = "Halloween", base = 0.3, color = Color3.fromRGB(130, 70, 200), accent = Color3.fromRGB(255, 150, 40),
		stand = Vector3.new(-150, 0, 40), pets = { "PumpkinPup", "GhostKitty", "BatDragon", "PumpkinKing" } },
}

-- Scaling pets: the pets of the eggs below have no fixed bonus - it grows with the best egg you've
-- unlocked (your "tier"): multiplier = 1 + (your tier's egg base) x power, so they stay good forever.
-- Their egg sets list power per pet (worst -> best).
local SET4 = { rarity = { "Common", "Rare", "Epic", "Legendary" }, chance = { 60, 28, 10, 2 } }
local function scaledSet(powers, base)
	local s = table.clone(base or SET4)
	s.power = powers
	return s
end
-- Winter 2026: snowflakes from pickups, the Frosty Gift Egg on the Spooky Egg's spot.
table.insert(Config.EventEggs, { id = "Frosty", name = "Frosty Gift Egg", stage = 1, price = 150, currency = "Snowflakes", event = "Winter", scales = true,
	setDef = scaledSet({ 0.85, 1, 1.15, 2.8 }), color = Color3.fromRGB(120, 200, 255), accent = Color3.fromRGB(255, 80, 90),
	stand = Vector3.new(-150, 0, 40), pets = { "SnowmanPup", "GingerbreadCat", "Reindeer", "FrostYeti" } })

-- Limited eggs: one at a time, a new one every week (same on every server), bought with money at
-- priceMult x the price of your best unlocked egg; scaling pets. They come back in turn.
Config.LIMITED_EPOCH = 1791158400 -- Monday 2026-10-05 00:00 UTC
Config.LIMITED_WEEK = 7 * 86400
Config.LimitedEggs = {
	{ id = "Crystal", name = "Crystal Cave Egg", stage = 1, limited = true, scales = true, priceMult = 2, setDef = scaledSet({ 1.2, 1.4, 1.6, 4 }),
		color = Color3.fromRGB(150, 110, 255), accent = Color3.fromRGB(120, 255, 240), pets = { "GemMole", "CrystalBat", "AmethystFox", "DiamondGolem" } },
	{ id = "Candy", name = "Candy Kingdom Egg", stage = 1, limited = true, scales = true, priceMult = 2, setDef = scaledSet({ 1.2, 1.4, 1.6, 4 }),
		color = Color3.fromRGB(255, 150, 200), accent = Color3.fromRGB(120, 230, 255), pets = { "GummyBear", "LollipopLamb", "CupcakeKitty", "CandyDragon" } },
	{ id = "Ocean", name = "Ocean Deep Egg", stage = 1, limited = true, scales = true, priceMult = 2, setDef = scaledSet({ 1.2, 1.4, 1.6, 4 }),
		color = Color3.fromRGB(40, 120, 200), accent = Color3.fromRGB(120, 255, 220), pets = { "BubblePuffer", "SeahorseKnight", "OctoPup", "Megalodon" } },
}
-- the special eggs' stands, on the lawn north of the spawn plaza (SpecialEggsServer)
Config.LIMITED_STAND = Vector3.new(-134, 0, 52)
Config.ROYAL_STAND = Vector3.new(-129, 0, 26) -- (right by the main path from the spawn)
for _, e in ipairs(Config.LimitedEggs) do
	e.stand = Config.LIMITED_STAND
end
-- the limited egg on sale now, and when it changes (os time)
function Config.limitedEgg(now)
	now = now or workspace:GetServerTimeNow()
	local week = math.floor((now - Config.LIMITED_EPOCH) / Config.LIMITED_WEEK)
	local egg = Config.LimitedEggs[week % #Config.LimitedEggs + 1]
	return egg, Config.LIMITED_EPOCH + (week + 1) * Config.LIMITED_WEEK
end

-- Robux egg (developer products RoyalEgg1 / RoyalEgg3): rare pets only, scaling. Where paid random
-- items aren't allowed (PolicyService), the egg can't be bought.
Config.ExclusiveEggs = {
	{ id = "Royal", name = "Royal Treasure Egg", stage = 1, robux = true, scales = true,
		setDef = scaledSet({ 2, 3, 5, 12 }, { rarity = { "Epic", "Legendary", "Mythic", "Secret" }, chance = { 60, 30, 9, 1 } }),
		color = Color3.fromRGB(255, 200, 60), accent = Color3.fromRGB(255, 90, 200), pets = { "RoyalCorgi", "CrownLion", "TreasureDragon", "DiamondPhoenix" } },
}
Config.ExclusiveEggs[1].stand = Config.ROYAL_STAND

-- Halloween 2026: candy from pickups, the Spooky Egg, lobby pumpkins. Ends by itself.
Config.Halloween = { ends = 1793577600 } -- 2026-11-02 00:00 UTC
Config.Candy = { Coin = 1, Gem = 3, Ring = 2, Golden = 50, Mission = 10 }
-- (the owner's /event command can force one event on for a server: workspace attribute ForceEvent
-- = "Halloween" | "Winter" | "None")
local function forcedEvent()
	return workspace:GetAttribute("ForceEvent")
end
function Config.halloweenActive()
	local f = forcedEvent()
	if f then
		return f == "Halloween"
	end
	return workspace:GetServerTimeNow() < Config.Halloween.ends
end
Config.Winter = { starts = 1796083200, ends = 1799107200 } -- 2026-12-01 .. 2027-01-05 UTC
Config.Snowflakes = Config.Candy -- (same amounts per pickup)
function Config.winterActive()
	local f = forcedEvent()
	if f then
		return f == "Winter"
	end
	local now = workspace:GetServerTimeNow()
	return now >= Config.Winter.starts and now < Config.Winter.ends
end
function Config.eventActive(event)
	if event == "Halloween" then
		return Config.halloweenActive()
	elseif event == "Winter" then
		return Config.winterActive()
	end
	return false
end
-- the season currency being handed out now ("Candy" / "Snowflakes"), or nil
function Config.seasonCurrency()
	if Config.halloweenActive() then
		return "Candy"
	elseif Config.winterActive() then
		return "Snowflakes"
	end
end

Config.PET_NAMES = {
	Puppy = "Puppy", Kitty = "Kitty", Bunny = "Bunny", RocketCorgi = "Rocket Corgi",
	Fennec = "Fennec Fox", ScarabBeetle = "Scarab Beetle", MummyCat = "Mummy Cat", PharaohSphinx = "Pharaoh Sphinx",
	Monkey = "Monkey", Parrot = "Parrot", TigerCub = "Tiger Cub", GoldenJaguar = "Golden Jaguar",
	Penguin = "Penguin", SnowFox = "Snow Fox", PolarBear = "Polar Bear", WoollyMammoth = "Woolly Mammoth", IceDragon = "Ice Dragon",
	LavaSlime = "Lava Slime", FireSalamander = "Fire Salamander", MagmaGolem = "Magma Golem", Phoenix = "Phoenix", InfernoDragon = "Inferno Dragon",
	CloudSheep = "Cloud Sheep", Owl = "Owl", Pegasus = "Pegasus", CloudWhale = "Cloud Whale", SkyGriffin = "Sky Griffin",
	StaticHedgehog = "Static Hedgehog", StormBat = "Storm Bat", LightningWolf = "Lightning Wolf", ThunderBird = "Thunder Bird", ThunderHydra = "Thunder Hydra",
	SkySquirrel = "Sky Squirrel", SunsetToucan = "Sunset Toucan", IslandTurtle = "Island Turtle", WindFox = "Wind Fox", SunLion = "Sun Lion", SkyLeviathan = "Sky Leviathan",
	AuroraHare = "Aurora Hare", CrystalOwl = "Crystal Owl", SpiritDeer = "Spirit Deer", AuroraWolf = "Aurora Wolf", AuroraSerpent = "Aurora Serpent", CelestialKirin = "Celestial Kirin",
	JetPenguin = "Jet Penguin", TurboHamster = "Turbo Hamster", RocketHawk = "Rocket Hawk", MechaShark = "Mecha Shark", TurboCheetah = "Turbo Cheetah", MechaDragon = "Mecha Dragon",
	MoonBunny = "Moon Bunny", Alien = "Alien", RoboDog = "Robo Dog", UFOCat = "UFO Cat", AstronautPup = "Astronaut Pup", LunarWolf = "Lunar Wolf",
	RockCrab = "Rock Crab", MartianBlob = "Martian Blob", RoverPup = "Rover Pup", AsteroidGolem = "Asteroid Golem", CrystalScorpion = "Crystal Scorpion", MarsDragon = "Mars Dragon", MarsCerberus = "Mars Cerberus",
	PuffCloudfish = "Puff Cloudfish", RingRay = "Ring Ray", MoonTurtle = "Moon Turtle", JupiterJelly = "Jupiter Jelly", SaturnWhale = "Saturn Whale", CosmicKraken = "Cosmic Kraken", TwinRingDragon = "Twin Ring Dragon",
	StarPuppy = "Star Puppy", CometFox = "Comet Fox", NebulaJelly = "Nebula Jelly", NebulaDragon = "Nebula Dragon", CosmicKitsune = "Cosmic Kitsune", CrystalMammoth = "Crystal Mammoth", StarbornChimera = "Starborn Chimera",
	VoidKitten = "Void Kitten", QuasarBunny = "Quasar Bunny", GalaxyUnicorn = "Galaxy Unicorn", SingularitySerpent = "Singularity Serpent", DarkMatterPanther = "Dark Matter Panther", VoidDragon = "Void Dragon", GalaxyEmperor = "Galaxy Emperor",
	PumpkinPup = "Pumpkin Pup", GhostKitty = "Ghost Kitty", BatDragon = "Bat Dragon", PumpkinKing = "Pumpkin King",
	SnowmanPup = "Snowman Pup", GingerbreadCat = "Gingerbread Cat", Reindeer = "Reindeer", FrostYeti = "Frost Yeti",
	GemMole = "Gem Mole", CrystalBat = "Crystal Bat", AmethystFox = "Amethyst Fox", DiamondGolem = "Diamond Golem",
	GummyBear = "Gummy Bear", LollipopLamb = "Lollipop Lamb", CupcakeKitty = "Cupcake Kitty", CandyDragon = "Candy Dragon",
	BubblePuffer = "Bubble Puffer", SeahorseKnight = "Seahorse Knight", OctoPup = "Octo Pup", Megalodon = "Megalodon",
	RoyalCorgi = "Royal Corgi", CrownLion = "Crown Lion", TreasureDragon = "Treasure Dragon", DiamondPhoenix = "Diamond Phoenix",
}

-- Pet effects (drawn by the client's PetFx module wherever the pet shows up). Each entry is a list
-- of { preset, color? }: flame, embers, frost, spark, sparkle, glow (a light), jet, dust, void, aura.
local C3 = Color3.fromRGB
Config.PET_FX = {
	RocketCorgi = { { "jet", C3(255, 150, 40) } },
	MummyCat = { { "dust", C3(230, 200, 140) }, { "glow", C3(120, 255, 120) } },
	PharaohSphinx = { { "sparkle", C3(255, 210, 80) }, { "dust", C3(230, 200, 140) }, { "glow", C3(255, 200, 90) } },
	GoldenJaguar = { { "sparkle", C3(255, 210, 80) } },
	IceDragon = { { "frost", C3(200, 240, 255) }, { "glow", C3(120, 210, 255) } },
	LavaSlime = { { "embers", C3(255, 140, 40) }, { "glow", C3(255, 120, 30) } },
	FireSalamander = { { "flame", C3(255, 120, 30) } },
	MagmaGolem = { { "embers", C3(255, 140, 40) }, { "glow", C3(255, 110, 20) } },
	Phoenix = { { "flame", C3(255, 150, 40) }, { "embers", C3(255, 200, 80) }, { "glow", C3(255, 140, 40) } },
	InfernoDragon = { { "flame", C3(255, 100, 20) }, { "embers", C3(255, 170, 50) }, { "glow", C3(255, 110, 20) } },
	SkyGriffin = { { "sparkle", C3(255, 230, 140) }, { "glow", C3(255, 220, 120) } },
	StaticHedgehog = { { "spark", C3(255, 240, 80) } },
	LightningWolf = { { "spark", C3(255, 240, 80) } },
	ThunderBird = { { "spark", C3(255, 240, 80) }, { "glow", C3(255, 240, 120) } },
	ThunderHydra = { { "spark", C3(255, 240, 80) }, { "glow", C3(150, 200, 255) }, { "aura", C3(120, 160, 255) } },
	WindFox = { { "sparkle", C3(170, 255, 230) } },
	SunLion = { { "sparkle", C3(255, 210, 80) }, { "glow", C3(255, 200, 80) } },
	SkyLeviathan = { { "sparkle", C3(170, 220, 255) }, { "glow", C3(150, 210, 255) }, { "aura", C3(255, 220, 140) } },
	AuroraHare = { { "sparkle", C3(140, 255, 190) } },
	CrystalOwl = { { "sparkle", C3(170, 240, 255) } },
	SpiritDeer = { { "sparkle", C3(200, 255, 230) }, { "glow", C3(180, 255, 220) } },
	AuroraWolf = { { "sparkle", C3(150, 255, 200) }, { "glow", C3(170, 120, 255) } },
	AuroraSerpent = { { "sparkle", C3(140, 255, 190) }, { "glow", C3(180, 120, 255) } },
	CelestialKirin = { { "sparkle", C3(150, 255, 210) }, { "glow", C3(190, 140, 255) }, { "aura", C3(140, 255, 200) } },
	JetPenguin = { { "jet", C3(255, 150, 40) } },
	TurboHamster = { { "jet", C3(255, 150, 40) } },
	RocketHawk = { { "jet", C3(90, 180, 255) } },
	MechaShark = { { "jet", C3(80, 170, 255) }, { "glow", C3(80, 170, 255) } },
	TurboCheetah = { { "jet", C3(80, 170, 255) }, { "spark", C3(140, 210, 255) } },
	MechaDragon = { { "jet", C3(80, 170, 255) }, { "glow", C3(90, 180, 255) }, { "aura", C3(90, 180, 255) } },
	UFOCat = { { "glow", C3(120, 255, 160) } },
	AstronautPup = { { "sparkle", C3(220, 230, 255) } },
	LunarWolf = { { "sparkle", C3(220, 230, 255) }, { "glow", C3(200, 215, 255) }, { "aura", C3(200, 215, 255) } },
	MartianBlob = { { "glow", C3(120, 255, 120) } },
	RoverPup = { { "dust", C3(210, 120, 80) } },
	AsteroidGolem = { { "dust", C3(160, 150, 140) }, { "glow", C3(255, 150, 60) } },
	CrystalScorpion = { { "sparkle", C3(255, 130, 200) }, { "glow", C3(255, 110, 180) } },
	MarsDragon = { { "dust", C3(210, 110, 70) }, { "glow", C3(255, 120, 160) }, { "aura", C3(255, 110, 90) } },
	MarsCerberus = { { "embers", C3(255, 120, 40) }, { "dust", C3(200, 100, 60) }, { "glow", C3(255, 90, 40) }, { "aura", C3(255, 90, 60) } },
	PuffCloudfish = { { "dust", C3(255, 190, 120) } },
	RingRay = { { "sparkle", C3(255, 220, 120) } },
	JupiterJelly = { { "glow", C3(255, 170, 90) }, { "sparkle", C3(255, 200, 140) } },
	SaturnWhale = { { "sparkle", C3(255, 225, 140) }, { "glow", C3(255, 220, 140) } },
	CosmicKraken = { { "sparkle", C3(120, 160, 255) }, { "glow", C3(90, 130, 255) }, { "aura", C3(120, 160, 255) } },
	TwinRingDragon = { { "sparkle", C3(255, 220, 120) }, { "glow", C3(255, 200, 100) }, { "aura", C3(255, 210, 110) } },
	StarPuppy = { { "sparkle", C3(255, 240, 160) } },
	CometFox = { { "sparkle", C3(170, 220, 255) } },
	NebulaJelly = { { "sparkle", C3(255, 140, 230) }, { "glow", C3(220, 110, 255) } },
	NebulaDragon = { { "sparkle", C3(220, 140, 255) }, { "glow", C3(200, 110, 255) } },
	CosmicKitsune = { { "sparkle", C3(190, 140, 255) }, { "glow", C3(160, 110, 255) } },
	CrystalMammoth = { { "frost", C3(180, 230, 255) }, { "glow", C3(120, 200, 255) }, { "aura", C3(140, 210, 255) } },
	StarbornChimera = { { "sparkle", C3(230, 150, 255) }, { "glow", C3(200, 110, 255) }, { "aura", C3(255, 140, 230) } },
	VoidKitten = { { "void", C3(170, 90, 255) } },
	QuasarBunny = { { "sparkle", C3(190, 220, 255) }, { "glow", C3(170, 210, 255) } },
	GalaxyUnicorn = { { "sparkle", C3(220, 160, 255) } },
	SingularitySerpent = { { "void", C3(170, 90, 255) }, { "glow", C3(150, 70, 255) } },
	DarkMatterPanther = { { "void", C3(190, 100, 255) }, { "glow", C3(160, 80, 255) } },
	VoidDragon = { { "flame", C3(170, 70, 255) }, { "void", C3(190, 100, 255) }, { "glow", C3(160, 70, 255) }, { "aura", C3(150, 70, 255) } },
	GalaxyEmperor = { { "sparkle", C3(255, 215, 110) }, { "void", C3(190, 110, 255) }, { "glow", C3(255, 200, 120) }, { "aura", C3(255, 210, 120) } },
	GhostKitty = { { "sparkle", C3(220, 225, 255) } },
	BatDragon = { { "void", C3(150, 80, 220) }, { "embers", C3(255, 150, 40) } },
	PumpkinKing = { { "flame", C3(255, 140, 30) }, { "embers", C3(255, 150, 40) }, { "glow", C3(255, 140, 40) }, { "aura", C3(170, 90, 255) } },
	GingerbreadCat = { { "sparkle", C3(255, 230, 200) } },
	Reindeer = { { "glow", C3(255, 90, 90) }, { "sparkle", C3(255, 240, 200) } },
	FrostYeti = { { "frost", C3(200, 240, 255) }, { "glow", C3(150, 220, 255) }, { "aura", C3(170, 230, 255) } },
	CrystalBat = { { "sparkle", C3(170, 255, 240) } },
	AmethystFox = { { "sparkle", C3(200, 140, 255) }, { "glow", C3(180, 110, 255) } },
	DiamondGolem = { { "sparkle", C3(220, 250, 255) }, { "glow", C3(150, 240, 255) }, { "aura", C3(180, 140, 255) } },
	LollipopLamb = { { "sparkle", C3(255, 190, 230) } },
	CupcakeKitty = { { "sparkle", C3(255, 220, 240) }, { "glow", C3(255, 150, 210) } },
	CandyDragon = { { "sparkle", C3(255, 170, 220) }, { "glow", C3(255, 120, 200) }, { "aura", C3(120, 230, 255) } },
	SeahorseKnight = { { "sparkle", C3(170, 240, 255) } },
	OctoPup = { { "sparkle", C3(150, 255, 230) }, { "glow", C3(120, 230, 255) } },
	Megalodon = { { "glow", C3(80, 180, 255) }, { "sparkle", C3(170, 240, 255) }, { "aura", C3(60, 160, 255) } },
	RoyalCorgi = { { "sparkle", C3(255, 225, 120) }, { "glow", C3(255, 210, 90) } },
	CrownLion = { { "sparkle", C3(255, 225, 120) }, { "glow", C3(255, 200, 80) }, { "aura", C3(255, 200, 70) } },
	TreasureDragon = { { "flame", C3(255, 190, 60) }, { "sparkle", C3(255, 225, 120) }, { "glow", C3(255, 200, 80) }, { "aura", C3(255, 200, 70) } },
	DiamondPhoenix = { { "flame", C3(170, 230, 255) }, { "sparkle", C3(230, 250, 255) }, { "glow", C3(160, 230, 255) }, { "aura", C3(255, 120, 220) } },
}

-- every egg (regular + event), for building pets and the Pet Index
function Config.allEggs()
	local list = table.clone(Config.Eggs)
	for _, group in ipairs({ Config.EventEggs, Config.LimitedEggs, Config.ExclusiveEggs }) do
		for _, e in ipairs(group) do
			table.insert(list, e)
		end
	end
	return list
end

-- Pets[kind] = { id, name, egg, rarity, rank, chance, power, mult, height, top } (built from the eggs)
-- top = the egg's best pet (announced to everyone when hatched).
Config.Pets = {}
for _, egg in ipairs(Config.allEggs()) do
	local set = egg.setDef or Config.EGG_SETS[#egg.pets]
	egg.set = set
	for rank, kind in ipairs(egg.pets) do
		local rarity = set.rarity[rank]
		Config.Pets[kind] = {
			id = kind,
			name = Config.PET_NAMES[kind] or kind,
			egg = egg.id,
			rarity = rarity,
			rank = rank,
			chance = set.chance[rank],
			power = set.power[rank],
			mult = math.floor((1 + (egg.base or Config.Eggs[1].base) * set.power[rank]) * 100 + 0.5) / 100,
			scales = egg.scales and set.power[rank] or nil, -- (scaling pet: see Config.petMult)
			height = Config.PET_HEIGHT[rarity],
			top = rank == #egg.pets,
		}
	end
end

-- Pet Index: owning every pet of an egg (ever) completes its set: +6% money each.
Config.INDEX_SET_BONUS = 0.06
function Config.indexSets(index) -- index = { [kind] = true }
	local n = 0
	for _, egg in ipairs(Config.allEggs()) do
		local all = true
		for _, kind in ipairs(egg.pets) do
			if not index[kind] then
				all = false
			end
		end
		if all then
			n += 1
		end
	end
	return n
end

function Config.getEgg(id)
	for _, e in ipairs(Config.allEggs()) do
		if e.id == id then
			return e
		end
	end
end

-- Golden pets: GOLDEN_COST copies of a pet fuse into one Golden pet whose money bonus is
-- GOLDEN_POWER times bigger. Drawn with its own texture tinted GOLDEN_TINT.
Config.GOLDEN_COST = 5
Config.GOLDEN_POWER = 2.5
Config.GOLDEN_TINT = Vector3.new(2, 1.8, 0.45)

-- Your tier: the best regular egg you've unlocked (1..15). Scaling pets grow with it.
function Config.tierOf(stage)
	local t = 1
	for i, e in ipairs(Config.Eggs) do
		if (stage or 1) >= e.stage then
			t = i
		end
	end
	return t
end
function Config.playerTier(player)
	return Config.tierOf(player and player:GetAttribute("UnlockedStage") or 1)
end

-- A pet's money multiplier (golden or not); scaling pets use `tier` (default 1).
function Config.petMult(kind, golden, tier)
	local p = Config.Pets[kind]
	if not p then
		return 1
	end
	local m = p.mult
	if p.scales then
		local egg = Config.Eggs[math.clamp(tier or 1, 1, #Config.Eggs)]
		m = math.floor((1 + egg.base * p.scales) * 100 + 0.5) / 100
	end
	if golden then
		return math.floor((1 + (m - 1) * Config.GOLDEN_POWER) * 100 + 0.5) / 100
	end
	return m
end

-- What an egg costs this player (limited eggs follow your tier).
function Config.eggPrice(egg, player)
	if egg.priceMult then
		return math.floor(Config.Eggs[Config.playerTier(player)].price * egg.priceMult)
	end
	return egg.price or 0
end

-- Saved pet list format (player attribute "Pets"): "uid:Kind;uid:Kind:G:L" (G = golden,
-- L = locked: can't be deleted, fused or traded). Equipped: "uid,uid".
function Config.parsePets(s)
	local list = {}
	for entry in string.gmatch(s or "", "[^;]+") do
		local uid, kind, flags = entry:match("^(%d+):(%w+)(.*)$")
		if uid and Config.Pets[kind] then
			table.insert(list, { uid = tonumber(uid), kind = kind, golden = string.find(flags, ":G", 1, true) ~= nil, locked = string.find(flags, ":L", 1, true) ~= nil })
		end
	end
	return list
end
function Config.serializePets(list)
	local parts = {}
	for _, p in ipairs(list) do
		table.insert(parts, p.uid .. ":" .. p.kind .. (p.golden and ":G" or "") .. (p.locked and ":L" or ""))
	end
	return table.concat(parts, ";")
end

function Config.parseEquipped(s)
	local set = {}
	for uid in string.gmatch(s or "", "%d+") do
		set[tonumber(uid)] = true
	end
	return set
end

-- Total money multiplier from a list of equipped pets ("Kind" or "Kind:G" for golden).
function Config.petMultiplier(kinds, tier)
	local m = 1
	for _, entry in ipairs(kinds) do
		local kind, flag = string.match(entry, "^(%w+):?(%a?)$")
		if kind and Config.Pets[kind] then
			m += Config.petMult(kind, flag == "G", tier) - 1
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
	-- a ring refuels enough to fly `fuelStuds` more studs (so fast rockets get less time: no endless flights)
	Ring = { perStage = 3, fuelStuds = 45, boost = 1.6, boostTime = 1.5 },
	Obstacle = { perStage = 4, fuelLoss = 1, slow = 0.45, slowTime = 0.9 },
}
Config.PICKUP_RADIUS = 9 -- generous on purpose: it should feel easy to grab coins
-- Obstacles per stage: none on Earth (the owner didn't want birds or bomb-like drones there),
-- storm clouds in the Sky, asteroids in Space.
function Config.obstaclesIn(stage)
	return Config.Stages[stage].zone == "Earth" and 0 or Config.Pickups.Obstacle.perStage
end

-- Flying skill -------------------------------------------------------------------------------
-- Power launch: during the countdown a needle swings across a bar; stop it in the green for a
-- stronger cannon blast.
Config.POWER_PERIOD = 1.1 -- seconds for the needle to swing across and back
Config.LaunchPower = {
	perfect = { zone = 0.07, blast = 1.3, time = 0.5, text = "PERFECT LAUNCH!" }, -- zone = half width
	good = { zone = 0.18, blast = 1.12, time = 0.2, text = "GOOD LAUNCH!" },
}
-- Where the needle is (0..1) `t` seconds after it starts swinging.
function Config.powerNeedle(t)
	local u = (t / Config.POWER_PERIOD) % 1
	return u < 0.5 and u * 2 or 2 - u * 2
end

-- Boost: grabbing coins / gems / rings charges the boost bar; hold SPACE (or the BOOST button)
-- to fly faster without using fuel.
Config.Boost = { speed = 1.6, drainTime = 2.5, Coin = 0.035, Gem = 0.12, Ring = 0.08 }

-- Combo: every coin, gem or ring adds to the combo; fly `gap` studs without grabbing one (or hit
-- an obstacle) and it's gone. Coins pay x the combo multiplier.
Config.Combo = { gap = 300, step = 8, perStep = 0.5, max = 3 }
function Config.comboMult(n)
	return math.min(Config.Combo.max, 1 + math.floor((n or 0) / Config.Combo.step) * Config.Combo.perStep)
end

-- Surprises that may show up somewhere ahead of you in a flight (only on your screen).
-- mystery crate: switched off (chance 0) - the owner didn't want a box floating over the track
Config.Crate = { chance = 0, studs = 400, petChance = 0.05, boostChance = 0.25, fuelStuds = 90 } -- mystery crate
Config.GoldenCoin = { chance = 1 / 40, studs = 1200 } -- super rare, the whole server hears about it

-- Lucky Spin: a prize roll. 1 free spin right away for new players, +1 per `every` seconds played
-- (stacks up to `max`), +1 with each daily reward. The server picks the prize (by weight).
-- money prizes pay like flying `studs` studs in your highest unlocked stage.
Config.Spin = {
	every = 1200,
	max = 3,
	boostTime = 300, -- seconds for the x2 boosts
	prizes = {
		{ id = "cash", kind = "money", studs = 120, weight = 30, name = "Cash", icon = "Coin", color = Color3.fromRGB(80, 200, 90) },
		{ id = "bag", kind = "money", studs = 300, weight = 18, name = "Money Bag", icon = "MoneyBag", color = Color3.fromRGB(60, 180, 120) },
		{ id = "x2money", kind = "boostMoney", weight = 14, name = "x2 Money", icon = "Coin", tag = "x2", color = Color3.fromRGB(255, 190, 40) },
		{ id = "x2luck", kind = "boostLuck", weight = 10, name = "x2 Luck", icon = "Clover", tag = "x2", color = Color3.fromRGB(60, 190, 110) },
		{ id = "boost", kind = "fullBoost", weight = 12, name = "Full Boost", icon = "FuelCan", color = Color3.fromRGB(60, 200, 255) },
		{ id = "pet", kind = "pet", weight = 8, name = "Free Pet", icon = "Gift", color = Color3.fromRGB(255, 120, 190) },
		{ id = "mega", kind = "money", studs = 1000, weight = 6, name = "Mega Cash", icon = "Trophy", color = Color3.fromRGB(170, 90, 255) },
		{ id = "jackpot", kind = "money", studs = 3000, weight = 2, name = "JACKPOT", icon = "Crown", color = Color3.fromRGB(255, 80, 80), jackpot = true },
	},
}
function Config.spinMoney(prize, stage)
	return math.floor(Config.moneyPerStud(stage or 1) * (prize.studs or 0))
end

-- Social + events ------------------------------------------------------------------------------
Config.FRIEND_BOOST = 0.1 -- +10% money for each friend in your server
Config.FRIEND_BOOST_MAX = 5
Config.GROUP_ID = 0 -- your Roblox group's id; members get GROUP_BOOST (0 = no group yet)
Config.GROUP_BOOST = 0.1

-- Race: every `every` seconds a race opens; everyone who joins launches together.
-- Prizes are paid like flying `studs` studs in your highest unlocked stage.
Config.Race = { every = 600, joinTime = 45, maxTime = 100, prizes = { 600, 400, 250 }, joinPrize = 150 }

-- Server events: one starts every `every` seconds and lasts `length` seconds.
Config.EVENT_EVERY = 900
Config.EVENT_LENGTH = 300
Config.EVENT_MONEY = 2 -- x money from flights
Config.EVENT_FUEL = 1.25 -- x fuel
Config.EVENT_LUCK = 2 -- x Epic-and-better chance
Config.Events = {
	Money = { name = "x2 MONEY", desc = "All flight money is doubled!", color = Color3.fromRGB(80, 210, 90), icon = "MoneyBag" },
	Luck = { name = "LUCKY EGGS x2", desc = "Epic + Legendary pets are 2x more likely!", color = Color3.fromRGB(60, 190, 110), icon = "Clover" },
	Fuel = { name = "FUEL FRENZY", desc = "+25% fuel on every rocket!", color = Color3.fromRGB(255, 150, 40), icon = "FuelCan" },
}
-- Lucky Hour: the same time on every server, every `every` seconds for `length` seconds - eggs
-- are `mult` x luckier (stacks with everything else). Players can plan around it.
Config.LUCKY_HOUR = { every = 3 * 3600, length = 1800, mult = 2 }
-- returns active, seconds left (if active) or seconds until the next one
function Config.luckyHour(now)
	now = now or workspace:GetServerTimeNow()
	local t = now % Config.LUCKY_HOUR.every
	if t < Config.LUCKY_HOUR.length then
		return true, Config.LUCKY_HOUR.length - t
	end
	return false, Config.LUCKY_HOUR.every - t
end

-- the event running right now (nil if none)
function Config.activeEvent()
	local key = workspace:GetAttribute("Event")
	if key and (workspace:GetAttribute("EventEnds") or 0) > workspace:GetServerTimeNow() then
		return key
	end
end

-- Free gifts: unlock after this many minutes of play in one session.
Config.GiftMinutes = { 1, 3, 5, 8, 12, 16, 20, 25, 30, 40 }
function Config.giftReward(stage, index)
	return math.floor(Config.moneyPerStud(stage) * (50 + index * 25))
end
-- Daily login reward (streak day 1..7, then repeats at day 7 value).
function Config.dailyReward(stage, day)
	return math.floor(Config.moneyPerStud(stage) * 200 * math.min(day, 7))
end

-- Gamepasses. Create each one on the Creator Dashboard (your experience -> Monetization ->
-- Passes), then paste its id here. id = 0 shows "coming soon" in the store.
-- Owning one sets the player attribute "Pass_<key>" (GamepassServer); in Studio you can test with
-- the chat command  /pass all  (or /pass VIP).
Config.Gamepasses = {
	{ key = "DoubleMoney", id = 2006181522, name = "2x Money", icon = "MoneyBag", robux = 149, color = Color3.fromRGB(80, 200, 90), desc = "Earn double money from every flight, coin and gem!" },
	{ key = "VIP", id = 2008281539, name = "VIP", icon = "Crown", robux = 199, color = Color3.fromRGB(255, 190, 40), desc = "+25% money, +1 pet slot, gold VIP tag over your head and in chat." },
	{ key = "RainbowPets", id = 2006865453, name = "Rainbow Pets", icon = "Rainbow", robux = 179, color = Color3.fromRGB(235, 90, 200), desc = "Your pets turn rainbow: their money boost is x1.5!" },
	{ key = "LuckyEggs", id = 2005683456, name = "Lucky Eggs", icon = "Clover", robux = 99, color = Color3.fromRGB(60, 190, 110), desc = "Epic and rarer pets are 3x more likely when you hatch." },
	{ key = "PetSlots", id = 2006871467, name = "+3 Pet Slots", icon = "Paw", robux = 129, color = Color3.fromRGB(110, 140, 240), desc = "Equip 3 more pets at once." },
	{ key = "MegaFuel", id = 2005743470, name = "Mega Fuel", icon = "FuelCan", robux = 49, color = Color3.fromRGB(255, 150, 40), desc = "+50% fuel on every rocket: fly much farther!" },
	{ key = "AutoHatch", id = 0, name = "Auto Hatch", icon = "Wheel", robux = 149, color = Color3.fromRGB(255, 120, 190), desc = "Eggs keep hatching by themselves until you stop (or run out of money)." },
	{ key = "Hatch8", id = 0, name = "Hatch 8", icon = "Gift", robux = 199, color = Color3.fromRGB(170, 90, 255), desc = "Hatch 8 eggs at once!" },
	{ key = "PetStorage", id = 0, name = "+100 Pet Storage", icon = "Paw", robux = 99, color = Color3.fromRGB(70, 180, 220), desc = "Keep 100 more pets." },
}
-- Developer products (bought again and again). id = 0 shows "coming soon".
Config.Products = {
	{ key = "SuperLuck", id = 0, robux = 39, name = "Super Luck", icon = "Clover", color = Color3.fromRGB(60, 190, 110), desc = "30 minutes of x3 luck on every egg." },
	{ key = "RoyalEgg1", id = 0, robux = 49, egg = "Royal", count = 1, name = "Royal Egg", icon = "Crown", color = Color3.fromRGB(255, 190, 40), desc = "Hatch 1 Royal Treasure Egg." },
	{ key = "RoyalEgg3", id = 0, robux = 129, egg = "Royal", count = 3, name = "3 Royal Eggs", icon = "Crown", color = Color3.fromRGB(255, 160, 40), desc = "Hatch 3 Royal Treasure Eggs." },
}
Config.SUPER_LUCK = 3 -- x luck from a Super Luck potion
Config.SUPER_LUCK_TIME = 1800
Config.PET_STORAGE_PASS = 100
function Config.getProduct(key)
	for _, p in ipairs(Config.Products) do
		if p.key == key then
			return p
		end
	end
end
-- The game's creator owns every pass for free (Roblox rule). Off = the owner plays like a normal
-- player (to judge the balance); use the chat command /pass all to test pass effects.
Config.OWNER_GETS_PASSES = false
Config.PASS = {
	DoubleMoney = 2, -- money x
	VIPMoney = 1.25, -- money x
	VIPSlots = 1,
	RainbowBoost = 1.5, -- pet boost x
	LuckyEggs = 3, -- Epic / Legendary chance x
	PetSlots = 3,
	MegaFuel = 1.5, -- fuel x
}
-- How much luckier this player's hatches are right now (x Epic-and-better chances):
--   Lucky Eggs pass x3; x2 from the Lucky Eggs server event or a Lucky Spin boost; x3 from a Super
--   Luck potion (the bigger of those two); Lucky Hour x2 on top. Capped at LUCK_CAP.
Config.LUCK_CAP = 12
function Config.luckFactor(player)
	local now = workspace:GetServerTimeNow()
	local f = 1
	if player and Config.hasPass(player, "LuckyEggs") then
		f *= Config.PASS.LuckyEggs
	end
	local boost = 1
	if Config.activeEvent() == "Luck" or (player and (player:GetAttribute("BoostLuckUntil") or 0) > now) then
		boost = Config.EVENT_LUCK
	end
	if player and (player:GetAttribute("SuperLuckUntil") or 0) > now then
		boost = math.max(boost, Config.SUPER_LUCK)
	end
	f *= boost
	if Config.luckyHour(now) then
		f *= Config.LUCKY_HOUR.mult
	end
	return math.min(f, Config.LUCK_CAP)
end

-- Chance (%) of each pet in `egg` (same order as egg.pets) with luck factor `luck`: Epic-and-better
-- chances x luck, the extra is taken from the commonest pets first (always adds up to 100).
function Config.eggChances(egg, luck)
	local chance = table.clone(egg.set.chance)
	luck = luck or 1
	if luck > 1 then
		local boosted, extra = 0, 0
		for rank, rarity in ipairs(egg.set.rarity) do
			if Config.Rarities[rarity].order >= Config.Rarities.Epic.order then
				extra += chance[rank] * (luck - 1)
				chance[rank] *= luck
				boosted += chance[rank]
			end
		end
		if boosted > 100 then -- (huge luck: only boosted pets left, in their own proportions)
			for rank, rarity in ipairs(egg.set.rarity) do
				local isBoosted = Config.Rarities[rarity].order >= Config.Rarities.Epic.order
				chance[rank] = isBoosted and chance[rank] * 100 / boosted or 0
			end
			return chance
		end
		for rank, rarity in ipairs(egg.set.rarity) do
			if extra <= 0 then
				break
			end
			if Config.Rarities[rarity].order < Config.Rarities.Epic.order then
				local take = math.min(chance[rank], extra)
				chance[rank] -= take
				extra -= take
			end
		end
	end
	return chance
end

function Config.hasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end
-- pet slots with rebirths and passes
function Config.petSlotsFor(player)
	local n = Config.petSlots(player:GetAttribute("Rebirths") or 0)
	if Config.hasPass(player, "VIP") then
		n += Config.PASS.VIPSlots
	end
	if Config.hasPass(player, "PetSlots") then
		n += Config.PASS.PetSlots
	end
	return n + (player:GetAttribute("SlotLevel") or 0)
end
-- how many pets you can keep
function Config.maxPetsFor(player)
	local n = Config.MAX_PETS + Config.STORAGE.step * (player:GetAttribute("StorageLevel") or 0)
	if Config.hasPass(player, "PetStorage") then
		n += Config.PET_STORAGE_PASS
	end
	return n
end

-- Robux donations. Create Developer Products on the Creator Dashboard, then paste their ids here.
-- id = 0 means "not set up yet" and the button shows as coming soon.
Config.Donations = {
	{ robux = 10, id = 3716679535 },
	{ robux = 50, id = 3716679654 },
	{ robux = 100, id = 3716679690 },
	{ robux = 500, id = 3716679750 },
	{ robux = 1000, id = 3716679787 },
}

-- Sounds (Creator Store audio). One consistent palette: most effects are from the DailySoundsFX
-- set (synthesized from scratch), jingles are licensed APM stings.
Config.Sounds = {
	Launch = "rbxassetid://12222065",
	Engine = "rbxassetid://12222095",
	Coin = "rbxassetid://130378474223829", -- bright coin pickup
	Gem = "rbxassetid://138309872562566", -- retro collect (gems, purchases)
	Beep = "rbxassetid://117751546358455",
	Boost = "rbxassetid://3406813517",
	Click = "rbxassetid://138409154614452", -- button press
	Tick = "rbxassetid://106623224876186", -- count-up ticks
	Pop = "rbxassetid://106984966606682", -- window open, little pops
	Whoosh = "rbxassetid://80984744279155", -- rings, banners
	Boom = "rbxassetid://94978851787238", -- cannon / landing impact
	PowerDown = "rbxassetid://96795857757261", -- out of fuel
	Jingle = "rbxassetid://1848281172", -- new best, unlocks, big prizes
	Fanfare = "rbxassetid://9045119921", -- extra-silly win (jackpots)
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

-- Stuck at the locked gate: flights already end there, so more distance pays nothing more.
function Config.isCapped(player)
	local unlocked = player:GetAttribute("UnlockedStage") or 1
	local best = player:GetAttribute("BestDistance") or 0
	return unlocked < Config.NUM_STAGES and best >= Config.stageEndX(unlocked) - Config.LAUNCH_X - 5
end

-- About how many studs the next level of an upgrade adds to a flight (before rings / boost).
-- def = the rocket, lv = { Fuel = n, Speed = n, Cannon = n, Money = n }
function Config.upgradeGain(key, def, lv)
	local fuelPer, speedPer = Config.Upgrades.Fuel.perLevel, Config.Upgrades.Speed.perLevel
	if key == "Fuel" then
		return def.fuel * fuelPer * def.speed * (1 + lv.Speed * speedPer)
	elseif key == "Speed" then
		return def.speed * speedPer * def.fuel * (1 + lv.Fuel * fuelPer)
	elseif key == "Cannon" then
		-- the blast adds speed * (power - 1) * time / 2.4 studs (it fades out with ^1.4)
		local p0, t0 = Config.cannonBlast(lv.Cannon)
		local p1, t1 = Config.cannonBlast(lv.Cannon + 1)
		return def.speed * (1 + lv.Speed * speedPer) * ((p1 - 1) * t1 - (p0 - 1) * t0) / 2.4
	end
	return 0
end

-- The upgrade to buy next: Money Boost while stuck at the gate, otherwise the distance upgrade
-- with the most studs per $. Returns key, studs gained (nil when nothing fits).
function Config.bestUpgrade(player)
	local lv = {}
	for key in pairs(Config.Upgrades) do
		lv[key] = player:GetAttribute(key .. "Level") or 0
	end
	if Config.isCapped(player) then
		if lv.Money < Config.Upgrades.Money.maxLevel then
			return "Money", 0
		end
		return nil, 0
	end
	local def = Config.getRocket(player:GetAttribute("Rocket"))
	local pick, gain, bestValue = nil, 0, -1
	for _, key in ipairs({ "Fuel", "Speed", "Cannon" }) do
		if lv[key] < Config.Upgrades[key].maxLevel then
			local g = Config.upgradeGain(key, def, lv)
			local value = g / Config.upgradeCost(key, lv[key])
			if value > bestValue then
				pick, gain, bestValue = key, g, value
			end
		end
	end
	return pick, gain
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
