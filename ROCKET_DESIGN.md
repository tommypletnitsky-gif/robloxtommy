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
4. Eggs + pets (money multiplier), egg per stage.
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
