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
  daily reward + free timed gifts; trails (+ skins). (Boards later: Farthest / Most Earned /
  Most Rebirths / Top Supporters.)
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

## Gamepasses (2026-10-05)
STORE button (bottom bar) -> 6 passes, ids in Config.Gamepasses (0 = "coming soon"):
2x Money (x2 money), VIP (x1.25 money, +1 pet slot, gold tag over head + [VIP] in chat),
Rainbow Pets (pet boost x1.5 + rainbow sparkles), Lucky Eggs (Epic/Legendary x3),
+3 Pet Slots, Mega Fuel (+50% fuel). GamepassServer checks ownership on join and after purchase.
Test in Studio with chat: /pass all, /pass VIP, /pass none.
On sale since 2026-10-05 (Creator Dashboard -> Monetization -> Passes; price set per pass under Sales):
2x Money 149 (2006181522), VIP 199 (2008281539), Rainbow Pets 179 (2006865453),
Lucky Eggs 99 (2005683456), +3 Pet Slots 129 (2006871467), Mega Fuel 49 (2005743470).
The store reads live prices from Roblox, so a price change on the dashboard shows up without code changes.
The creator automatically owns their own passes, so the owner always sees "OWNED".

## Fun update (2026-10-05, "what's missing" -> "do all of it")
- Power launch: during the countdown a needle swings over a red/yellow/green bar; click / tap /
  SPACE to stop it. Green = PERFECT (blast x1.3, +0.5s), yellow = GOOD (x1.12). (Config.LaunchPower)
- Boost: coins / gems / rings fill a boost bar; hold SPACE, R2 or the BOOST button for x1.6 speed
  with no fuel cost. Server tracks the bar too. (Config.Boost) SPACE / Shift no longer steer up/down.
- Combo: every coin / gem / ring adds to it; 300 studs without one or hitting an obstacle ends it.
  Coins pay x1.5 at 5, x2 at 10 ... up to x5. Best combo saved (BestCombo). (Config.Combo)
- Earth obstacles: flying drones (owner said no birds earlier), 2 in stage 1, 3 per Earth stage.
- Surprises per flight (only you see them): mystery crate 45% (money bag / super boost / 5% free pet),
  golden coin 1 in 40 (server-wide shout). (Config.Crate, Config.GoldenCoin)
- Races (EventServer): every 10 min a 45s JOIN window, everyone launches together, live standings,
  prizes for top 3 + something for everyone, RaceWins stat, results window.
- Server events every 15 min for 5 min: x2 Money / Lucky Eggs x2 / Fuel Frenzy +25%.
- Friend boost +10% money per friend in the server (max +50%). Group boost ready (Config.GROUP_ID = 0).
- Lobby leaderboard beside the main path flipping Farthest Flights / Most Earned / Most Rebirths /
  Top Supporters (was Farthest / Richest / Top Supporters; the Farthest record never goes down).
- Donations are real developer products (10 / 50 / 100 / 500 / 1000 R$) inside the Store window;
  the SUPPORT side button is gone.
- Owner test chat: /race, /event money|luck|fuel|off, /golden.

## Longer game (2026-10-05, "it's super easy to beat the game")
Problems: a ring gave +1.5s fuel no matter how fast you fly, so fast rockets never ran out; the
boost bar filled almost constantly; upgrades were so cheap they were all maxed by stage 10.
Changes (checked with a balance sim, normal player without passes / pets / rebirths):
- Rings refuel by distance (45 studs worth: less time for faster rockets). Crate boost: 90 studs.
- Boost fills ~3x slower (coin 0.035, gem 0.12, ring 0.08). Combo: x1.5 every 8, max x3.
- Stage 2 costs $2,000, each stage x2.4 (was $500, x2.2). Upgrades start 2x pricier and grow x1.65
  (Money x1.7) per level. Rockets 3x pricier.
- Pace now: stage 2 ~3 min, stage 10 ~45 min (31 min skilled / 63 min clumsy), stage 20 ~4.5 h,
  stage 30 30h+ without pets and rebirths (pets + rebirths are what get you there).
- The owner gets every gamepass free (x2.5 money, +50% fuel): test as a normal player with /pass none.

