# Verification — 2026-10-07

Fresh `scripts/test.ps1` run on installed PZ Kahlua:

- Core: 96 behavioral assertions.
- Server: 88 behavioral assertions, including replacement player identity regression and SP bridge.
- Client: 20 behavioral assertions, including revision/session recovery, text focus, interpolation and accepted-shot feedback.
- Total: **204** behavioral assertions.
- All three production Lua modules compile in Kahlua; EN/KO sandbox keys match; packaging/test PowerShell parses.
- Independent read-only code review found a stale player-object slot assignment issue; fixed by checking exact participant object identity before processing commands. Regression verifies no opponent sequence/state change.

Staging and local installation each verified **8 identical files** by SHA-256. Local install: `C:/Users/ask13/Zomboid/mods/PlayableTennis`. No Workshop upload, remote repository creation, server preset edit, or existing save edit was performed.

These tests run the actual production Lua under the game's VM with mocked engine boundary objects. They verify rules and adapter decisions. Actual SP rendering, sound, UI clipping, keyboard conflicts, wall tile varieties, save/load serialization, in-game hosting and two-client dedicated networking remain **unverified**. Follow PLAYTEST.md before treating this prototype as a multiplayer release.
