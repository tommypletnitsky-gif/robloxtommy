# Rocket Simulator — UI design

Status: approved (owner asked for "good looking UI", design decided by Claude, 2026-10-04)

## Look
- Bright glossy cartoon style (Pet Simulator–like): thick dark outlines (#1E1E32), vertical gloss
  gradients, white shine strip on the top third, FredokaOne font with dark text stroke.
- **3D icons instead of emoji**: generated meshes in `ReplicatedStorage.UIIcons`
  (Gift, Calendar, Heart, Coin, Trophy, Bolt, FuelCan, MoneyBag) shown in ViewportFrames that bob
  gently and spin once on hover / press (`UIKit.icon3D`). Rockets, pets and cannons use their own
  game models as icons.
- **Buttons** (`UIKit.button`): glossy face on a darker "lip" (5 px) that it presses down into,
  hover grows 6%, click squish + sound. Optional 3D icon above the text, or on the left (`IconSide`).
- **Windows** (`UIKit.window(title, color, size, icon)`): drop shadow, panel tinted with the
  window color, gloss header ribbon with a 3D icon breaking out of the top-left, round red close
  button. Windows spring open and shrink to fit small screens.
- Cards (`UIKit.card`), pills (`UIKit.pill`) and bars (`UIKit.bar`) for shop content.

## Colors
Rockets blue #468CFF · Upgrades purple #AA50F0 · Pets pink #FF78BE · Gifts pink #FF6EAA ·
Daily gold #FFB428 · Support teal #28BEC8 · Rebirth purple #A569F5 · Launch orange #FF821E.
Buy = green #50C85A, can't afford = red #EB5A5A, owned/equip = blue, equipped/maxed = grey.

## Surfaces
- HUD: money pill (3D coin), best pill (3D trophy), stage card; bottom bar LAUNCH (your equipped
  rocket in 3D) + PETS (3D puppy); side bar GIFTS / DAILY / SUPPORT with 3D icons and "!" badges.
- Rockets window: Rockets / Trails pill tabs; 3-column card grid (spinning rocket, #tier, speed and
  fuel bars, range, buy/equip button, EQUIPPED pill + green border).
- Upgrades window: one big card per upgrade (3D icon tile, level pill, level bar, now → next,
  price button); the cannon card shows your current cannon look.
- Gifts: grid of cards with 3D gifts and timers. Daily: 7 day cards (coins, day 7 gift), ticks on
  claimed days, today outlined in gold.

## States
Affordable / not affordable / owned / equipped / maxed on every buy button; locked eggs and
rebirth show the requirement; windows close when you walk away from the building.
Phone: windows scale down to fit; bottom/side bars keep 90+ px touch targets.
