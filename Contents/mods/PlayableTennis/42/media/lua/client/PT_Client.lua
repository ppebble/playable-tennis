-- Tennis UI. The server alone decides contact, movement and scores.
require "ISUI/ISPanel"
require "ISUI/ISContextMenu"
require "PT_Core"
require "PT_Wall"
require "PT_Swing"
require "PT_CourtSelector"

PTClient = { courts = {}, seq = 0, revision = -1, retired = {}, lastSync = 0 }
local C = PTClient
local function now() return getTimestampMs() end
local function notice(message)
    C.message = tostring(message or "")
    C.messageUntil = now() + 7000
end
local function player() return getSpecificPlayer(0) end
local function swingAnimation()
    local ok,_,reason=pcall(PTSwing.play,player(),now())
    if not ok then
        print("[PlayableTennis] cosmetic swing failed: "..tostring(_))
        notice("Swing animation failed; tennis input is still sent. See the game log.")
        return
    end
    if reason=="busy" then notice("Swing animation unavailable while another action is in progress.") end
end
local function holdsSports(p)
    local item=p and p:getPrimaryHandItem()
    return item and item:getFullType()=="PlayableTennis.SportsTennisRacket"
end
local function equippedToStart(p)
    if not p or p:isDead() or p:getVehicle() or not holdsSports(p) then return false end
    local ball=p:getSecondaryHandItem()
    return p:getPrimaryHandItem():getCondition()>0 and ball and ball:getFullType()=="Base.TennisBall"
end
local function mouseEligible(p)
    if not p or not C.session or not C.core then return false end
    if C.waiting then return false,"Waiting for opponent." end
    if C.core.paused then return false,C.core.message or "Game paused. Both players must return with their rackets." end
    if C.core.phase=="finished" then return false,"Game finished. Use the court menu to join or start again." end
    if p:isDead() or p:getVehicle() then return false,"Stay alive and on foot to play tennis." end
    local c=C.core.court
    if p:getZ()~=c.z or not PTWall.contains(c,p:getX(),p:getY(),2) then return false,"Return to the court and its floor to play tennis." end
    local item=p:getPrimaryHandItem()
    if not holdsSports(p) or item:getCondition()<=0 then return false,"Equip an intact SPORTS Tennis Racket in your primary hand." end
    return true
end
local function releaseGuard(force)
    local guard=C.attackGuard
    if guard and (force or (not holdsSports(guard.player) and not isMouseButtonDown(0) and not isMouseButtonDown(1))) then
        guard.player:setBannedAttacking(guard.previous)
        C.attackGuard=nil
    end
end
local function updateGuard(p)
    if C.attackGuard and C.attackGuard.player~=p then releaseGuard(true) end
    -- A sports racket never enables combat, even outside a court or while waiting.
    if p and not p:isDead() and holdsSports(p) then
        if not C.attackGuard then C.attackGuard={player=p,previous=p:isBannedAttacking()} end
        p:setBannedAttacking(true)
    elseif C.attackGuard then
        -- Drain a held click before restoring combat, so ending/leaving a match
        -- cannot turn the same tennis click into a delayed vanilla attack.
        if not p or p:isDead() then releaseGuard(true)
        else releaseGuard(false) end
        if C.attackGuard then C.attackGuard.player:setBannedAttacking(true) end
    end
end
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
    C.session, C.core, C.previousBall, C.ballSamples = nil, nil, nil, nil
    releaseGuard(false)
    C.joinPending = false
    send("leave", {})
end
local function join(id)
    C.joinPending = true
    send("join", { id = id })
end
local function removeCourt(id) send("remove", { id = id }) end
local function canStartPractice()
    return not C.session or (C.core and C.core.phase=="finished")
end
local function startWallAt(args)
    if not canStartPractice() then notice("Leave your current match/practice first."); return end
    if not equippedToStart(player()) then notice("Hold a sports racket in your primary hand and Tennis Ball in your secondary hand."); return end
    if now()<(C.wallPendingUntil or 0) then return end
    C.wallPendingUntil=now()+500
    C.joinPending=true
    swingAnimation()
    send("startWall",args)
