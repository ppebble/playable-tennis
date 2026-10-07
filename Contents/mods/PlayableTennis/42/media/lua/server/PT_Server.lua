if isClient() then return end
require "PT_Core"
require "PT_Wall"
require "PT_Training"
PTServer = { sessions = {}, members = {}, serial = 0, rates = {} }
local S = PTServer
local function now() return getTimestampMs() / 1000 end
local function settings()
    return (SandboxVars and SandboxVars.PlayableTennis) or {}
end
local function bounded(value, default, low, high)
    if type(value) ~= "number" or value ~= value then return default end
    return math.max(low, math.min(high, value))
end
local function database()
    local db = ModData.getOrCreate("PlayableTennis_v1")
    db.courts = db.courts or {}
    db.nextId = db.nextId or 0
    db.wallBest = db.wallBest or {}
    db.sets = db.sets or {}
    return db
end
local function key(p) return p:getUsername() end
local function connected(p)
    if not p then return false end
    if not isServer() then return getSpecificPlayer(0)==p end
    local players=getOnlinePlayers()
    for i=0,players:size()-1 do if players:get(i)==p then return true end end
    return false
end
local function save(s)
    if s.core.court.mode~="tennis" then return end
    local core=s.core
    local signature=table.concat({tostring(core.points[1]),tostring(core.points[2]),tostring(core.server),
        tostring(core.faults),tostring(core.bestRally),tostring(core.winner),tostring(core.testTarget~=nil),
        tostring(s.names and s.names[1]),tostring(s.names and s.names[2])},":")
    if signature==s.savedSignature then return end
    s.savedSignature=signature
    -- Checkpoint score and identities, never a live trajectory. A restart is a let.
    local checkpoint=PTCore.snapshot(core)
    checkpoint.ball=nil; checkpoint.rally=0
    if checkpoint.phase~="finished" then checkpoint.phase="ready" end
    database().sets[core.court.id]={core=checkpoint,names=PTCore.snapshot(s.names or {})}
end
local function pause(s,reason)
    s.core.paused=true; s.core.message=reason
    if s.core.phase=="rally" then s.core.ball=nil; s.core.phase="ready"; s.core.rally=0 end
    save(s)
end
local function emit(p, command, args)
    if isServer() then sendServerCommand(p, "PlayableTennis", command, args)
    elseif PTClient then PTClient.receive(command, args) end
end
local function fail(p, message) emit(p, "error", { message = message }) end
local function integer(v, lo, hi)
    return type(v) == "number" and v == v and v >= lo and v <= hi and v == math.floor(v)
end
local function near(p, c, margin)
    if c.frame then return not p:isDead() and p:getZ()==c.z and PTWall.contains(c,p:getX(),p:getY(),margin) end
    return not p:isDead() and p:getZ() == c.z and p:getX() >= c.x1-margin and p:getX() <= c.x2+margin
        and p:getY() >= c.y1-margin and p:getY() <= c.y2+margin
end

local function squareAt(x,y,z) return getCell():getGridSquare(x,y,z) end
local function sportsRacket(p)
    local item=p:getPrimaryHandItem()
    return item and item:getFullType()=="PlayableTennis.SportsTennisRacket" and item:getCondition()>0
end
local function ballInHand(p)
    local item=p:getSecondaryHandItem()
    return item and item:getFullType()=="Base.TennisBall"
end
local function clearCourt(c)
    return PTWall.validateCourt(c,squareAt)
end
S.validateCourt = clearCourt
local function wallPath(c,x1,y1,x2,y2)
    local ax,ay=PTWall.toWorld(c,x1,math.max(0.02,y1))
    local bx,by=PTWall.toWorld(c,x2,math.max(0.02,y2))
    return PTWall.lineClear(ax,ay,bx,by,c.z,squareAt)
end
-- Reward time spent in real rallies, not packet volume or missed swings.
-- Recent successful contact is required so waiting/AFK participants do not train.
local function trainingContact(s,slot,p)
    s.training=s.training or {}
    local entry=s.training[slot]
    if not entry or entry.player~=p then entry={player=p,seconds=0}; s.training[slot]=entry end
    entry.lastContact=s.core.clock
end
local function trainRally(s,dt)
    if s.core.phase~="rally" or s.core.paused or not s.core.ball then return end
    for slot,entry in pairs(s.training or {}) do
        local p=s.players[slot]
        if p==entry.player and connected(p) and near(p,s.core.court,2) and not p:getVehicle()
            and sportsRacket(p) and s.core.clock-entry.lastContact<=6 then
            entry.seconds=entry.seconds+dt
            if entry.seconds+0.00000001>=1 then
                entry.seconds=math.max(0,entry.seconds-1)
                PTTraining.advance(p,1,settings())
            end
        end
    end
