local function check(v,msg) checks=(checks or 0)+1; assert(v,msg) end
IsoFlagType=setmetatable({}, {__index=function(t,k) return k end})
local squares={}
local function square(x,y,z)
    local key=x..","..y..","..z
    if squares[key]==false then return nil end
    if not squares[key] then
        local s={flags={}}
        function s:has(k) return self.flags[k] or false end
        function s:getFloor() return not self.noFloor end
        function s:isSolid() return self.solid or false end
        function s:isSolidTrans() return false end
        squares[key]=s
    end
    return squares[key]
end
local function setup(edge)
    squares={}; square(10,10,0).flags["Wall"..edge]=true
end
for _,edge in ipairs({"N","W"}) do
    for _,side in ipairs({-1,1}) do
        setup(edge)
        local px=edge=="N" and 10.5 or 10+side*4
        local py=edge=="W" and 10.5 or 10+side*4
        local c,err=PTWall.select(px,py,0,{x=10,y=10,edge=edge},square)
        check(c~=nil,"cardinal face accepts: "..tostring(err))
        local lx,ly=PTWall.toLocal(c,px,py)
        check(lx==0 and ly==4,"positive local depth for either wall side")
        local wx,wy=PTWall.toWorld(c,lx,ly)
        check(wx==px and wy==py,"world local inverse")
        check(PTWall.contains(c,px,py,0),"world proximity uses local frame")
        check(c.wallMinX==-0.5 and c.wallMaxX==0.5,"single tile wall supported")
        check(PTWall.valid(c,square),"selected segment valid")
        square(10,10,0).flags["Wall"..edge]=nil
        check(not PTWall.valid(c,square),"destroyed wall invalidates")
    end
end
for _,bad in ipairs({"WindowN","DoorWallN","HoppableN"}) do
    setup("N"); square(10,10,0).flags[bad]=true
    check(not PTWall.select(10.5,14,0,{x=10,y=10,edge="N"},square),"reject "..bad)
end
setup("N")
check(not PTWall.select(10.5,10.5,0,{x=10,y=10,edge="N"},square),"too close")
check(not PTWall.select(10.5,19,0,{x=10,y=10,edge="N"},square),"too far")
check(not PTWall.select(10.5,14,0,{x=10,y=10,z=1,edge="N"},square),"different floor")
square(10,12,0).flags.collideN=true
check(not PTWall.select(10.5,14,0,{x=10,y=10,edge="N"},square),"intermediate wall blocks route")
setup("N"); square(10,12,0).solid=true
check(not PTWall.select(10.5,14,0,{x=10,y=10,edge="N"},square),"solid object blocks route")
setup("N"); squares["10,12,0"]=false
check(not PTWall.select(10.5,14,0,{x=10,y=10,edge="N"},square),"unloaded route rejected")
setup("N"); square(10,12,0).noFloor=true
check(not PTWall.select(10.5,14,0,{x=10,y=10,edge="N"},square),"missing floor rejected")
setup("N"); square(9,10,0).flags.WallN=true; square(11,10,0).flags.WallN=true
local c=PTWall.select(10.5,14,0,{x=10,y=10,edge="N"},square)
check(c.wallMinX==-1.5 and c.wallMaxX==1.5,"contiguous wall span expanded")
square(9,10,0).flags.WindowN=true
check(not PTWall.valid(c,square),"changed endpoint invalidates span")
setup("N"); square(8,10,0).flags.WallN=true
c=PTWall.select(10.5,14,0,{x=10,y=10,edge="N"},square)
check(c.wallMinX==-0.5,"does not cross hole to another wall")
setup("N")
local found,err=PTWall.find(10.5,14,0,10.4,10.1,square)
check(found~=nil and err==nil,"mouse endpoint finds nearby wall")
check(found.wall.tilex==10 and found.wall.tiley==10 and found.wall.edge=="N","find selected owning edge")
check(not PTWall.find(10.5,14,0,999,999,square),"distant mouse endpoint rejected")
check(PTWall.valid(found,square,10.5,14),"current player clear corridor accepted")
check(not PTWall.valid(found,square,10.5,8),"crossing behind original face rejected")
square(10,12,0).flags.collideN=true
check(not PTWall.valid(found,square,10.5,14),"new obstruction invalidates current corridor")
setup("N")
square(11,12,0).flags.collideW=true
check(not PTWall.lineClear(10.5,12.5,12.5,12.5,0,square),"west boundary crossing blocked")
check(not PTWall.lineClear(12.5,12.5,10.5,12.5,0,square),"west boundary blocked reverse")
setup("N")
c=PTWall.select(10.5,14,0,{x=10,y=10,edge="N"},square)
check(c.y2==8,"free wall play area includes four tiles behind starting position")
local ok,message=PTWall.valid({},square)
check(not ok and type(message)=="string","missing wall reports reason")
ok,message=PTWall.valid(c,square,10.5,8)
check(not ok and type(message)=="string","wrong side reports reason")
square(10,12,0).solid=true
ok,message=PTWall.valid(c,square,10.5,14)
check(not ok and type(message)=="string","blocked route reports reason")
square(10,10,0).flags.WallN=false
ok,message=PTWall.valid(c,square)
check(not ok and type(message)=="string","changed wall reports reason")
for _,sx in ipairs({-1,1}) do
    for _,sy in ipairs({-1,1}) do
        local ax,ay=20.5,20.5
        local bx,by=ax+sx,ay+sy
        squares={}
        check(PTWall.lineClear(ax,ay,bx,by,0,square),"clear diagonal accepted")
        square(sx>0 and 21 or 20,20+sy,0).flags.WallW=true
        check(not PTWall.lineClear(ax,ay,bx,by,0,square),"destination west leg blocks diagonal")
        squares={}
        square(20+sx,sy>0 and 21 or 20,0).flags.WallN=true
        check(not PTWall.lineClear(ax,ay,bx,by,0,square),"destination north leg blocks diagonal")
    end
end
print("PASS wall geometry checks: "..checks)
