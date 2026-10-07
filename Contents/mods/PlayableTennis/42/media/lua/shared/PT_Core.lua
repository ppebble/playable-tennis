-- Pure Lua 5.1 / Kahlua simulation. The server alone advances this state.
PTCore = {}
local STEP, GRAVITY, NET_HEIGHT = 1 / 120, 9.8, 0.91
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
local function finite(v) return type(v) == "number" and v == v and v > -math.huge and v < math.huge end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function reject(s, message) s.message = message; return false end
local function midX(s) return (s.court.x1 + s.court.x2) / 2 end
local function midY(s) return (s.court.y1 + s.court.y2) / 2 end
local function validSlot(slot) return slot == 1 or slot == 2 end
local function validAim(aim) return finite(aim) and aim >= -1 and aim <= 1 end
local function inside(s, x, y)
    local c = s.court
    return x >= c.x1 and x <= c.x2 and y >= c.y1 and y <= c.y2
end
local function onSide(s, slot, y)
    if s.court.mode == "wall" then return slot == 1 and y > s.court.y1 end
    return (slot == 1 and y < midY(s)) or (slot == 2 and y > midY(s))
end
local function resetBall(s, message)
    s.phase, s.ball, s.bounces = "ready", nil, 0
    s.servicePending, s.wallReady = false, false
    s.rally = 0
    s.message = message
end
local function point(s, winner, reason)
    s.points[winner] = s.points[winner] + 1
    local other = 3 - winner
    local message = reason .. " Point: player " .. winner .. "."
    if s.points[winner] >= 4 and s.points[winner] - s.points[other] >= 2 then
        s.games[winner] = s.games[winner] + 1
        s.points = {0, 0}
        s.server = 3 - s.server
        message = reason .. " Game: player " .. winner .. "."
    end
    s.faults = 0
    resetBall(s, message)
    if s.games[winner] >= s.options.gamesToWin then
        s.phase, s.winner = "finished", winner
        s.message = "Match won by player " .. winner .. "."
    end
end
local function failShot(s, reason)
    if s.court.mode == "wall" then
        resetBall(s, reason .. " Practice ready; best " .. s.bestRally .. ".")
    elseif s.servicePending then
        s.faults = s.faults + 1
        if s.faults >= 2 then point(s, 3 - s.server, "Double fault: " .. reason)
        else resetBall(s, "First fault: " .. reason .. " Serve again.") end
    else
        point(s, 3 - s.lastHit, reason)
    end
end
local function landing(s)
    local b, c = s.ball, s.court
    if s.bounces >= 1 then
        if c.mode == "wall" then failShot(s, "Two bounces.")
        else point(s, s.lastHit, "Two bounces.") end
        return
    end
    if not c.freeWall and not inside(s, b.x, b.y) then failShot(s, "Out."); return end
    if s.court.mode == "wall" then
        if not s.wallReady then failShot(s, "Ball bounced before reaching the wall."); return end
    elseif s.servicePending then
        local expected = 3 - s.server
        local validY = onSide(s, expected, b.y) and math.abs(b.y - midY(s)) <= (c.y2 - c.y1) / 4
        local validX = (s.serveFromLeft and b.x >= midX(s)) or (not s.serveFromLeft and b.x <= midX(s))
        if not validY or not validX then failShot(s, "Serve missed the diagonal service box."); return end
        s.servicePending = false
    elseif s.bounces == 0 and onSide(s, s.lastHit, b.y) then
        failShot(s, "Ball landed on the hitter's side."); return
    end
    s.bounces = s.bounces + 1
    b.z = 0
    b.vz = math.max(2.5, -b.vz * 0.78)
end
local function integrate(s, dt)
    local b, c = s.ball, s.court
    if not b then return end
    local ox, oy, oz = b.x, b.y, b.z
    b.x = b.x + b.vx * dt
    b.y = b.y + b.vy * dt
    b.z = b.z + b.vz * dt - 0.5 * GRAVITY * dt * dt
    b.vz = b.vz - GRAVITY * dt
    if c.mode == "wall" then
        if oy >= c.y1 and b.y < c.y1 then
            local fraction = (oy - c.y1) / (oy - b.y)
            local wallZ = oz + (b.z - oz) * fraction
            local wallX = ox + (b.x - ox) * fraction
            if wallX < (c.wallMinX or c.x1) or wallX > (c.wallMaxX or c.x2) or wallZ <= 0 or wallZ > 2.8 then
                failShot(s, "Missed the wall (height 0 to 2.8)."); return
            end
            -- Reflect only the wall-normal velocity. Preserve lateral speed
            -- and the gravity arc instead of retargeting the return landing.
            b.y, b.vy = c.y1 + (c.y1 - b.y), -b.vy
            s.wallReady, s.bounces = true, 0
            s.rally = s.rally + 1
            s.bestRally = math.max(s.bestRally, s.rally)
            s.message = "Wall return: " .. s.rally .. "."
        end
    elseif (oy < midY(s) and b.y >= midY(s)) or (oy > midY(s) and b.y <= midY(s)) then
        local fraction = (midY(s) - oy) / (b.y - oy)
        local netZ = oz + (b.z - oz) * fraction
        if netZ <= NET_HEIGHT then failShot(s, "Net."); return end
    end
    if b.z <= 0 then
        -- Score at the contact point, not the end of a substep beyond the line.
        local fraction = oz / math.max(0.000001, oz - b.z)
        b.x, b.y = ox + (b.x - ox) * fraction, oy + (b.y - oy) * fraction
        landing(s)
    end
    if s.ball and (b.x < c.x1 - 8 or b.x > c.x2 + 8 or b.y < c.y1 - 8 or b.y > c.y2 + 8) then
        if c.mode ~= "wall" and s.bounces >= 1 then point(s, s.lastHit, "Unreturned ball left the play area.")
        else failShot(s, "Ball left the play area.") end
    end
