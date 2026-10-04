# Rocket Simulator — Design

Equip a rocket, launch down a long path sitting on top of it, fly as far as you can before the
fuel runs out. Distance = money. Money buys better rockets, upgrades, eggs and new stages.

## Answers from the owner (2026-10-04)
- Flying: rocket launches forward along the path by itself; you steer (W/S = up/down,
  A/D = left/right). Fuel runs out -> rocket glides down -> distance counts.
- Farther: better rockets, upgrades (Fuel / Speed / Money), rebirth.
- Unlocking: you must fly to the end of your current stage (reach the gate) AND pay money.
- Money: based on distance flown; later stages pay more per meter.
- Pets (from eggs): money multiplier. Eggs only available for stages you've unlocked.
- Theme: Earth (stages 1-10) -> Sky (11-20, path climbs) -> Space (21-30).
- Obstacles: rings (boost) + things that slow you down.

## Ideas taken from a reference TikTok (2026-10-04)
"OPUS is insane pt.3" (@lihfolk): AI-built Roblox game. Kept our rocket idea, borrowed:
- Chunky square icon buttons along the bottom (ours: ROCKETS / LAUNCH / UPGRADES / EGGS).
- Dramatic low-poly biomes: jagged mountain ranges + snow caps along Earth stages.
- A "Roll" luck moment -> our egg opening should feel like a roll (step 4).

## Build steps (each one saved to GitHub)
1. DONE - Core loop: world (30 stages, gates), rocket tool, launch + steering + fuel, distance,
   money, stage unlocking, HUD.
2. Shop: buy rockets, upgrades (Fuel / Speed / Money). DONE
3. Obstacles + boost rings.
4. DONE - Eggs + pets (money multiplier). See "Eggs + pets" below.
5. DONE - Rebirth + saving (ProfileStore). See "Rebirth" below.
6. Polish: sounds, effects, balance.

## Code layout (synced into Studio from `sync.json`)
| File | Studio location |
|---|---|
| `src/shared/Config.lua` | ReplicatedStorage.Shared.Config — all numbers/tuning |
| `src/shared/RocketModel.lua` | ReplicatedStorage.Shared.RocketModel — builds rocket models |
| `src/server/WorldBuilder.lua` | ServerScriptService.WorldBuilder — builds the map |
| `src/server/GameServer.server.lua` | ServerScriptService.GameServer — data, flights, money |
| `src/client/RocketClient.client.lua` | StarterPlayerScripts.RocketClient — steering + HUD |

All tuning (speeds, fuel, prices, stage costs) lives in `Config.lua`.

## Makeover answers (2026-10-04, "it still doesn't look like a game")
- Art: BRIGHT CARTOON SIMULATOR (Pet Sim 99 style): saturated colors, round shapes, sparkles.
- Lobby: ROCKET LAUNCH BASE (launch tower, fuel tanks, hangar w/ shops, countdown screen).
- Launch feel: camera shake + smoke, sounds + music, slow-mo landing + coin burst + big result screen.
- In flight: MOUSE STEERING (rocket follows the cursor; finger drag on phone; keys as backup),
  coins/gems to collect, boost rings, obstacles, other players' rockets visible.
- UI: GLOSSY BUBBLY (thick outlines, gradients, bouncy buttons, cartoon font).
- Rockets: TOOLBOX MODELS (strip every script on insert).
- Extras: leaderboards = RICHEST + TOP ROBUX DONATORS (donate buttons, "support the game");
  daily reward + free timed gifts; trails (+ skins).
- Owner will PUBLISH so donations/DataStores work (until then: "coming soon" / server-only boards).
- Order: everything at once. Devices: PC + phone.

## Path looks pass (2026-10-04, "only important thing is the looks")
- Earth stages now use real smooth TERRAIN (src/server/TerrainBuilder.lua): flat runway corridor,
  rolling hills, mountain ridges with snow caps, a river beside the runway, swamp pools, desert
  dunes, canyon terraces, volcano cones + lava rivers, coastline into the ocean before the Sky zone.
  Regenerate with tools/build_terrain.lua (≈2s). Terrain surface quirk: write 2 studs lower.
- Runway: dark track, white edges, dashed yellow centre, red/white kerbs, arrows (Scenery.lua).
- Biome scenery per Earth stage (barn/windmill/crops, pyramids/cacti, palms, mushrooms, pines,
  snowmen/igloos, ice spikes, lava pools + smoking volcanoes, cabins).
