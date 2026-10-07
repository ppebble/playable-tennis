# Live acceptance checklist — 0.2.2 development snapshot

Use a disposable test profile and identical snapshot files on server and both clients. Version remains 0.2.2 during development, so also record the Git commit. Source tests, installation hashes, SP, hosted MP and dedicated sessions are separate evidence layers. Earlier user testing confirmed playable wall rallies on a clear wall; the following checks remain for the latest snapshot.

- Convert a worn/bloody/favorite/custom-named racket both ways. Verify one item, preserved state and hands/held ball; relog/save/reload. Detach hotbar first. Both clients must observe replacement and the held native racket model.
- Base racket remains a weapon and never plays sport. Sports racket never attacks, including outside sessions/waiting. Switching back with held buttons must not cause a delayed attack; exit must restore previous restrictions.
- Equip sports primary + TennisBall secondary. RMB+LMB at a solid wall from perpendicular depths1–14. Repeat all four faces, one/six/nine-tile segments, diagonal starts and offset targets. Start again from a previously successful nearby position. Record HUD width/floor and exact error for rejected selections. Doors/windows/fences, blocked routes and missing floor must still fail; inventory-only ball/reversed hands must fail.
- After serve, release RMB and move/run with cursor aim and LMB returns. Miss and verify RMB+LMB is required to restart. Repeat on both modes. Inventory scrolling/clicking and chat must work without triggering shots.
- Verify the wall player area widens toward the rear (+4 tiles each side at depth14), side returns remain reachable, and only the real wall reflects. Check shallow/deep/diagonal shots and natural velocity through reflection; there is no first-landing-at14 guarantee. Tennis stays rectangular.
- Observe one-hand, roughly one-second follow-through standing, walking, running and sprinting. No two-arm surrender, damage or movement lock. An active swing should finish instead of restarting on each click; another action must not be interrupted. Check the remote client's view.
- Insert obstacles, demolish the wall, move away, enter a vehicle, die/disconnect. No stuck guard/phantom session. Personal best should survive restart; active rally should not.
- Register tennis. First player sees waiting and cannot send strokes; second join enables play. Verify equipment/serve rules, 20 returns, faults, deuce/game/match, departure/rejoin, and a concurrent unrelated wall session.
- Both clients must agree on ball/score/transitions. Verify stale or replayed commands cannot affect another session. Test latency and a stalled server separately.
- Check floor markers, cursor alignment, ball movement at different zooms/resolutions and wall reflection with video. Record any residual visual pause or packet-loss freeze separately from actual FPS.

Record game build, Git commit, settings, steps, logs and screenshots/video. A mocked test never completes a live checklist item. Use test profiles rather than changing production saves for this checklist.

- Select a rectangle forwards/backwards; verify dimensions, red invalid preview, Escape/rightclick, no leaked swing. Invalid replacement retains old court; valid replacement ends old match and leaves exactly one registered court. Other wall practice continues.
- Start Solo test, observe fixed far-left target, request opponent feed while ready, return into/outside target range and check ordinary scores. Feed during rally must fail. Normal Join cannot enter a test session; normal1v1 still waits for two real participants. This is not live network proof.
