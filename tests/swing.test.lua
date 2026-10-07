checks=0
local function check(value,label) checks=checks+1; if not value then error(label) end end
local p={kind="PlayableTennis.SportsTennisRacket"}
function p:getPrimaryHandItem() return {getFullType=function() return self.kind end} end
function p:isDead() return self.dead end
function p:getVehicle() return self.vehicle end
function p:getVariableString(name) return name=="PerformingAction" and "RemoveBushLongBlade" or "holdingbagright" end
check(PTSwing.play(p,1000),"first cosmetic swing")
local action=SwingMock.queue.queue[1]
action.action={setUseProgressBar=function(self,value) self.progress=value end,
    setBlockMovementEtc=function(self,value) self.block=value end}
action:start()
check(action.anim=="RemoveBushLongBlade" and not action.models,"native one-handed animation without hand model substitution")
check(action.variables.PT_RacketStroke==true,"owned movement mask is scoped to tennis action")
action:animEvent("Chop",nil)
check(action.anim=="RemoveBushLongBlade" and not PT_SwingAction.complete,"native chop event has no world mutation callback")
local samples=0
function p:getAnimationDebug() samples=samples+1; return 'Native RemoveBushLongBlade Variables: ignored' end
for i=1,8 do action:update() end
check(samples==1,"playback diagnostic samples layers once after animation evaluation")
check(action.action.progress==false and action.action.block==false,"no progress bar or movement block")
check(not action.stopOnAim and not action.stopOnWalk and not action.stopOnRun,"movement and aim remain enabled")
check(action.maxTime/30==1 and action:adjustMaxTime(30)==30,"one second motion independent of moodles")
check(not PT_SwingAction.complete,"cosmetic action uses remote animation sync, no server mutation")
SwingMock.queue.queue={}
check(not PTSwing.play(p,1249),"rapid click throttled")
local ok, reason = PTSwing.play(p,1249)
check(not ok and reason=="cooldown","cooldown suppression is identifiable")
check(PTSwing.play(p,1250),"next cooldown eligible")
check(not PTSwing.play(p,1500),"never queue behind existing action")
ok, reason = PTSwing.play(p,1500)
check(not ok and reason=="swing-active","one second follow-through is not cut short by repeat clicks")
SwingMock.queue.queue={{}}
ok, reason = PTSwing.play(p,1500)
check(not ok and reason=="busy","real action queue suppression is identifiable")
SwingMock.queue.queue={}
p.kind="Base.TennisRacket"
check(not PTSwing.play(p,1500),"weapon racket excluded")
p.kind="PlayableTennis.SportsTennisRacket"; p.dead=true
check(not PTSwing.play(p,1500),"dead player excluded")
p.dead=false; p.vehicle=true
check(not PTSwing.play(p,1500),"vehicle excluded")