- Sky: pastel cloud road lined with cloud puffs (rainbow road in Rainbow Bridge), sea of clouds,
  floating islands with waterfalls, hot-air balloons, lightning, aurora ribbons, wind streaks.
- Space: glass track with neon edges/arrows, themed planets per stage (Earth below, the Moon,
  Mars, striped Jupiter, Saturn rings, nebula, ice giant, black hole, golden Galaxy Core star).
- New arch gates with striped pillars + stage banner; round distance signs every 100m.
- Per-world lighting moods on the client (desert, canyon, swamp mist, volcano evening, tundra,
  golden sunset, thunderstorm, aurora night, edge-of-space dusk).

## Eggs + pets (2026-10-04, "now make the eggs and pets")
- Egg Garden beside the spawn: 6 eggs on pedestals (E to open), each needs its stage unlocked:
  Meadow (stage 1, $300), Jungle (5), Frost (8), Cloud (13), Moon (22), Galaxy (27).
- 4 pets per egg: Common 60% / Rare 30% / Epic 8.5% / Legendary 1.5%. 24 pets in total.
- Pet = money multiplier: 1 + egg bonus x rarity power (Meadow x1.1 .. x2, Galaxy x11 .. x101).
  Equipped pets add up (total = 1 + sum(mult - 1)); 3 equipped, 60 max. Applied in GameServer payouts.
- Hatch 1 or 3; "roll" show: egg wobbles while pet names flicker, flash, reveal (rarity, boost, NEW!).
  Legendary hatches are announced to the whole server.
- PETS button: inventory, click to equip/unequip, Equip Best, delete (click twice).
- Equipped pets follow you (hop when walking, fly beside the rocket). Drawn on each client.
- Models: generated meshes (cute chibi style) in ReplicatedStorage.PetModels / EggModels (place-only).
- Server checks everything: stage, money, inventory space, standing at the egg.

## Rebirth (2026-10-04)
- Rebirth Portal plaza beside the spawn (E to open). Needs Stage 8, then +2 stages per rebirth.
- Resets money, stages, best distance, rockets, upgrades. Keeps pets, trails, daily/gift rewards.
- Reward: money x(1 + 0.5 per rebirth) forever, +1 pet slot per rebirth (3 -> up to 6).
- Confirm by clicking twice; confetti + server-wide announcement; rebirth badge on the HUD and a
  Rebirths leaderstat.

## Flight controls v4 (2026-10-04, "the movement is the whole game concept, make it perfect")
- Mouse is locked + hidden while flying: small moves slide an aim point (~2-3 cm = edge of lane),
  no reaching for the screen edges. Roblox's mouse sensitivity setting scales it.
- Touch: drag anywhere. Keys: WASD / arrows. Gamepad: left stick. Right mouse: look around.
- The rocket follows the aim on a smooth critically-damped spring (no wobble), banks into turns,
  nose points where it's going. Liftoff always goes straight.
- Land early: pull down past the lowest height and keep pulling (a ring fills red with "LAND");
  pull up to cancel.
- Zoom: mouse wheel / I / O / pinch, eased; camera stretches a little on boosts.
- Camera: straight behind, never rolls, trails sideways/vertical moves on a soft spring and
  looks a bit toward where you steer.
- Rider: kneels on the rocket holding a handlebar (every rocket has one), leans into turns,
  tucks on boosts, fist pump through rings, flails when out of fuel. Other players see it too.
- Pets fly beside the rocket (never between it and the camera).

## Overnight update (2026-10-04, "do the stuff the game should have")
- Quests: 8 goal chains with money rewards (QUESTS button, "!" when claimable).
- Settings (gear button): music / sound toggles (saved), codes (ROCKET, BLASTOFF, TOTHEMOON,
  CANNON), controls help.
- New-player guide: arrows + sparkle path for launch -> upgrade -> unlock -> first pet.
- Best-distance flag on the path + "NEW BEST!" mid-flight.
- Pet Index: collection book of all 24 pets; each full egg set = +10% money forever.
- Stage unlock celebration; Best distance in the player list; HUD shrinks on small screens.
- Balance sim (scratch): stages 2-10 take ~2-5 min each, stage 20 ~1.4 h, stage 30 ~12 h of play
  without pets/rebirth - no walls, so prices unchanged.