end
local function receiverReady(s,servingSlot)
    local core=s.core
    if core.court.mode~="tennis" then return true end
    if core.testTarget and servingSlot==1 then
        return PTCore.receiverInArea(core,1,core.testTarget.x,core.testTarget.y)
    end
    local p=s.players[3-servingSlot]
    local connected=false
    if isServer() then
        local players=getOnlinePlayers()
        for i=0,players:size()-1 do if players:get(i)==p then connected=true; break end end
    else connected=p~=nil and getSpecificPlayer(0)==p end
    if not connected or not p or p:isDead() or p:getVehicle() or p:getZ()~=core.court.z or not sportsRacket(p) then return false end
    local x,y=PTWall.toLocal(core.court,p:getX(),p:getY())
    return PTCore.receiverInArea(core,servingSlot,x,y)
end
local function publish(s)
    PTCore.refreshTestTarget(s.core)
    local servingSlot=s.core.testTarget and 1 or s.core.server
    s.core.receiveSlot=3-servingSlot
    s.core.receiverReady=receiverReady(s,servingSlot)
    if s.core.testTarget then s.core.feedReceiverReady=receiverReady(s,2) end
    s.revision=s.revision+1
    local names=PTCore.snapshot(s.names or {})
    for i=1,2 do if s.players[i] then names[i]=key(s.players[i]) end end
    save(s)
    for slot=1,2 do
        local p=s.players[slot]
        if connected(p) then emit(p,"state",{session=s.id,slot=slot,revision=s.revision,lastSeq=s.seq[slot] or 0,
            core=PTCore.snapshot(s.core),waiting=s.core.court.mode=="tennis" and not s.core.testTarget and not (s.players[1] and s.players[2]),players=names}) end
    end
end
local function close(s,reason)
    local c=database().courts[s.core.court.id]
    if c then c.bestRally=math.max(c.bestRally or 0,s.core.bestRally or 0) end
    if s.core.court.freeWall and s.players[1] then
        local who=key(s.players[1]); local records=database().wallBest
        records[who]=math.max(records[who] or 0,s.core.bestRally or 0)
    end
    for i=1,2 do
        local p=s.players[i]
        if s.names and s.names[i] then S.members[s.names[i]]=nil end
        if p then
            S.members[key(p)]=nil
            if connected(p) then emit(p,"left",{session=s.id,message=reason}) end
        end
    end
    S.sessions[s.core.court.id]=nil
    database().sets[s.core.court.id]=nil
