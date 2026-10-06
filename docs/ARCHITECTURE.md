# Architecture and implementation boundary

## Objective and acceptance

Two human players can register/join a court, serve, move and return a timed ball, and finish a first-to-N-games match. One player can register a real wall and count repeated rebounds. No AI. Independent sibling repository, namespaced modules, versioned B42 layout, read-only upstream installation and Workshop assets. Existing presets/saves remain user-managed.

The source acceptance gate is deterministic rules, adversarial server commands, client packet/input behavior, syntax and install hashes. The **playable release gate still requires actual SP and two-client dedicated-server playtests**, especially UI coordinates, network event delivery and timing feel.

## Components

| Module | Responsibility |
|---|---|
| shared/PT_Core.lua | No game APIs; authoritative state transitions, ballistic integration, hits, score, snapshots |
| server/PT_Server.lua | Trusted sender/position/equipment validation, court geometry, membership, ticks, targeted snapshots, persistence |
| client/PT_Client.lua | Court context menu, RMB aim/LMB stroke, J/K backups, projected overlay/HUD, interpolation, stale-state recovery |
| sandbox-options + Translate | Namespaced configuration, EN/KO setting labels |
| tests + scripts | Installed Kahlua execution, mocks of engine boundary, repeatable packaging and local install |

Flow: UI sends an intent → server validates session, sequence, sender, position and equipment → Core updates rules → server sends a complete snapshot → client draws it. The client cannot submit ball positions, player slots, scores, timestamps or claimed hits. Identity comes from the game event's player object. All arithmetic is ordinary Lua supported by the installed Kahlua VM.

## Court and wall detection

v0.1 manually registers two corners in world coordinates, north/south orientation only. The server normalizes coordinates, enforces integer/range/size/floor/proximity limits and rejects overlaps. Loaded squares need floor, no solid objects/water, and no internal north/west collision boundaries. Wall courts require a continuous `WallN` north boundary and exclude door, window and hoppable flags. Validation runs on registration, joining, serving, and periodically during a session. This catches destroyed walls/unloaded squares and closes invalid sessions. It is conservative tile validation, not a full mesh collider.

Court sprite identifiers have not been verified in the installed text sources. Automatic art-based detection is postponed until actual map tiles and their rotation/origin patterns can be catalogued. Physical net tiles are not needed: the overlay draws a net line and Core tests a 0.91-height plane. Existing physical nets/fences may make a site fail the clearance test.

## Ball, hits and rules

The virtual ball has world x/y, height z above court floor and vx/vy/vz. Gravity is 9.8 and integration uses 1/120-second substeps. Landing uses interpolated contact location; net and wall crossings use swept plane checks. Game timescale does not accelerate a multiplayer rally. Shot targets are assisted opposite-side landing positions with bounded continuous lateral mouse aiming (keyboard backups retain three choices). A loft adjustment prevents short fast assisted shots always hitting the net. Wall reflection reverses longitudinal velocity; ground reflection damps vertical velocity. This is an arcade prototype, not drag/spin/material simulation.

Swing requests require player and ball on the correct side, horizontal reach, height, turn ownership, cooldown and valid serve receive timing. A miss consumes cooldown. The server uses its received player position; there is no untrusted client rewind. The 100ms visual interpolation plus network latency makes low-speed play the starting test case. Future lag compensation must keep a bounded server history and constrain accepted rewind by measured connection latency, without accepting claimed client positions.

Tennis state is `ready -> rally -> ready/finished`; point counters support deuce, two-point game margin, alternate serve halves, faults, diagonal service boxes and first-bounce receiving. Games alternate server. Match is first to configured game count; no sets/tiebreaks/change of ends. Practice returns to ready after a miss and retains the best streak. No inventory ball removal or reward means no duplication/rollback inventory transaction is required.

## Authority, persistence and recovery

Server dispatcher accepts create/join/remove/sync/leave/serve/swing. Every stroke has a fresh session token and increasing sequence. Duplicate/out-of-order strokes are ignored. Shape/range checks reject malformed coordinates and nonfinite inputs. Rate is capped per user, registrations per owner/world and active sessions are bounded. Only participants receive snapshots. An owner/admin may remove only a nearby idle court. Registration can be restricted to administrators via sandbox.

