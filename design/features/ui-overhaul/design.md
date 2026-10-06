# UI overhaul — every window, and a real Quest Board

Status: approved (owner: "only focus on UI ... the quest ui doesn't even seem like a quest ui,
change it to be better", 2026-10-06)

## Problems seen (screenshots of every window)
- Every window is the same white panel with a list of white cards: nothing says "quests",
  "daily", "shop". Lots of empty white.
- The header is a flat colored strip; the 3D icon is cut off at the top.
- Quests: one long scroll mixing daily missions and quests; "keep going..." grey buttons on
  almost every row look disabled/broken; no sense of progress through a quest chain.
- Daily Reward: claimed days have no check mark (bug), no "claimed" stamp.
- Windows never use more than 700x500 even on big screens.

## Global window style (UIKit.window — applies to every menu)
- Panel = the window's color, light, with a tiled polka-dot pattern (uploaded image
  `assets/ui/dots.png`) and a soft vertical gradient. Thick dark outline, drop shadow.
- Title ribbon: a chunky glossy banner that sticks out above the top edge, title centered,
  big 3D icon breaking out on its left. Round red X on the top-right corner.
- Content sits on the patterned panel; cards are white with colored outlines.
- Fits the screen: scales down on phones (as before) and up to 1.15x on big screens.
- New helpers: `UIKit.tabs` (pill tab bar, badge dots), `UIKit.rewardChip` (coin icon +
  amount), `UIKit.claimable(button, on)` (pulse + shine sweep + glow), `UIKit.stamp`
  (rotated "CLAIMED" stamp), `UIKit.windowTitle(w)`.

## Quest Board (QuestClient)
- Tabs: 📅 DAILY | 📜 QUESTS, each with a red dot when something can be claimed. Opens on the
  tab that has something to claim.
- DAILY tab: a timer chip "New missions in 7:35:05"; three tall mission cards side by side:
  icon tile on a sun-ray background, mission text, progress bar with numbers, reward chip,
  big button: CLAIM! (green, pulsing, shine) when done, "73%" grey pill while in progress,
  "CLAIMED" stamp over the card after claiming. Below: a bonus track — three checkpoint
  circles connected by a bar, ending in a Lucky Spin crown: "Finish all 3 → free LUCKY SPIN".
- QUESTS tab: cards with icon tile, title, progress bar, and a row of tier pips (●●●○○○○ =
  goal 4 of 7). Right: reward chip + button (same states). Ready quests float to the top with
  a gold outline; finished chains show "⭐ COMPLETE" at the bottom.
- Empty/loading: before missions arrive the daily tab shows "Getting today's missions...".

## Daily Reward
- Fix: claimed days show a green ✔ stamp; today's reward glows with rays when ready.
- Streak pill on top ("🔥 2 day streak! Day 7 = a BIG gift"), TODAY tag, claimed days tinted
  green and dimmed, button "CLAIM DAY 3!" pulses; otherwise grey "⏰ Next in 3:12:40".

## Free Gifts
- Header pill: "A gift is ready!" / "⏰ Next gift in 1:28" / "All gifts opened" with n/10.
- Ready gift: sun rays + gold outline + pulsing OPEN!; waiting: grey "⏰ 4:28"; opened: green
  ✔ stamp over a dimmed gift and an OPENED tag (no fake button).

## Rebirth
- NOW → NEXT hero tiles (next one gold), "Unlock Stage 8" bar (Stage 1 / 8), YOU KEEP (green)
  and STARTS OVER (red) side by side, big button (pulses when you can rebirth).

## Race Results
- Podium for the top 3: avatar headshots, names, distance + prize, crown on #1, YOU tag on your
  spot; places 4+ as rows under it.

## Everywhere else
- Toasts are dark pills with colored text, max 3 on screen (the rest queue).
- Ribbon icon never covers the title; the Egg window shows the egg you're at as its icon;
  Pet Index has an icon; the Bolt icon is a real yellow lightning bolt (tools/build_bolt_icon.lua).
- Pets empty state: puppy on rays, "No pets yet!", where to hatch.
- Lucky Spin: SPIN! pulses while you have spins.

## States everywhere
- Ready (green, pulse), in progress (grey %, no fake button text), done (stamp / ✔),
  locked (grey + 🔒 text). Phones: windows scale to fit, tabs stay 48px+ tall.
