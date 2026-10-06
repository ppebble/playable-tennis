# Live acceptance checklist — pending

Use a disposable test world/profile. Keep source tests, local hashes, SP, hosted MP and dedicated-server observations as separate evidence. Do not mark this checklist complete from mocks.

## Single player wall

- Enable PlayableTennis, equip vanilla racket, carry tennis ball. Register a clear outdoor 8×18 rectangle with continuous north wall. Check invalid window/door/fence/hole refusal.
- Join and verify projected corner lines align with selected world tiles at different zoom levels/resolutions. HUD must not consume mouse movement/clicks.
- K from south baseline starts a visible ball. Move into range and press J after wall rebound; perform 10 returns using three aim choices. Check sound occurs once per accepted shot, no combat/damage and no item duplication.
- Early/missed J consumes cooldown; high/low/out-of-reach ball is rejected. Two ground bounces reset rally. Leave/rejoin preserves best; save/quit/load preserves court and best but no active ball.
- Destroy part of wall, leave chunk, enter vehicle, die: clean session shutdown, no console error. Verify typed J/K in chat/text fields does not swing.

## Two real clients + dedicated server

- Install identical package on server and both clients; enable on an isolated test preset. Verify mod loads without exceptions in server and both client logs. Do not reuse an active production preset/port.
- Register one court, join both, verify north/south roles and waiting before second player joins. Each client equips own racket.
- Serve from the displayed side; receiving before first bounce fails. Exchange 20+ returns. Both HUDs agree on ball reset, points and games.
- Exercise first/double fault, net, first-bounce out, second bounce outside after first legal bounce, deuce, advantage, game, server rotation and first-to-N match end.
- Leave and rejoin for new match; disconnect one client mid-flight, reconnect and request sync. No stale ball/old-session packet should re-enter a new match.
- Compare low and high latency: record ping, server tick stalls, apparent input-to-contact delay and rejected-hit frequency. Confirm server stall replays point rather than awarding surprise points.
- Modify floor/wall while active and approach chunk boundaries; confirm safe shutdown. Two separate courts must not share score or packets.
- Save/restart dedicated server and verify court/records, fresh session state. Repeat in in-game hosting separately; neither validates the other.

## Record evidence

For each result capture installed build/mod version, SP/host/dedicated mode, settings, steps, observed behavior and relevant logs. Screenshots/video are needed for alignment and animation claims. User-managed saves and production settings are out of scope for automatic changes.
