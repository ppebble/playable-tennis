local court = {id = "test", x1 = 0, y1 = 0, x2 = 8, y2 = 18, z = 0, mode = "tennis"}
local function check(value, message)
    checks = (checks or 0) + 1
    assert(value, message)
end
local function new(options) return PTCore.new(court, options) end
local function advance(s, seconds)
    for i = 1, math.floor(seconds * 120 + 0.5) do PTCore.step(s, 1 / 120) end
end
local function ground(s, x, y)
    s.ball = {x = x, y = y, z = 0.001, vx = 0, vy = 0, vz = -1}
    PTCore.step(s, 1 / 120)
end
local function winPoint(s, slot)
    s.phase, s.servicePending, s.lastHit, s.bounces = "rally", false, slot, 1
    ground(s, 4, slot == 1 and 14 or 4)
end
local s = new()
check(s.shotId == 0, "new session has no accepted shots")
check(not PTCore.serve(s, 2, 6, 18, 0), "only server may serve")
check(not PTCore.serve(s, 1, 6, 0, 0), "deuce baseline side enforced")
check(not PTCore.serve(s, 1, 2, 4, 0), "baseline distance enforced")
check(not PTCore.serve(s, 1, 2, 0, 2), "aim must be within normalized range")
check(PTCore.serve(s, 1, 2, 0, 0), "legal north serve")
check(s.shotId == 1, "accepted serve advances shot sequence")
check(not PTCore.serve(s, 1, 2, 0, 0), "cannot serve twice")
check(not PTCore.swing(s, 1, 2, 0, 0), "cooldown rejects immediate hit")
local sawServeBounce = false
for i = 1, 600 do
    PTCore.step(s, 1 / 120)
    if s.ball and s.ball.y > 9 and s.servicePending and s.ball.z <= 2.4 then
        check(not PTCore.swing(s, 2, s.ball.x, s.ball.y, 0), "serve must bounce before return")
    end
    if s.ball and not s.servicePending then sawServeBounce = true; break end
end
check(sawServeBounce and s.bounces == 1, "default serve reaches diagonal box over net")
check(s.ball.x >= 4 and s.ball.y >= 9 and s.ball.y <= 13.5, "serve landing coordinates legal")
advance(s, 0.08)
check(not PTCore.swing(s, 2, 0, 18, 0), "distant racket cannot hit")
check(not PTCore.swing(s, 2, s.ball.x, s.ball.y, 0), "missed attempt also consumes cooldown")
check(s.shotId == 1, "misses do not advance shot sequence")
advance(s, 0.26)
check(PTCore.swing(s, 2, s.ball.x, s.ball.y, 0), "receive after bounce in reach")
check(s.shotId == 2, "accepted return advances shot sequence")
check(s.lastHit == 2 and s.rally == 1 and s.bounces == 0, "return resets bounce counter")
check(not PTCore.swing(s, 2, s.ball.x, s.ball.y, 0), "repeat hit rejected")
advance(s, 6)
check(s.points[2] == 1 and s.phase == "ready", "unreturned legal shot awards hitter")
check(not PTCore.serve(s, 1, 2, 0, 0), "odd point switches service side")
check(PTCore.serve(s, 1, 6, 0, 0), "ad service side accepted")

s = new()
check(PTCore.serve(s, 1, 2, 0, 0), "start net fault")
s.ball = {x = 5, y = 8.99, z = 0.3, vx = 0, vy = 9, vz = 0}
PTCore.step(s, 1 / 120)
check(s.faults == 1 and s.phase == "ready" and s.points[2] == 0, "first net fault retries")
check(PTCore.serve(s, 1, 2, 0, 0), "retry serve")
ground(s, 2, 12)
check(s.points[2] == 1 and s.faults == 0, "second wrong-box fault awards receiver")

