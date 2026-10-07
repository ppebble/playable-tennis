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
check(s.points[1] == 3 and s.points[2] == 3 and s.games[1] == 0, "deuce")
winPoint(s, 1)
check(s.games[1] == 0 and s.points[1] == 4, "advantage is not a game")
winPoint(s, 2)
check(s.games[1] == 0 and s.points[1] == s.points[2], "return to deuce")
winPoint(s, 1); winPoint(s, 1)
check(s.games[1] == 1 and s.server == 2 and s.points[1] == 0, "game resets points and switches server")
check(s.phase == "finished" and s.winner == 1, "first-to-one match completes")
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
                    expectedY = 9 + (slot == 1 and 1 or -1) * 18 * 0.32
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
check(solo.testTarget.x < 4 and solo.testTarget.y == 16, "target far left fixed position")
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
check(PTCore.swing(rallyTest,1,4,3,-2/3),"player aims normal shot at fixed target")
for i=1,600 do
    PTCore.step(rallyTest,1/120)
    if rallyTest.lastHit==2 or rallyTest.phase~="rally" then break end
end
check(rallyTest.lastHit==2 and rallyTest.shotId==2,"real trajectory reaches target and returns without teleporting")
