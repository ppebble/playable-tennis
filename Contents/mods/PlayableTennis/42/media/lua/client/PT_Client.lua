-- Owned prototype UI. The server alone decides contact, movement and scores.
require "ISUI/ISPanel"
require "ISUI/ISContextMenu"

PTClient = { courts = {}, seq = 0, revision = -1, retired = {}, lastSync = 0 }
local C = PTClient
local function now() return getTimestampMs() end
local function notice(message)
    C.message = tostring(message or "")
    C.messageUntil = now() + 7000
end
local function player() return getSpecificPlayer(0) end
local function send(command, args)
    local p = player()
    if not p then return end
    args = args or {}
    if isClient() then
        sendClientCommand(p, "PlayableTennis", command, args)
    elseif PTServer then
        PTServer.dispatch(p, command, args)
    else
        notice("Tennis server module unavailable.")
    end
end
local function sync()
    C.lastSync = now()
    send("sync", {})
end
local function leave()
    if C.session then C.retired[C.session] = true end
    C.session, C.core, C.previousBall = nil, nil, nil
    C.joinPending = false
    send("leave", {})
end
local function join(id)
    C.joinPending = true
    send("join", { id = id })
end
local function removeCourt(id) send("remove", { id = id }) end
function C.receive(command, args)
    args = args or {}
    if command == "list" then
        C.courts = args.courts or {}
    elseif command == "error" then
        notice(args.message)
    elseif command == "left" then
        if args.session and C.session and args.session ~= C.session then return end
        if C.session then C.retired[C.session] = true end
        C.session, C.core, C.previousBall = nil, nil, nil
        C.joinPending = false
        notice(args.message or "Left court.")
    elseif command == "state" and args.core and args.session then
        if C.retired[args.session] then return end
        if C.session and C.session ~= args.session and not C.joinPending then return end
        local revision = tonumber(args.revision) or 0
        if C.session == args.session and revision <= C.revision then return end
        local old = C.core
        local sameSession = C.session == args.session
        if sameSession and old and old.shotId and args.core.shotId
            and args.core.shotId > old.shotId then
            getSoundManager():playUISound("TennisRacketHit")
        end
        if not sameSession then
            if C.session then C.retired[C.session] = true end
            C.seq, C.revision, C.previousBall = 0, -1, nil
        elseif C.core and C.core.phase == "rally" and args.core.phase == "rally"
            and C.core.shotId == args.core.shotId
            and C.core.bounces == args.core.bounces
            and C.core.wallReady == args.core.wallReady then
            C.previousBall = C.core.ball
        else
            C.previousBall = nil
        end
        C.session, C.slot, C.core = args.session, args.slot, args.core
        C.waiting, C.names = args.waiting, args.players
        C.seq = math.max(C.seq, tonumber(args.lastSeq) or 0)
        C.revision, C.receivedAt, C.joinPending = revision, now(), false
    end
end
local function inputBlocked()
    return getCore():isDoingTextEntry()
end
local function aim()
    if isKeyDown(Keyboard.KEY_LEFT) then return -1 end
    if isKeyDown(Keyboard.KEY_RIGHT) then return 1 end
    return 0
end
local function input(command)
    if not C.session or inputBlocked() then return end
    if now() - (C.receivedAt or 0) > 3000 then
        notice("Waiting for server state; syncing...")
        if now() - C.lastSync > 2000 then sync() end
        return
    end
    C.seq = C.seq + 1
    C.flashUntil = now() + 180
    send(command, { aim = aim(), seq = C.seq, session = C.session })
end
local function keyPressed(key)
    if key == Keyboard.KEY_J then input("swing") end
    if key == Keyboard.KEY_K then input("serve") end
end
local function mark(square, corner)
    C.draft = C.draft or {}
    C.draft[corner] = { x = square:getX(), y = square:getY(), z = square:getZ() }
    notice("Marked corner " .. corner .. " at " .. square:getX() .. ", " .. square:getY())