end
local function launch(s, x, y, z, tx, ty, wall)
    local dx, dy = tx - x, ty - y
    local duration = math.sqrt(dx * dx + dy * dy) / s.options.ballSpeed
    duration = math.max(0.4, duration)
    local targetZ = wall and 1.2 or 0
    if not wall and dy ~= 0 then
        local fraction = (midY(s) - y) / dy
        if fraction > 0 and fraction < 1 then
            -- Speed is a target: add loft where a short court otherwise forces
            -- every automatically aimed serve into the net at high settings.
            local need = NET_HEIGHT + 0.2 - z * (1 - fraction)
            if need > 0 then
                duration = math.max(duration, math.sqrt(2 * need / (GRAVITY * fraction * (1 - fraction))))
            end
        end
    end
    s.ball = {x = x, y = y, z = z, vx = dx / duration, vy = dy / duration,
        vz = (targetZ - z + 0.5 * GRAVITY * duration * duration) / duration}
end
function PTCore.new(court, options)
    options = options or {}
    local function option(name, default, lo, hi)
        local v = options[name]
        return finite(v) and clamp(v, lo, hi) or default
    end
    return {court = copy(court), options = {gamesToWin = math.floor(option("gamesToWin", 2, 1, 6)),
        ballSpeed = option("ballSpeed", 9, 5, 14), hitRadius = option("hitRadius", 1.8, 0.75, 3)},
        phase = "ready", server = 1, points = {0, 0}, games = {0, 0}, winner = 0,
        ball = nil, lastHit = 0, shotId = 0, bounces = 0, faults = 0, rally = 0, bestRally = 0,
        clock = 0, accumulator = 0, lastSwing = {-100, -100},
        message = "Ready. Serve from your baseline and the indicated service side."}
end
-- Shared target calculation for authoritative shots and client aim previews.
function PTCore.aimTarget(s, slot, aim, serving)
    if type(s) ~= "table" or type(s.court) ~= "table" or not validSlot(slot)
        or not validAim(aim) or type(serving) ~= "boolean" then return nil end
    local c = s.court
    if not finite(c.x1) or not finite(c.x2) or not finite(c.y1) or not finite(c.y2)
        or c.x2 <= c.x1 or c.y2 <= c.y1 or (c.mode ~= "wall" and c.mode ~= "tennis") then return nil end
    local width, length = c.x2 - c.x1, c.y2 - c.y1
    if c.mode == "wall" then
        if c.freeWall then
            local lo,hi=c.wallMinX,c.wallMaxX
            return (lo+hi)/2 + aim*(hi-lo)*0.35,c.y1
        end
        return midX(s) + aim * width * (serving and 0.18 or 0.3), c.y1
    end
    if serving then
        if type(s.points) ~= "table" or not finite(s.points[1]) or not finite(s.points[2]) then return nil end
        local even = (s.points[1] + s.points[2]) % 2 == 0
        local fromLeft = (slot == 1 and even) or (slot == 2 and not even)
        return midX(s) + (fromLeft and 1 or -1) * width * 0.25 + aim * width * 0.1,
            midY(s) + (slot == 1 and 1 or -1) * length * 0.16
    end
    return midX(s) + aim * width * 0.3,
        midY(s) + (slot == 1 and 1 or -1) * length * 0.32
