# Runtime contract — v0.2.0

PTCore.new/serve/swing/step/snapshot and aimTarget(state,slot,aim,serving) remain pure Lua. aim finite [-1,1]. Tennis coordinates are world x/y; freeWall coordinates are local wall tangent/depth. Free wall court includes frame={originX,originY,ux,uy,vx,vy}, wallMinX/wallMaxX, wall edge metadata. Wall target/hit tests use actual wall extents. Free serves launch at current player depth, not an artificial baseline.

PTWall.select(px,py,z,{x,y,edge=N or W},getSquare) and find(px,py,z,wx,wy,getSquare) return temporary court/error. toLocal/toWorld/contains convert frames. valid checks wall and optional player corridor; lineClear traces loaded floor and wall edges.

PTServer.dispatch(player,command,args): create {x1,y1,x2,y2,z,mode=tennis}, join {id}, remove {id}, startWall {x,y,optional edge}, serve/swing {aim,seq,session}, leave, sync. Server player event supplies identity. startWall requires primary PlayableTennis.SportsTennisRacket and secondary Base.TennisBall, immediately launches practice, never registers a court. Serve has same equipment requirement. Swing only needs intact sports primary. Tennis waiting rejects all strokes until both slots exist.

Client receives state {session,slot,revision,lastSeq,core,waiting,players}, list {courts}, error {message}, left {session,message}. PTClient.receive is SP bridge. Frames are projected back into world coordinates before rendering. Normal base racket does not send sports input. Sports primary always guards ordinary combat input. On inventory conversion/equipment changes, a held click is drained before prior attack state restoration; lifecycle exits restore immediately.

PT_ConvertRacket implements server-native complete(), context menu only queues it. Sports item is base:normal with vanilla appearance. Inventory root ownership, no vehicle/death/attachment, idempotent completion. Preserve item state and equipment; blood uses PT_WeaponBlood while Normal.
