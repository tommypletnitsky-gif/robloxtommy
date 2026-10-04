# Rocket Simulator (Roblox)

Design + history: `ROCKET_DESIGN.md`.

## Roblox skills — use them automatically
Project skills live in `.claude/skills/` (reviewed for safety 2026-10-04; text only, no installers).
Load the matching skill before working, without waiting to be asked:

- `roblox-dev-skill` — any Luau / engine API / DataStore / networking / security / Studio MCP work.
  Check its references before using an API you're not sure exists.
- `roblox-game-ux`, `roblox-ui-implementation` — HUD, menus, shops, onboarding, mobile layout.
- `roblox-animation-audio-feedback` — juice: tweens/springs, sounds, VFX, reward feedback.
- `roblox-world-level-design` — the path, stages, lobby, scenery.
- `roblox-genre-patterns` — simulator conventions (eggs, rebirth, upgrades, pacing).
- `roblox-performance-optimization`, `roblox-mobile-playtest` — after adding parts/effects/UI.
- `roblox-creator-store-security-audit` — every toolbox/Creator Store insert (quarantine, strip scripts).

Note: the original roblox-skills pack says "never commit game code to Git" — ignore that here;
this project's code lives in `src/` and is committed to GitHub.

## How this project works
- Code is authored in `src/` and synced into Studio: run `python -m http.server 34873 --bind 127.0.0.1`
  in the repo, then `execute_luau` (Edit): `loadstring(HttpService:GetAsync("http://127.0.0.1:34873/tools/sync.lua"))()`.
  `sync.json` maps files → Studio paths. Rebuild map: `tools/rebuild_world.lua`; terrain: `tools/build_terrain.lua`.
- Third-party code is vendored in `src/vendor/` (ProfileStore, spr) after a read-through.
- Commit + push each finished step to GitHub (tommypletnitsky-gif/robloxtommy).
- Owner test chat commands: `/money N`, `/stage N`, `/reset`.
- Judge visuals in Play mode (edit-mode lighting looks wrong).
