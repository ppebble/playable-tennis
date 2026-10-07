# Verification — 0.2.2 development snapshot, 2026-10-07

Version 0.2.2 is retained during user testing. No release/tag or Workshop publication is implied by this snapshot.

## Automated evidence

The current suite passes **936 assertions** in the installed game's Kahlua VM, covering physics/scoring, wall selection and geometry, server authority/lifecycle, client controls, per-frame rendering, cosmetic swing and inventory conversion. Eight production Lua modules compile. EN/KO keys, non-weapon item/native-model bindings, both animation nodes and PowerShell syntax pass their contracts.

A separate installed-engine UI regression reproduces the former fullscreen-overlay hit-test failure and verifies the zero-area overlay used now. These checks include engine mocks and inspected native behavior; they are not live gameplay or a two-client test.

Source/stage/local installation were checked separately by hashes for **20 runtime files**. Installation does not prove an already-running game has reloaded them. Public GitHub source registration is separate from a Workshop release.

## Current behavior covered

- Sports/weapon racket separation, native replacement and state preservation, including Normal-item blood storage via namespaced modData.
- RMB+LMB start/restart/serve, then free movement and cursor/LMB rally controls in both modes; waiting 1v1 input remains blocked.
- Perpendicular wall start depth1–14, four wall faces, continuous segments, alternative clear routes and retained obstacle/material checks.
- Fixed wall depth14 and flared player area; actual wall reflection bounds remain unchanged. Tennis remains rectangular.
- Natural wall-normal velocity reflection without landing-distance retargeting; contact-path display interpolation avoids stationary-looking symmetric samples.
- One-second event-free one-hand animation nodes, including explicit actions matching to avoid the native surrender fallback. Existing swings finish and unrelated queued actions are not interrupted.

## Live evidence and remaining gaps

The user reported playable solo rallies on a clear six-tile wall in an earlier snapshot. They also reported incorrect/absent motion and a brief visual pause at reflection, which motivated the latest changes. That earlier gameplay report does not validate the latest corrections.

Still pending: latest held racket appearance and one-hand motion while standing/running; rebound smoothness at multiple zooms; custom map wall acquisition; inventory replacement and remote animation replication between two clients; dedicated/hosted gameplay, latency behavior and disk save/reload. Follow PLAYTEST.md before making release claims. Source tests and package hashes do not close these gaps.

A previously investigated IsoTree.isPlayerInsideARoom null-room rendering error is outside this mod's patches; no engine, map or save fix is included.

## Fixed-target test and rectangle selector

Core480, wall91, server161, client87, render14, swing15, selector35, client-selector integration8, native dispatcher4 and inventory29 checks pass. Native building cursor/ranch area highlight inspected; selector input never consumes world area via a fullscreen panel. Core tests trace actual player shot into fixed target and return; server validates feed authorization, replay protection, exclusive test sessions and safe singleton replacement. Client tests cover menu commands, target circle and selector input guard. In-game rectangle interaction and fixed-target play remain unverified, and this fixture does not validate two-client networking.

## Remote-client startup correction

The 2026-10-07 18:32 client DebugLog records `require("BuildingObjects/ISBuildingObject") failed` at 18:55:54, followed by the selector's line5 initialization failure. Its missing `cancel` and `blocksInput` functions then caused startup and every-tick errors in PT_Client. The installed base lives under server Lua and is not available in that remote-client load.

The selector now owns its small drag callback table without requiring server Lua. It handles the native tile-selection event when the vanilla dispatcher is absent; singleplayer retains the installed dispatcher without duplicate processing. Deactivation is assigned directly because IsoCell uses raw table lookup. No vanilla globals or handlers are overridden.

The old dependency fails the new remote-client fixture before the fix. The corrected tests run the real selector together with PT_Client through startup, 120 ticks, selection, disconnect and restart. A separate test loads the installed ISBaseObject/ISBuildingObject sources and exercises the actual singleplayer dispatcher. These remain Kahlua tests with mocked world/player input, not proof of a live reconnect or visual selection. Version remains 0.2.2; no release or preset change.
## Court confirmation, outlines and swing conditions

Current suites: core480, wall91, server161, client93, render14, swing15, selector40, client-selector9, legacy native dispatcher4, inventory29. The installed Java IsoPlayer hierarchy does not expose isBuildButtonReleased even though a legacy server Lua file references it. The remote selector now confirms via UIManager's world-only OnMouseDown event; integration tests use that event with the real client handler, without inventing build-button methods. The previous native-dispatch fixture remains only a legacy/singleplayer compatibility check and never proved remote click availability.

Selection and server registration share floor/obstacle validation. Selection checks proximity, refreshes cached validation, and revalidates on confirmation. Server authority remains final. Create no longer immediately sends sync (which could replace a rejection message); the server acknowledges successful registration. Selected and idle registered courts draw outlines, including world-correct registered outlines while wall practice is active. Wall practice omits its trapezoid visualization but retains its reach geometry.

Both swing nodes now select only the owned PerformingAction. The mutable RightHandMask condition previously could reject the nodes when native ModelManager rebuilt equipped models, exposing Bob_EmoteSurrender. A native AnimNode parser/condition test now covers blank, sports and changed hand masks while excluding unrelated actions. Sports equipment is still required by the timed action. This fixes a demonstrated rejection path, not a live visual verification of the reported animation.

Live court confirmation/joining, visible outlines and animation still require a game restart and playtest. Version stays 0.2.2, no release or server preset changes.