end
local function register(mode)
    local a, b = C.draft[1], C.draft[2]
    if a.z ~= b.z then notice("Corners must be on the same floor."); return end
    send("create", { x1 = math.min(a.x,b.x), y1 = math.min(a.y,b.y),
        x2 = math.max(a.x,b.x), y2 = math.max(a.y,b.y), z = a.z, mode = mode })
    sync()
end
local function contextMenu(playerIndex, context, objects, test)
    -- One keyboard and HUD owner per client; split-screen is outside this prototype.
    if playerIndex ~= 0 then return end
    if test then return end
    local p = player()
    if not p then return end
    local square
    for _, object in ipairs(objects) do
        if object.getSquare then square = object:getSquare(); if square then break end end
    end
    local locationLabel = square and "clicked tile" or "current feet (empty click)"
    square = square or p:getSquare()
    if not square then return end
    local root = context:addOption("Playable Tennis")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    menu:addOption("Mark corner 1 (" .. locationLabel .. ")", square, mark, 1)
    menu:addOption("Mark corner 2 (" .. locationLabel .. ")", square, mark, 2)
    if C.draft and C.draft[1] and C.draft[2] then
        menu:addOption("Register 1v1 court", "tennis", register)
        menu:addOption("Register wall court (wall on north edge)", "wall", register)
    end
    menu:addOption("Refresh court list / synchronize", nil, sync)
    local count = 0
    for _, court in pairs(C.courts) do
        if court.id and court.x1 and court.y1 and court.z == math.floor(p:getZ())
            and math.abs(p:getX() - court.x1) < 100 and math.abs(p:getY() - court.y1) < 100 then
            menu:addOption("Join " .. tostring(court.id) .. " (" .. tostring(court.mode) .. ")", court.id, join)
            menu:addOption("Remove " .. tostring(court.id) .. " (owner/admin, idle)", court.id, removeCourt)
            count = count + 1
            if count >= 20 then break end
        end
    end
    if C.session then
        menu:addOption("Serve [K]", "serve", input)
        menu:addOption("Swing [J]", "swing", input)
        menu:addOption("Leave court", nil, leave)
    end
    if now() - C.lastSync > 2000 then sync() end
end
local Overlay = ISPanel:derive("PT_Overlay")
local function score(core)
    local a,b = core.points[1],core.points[2]
    if a >= 3 and b >= 3 then
        if a == b then return "Deuce" end
        return a > b and "AD : 40" or "40 : AD"
    end
    local labels = {"0","15","30","40"}
    return labels[math.min(a,3)+1] .. " : " .. labels[math.min(b,3)+1]
end
local function project(x, y, z)
    return isoToScreenX(0, x, y, z), isoToScreenY(0, x, y, z)
end
function Overlay:worldLine(x1,y1,x2,y2,z,r,g,b)
    local ax,ay = project(x1,y1,z)
    local bx,by = project(x2,y2,z)
    self:drawLine2(ax,ay,bx,by,0.85,r,g,b)
