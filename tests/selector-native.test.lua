local limits=PTCore.courtLimits
local endX,endY=10+limits.minWidth-1,20+limits.minLength-1
checks=0
local S,M=PTCourtSelector,SelectorMock
local function check(v,m) checks=checks+1; assert(v,m) end
local function square(x,y) return {getX=function()return x end,getY=function()return y end,getZ=function()return 0 end} end
local result
S.begin(M.player,function(r) result=r end)
local cursor=S.cursor
local function dispatch(x,y)
    DoTileBuilding(cursor,true,x,y,0,square(x,y))
    M.events.OnDoTileBuilding2(cursor,true,x,y,0,square(x,y))
end
dispatch(10,20)
M.down=true; dispatch(10,20)
M.down=false; M.released=true; dispatch(10,20)
check(cursor.startX==10 and not result,"vanilla dispatcher accepts first corner once")
M.released=false; dispatch(endX,endY)
M.down=true; dispatch(endX,endY)
M.down=false; M.released=true; dispatch(endX,endY)
check(result and result.x2==endX+1 and result.y2==endY+1,"vanilla dispatcher submits second corner")
check(not S.isActive() and not M.cell.drag,"vanilla dispatch clears cursor")
S.begin(M.player,function()end)
M.cell:setDrag({})
check(not S.isActive(),"raw deactivation clears selector")