end
function C.receive(command, args)
    args = args or {}
    if command == "list" then
        C.courts = args.courts or {}
    elseif command == "error" then
        C.joinPending=false
        notice(args.message)
    elseif command == "created" then
        notice("Court "..tostring(args.id).." registered. Right-click > Playable Tennis > Join.")
    elseif command == "left" then
        if args.session and C.session and args.session ~= C.session then return end
        if C.session then C.retired[C.session] = true end
        C.session, C.core, C.previousBall, C.ballSamples = nil, nil, nil, nil
        releaseGuard(false)
        C.joinPending = false
        notice(args.message or "Left court.")
    elseif command == "state" and args.core and args.session then
        if C.suspended then return end
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
            and C.core.shotId == args.core.shotId then
            C.previousBall = C.core.ball
        else
            C.previousBall = nil
        end
        -- Simulation timestamps keep arrival jitter from restarting a segment.
        local stamp=tonumber(args.core.clock) or revision*0.1
        local samples=C.ballSamples
        if not C.previousBall or not samples or not samples[1] or stamp<samples[#samples].time then
            samples={}
            C.ballAnchorTime,C.ballAnchorAt,C.ballRenderTime=stamp,now(),nil
        end
        if args.core.ball then
            local sample={time=stamp,ball=args.core.ball,bounces=args.core.bounces or 0}
            if samples[#samples] and samples[#samples].time==stamp then samples[#samples]=sample
            else samples[#samples+1]=sample end
            while #samples>8 do table.remove(samples,1) end
            -- Recover the clock mapping after a simulation pause/network stall.
            if C.ballAnchorTime+(now()-C.ballAnchorAt)/1000-stamp>0.3 then
                C.ballAnchorTime,C.ballAnchorAt=stamp,now()
            end
        else samples={} end
        C.ballSamples=samples
        C.session, C.slot, C.core = args.session, args.slot, args.core
        C.waiting, C.names = args.waiting, args.players
        C.seq = math.max(C.seq, tonumber(args.lastSeq) or 0)
        C.revision, C.receivedAt, C.joinPending = revision, now(), false
    end
end
local function inputBlocked()
    return getCore():isDoingTextEntry() or PTCourtSelector.blocksInput()
end
local function aim()
    if isKeyDown(Keyboard.KEY_LEFT) then return -1 end
    if isKeyDown(Keyboard.KEY_RIGHT) then return 1 end
    return 0
end
local function mouseAim()
    local c=C.core.court
    local x=screenToIsoX(0,getMouseX(),getMouseY(),c.z)
    local y=screenToIsoY(0,getMouseX(),getMouseY(),c.z)
    x=PTWall.toLocal(c,x,y)
    local width=c.x2-c.x1
    local base,scale=(c.x1+c.x2)/2,width*0.3
    if c.freeWall then base=(c.wallMinX+c.wallMaxX)/2; scale=(c.wallMaxX-c.wallMinX)*0.35
    elseif C.core.phase=="ready" then
        if c.mode=="wall" then scale=width*0.18
        else
            local even=(C.core.points[1]+C.core.points[2])%2==0
            local server=C.core.server
            local left=(server==1 and even) or (server==2 and not even)
            base=base+(left and 1 or -1)*width*0.25
            scale=width*0.1
        end
    end
    return math.max(-1,math.min(1,(x-base)/scale))
end
local function input(command,selectedAim)
    if inputBlocked() then return end
    local eligible,reason=mouseEligible(player())
    if not eligible then
        if reason then notice(reason) end
        return
    end
    if command=="serve" and not equippedToStart(player()) then notice("Hold the Tennis Ball in your secondary hand to serve."); return end
    if command=="serve" and C.core.phase=="ready" and C.core.receiverReady==false then
        notice("Waiting for the receiver: stand in the blue return area with a sports racket.")
        return
    end
    if now() - (C.receivedAt or 0) > 3000 then
        notice("Waiting for server state; syncing...")
        if now() - C.lastSync > 2000 then sync() end
        return
    end
    C.seq = C.seq + 1
    swingAnimation()
    send(command, { aim = selectedAim or aim(), seq = C.seq, session = C.session })
end
local function mouseDown()
    local p=player()
    -- This event is emitted only for a world click unconsumed by other UI.
    -- Its return value does not cancel combat: OnPlayerUpdate applies the gate.
    if inputBlocked() or C.textWasFocused then return end
    if canStartPractice() then
        if not isMouseButtonDown(1) then return end
        if equippedToStart(p) then
            startWallAt({x=screenToIsoX(0,getMouseX(),getMouseY(),p:getZ()),y=screenToIsoY(0,getMouseX(),getMouseY(),p:getZ())})
        end
        return
    end
    -- Aim stance is only needed to start/restart a point. During the rally,
    -- cursor targeting is independent of vanilla aiming and running speed.
    if C.core.phase=="ready" and not isMouseButtonDown(1) then notice("Hold RMB while clicking LMB to serve, or press K."); return end
    updateGuard(p)
    input(C.core.phase=="ready" and "serve" or "swing",mouseAim())
end
local function keyPressed(key)
    if key == Keyboard.KEY_J then input("swing") end
    if key == Keyboard.KEY_K then input("serve") end
end
local function drawCourt()
    PTCourtSelector.begin(player(),function(args)
        notice("Registering court...")
        send("create",args)
    end,function(c)
        local p=player()
        if not p or p:getZ()~=c.z or p:getX()<c.x1-3 or p:getX()>c.x2+3
            or p:getY()<c.y1-3 or p:getY()>c.y2+3 then return false,"Stand beside the court to register it." end
        if SandboxVars and SandboxVars.PlayableTennis and SandboxVars.PlayableTennis.AllowCourtCreation==false
            and p:getAccessLevel()~="admin" then return false,"Court registration is admin-only." end
        for _,other in pairs(C.courts) do
            if not other.owned and other.z==c.z and c.x1<other.x2 and c.x2>other.x1 and c.y1<other.y2 and c.y2>other.y1 then
                return false,"This area overlaps another player's court."
            end
        end
        return PTWall.validateCourt(c,function(x,y,z) return getCell():getGridSquare(x,y,z) end)
    end)
end
local function contextMenu(playerIndex, context, objects, test)
    -- One keyboard and HUD owner per client; split-screen is not supported.
    if playerIndex ~= 0 then return end
    if test then return end
    local p = player()
    if not p then return end
    local square
    for _, object in ipairs(objects) do
        if object.getSquare then square = object:getSquare(); if square then break end end
    end
    square = square or p:getSquare()
    if not square then return end
    local root = context:addOption("Playable Tennis")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    menu:addOption("Draw / replace my court (rectangle selection)",nil,drawCourt)
    menu:addOption("Refresh court list / synchronize", nil, sync)
    if canStartPractice() then
        menu:addOption("Start wall practice here (sports racket + ball in hands)",
            {x=square:getX()+0.5,y=square:getY()+0.5},startWallAt)
    end
    local count = 0
    for _, court in pairs(C.courts) do
        if court.id and court.x1 and court.y1 and court.z == math.floor(p:getZ())
            and math.abs(p:getX() - court.x1) < 100 and math.abs(p:getY() - court.y1) < 100 then
            if court.mode=="tennis" then
                menu:addOption("Join " .. tostring(court.id) .. " (" .. tostring(court.mode) .. ")",court.id,join)
            end
            menu:addOption("Remove " .. tostring(court.id) .. " (owner/admin; ends its game)", court.id, removeCourt)
            count = count + 1
            if count >= 20 then break end
        end
    end
    if C.session then
        menu:addOption("Serve [K]", "serve", input)
        menu:addOption("Swing [J]", "swing", input)
        menu:addOption(C.core and C.core.court.freeWall and "Remove wall practice area" or "Leave court", nil, leave)
    end
    if now() - C.lastSync > 2000 then sync() end
end
local Overlay = ISPanel:derive("PT_Overlay")
local function score(core)
    local a,b = core.points[1],core.points[2]
    if a >= 3 and b >= 3 then
        if a == b then return "40 : 40" end
        return a > b and "AD : 40" or "40 : AD"
    end
    local labels = {"0","15","30","40"}
    return labels[math.min(a,3)+1] .. " : " .. labels[math.min(b,3)+1]
end
local function project(x, y, z)
    if C.core and C.core.court.frame then x,y=PTWall.toWorld(C.core.court,x,y) end
    return isoToScreenX(0, x, y, z), isoToScreenY(0, x, y, z)
end
-- Presentation only: interpolate authoritative samples through wall/floor contacts.
-- Stop at the last sample if packets stop; never extrapolate a fictional hit.
function C.ballPosition()
    local ball=C.core and C.core.ball
    if not ball then return end
    local samples=C.ballSamples
    if not samples or #samples<2 then return ball.x,ball.y,ball.z end
    local renderTime=C.ballAnchorTime+(now()-C.ballAnchorAt)/1000-0.1
    renderTime=math.max(C.ballRenderTime or samples[1].time,math.min(samples[#samples].time,renderTime))
    C.ballRenderTime=renderTime
    local first,last=samples[1],samples[#samples]
    for i=2,#samples do
        if samples[i].time>=renderTime then first,last=samples[i-1],samples[i]; break end
    end
    local duration=last.time-first.time
    local t=duration>0 and math.max(0,math.min(1,(renderTime-first.time)/duration)) or 1
    local old=first.ball
    ball=last.ball
    local x=old.x+(ball.x-old.x)*t
    local y=old.y+(ball.y-old.y)*t
    local court=C.core.court
    if court.mode=="wall" and old.vy and ball.vy and old.vy<0 and ball.vy>0
        and old.y>=court.y1 and ball.y>=court.y1 then
        -- Equal positions before/after reflection must not look stationary.
        -- Interpolate the travelled path via the wall, not its endpoint chord.
        local incoming=(old.y-court.y1)/(-old.vy)
        local outgoing=(ball.y-court.y1)/ball.vy
        local duration=incoming+outgoing
        if duration>0 then
            local elapsed=t*duration
            y=elapsed<=incoming and old.y+old.vy*elapsed
                or court.y1+ball.vy*(elapsed-incoming)
        end
    end
    local z=old.z+(ball.z-old.z)*t
    if old.vz and ball.vz and duration>0 then
        local gravity=9.8
        if last.bounces>first.bounces then
            local contact=(old.vz+math.sqrt(old.vz*old.vz+2*gravity*math.max(0,old.z)))/gravity
            if contact>0 and contact<duration then
                local elapsed=t*duration
                if court.mode=="tennis" and old.vx and old.vy then
                    -- The server slows horizontal travel at a floor bounce.
                    -- Preserve that contact instead of smearing both speeds
                    -- into a single line across the whole snapshot interval.
                    local cx,cy=old.x+old.vx*contact,old.y+old.vy*contact
                    if elapsed<=contact then
                        x,y=old.x+old.vx*elapsed,old.y+old.vy*elapsed
                    else
                        local after=(elapsed-contact)/(duration-contact)
                        x,y=cx+(ball.x-cx)*after,cy+(ball.y-cy)*after
                    end
                end
                if elapsed<=contact then
                    z=old.z+old.vz*elapsed-gravity*elapsed*elapsed/2
                else
                    local remaining=duration-contact
                    local launch=(ball.z+gravity*remaining*remaining/2)/remaining
                    local after=elapsed-contact
                    z=launch*after-gravity*after*after/2
                end
            end
        else
            z=z+gravity*duration*duration*t*(1-t)/2
        end
    end
    return x,y,math.max(0,z)
end
local worldBallRender = Events.OnPostRender and getRenderer and getPlayer
local function drawBall(draw)
    if not C.core or not player() or math.floor(player():getZ())~=C.core.court.z then return end
    local bx,by,bz=C.ballPosition()
    if not bx then return end
    local z=C.core.court.z
    local sx,sy=project(bx,by,z)
    draw(sx-4,sy-2,8,4,0.5,0,0,0)
    local px,py=project(bx,by,z+math.max(0,bz)/3)
    draw(px-3,py-3,6,6,1,0.9,1,0.15)
end
if worldBallRender then
    Events.OnPostRender.Add(function()
        if not C.overlay or getPlayer()~=player() then return end
        -- B42 isoToScreen divides camera-relative coordinates by zoom. The
        -- world FBO expects those coordinates before zoom, unlike UIManager.
        local zoom=getCore():getZoom(0)
        drawBall(function(x,y,w,h,a,r,g,b)
            getRenderer():render(nil,x*zoom,y*zoom,w*zoom,h*zoom,r,g,b,a,nil)
        end)
    end)
end
function Overlay:worldLine(x1,y1,x2,y2,z,r,g,b,absolute)
    local ax,ay,bx,by
    if absolute then
        ax,ay=isoToScreenX(0,x1,y1,z),isoToScreenY(0,x1,y1,z)
        bx,by=isoToScreenX(0,x2,y2,z),isoToScreenY(0,x2,y2,z)
    else
        ax,ay=project(x1,y1,z)
        bx,by=project(x2,y2,z)
    end
    self:drawLine2(ax,ay,bx,by,0.85,r,g,b)
end
function Overlay:render()
    local core = C.core
    local preview=PTCourtSelector.cursor and PTCourtSelector.cursor.preview
    if preview then
        local c=preview.court
        self:worldLine(c.x1,c.y1,c.x2,c.y1,c.z,preview.red,preview.green,0.3,true)
        self:worldLine(c.x2,c.y1,c.x2,c.y2,c.z,preview.red,preview.green,0.3,true)
        self:worldLine(c.x2,c.y2,c.x1,c.y2,c.z,preview.red,preview.green,0.3,true)
        self:worldLine(c.x1,c.y2,c.x1,c.y1,c.z,preview.red,preview.green,0.3,true)
    end
    if player() then
        for _,court in pairs(C.courts) do
            if court.x2 and court.y2 and court.z==math.floor(player():getZ())
                and (not core or core.court.id~=court.id) then
                self:worldLine(court.x1,court.y1,court.x2,court.y1,court.z,0.6,0.8,1,true)
                self:worldLine(court.x2,court.y1,court.x2,court.y2,court.z,0.6,0.8,1,true)
                self:worldLine(court.x2,court.y2,court.x1,court.y2,court.z,0.6,0.8,1,true)
                self:worldLine(court.x1,court.y2,court.x1,court.y1,court.z,0.6,0.8,1,true)
                local lx,ly=isoToScreenX(0,court.x1,court.y1,court.z),isoToScreenY(0,court.x1,court.y1,court.z)
                self:drawText("Court "..tostring(court.id).." | Right-click: Join",lx,ly-20,0.6,0.8,1,1,UIFont.Small)
            end
        end
    end
    if core and player() then
        local court = core.court
        local x1,y1,x2,y2,z = court.x1,court.y1,court.x2,court.y2,court.z
        if math.floor(player():getZ()) == z then
            local mx,my = (x1+x2)/2,(y1+y2)/2
            if court.mode == "tennis" then
                self:worldLine(x1,y1,x2,y1,z,1,1,1)
                self:worldLine(x2,y1,x2,y2,z,1,1,1)
                self:worldLine(x2,y2,x1,y2,z,1,1,1)
                self:worldLine(x1,y2,x1,y1,z,1,1,1)
                self:worldLine(x1,my,x2,my,z,0.3,0.8,1)
                self:worldLine(x1,(y1+my)/2,x2,(y1+my)/2,z,1,1,1)
                self:worldLine(x1,(y2+my)/2,x2,(y2+my)/2,z,1,1,1)
                self:worldLine(mx,(y1+my)/2,mx,(y2+my)/2,z,1,1,1)
                if core.phase=="ready" and not C.waiting and (core.server==C.slot) then
                    local a=PTCore.serveArea(core,C.slot)
                    self:worldLine(a.x1,a.y1,a.x2,a.y1,z,0.2,1,0.4)
                    self:worldLine(a.x2,a.y1,a.x2,a.y2,z,0.2,1,0.4)
                    self:worldLine(a.x2,a.y2,a.x1,a.y2,z,0.2,1,0.4)
                    self:worldLine(a.x1,a.y2,a.x1,a.y1,z,0.2,1,0.4)
                    local sx,sy=project((a.x1+a.x2)/2,a.baseline,z)
                    self:drawText("Serve Zone",sx-35,sy-25,0.2,1,0.4,1,UIFont.Small)
                end
                if core.phase=="ready" then
                    local a=PTCore.receiveArea(core,core.server)
                    self:worldLine(a.x1,a.y1,a.x2,a.y1,z,0.3,0.7,1)
                    self:worldLine(a.x2,a.y1,a.x2,a.y2,z,0.3,0.7,1)
                    self:worldLine(a.x2,a.y2,a.x1,a.y2,z,0.3,0.7,1)
                    self:worldLine(a.x1,a.y2,a.x1,a.y1,z,0.3,0.7,1)
                    local rx,ry=project(a.x,a.y,z)
                    self:drawText("Receive Zone",rx-40,ry-25,0.3,0.7,1,1,UIFont.Small)
                end
            else
                -- Mark the actual wall foot, not a fractional storey above it.
                local left,right=court.wallMinX or x1,court.wallMaxX or x2
                self:worldLine(left,y1,right,y1,z,0.3,0.8,1)
                self:worldLine(left,y1,left,y1+0.6,z,0.3,0.8,1)
                self:worldLine(right,y1,right,y1+0.6,z,0.3,0.8,1)
            end
            if mouseEligible(player()) and (core.phase=="rally" or isMouseButtonDown(1)) and not inputBlocked() then
                local tx,ty=PTCore.aimTarget(core,C.slot,mouseAim(),core.phase=="ready")
                if tx then
                    local sx,sy=project(tx,ty,z)
                    self:drawLine2(sx-7,sy,sx+7,sy,1,0.2,1,0.5)
                    self:drawLine2(sx,sy-5,sx,sy+5,1,0.2,1,0.5)
                end
            end
            if not worldBallRender then
                drawBall(function(x,y,w,h,a,r,g,b) self:drawRect(x,y,w,h,a,r,g,b) end)
            end
        end
        local center=getCore():getScreenWidth()/2
        local top=36
        local width=math.min(460,getCore():getScreenWidth()-32)
        local function centered(text,y,font,zoom,r,g,b)
            local tw=getTextManager():MeasureStringX(font,text)
            zoom=math.min(zoom,(width-24)/math.max(1,tw))
            self:drawTextZoomed(text,center-tw*zoom/2,y,zoom,r or 1,g or 1,b or 1,1,font)
        end
        if court.mode=="wall" then
            self:drawRect(center-width/2,top,width,36,0.75,0.04,0.06,0.07)
            centered("Rally "..tostring(core.rally or 0).." | Best "..tostring(core.bestRally or 0)
                .." | Depth "..tostring(y2-y1),top+8,UIFont.Small,1)
        else
            local names=C.names or {}
            local function name(slot)
                return names[slot] or "Player "..tostring(slot)
            end
            local serving=core.server
            local status
            if core.phase=="finished" then status=name(core.winner or serving).." Win"
            elseif C.waiting then status="Waiting for opponent"
            elseif core.paused then status="Paused - return to court with your racket"
            elseif core.phase=="ready" then
                status=core.receiverReady==false and "Waiting for receiver in Receive Zone"
                    or (serving==C.slot and "Your serve" or name(serving).." to serve")
            elseif core.points[1]>=3 and core.points[1]==core.points[2] then status="Deuce"
            else status="Rally" end
            local scoreZoom=2.4
            local scoreHeight=getTextManager():getFontHeight(UIFont.Large)*scoreZoom
            self:drawRect(center-width/2,top,width,64+scoreHeight,0.75,0.04,0.06,0.07)
            centered(status,top+8,UIFont.Small,1,0.7,0.9,1)
            centered(name(1).."  |  "..name(2),top+29,UIFont.Small,1)
            centered(score(core):gsub(" : ","  |  "),top+52,UIFont.Large,scoreZoom)
        end
    end
    if now() < (C.messageUntil or 0) then
        local message=C.message
        local friendly={
            ["Swing cooldown."]="Wait a moment before swinging again.",
            ["Ball is outside racket height (0.15 to 2.4)."]="The ball is too high or too low to hit.",
            ["Waiting for opponent."]="Waiting for opponent.",
            ["Hold RMB while clicking LMB to serve, or press K."]="Hold right-click, then left-click to serve.",
            ["Waiting for the receiver: stand in the blue return area with a sports racket."]="The receiver must enter Receive Zone with a racket.",
            ["Equip an intact SPORTS Tennis Racket in your primary hand."]="Hold a usable sports racket in your right hand.",
            ["Hold the Tennis Ball in your secondary hand to serve."]="Hold a tennis ball in your left hand to serve.",
            ["Hold a Tennis Ball in your secondary hand to serve."]="Hold a tennis ball in your left hand to serve.",
            ["Waiting for server state; syncing..."]="Reconnecting to the game...",
        }
        message=friendly[message] or message
        if message:find("green serve box",1,true) then message="Move into Serve Zone to serve." end
        local screenWidth=getCore():getScreenWidth()
        local tw=getTextManager():MeasureStringX(UIFont.Small,message)
        local zoom=math.min(1,(screenWidth-56)/math.max(1,tw))
        local y=core and (core.court.mode=="wall" and 80
            or 112+getTextManager():getFontHeight(UIFont.Large)*2.4) or 36
        self:drawRect((screenWidth-tw*zoom)/2-12,y,tw*zoom+24,30,0.85,0.05,0.05,0.05)
        self:drawTextZoomed(message,(screenWidth-tw*zoom)/2,y+6,zoom,1,0.85,0.4,1,UIFont.Small)
    end
end
local function tick()
    C.textWasFocused=inputBlocked()
    if C.session and C.core and C.core.phase~="finished"
        and now() - C.lastSync > 5000 and now() - (C.receivedAt or 0) > 1500 then sync() end
end
local function start()
    local p=player()
    if not p or p:isDead() then return end
    -- OnCreatePlayer and OnGameStart can both fire for initial creation.
    -- Respawning needs this setup again, but a second event must not erase
    -- the snapshot already restored by the first event's sync.
    if C.overlay and C.activePlayer==p and not C.suspended then return end
    PTCourtSelector.cancel()
    releaseGuard(true)
    if C.overlay then C.overlay:removeFromUIManager() end
    C.session, C.core, C.previousBall, C.draft, C.ballSamples = nil, nil, nil, nil, nil
    C.courts, C.seq, C.revision = {}, 0, -1
    C.suspended,C.activePlayer,C.joinPending=false,p,false
    -- B42 top-level isPointOver occludes lower UI even with consumeMouseEvents=false.
    -- A zero-area display panel still renders absolute coordinates, but cannot
    -- cover inventory/context-menu hit tests or redirect their wheel to zoom.
    C.overlay = Overlay:new(0,0,0,0)
    C.overlay:initialise()
    C.overlay:instantiate()
    C.overlay.background = false
    C.overlay:setWantMouseEvents(false)
    C.overlay:addToUIManager()
    sync()
end
local function stop()
    PTCourtSelector.cancel()
    releaseGuard(true)
    -- Death/disconnect only suspend local presentation. The server retains
    -- this player's court and score; its same session ID must be resumable.
    C.suspended,C.activePlayer,C.joinPending=true,nil,false
    C.session,C.core,C.previousBall,C.ballSamples=nil,nil,nil,nil
    if C.overlay then C.overlay:removeFromUIManager(); C.overlay=nil end
end
Events.OnServerCommand.Add(function(module,command,args)
    if module == "PlayableTennis" then C.receive(command,args) end
end)
Events.OnFillWorldObjectContextMenu.Add(contextMenu)
Events.OnKeyPressed.Add(keyPressed)
Events.OnMouseDown.Add(mouseDown)
-- Installed updateInternal2 invokes this before reading input / attack gates.
Events.OnPlayerUpdate.Add(function(p) if p==player() then updateGuard(p) end end)
Events.OnPlayerDeath.Add(function(p) if p==player() or (C.attackGuard and C.attackGuard.player==p) then stop() end end)
Events.OnDisconnect.Add(stop)
Events.OnMainMenuEnter.Add(stop)
Events.OnGameStart.Add(start)
Events.OnCreatePlayer.Add(function(index) if index==0 then start() end end)
Events.OnTick.Add(tick)