s = new()
s.phase, s.lastHit, s.servicePending = "rally", 1, false
ground(s, 9, 14)
check(s.points[2] == 1, "out before first bounce loses point")
s.phase, s.lastHit, s.servicePending = "rally", 1, false
ground(s, 4, 3)
check(s.points[2] == 2, "own-side landing loses point")
s.phase, s.lastHit, s.servicePending, s.bounces = "rally", 1, false, 1
ground(s, 9, 20)
check(s.points[1] == 1, "second bounce outside still wins for hitter")

s = new({gamesToWin = 1})
for i = 1, 3 do winPoint(s, 1); winPoint(s, 2) end
check(s.points[1] == 3 and s.points[2] == 3, "deuce")
winPoint(s, 1)
check(s.phase == "ready" and s.points[1] == 4, "advantage is not a game")
winPoint(s, 2)
check(s.phase == "ready" and s.points[1] == s.points[2], "return to deuce")
winPoint(s, 1); winPoint(s, 1)
check(s.server == 1 and s.points[1] == 6, "victory preserves final points without aggregate games or server rotation")
check(s.phase == "finished" and s.winner == 1, "single points game completes")
check(not PTCore.serve(s, 2, 6, 18, 0), "finished match cannot restart")

s = new()
local snap = PTCore.snapshot(s)
snap.court.x1, snap.options.ballSpeed, snap.points[1] = 99, 99, 99
check(s.court.x1 == 0 and s.options.ballSpeed == 9 and s.points[1] == 0, "snapshot is deep independent copy")
local source = {x1 = 0, y1 = 0, x2 = 8, y2 = 18, z = 0, mode = "wall"}
s = PTCore.new(source, {})
source.mode = "tennis"
check(s.court.mode == "wall", "constructor copies court")
check(PTCore.serve(s, 1, 4, 18, 0), "practice serve")
advance(s, 0.3)
check(not PTCore.swing(s, 1, s.ball.x, s.ball.y, 0), "practice must reach wall first")
for i = 1, 500 do
    PTCore.step(s, 1 / 120)
    if s.wallReady then break end
end
check(s.wallReady and s.ball.vy > 0 and s.rally == 1 and s.bestRally == 1, "north wall reflects and counts")
check(PTCore.swing(s, 1, s.ball.x, s.ball.y, 0), "practice return after wall contact")
for i = 1, 500 do
    PTCore.step(s, 1 / 120)
    if s.wallReady then break end
end
check(s.wallReady and s.rally == 2 and s.bestRally == 2, "second wall rally counts")
s.bounces = 1
ground(s, 4, 10)
check(s.phase == "ready" and s.bestRally == 2 and s.rally == 0, "practice reset preserves personal best")

local wallCourt = {x1 = 0, y1 = 0, x2 = 8, y2 = 20, z = 0, mode = "wall"}
s = PTCore.new(wallCourt, {})
check(PTCore.serve(s, 1, 4, 20, 0), "twenty-tile practice serve")
local reachable = false
for i = 1, 1200 do
    PTCore.step(s, 1 / 120)
    if s.ball and s.wallReady and s.ball.z >= 0.15 and s.ball.z <= 2.4 and math.abs(s.ball.y - 19) <= 1.8 then
        reachable = PTCore.swing(s, 1, 4, 19, 0)
        break
    end
end
check(reachable, "practice return reachable one tile forward of twenty-tile baseline")

for _, length in ipairs({12, 18, 30}) do
    for _, speed in ipairs({5, 9, 14}) do
        local compact = {x1 = 0, y1 = 0, x2 = 8, y2 = length, z = 0, mode = "tennis"}
        local serveState = PTCore.new(compact, {ballSpeed = speed})
        PTCore.serve(serveState, 1, 2, 0, 0)
        local bounced = false
        for i = 1, 2000 do
            PTCore.step(serveState, 1 / 120)
            if serveState.ball and not serveState.servicePending then bounced = true; break end
            if serveState.phase ~= "rally" then break end
        end
        check(bounced, "legal serve must clear net across supported speed/court sizes")
    end
end

