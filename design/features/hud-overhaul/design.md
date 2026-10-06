# HUD overhaul — lobby + flight

Status: approved (owner: "make the hud look better too", 2026-10-06)

Goal: the always-on HUD matches the new window style (glossy bands, patterns, 3D icons) and
reads at a glance; nothing new covers the playfield.

## Lobby
- **Stage card (top right)**: a mini window: glossy blue band with "STAGE 1 / 30" in white,
  dotted light-blue panel, stage name, progress bar, the big button (grey "Reach 500m!",
  orange "Stage 2: $2K", green pulsing "UNLOCK $2K" when you can).
- **Money pill**: small green "+" on its right end opens the Store.
- **Side menu**: GIFTS / DAILY show their countdown on the button ("1:28", "4h 57m") while
  waiting, and their name + red "!" when ready.
- **Settings**: icon-only round buttons show the icon centered and full size (the gear).

## Flight
- **Dashboard (top center)**: one dark see-through rounded panel holding distance, stage name,
  FUEL and BOOST bars. Each bar has a round 3D icon (fuel can / lightning bolt) on its left.
  Low fuel (< 25%): the fuel bar turns red and blinks.
- **Countdown**: the progress bar hides while the black cinema bars are on (they covered it).

## Flight Report
- Same look as windows: dotted blue panel, the lines + total on a white sheet, gold ribbon.

## States
- Stage card: locked (grey), can't afford (orange), ready (green pulse), all stages open.
- Fuel: normal (orange), low (red blink), empty (bar empty).
- Phones: every piece keeps its UIKit.hudScale; nothing gets bigger than before.
