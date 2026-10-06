local M,S=ServerMock,PTServer
local count=0
local function check(value,label) count=count+1; assert(value,"SERVER: "..label) end
local function db() return ModData.getOrCreate("PlayableTennis_v1") end
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

M.reset()
local a=M.player("alpha")
for _,v in ipairs({-1,100001,math.huge,0/0,100.5,"100",false}) do
    command(a,"create",{x1=v,y1=100,x2=108,y2=120,z=0,mode="tennis"})
    check(last().command=="error","malicious coordinate rejected")
end
check(not db().courts or next(db().courts)==nil,"invalid coordinates did not persist")
for _,z in ipairs({-1,8,0.5,math.huge}) do
    command(a,"create",{x1=100,y1=100,x2=108,y2=120,z=z,mode="tennis"})
    check(last().command=="error","unsupported floor rejected")
end
local id=create(a)
check(db().courts[id]~=nil,"valid court persisted")
create(a)
check(last().command=="error" and db().nextId==1,"overlapping registration rejected")
for i=1,3 do create(a,"tennis",100+i*20) end
create(a,"tennis",200)
check(db().nextId==4 and last().command=="error","per owner limit enforced")

for _,bad in ipairs({"hole","WindowN","DoorWallN","HoppableN"}) do
    M.reset(); a=M.player("alpha")
    for x=100,107 do M.square(x,100,0).flags.WallN=true end
    if bad=="hole" then M.square(104,100,0).flags.WallN=false else M.square(104,100,0).flags[bad]=true end
    command(a,"create",{x1=100,y1=100,x2=108,y2=120,z=0,mode="wall"})
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
for _,equipment in ipairs({"missing","broken","wrong","noBall"}) do
    a.racket=equipment~="missing"; a.condition=equipment=="broken" and 0 or 10
    a.itemType=equipment=="wrong" and "Base.BaseballBat" or nil; a.ball=equipment~="noBall"
    input(a,s,(s.seq[1] or 0)+1)
    check(s.core.phase=="ready" and last().command=="error","equipment guard "..equipment)
end
a.racket=true; a.condition=10; a.itemType=nil; a.ball=true
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
    a,id,s=setup("wall")
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

a,id,s=setup("wall")
b=M.player("beta",102,120); command(b,"join",{id=id})
check(not S.members.beta,"wall practice has one player capacity")
a.y=120; input(a,s,1)
check(s.core.phase=="rally","wall serve accepted with physical equipment")
local id2=create(b,"wall",140); command(b,"join",{id=id2})
local s2=S.members.beta
check(s2 and s2~=s,"independent courts create independent sessions")
s.core.bestRally=7; command(a,"leave",{})
check(S.sessions[id2]==s2 and S.members.beta==s2,"leaving does not close another court")
check(db().courts[id].bestRally==7,"practice best persisted when session closes")
a.x=102; a.y=120; command(a,"join",{id=id})
check(S.members.alpha.id~=s.id and S.members.alpha.core.bestRally==7,"rejoin creates fresh session and restores practice best")
check(S.members.alpha.core.phase=="ready" and not S.members.alpha.core.ball,"rejoin never resumes stale trajectory")
input(a,S.members.alpha,1,{session=s.id})
check(S.members.alpha.seq[1]==nil,"closed session packet cannot enter fresh session")
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
check(last().command=="error" and db().nextId==64,"world court limit enforced")
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
id=create(a,"wall"); command(a,"join",{id=id})
check(delivered[#delivered].command=="state" and #M.packets==0,"single player state uses direct client bridge")
a.y=120; s=S.members.alpha; input(a,s,1)
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
checks=(checks or 0)+count
print("SERVER PASS: "..count.." behavioral checks")