local a, b = new(), new()
PTCore.serve(a, 1, 2, 0, 0); PTCore.serve(b, 1, 2, 0, 0)
for i = 1, 12 do PTCore.step(a, 1 / 12) end
for i = 1, 120 do PTCore.step(b, 1 / 120) end
check(math.abs(a.ball.x - b.ball.x) < 0.000001 and math.abs(a.ball.z - b.ball.z) < 0.000001, "fixed-step state independent of frame partition")
local before = a.clock
PTCore.step(a, -1); PTCore.step(a, 0 / 0); PTCore.step(a, math.huge)
check(a.clock == before, "invalid dt ignored")
PTCore.step(a, 1000)
check(a.clock - before < 0.251, "stall catch-up bounded")

-- Free wall mode uses the real narrow wall face, not a registered tennis box.
for _,depth in ipairs({2,4,8}) do
    local c={id="free",mode="wall",freeWall=true,x1=-2,x2=2,y1=0,y2=depth+4,z=0,wallMinX=-0.5,wallMaxX=0.5}
    local s=PTCore.new(c)
    check(PTCore.serve(s,1,0,depth,0.5),"free practice serves from current position, not artificial baseline")
    local contact=false
    for i=1,240 do
        PTCore.step(s,1/120)
        if s.wallReady then contact=true; break end
        if not s.ball then break end
    end
    check(contact and s.rally==1,"free practice reaches a single-tile wall from supported distance")
end
local free=PTCore.new({mode="wall",freeWall=true,x1=-2,x2=2,y1=0,y2=8,z=0,wallMinX=-0.5,wallMaxX=0.5})
free.phase="rally"; free.ball={x=1,y=0.01,z=1,vx=0,vy=-4,vz=0}
PTCore.step(free,1/30)
check(free.phase=="ready" and free.bestRally==0,"play region cannot substitute for actual wall segment")
free.phase="rally"; free.ball={x=2.1,y=3,z=0.01,vx=0,vy=0,vz=-1}; free.wallReady=true; free.bounces=0
PTCore.step(free,1/30)
check(free.phase=="rally" and free.bounces==1,"free-wall bounce has no imaginary court sideline")

local function near(actual, expected) return math.abs(actual - expected) < 0.000001 end
for _, mode in ipairs({"tennis", "wall"}) do
    for _, slot in ipairs({1, 2}) do
        for _, serving in ipairs({true, false}) do
            for _, aim in ipairs({-1, -0.37, 0, 0.62, 1}) do
                local targetState = new()
                targetState.court.mode = mode
                local tx, ty = PTCore.aimTarget(targetState, slot, aim, serving)
                local expectedX, expectedY
                if mode == "wall" then
                    expectedX, expectedY = 4 + aim * 8 * (serving and 0.18 or 0.3), 0
                elseif serving then
                    expectedX = 4 + (slot == 1 and 1 or -1) * 2 + aim * 0.8
                    expectedY = 9 + (slot == 1 and 1 or -1) * 18 * 0.16
                else
                    expectedX = 4 + aim * 2.4
                    expectedY = 9 + (slot == 1 and 1 or -1) * 18 * 0.225
                end
                check(near(tx, expectedX) and near(ty, expectedY), "shared preview preserves serve/wall/rally target formulas")
            end
        end
    end
end
for _, slot in ipairs({1, 2}) do
    for _, odd in ipairs({false, true}) do
        for _, aim in ipairs({-0.83, 0.24, 0.77}) do
            local fractional = new()
            fractional.server = slot
            fractional.points[1] = odd and 1 or 0
            local fromLeft = (slot == 1 and not odd) or (slot == 2 and odd)
            local tx, ty = PTCore.aimTarget(fractional, slot, aim, true)
            check((fromLeft and tx > 4 or not fromLeft and tx < 4)
                and math.abs(ty - 9) < 4.5, "fractional aim target stays in diagonal service box")
            check(PTCore.serve(fractional, slot, fromLeft and 2 or 6, slot == 1 and 0 or 18, aim), "fractional serve accepted")
            local bounced = false
            for i = 1, 1000 do
                PTCore.step(fractional, 1 / 120)
                if fractional.ball and not fractional.servicePending then bounced = true; break end
                if fractional.phase ~= "rally" then break end
            end
            check(bounced, "fractional serve physically lands legally")
            advance(fractional, 0.08)
            check(PTCore.swing(fractional, 3 - slot, fractional.ball.x, fractional.ball.y, aim), "fractional return accepted")
        end
    end
