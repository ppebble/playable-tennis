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
for _,size in ipairs({{7,20},{11,20},{8,17},{8,21}}) do
    command(a,"create",{x1=100,y1=100,x2=100+size[1],y2=100+size[2],z=0,mode="tennis"})
    check(last().command=="error" and db().courts[id],"new court dimension limits preserve old valid registration")
end
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

for _,cause in ipairs({"disconnect","vehicle","death","distance","floor","disabled","racket"}) do
    a,id,s=setup("tennis")
    s.core.points={2,3}
    if cause=="disconnect" then M.players={}
    elseif cause=="vehicle" then a.vehicle={}
    elseif cause=="death" then a.dead=true
    elseif cause=="distance" then a.x=1000
    elseif cause=="floor" then M.square(102,106,0).floor=false
    elseif cause=="racket" then a.racket=false
    else SandboxVars.PlayableTennis.Enabled=false end
    audit()
    check(S.sessions[id]==s and S.members.alpha==s and s.core.paused,"audit preserves and pauses on "..cause)
    check(s.core.points[1]==2 and s.core.points[2]==3 and db().sets[id].names[1]=="alpha","reserved identity and score saved: "..cause)
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
check(db().courts[id2]==nil and not S.members.beta and not db().sets[id2],"owner removal ends active saved set")
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
check(last().command=="error" and db().nextId==0,"wall court registration rejected")
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
M.square(100,101,0).solid=true
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
for i=1,1200 do PTCore.step(s.core,1/120) end
check(s.core.phase=="ready" and s.core.server==2,"server fixture reaches ready after feed")
a.x,a.y=102,109
command(a,"serve",{session=s.id,seq=3,aim=0})
check(s.core.phase=="ready" and s.core.server==2,"invalid solo baseline retains scheduled server")
local rejection=M.packets[#M.packets-1]
check(rejection.command=="error" and string.find(rejection.args.message,'baseline',1,true),"baseline rejection emits visible error before state")
a.x=(s.core.points[1]+s.core.points[2])%2==0 and 102 or 106; a.y=100
command(a,"serve",{session=s.id,seq=4,aim=0})
check(s.core.phase=="rally" and s.core.server==1 and s.core.lastHit==1,"solo server accepts human serve after feed")
M.square(103,105,0).solid=true
create(a)
check(S.members.alpha==s and db().courts[id],"invalid replacement preserves old court session")
M.square(103,105,0).solid=false
create(a)
check(not S.members.alpha and not S.sessions[id] and not db().courts[id],"valid replacement closes solo session")
M.reset(); a=M.player("alpha"); local wallId,wallSession=startWall(a)
b=M.player("beta"); create(b)
check(S.sessions[wallId]==wallSession and S.members.alpha==wallSession,"replacement preserves free wall session")
-- Readiness is checked using live receiver state, including between retries.
for servingSlot=1,2 do
    for parity=0,1 do
        a,id,s=setup("tennis")
        b=M.player("beta",106,120); command(b,"join",{id=id})
        s.core.server=servingSlot; s.core.points[1]=parity
        local server=servingSlot==1 and a or b
        local receiver=servingSlot==1 and b or a
        local serveArea=PTCore.serveArea(s.core,servingSlot)
        local receiveArea=PTCore.receiveArea(s.core,servingSlot)
        server.x,server.y=(serveArea.x1+serveArea.x2)/2,serveArea.baseline
        receiver.x,receiver.y=receiveArea.x,receiveArea.y
        command(server,"sync",{})
        check(s.core.receiverReady and s.core.receiveSlot==3-servingSlot,"snapshot publishes correct ready receiver")
        M.players={server}
        input(server,s,1)
        check(s.core.phase=="ready" and not s.core.receiverReady,"disconnected receiver cannot be ready before audit")
        M.players={a,b}
        local sequence=2
        for _,cause in ipairs({"wrongHalf","net","behindBaseline","floor","dead","vehicle","broken","missing","vanilla"}) do
            receiver.x,receiver.y,receiver.z=receiveArea.x,receiveArea.y,0
            receiver.dead,receiver.vehicle,receiver.condition,receiver.racket,receiver.itemType=false,nil,10,true,nil
            if cause=="wrongHalf" then receiver.x=208-receiver.x
            elseif cause=="net" then receiver.y=110
            elseif cause=="behindBaseline" then receiver.y=servingSlot==1 and 121.6 or 98.4
            elseif cause=="floor" then receiver.z=1
            elseif cause=="dead" then receiver.dead=true
            elseif cause=="vehicle" then receiver.vehicle={}
            elseif cause=="broken" then receiver.condition=0
            elseif cause=="missing" then receiver.racket=false
            else receiver.itemType="Base.TennisRacket" end
            input(server,s,sequence); sequence=sequence+1
            check(s.core.phase=="ready" and not s.core.ball and not s.core.receiverReady,"live receiver gate rejects "..cause)
            check(s.core.points[1]==parity and s.core.points[2]==0 and s.core.faults==0,"receiver rejection does not consume a fault or point")
        end
        receiver.x,receiver.y,receiver.z=receiveArea.x,receiveArea.y,0
        receiver.dead,receiver.vehicle,receiver.condition,receiver.racket,receiver.itemType=false,nil,10,true,nil
        input(server,s,sequence); sequence=sequence+1
        check(s.core.phase=="rally","positioned receiver unlocks serve for either server and parity")
        s.core.ball.z=-1; PTCore.step(s.core,1/120)
        check(s.core.phase=="ready" and s.core.faults==1,"first fault produces retry fixture")
        receiver.x=208-receiver.x
        input(server,s,sequence); sequence=sequence+1
        check(s.core.phase=="ready" and s.core.faults==1,"receiver must return to receive area for second serve")
        receiver.x=receiveArea.x
        input(server,s,sequence)
        check(s.core.phase=="rally" and s.core.faults==1,"ready receiver unlocks second serve without clearing fault")
    end
end
M.reset(); a=M.player("alpha"); id=create(a)
command(a,"startSolo",{id=id}); s=S.members.alpha
local before=PTCore.snapshot(s.core)
a.x=106
command(a,"feed",{session=s.id,seq=1,aim=0})
check(s.core.phase=="ready" and not s.core.ball and s.core.server==before.server and s.core.faults==before.faults,"feed rejects unpositioned tester before changing scheduled server")
local receiveArea=PTCore.receiveArea(s.core,2)
a.x,a.y=receiveArea.x,receiveArea.y
command(a,"feed",{session=s.id,seq=2,aim=0})
check(s.core.phase=="rally" and s.core.lastHit==2,"positioned tester unlocks feed")
check(s.core.testTarget.x==s.core.ball.x and s.core.testTarget.y==s.core.court.y2,"feed target depicts actual opposite server")
S.tick(); M.time=M.time+700; S.tick()
receiveArea=PTCore.receiveArea(s.core,1)
check(s.core.phase=="ready" and s.core.testTarget.x==receiveArea.x and s.core.testTarget.y==receiveArea.y,"stall let repositions solo target for human serve")
check(s.core.receiverReady,"solo target is immediately ready after let")
-- Persist only serializable values, restore a new runtime, and explicitly rebind
-- the authenticated live username without exposing either reserved slot.
a,id,s=setup("tennis")
b=M.player("beta",106,120); command(b,"join",{id=id})
s.core.points={3,3}; s.core.faults=1
input(a,s,1)
check(s.core.phase=="rally","persistence fixture starts a live rally")
a.racket=false
M.time=M.time+40; S.tick()
check(s.core.paused and s.core.phase=="ready" and not s.core.ball,"racket drop cancels rally before a point is awarded")
check(s.core.points[1]==3 and s.core.points[2]==3 and s.core.faults==1,"pause retains deuce and fault count")
a.racket=true; M.time=M.time+40; S.tick()
check(not s.core.paused and s.core.phase=="ready","racket return resumes saved point")
local function serializable(v)
    if type(v)=="table" then for k,value in pairs(v) do if not serializable(k) or not serializable(value) then return false end end; return true end
    return type(v)=="string" or type(v)=="number" or type(v)=="boolean" or v==nil
end
check(serializable(db().sets),"persistent records contain no player objects or functions")
local saved=PTCore.snapshot(M.db)
s.core.points[1]=99
check(saved.PlayableTennis_v1.sets[id].core.points[1]==3,"persistent snapshot does not alias live score")
M.reset(); M.db=saved
a=M.player("alpha",102,100)
command(a,"sync",{})
s=S.members.alpha
check(s and s.players[1]==a and not s.players[2] and s.core.points[1]==3 and s.core.points[2]==3,"restart restores score and rebinds returning username")
check(s.core.paused and s.names[2]=="beta" and s.core.phase=="ready","restart retains absent participant reservation and replays interrupted rally")
c=M.player("gamma",106,120); command(c,"join",{id=id})
check(not S.members.gamma and last().command=="error","stranger cannot take disconnected player's reserved slot")
b=M.player("beta",106,120); command(b,"join",{id=id})
check(s.players[2]==b and not s.core.paused and s.core.points[1]==3,"same user join resumes both participants without clearing points")
local impostor=M.player("alpha",102,100)
command(impostor,"sync",{})
check(s.players[1]==a and last().command=="error","duplicate live username cannot hijack reservation")
M.players={b,impostor}
command(impostor,"sync",{})
check(s.players[1]==impostor and s.seq[1]==nil,"replacement connection can rebind after original disconnects")
impostor.dead=true
local respawn=M.player("alpha",102,100)
command(respawn,"sync",{})
check(s.players[1]==respawn and s.core.points[1]==3,"living respawn rebinds while old dead entity remains listed online")
command(impostor,"leave",{})
check(S.sessions[id]==s and S.members.alpha==s,"old dead entity cannot terminate rebound set")
impostor=respawn
M.players={impostor}; M.packets={}
command(impostor,"sync",{})
for _,packet in ipairs(M.packets) do check(packet.player~=b,"publish does not send to retained disconnected player object") end
M.packets={}
command(impostor,"leave",{})
check(not db().sets[id] and not S.members.beta,"explicit leave clears both reservations and persisted score")
for _,packet in ipairs(M.packets) do check(packet.player~=b,"close does not send to retained disconnected player object") end
command(impostor,"join",{id=id}); s=S.members.alpha
check(s.core.points[1]==0 and s.core.points[2]==0,"deliberate join after leave begins fresh score")
s.core.phase="finished"; s.core.winner=1
M.packets={}; M.time=M.time+40; S.tick()
check(not S.sessions[id] and not db().sets[id] and not S.members.alpha,"victory releases persisted set and reservations")
check(last().command=="state" and last().args.core.phase=="finished" and last().args.core.winner==1,"victory publishes final scoreboard without a left packet")
command(impostor,"join",{id=id})
check(S.members.alpha and S.members.alpha.core.points[1]==0,"new join after victory starts a new set")
M.reset(); a=M.player("alpha")
db().courts={legacy={id="legacy",mode="tennis",x1=100,x2=114,y1=100,y2=130,z=0,owner="alpha"}}
command(a,"join",{id="legacy"})
check(S.members.alpha~=nil,"existing oversized court remains playable without forced migration")
M.reset(); a=M.player("alpha",100,202.5)
-- Native east/west net remains in place through register, join and serve audits.
for y=200,209 do
    local sq=M.square(109,y,0)
    sq.flags.HoppableW=true; sq.flags.collideW=true
    local net={getSprite=function() return {getName=function() return "recreational_sports_01_53" end} end,
        getProperties=function() return {Is=function(_,f) return f==IsoFlagType.HoppableW or f==IsoFlagType.collideW end} end}
    function sq:getObjects() return {size=function() return 1 end,get=function() return net end} end
end
command(a,"create",{x1=100,x2=118,y1=200,y2=210,z=0,mode="tennis"})
id=tostring(db().nextId)
check(db().courts[id] and db().courts[id].x2==118 and not db().courts[id].frame,"east-west registration persists world rectangle")
command(a,"join",{id=id}); s=S.members.alpha
check(s and s.core.court.frame and s.core.court.y2==118,"east-west join creates local play frame")
local receive=PTCore.receiveArea(s.core,1)
local rx,ry=PTWall.toWorld(s.core.court,receive.x,receive.y)
b=M.player("beta",rx,ry); command(b,"join",{id=id})
check(s.core.receiverReady,"east-west receiver readiness converts world coordinates")
input(a,s,1)
check(s.core.phase=="rally" and s.core.ball.y<101,"west baseline player serves eastward")
s.core.points={2,1}; command(a,"sync",{})
saved=PTCore.snapshot(M.db); M.reset(); M.db=saved
a=M.player("alpha",100,202.5); command(a,"sync",{}); s=S.members.alpha
check(s and s.core.court.frame and s.core.court.x1==200 and s.core.points[1]==2,"east-west restart preserves score and canonical frame")
-- XP follows bounded active time after accepted human contact, not input spam.
a,id,s=setup()
S.tick()
for i=1,15 do M.time=M.time+100; S.tick() end
check(#M.training==0,"waiting without opponent never grants training XP")
b=M.player("beta",106,115); command(b,"join",{id=id})
input(a,s,1)
check(s.training and s.training[1] and not s.training[2],"accepted serve arms only its human training slot")
local function trainingTicks(n)
    for i=1,n do
        if s.core.phase=="rally" then s.core.ball.z=100; s.core.ball.vz=0; s.core.ball.vx=0; s.core.ball.vy=0 end
        M.time=M.time+100; S.tick()
    end
end
trainingTicks(25)
check(#M.training>=2 and #M.training<=3,"active rally trains by elapsed seconds")
for _,grant in ipairs(M.training) do check(grant.player==a and grant.seconds==1,"unengaged opponent gets no XP and credits are batched") end
local marked=s.training[1].lastContact
command(a,"swing",{session=s.id,seq=2,aim=0})
check(s.training[1].lastContact==marked,"rejected swing cannot refresh training activity")
trainingTicks(60)
local credited=#M.training
check(credited<=6,"one contact cannot generate unbounded AFK training")
trainingTicks(20)
check(#M.training==credited,"expired contact stops XP despite an artificial ongoing rally")
s.core.phase="ready"; s.core.ball=nil; trainingTicks(20)
check(#M.training==credited,"ready state adds no training time")
M.reset(); a=M.player("alpha"); id,s=startWall(a); S.tick()
trainingTicks(15)
check(#M.training>=1,"wall practice uses the same active training path")
local before=#M.training; a.racket=false; trainingTicks(15)
check(#M.training==before,"unequipped player receives no wall practice XP")
M.reset(); a=M.player("alpha"); id,s=startWall(a); S.tick()
M.time=M.time+5000; S.tick()
check(#M.training==0,"server stall cannot award catch-up exercise XP")
checks=(checks or 0)+count
print("SERVER PASS: "..count.." behavioral checks")