end
function PTCore.serve(s, slot, px, py, aim)
    if not validSlot(slot) or not finite(px) or not finite(py) or not validAim(aim) then return reject(s, "Invalid serve input.") end
    if s.phase ~= "ready" then return reject(s, "Wait until ready to serve.") end
    if slot ~= s.server then return reject(s, "The other player serves.") end
    local c, wall = s.court, s.court.mode == "wall"
    local baseline = (wall or slot == 2) and c.y2 or c.y1
    if c.freeWall then baseline=py end
    if c.freeWall then
        if not PTWall.containsLocal(c, px, py, 0) or py < c.y1 + 1 then
            return reject(s, "Stand inside the wall practice area, 1 to 14 tiles from the wall.")
        end
    elseif px < c.x1 + 0.2 or px > c.x2 - 0.2 or math.abs(py - baseline) > 1.5 then
        return reject(s, "Stand within 1.5 tiles of your baseline, inside the court width.")
    end
    local even = (s.points[1] + s.points[2]) % 2 == 0
    local fromLeft = (slot == 1 and even) or (slot == 2 and not even)
    if not wall and ((fromLeft and px >= midX(s) - 0.1) or (not fromLeft and px <= midX(s) + 0.1)) then
        return reject(s, fromLeft and "Serve from the left half of your baseline." or "Serve from the right half of your baseline.")
    end
    local tx, ty = PTCore.aimTarget(s, slot, aim, true)
    launch(s, px, baseline + ((wall or slot == 2) and -0.1 or 0.1), 1.4, tx, ty, wall)
    s.phase, s.lastHit, s.bounces = "rally", slot, 0
    s.servicePending, s.serveFromLeft, s.wallReady = not wall, fromLeft, false
    s.lastSwing[slot], s.rally = s.clock, 0
    s.shotId = s.shotId + 1
    s.message = wall and "Practice started. Return after the wall contact." or "Serve in flight; receiver must allow the first bounce."
    return true
end
function PTCore.swing(s, slot, px, py, aim)
    if not validSlot(slot) or not finite(px) or not finite(py) or not validAim(aim) then return reject(s, "Invalid swing input.") end
    if s.phase ~= "rally" or not s.ball then return reject(s, "No ball in play.") end
    local b, c, wall = s.ball, s.court, s.court.mode == "wall"
    if s.clock - s.lastSwing[slot] < 0.25 then return reject(s, "Swing cooldown.") end
    -- A mistimed attempt also costs a swing, preventing repeated probing hits.
    s.lastSwing[slot] = s.clock
    if not onSide(s, slot, py) or not onSide(s, slot, b.y) then return reject(s, "Hit on your own side of the net.") end
    if wall then
        if not s.wallReady then return reject(s, "Wait for the wall return.") end
    else
        if slot == s.lastHit then return reject(s, "Wait for the opponent's return.") end
        if s.servicePending then return reject(s, "Let the serve bounce first.") end
    end
    if b.z < 0.15 or b.z > 2.4 then return reject(s, "Ball is outside racket height (0.15 to 2.4).") end
    if (px - b.x) ^ 2 + (py - b.y) ^ 2 > s.options.hitRadius ^ 2 then return reject(s, "Ball is out of reach.") end
    if c.freeWall then
        if not PTWall.containsLocal(c, px, py, 0) then return reject(s, "Return to the wall practice area.") end
    elseif px < c.x1 - 2 or px > c.x2 + 2 or py < c.y1 - 2 or py > c.y2 + 2 then return reject(s, "Return to the court.") end
    local tx, ty = PTCore.aimTarget(s, slot, aim, false)
    launch(s, b.x, b.y, b.z, tx, ty, wall)
    s.lastHit, s.bounces, s.wallReady = slot, 0, false
    s.lastSwing[slot] = s.clock
    if not wall then s.rally = s.rally + 1; s.bestRally = math.max(s.bestRally, s.rally) end
    s.shotId = s.shotId + 1
    s.message = "Return hit."
    return true
end
-- Explicit test fixture, never enabled by normal match creation.
function PTCore.enableTestTarget(s)
    if s.court.mode ~= "tennis" or s.phase ~= "ready" then return false end
    local c = s.court
    s.testTarget = {x = midX(s) - (c.x2-c.x1)*0.2, y = c.y2-2, radius = s.options.hitRadius}
    return true
end
function PTCore.feedTestTarget(s)
    if not s.testTarget or s.phase ~= "ready" then return false end
    -- A deliberate test-only feed may substitute the scheduled server.
    s.server = 2
    s.faults = 0
    local even = (s.points[1]+s.points[2])%2 == 0
    local x = midX(s)+(even and 1 or -1)*(s.court.x2-s.court.x1)*0.25
    return PTCore.serve(s,2,x,s.court.y2,0)
end
local function returnFromTestTarget(s)
    local target,b = s.testTarget,s.ball
    if not target or not b or s.phase ~= "rally" or s.lastHit ~= 1 or s.servicePending then return end
    if b.y <= midY(s) or b.z < 0.15 or b.z > 2.4 or s.clock-s.lastSwing[2] < 0.25 then return end
    if (target.x-b.x)^2+(target.y-b.y)^2 > s.options.hitRadius^2 then return end
    PTCore.swing(s,2,target.x,target.y,0)
end
function PTCore.step(s, dt)
    if not finite(dt) or dt <= 0 then return end
    -- Avoid an unbounded catch-up loop after stalls; server publishes fresh state.
    s.accumulator = s.accumulator + math.min(dt, 0.25)
    while s.accumulator + 0.000000001 >= STEP do
        s.accumulator = s.accumulator - STEP
        s.clock = s.clock + STEP
        if s.phase == "rally" then integrate(s, STEP); returnFromTestTarget(s) end
    end
end
function PTCore.snapshot(s) return copy(s) end
return PTCore
