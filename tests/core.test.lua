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
check(not PTCore.serve(s, 1, 2, 0, 2), "aim must be discrete")
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
