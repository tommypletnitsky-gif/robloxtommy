# Halloween event 2026

Status: approved (owner: "keep going, make it even better" — seasonal events are what the top
games run in October; see design/INSPIRATION.md)

## Dates
- Runs from now until **Nov 2, 2026 00:00 UTC**, then switches itself off (no update needed).
  `Config.Halloween.ends`; `Config.halloweenActive()` everywhere.

## Candy
- Every coin you grab in flight during the event also gives **+1 🍬 Candy**; a gem gives +3,
  a boost ring +2, the golden coin +50. Candy is saved (attribute `Candy`) and shown in a candy
  pill under the money while the event runs.
- Each daily mission claimed during the event also gives +10 candy.

## Spooky Egg (event egg, paid with candy)
- 75 🍬 per hatch (x3 = 225). Open to everyone (stage 1).
- Pets: Pumpkin Pup (Common), Ghost Kitty (Rare), Bat Dragon (Epic), Pumpkin King (Legendary).
  Egg bonus 0.6: x1.6 / x2.2 / x3.4 / x7 — strong for new players, a reason to come back.
- Pets are kept forever (and count in the Pet Index as a 7th set). The egg leaves with the event.
- Hatching uses the normal hatch show; Legendary is announced to the server.

## Lobby
- A "Spooky Patch" next to the Egg Garden (built at runtime only while the event runs): the
  Spooky Egg on a pedestal with a purple glow, jack-o-lanterns, a candy-corn sign with the event
  timer, and a light pillar labelled "🎃 HALLOWEEN".
- Pumpkins line the main path. No lights (keep the lobby cheap), just models.

## UI
- Event pill at the top: "🎃 HALLOWEEN 26d 4h" (click: toast explaining candy + egg).
- Candy pill under money: "🍬 123" with a +1 pop when you get candy.
- Egg window shows candy prices ("🍬 75") and the candy you have.

## States
- Event over: no candy pill, no egg stand, candy kept in the save (shown again next event).
- Not enough candy: red hatch buttons, "Grab coins in flight to collect candy!".