end
function Overlay:render()
    local core = C.core
    if core and player() then
        local court = core.court
        local x1,y1,x2,y2,z = court.x1,court.y1,court.x2,court.y2,court.z
        if math.floor(player():getZ()) == z then
            local mx,my = (x1+x2)/2,(y1+y2)/2
            self:worldLine(x1,y1,x2,y1,z,1,1,1)
            self:worldLine(x2,y1,x2,y2,z,1,1,1)
            self:worldLine(x2,y2,x1,y2,z,1,1,1)
            self:worldLine(x1,y2,x1,y1,z,1,1,1)
            if court.mode == "tennis" then
                self:worldLine(x1,my,x2,my,z,0.3,0.8,1)
                self:worldLine(x1,(y1+my)/2,x2,(y1+my)/2,z,1,1,1)
                self:worldLine(x1,(y2+my)/2,x2,(y2+my)/2,z,1,1,1)
                self:worldLine(mx,(y1+my)/2,mx,(y2+my)/2,z,1,1,1)
            else
                self:worldLine(x1,y1,x2,y1,z+0.4,0.3,0.8,1)
            end
            local ball = core.ball
            if ball then
                local bx,by,bz = ball.x,ball.y,ball.z
                local old = C.previousBall
                if old then
                    local t = math.min(1, math.max(0, (now() - C.receivedAt)/100))
                    bx,by,bz = old.x+(bx-old.x)*t,old.y+(by-old.y)*t,old.z+(bz-old.z)*t
                end
                local sx,sy = project(bx,by,z)
                self:drawRect(sx-4,sy-2,8,4,0.5,0,0,0)
                -- Physics height is metres; one rendered storey is approximately 3 m.
                local px,py = project(bx,by,z+math.max(0,bz)/3)
                self:drawRect(px-3,py-3,6,6,1,0.9,1,0.15)
            end
        end
        local x,y = 24,160
        self:drawRect(x,y,490,170,0.83,0.04,0.06,0.07)
        local function line(text,row,r,g,b)
            self:drawText(text,x+10,y+8+row*21,r or 1,g or 1,b or 1,1,UIFont.Small)
        end
        line("Playable Tennis | " .. court.mode .. " | Slot " .. tostring(C.slot),0)
        line("Games " .. core.games[1] .. " : " .. core.games[2] .. "    " .. score(core) .. "    " .. core.phase,1)
        if court.mode == "wall" then
            line("Rally " .. tostring(core.rally) .. " | Best " .. tostring(core.bestRally),2)
        else
            line("Server: slot " .. tostring(core.server) .. " | You: " .. (C.slot == 1 and "north" or "south"),2)
        end
        line("J swing | K serve | Hold left/right arrow to aim",3)
        local even = (core.points[1] + core.points[2]) % 2 == 0
        local left = (core.server == 1 and even) or (core.server == 2 and not even)
        local side = left and "west (lower X)" or "east (higher X)"
        line(court.mode == "wall" and "Serve near south baseline; return after wall rebound."
            or "Serve near baseline, " .. side .. " half.",4)
        line(tostring(C.waiting and "Waiting for opponent" or core.message or ""),5,0.7,0.9,1)
        line("Right-click > Playable Tennis: courts / leave / sync",6)
        if now() < (C.flashUntil or 0) then
            self:drawRect(x+470,y+10,10,10,1,1,0.8,0.2)
        end
    end
    if now() < (C.messageUntil or 0) then
        self:drawRect(24,335,640,30,0.85,0.05,0.05,0.05)
        self:drawText(C.message,34,341,1,0.85,0.4,1,UIFont.Small)
    end
end
local function tick()
    if C.overlay then
        local w,h = getCore():getScreenWidth(),getCore():getScreenHeight()
        if C.overlay.width ~= w then C.overlay:setWidth(w) end
        if C.overlay.height ~= h then C.overlay:setHeight(h) end
    end
    if C.session and now() - C.lastSync > 5000 and now() - (C.receivedAt or 0) > 1500 then sync() end
end
local function start()
    if C.overlay then C.overlay:removeFromUIManager() end
    C.session, C.core, C.previousBall, C.draft = nil, nil, nil, nil
    C.retired, C.courts, C.seq, C.revision = {}, {}, 0, -1
    C.overlay = Overlay:new(0,0,getCore():getScreenWidth(),getCore():getScreenHeight())
    C.overlay:initialise()
    C.overlay:instantiate()
    C.overlay.background = false
    C.overlay:setWantMouseEvents(false)
    C.overlay:addToUIManager()
    sync()
end
Events.OnServerCommand.Add(function(module,command,args)
    if module == "PlayableTennis" then C.receive(command,args) end
end)
Events.OnFillWorldObjectContextMenu.Add(contextMenu)
Events.OnKeyPressed.Add(keyPressed)
Events.OnGameStart.Add(start)
Events.OnTick.Add(tick)