end
for _, bad in ipairs({0 / 0, math.huge, -math.huge, "0", -1.01, 1.01, false}) do
    local invalid = new()
    check(PTCore.aimTarget(invalid, 1, bad, true) == nil, "preview rejects invalid normalized aim")
    check(not PTCore.serve(invalid, 1, 2, 0, bad), "serve rejects invalid normalized aim")
    check(not PTCore.swing(invalid, 1, 2, 0, bad), "swing rejects invalid normalized aim")
end
check(PTCore.aimTarget(nil, 1, 0, true) == nil, "preview rejects absent state")
check(PTCore.aimTarget({}, 1, 0, true) == nil, "preview rejects absent court")
check(PTCore.aimTarget(new(), 3, 0, true) == nil, "preview rejects invalid slot")
check(PTCore.aimTarget(new(), 1, nil, true) == nil, "preview rejects absent aim")
check(PTCore.aimTarget(new(), 1, 0, nil) == nil, "preview requires serving boolean")

-- Wall contact preserves speed and gravity instead of choosing a new landing.
-- Side positions intentionally make diagonal travel exceed fourteen tiles.
local practice = {mode="wall",freeWall=true,x1=-2,x2=2,y1=0,y2=14,z=0,wallMinX=-0.5,wallMaxX=0.5}
local function checkWallReflection(state)
    for i=1,1600 do
        local before=PTCore.snapshot(state).ball
        PTCore.step(state,1/120)
        if not state.ball then return false end
        if state.wallReady then
            local ball,dt=state.ball,1/120
            check(near(ball.vx,before.vx),"wall preserves lateral velocity")
            check(near(ball.vy,-before.vy),"wall reverses normal velocity without slowing")
            check(near(ball.vz,before.vz-9.8*dt),"wall preserves vertical velocity under gravity")
            check(near(ball.x,before.x+before.vx*dt),"lateral trajectory stays continuous at impact")
            check(near(ball.y,2*state.court.y1-before.y-before.vy*dt),"reflection consumes remaining substep without pause")
            check(near(ball.z,before.z+before.vz*dt-0.5*9.8*dt*dt),"vertical trajectory stays continuous at impact")
            return true
        end
    end
    return false
end
for _,speed in ipairs({5,9,14}) do
    for _,depth in ipairs({2,6,12,13,14}) do
        for _,side in ipairs({-1,1}) do
            local lo,hi=PTWall.localBounds(practice,depth)
            local px=side<0 and lo+0.15 or hi-0.15
            local state=PTCore.new(practice,{ballSpeed=speed})
            check(PTCore.serve(state,1,px,depth,-side),"serve accepts trapezoid side position without diagonal depth cap")
            check(checkWallReflection(state),"side serve reaches wall with continuous physical reflection")
        end
    end
