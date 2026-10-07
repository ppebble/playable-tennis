local function check(value,message) checks=(checks or 0)+1; assert(value,message) end
local function snapshot(rev,phase,x,session,lastSeq)
    return {session=session or 'a',slot=1,revision=rev,lastSeq=lastSeq or 0,core={
        court={id='court',x1=0,y1=0,x2=8,y2=18,z=0,mode='tennis'},
        phase=phase,ball=x and {x=x,y=10,z=1},points={0,0},games={0,0},server=1}}
end
Events.OnGameStart.callback()
check(PTClient.overlay.mouseEvents==false,'overlay does not consume mouse input')
check(PTClient.overlay.width==0 and PTClient.overlay.height==0,'display overlay has no native mouse hit area')
Events.OnTick.callback()
check(PTClient.overlay.width==0 and PTClient.overlay.height==0,'tick never expands overlay over inventory')
PTClient.receive('state',snapshot(1,'rally',1,'a',5))
check(PTClient.seq==5,'resync restores acknowledged sequence')
PTClient.receive('state',snapshot(1,'rally',99))
check(PTClient.core.ball.x==1,'duplicate revision ignored')
PTClient.receive('state',snapshot(0,'rally',99))
check(PTClient.core.ball.x==1,'older revision ignored')
ClientMock.time=ClientMock.time+100
PTClient.receive('state',snapshot(2,'rally',3,'a',6))
check(PTClient.previousBall.x==1,'continuous rally retains interpolation origin')
ClientMock.time=ClientMock.time+50
PTClient.overlay:render()
local draw=ClientMock.draws[6]
-- Four world ball/shadow/HUD primitives are collected; find the 6x6 ball.
local ball
for _,d in ipairs(ClientMock.draws) do if d.w==6 and d.h==6 then ball=d end end
check(ball and ball.x==-83,'mid-snapshot ball interpolated without advancing physics')
PTClient.receive('state',snapshot(3,'ready',nil,'a',6))
check(PTClient.previousBall==nil,'point reset discards interpolation history')
local sent=#ClientMock.sent
ClientMock.focused=true
Events.OnKeyPressed.callback(Keyboard.KEY_J)
check(#ClientMock.sent==sent,'text focus suppresses swing')
ClientMock.focused=false
Events.OnKeyPressed.callback(Keyboard.KEY_J)
check(ClientMock.sent[#ClientMock.sent].command=='swing' and PTClient.seq==7,'swing increments sequence')
ClientMock.time=ClientMock.time+4000
Events.OnKeyPressed.callback(Keyboard.KEY_K)
check(ClientMock.sent[#ClientMock.sent].command=='sync' and PTClient.seq==7,'stale state freezes serve and requests sync')
local afterSync=#ClientMock.sent
Events.OnKeyPressed.callback(Keyboard.KEY_K)
check(#ClientMock.sent==afterSync,'stale input sync rate bounded')
PTClient.receive('left',{session='old'})
check(PTClient.session=='a','late leave for other session ignored')
PTClient.receive('left',{session='a'})
PTClient.receive('state',snapshot(9,'rally',5,'a'))
check(PTClient.session==nil,'retired session cannot resurrect')
PTClient.receive('state',snapshot(1,'rally',5,'b',0))
check(PTClient.session=='b' and not PTClient.previousBall,'fresh session resets interpolation')
PTClient.receive('list',{courts={{id='court',x1=0,y1=0,z=0,mode='tennis'}}})
local square={getX=function() return 1 end,getY=function() return 2 end,getZ=function() return 0 end}
local menu=ClientMock.menu()
Events.OnFillWorldObjectContextMenu.callback(0,menu,{{getSquare=function() return square end}},false)
menu.submenu.options[1].callback(menu.submenu.options[1].target,menu.submenu.options[1].arg)
check(ClientMock.selecting,'context begins one rectangle selection workflow')
ClientMock.selectCourt({x1=1,y1=2,x2=9,y2=20,z=0,mode='tennis'})
check(ClientMock.sent[#ClientMock.sent].command=='create','confirmation does not sync over the registration result')
PTClient.receive('error',{message='Obstacle blocks court'})
check(PTClient.message=='Obstacle blocks court','registration failure stays visible')
PTClient.receive('created',{id='court'})
check(string.find(PTClient.message,'registered')~=nil,'registration acknowledgment explains joining')
PTCourtSelector.cancel()
local join
for _,o in ipairs(menu.submenu.options) do if o.name=='Join court (tennis)' then join=o end end
check(join~=nil,'nearby saved court exposed in menu')
join.callback(join.target)
check(ClientMock.sent[#ClientMock.sent].command=='join' and ClientMock.sent[#ClientMock.sent].args.id=='court','join menu sends court id')
local prior=snapshot(2,'rally',4,'b'); prior.core.shotId=1
PTClient.receive('state',prior)
local shot=snapshot(3,'rally',6,'b'); shot.core.shotId=2
PTClient.receive('state',shot)
check(PTClient.previousBall==nil,'shot discontinuity discards interpolation')
check(ClientMock.sound=='TennisRacketHit','accepted new shot emits local feedback')
local bounce=snapshot(4,'rally',6,'b'); bounce.core.shotId=2; bounce.core.bounces=1
PTClient.receive('state',bounce)
check(PTClient.previousBall~=nil,'bounce retains continuous visual interpolation')

local p=ClientMock.player
local function click() Events.OnMouseDown.callback() end
local function update() Events.OnPlayerUpdate.callback(p) end
local function last() return ClientMock.sent[#ClientMock.sent] end
ClientMock.buttons={[0]=true,[1]=true}; ClientMock.mouseX=5
update()
check(p.banned and PTClient.attackGuard,'sports racket suppresses native combat')
local before=#ClientMock.sent
click()
check(#ClientMock.sent==before+1 and last().command=='swing','world RMB LMB sends rally swing')
check(math.abs(last().args.aim-1/2.4)<0.000001,'world mouse maps to continuous aim')
update(); update()
check(#ClientMock.sent==before+1,'holding buttons does not auto fire')
ClientMock.buttons={}; update()
check(p.banned and PTClient.attackGuard,'sports racket stays noncombat without RMB')
local waiting=snapshot(5,'ready',nil,'b'); waiting.waiting=true
PTClient.receive('state',waiting)
ClientMock.buttons={[0]=true,[1]=true}; before=#ClientMock.sent
Events.OnKeyPressed.callback(Keyboard.KEY_J); Events.OnKeyPressed.callback(Keyboard.KEY_K); click(); update()
check(#ClientMock.sent==before,'waiting tennis rejects all mouse and key strokes')
check(p.banned,'waiting does not release sports combat guard')
local ready=snapshot(6,'ready',nil,'b'); ready.waiting=false
PTClient.receive('state',ready)
p.noBall=true; p.inventoryBall=true; before=#ClientMock.sent
click(); Events.OnKeyPressed.callback(Keyboard.KEY_K)
check(#ClientMock.sent==before,'loose inventory ball cannot serve without secondary ball')
p.noBall=false; p.secondaryType='Base.Baseball'; click()
check(#ClientMock.sent==before,'wrong secondary item cannot serve')
p.secondaryType=nil; ClientMock.mouseX=6.4; click()
check(last().command=='serve' and math.abs(last().args.aim-0.5)<0.000001,'secondary tennis ball enables aimed serve')
ClientMock.mouseX=999; click()
check(last().args.aim==1,'mouse aim clamps to supported range')
before=#ClientMock.sent; ClientMock.focused=true; click()
check(#ClientMock.sent==before,'focused text suppresses mouse input')
Events.OnTick.callback(); ClientMock.focused=false; click()
check(#ClientMock.sent==before,'unfocus click cannot also swing')
Events.OnTick.callback(); ClientMock.time=ClientMock.time+4000; before=#ClientMock.sent; click()
check(#ClientMock.sent==before+1 and last().command=='sync','stale mouse only syncs')
PTClient.receive('left',{session='b'}); ClientMock.buttons={}; update()
check(p.banned and not PTClient.session,'sports guard persists outside session')
p.primaryType='Base.TennisRacket'; update(); before=#ClientMock.sent
ClientMock.buttons={[0]=true,[1]=true}; click(); update()
check(not p.banned and #ClientMock.sent==before,'vanilla racket preserves combat and never starts practice')
PTClient.receive('state',snapshot(1,'ready',nil,'vanilla')); before=#ClientMock.sent
click(); Events.OnKeyPressed.callback(Keyboard.KEY_J); Events.OnKeyPressed.callback(Keyboard.KEY_K)
check(#ClientMock.sent==before and not p.banned,'vanilla racket never sports even in session')
PTClient.receive('left',{session='vanilla'}); p.primaryType=nil; p.noBall=true; update(); before=#ClientMock.sent
click()
check(p.banned and #ClientMock.sent==before,'sports without session blocks combat but needs held ball to start')
p.noBall=false; ClientMock.mouseX=17.25; ClientMock.mouseY=9.75; click()
check(last().command=='startWall' and last().args.x==17.25 and last().args.y==9.75,'no-session click sends world wall target')
before=#ClientMock.sent; click()
check(#ClientMock.sent==before,'wall start duplicate cooldown')
ClientMock.time=ClientMock.time+501; click()
check(#ClientMock.sent==before+1,'wall start retry permitted after cooldown')
ClientMock.buttons={}; update(); p.primaryType='Base.Axe'; update()
check(not p.banned and not PTClient.attackGuard,'unequipping restores previous native attack baseline')
p.banned=true; p.primaryType=nil; update(); p.primaryType='Base.Axe'; update()
check(p.banned and not PTClient.attackGuard,'preexisting native ban survives equip unequip')
p.banned=false; p.primaryType=nil; update(); ClientMock.buttons={[0]=true}; p.primaryType='Base.Axe'; update()
check(p.banned,'held tennis click drains before weapon combat resumes')
ClientMock.buttons={}; update()
check(not p.banned,'release clears guard after switching weapon')
p.primaryType=nil; update()
check(p.banned,'reequipping reacquires clean baseline')
-- Context fallback targets the selected tile centre, not the player's position.
ClientMock.time=ClientMock.time+501
local menu2=ClientMock.menu(); Events.OnFillWorldObjectContextMenu.callback(0,menu2,{{getSquare=function() return square end}},false)
local wallOption
for _,o in ipairs(menu2.submenu.options) do if string.find(o.name,'Start wall practice',1,true) then wallOption=o end end
check(wallOption~=nil,'wall practice context fallback exists')
wallOption.callback(wallOption.target)
check(last().command=='startWall' and last().args.x==1.5 and last().args.y==2.5,'context fallback sends selected tile centre')
-- All four cardinal frames use wall-local aiming and transform rendered balls.
local frames={{ux=1,uy=0,vx=0,vy=1},{ux=-1,uy=0,vx=0,vy=-1},
    {ux=0,uy=1,vx=1,vy=0},{ux=0,uy=-1,vx=-1,vy=0}}
for i,f in ipairs(frames) do
    f.originX=30; f.originY=40
    local s=snapshot(i,'rally',1,'rotated'); s.core.court={id='wall',mode='wall',freeWall=true,
        x1=-5,x2=5,y1=0,y2=20,z=0,wallMinX=-2,wallMaxX=2,frame=f}
    PTClient.receive('state',s)
    p.x,p.y=PTWall.toWorld(s.core.court,0,5)
    ClientMock.mouseX,ClientMock.mouseY=PTWall.toWorld(s.core.court,0.7,0)
    ClientMock.buttons={[0]=true,[1]=true}; click()
    check(last().command=='swing' and math.abs(last().args.aim-0.5)<0.000001,'cardinal wall mouse aim '..i)
    PTClient.previousBall=nil; ClientMock.draws={}; ClientMock.lines={}; PTClient.overlay:render()
    local groundX,groundY=PTWall.toWorld(s.core.court,-2,0)
    check(ClientMock.lines[1].y==groundX*5+groundY*5,'wall baseline stays at ground level '..i)
    local bx,by=PTWall.toWorld(s.core.court,1,10)
    local rendered
    for _,d in ipairs(ClientMock.draws) do if d.w==6 and d.h==6 then rendered=d end end
    check(rendered and math.abs(rendered.x-(bx*10-by*10-3))<0.000001
        and math.abs(rendered.y-(bx*5+by*5-13))<0.000001,'cardinal wall ball projection '..i)
end
Events.OnDisconnect.callback()
check(not p.banned and not PTClient.session,'disconnect restores native baseline')
PTClient.receive('state',snapshot(8,'ready',nil,'rotated'))
check(not PTClient.session,'late disconnected state cannot resurrect')
p.x=nil; p.y=nil
Events.OnGameStart.callback()
PTClient.receive('state',snapshot(1,'ready',nil,'death')); update(); Events.OnPlayerDeath.callback(p)
check(not p.banned and not PTClient.session,'death clears guard and session')
Events.OnCreatePlayer.callback(0)
PTClient.receive('state',snapshot(1,'ready',nil,'menu')); update(); Events.OnMainMenuEnter.callback()
check(not p.banned and not PTClient.session,'main menu clears guard and session')
-- Each point starts with RMB+LMB; all subsequent returns need only LMB.
Events.OnGameStart.callback()
ClientMock.buttons={[0]=true}; before=#ClientMock.sent
click()
check(#ClientMock.sent==before,'idle LMB cannot start wall practice')
for _,mode in ipairs({'wall','tennis'}) do
    local id='free-movement-'..mode
    local s=snapshot(1,'ready',nil,id); s.core.court.mode=mode
    PTClient.receive('state',s); before=#ClientMock.sent; click()
    check(#ClientMock.sent==before,mode..' ready requires RMB')
    ClientMock.buttons[1]=true; click()
    check(last().command=='serve',mode..' RMB LMB starts point')
    s=snapshot(2,'rally',1,id); s.core.court.mode=mode
    PTClient.receive('state',s); ClientMock.buttons[1]=nil; before=#ClientMock.sent
    local beforeMotion=ClientMock.swings or 0
    click()
    check(#ClientMock.sent==before+1 and last().command=='swing',mode..' LMB returns without aim stance')
    check(ClientMock.swings==beforeMotion+1,mode..' uses shared single-handed swing')
    ClientMock.lines={}; PTClient.overlay:render()
    check(#ClientMock.lines==(mode=='wall' and 5 or 10),mode..' cursor aim marker visible without RMB')
    s=snapshot(3,'ready',nil,id); s.core.court.mode=mode
    PTClient.receive('state',s); before=#ClientMock.sent; click()
    check(#ClientMock.sent==before,mode..' missed point resets RMB requirement')
    PTClient.receive('left',{session=id})
end
PTClient.receive('list',{courts={{id='play-court',x1=0,y1=0,x2=8,y2=18,z=0,mode='tennis'}}})
local playMenu=ClientMock.menu()
Events.OnFillWorldObjectContextMenu.callback(0,playMenu,{{getSquare=function() return square end}},false)
for _,o in ipairs(playMenu.submenu.options) do
    check(not string.find(o.name,'Solo test',1,true) and not string.find(o.name,'Test:',1,true),'release menu excludes test modes')
end
local targetState=snapshot(1,'ready',nil,'play-ui')
targetState.core.court.id='play-court'
PTClient.receive('state',targetState)
ClientMock.buttons={}; ClientMock.lines={}; PTClient.overlay:render()
check(#ClientMock.lines==16,'normal court draws serve and receive zones without test target')
check(ClientMock.lines[9].x==17 and ClientMock.lines[9].y==-6.5,'serve zone uses north baseline and west half')
PTCourtSelector.begin(p,function() end); before=#ClientMock.sent
ClientMock.buttons={[0]=true,[1]=true}; click(); Events.OnKeyPressed.callback(Keyboard.KEY_K)
check(#ClientMock.sent==before,'selection does not send sports mouse or keyboard commands')
PTCourtSelector.cancel()
ClientMock.selectionCooldown=true; before=#ClientMock.sent; click()
check(#ClientMock.sent==before,'selection completion click cannot trigger a sports stroke')
ClientMock.selectionCooldown=false
-- Normal server previews aim diagonally from the serving player's side.
targetState=snapshot(2,'ready',nil,'play-ui')
PTClient.receive('state',targetState)
ClientMock.mouseX=6; click()
check(last().command=='serve' and last().args.aim==0,'serve aims from scheduled player')
local savedSwing=PTSwing.play
PTSwing.play=function() error('cosmetic failure fixture') end
before=#ClientMock.sent; click()
check(#ClientMock.sent==before+1 and last().command=='serve','cosmetic animation failure cannot swallow serve command')
PTSwing.play=savedSwing
p.x=30; before=#ClientMock.sent; click()
check(#ClientMock.sent==before and string.find(PTClient.message,'Return to the court',1,true),'outside court reports why serve cannot start')
p.x=nil; p.noRacket=true; click()
check(#ClientMock.sent==before and string.find(PTClient.message,'SPORTS Tennis Racket',1,true),'missing racket reports why serve cannot start')
p.noRacket=false; ClientMock.buttons={[0]=true}; click()
check(string.find(PTClient.message,'Hold RMB',1,true),'ready click explains required serve input')
PTClient.receive('left',{session='play-ui'})
ClientMock.lines={}; PTClient.overlay:render()
check(#ClientMock.lines==4,'registered idle court displays just its four boundary edges')
local wallView=snapshot(1,'ready',nil,'wall-boundary')
wallView.core.court={id='wall-test',mode='wall',freeWall=true,x1=0,x2=8,y1=0,y2=14,z=0,
    wallMinX=0,wallMaxX=8,frame={originX=100,originY=200,ux=0,uy=1,vx=1,vy=0}}
ClientMock.buttons={}
PTClient.receive('state',wallView)
ClientMock.lines={}; PTClient.overlay:render()
check(#ClientMock.lines==7,'wall displays three wall marks and saved court edges without trapezoid')
check(ClientMock.lines[1].x==0 and ClientMock.lines[1].y==0,'saved court uses world coordinates during rotated wall practice')
PTCourtSelector.cursor={preview={court={x1=1,y1=2,x2=9,y2=20,z=0},red=0.2,green=0.9}}
ClientMock.lines={}; PTClient.overlay:render()
check(#ClientMock.lines==11,'selection adds four outline edges without a filled area')
PTCourtSelector.cursor=nil
PTClient.receive('left',{session='wall-boundary'})
PTClient.receive('list',{courts={}})
local receiverState=snapshot(1,'ready',nil,'receiver-ready')
receiverState.core.receiverReady=false
PTClient.receive('state',receiverState)
ClientMock.buttons={[0]=true,[1]=true}
before=#ClientMock.sent
local swingsBefore=ClientMock.swings or 0
click()
check(#ClientMock.sent==before and (ClientMock.swings or 0)==swingsBefore,'waiting receiver suppresses serve and cosmetic stroke')
check(string.find(PTClient.message,'Waiting for the receiver',1,true),'receiver readiness failure is visible')
ClientMock.buttons={}; ClientMock.lines={}; PTClient.overlay:render()
check(#ClientMock.lines==16,'ready normal match displays serving and diagonal receiving areas')
receiverState=snapshot(2,'ready',nil,'receiver-ready'); receiverState.core.receiverReady=true
PTClient.receive('state',receiverState)
ClientMock.buttons={[0]=true,[1]=true}; click()
check(#ClientMock.sent==before+1 and last().command=='serve','fresh receiver ready state enables serve')
receiverState=snapshot(3,'ready',nil,'receiver-ready'); receiverState.core.receiverReady=false
PTClient.receive('state',receiverState); before=#ClientMock.sent; click()
check(#ClientMock.sent==before,'receiver leaving ready area blocks the next serve')
print('PASS client checks: '..checks)

-- A persistent paused game keeps scores visible and cannot emit cosmetic swings.
local paused=snapshot(1,'ready',nil,'paused-score')
paused.core.paused=true; paused.core.message='Return with both rackets to resume.'
paused.core.points={2,3}; paused.core.games=nil
PTClient.receive('left',{session=PTClient.session})
PTClient.receive('state',paused)
local commands,swings=#ClientMock.sent,ClientMock.swings or 0
ClientMock.focused=false; ClientMock.buttons={[0]=true,[1]=true}
Events.OnKeyPressed.callback(Keyboard.KEY_K)
check(#ClientMock.sent==commands and (ClientMock.swings or 0)==swings,'paused game blocks serve animation and command')
local labels={}
PTClient.overlay.drawText=function(self,text) labels[#labels+1]=text end
PTClient.overlay:render()
local pointScore,overall,pausedMessage=false,false,false
for _,text in ipairs(labels) do
    if string.find(text,'30  |  40',1,true) then pointScore=true end
    if string.find(text,'Games ',1,true) then overall=true end
    if string.find(text,'Paused -',1,true) then pausedMessage=true end
end
check(pointScore and not overall,'HUD shows point score without requiring overall games tally')
check(pausedMessage,'pause explanation is not overwritten by receiver readiness')

paused.players={'Alice','Bob'}; paused.revision=2; paused.core.paused=false; paused.core.phase='finished'; paused.core.winner=2
PTClient.receive('state',paused)
labels={}; PTClient.overlay:render()
local winner=false
for _,text in ipairs(labels) do if string.find(text,'Bob Win',1,true) then winner=true end end
check(winner,'finished game clearly labels the winner without an overall score')

PTClient.receive('list',{courts={{id='again',x1=0,y1=0,x2=8,y2=18,z=0,mode='tennis'}}})
local againMenu=ClientMock.menu()
Events.OnFillWorldObjectContextMenu.callback(0,againMenu,{{getSquare=function() return square end}},false)
local joinOption,wallOption,removeOption
for _,option in ipairs(againMenu.submenu.options) do
    if string.find(option.name,'Join again',1,true) then joinOption=option end
    if string.find(option.name,'Start wall practice',1,true) then wallOption=option end
    if string.find(option.name,'Remove again',1,true) then removeOption=option end
end
check(joinOption and wallOption,'finished game exposes join and wall practice without leave')
check(removeOption and string.find(removeOption.name,'ends its game',1,true),'removal menu explains active game termination')
joinOption.callback(joinOption.target)
check(last().command=='join' and PTClient.joinPending,'finished game can join a new game directly')
-- A wall restart must accept the server response from its new session as well.
ClientMock.time=ClientMock.time+600
wallOption.callback(wallOption.target)
check(last().command=='startWall' and PTClient.joinPending,'finished game can request wall practice directly')
PTClient.receive('state',snapshot(1,'rally',1,'restart-wall'))
check(PTClient.session=='restart-wall' and PTClient.retired['paused-score'],'restart accepts new session and retires final-score session')

-- Death is a temporary lifecycle stop, not explicit court withdrawal.
local saved=snapshot(2,'ready',nil,'restart-wall'); saved.core.points={2,3}
PTClient.receive('state',saved)
local sentBeforeDeath=#ClientMock.sent
p.dead=true; Events.OnPlayerDeath.callback(p)
check(PTClient.suspended and not PTClient.overlay and not PTClient.retired['restart-wall'],
    'death suspends presentation without retiring persistent server session')
PTClient.receive('state',saved)
check(not PTClient.session and #ClientMock.sent==sentBeforeDeath,'dead client ignores delayed state and sends no leave')
p.dead=false
Events.OnCreatePlayer.callback(1)
check(not PTClient.overlay,'other split-screen player creation does not resume player zero')
Events.OnCreatePlayer.callback(0)
check(PTClient.overlay and last().command=='sync','local respawn restores overlay and synchronizes')
PTClient.receive('state',saved)
check(PTClient.session=='restart-wall' and PTClient.core.points[1]==2 and PTClient.core.points[2]==3,
    'same-ID server snapshot restores saved points after respawn')
local restoredOverlay=PTClient.overlay
local afterRespawn=#ClientMock.sent
Events.OnGameStart.callback(); Events.OnCreatePlayer.callback(0)
check(PTClient.overlay==restoredOverlay and PTClient.session=='restart-wall' and #ClientMock.sent==afterRespawn,
    'creation/start event order is idempotent and preserves resumed snapshot')
check(PTClient.retired['paused-score'],'temporary recovery preserves explicitly retired session guard')

local finalState=snapshot(3,'finished',nil,'restart-wall'); finalState.core.winner=1
PTClient.receive('state',finalState)
local beforeFinalTick=#ClientMock.sent
ClientMock.time=ClientMock.time+10000
Events.OnTick.callback()
check(#ClientMock.sent==beforeFinalTick and PTClient.core.winner==1,
    'finished scoreboard remains visible instead of stale auto-sync asking server for released membership')
PTClient.receive('left',{session=PTClient.session})
local rotated=snapshot(1,'ready',nil,'east-west-tennis')
rotated.core=PTCore.new({id='ew',mode='tennis',x1=100,x2=118,y1=200,y2=210,z=0})
rotated.core.receiverReady=true
PTClient.receive('state',rotated)
p.x,p.y=100,202.5
ClientMock.mouseX,ClientMock.mouseY=110,208
ClientMock.buttons={[0]=true,[1]=true}; click()
check(last().command=='serve' and math.abs(last().args.aim-0.5)<0.000001,'east-west mouse aims across local court width')
labels={}; PTClient.overlay.drawText=function(self,text) labels[#labels+1]=text end
PTClient.overlay:render()
local serveZone,debug=false,false
for _,text in ipairs(labels) do
    if text=='Serve Zone' then serveZone=true end
    if string.find(text,'lower Y',1,true) or string.find(text,'You: west',1,true) then debug=true end
end
check(serveZone and not debug,'rotated court uses friendly zone labels without axis diagnostics')
rotated.revision=2; rotated.core.phase='rally'; rotated.core.ball={x=202.5,y=109,z=1}
PTClient.receive('state',rotated)
ClientMock.draws={}; PTClient.overlay:render()
local worldBall
for _,d in ipairs(ClientMock.draws) do if d.w==6 and d.h==6 then worldBall=d end end
check(worldBall and math.abs(worldBall.x-(109*10-202.5*10-3))<0.000001
    and math.abs(worldBall.y-(109*5+202.5*5-13))<0.000001,'east-west tennis ball renders in world axes')

-- Compact top-center HUD, responsive score, notices and idle visibility.
PTClient.courts={}; PTClient.messageUntil=0
ClientMock.texts={}; ClientMock.draws={}; PTClient.overlay:render()
local large
for _,t in ipairs(ClientMock.texts) do if t.font==UIFont.Large then large=t end end
check(large and large.zoom>2 and large.y<100,'score is enlarged at top of screen')
local tw=getTextManager():MeasureStringX(large.font,large.text)*large.zoom
check(math.abs(large.x+tw/2-640)<0.01,'score centered on viewport')
ClientMock.screenWidth=800; ClientMock.texts={}; PTClient.overlay:render()
for _,t in ipairs(ClientMock.texts) do
    if t.font==UIFont.Large then check(math.abs(t.x+getTextManager():MeasureStringX(t.font,t.text)*t.zoom/2-400)<0.01,'HUD recenters on resolution change') end
end
ClientMock.screenWidth=nil
PTClient.core.court.mode='wall'; PTClient.core.rally=5; PTClient.core.bestRally=9
ClientMock.texts={}; PTClient.overlay:render()
check(#ClientMock.texts==1 and ClientMock.texts[1].text=='Rally 5 | Best 9 | Depth 18','wall HUD contains only three requested metrics')
PTClient.receive('error',{message='Swing cooldown.'})
ClientMock.texts={}; PTClient.overlay:render()
check(ClientMock.texts[2].text=='Wait a moment before swinging again.','yellow input notice replaces diagnostic wording')
PTClient.receive('left',{session=PTClient.session}); PTClient.messageUntil=0
ClientMock.texts={}; ClientMock.draws={}; PTClient.overlay:render()
check(#ClientMock.texts==0 and #ClientMock.draws==0,'holding racket outside play has no persistent HUD')

-- The wall removal menu reuses the authorized leave path and clears presentation.
local wallRemoval=snapshot(1,'rally',1,'wall-remove')
wallRemoval.core.court.mode='wall'; wallRemoval.core.court.freeWall=true
PTClient.receive('state',wallRemoval)
local removeMenu=ClientMock.menu()
Events.OnFillWorldObjectContextMenu.callback(0,removeMenu,{{getSquare=function() return square end}},false)
local removeWall
for _,o in ipairs(removeMenu.submenu.options) do if o.name=='Remove wall practice area' then removeWall=o end end
check(removeWall~=nil,'active wall practice has explicit remove-area menu')
removeWall.callback()
check(last().command=='leave','wall removal sends normal authorized leave command')
PTClient.receive('left',{session='wall-remove',message='Wall practice area removed.'})
check(not PTClient.core and not PTClient.session,'confirmed wall removal clears HUD and area overlay')
