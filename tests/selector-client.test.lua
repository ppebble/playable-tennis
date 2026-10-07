local limits=PTCore.courtLimits
local endX,endY=10+limits.minWidth-1,20+limits.minLength-1
checks=0
local function check(value,message) checks=checks+1; assert(value,message) end
Events.OnGameStart.fire()
check(PTClient.overlay~=nil,"startup completes with real selector")
for i=1,120 do Events.OnTick.fire() end
check(not PTCourtSelector.blocksInput(),"idle input works without server building globals")
check(ISBuildingObject==nil,"no hidden server dependency")
local result
PTCourtSelector.begin(ClientMock.player,function(r) result=r end)
Events.OnTick.fire()
check(PTCourtSelector.blocksInput(),"real selector blocks gameplay")
local sent=#ClientMock.sent
ClientMock.buttons={[0]=true,[1]=true}
Events.OnMouseDown.fire(10,20)
Events.OnMouseDown.fire(endX,endY)
check(#ClientMock.sent==sent,"selector clicks cannot start wall practice through client handler")
check(result and result.x2==endX+1 and result.y2==endY+1,"real selection submits rectangle")
ClientMock.time=ClientMock.time+251
Events.OnTick.fire()
check(not PTCourtSelector.blocksInput(),"input restored after confirmation")
PTCourtSelector.begin(ClientMock.player,function()error("cancel submitted")end)
Events.OnDisconnect.fire()
check(not PTCourtSelector.isActive() and PTClient.overlay==nil,"shared disconnect cleans both modules")
Events.OnGameStart.fire()
Events.OnTick.fire()
check(PTClient.overlay~=nil,"restart completes")
