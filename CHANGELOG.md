# Mod Menu changelog

## 1.1.0-test.2 — 2026-10-14

Test build (the `-test` in the version marks it). Needed by Goobies Multiplayer 1.0.0-test.3 and later.

- Mod Menu blocks Steam achievements by itself: `Mods\ModMenuGuard` (a hidden helper) stops achievement unlocks, stat
  changes and leaderboard score uploads from inside `Win64`, in single player too. Nothing to move or rename any more.
- If the block cannot be confirmed, the main menu says "Achievement protection not confirmed - achievements may
  unlock" (shorter, and it wraps in small windows); play stays allowed.

## 1.1.0-test.1 — 2026-10-14

Test build (the `-test` in the version marks it). Needed by Goobies Multiplayer 1.0.0-test.2 and later.

- `Report a problem.bat` ships in `Mods\mod_menu`: one double-click collects the logs into a zip (personal
  information removed) and opens the crash-report page. Mod Menu also notices a new crash of this game copy at start.
- Several game windows can share one install: settings and the mod list are written safely when windows write at the
  same time, and an unchanged file is never rewritten.
- New button registry and group tree for other mods. Mod Menu on its own no longer moves any menu button; a menu
  changes only when another mod (such as Menu Options) styles it.
- Achievement guard support (D57): Mod Menu reads the guard's status. This build does not include the native guard
  yet, so the main menu shows a notice that achievements are not blocked; play stays allowed.
- Bundled UE4SS runtime updated to the one used in the Goobies Multiplayer tests (UE4SS v3.0.1-1164-g5e627997).
- The achievement guard DLL of 1.0.1 is no longer included (it returns as part of Mod Menu in a later build).

## 1.0.1 — 2026-10-10

- Fixed slider tooltips keeping the last value when entering from above or moving along the line. They now calculate the nearest tick from the pointer position.
- Extended tick hover areas to meet halfway between neighboring ticks and reach the top of the text beside the slider.
- Aligned toggles, color palettes, and slider values to the same right inset in the settings panel.
- Adjusted slider track widths and tooltip positioning to match the aligned values.
- Updated the bundled achievement guard to the build used in the development tests.
- Added the changelog to the distribution ZIP and synchronized package, runtime, default registry, and archive versions.

## 1.0.0 — 2026-10-10

Initial mod.
