# Inspiration notes: what successful Roblox simulators do (2026-10-05)

Sources: Roblox charts (live), game pages, and gameplay frames from YouTube videos.

## Games looked at
| Game | Players (when checked) | Why it matters |
|---|---|---|
| Pet Simulator 99 (BIG Games) | top simulator, ~48K | the art / UI standard for simulators |
| Rocket Rush (VOXELIFIED) | 6.3K, 4.3M visits in 3 weeks | closest to our game: cannon launch, fly, coins by distance |
| +1 Stone Skipping | 32K | "how far can you go" loop, very popular right now |
| +1 Wings For Eggs / Drill for Eggs / Race for Eggs | 10-18K | the current "+1 / for Eggs" wave: short loop + eggs |
| Flying Boot Race Simulator | 35M visits, but ~2 online now | same idea as ours, shows that copying the old formula isn't enough |

## Looks
- **Colors:** very bright and saturated, "plastic toy" look. Neon-ish green grass, clear blue sky,
  white clouds, candy colors. Nothing muddy or realistic.
- **Surfaces:** smooth, clean, low-poly. Chunky faceted cliffs and rocks. Checker patterns
  (Stone Skipping) and bright outlined paths (Rocket Rush: yellow borders on grey pads).
- **Enclosed spaces:** every area is framed by cliffs, rock walls, trees or buildings, so you never
  see an empty horizon or the edge of the map. The camera stays fairly close.
- **The ground is busy:** coins, chests, eggs and pets everywhere (PS99). Things to grab are
  louder than decoration.
- **Light beams and floating labels** over important things (eggs, portals: "COMMON 50 Wins").

## UI
- Currency top-left with a big icon; a column of small square icon buttons on the left edge
  (Shop, Evolve, Hangar, Upgrades, Rewards, Quests, Worlds, Achievements).
- A big progress bar bottom-center (Stone Skipping) with +10K / +100K / +1M quick buttons.
- Quests / goals on the right, short and readable. Very little in the middle of the screen.

## Mechanics
- Rocket Rush: hold to charge, release to launch; steer toward pickups (the "skill gap");
  burn engine on hold; fuel cans, boost rings; enemies (tanks / helicopters / jets) you smash
  into; zones that drain fuel faster; Rebirth for multipliers + new zones; weekly updates.
- Fly / boot race games: charge -> launch -> upgrade -> pets -> new worlds; "worlds" with themes
  (Fire World, Water World) are the long-term goal; badges for reaching each world.
- Everyone: codes in the description, group rewards, "updates every Saturday", events.

## What we changed from this
- Terrain is now bright toy green with smooth, untextured ground and low-poly lavender cliffs
  (MaterialService overrides ToonGrass / ToonRock / ToonGround / ToonLeafyGrass with no texture
  maps: a clean plastic look). Tree palettes brighter. 60% more scenery per Earth stage.
- Camera can't zoom far out anymore (flight max x1.6, walking 45 studs): the world is framed
  like the top games instead of showing empty land.
- Mystery crates off (owner didn't want the box in the sky).

## Ideas for later (not done yet)
- Smash-able targets in flight (Rocket Rush's best part) as a reward, not a penalty.
- Light beams over eggs / the cannon, and floating labels like "UNLOCK STAGE 2".
- Bottom-center progress bar to the next stage.
- A weekly update rhythm + group rewards once there's a group.