end
local sideReturn=PTCore.new(practice)
sideReturn.phase,sideReturn.wallReady,sideReturn.clock="rally",true,2
sideReturn.ball={x=5.4,y=13.2,z=1.4,vx=0,vy=1,vz=0}
check(PTCore.swing(sideReturn,1,5.8,14,-1),"side ball can be returned at far trapezoid edge")
check(checkWallReflection(sideReturn),"diagonal swing from fourteen reflects without retargeting")
local outside=PTCore.new(practice)
check(not PTCore.serve(outside,1,0,14.01,0),"serve cannot extend normal depth past fourteen")
outside.phase,outside.wallReady,outside.clock="rally",true,2
outside.ball={x=6.4,y=14,z=1,vx=0,vy=1,vz=0}
check(not PTCore.swing(outside,1,6.4,14,0),"swing outside trapezoid is rejected")
local solo = new()
check(not PTCore.feedTestTarget(solo), "normal match cannot feed")
check(PTCore.enableTestTarget(solo), "tennis enables explicit target")
check(solo.testTarget.x > 4 and solo.testTarget.y == 13.5, "target starts in diagonal receiving half")
check(PTCore.feedTestTarget(solo) and solo.server == 2 and solo.servicePending, "feed uses legal slot two serve")
check(not PTCore.feedTestTarget(solo), "feed cannot interrupt rally")
local restart = new()
PTCore.enableTestTarget(restart)
check(PTCore.feedTestTarget(restart), "solo restart fixture feeds")
for i=1,1200 do PTCore.step(restart,1/120) end
check(restart.phase=="ready" and restart.server==2,"unreturned feed leaves opponent scheduled")
check(not PTCore.serve(restart,1,2,9,0) and restart.server==2,"invalid solo restart does not change scheduled server")
local restartX=(restart.points[1]+restart.points[2])%2==0 and 2 or 6
check(PTCore.serve(restart,1,restartX,0,0) and restart.server==1,"solo player can serve after opponent feed ends")
local normalRestart=new(); normalRestart.server=2
check(not PTCore.serve(normalRestart,1,2,0,0) and normalRestart.server==2,"normal match preserves opponent service turn")
for _,pending in ipairs({true,false}) do
    solo.phase,solo.servicePending,solo.lastHit,solo.clock="rally",pending,1,2
    solo.ball={x=solo.testTarget.x,y=solo.testTarget.y,z=1,vx=0,vy=0,vz=0}
    PTCore.step(solo,1/120)
    check(solo.lastHit==(pending and 1 or 2),"target respects serve bounce")
end
solo.lastHit,solo.servicePending,solo.clock=1,false,3
solo.ball={x=7.8,y=16,z=1,vx=0,vy=0,vz=0}
PTCore.step(solo,1/120)
check(solo.lastHit==1,"target cannot chase side shots")
solo.ball={x=solo.testTarget.x,y=16,z=3,vx=0,vy=0,vz=0}
PTCore.step(solo,1/120)
check(solo.lastHit==1,"target cannot hit excessive height")
solo.phase="finished"
check(not PTCore.feedTestTarget(solo),"finished game cannot feed")
local rallyTest=new()
PTCore.enableTestTarget(rallyTest)
rallyTest.phase,rallyTest.lastHit,rallyTest.clock="rally",2,1
rallyTest.ball={x=4,y=3,z=1.2,vx=0,vy=0,vz=0}
check(PTCore.swing(rallyTest,1,4,3,2/3),"player aims normal shot at fixed target")
for i=1,600 do
    PTCore.step(rallyTest,1/120)
    if rallyTest.lastHit==2 or rallyTest.phase~="rally" then break end
end
check(rallyTest.lastHit==2 and rallyTest.shotId==2,"real trajectory reaches target and returns without teleporting")

-- Live solo failure: a serve outside the baseline must stay rejected,
-- and the highlighted destination must actually accept the serve.
for slot=1,2 do
    for point=0,1 do
        local serveState=new()
        serveState.server=slot; serveState.points[1]=point
        local area=PTCore.serveArea(serveState,slot)
        local x=(area.x1+area.x2)/2
        check(not PTCore.serve(serveState,slot,x,9,0),"middle of court cannot serve")
        check(string.find(serveState.message,"green serve box",1,true),"rejection identifies visible serve destination")
        check(not serveState.ball,"rejected serve cannot create a ball")
        check(PTCore.serve(serveState,slot,x,area.baseline,0),"highlighted service box starts serve")
    end
end

