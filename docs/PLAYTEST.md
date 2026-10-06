# Live acceptance checklist — v0.2.0, pending

Use a disposable test profile, identical mod versions on server and both clients. Source tests, installation hashes, SP, hosted MP and dedicated sessions are separate proof layers.

- Convert a worn/bloody/favorite/custom-named racket both ways. Verify one item, same condition/repair count/name/weight/modData, preserved primary/secondary hands and held ball; relog/save/reload and recheck. Detach hotbar before conversion. Verify both clients observe equipment replacement.
- Base racket works as normal weapon, but never starts/plays sport. Sports racket never attacks even outside a session or while waiting. Switching back with held mouse buttons must not cause a delayed attack. Existing restrictions must remain after exit.
- Equip sports primary + TennisBall secondary. Aim and RMB+LMB at a single-tile wall from 2–8 tiles away. Repeat from all four directions, wider walls and offset target points. No court registration or drawn rectangle required. Reject door/window/fence, blocked path and missing floor. Inventory-only ball and reversed hands must fail start.
- Perform repeated wall returns, miss, restart from a changed nearby position, remove held ball and test start rejection. Insert obstacle, demolish wall, move away, enter vehicle, die/disconnect. No stuck guard or phantom session. Personal best persists through save/restart but active rally does not.
- Register a tennis court. First participant: waiting HUD, no J/K or mouse stroke. After second joins: proper roles, sport-only equipment and secondary-hand ball at serve. Exchange 20 returns. Test serve bounce, faults, deuce/game/match, departure and rejoin.
- Check both clients agree on ball, score and game transitions, plus unrelated parallel wall practice. Confirm malformed/replayed inputs cannot affect another player's session.
- Verify wall/court/ball rendering at different zooms/resolutions; mouse targets correspond to all four wall frames. Click inventory/chat controls while aiming: no sports stroke. Test high latency and stalled server independently.

Record build/mod version, mode, settings, steps, logs and screenshots/video. No checklist item is completed merely by mocked Kahlua tests. Existing production presets and saves are not modified by this workflow.
