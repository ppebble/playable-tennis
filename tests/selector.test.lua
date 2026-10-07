local limits=PTCore.courtLimits
local endX,endY=10+limits.minWidth-1,20+limits.minLength-1
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
cursor:render(endX,endY,0)
local h=cursor.preview.court
check(h.x1==10 and h.y1==20 and h.x2==endX+1 and h.y2==endY+1,"inclusive outline preview")
check(#M.highlights==0,"selection never fills the court")
check(cursor:isValid(square(endX,endY,0)),"minimum allowed rectangle")
check(not cursor:isValid(square(endX-1,endY,0)),"width too small")
check(not cursor:isValid(square(10+limits.maxWidth,endY,0)),"width too large")
check(not cursor:isValid(square(endX,endY-1,0)),"length too small")
check(not cursor:isValid(square(endX,20+limits.maxLength,0)),"length too large")
check(not cursor:isValid(square(endX,endY,1)),"other floor")
cursor:create(endX,endY,1)
check(not result,"wrong-floor click ignored")
cursor:create(endX-1,endY,0)
check(not result and S.isActive(),"invalid click retains selection")
cursor:create(endX,endY,0)
check(result and result.x2==endX+1 and result.y2==endY+1 and result.mode=="tennis","callback bounds")
check(not S.isActive() and not M.cell.drag,"completion clears cursor")
check(S.blocksInput(),"completion click cannot leak into gameplay")
M.time=M.time+249
check(S.blocksInput(),"completion input guard lasts 250ms")
M.time=M.time+1
check(not S.blocksInput(),"completion input guard expires")
local r,valid=S.rectangle(10+limits.maxWidth-1,20+limits.maxLength-1,10,20,0)
check(valid and r.x1==10 and r.y1==20 and r.x2==10+limits.maxWidth and r.y2==20+limits.maxLength,"reverse maximum corners")
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
-- Exercise the engine event, not just direct helper calls, on a remote client.
S.begin(M.player,function(r) result=r end)
local active=S.cursor
result=nil
M.events.OnDoTileBuilding2(active,true,10,20,0,square(10,20,0))
check(not active.startX,"render does not select without a release")
M.events.OnMouseDown(10,20)
check(active.startX==10,"native mouse event selects first corner")
M.events.OnDoTileBuilding2(active,false,endX,endY,1,square(endX,endY,1))
check(not result,"native event cannot select another floor")
M.events.OnMouseDown(endX,endY)
check(result and not S.isActive(),"native mouse event submits remote-client court")
S.begin(M.player,function()error("duplicate dispatcher")end)
DoTileBuilding=function()end
M.events.OnDoTileBuilding2(S.cursor,false,10,20,0,square(10,20,0))
check(not S.cursor.startX,"fallback defers to existing vanilla dispatcher")
DoTileBuilding=nil
S.cancel()
local allowed=false
S.begin(M.player,function()error("invalid registration")end,function()return allowed,"Blocked floor" end)
S.cursor:create(10,20,0)
S.cursor:render(endX,endY,0)
check(S.cursor.preview.red==1,"blocked floor preview is red despite valid size")
S.cursor:create(endX,endY,0)
check(S.isActive(),"invalid confirmation keeps selection open")
allowed=true; M.time=M.time+201
S.cursor:render(endX,endY,0)
check(S.cursor.preview.green==0.9,"clear floor refreshes to green")
allowed=false
S.cursor:create(endX,endY,0)
check(S.isActive(),"confirmation revalidates even a cached green preview")
S.cancel()
