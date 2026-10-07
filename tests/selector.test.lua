local S,M=PTCourtSelector,SelectorMock
checks=0
local function check(v,message) checks=checks+1; if not v then error(message) end end
local function square(x,y,z) return {getX=function()return x end,getY=function()return y end,getZ=function()return z end} end
local result
S.cancel()
check(not S.blocksInput(),"idle cancel does not block gameplay")
check(S.begin(M.player,function(r) result=r end),"begin")
local cursor=M.cell.drag
check(S.isActive(),"active")
check(S.blocksInput(),"selection blocks gameplay")
cursor:create(10,20,0)
cursor:render(15,31,0)
local h=M.highlights[#M.highlights]
check(h[2]==10 and h[3]==20 and h[4]==16 and h[5]==32,"inclusive native highlight")
check(cursor:isValid(square(15,31,0)),"minimum allowed rectangle")
check(not cursor:isValid(square(14,31,0)),"width too small")
check(not cursor:isValid(square(24,31,0)),"width too large")
check(not cursor:isValid(square(15,30,0)),"length too small")
check(not cursor:isValid(square(15,50,0)),"length too large")
check(not cursor:isValid(square(15,31,1)),"other floor")
cursor:create(15,31,1)
check(not result,"wrong-floor click ignored")
cursor:create(14,31,0)
check(not result and S.isActive(),"invalid click retains selection")
cursor:create(15,31,0)
check(result and result.x2==16 and result.y2==32 and result.mode=="tennis","callback bounds")
check(not S.isActive() and not M.cell.drag,"completion clears cursor")
check(S.blocksInput(),"completion click cannot leak into gameplay")
M.time=M.time+249
check(S.blocksInput(),"completion input guard lasts 250ms")
M.time=M.time+1
check(not S.blocksInput(),"completion input guard expires")
local r,valid=S.rectangle(23,49,10,20,0)
check(valid and r.x1==10 and r.y1==20 and r.x2==24 and r.y2==50,"reverse maximum corners")
S.begin(M.player,function()error("cancel callback")end)
M.events.OnKeyPressed(Keyboard.KEY_ESCAPE)
check(not S.isActive(),"escape cancels")
check(S.blocksInput(),"cancel temporarily blocks gameplay")
M.time=M.time+250
check(not S.blocksInput(),"cancel input guard expires")
S.begin(M.player,function()end)
M.right=true; M.events.OnTick()
check(not S.isActive(),"rightclick cancels")
S.begin(M.player,function()end)
M.events.OnTick()
check(S.isActive(),"context-menu held right does not cancel immediately")
M.right=false; M.events.OnTick(); M.right=true; M.events.OnTick()
check(not S.isActive(),"next rightclick cancels")
M.right=false
S.begin(M.player,function()end)
M.player.z=1; M.events.OnTick()
check(not S.isActive(),"floor change cancels")
M.player.z=0
S.begin(M.player,function()end)
M.cell:setDrag({deactivate=function()end})
check(not S.isActive(),"native cursor replacement clears active state")
S.cancel()
check(M.cell.drag~=nil,"cancel preserves another native cursor")
S.begin(M.player,function()end)
M.events.OnDisconnect()
check(not S.isActive(),"disconnect cancels")
check(not S.begin(nil,function()end),"invalid player rejected")
