# Verification — 0.2.2

This file records verification boundaries for the release package. Automated test files and this document stay in the repository; packaging copies only Contents/mods/PlayableTennis. Preparing or installing that package does not publish it to Steam.

## Automated checks

Run scripts/test.ps1 against the installed game before packaging. It executes production Lua in the game’s Kahlua VM with fixtures for physics, point/deuce scoring, wall selection, server authority and persistence, client controls and HUD, rendering, cosmetic swings, rectangle selection and inventory conversion. It also checks native court property APIs, XP thresholds and entry points, animation-node selection, UI hit testing, Lua syntax, translation parity and item/PowerShell contracts. Use the current command output for assertion totals; historical totals are not release evidence.

Release regressions must cover rejection of removed solo/forced-feed commands, migration of legacy test checkpoints without deleting registered courts or ordinary point checkpoints, the named winner HUD, and removal of animation diagnostics while retaining the one-handed equipped-racket swing. No automated fixture establishes live multiplayer behavior.

## Package and installation checks

Run scripts/package.ps1, then scripts/package.ps1 -Install. Verify source, staged and installed runtime file hashes separately. The installer backs up its owned previous installation; it does not change server presets or saved games. Server and every client need identical files, and an already-running game must reload the mod before an installation is meaningful.

## Live evidence and remaining gaps

The user has reported playable wall and tennis sessions and supplied screenshots of the in-game interface. Those reports are evidence for the versions played, not proof of every subsequent release change. Use docs/PLAYTEST.md for fresh singleplayer, hosted and two-client dedicated validation.

Still verify the final winner display and top-centered HUD at multiple resolutions, held racket and one-handed motion while moving, remote animation/item replication, ball presentation with latency, and persisted scores after reconnect/restart. Source tests and package hashes do not close these live evidence gaps.
