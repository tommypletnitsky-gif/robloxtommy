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
5. Rebirth + saving (DataStore).
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
