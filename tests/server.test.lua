local M,S=ServerMock,PTServer
local count=0
local function check(value,label) count=count+1; assert(value,"SERVER: "..label) end
local function db() return ModData.getOrCreate("PlayableTennis_v1") end
local function empty(t) for _ in pairs(t) do return false end; return true end
local function last() return M.packets[#M.packets] end
local function command(p,name,args) M.time=M.time+70; S.dispatch(p,name,args) end
local function create(p,mode,x)
    x=x or 100; p.x=x+2; p.y=100
    if mode=="wall" then for i=x,x+7 do M.square(i,100,0).flags.WallN=true end end
    command(p,"create",{x1=x,y1=100,x2=x+8,y2=120,z=0,mode=mode or "tennis"})
    return tostring(db().nextId)
end
local function setup(mode)
    M.reset(); local a=M.player("alpha"); local id=create(a,mode)
    command(a,"join",{id=id}); return a,id,S.members.alpha
end
local function input(p,s,seq,extra)
    local args={seq=seq,session=s.id,aim=0}
    for k,v in pairs(extra or {}) do args[k]=v end
    command(p,"serve",args)
end
local function audit() M.time=M.time+1100; S.tick() end
local function startWall(p,edge,side,x)
    edge=edge or "N"; side=side or 1; x=x or 100
    for offset=-4,4 do M.square(x+(edge=="N" and offset or 0),100+(edge=="W" and offset or 0),0).flags["Wall"..edge]=true end
    p.x=edge=="N" and x+0.5 or x+side*4
    p.y=edge=="W" and 100.5 or 100+side*4
    command(p,"startWall",{x=x,y=100,edge=edge})
    local session=S.members[p.name]
    return session and session.core.court.id,session
end

M.reset()
local a=M.player("alpha")
for _,v in ipairs({-1,100001,math.huge,0/0,100.5,"100",false}) do
    command(a,"create",{x1=v,y1=100,x2=108,y2=120,z=0,mode="tennis"})
    check(last().command=="error","malicious coordinate rejected")
end
check(not db().courts or empty(db().courts),"invalid coordinates did not persist")
for _,z in ipairs({-1,8,0.5,math.huge}) do
    command(a,"create",{x1=100,y1=100,x2=108,y2=120,z=z,mode="tennis"})
    check(last().command=="error","unsupported floor rejected")
end
local id=create(a)
check(db().courts[id]~=nil,"valid court persisted")
create(a)
check(last().command=="list" and db().nextId==2 and not db().courts[id],"overlapping registration replaces old court")
for i=1,3 do create(a,"tennis",100+i*20) end
create(a,"tennis",200)
local registered=0; for _ in pairs(db().courts) do registered=registered+1 end
check(db().nextId==6 and registered==1,"only newest registered court survives")

for _,bad in ipairs({"hole","WindowN","DoorWallN","HoppableN"}) do
    M.reset(); a=M.player("alpha")
    M.square(100,100,0).flags.WallN=bad~="hole"
    if bad~="hole" then M.square(100,100,0).flags[bad]=true end
    a.x=100.5; a.y=104
    command(a,"startWall",{x=100,y=100,edge="N"})
    check(last().command=="error","wall rejects "..bad)
end
for _,bad in ipairs({"floor","solid","water","collideW","collideN"}) do
    M.reset(); a=M.player("alpha"); local sq=M.square(103,105,0)
    if bad=="floor" then sq.floor=false elseif bad=="solid" then sq.solid=true else sq.flags[bad]=true end
    create(a); check(last().command=="error","court rejects "..bad)
end

local s
a,id,s=setup("tennis")
input(a,s,1)
check(s.core.phase=="ready" and s.seq[1]==1,"cannot serve without opponent")
local b=M.player("beta",106,120); command(b,"join",{id=id})
local c=M.player("gamma",106,120); command(c,"join",{id=id})
check(not S.members.gamma and last().command=="error","third player rejected")
check(s.players[1]==a and s.players[2]==b,"stable player assignments")
input(c,s,1)
check(s.seq[2]==nil,"outsider cannot submit opponent input")
input(a,s,2,{session="stale"})
check(s.seq[1]==1,"old session rejected before consuming sequence")
input(a,s,0); input(a,s,1); input(a,s,1.5); input(a,s,math.huge)
check(s.seq[1]==1,"invalid and replayed sequence ignored")
input(a,s,2,{aim=9})
check(s.core.phase=="ready" and last().command=="error","invalid aim cannot serve")
for _,equipment in ipairs({"missing","broken","wrong","vanilla","inventoryOnly","wrongSecondary"}) do
    a.racket=equipment~="missing"; a.condition=equipment=="broken" and 0 or 10
    a.itemType=equipment=="wrong" and "Base.BaseballBat" or (equipment=="vanilla" and "Base.TennisRacket" or nil)
    a.ball=true; a.secondaryBall=equipment~="inventoryOnly"
    a.secondaryType=equipment=="wrongSecondary" and "Base.Baseball" or nil
    input(a,s,(s.seq[1] or 0)+1)
    check(s.core.phase=="ready" and last().command=="error","equipment guard "..equipment)
end
a.racket=true; a.condition=10; a.itemType=nil; a.ball=true; a.secondaryBall=true; a.secondaryType=nil
input(a,s,20,{x=99999,y=99999})
check(s.core.phase=="rally" and s.core.ball.x==a.x,"serve uses server position ignoring claimed coordinates")
local ball=s.core.ball
input(a,s,20)
check(s.core.ball==ball and s.seq[1]==20,"replayed serve cannot relaunch ball")
M.packets={}; command(a,"sync",{})
check(last().command=="state" and last().args.lastSeq==0,"opponent receives own sequence acknowledgement")
for _,packet in ipairs(M.packets) do check(packet.player==a or packet.player==b,"no session packet broadcast to outsider") end
local acknowledged=false
for _,packet in ipairs(M.packets) do if packet.player==a and packet.command=="state" then acknowledged=packet.args.lastSeq==20 end end
check(acknowledged,"sync recovers sender input sequence")
S.tick(); local y=s.core.ball.y; M.time=M.time+100; S.tick()
check(s.core.ball and s.core.ball.y~=y,"server tick advances production trajectory")
local points=s.core.points[1]+s.core.points[2]
M.time=M.time+700; S.tick()
check(s.core.phase=="ready" and not s.core.ball and s.core.points[1]+s.core.points[2]==points,"server stall replays point without awarding score")

for _,cause in ipairs({"disconnect","vehicle","death","distance","floor","disabled"}) do
    a,id,s=setup("tennis")
    if cause=="disconnect" then M.players={}
    elseif cause=="vehicle" then a.vehicle={}
    elseif cause=="death" then a.dead=true
    elseif cause=="distance" then a.x=1000
    elseif cause=="floor" then M.square(102,106,0).floor=false
    else SandboxVars.PlayableTennis.Enabled=false end
    audit()
    check(not S.sessions[id] and not S.members.alpha,"audit closes on "..cause)
    check(last().command=="left","closure informs participant: "..cause)
end

a,id,s=setup("tennis")
b=M.player("beta",142,100)
local id2=create(b,"tennis",140); command(b,"join",{id=id2})
local s2=S.members.beta
check(s2 and not S.members.alpha and not S.sessions[id],"replacement closes old session")
check(not db().courts[id],"replacement deletes old court")
command(a,"leave",{})
check(S.sessions[id2]==s2,"old member cannot close new session")
command(b,"leave",{}); command(b,"join",{id=id2})
check(S.members.beta.id~=s2.id,"rejoin creates fresh session")
input(b,S.members.beta,1,{session=s2.id})
check(S.members.beta.seq[1]==nil,"stale session input rejected")
command(b,"remove",{id=id2})
check(db().courts[id2]~=nil,"active court removal rejected")
command(b,"leave",{}); command(b,"remove",{id=id2})
check(db().courts[id2]==nil,"owner removes idle court")
check(M.command and M.tick,"production event handlers registered")
a,id,s=setup("tennis")
b=M.player("beta",106,120); command(b,"join",{id=id})
local replacement=M.player("alpha",106,120)
local previousCore=PTCore.snapshot(s.core)
local function same(left,right)
    if type(left)~=type(right) then return false end
    if type(left)~="table" then return left==right end
    for k,v in pairs(left) do if not same(v,right[k]) then return false end end
    for k in pairs(right) do if left[k]==nil then return false end end
    return true
end
input(replacement,s,100)
check(last().command=="error" and last().player==replacement,"reconnected object with same username is rejected")
check(s.seq[1]==nil and s.seq[2]==nil,"replacement object cannot consume either player's sequence")
check(same(previousCore,PTCore.snapshot(s.core)),"replacement object cannot mutate opponent or match core")
command(replacement,"leave",{})
check(S.sessions[id]==s and S.members.alpha==s,"replacement object cannot close original session")
input(a,s,1)
check(s.seq[1]==1 and s.core.phase=="rally","original player remains authorized after replacement rejection")
M.reset(); a=M.player("alpha")
SandboxVars.PlayableTennis.AllowCourtCreation=false
create(a); check(last().command=="error","admin only registration denies ordinary player")
a.admin=true; id=create(a); check(db().courts[id]~=nil,"admin may register restricted court")
command(a,"leave",{})
b=M.player("beta"); command(b,"remove",{id=id})
check(db().courts[id]~=nil,"other player cannot remove owner court")
M.reset(); a=M.player("alpha")
db().courts={}; db().nextId=64
for i=1,64 do db().courts[tostring(i)]={id=tostring(i),x1=1000+i*20,x2=1008+i*20,y1=100,y2=120,z=0,mode="tennis",owner="owner"..i} end
create(a)
check(last().command=="list" and db().nextId==65 and not db().courts["64"],"legacy courts replaced by singleton")
M.reset(); a=M.player("alpha"); id=create(a)
for i=1,16 do S.sessions["occupied"..i]={} end
command(a,"join",{id=id})
check(not S.members.alpha and last().command=="error","active session cap enforced")
M.reset(); a=M.player("alpha"); M.packets={}
for i=1,16 do S.dispatch(a,"sync",{}) end
local packetCount=#M.packets
S.dispatch(a,"sync",{})
check(#M.packets==packetCount,"excess command traffic rate limited")
M.time=M.time+1001; S.dispatch(a,"sync",{})
check(#M.packets>packetCount,"rate limit resets after window")
M.reset(); a=M.player("alpha")
for _,badId in ipairs({0/0,{},false,100,"missing"}) do
    command(a,"join",{id=badId})
    check(last().command=="error" and not S.members.alpha,"malformed court id safely rejected")
end
M.reset(); a=M.player("alpha")
local originalIsServer=isServer
isServer=function() return false end
local delivered={}
PTClient={receive=function(command,args) delivered[#delivered+1]={command=command,args=args} end}
id,s=startWall(a)
check(delivered[#delivered].command=="state" and #M.packets==0,"single player state uses direct client bridge")
check(s.core.phase=="rally","single player direct dispatch starts practice")
S.tick(); M.time=M.time+100; S.tick()
check(S.members.alpha==s,"single player online audit recognizes local player")
command(a,"leave",{})
check(delivered[#delivered].command=="left" and not S.members.alpha,"single player close uses direct client bridge")
isServer=originalIsServer; PTClient=nil
a,id,s=setup("tennis")
b=M.player("beta",106,120); command(b,"join",{id=id})
input(a,s,1,{aim=0.375})
check(s.core.phase=="rally" and s.core.shotId==1,"multiplayer accepts fractional mouse serve aim")
local seq=2
for _,bad in ipairs({0/0,math.huge,-math.huge,"0.5",{},1.001,-1.001}) do
    input(a,s,seq,{aim=bad}); seq=seq+1
    check(last().command=="error" and s.core.shotId==1,"malformed mouse aim rejected without a new shot")
end
s.core.ball={x=106,y=119,z=1,vx=0,vy=1,vz=0}
s.core.servicePending=false; s.core.bounces=1
command(b,"swing",{session=s.id,seq=1,aim=-0.625})
check(s.core.lastHit==2 and s.core.shotId==2,"multiplayer accepts fractional mouse return aim")
for _,edge in ipairs({"N","W"}) do
    for _,side in ipairs({-1,1}) do
        M.reset(); a=M.player("alpha")
        id,s=startWall(a,edge,side)
        check(s and s.core.phase=="rally","wall starts from cardinal side "..edge..side)
        check(s.core.court.freeWall and s.players[1]==a and not s.players[2],"wall is solo temporary session")
        local registry=db()
        check(not registry.courts or empty(registry.courts),"wall start does not register court")
        local lx,ly=PTWall.toLocal(s.core.court,a.x,a.y)
        check(math.abs(s.core.ball.x-lx)<0.001 and ly>0,"wall shot uses local cardinal frame")
        local originalBall=s.core.ball
        command(a,"startWall",{x=100,y=100,edge=edge})
        check(S.members.alpha==s and s.core.ball==originalBall and last().command=="error","duplicate wall start cannot reset session")
        b=M.player("beta",a.x,a.y); command(b,"join",{id=id})
        check(not S.members.beta,"temporary wall session cannot be joined")
        input(a,s,1,{session="stale"})
        check(s.seq[1]==nil and s.core.ball==originalBall,"stale wall input cannot mutate trajectory")
        command(a,"leave",{})
        check(not S.members.alpha and (not db().courts or empty(db().courts)),"wall closure leaves no saved court")
    end
end
M.reset(); a=M.player("alpha")
create(a,"wall")
check(last().command=="error" and not db().nextId,"wall court registration rejected")
db().courts={legacy={id="legacy",mode="wall",x1=100,x2=108,y1=100,y2=120,z=0}}
command(a,"join",{id="legacy"})
check(last().command=="error" and not S.members.alpha,"legacy wall registry cannot be joined")
for _,equipment in ipairs({"vanilla","broken","inventoryOnly","wrongSecondary","vehicle","dead"}) do
    M.reset(); a=M.player("alpha")
    a.itemType=equipment=="vanilla" and "Base.TennisRacket" or nil
    a.condition=equipment=="broken" and 0 or 10
    a.secondaryBall=equipment~="inventoryOnly"; a.ball=true
    a.secondaryType=equipment=="wrongSecondary" and "Base.Baseball" or nil
    a.vehicle=equipment=="vehicle" and {} or nil; a.dead=equipment=="dead"
    startWall(a)
    check(not S.members.alpha and last().command=="error","wall start equipment/activity guard "..equipment)
end
for _,args in ipairs({{x=0/0,y=100,edge="N"},{x=100,y=math.huge,edge="N"},{x=100,y=100,edge="S"},{x=100,y=100,edge="N",z=1},{x={},y=100},{x=100000000,y=100},{}}) do
    M.reset(); a=M.player("alpha",100.5,104); M.square(100,100,0).flags.WallN=true
    command(a,"startWall",args)
    check(not S.members.alpha and last().command=="error","malformed wall payload rejected")
end
for _,cause in ipairs({"disconnect","destroyedWall","vehicle"}) do
    M.reset(); a=M.player("alpha"); id,s=startWall(a)
    if cause=="disconnect" then M.players={}
    elseif cause=="destroyedWall" then M.square(100,100,0).flags.WallN=false
    else a.vehicle={} end
    audit()
    check(not S.members.alpha and not S.sessions[id],"temporary wall audit closes on "..cause)
end
M.reset(); a=M.player("alpha",100.5,104); M.square(100,100,0).flags.WallN=true
command(a,"startWall",{x=100.5,y=100})
check(S.members.alpha and S.members.alpha.core.phase=="rally","mouse world target discovers wall without explicit edge")
s=S.members.alpha; s.core.bestRally=7
command(a,"leave",{})
command(a,"startWall",{x=100.5,y=100})
s=S.members.alpha
check(s.core.bestRally==7,"free practice record follows the player without registering courts")
-- New obstacles on the authoritative ball path stop practice without pretending
-- the ball can travel through furniture or another wall.
S.tick(); M.square(100,103,0).solid=true
M.time=M.time+100; S.tick()
check(s.core.phase=="ready" and not s.core.ball,"authoritative practice trajectory stops at a new solid obstacle")
M.reset(); a=M.player("alpha",100.5,104)
M.square(100,102,0).solid=true
id,s=startWall(a)
check(s and s.core.phase=="rally","wall start chooses clear side target when centre route blocked")
M.reset(); a=M.player("alpha",105,114)
for offset=-4,4 do M.square(100+offset,100,0).flags.WallN=true end
command(a,"startWall",{x=100,y=100,edge="N"})
check(S.members.alpha and S.members.alpha.core.phase=="rally","server starts diagonal practice at perpendicular depth fourteen")
M.reset(); a=M.player("alpha"); id=create(a)
command(a,"startSolo",{id=id}); s=S.members.alpha
check(s and s.core.testTarget and not s.players[2],"solo owns only real player slot")
check(last().command=="state" and not last().args.waiting,"solo publishes playable state")
b=M.player("beta"); command(b,"join",{id=id})
check(not S.members.beta,"normal player cannot enter test session")
command(b,"startSolo",{id=id}); check(not S.members.beta,"other tester cannot replace occupied session")
command(a,"feed",{session=s.id,seq=1,aim=0})
check(s.core.phase=="rally" and s.core.lastHit==2,"authorized explicit target feed")
local fed=s.core.ball
command(a,"feed",{session=s.id,seq=1,aim=0})
check(s.core.ball==fed,"duplicate feed cannot reset ball")
command(a,"feed",{session=s.id,seq=2,aim=0})
check(s.core.ball==fed,"feed during rally rejected")
M.square(103,105,0).solid=true
create(a)
check(S.members.alpha==s and db().courts[id],"invalid replacement preserves old court session")
M.square(103,105,0).solid=false
create(a)
check(not S.members.alpha and not S.sessions[id] and not db().courts[id],"valid replacement closes solo session")
M.reset(); a=M.player("alpha"); local wallId,wallSession=startWall(a)
b=M.player("beta"); create(b)
check(S.sessions[wallId]==wallSession and S.members.alpha==wallSession,"replacement preserves free wall session")
checks=(checks or 0)+count
print("SERVER PASS: "..count.." behavioral checks")