## Pristine pass (2026-10-05, "change anything, make it amazing")
Plan + audit: design/features/pristine-pass/design.md. Research: design/INSPIRATION.md.
- Flight Report (src/client/FlightReport.lua): distance counts up, earning lines pop in (distance
  money, money boost, coins, best combo), TOTAL slams in + cartoon coins fly into the money pill,
  next-goal line, FLY AGAIN (queues an instant relaunch while landing) and UPGRADE.
- HUD: UPGRADE + ROCKETS buttons next to LAUNCH (same windows as the shops) with "!" badges that
  wiggle; "+$X" popups beside the money; money stays visible in flight; stage banner sweep.
- Lucky Spin (SpinServer / SpinClient): prize roll with ticks; prizes cash / bag / x2 Money 5m /
  x2 Luck 5m / Full Boost / Free Pet / Mega / JACKPOT. Free: welcome spin, +1 per 20 min played
  (max 3), +1 per daily claim. Granted instantly on the server; the client holds the money
  display (UIKit.moneyHold) until the roll lands. Owner test: /spins 3.
- Sound palette: DailySoundsFX set (coin, gem/purchase, tick, pop, whoosh, boom, power-down) +
  APM jingles (new best, unlocks, legendary hatch). Hatch sounds scale with rarity.
- World: barns with silos (no crate look), landmark light pillars + labels (launch pad, eggs,
  rebirth), egg boards only near you, pickup bursts + ring shockwaves.
- First session: no popups before the first flight; hints wait for a clear screen
  (UIKit.busy / UIKit.whenFree); quest-complete toasts; guide arrows only on visible buttons.
- Phones: flight HUD + left column scale/pack; progress bar follows the bottom bar; top pills wrap.
- Security (from an independent review): power launch graded on the server with the shared clock,
  boost grace costs bar, pickup reach checked per kind, receipts deduped, races robust to /race
  and leavers, solo race = join prize.
- Gotchas: Luau allows 200 locals per function (RocketClient is ~170: put new features in their
  own scripts/modules). GuiObject.AbsolutePosition is measured below Roblox's top bar; convert
  with UIKit.toGui() before using it as a Position in our IgnoreGuiInset ScreenGui.

## Round 2 (2026-10-05, "keep going, make it even better")
Briefs: design/features/round2/design.md, design/features/halloween/design.md.
- Golden pets: 5 copies -> 1 Golden (x2.5 bonus). Saved as "uid:Kind:G"; PetKinds "Kind:G".
  Gold look = the pet's own mesh + texture via SpecialMesh.VertexColor (Config.GOLDEN_TINT).
  Fusing refills freed slots best-first. Pet cards: "⭐ n/5" tag -> gold GOLD button (press twice).
- Daily missions: 3/day (UTC) per player from Config.Missions, goals scale with stage, entries
  "id:goal:start:stage" (reward paid at the roll stage), all 3 = Lucky Spin, rebirth lowers
  unclaimed goals. Top of the Quests window, with countdown + toasts. StatPerfect counts
  server-graded PERFECT launches.
- Coin patterns: line / arc / wave / corkscrew / diagonal, kept inside the lane and height band.
- Flight FX (FlightFxClient): wind streaks off every rocket, sonic-boom hoop when boost starts.
- Halloween 2026 (ends 2026-11-02 00:00 UTC by itself): coins/gems/rings/golden coin give candy
  (Config.Candy), missions +10 candy; Spooky Egg (Config.EventEggs, candy price, built at runtime
  by HalloweenServer at the Egg Garden entrance) with Pumpkin Pup / Ghost Kitty / Bat Dragon /
  Pumpkin King (x1.6 / x2.2 / x3.4 / x7, kept forever, own Pet Index set); jack-o-lanterns by the
  path lamps; event pill "🎃 🍬 n • time left" (HalloweenClient).
- Place-only assets (need Save + Publish): PetModels PumpkinPup/GhostKitty/BatDragon/PumpkinKing,
  EggModels.Spooky, ReplicatedStorage.HalloweenModels.JackOLantern, UIIcons.Bolt rotated.