-- Receive geometry follows the serving slot and total point parity.
for slot=1,2 do
    for parity=0,1 do
        local state=new(); state.points[1]=parity
        local area=PTCore.receiveArea(state,slot)
        local service=PTCore.serveArea(state,slot)
        check((area.x>4)==service.left,"receiver occupies diagonal half for each serving slot and parity")
        check(PTCore.receiverInArea(state,slot,area.x,area.y),"receive marker is a valid ready position")
        check(not PTCore.receiverInArea(state,slot,8-area.x,area.y),"other receiving half is not ready")
        check(not PTCore.receiverInArea(state,slot,area.x,9),"receiver at net is not ready")
        check(not PTCore.receiverInArea(state,slot,area.x,slot==1 and 19.51 or -1.51),"receiver behind allowed baseline margin is not ready")
    end
end
for _,length in ipairs({12,18,30}) do
    for _,speed in ipairs({6,9,14}) do
        for parity=0,1 do
            local state=PTCore.new({x1=0,x2=8,y1=0,y2=length,mode="tennis"},{ballSpeed=speed})
            state.points[1]=parity; PTCore.enableTestTarget(state)
            local area=PTCore.serveArea(state,1)
            check(PTCore.serve(state,1,(area.x1+area.x2)/2,0,0),"solo center serve launches")
            local tx,ty=state.testTarget.x,state.testTarget.y
            local returned,stationary=false,true
            for i=1,1200 do
                PTCore.step(state,1/120)
                if state.lastHit==2 then returned=true; break end
                if state.phase~="rally" then break end
                stationary=stationary and state.testTarget.x==tx and state.testTarget.y==ty
            end
            check(returned,"real center serve reaches diagonal target for both sides across supported lengths/speeds")
            check(stationary,"solo target remains fixed throughout rally")
            for i=1,1800 do PTCore.step(state,1/120) end
            area=PTCore.receiveArea(state,1)
            check(state.phase=="ready" and state.testTarget.x==area.x and state.testTarget.y==area.y,"point reset updates target to next service diagonal")
        end
    end
end

-- Bounded tennis trajectory across new sizes and legacy saved extremes.
for _,dimensions in ipairs({{8,18},{10,20},{14,30},{6,12}}) do
    local width,length=dimensions[1],dimensions[2]
    for _,speed in ipairs({5,9,14}) do
        for _,slot in ipairs({1,2}) do
            local state=PTCore.new({mode="tennis",x1=0,x2=width,y1=0,y2=length},{ballSpeed=speed})
            state.server=slot
            local area=PTCore.serveArea(state,slot)
            check(PTCore.serve(state,slot,(area.x1+area.x2)/2,area.baseline,0),"bounded flight starts from either end")
            local peak,rebound,window,firstTime,firstY=0,0,0,nil,nil
            local receive=PTCore.receiveArea(state,slot)
            for i=1,1200 do
                PTCore.step(state,1/120)
                local ball=state.ball
                if not ball then break end
                if state.bounces==0 then peak=math.max(peak,ball.z)
                else
                    rebound=math.max(rebound,ball.z)
                    if not firstTime then firstTime,firstY=state.clock,ball.y end
                    if ball.z>=0.15 and ball.z<=2.4 then window=window+1/120 end
                end
            end
            check(firstTime~=nil,"bounded serve lands legally")
            check(peak<=2.401,"tennis flight apex stays at or below racket maximum")
            check(rebound<=1.101,"tennis rebound is capped at 1.1 height")
            check(window>=0.85,"bounce allows at least .85 seconds in legal racket height")
            check(math.abs(math.abs(firstY-length/2)-length*.16)<0.01,"serve marker is first ground contact")
            if slot==2 and speed==9 then
                print("PHYSICS "..width.."x"..length.." feed: apex="..peak.." bouncePeak="..rebound.." firstBounceSeconds="..firstTime.." heightWindow="..window)
            end
            state=PTCore.new({mode="tennis",x1=0,x2=width,y1=0,y2=length},{ballSpeed=speed})
            state.phase,state.lastHit,state.clock="rally",3-slot,1
            local y=slot==1 and 1 or length-1
            state.ball={x=width/2,y=y,z=1.2,vx=0,vy=0,vz=0}
            local tx,ty=PTCore.aimTarget(state,slot,0,false)
            check(math.abs(math.abs(ty-length/2)/(length/2)-.45)<.00001,"rally first landing is45 percent into opposing half")
            check(PTCore.swing(state,slot,width/2,y,0),"bounded baseline rally launches")
            local landed=false
            for i=1,600 do
                PTCore.step(state,1/120)
                if not state.ball then break end
                if state.bounces==1 then
                    landed=true
                    check(math.abs(state.ball.y-ty)<.01 and math.abs(state.ball.x-tx)<.01,"rally marker agrees with actual first bounce")
                    break
                end
            end
            check(landed,"early rally bounce clears net and remains in opposing half")
        end
    end
