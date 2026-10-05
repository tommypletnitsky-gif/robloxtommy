# Pristine pass — make every moment feel rewarding

Status: approved (owner: "change stuff of your choice ... the game must be really amazing", 2026-10-05)

## Goal
A brand-new player feels constant reward in the first 15 minutes: every action gets sound +
motion + visual feedback, there's always a clear next goal one tap away, and the world looks
like a top-chart simulator (see design/INSPIRATION.md).

## Audit findings (first session played as a fresh player, no passes)
1. Upgrading needs a walk to a building + E after every flight (biggest friction).
2. Landing card is plain: one total, emoji money bags flying over it, no breakdown, no next step.
3. The guide bubble "Press LAUNCH" now points at the new progress bar.
4. Egg name boards overlap into a pile from across the lobby.
5. Stage-2 barns read as "red boxes with an X" from the flight camera.
6. Coin / ring pickups: sound only, almost no visual burst.
7. Crossing into a new stage = a small toast; should be a moment.
8. Money only ticks; no "+$X" next to the counter.
9. Sound palette is thin (one coin sound for everything, click for every button).

## Plan (in order of player impact)
### A. Loop friction + feedback
- HUD buttons **UPGRADE** and **ROCKETS** next to LAUNCH (open the same windows as the shops)
  with a red "!" when you can afford something. Shops in the world keep working.
- **Flight Report** (landing): lines count up one by one (Distance, Coins, Bonus multiplier),
  then the TOTAL slams in; NEW BEST stamp; a "next goal" line; buttons **FLY AGAIN** (queues an
  instant relaunch when you're back) and **UPGRADE**.
- Cartoon UI coins (not emoji) fly from the middle of the screen into the money counter;
  "+$X" pops beside the counter whenever money goes up.
- Stage banner sweeping across the screen when you fly into a new stage.
- Pickup bursts: coin sparkle pop, ring shockwave, gem burst (pooled, cheap).
### B. Audio language
- Distinct sounds: coin, gem, ring whoosh, purchase, window open, unlock fanfare, landing,
  new best, count-up ticks. Creator Store audio only (no scripts in audio).
### C. World
- Barns get real roofs + silos. Egg boards fade out with distance. Light beams over the cannon,
  eggs and rebirth portal; big floating labels over the shops / eggs / cannon.
### D. New dopamine system: Lucky Spin
- A prize wheel: 1 free spin per 20 minutes played (stacks up to 3) + 1 on each daily claim.
  Prizes: money (scaled to your stage), x2 Money for 5 min, x2 Luck for 5 min, Full Boost on
  your next flight, a free egg from your best egg, jackpot. Server picks the prize; the
  client wheel spins to it with ticks and a big reveal. Active boosts show as pills at the top.
### E. Quality
- Mobile check at phone size (HUD fit, touch targets, overlaps).
- Independent code review of everything changed this session; fix what it finds.
- Frame-rate check after each part.

## Layout notes (all sizes go through UIKit.hudScale on phones)
- Bottom bar: LAUNCH (wide) · UPGRADE · ROCKETS · PETS · STORE; progress bar above it.
- Flight Report: centered card 460x380, buttons at the bottom; tap outside = close.
- Spin: side-bar button SPIN with a counter badge; window 560x560 with the wheel.
- States: every button has affordable / not affordable / owned / maxed / cooldown text.
