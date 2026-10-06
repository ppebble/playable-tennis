# Verification — v0.2.0, 2026-10-07

Fresh installed-game Kahlua verification:

- Core: 218 behavioral assertions.
- Wall geometry: 66 (four faces, single wall segment, ray traversal, blocked diagonals, unloaded floor).
- Server: 150 (both-joined activation, sports-only racket, secondary-hand ball, temporary wall sessions, authority, sequences, obstacles, lifecycle, personal best).
- Client: 60 (waiting input gating, equipment exclusivity, mouse wall start, four transformed frames, native attack guard and cleanup, stale sessions/focus).
- Inventory conversion: 29 (roundtrip state, native-aware Normal blood no-op, ownership, replay, hands and replacement).
- **Total: 523 assertions.** All six production Lua modules compile; EN/KO setting/item/menu keys match; non-weapon type and native appearance contracts pass; PowerShell parses.

Independent review found Normal items cannot store HandWeapon blood via its getters/setters. Fixed with a namespaced temporary field and native-aware mock regression. Integration review found no further concrete blocker.

Package and local installation are verified separately by file hashes. No Workshop upload, remote repository creation, existing preset edit or save edit. Runtime package has 16 files including common marker, native item definition, translations and six Lua modules.

Unverified: actual item definition load/held appearance, native timed-action transport and equipment replication across two clients, actual UI aim/coordinates, combat suppression in live gameplay, hosted/dedicated networking, disk save reload, custom wall tile variants. Source/mocks and inspected installed bytecode are not live-game evidence. Follow PLAYTEST.md before release claims.
