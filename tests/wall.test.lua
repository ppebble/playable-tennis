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
        check(c.y2-c.y1==14,"fourteen tile practice depth on every wall face")
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
check(not PTWall.select(10.5,24.1,0,{x=10,y=10,edge="N"},square),"too far")
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
check(c.y2==14,"free wall play area has fixed fourteen tile depth")
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
-- Facade windows/columns must split a wall, never move practice upstairs.
setup("N")
square(11,10,0).flags.WallN=true
square(12,10,0).flags.WallN=true; square(12,10,0).flags.WindowN=true
square(9,9,0).flags.WallN=true
for x=8,14 do square(x,10,1).flags.WallN=true end
local facade=PTWall.select(10.5,14,0,{x=10,y=10,edge="N"},square)
check(facade and facade.z==0,"facade practice stays at player floor despite upstairs wall")
check(facade.wallMaxX-facade.wallMinX==2,"two solid facade tiles stop at window and recessed column")
setup("N")
for x=8,13 do square(x,10,0).flags.WallN=true end
local wide=PTWall.select(10.5,14,0,{x=10,y=10,edge="N"},square)
check(wide.wallMaxX-wide.wallMinX==5,"long wall is capped at five selected tiles")
for _,distance in ipairs({1,2,8,14}) do
    local depthCourt=PTWall.select(10.5,10+distance,0,{x=10,y=10,edge="N"},square)
    check(depthCourt and depthCourt.y2==14,"practice depth independent of starting distance "..distance)
end
local trap=PTWall.select(10.5,24,0,{x=10,y=10,edge="N"},square)
local left,right=PTWall.localBounds(trap,0)
check(left==trap.x1 and right==trap.x2,"wall end has unchanged baseline width")
left,right=PTWall.localBounds(trap,7)
check(left==trap.x1-1 and right==trap.x2+1,"mid depth adds one tile per side")
left,right=PTWall.localBounds(trap,14)
check(left==trap.x1-2 and right==trap.x2+2,"rear adds two tiles per side")
check(PTWall.containsLocal(trap,right,14,0),"rear corner can return ball")
check(not PTWall.containsLocal(trap,right+0.01,14,0),"outside trapezoid rejected")
check(not PTWall.containsLocal(trap,0,14.01,0),"perpendicular depth beyond fourteen rejected")
check(PTWall.containsLocal(trap,0,14.2,0.3),"caller margin retained")
check(PTWall.select(14.5,24,0,{x=10,y=10,edge="N"},square)~=nil,"diagonal distance exceeding fourteen is valid at depth fourteen")
check(not PTWall.select(30,24,0,{x=10,y=10,edge="N"},square),"unbounded lateral acquisition rejected")
check(PTWall.find(10.5,24,0,10.4,7.1,square)~=nil,"relaxed cursor search finds wall three squares away")
-- An obstruction on the center route must not hide an open wall endpoint.
setup("N")
for x=8,13 do square(x,10,0).flags.WallN=true end
local openEnd=PTWall.select(13.5,16,0,{x=10,y=10,edge="N"},square)
check(openEnd~=nil,"wide wall selects from side")
square(11,12,0).solid=true
check(not PTWall.lineClear(13.5,16,10.5,10.05,0,square),"fixture blocks center path")
check(PTWall.valid(openEnd,square,13.5,16),"open endpoint remains usable around center obstruction")
local blockedEnd,why=PTWall.select(13.5,16,0,{x=10,y=10,edge="N"},square)
check(blockedEnd~=nil and why==nil,"selection uses open endpoint too")
print("PASS wall geometry checks: "..checks)

-- A long facade must not widen aim or the receiving area without bound.
for _,edge in ipairs({"N","W"}) do
    for _,side in ipairs({-1,1}) do
        setup(edge)
        for offset=-8,8 do
            square(10+(edge=="N" and offset or 0),10+(edge=="W" and offset or 0),0).flags["Wall"..edge]=true
        end
        local px,py=10+(edge=="N" and .5 or side*14),10+(edge=="W" and .5 or side*14)
        local capped=PTWall.select(px,py,0,{x=10,y=10,edge=edge},square)
        check(capped and capped.wallMaxX-capped.wallMinX==5,"all four wall faces cap reflection span at five")
        local lo,hi=PTWall.localBounds(capped,14)
        check(hi-lo==9,"maximum rear width is nine tiles")
        check(not PTWall.containsLocal(capped,hi+.01,14),"former wider side area is outside practice")
    end
end

-- Real net tiles are allowed only on the correct central edge. Other fences,
-- even ones sharing a square with a tennis net, remain obstacles.
local function addNetObject(sq,name,edge)
    sq.objects=sq.objects or {}
    local props={has=function(_,flag) return flag=="Hoppable"..edge or flag=="collide"..edge end}
    sq.objects[#sq.objects+1]={getSprite=function() return {getName=function() return name end} end,
        getProperties=function() return props end}
    function sq:getObjects() return {size=function() return #self.objects end,get=function(_,i) return self.objects[i+1] end} end
    sq.flags["Hoppable"..edge]=true; sq.flags["collide"..edge]=true
end
for _,edge in ipairs({"N","W"}) do
    local c={mode="tennis",x1=0,y1=0,x2=edge=="N" and 10 or 18,y2=edge=="N" and 18 or 10,z=0}
    local first=edge=="N" and 49 or 52
    for index=first,first+2 do
        squares={}
        local x,y=edge=="N" and 5 or 9,edge=="N" and 9 or 5
        addNetObject(square(x,y,0),"recreational_sports_01_"..index,edge)
        -- A real square includes its floor before the net; B42 exposes has, not Is.
        table.insert(square(x,y,0).objects,1,{
            getSprite=function() return {getName=function() return "floors_exterior_tilesandstone_01_0" end} end,
            getProperties=function() return {has=function() return false end} end})
        check(PTWall.validateCourt(c,square),"native net segment allowed on matching center edge")
        addNetObject(square(x,y,0),"fencing_01_0",edge)
        check(not PTWall.validateCourt(c,square),"co-located ordinary fence cannot hide behind net exception")
        squares={}
        addNetObject(square(x+(edge=="W" and 1 or 0),y+(edge=="N" and 1 or 0),0),"recreational_sports_01_"..index,edge)
        check(not PTWall.validateCourt(c,square),"off-center tennis net is rejected")
    end
    squares={};addNetObject(square(5,5,0),"fencing_01_0",edge)
    check(not PTWall.validateCourt(c,square),"ordinary low fence remains blocked")
end
squares={}
local framed={mode="tennis",x1=100,y1=200,x2=110,y2=218,z=0,
    frame={originX=0,originY=0,ux=0,uy=1,vx=1,vy=0}}
addNetObject(square(209,105,0),"recreational_sports_01_53","W")
check(PTWall.validateCourt(framed,square),"canonical court validates center net in world coordinates")
square(208,105,0).solid=true
check(not PTWall.validateCourt(framed,square),"rotated world solid furniture still blocks court")