Server scheduling runs at 30Hz with 10Hz snapshots and 120Hz internal physics. Bounded catch-up prevents work explosions. A >500ms tick stall replays the current point as a let without changing score. Full snapshots include revision, acknowledged input sequence, shot ID and complete Core state. Client ignores stale revisions and retired sessions, snaps at shot/bounce discontinuities, freezes input on stale state and requests a bounded resync. This favors consistency over hiding lag.

`ModData.getOrCreate("PlayableTennis_v1")` owns registrations, owners, monotonic court ID and best practice records. Records checkpoint to ModData during audit and on closing; actual disk persistence follows the game's save cycle. Sessions/players/ball/score are memory-only. Disconnect, death, vehicle entry, excessive distance, invalid geometry or disabling the mod closes the session. Restart starts a fresh match; it cannot resume a phantom ball or stale participant.

## Assets, UI, compatibility

Use vanilla `Base.TennisRacket` and `Base.TennisBall`; no third-party assets are copied. Racket model remains visible through normal equipment. Own overlay draws ball/shadow/lines and feedback. Native `TennisRacketHit` is local UI audio, not a world noise event. General combat `DoAttack` is deliberately not used as animation. Next asset step is an owned noncombat animation state with timing events; that requires verifying client/remote animation replication before coupling hit windows to it.

All modules use PT_/PlayableTennis namespaces and add event listeners without overriding vanilla functions. No Java patch, other mod requirement, world item spawning, game speed change, damage, or custom XP. Exact vanilla FullTypes intentionally exclude untested replacement rackets. Mouse input is enabled only after explicit court joining, while holding an intact racket near the court on the same floor and before match completion. Waiting and serve-ready phases are included. Holding RMB applies a scoped native attack gate before input processing; prior state is restored after both buttons release, or immediately on death/disconnect/menu exit. Normal racket weapon use outside this mode is preserved. Already-running attacks and direct combat calls by other mods are outside this input guard. Keyboard backups remain fixed; context actions remain available. One local keyboard player per process only. B42.20 is the declared minimum; tested API evidence is from the currently installed build, not every historical B42 build.

## Installed evidence (2026-10-07)

Root: `C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/media`. Steam app manifest reports build ID `25485521`; this does not independently identify all semantic B42 versions.

| API/asset | Installed source evidence |
|---|---|
| Project world overlay | lua/client/Foraging/ISBaseIcon.lua:167–176 (`isoToScreenX/Y`) |
| Nonblocking UI / line drawing | lua/client/ISUI/ISUIElement.lua:1837–1840,1229–1242 |
| Keyboard listener | lua/client/Farming/CFarming_Interact.lua:314–315 |
| Trusted command sender | lua/server/ClientCommands.lua:1295–1307 |
| Client send | lua/client/XpSystem/ISUI/ISHealthPanel.lua:194 |
| Targeted server send / receive | lua/shared/Util/LuaNet.lua:53,113,263 |
| Millisecond clock | lua/client/Hotbar/ISHotbar.lua:734,808 |
| Global mod persistence | lua/server/Foraging/forageServer.lua:26,29 |
| Wall flags / ownership of edges | lua/server/BuildingObjects/ISBuildIsoEntity.lua:195; lua/shared/Util/AdjacentFreeTileFinder.lua:4–24 |
| Racket and sound names | scripts/generated/items/weapon.txt:5175–5213 |
| Tennis ball | scripts/generated/items/normal.txt:10179–10185 |
| Local UI sound API | lua/client/ISUI/ISButton.lua:46,77 |
| Text input suppression | installed jar `javap zombie.core.Core`: `public boolean isDoingTextEntry()` |

These are source/API observations. Mocks test adapter decisions but cannot prove engine rendering, actual packet delivery or save serialization.

## Expansion order

1. Complete SP and two-client dedicated-server checks in PLAYTEST.md; tune ball speed/reach from measured hit timing, not guesses.
2. Add remappable keys, Korean gameplay text, configurable HUD and verified noncombat racket animation. Keep server contact authoritative.
3. Add east/west coordinate transform and verified court-tile detection; normalize all courts into local u/v coordinates so rules stay unchanged.
4. Add bounded latency compensation and spatial sounds; test packet delay/loss, low server frame rate and disconnect/reconnect before broad compatibility claims.
5. Add optional power/spin, service lets, sets/tiebreaks, change of ends, spectator snapshots and durable completed-match history. Each feature gets rules and authority tests. No AI branch is planned.
