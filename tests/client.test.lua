local function check(value,message) checks=(checks or 0)+1; assert(value,message) end
local function snapshot(rev,phase,x,session,lastSeq)
    return {session=session or 'a',slot=1,revision=rev,lastSeq=lastSeq or 0,core={
        court={id='court',x1=0,y1=0,x2=8,y2=18,z=0,mode='tennis'},
        phase=phase,ball=x and {x=x,y=10,z=1},points={0,0},games={0,0},server=1}}
end
Events.OnGameStart.callback()
check(PTClient.overlay.mouseEvents==false,'overlay does not consume mouse input')
PTClient.receive('state',snapshot(1,'rally',1,'a',5))
check(PTClient.seq==5,'resync restores acknowledged sequence')
PTClient.receive('state',snapshot(1,'rally',99))
check(PTClient.core.ball.x==1,'duplicate revision ignored')
PTClient.receive('state',snapshot(0,'rally',99))
check(PTClient.core.ball.x==1,'older revision ignored')
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
menu.submenu.options[2].callback(menu.submenu.options[2].target,menu.submenu.options[2].arg)
check(PTClient.draft[1].x==1 and PTClient.draft[2].y==2,'context corners use selected square')
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
check(PTClient.previousBall==nil,'bounce discontinuity discards interpolation')
-- Native UI emits OnMouseDown only for an unconsumed world left press.
local p=ClientMock.player
ClientMock.buttons={[0]=true,[1]=true}
ClientMock.mouseX=5
Events.OnPlayerUpdate.callback(p)
check(p.banned and PTClient.attackGuard,'native attack disabled before input for tennis aiming')
local before=#ClientMock.sent
Events.OnMouseDown.callback()
local stroke=ClientMock.sent[#ClientMock.sent]
check(#ClientMock.sent==before+1 and stroke.command=='swing','RMB plus world LMB sends a rally swing')
check(math.abs(stroke.args.aim-1/2.4)<0.000001,'world cursor maps to continuous lateral aim')
Events.OnPlayerUpdate.callback(p); Events.OnPlayerUpdate.callback(p)
check(#ClientMock.sent==before+1,'holding buttons or UI-consumed click does not auto-fire')
ClientMock.buttons[1]=false
Events.OnMouseDown.callback()
check(#ClientMock.sent==before+1,'left without right does not send a tennis stroke')
Events.OnPlayerUpdate.callback(p)
check(p.banned,'held left is drained after right release to prevent delayed combat')
ClientMock.buttons[0]=false
Events.OnPlayerUpdate.callback(p)
check(not p.banned and not PTClient.attackGuard,'normal combat restored after both buttons released')
local ready=snapshot(5,'ready',nil,'b'); ready.core.shotId=2
PTClient.receive('state',ready)
ClientMock.buttons={[0]=true,[1]=true}; ClientMock.mouseX=6.4
Events.OnMouseDown.callback()
stroke=ClientMock.sent[#ClientMock.sent]
check(stroke.command=='serve' and math.abs(stroke.args.aim-0.5)<0.000001,'ready left click serves into mouse-selected service target')
ClientMock.mouseX=999
Events.OnMouseDown.callback()
check(ClientMock.sent[#ClientMock.sent].args.aim==1,'cursor outside court clamps target on server-compatible range')
before=#ClientMock.sent; ClientMock.focused=true
Events.OnMouseDown.callback()
check(#ClientMock.sent==before,'focused text suppresses mouse stroke')
Events.OnTick.callback(); ClientMock.focused=false
Events.OnMouseDown.callback()
check(#ClientMock.sent==before,'click that unfocuses text cannot also swing')
Events.OnTick.callback()
ClientMock.time=ClientMock.time+4000; before=#ClientMock.sent
Events.OnMouseDown.callback()
check(#ClientMock.sent==before+1 and ClientMock.sent[#ClientMock.sent].command=='sync','stale mouse input only requests sync')
PTClient.receive('left',{session='b'})
check(p.banned,'leave with held buttons waits for release')
ClientMock.buttons={}; Events.OnPlayerUpdate.callback(p)
check(not p.banned,'leave restores old combat state after release')
before=#ClientMock.sent; ClientMock.buttons={[0]=true,[1]=true}
Events.OnMouseDown.callback(); Events.OnPlayerUpdate.callback(p)
check(#ClientMock.sent==before and not p.banned,'outside a session mouse and combat remain untouched')
p.banned=true
PTClient.receive('state',snapshot(1,'ready',nil,'c'))
Events.OnPlayerUpdate.callback(p); ClientMock.buttons={}; Events.OnPlayerUpdate.callback(p)
check(p.banned and not PTClient.attackGuard,'preexisting attack ban is restored instead of cleared')
p.banned=false; p.noRacket=true; ClientMock.buttons={[0]=true,[1]=true}; before=#ClientMock.sent
Events.OnPlayerUpdate.callback(p); Events.OnMouseDown.callback()
check(not p.banned and #ClientMock.sent==before,'unequipped racket does not claim mouse or combat')
p.noRacket=false; Events.OnPlayerUpdate.callback(p)
check(p.banned,'equipped racket reacquires native attack gate')
Events.OnDisconnect.callback()
check(not p.banned and not PTClient.session,'disconnect unconditionally restores gate')
PTClient.receive('state',snapshot(2,'ready',nil,'c'))
check(not PTClient.session,'late state cannot resurrect disconnected session')
PTClient.receive('state',snapshot(1,'ready',nil,'d')); Events.OnPlayerUpdate.callback(p)
Events.OnPlayerDeath.callback(p)
check(not p.banned and not PTClient.session,'death restores attack gate and clears session')
PTClient.receive('state',snapshot(1,'ready',nil,'e')); Events.OnPlayerUpdate.callback(p)
Events.OnMainMenuEnter.callback()
check(not p.banned and not PTClient.session,'return to menu releases held guard')
print('PASS client checks: '..checks)
