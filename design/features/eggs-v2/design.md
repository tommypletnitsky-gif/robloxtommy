# Eggs + Pets v2 — 15 themed eggs, 84 pets, the Hatchery, a 3D hatch

Status: approved (owner, 2026-10-07: "ONLY do the eggs and pets ... around 15 eggs, each looks like
its stage ... 4-7 pets ... pets connected to THAT stage ... really make it look good")

## Rules from the owner
- ~15 eggs, one per pair of stages, each egg *looks like where it comes from* (ancient desert egg
  with bones floating on a magnetic force, ice-age egg with mammoth tusks, lava egg...).
- 4-7 pets per egg, themed to that egg's stages (lava egg -> fire creatures with flames + light).
  The best pets can have several heads.
- Cheap eggs stay simple; expensive eggs get the crazy looks and animation.
- Each egg's WORST pet is at least as good as the previous egg's SECOND-BEST pet.
- Pets earn a little less than before balance v2, but each egg must be clearly worth buying.

## Rarities (7)
Common (grey) · Uncommon (green) · Rare (blue) · Epic (purple) · Legendary (gold) · Mythic (pink-red)
· Secret (black with rainbow). Eggs 1-3 have 4 pets (C R E L), 4-7 have 5 (C U R E L), 8-11 have 6
(+ Mythic), 12-15 have 7 (+ Secret).

## Economy (sim: sim3.py; live game vs. v2)
- Pet multiplier = 1 + egg.base * power. Equipped pets add up (unchanged).
- base_1 = 0.06, base_(k+1) = base_k * 1.4  =>  next egg's Common = this egg's second-best (rule).
- Powers inside an egg: second-best is always 1.4, the ones below are spread evenly from 1.0, the
  top pet is the chase: 4-pet eggs x3, 5 -> x4, 6 -> x6, 7 -> x10.
- Chances: 4 pets 60/28/10/2 · 5 pets 50/28/14/6.5/1.5 · 6 pets 45/27/15/9.3/3/0.7 ·
  7 pets 42/26/16/10.2/4.5/1.1/0.2 (%). Lucky passes/events x2 on Epic and better.
- Price ~ 10^(3.4 + 0.26 (stage-1)), rounded: 2.5K 8K 25K 90K 300K 1M 3.5M 11M 36M 120M 400M
  1.3B 4.5B 15B 50B.
- Sim (normal player): stage 10 ~85 min, stage 20 ~8 h (live v3: 71 min / 8.3 h).
- Pet Index set bonus 10% -> 6% (15 sets now). Only an egg's TOP pet is announced to everyone.
- Old pet ids stay valid (saves keep working); 24 existing pets move into the new eggs.

## The 15 eggs (unlock stage · price · pets C/U/R/E/L/M/S)
Egg look = generated shell mesh (+ attached props) · orbiting props · particles/beams/light, all
animated on the client. Pets with ★ get extra effects (flames, frost, sparks, glow, aura).

| # | Egg (stages) | Look | Pets |
|---|---|---|---|
| 1 | Meadow (1-2) · $2.5K | pastel green egg, painted daisies, leafy vine; 2 butterflies flutter round | Puppy, Kitty, Bunny, Rocket Corgi★ |
| 2 | Ancient Sands (3-4) · $8K | sandstone + hieroglyphs + gold bands + scarab gem; 4 bones float round it, held by purple magnetic beams; sand swirl | Fennec Fox, Scarab Beetle, Mummy Cat★, Pharaoh Sphinx★ |
| 3 | Jungle (5-6) · $25K | woven leaves + vines + glowing flower; fireflies, leaves swirl | Monkey, Parrot, Tiger Cub, Golden Jaguar★ |
| 4 | Ice Age (7-8) · $90K | egg frozen in cracked blue ice, two woolly-mammoth tusks curling out; snow + frost mist, ice shards orbit | Penguin, Snow Fox, Polar Bear, Woolly Mammoth, Ice Dragon★ |
| 5 | Magma (9-10) · $300K | black obsidian with glowing lava cracks; molten rocks orbit, embers rise, flickering fire light | Lava Slime★, Fire Salamander★, Magma Golem★, Phoenix★, Inferno Dragon★ |
| 6 | Cloud (11-12) · $1M | fluffy cloud egg with little golden wings + halo; tiny clouds orbit, sparkles | Cloud Sheep, Owl, Pegasus, Cloud Whale, Sky Griffin★ |
| 7 | Thunder (13-14) · $3.5M | storm-grey egg with glowing lightning cracks; 2 storm clouds orbit, electric arcs jump to them | Static Hedgehog★, Storm Bat, Lightning Wolf★, Thunder Bird★, Thunder Hydra★ (3 heads) |
| 8 | Sky Island (15-16) · $11M | egg made of a floating island: grass + tiny trees on top, waterfall; mini rocks + birds orbit, sunset glow | Sky Squirrel, Sunset Toucan, Island Turtle, Wind Fox★, Sun Lion★, Sky Leviathan★ |
| 9 | Aurora (17-18) · $36M | crystal egg with green/purple aurora swirls; aurora ribbons wind round it, crystal shards | Aurora Hare★, Crystal Owl★, Spirit Deer★, Aurora Wolf★, Aurora Serpent★, Celestial Kirin★ |
| 10 | Jet Stream (19-20) · $120M | rocket-capsule egg with fins + glowing thruster; 2 mini jets orbit leaving contrails | Jet Penguin★, Turbo Hamster★, Rocket Hawk★, Mecha Shark★, Turbo Cheetah★, Mecha Dragon★ |
| 11 | Moon (21-22) · $400M | cratered moon-rock egg with a tiny flag; satellite orbits, star dust | Moon Bunny, Alien, Robo Dog, UFO Cat★, Astronaut Pup★, Lunar Wolf★ |
| 12 | Mars (23-24) · $1.3B | rusty red rock egg, crystal veins; asteroids orbit through a red dust storm | Rock Crab, Martian Blob★, Rover Pup★, Asteroid Golem★, Crystal Scorpion★, Mars Dragon★, Mars Cerberus★ (3 heads) |
| 13 | Gas Giant (25-26) · $4.5B | Jupiter-banded egg with a Saturn ring round it; small moons orbit in the ring | Puff Cloudfish★, Ring Ray★, Moon Turtle★, Jupiter Jelly★, Saturn Whale★, Cosmic Kraken★, Twin Ring Dragon★ (2 heads) |
| 14 | Nebula (27-28) · $15B | glowing purple egg with swirling nebula + stars inside; comet orbits with a trail | Star Puppy★, Comet Fox★, Nebula Jelly★, Nebula Dragon★, Cosmic Kitsune★, Crystal Mammoth★, Starborn Chimera★ (3 heads) |
| 15 | Black Hole (29-30) · $50B | pitch-black void egg with purple cracks; spinning accretion disk, stars spiral in | Void Kitten★, Quasar Bunny★, Galaxy Unicorn★, Singularity Serpent★, Dark Matter Panther★, Void Dragon★, Galaxy Emperor★ (3 heads) |

Spooky Egg (Halloween) stays as an event egg.

## Where: the Hatchery (behind the spawn)
The empty meadow behind the spawn (−X) becomes the Hatchery: a wide stone walk from the spawn
plaza with three themed areas, Earth (eggs 1-5), Sky (6-10, on cloud platforms), Space (11-15, a
dark star platform with neon). Each egg sits on its own diorama that matches it (sand dune with a
mini pyramid, snow mound with ice crystals, basalt with a lava pool, cloud platform, launch pad,
moon crater, red rocks, planet rings, crystal asteroid, void platform with gold rings). Locked
eggs show a lock + "Stage N". The old Egg Garden circle goes; the fingerpost points to the Hatchery.

## Animation
- Lobby: eggs bob + turn slowly; orbiting props, beams, particles and light only run near you
  (LOD by distance). Expensive eggs: more orbiters, aura ring, stronger light.
- Hatch: a real 3D show in front of the camera (particles and beams work, unlike the old 2D
  viewport): the egg drops in, shakes harder and harder, orbiters speed up, cracks glow in the
  best rarity's colour (Epic+ tease), then bursts into shell shards + flash; the pet springs out
  spinning with its effects, name, rarity and multiplier. 3-hatch = three eggs side by side.
- Pets: rarity sets size (Common 3 studs tall ... Secret 5.8). ★ pets carry effects everywhere
  (following you, hatch show).

## States
Locked egg (lock + stage), can't afford (red price), pets full, hatching (busy), event egg gone.
Phones: hatch show fits the screen; boards readable; prompts reachable.