end
local function list(p)
    local courts={}
    for _,c in pairs(database().courts) do
        if near(p,c,45) and #courts<32 then
            courts[#courts+1]={id=c.id,x1=c.x1,y1=c.y1,x2=c.x2,y2=c.y2,z=c.z,mode=c.mode,bestRally=c.bestRally or 0}
        end
    end
    emit(p,"list",{courts=courts})
end
local function newSession(c)
    local count=0; for _ in pairs(S.sessions) do count=count+1 end
    if count>=16 then return nil end
    S.serial=S.serial+1
    local s={id=tostring(getTimestampMs())..":"..S.serial,core=PTCore.new(c,{
        ballSpeed=bounded(settings().BallSpeed,9,6,14),
        hitRadius=bounded(settings().HitRadius,1.8,1,2.5)}),players={},names={},seq={},revision=0}
    s.core.bestRally=c.bestRally or 0
    S.sessions[c.id]=s
    return s
end
local function restore()
    local db=database()
    for id,record in pairs(db.sets) do
        if not db.courts[id] or record.core.phase=="finished" then db.sets[id]=nil
        elseif not S.sessions[id] then
            local s=newSession(db.courts[id])
            if s then
                s.core=PTCore.snapshot(record.core); s.core.court=PTCore.playCourt(db.courts[id])
                s.names=PTCore.snapshot(record.names or {})
                pause(s,"Point score saved. Waiting for participants to return.")
                for _,who in pairs(s.names) do S.members[who]=s end
            end
        end
    end
end
local function availability(s)
    if settings().Enabled==false then return "Tennis disabled by server; score saved." end
    for i=1,(s.core.testTarget and 1 or 2) do
        local p=s.players[i]
        if not connected(p) or not near(p,s.core.court,2) or p:getVehicle() or not sportsRacket(p) then
            return "Waiting for both participants on court with intact sports rackets; score saved."
        end
    end
    if not s.lastCourtCheck or now()-s.lastCourtCheck>=1 then
        s.lastCourtCheck=now()
        local ok,why=clearCourt(s.core.court)
        s.courtProblem=not ok and why or nil
    end
    return s.courtProblem
end
local function refreshPause(s)
    if s.core.court.mode~="tennis" or s.core.phase=="finished" then return end
    local reason=availability(s)
    if reason then pause(s,reason)
    elseif s.core.paused then s.core.paused=false; s.core.message="Participants ready. Replay the current point." end
end
function S.dispatch(p,command,args)
    if not p or type(command)~="string" or (args~=nil and type(args)~="table") then return end
    args=args or {}
    restore()
    local who=key(p)
    local t=now()
    local rate=S.rates[who]
    if not rate or t-rate.time>=1 then rate={time=t,count=0}; S.rates[who]=rate end
    rate.count=rate.count+1
    if rate.count>16 then return end
    if settings().Enabled==false and command~="sync" and command~="leave" then fail(p,"Playable Tennis is disabled by the server."); return end
    local s=S.members[who]
    if s and p~=s.players[1] and p~=s.players[2] then
        local slot=s.names and (s.names[1]==who and 1 or (s.names[2]==who and 2))
        local old=slot and s.players[slot]
        if not slot or (connected(old) and not old:isDead()) or not connected(p) or p:isDead() or (command~="sync" and command~="join" and command~="startSolo") then
            fail(p,"Player connection changed. Sync to resume your saved game."); return
        end
        s.players[slot]=p; s.seq[slot]=nil
    end
    if command=="sync" then
        list(p)
        if s then refreshPause(s); publish(s) else emit(p,"left",{message="No active session. Join a nearby court."}) end
        return
    end
    if command=="leave" then if s then close(s,"A participant left. Join again for a new game.") end; return end
    if command=="startWall" then
        if s then fail(p,"Leave your current court/practice before starting wall practice."); return end
        if p:isDead() or p:getVehicle() or not sportsRacket(p) or not ballInHand(p) then
            fail(p,"Hold a sports racket in your primary hand and a Tennis Ball in your secondary hand, on foot."); return
        end
        local c,why
        if args.edge then c,why=PTWall.select(p:getX(),p:getY(),p:getZ(),args,squareAt)
        else c,why=PTWall.find(p:getX(),p:getY(),p:getZ(),args.x,args.y,squareAt) end
        if not c then fail(p,why); return end
        c.freeWall=true; c.id="wall:"..who..":"..tostring(getTimestampMs())
        c.bestRally=database().wallBest[who] or 0
        s=newSession(c)
        if not s then fail(p,"Server session limit reached."); return end
        local px,py=PTWall.toLocal(c,p:getX(),p:getY())
        local startAim
        for _,candidate in ipairs({0,-0.5,0.5,-1,1}) do
            local tx,ty=PTCore.aimTarget(s.core,1,candidate,true)
            if wallPath(c,px,py,tx,ty) then startAim=candidate; break end
        end
        if startAim==nil then S.sessions[c.id]=nil; fail(p,"All shot paths to this wall are obstructed. Move sideways or select another segment."); return end
        if not PTCore.serve(s.core,1,px,py,startAim) then S.sessions[c.id]=nil; fail(p,s.core.message); return end
        s.players[1]=p; S.members[who]=s; trainingContact(s,1,p); publish(s); return
    end
    if command=="create" then
        if settings().AllowCourtCreation==false and p:getAccessLevel()~="admin" then fail(p,"Court registration is admin-only."); return end
        if args.mode~="tennis" then fail(p,"Register courts for 1v1 only. Aim at a wall to start solo practice."); return end
        for _,n in ipairs({"x1","y1","x2","y2"}) do
            if not integer(args[n],0,100000) then fail(p,"Invalid court coordinates."); return end
        end
        if not integer(args.z,0,7) then fail(p,"Invalid floor."); return end
        local c={x1=math.min(args.x1,args.x2),x2=math.max(args.x1,args.x2),y1=math.min(args.y1,args.y2),y2=math.max(args.y1,args.y2),z=args.z,mode=args.mode}
        local limits=PTCore.courtLimits
        if not PTCore.validCourtSize(c) then
            fail(p,"Court width must be "..limits.minWidth.."-"..limits.maxWidth.." and length "..limits.minLength.."-"..limits.maxLength.." tiles (either orientation)."); return
        end
        if not near(p,c,3) then fail(p,"Stand beside the court to register it."); return end
        local db=database()
        local ok,why=clearCourt(c)
        if not ok then fail(p,why); return end
        -- Validate first: an invalid selection must not destroy a playable court.
        for id in pairs(db.courts) do
            if S.sessions[id] then close(S.sessions[id],"The registered court was replaced.") end
        end
        db.courts={}
        db.sets={}
        db.nextId=db.nextId+1; c.id=tostring(db.nextId); c.owner=who; c.bestRally=0
        db.courts[c.id]=c
        emit(p,"created",{id=c.id})
        if isServer() then
            local players=getOnlinePlayers()
            for i=0,players:size()-1 do list(players:get(i)) end
        else list(p) end
        return
    end
    if command=="remove" then
        local c=database().courts[args.id]
        if not c or not near(p,c,5) or (c.owner~=who and p:getAccessLevel()~="admin") then fail(p,"Only the owner/admin may remove a nearby court."); return end
        if S.sessions[c.id] then close(S.sessions[c.id],"The registered court was removed.") end
        database().sets[c.id]=nil
        database().courts[c.id]=nil; list(p); return
    end
    if command=="join" or command=="startSolo" then
        if s then
            if args.id==s.core.court.id then refreshPause(s); publish(s)
            else fail(p,"Leave your current session first.") end
            return
        end
        local c=database().courts[args.id]
        if not c or not near(p,c,4) then fail(p,"Court not found nearby."); return end
        if c.mode~="tennis" then fail(p,"Wall practice no longer needs court registration. Aim at a nearby wall."); return end
        local ok,why=clearCourt(c); if not ok then fail(p,why); return end
        s=S.sessions[c.id]
        if s and (command=="startSolo" or s.core.testTarget) then fail(p,"Court is occupied. Leave the current match before starting another mode."); return end
        if command=="startSolo" and (p:getVehicle() or not sportsRacket(p) or not ballInHand(p)) then
            fail(p,"Hold a sports racket and a Tennis Ball, on foot, to start solo testing."); return
        end
        if not s then
            s=newSession(c)
            if not s then fail(p,"Server session limit reached."); return end
        end
        local slot=not s.names[1] and 1 or (c.mode=="tennis" and not s.names[2] and 2 or nil)
        if not slot then fail(p,"Court is full."); return end
        if command=="startSolo" then PTCore.enableTestTarget(s.core) end
        s.players[slot]=p; s.names[slot]=who; S.members[who]=s; refreshPause(s); publish(s); return
    end
    if command~="serve" and command~="swing" and command~="feed" then return end
    if not s or args.session~=s.id then fail(p,"Session changed; sync and join again."); return end
    local slot=s.players[1]==p and 1 or 2
    if not integer(args.seq,1,2147483647) or args.seq<=(s.seq[slot] or 0) then return end
    s.seq[slot]=args.seq
    if type(args.aim)~="number" or args.aim~=args.aim or args.aim < -1 or args.aim > 1 then fail(p,"Invalid aim."); return end
    if s.core.court.mode=="tennis" and not s.core.testTarget and not (s.players[1] and s.players[2]) then fail(p,"Waiting for a second player."); publish(s); return end
    if not near(p,s.core.court,2) or p:getVehicle() then fail(p,"Stay on the court, alive and on foot."); return end
    if not sportsRacket(p) then fail(p,"Equip an intact SPORTS Tennis Racket in your primary hand."); return end
    refreshPause(s)
    if s.core.paused then fail(p,s.core.message); publish(s); return end
    if s.core.court.freeWall then
        local ok,why=PTWall.valid(s.core.court,squareAt,p:getX(),p:getY())
        if not ok then close(s,why); return end
    end
    if command=="serve" or command=="feed" then
        if not ballInHand(p) then fail(p,"Hold a Tennis Ball in your secondary hand to serve."); return end
        local ok,why=clearCourt(s.core.court); if not ok then
            if s.core.court.mode=="tennis" then pause(s,why); publish(s) else close(s,why) end
            return
        end
        if s.core.court.mode=="tennis" and s.core.phase=="ready" then
            PTCore.refreshTestTarget(s.core)
            local servingSlot=command=="feed" and 2 or slot
            if not receiverReady(s,servingSlot) then
                s.core.message="Receiver must stand in the blue receive area with an intact SPORTS Tennis Racket, alive and on foot."
                fail(p,s.core.message); publish(s); return
            end
        end
    end
    if command=="feed" then
        if not PTCore.feedTestTarget(s.core) then fail(p,"Target feed is available only while ready in solo testing.") end
        publish(s); return
    end
    local px,py=p:getX(),p:getY()
    if s.core.court.frame then px,py=PTWall.toLocal(s.core.court,px,py) end
    if s.core.court.freeWall then
        local tx,ty=PTCore.aimTarget(s.core,slot,args.aim,command=="serve")
        local from=s.core.ball
        if not wallPath(s.core.court,command=="swing" and from and from.x or px,
            command=="swing" and from and from.y or py,tx,ty) then fail(p,"The shot path to the wall is obstructed."); return end
    end
    local accepted=PTCore[command](s.core,slot,px,py,args.aim)
    if command=="serve" then
        print("[PlayableTennis] serve "..(accepted and "accepted" or "rejected")..": session="..s.id.." seq="..args.seq.." player=("..px..","..py..") court=("..s.core.court.x1..","..s.core.court.y1..","..s.core.court.x2..","..s.core.court.y2..") slot="..slot.." | "..tostring(s.core.message))
        if not accepted then fail(p,s.core.message) end
    end
    if accepted then s.lastActivity=t; trainingContact(s,slot,p) end
    publish(s)
end
local function onlineSet()
    local result={}
    if isServer() then
        local players=getOnlinePlayers()
        for i=0,players:size()-1 do result[key(players:get(i))]=players:get(i) end
    else
        local p=getSpecificPlayer(0); if p then result[key(p)]=p end
    end
    return result
end
function S.tick()
    restore()
    local t=now()
    local delta=t-(S.lastTick or t); S.lastTick=t
    if delta<0 then delta=0 end
    S.accumulator=(S.accumulator or 0)+math.min(delta,0.2)
    if t-(S.lastAudit or 0)>=1 then
        S.lastAudit=t
        local online=onlineSet()
        for who in pairs(S.rates) do if not online[who] then S.rates[who]=nil end end
        local closing={}
        for _,s in pairs(S.sessions) do
            local reason=nil
            local stored=database().courts[s.core.court.id]
            if stored then stored.bestRally=math.max(stored.bestRally or 0,s.core.bestRally or 0) end
            if s.core.court.freeWall and s.players[1] then
                local who=key(s.players[1]); local records=database().wallBest
                records[who]=math.max(records[who] or 0,s.core.bestRally or 0)
            end
            if s.core.court.mode=="tennis" then
                if not stored then reason="The registered court was removed." end
            else
            if settings().Enabled==false then reason="Tennis disabled by server." end
            for i=1,2 do
                local p=s.players[i]
                if p and (online[key(p)]~=p or not near(p,s.core.court,8) or p:getVehicle()) then reason="Participant disconnected, died, or left the court." end
            end
            local valid,why=clearCourt(s.core.court)
            if not valid then reason=why end
            end
            if reason then closing[#closing+1]={s=s,reason=reason} end
        end
        for _,entry in ipairs(closing) do close(entry.s,entry.reason) end
    end
    -- Check availability before every physics advance, not only the slow audit:
    -- dropping a racket/disconnecting must never lose the current point.
    for _,s in pairs(S.sessions) do refreshPause(s) end
    -- A long server stall is a let: replay current point rather than integrate a lethal catch-up burst.
    if delta>0.5 then
        for _,s in pairs(S.sessions) do
            if s.core.phase=="rally" then
                s.core.ball=nil; s.core.phase="ready"; s.core.message="Server pause: replay point."
            end
        end
        S.accumulator=0
    end
    while S.accumulator>=1/30 do
        for _,s in pairs(S.sessions) do
            local c=s.core.court
            local old=s.core.ball and {x=s.core.ball.x,y=s.core.ball.y}
            if not s.core.paused then PTCore.step(s.core,1/30) end
            local ball=s.core.ball
            if c.freeWall and old and ball and not wallPath(c,old.x,old.y,ball.x,ball.y) then
                s.core.ball=nil; s.core.phase="ready"; s.core.rally=0
                s.core.message="Ball met an obstacle/unloaded floor. Hold the ball to restart."
            end
            trainRally(s,1/30)
        end
        S.accumulator=S.accumulator-1/30
    end
    local finished={}
    for _,s in pairs(S.sessions) do
        if s.core.phase=="finished" then finished[#finished+1]=s else save(s) end
    end
    for _,s in ipairs(finished) do
        publish(s)
        -- Keep the final scoreboard on clients until a deliberate new join.
        for _,who in pairs(s.names or {}) do S.members[who]=nil end
        S.sessions[s.core.court.id]=nil; database().sets[s.core.court.id]=nil
    end
    if t-(S.lastSend or 0)>=0.1 then
        S.lastSend=t
        for _,s in pairs(S.sessions) do publish(s) end
    end
end
Events.OnClientCommand.Add(function(module,command,p,args)
    if module=="PlayableTennis" then S.dispatch(p,command,args) end
end)
Events.OnTick.Add(S.tick)
