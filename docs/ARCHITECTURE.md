# Architecture — 0.2.2

Player-versus-player tennis and independent wall practice, without AI. The native server owns gameplay. Tests against source and engine mocks do not establish live multiplayer compatibility.

## Modules

- **PT_Core:** pure Lua ballistic state, serve/rally/scoring and aim targets. Tennis uses a rectangular court; east-west courts swap world axes into the same local simulation frame. Free practice uses a cardinal local frame, real wall extents and a flared player area.
- **PT_Wall:** selects an actual north/west tile edge from either face, covering all four directions. It gathers 1–5 continuous solid wall tiles. Starting depth is 1–14 tiles perpendicular to the wall, not diagonal distance. Cursor search and alternative clear routes permit nearby usable segments. Loaded floors, wall/window/door/fence flags and grid traversal reject invalid routes; diagonal traversal checks both legs and destination edges.
- **PT_Server:** validates sender identity, membership, equipment, sequence/rate limits and session tokens. Only tennis courts are registered; startWall creates a temporary session and serves. Tennis strokes require both participants. Every stroke requires a sports racket in the primary hand; serve/start also requires a tennis ball in the secondary hand. The virtual ball does not create or consume inventory balls.
- **PT_Training:** server/SP-only native XP requests for Fitness and Nimble; PT_Server admits whole seconds of active rally time after recent successful human contact. Training clocks are ephemeral session data, excluded from score checkpoints. No exercise fatigue or endurance mutation.
- **PT_Client:** RMB+LMB starts/restarts wall practice and serves tennis points. During a rally, cursor aim and LMB work without native aiming stance, retaining ordinary movement/run controls. J/K remain backup controls. Waiting blocks sports input. The sports primary item guards normal combat input even outside sessions. UI-consumed clicks are excluded. A zero-area overlay avoids intercepting native inventory hit tests; the ball renders through OnPostRender.
- **PT_Swing:** cosmetic, event-free native one-hand clip, about one second at normal speed. Owned actions and maskingright nodes avoid the default surrender fallback and permit moving-arm presentation. No damage events or locomotion block. A running swing is not restarted; another queued action is not interrupted. Visual timing is independent of the 250ms hit-attempt cooldown.
- **PT_ConvertRacket / PT_RacketMenu:** B42 timed-action complete() replaces an owned root-inventory item using native container/equipment transport. Rechecks ownership/attachment, refuses duplicate completion, preserves condition, repairs, custom state, modData and equipped hands.
- **PT_Items:** base:normal sports item references the vanilla racket icon/model/weight and hand-mask bindings. It is not a HandWeapon. Since Normal blood accessors are no-ops, PT_WeaponBlood temporarily preserves blood for reverse conversion. No copied game assets or vanilla item overrides.

## Physics and synchronization

Server fixed update is 30Hz, ballistic integration 120Hz, snapshots 10Hz. Aim is finite [-1,1]; clients do not supply scores, hit outcomes, player positions or ball positions. Session/revision/sequence checks reject stale input. Display uses a bounded eight-sample buffer and monotonic server-clock presentation delayed by100ms. Floor contact interpolates pre/post-bounce velocity and gravity separately; wall contact follows the reflection path instead of cutting directly between equal-distance endpoints. Rendering stops at the last sample if packets stop. Stale input is blocked and long server stalls replay the point. Historical rewind/latency compensation is not implemented.

Free practice has fixed depth14. Its player area expands linearly to two additional tiles on each side at the back; actual reflecting wall extents do not expand beyond the selected maximum five-tile segment. Maximum rear width is nine tiles. Reflection reverses wall-normal velocity while preserving tangent velocity and the gravity trajectory. No hitter-distance landing correction remains. Initial shots and moving-ball routes are checked for loaded floors/obstacles, and original wall extents are periodically revalidated. Ceiling/3D occlusion and dynamic actor collision are not simulated.

Tennis supports north–south and east–west rectangles with a virtual net and point/deuce scoring. Four points with a two-point lead finish the current game; there is no aggregate games or sets score. New court bounds are8–10 tiles wide and18–20 long; existing geometry remains usable. Rally first bounce is45% into the opponent half, initial apex is capped at2.4 and rebound apex at1.1. See TRAJECTORY.md for the model and range rationale. There are no tiebreaks or change of ends. Both modes share controls and cosmetic swing. The wall trapezoid is not applied to tennis.

## Persistence and compatibility

ModData PlayableTennis_v1 stores registered tennis courts, personal wallBest records and unfinished tennis point checkpoints keyed by court. Checkpoints hold plain copied core data and reserved usernames, never live player objects or a ball in flight. Same-username participants resume after interruption or restart; equipment changes, death, disconnect, vehicle entry, departure, disabled settings and temporarily unavailable court geometry pause tennis without awarding a point. Explicit Leave, court removal/replacement or single-game victory clear that checkpoint. Temporary wall sessions still close on these interruptions and do not resume. Old registered wall courts are retained only for owner/admin removal. Legacy solo-test checkpoints are discarded while registered courts and ordinary two-player checkpoints remain intact.

Standalone namespaced Lua, no Java patches or vanilla method overrides. Existing attacks or another mod's direct attack calls are not cancelled. Server and all clients need identical files; verify exact file identity when checking deployment. No split-screen support. No custom audio/assets are bundled; the sports item references installed native assets. Latest held appearance, swing blending and remote action/item replication still need live verification.

## Installed-source evidence

Inspected media root: C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/media. Initial appmanifest build ID25485521 is not proof for every historical B42 build.

- Projection: lua/client/Foraging/ISBaseIcon.lua; server/BuildingObjects/ISMoveableCursor.lua.
- Networking: server/ClientCommands.lua and shared/Util/LuaNet.lua.
- Wall flags: server/BuildingObjects/ISBuildIsoEntity.lua; shared/Util/AdjacentFreeTileFinder.lua.
- Persistence: server/Foraging/forageServer.lua.
- Native replacement: shared/TimedActions/ISLitCandleExtinguish.lua and ISClothingExtraAction.lua.
- Native racket/ball: scripts/generated/items/weapon.txt and normal.txt.
- Installed bytecode: OnPlayerUpdate precedes UpdateInputState/bannedAttacking checks; UIManager dispatches OnMouseDown only for unconsumed clicks; Normal blood accessors do not retain blood.
- Installed animation/action groups: native one-hand clip, actions fallback and movement child tags underpin the owned animation XML. Source inspection does not prove the rendered result.

## Next evidence gate

Follow PLAYTEST.md in SP and a two-client dedicated match. Prior user testing established playable wall rallies on a clear wall, but the latest motion and rendering fixes still require fresh visual and multiplayer evidence. No AI branch is planned.

## Existing vanilla tennis nets

Court validation permits only recreational_sports_01_49/50/51 (N edge) and52/53/54 (W edge) at the exact central line with matching orientation. Installed newtiledefinitions.tiles.txt marks these Hoppable and WallNTrans/WallWTrans; native loading supplies collideN/collideW. Other blockers on the same square still invalidate the court. Solid furniture/water/floor validation remains unchanged. There is no general low-fence rebound: virtual tennis net contact below or at0.91 is a fault/lost point under the existing scoring rules. Physical player collision is unchanged.

The vanilla gym cell49_4 includes52/53/54 in its tile dictionary. The user's measured court lines are18x10; registration accepts this east-west orientation. Static validation is not proof of a live successful registration on every vanilla court.