## Balance v3 (2026-10-06, "finished the game in 15-20 min")
A full-economy sim (flights + pets + quests + missions + spins + gifts + daily, normal player, no
passes) showed the snowball: cheap eggs -> 3 Legendaries (x2 each) by minute 10, Cloud pets x13,
stage 20 in ~22 min. Like the pro simulators: eggs cost several flights at their stage, pets are
bonuses (not the main income), side rewards are worth about one flight, stage prices outgrow
income. Changes:
- Pets: RARITY_POWER 1 / 1.6 / 2.8 / 6; egg bonus 0.06 / 0.12 / 0.22 / 0.45 / 1.1 / 2.5;
  egg prices 2.5K / 60K / 350K / 5M / 600M / 9B. Spooky Egg 150 candy, bonus 0.18.
- Stage cost growth 2.4 -> 2.9. Upgrades grow x1.75 per level (Money x1.8, +7% per level).
- Quests 60 x 1.4^tier studs, missions 200, gifts 50 + 25i, daily 200/day, spins 120 / 300 /
  1000 / 3000, golden coin 1200, race 600 / 400 / 250 (+150 to join).
- Sim result (normal skill): stage 3 9m, stage 8 (first rebirth) ~50m, stage 10 ~78m,
  stage 15 ~4h, stage 20 ~9.5h (before rebirth multipliers).
- Config.OWNER_GETS_PASSES = false: the creator no longer gets every pass free (they did,
  x2.5 money) so the owner plays like a normal player; /pass all still tests passes.

## UI overhaul + improvement audit (2026-10-06/07)
- UI: every window has the patterned frame + ribbon title, animated open/close (rise + spring,
  ribbon drop, cards pop in one by one), dark backdrop (tap outside closes). HUD buttons are
  "tiles" (outline, rim, stripes, name tag) with 2D sticker icons from one sprite sheet
  (tools/make_icons.py -> assets/ui/icons.png, UIKit.IMAGES). Phones: landscape only, windows
  never below 0.68 scale. Owner wants money top-left with the 4 side buttons right under it.
- Improvement audit: 7 lenses (server/client bugs, security, perf, design, juice, world),
  bug claims checked by 3 skeptics each, 39 items built in 4 reviewed rounds:
  - Fixes: remotes wait for the save, server distance cap follows the real flight curve,
    movement + pickup checks (DebugCap workspace attribute logs clamps), receipt + gamepass
    safety, leaderboards never drop (pages: Farthest / Most Earned / Most Rebirths /
    Supporters), many UI/state bugs.
  - Clarity: stage card shows "$X more • ~N flights" while saving for a gate, REBIRTH READY
    badge + guide, BEST PICK upgrade advice, Day 7 daily = free pet (calendar cycles weekly),
    overhead rank tags, invite friends in the Store.
  - Feel: landing/new-best shake, locked-gate hit, stage-entry hoop, purchase float text,
    rarity-scaled hatch, summed coin label, money counts up with the report.
  - World: planets ahead of the Space stages, rainbow arch, Sky / Space zone gates, finish
    arch at stage 30, gate burst/shatter, coloured Space tracks, lobby fingerpost.
  - Long term: rival flags for other players' bests, races ranked by % of your own track,
    rebirth-only trails (Stardust 1, Comet 2, Aurora 3, Supernova 5, Black Hole 8), rebirth
    celebration.

## Eggs + Pets v2 (2026-10-07, owner: "ONLY do the eggs and pets ... really make it look good")
- 15 eggs, one per pair of stages, each looking like where it comes from: Meadow, Ancient Sands
  (bones floating on a purple magnetic chain), Jungle, Ice Age (frozen egg with mammoth tusks),
  Magma (obsidian with glowing lava cracks, embers, flickering light), Cloud (halo), Thunder
  (storm clouds + electric arcs), Sky Island, Aurora (light ribbons), Jet Stream (mini jets with
  contrails), Moon (satellite), Mars (asteroids, dust storm), Gas Giant (ring + moons), Nebula
  (comets), Black Hole (accretion disk, stars spiralling in). Cheap eggs move a little, expensive
  eggs a lot (EggLooks).
- 84 pets (+4 Halloween): 4 per egg early, then 5, 6, 7; rarities Common .. Legendary, Mythic,
  Secret; bosses have several heads (Thunder Hydra, Mars Cerberus, Twin Ring Dragon, Starborn
  Chimera, Galaxy Emperor). Effects per pet (PetFx: flames, embers, frost, sparks, glow, jets,
  void, aura), rarer = bigger.
