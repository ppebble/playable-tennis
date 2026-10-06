# Architecture — v0.2.0

Goal: player-versus-player tennis and unregistered solo wall practice, no AI. The native server owns gameplay. Local source tests do not constitute a live multiplayer release gate.

## Modules

- PT_Core: pure Lua ballistic state machine, service/rally/scoring, shared aimTarget. Tennis uses world coordinates; free practice uses a cardinal local frame. Real wall extents constrain rebounds and targets; free practice has no imaginary sideline out rule.
- PT_Wall: selects an actual north/west tile edge from either face (four directions), contiguous 1–9 tiles, starting range 2–8. Transforms world/local coordinates. Loaded floor, real wall/window/door/fence flags and grid traversal reject blocked routes. Diagonal traversal checks both legs and destination edges.
- PT_Server: sender identity, membership, exact equipment, sequence/rate checks, fixed updates and targeted snapshots. create/join are tennis-only; startWall selects an unregistered wall and immediately serves. Waiting for a second participant never accepts strokes. Every serve/swing requires PlayableTennis.SportsTennisRacket primary; serve/startWall also requires Base.TennisBall secondary. No inventory ball creation or consumption.
- PT_Client: native RMB aim + world LMB event, J/K backups, court menus, transformed world overlay. A waiting 1v1 session blocks all sports input. Without a session, sports+ball permits direct wall start. A sports racket in primary hand always sets a native attack gate, even outside sessions; base racket never triggers sports inputs. This prevents normal input attacks, not arbitrary other-mod direct attacks or an already-running animation.
- PT_ConvertRacket + PT_RacketMenu: native B42 timed-action complete() replaces an owned root-inventory item using sendReplaceItemInContainer, replaceItemInContainer and sendEquip. No client-only inventory mutation. Rechecks ownership/attachment, refuses stale/duplicate completion, preserves condition, repair count, custom state/modData and hands.
- PT_Items: distinct base:normal sports item references the vanilla TennisRacket icon/model/weight. A Normal item is not a HandWeapon. Blood accessors on Normal are no-ops, so PT_WeaponBlood modData temporarily preserves weapon blood and is removed on reverse conversion. No copied assets or vanilla definition overrides.

## Physics and synchronization

Server fixed update 30Hz, internal ballistic integration 120Hz, complete snapshots 10Hz. Input aim is finite [-1,1]; clients never supply scores, hit outcomes, player positions or ball positions. Session token/revision/monotonic input sequence reject stale packets. Client interpolates continuous snapshots, snaps across strokes/bounces and freezes stale input. Long server stalls replay the point. There is no historical rewind/latency compensation yet.

Free wall practice uses a temporary frame anchored on the chosen wall, not a registered court. Initial/selected shot routes and each moving-ball step are checked against loaded floor/obstacles. Original wall extents are revalidated periodically. Full 3D ceiling/occlusion/dynamic actor collision is not implemented. Tennis remains north–south rectangle registration with a virtual net, first-to-N games, no sets/tiebreak/end change.

## Persistence and compatibility

ModData PlayableTennis_v1 owns registered tennis courts and wallBest records per username. Temporary wall sessions are not persisted or joinable. Active participants/ball/score are never restored after restart. Death, disconnect, vehicle entry, too-far departure, disabled settings or invalid wall closes sessions. Old wall registrations are retained for owner/admin removal but cannot be joined.

Standalone namespaced Lua, no Java patches or combat overrides. Primary/secondary hands are the game's representation of requested right/left hands. Server and every client require the same version. Native item replacement replication, normal-item held model and real mouse/gameplay interaction still need live confirmation. No split-screen support.

## Installed-source evidence

Installed root: C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/media. Initial appmanifest build ID: 25485521 (not proof of all historical B42 versions).

- Projection: lua/client/Foraging/ISBaseIcon.lua:167–176; screenToIsoX/Y used in server/BuildingObjects/ISMoveableCursor.lua:788–789.
- Networking: server/ClientCommands.lua:1295–1307, shared/Util/LuaNet.lua:53,113,263.
- Wall flags/edge ownership: server/BuildingObjects/ISBuildIsoEntity.lua:195; shared/Util/AdjacentFreeTileFinder.lua:4–24.
- Persistence: server/Foraging/forageServer.lua:26,29.
- Replacement: shared/TimedActions/ISLitCandleExtinguish.lua complete; shared/TimedActions/ISClothingExtraAction.lua.
- Racket: scripts/generated/items/weapon.txt:5175–5213. Ball: generated/items/normal.txt:10179–10185.
- Installed javap: IsoPlayer.updateInternal2 invokes OnPlayerUpdate before UpdateInputState and bannedAttacking checks. UIManager emits OnMouseDown only for unconsumed clicks, and ignores listener return values. InventoryItem blood methods are no-ops; HandWeapon overrides them.

## Next evidence gate

Run SP wall practice on all four faces and a two-client dedicated match, including inventory conversion, equipment replication, both-joined activation and packet delay. Then improve animation, localization, key remapping, wider court orientation and bounded lag compensation from measured playtests. No AI branch is planned.