end
local scoreOnly=new({gamesToWin=6})
for i=1,4 do winPoint(scoreOnly,1) end
check(scoreOnly.phase=="finished" and scoreOnly.winner==1,"legacy games-to-win option cannot extend victory")
check(scoreOnly.games==nil and scoreOnly.options.gamesToWin==nil,"no aggregate games state")
-- Extreme aim shots remain reachable after their legal first bounce; an
-- eventual second bounce outside the court is a valid unreturned winner.
for _,dimensions in ipairs({{8,18},{10,20},{14,30}}) do
    local width,length=dimensions[1],dimensions[2]
    for _,aim in ipairs({-1,0,1}) do
        for _,speed in ipairs({5,9,14}) do
            local state=PTCore.new({mode="tennis",x1=0,x2=width,y1=0,y2=length},{ballSpeed=speed})
            state.phase,state.lastHit,state.clock="rally",2,1
            state.ball={x=width*(aim<0 and .8 or .2),y=1,z=1.2,vx=0,vy=0,vz=0}
            check(PTCore.swing(state,1,state.ball.x,state.ball.y,aim),"crosscourt extreme shot launches")
            local reachable=0
            for i=1,900 do
                PTCore.step(state,1/120)
                local b=state.ball
                if not b then break end
                if state.bounces==1 and b.z>=.15 and b.z<=2.4 and b.x>=-1.8 and b.x<=width+1.8
                    and b.y>=length/2 and b.y<=length+1.8 then reachable=reachable+1/120 end
            end
            check(reachable>=.6,"extreme diagonal leaves at least .6 seconds inside court plus racket reach")
        end
    end
    local feed=PTCore.new({mode="tennis",x1=0,x2=width,y1=0,y2=length})
    PTCore.enableTestTarget(feed); PTCore.feedTestTarget(feed)
    local receive=PTCore.receiveArea(feed,2)
    local returned=false
    for i=1,600 do
        PTCore.step(feed,1/120)
        local b=feed.ball
        if not b then break end
        if not feed.servicePending and b.z>=.15 and b.z<=2.4
            and (receive.x-b.x)^2+(receive.y-b.y)^2<=feed.options.hitRadius^2 then
            returned=PTCore.swing(feed,1,receive.x,receive.y,0);break
        end
    end
    check(returned,"opposite serve can actually be returned at receiving marker including legacy maximum")
end
for _,height in ipairs({.15,.5,1.2,2.4}) do
    for _,y in ipairs({.1,8,8.99}) do
        local state=new()
        state.phase,state.lastHit,state.clock="rally",2,1
        state.ball={x=4,y=y,z=height,vx=0,vy=0,vz=0}
        check(PTCore.swing(state,1,4,y,1),"near net and baseline contact accepted")
        local b=state.ball
        local apex=b.z+math.max(0,b.vz)^2/(2*9.8)
        check(apex<=2.400001,"net clearance cannot override the trajectory height cap")
    end
end