- Economy: base 0.06 x1.4 per egg; inside an egg powers 1 .. 1.4 + a chase pet (x3/4/6/10);
  the owner's rule holds (an egg's worst pet >= the previous egg's 2nd best). Prices 2.5K .. 50B.
  Sim: stage 10 ~85 min, stage 20 ~8 h. Index set bonus 6% (15 sets).
- The Hatchery: the meadow behind the spawn, a walk through Earth / Sky / Space areas with an
  arch each; every egg on its own diorama. 3D hatch show (HatchShow): eggs drop in, shake harder,
  Epic+ glow in their rarity colour, burst into shell pieces, the pet springs out with effects.
- Assets: generate_mesh -> ServerStorage.EggGen -> tools/normalize_eggs.lua -> EggModels /
  PetModels / EggProps (place-only: Save + Publish).
- Halloween: the Spooky Egg is a carved purple jack-o'-lantern lit from inside, with bats circling,
  ghost wisps and fog, on a little graveyard (gravestones, dead tree, candles) at the Hatchery
  entrance; a new Pumpkin King (crown, scepter, cape, flames).
- Egg window: 6-7 pet eggs show two centred rows; the hatch buttons stay pinned under the cards
  (they scrolled out of sight on phones). Hatch show text shrinks on phones; the joystick hides.

## Pet tools, trading, limited eggs, Robux items, Winter (2026-10-07)
Owner picked from the "what's missing" list (all but the big hatch announcements: rare hatches are
now one plain chat line, "X has just hatched a Legendary Y", no sound / banner).
- Saving: Studio play tests use their own DataStores ("_Studio": profiles + leaderboards), so test
  money never touches real saves once Studio API access is on.
- Pets window: modes 🐾 Equip / 🔒 Lock / 🗑 Delete (pick many, Delete N, confirm). Locked pets can't
  be deleted, fused or traded. Storage +20 x5 ($25K .. $2B, from 60 to 160; pass +100) and equip
  slots +1 x2 ($50M, $20B), paid with money.
- Egg window: tap a pet (below Legendary) to auto-delete it when hatched (still counts for the
  Index); ⚡ Fast hatch (short show); 🔁 Auto (Auto Hatch pass) keeps hatching; Hatch 8 (pass;
  two rows of 4 in the show); the luck you have now. Phones: two rows for 6-7 pets, buttons pinned.
- Luck: one factor (Config.luckFactor) - Lucky Eggs pass x3, event / spin boost x2 or Super Luck
  x3, Lucky Hour x2 (every 3 h for 30 min, same on every server, pill counts down), capped at x12;
  chances always add up to 100.
- Trading (TradeServer / TradeClient): PETS -> Trade, invite, both offer up to 8 pets, Ready, 3 s
  countdown, everything checked again, then both inventories change at once and both saves are
  written. Any change un-readies both; leaving / flying cancels; requests can be turned off.
- Scaling pets: limited / Royal / Winter pets have no fixed bonus - it follows your best unlocked
  egg (tier), so they stay good forever.
- Limited egg (weekly, same everywhere): Crystal Cave, Candy Kingdom, Ocean Deep in turn; costs 2x
  your best egg. Marble showcase on the lawn north of the spawn plaza; board shows your price and
  the time left.
- Royal Treasure Egg (Robux, developer products RoyalEgg1 R$49 / RoyalEgg3 R$129): Epic+ pets only
  (Royal Corgi, Crown Lion, Treasure Dragon, Diamond Phoenix); golden stand with a red carpet by the
  main path. Hidden where paid random items aren't allowed (PolicyService). Never auto-deleted.
- New passes / products (ids 0 until created): Auto Hatch, Hatch 8, +100 Pet Storage, Super Luck.
- Winter (Dec 1 - Jan 5): snowflakes from pickups and missions, Frosty Gift Egg (Snowman Pup,
  Gingerbread Cat, Reindeer, Frost Yeti) on the event spot with pines in lights, presents, candy
  canes and a snowman, snow over the plaza, ❄ pill. Owner command /event winter|halloween|none|auto.
- Phones / low graphics: animated eggs come alive closer (46 studs instead of 70).

