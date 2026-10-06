# Verification — 2026-10-07

Fresh `scripts/test.ps1` run on installed PZ Kahlua:

- Core: 210 behavioral assertions, including bounded continuous aiming and fractional service-box landings.
- Server: 97 behavioral assertions, including fractional aim validation, replacement player identity regression and SP bridge.
- Client: 42 behavioral assertions, including mouse serve/swing, focus, stale inputs, attack-gate restoration, revision/session recovery and interpolation.
- Total: **349** behavioral assertions (v0.1.1).
- All three production Lua modules compile in Kahlua; EN/KO sandbox keys match; packaging/test PowerShell parses.
- Independent read-only code review found a stale player-object slot assignment issue; fixed by checking exact participant object identity before processing commands. Regression verifies no opponent sequence/state change.

Staging and local installation each verified **8 identical files** by SHA-256. Local install: `C:/Users/ask13/Zomboid/mods/PlayableTennis`. No Workshop upload, remote repository creation, server preset edit, or existing save edit was performed.

These tests run the actual production Lua under the game's VM with mocked engine boundary objects. They verify rules and adapter decisions. Actual SP rendering, sound, UI clipping, keyboard conflicts, wall tile varieties, save/load serialization, in-game hosting and two-client dedicated networking remain **unverified**. Follow PLAYTEST.md before treating this prototype as a multiplayer release.

Installed bytecode inspection confirms `IsoPlayer.updateInternal2` invokes `OnPlayerUpdate` before input processing and checks `bannedAttacking` in normal attack paths. `UIManager` emits `OnMouseDown` only for an unconsumed world click; event return values do not cancel combat. The scoped guard uses `isBannedAttacking/setBannedAttacking`, preserves native aim, and restores the prior flag after button release or lifecycle cleanup. This is API/source evidence, not a live combat-input test; direct attack calls from other mods and already-running animations are outside the guard.
