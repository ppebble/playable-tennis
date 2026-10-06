# Runtime contract — 0.2.2 development snapshot

This is an in-development contract, not a release declaration.

PTCore.new/serve/swing/step/snapshot and aimTarget(state,slot,aim,serving) remain pure Lua. Aim is finite [-1,1]. Tennis coordinates are world x/y; freeWall coordinates are wall tangent/perpendicular depth. Free wall courts include frame={originX,originY,ux,uy,vx,vy}, wallMinX/wallMaxX and edge metadata. Wall targets/reflection use real solid extents; the player area widens linearly to +4 tiles per side at depth14. Free serves launch at the player's current depth. Reflection reverses normal velocity without recalculating landing distance. Tennis stays rectangular.

PTWall.select(px,py,z,{x,y,edge=N or W},getSquare) and find(px,py,z,wx,wy,getSquare) return a temporary court/error. Start depth is perpendicular 1–14 tiles. toLocal/toWorld/contains convert/check the frame and player area. valid checks wall and optional player corridor; lineClear traces loaded floor and edges. Window/door/fence rejection and obstacle checks remain active despite relaxed selection.

PTServer.dispatch(player,command,args): create {x1,y1,x2,y2,z,mode=tennis}, join {id}, remove {id}, startWall {x,y,optional edge}, serve/swing {aim,seq,session}, leave, sync. Identity comes from the server player event. startWall requires primary PlayableTennis.SportsTennisRacket and secondary Base.TennisBall, immediately serves and never registers a court. Serve has the same equipment requirement. Swing needs an intact sports primary. Tennis rejects strokes until both slots exist.

Client receives state {session,slot,revision,lastSeq,core,waiting,players}, list {courts}, error {message}, left {session,message}. PTClient.receive is the SP bridge. Mouse RMB+LMB starts/restarts/serves; rally LMB uses cursor aim without requiring native aiming. UI-consumed clicks do not become sports input. Frames project into world coordinates; wall-contact interpolation and per-world-render drawing affect presentation only.

Base racket never sends sports input. Sports primary always guards ordinary combat input. Conversion/equipment changes drain held mouse buttons before restoring prior attack state; lifecycle exits restore immediately. This does not cancel already-running attacks or arbitrary other-mod attack calls.

PT_Swing queues a cosmetic one-second native one-hand action with no damage event. It permits locomotion, does not restart an active swing, and skips another occupied action queue. Visual completion is not a hit condition: authoritative attempts retain a 250ms cooldown.

PT_ConvertRacket implements server-native complete(); the inventory context menu only queues it. Sports item is base:normal with native appearance and hand masks. Require root ownership and no vehicle/death/attachment; completion is idempotent. Preserve item state and equipment; blood uses PT_WeaponBlood while Normal.
