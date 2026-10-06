# UI motion + HUD polish

Status: approved (owner: "change the looks of these UIs ... when u open each ui it has animation,
looks clean", 2026-10-06, with a screenshot of the lobby HUD)

Research (DevForum, Roblox docs, NN/g; Reddit/YouTube were not reachable): popups ~0.3 s in,
~0.2 s out, ease-out in / ease-in out; springs with a small overshoot; UIScale (not Size) for
pops; stagger list items; shine sweeps every ~2.5 s; avoid CanvasGroups (blank on low memory,
ViewportFrame issues) and tweens < 0.1 s (choppy on phones).

## Windows (UIKit.toggle)
- Open: rises 46 px while springing from 0.7x to full (spr 0.58 / 3.6); the title ribbon drops
  in (0.35x -> 1); the X pops in; the ribbon icon spins; then the cards pop in one by one
  (35 ms apart, 0.6x -> 1, spr 0.72 / 4.5). Switching tabs pops that tab's cards too.
- Close: shrinks to 0.8x in 0.16 s (Quad In), the backdrop fades in 0.15 s.
- Items inside a UIListLayout / UIGridLayout sit in a same-size holder while they pop, so
  their neighbours don't slide around (a UIScale changes the layout otherwise).

## HUD
- Back in the lobby (join, landing): side + bottom buttons pop in one by one; the money / best
  pills slide in from the left, the stage card from the right.
- LAUNCH has a shine sweeping across every 2.8 s; red "!" badges beat.
- 3D icons are lit from the front with a white ambient: vivid instead of muddy.
- ROCKETS shows a whole rocket flying diagonally (the upright one lost its nose).
- Guide bubble: cream with a gold outline.

## Roblox chat (desktop)
- The chat box covered the money pill and caught clicks on QUESTS. On computers the left
  column (money, best, side buttons) now starts under the chat box (chat made 85% wide, 80%
  tall). Phones keep it at the top (chat is folded away there).

## States
- A window reopened while closing springs back open; tapping the backdrop closes it.
- Phones: same motion; every piece keeps its UIKit.hudScale / window fit.
