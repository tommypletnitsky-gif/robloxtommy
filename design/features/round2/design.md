# Round 2 — golden pets, daily missions, coin patterns

Status: approved (owner: "keep going, make it even better", 2026-10-05)

## Why
- Duplicates pile up (a typical inventory is 6x Monkey) and have no use -> **Golden pets**.
- Nothing pulls a player back tomorrow except the daily reward -> **Daily missions**.
- Coins only come in straight lines; steering has little to aim for -> **Coin patterns**.

## Golden pets
- 5 copies of the same (non-golden) pet fuse into 1 Golden pet of that kind.
- Golden money bonus = 2.5x the normal bonus (Monkey x1.25 -> Golden Monkey x1.63). Per slot
  that's the strongest way to use duplicates.
- Saved as "uid:Kind:G" in Pets (old saves load unchanged). PetKinds carries "Kind:G" so every
  client draws the follower golden.
- Look: the pet's own mesh + texture re-drawn with a gold tint (details stay crisp), gold
  sparkles on followers, gold card frame + "Golden" name in the Pets window.
- UI: on a pet card a small "⭐ n/5" tag shows how many copies you have (2+); at 5+ it turns into
  a gold button. Press twice to fuse (like delete). The server picks unequipped copies first and
  keeps the golden one equipped if any copy was equipped.
- Reveal: dark backdrop, spinning rays, the golden pet springs in, "⭐ GOLDEN MONKEY!", the bonus
  before -> after, jingle + coins. Epic / Legendary goldens are announced to the server.

## Daily missions
- 3 missions per day (UTC day), picked per player from a pool (launch N times, collect coins,
  boost rings, total distance scaled to your stage, hatch eggs (stage 2+), PERFECT launches).
- Progress = a stat now minus the stat when the day's missions were rolled (saved).
- Each claim pays money scaled to your stage; finishing all 3 gives a Lucky Spin.
- UI: top of the Quests window: "DAILY MISSIONS - new in hh:mm:ss", three cards with progress
  bars and CLAIM buttons, the all-3 bonus line. The QUESTS badge lights for claimable missions;
  a toast pops when one is done (after the flight).

## Coin patterns
- Each group of 5 coins is one of: line, arc (up and over), wave (left-right), corkscrew,
  diagonal. Stage 1 only uses line / arc. Everything stays inside the lane.

## States
- Pets: 1 copy (no tag), 2-4 copies (grey "⭐ 3/5"), 5+ (gold button), golden (gold frame,
  no tag), armed (button reads "SURE?").
- Missions: in progress (grey "keep going"), done (green CLAIM), claimed (✔), all claimed
  (bonus line ✔). Day rollover refreshes the cards.
