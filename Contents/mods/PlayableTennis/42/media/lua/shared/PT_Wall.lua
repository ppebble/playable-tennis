-- Cardinal walls use their owning square's north/west edge. All ball simulation
-- stays in a local frame with the wall at y=0 and the player on positive y.
PTWall = {}
local W = PTWall
local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
local function flag(sq,name) return IsoFlagType[name] and sq:has(IsoFlagType[name]) end
local function solidWall(sq,edge)
    return sq and flag(sq,"Wall"..edge) and not flag(sq,"Window"..edge)
        and not flag(sq,"DoorWall"..edge) and not flag(sq,"Hoppable"..edge)
        and not flag(sq,"window"..edge)
end
local function floorClear(sq)
    return sq and sq:getFloor() and not sq:isSolid() and not sq:isSolidTrans() and not flag(sq,"water")
end
local function blocked(sq,edge)
    return not sq or flag(sq,"collide"..edge) or flag(sq,"Wall"..edge)
        or flag(sq,"Window"..edge) or flag(sq,"DoorWall"..edge) or flag(sq,"Hoppable"..edge)
end
function W.toLocal(c,x,y)
    local f=c.frame
    if not f then return x,y end
    local dx,dy=x-f.originX,y-f.originY
    return dx*f.ux+dy*f.uy,dx*f.vx+dy*f.vy
end
function W.toWorld(c,x,y)
    local f=c.frame
    if not f then return x,y end
    return f.originX+x*f.ux+y*f.vx,f.originY+x*f.uy+y*f.vy
end
function W.localBounds(c,y)
    local flare=c.freeWall and math.max(0,math.min(14,y))/14*4 or 0
    return c.x1-flare,c.x2+flare
end
function W.containsLocal(c,x,y,margin)
    margin=margin or 0
    local left,right=W.localBounds(c,y)
    return x>=left-margin and x<=right+margin and y>=c.y1-margin and y<=c.y2+margin
end
function W.contains(c,x,y,margin)
    x,y=W.toLocal(c,x,y)
    return W.containsLocal(c,x,y,margin)
end
-- Grid traversal checks both edges at a corner, avoiding diagonal passage
-- through walls. It deliberately does not require a registered clear rectangle.
function W.lineClear(x1,y1,x2,y2,z,getSquare)
    local cx,cy=math.floor(x1),math.floor(y1)
    local ex,ey=math.floor(x2),math.floor(y2)
    if not floorClear(getSquare(cx,cy,z)) then return false end
    local dx,dy=x2-x1,y2-y1
    local sx,sy=dx>=0 and 1 or -1,dy>=0 and 1 or -1
    local tx=dx==0 and math.huge or ((sx>0 and cx+1 or cx)-x1)/dx
    local ty=dy==0 and math.huge or ((sy>0 and cy+1 or cy)-y1)/dy
    local stepx=dx==0 and math.huge or math.abs(1/dx)
    local stepy=dy==0 and math.huge or math.abs(1/dy)
    for i=1,128 do
        if cx==ex and cy==ey then return true end
        local crossX,crossY=tx<=ty+0.00000001,ty<=tx+0.00000001
        if crossX then
            if blocked(getSquare(sx>0 and cx+1 or cx,cy,z),"W") then return false end
            if not floorClear(getSquare(cx+sx,cy,z)) then return false end
        end
        if crossY then
            if blocked(getSquare(cx,sy>0 and cy+1 or cy,z),"N") then return false end
            if not floorClear(getSquare(cx,cy+sy,z)) then return false end
        end
        if crossX and crossY then
            -- A corner has four incident edges, including the two beside the
            -- destination. Checking only the source legs permits corner leaks.
            if blocked(getSquare(sx>0 and cx+1 or cx,cy+sy,z),"W")
                or blocked(getSquare(cx+sx,sy>0 and cy+1 or cy,z),"N") then return false end
        end
        if crossX then cx=cx+sx; tx=tx+stepx end
        if crossY then cy=cy+sy; ty=ty+stepy end
        if not floorClear(getSquare(cx,cy,z)) then return false end
    end
    return false
end
function W.valid(c,getSquare,px,py)
    local wall=c.wall
    if not wall then return false,"Wall practice has no selected wall." end
    for offset=wall.minOffset,wall.maxOffset do
        local x=wall.tilex+(wall.edge=="N" and offset or 0)
        local y=wall.tiley+(wall.edge=="W" and offset or 0)
        if not solidWall(getSquare(x,y,c.z),wall.edge) then
            return false,"The practice wall is unloaded, damaged or no longer solid."
        end
    end
    if px~=nil and py~=nil then
        local lx,depth=W.toLocal(c,px,py)
        if depth<=0 then return false,"Stay on the selected side of the practice wall." end
        -- A blocked route to the middle does not make an open end unusable.
        local nearest=math.max(c.wallMinX+0.05,math.min(c.wallMaxX-0.05,lx))
        local tx,ty=W.toWorld(c,nearest,0.05)
        local clear=W.lineClear(px,py,tx,ty,c.z,getSquare)
        for offset=wall.minOffset,wall.maxOffset do
            if clear then break end
            tx,ty=W.toWorld(c,offset,0.05)
            clear=W.lineClear(px,py,tx,ty,c.z,getSquare)
        end
        if not clear then return false,"No clear route to this wall. Move past obstacles onto loaded floor." end
    end
    return true
end
function W.select(px,py,z,args,getSquare)
    if not finite(px) or not finite(py) or not finite(z) or z~=math.floor(z)
        or type(args)~="table" or not finite(args.x) or not finite(args.y)
        or args.x~=math.floor(args.x) or args.y~=math.floor(args.y)
        or math.abs(args.x)>1000000 or math.abs(args.y)>1000000
        or (args.edge~="N" and args.edge~="W") or (args.z~=nil and args.z~=z) then
        return nil,"Invalid wall selection."
    end
    local x,y,edge=args.x,args.y,args.edge
    if not solidWall(getSquare(x,y,z),edge) then return nil,"Choose a solid wall without doors, windows or fences." end
    local ox,oy=x+(edge=="N" and 0.5 or 0),y+(edge=="W" and 0.5 or 0)
    local depth=edge=="N" and py-oy or px-ox
    if math.abs(depth)>14 or math.abs(depth)<1 then return nil,"Stand 1 to 14 tiles from the wall, measured straight out from its face." end
    local sign=depth>0 and 1 or -1
    local c={mode="wall",freeWall=true,z=z,y1=0,y2=14,
        frame={originX=ox,originY=oy,ux=edge=="N" and 1 or 0,uy=edge=="W" and 1 or 0,
            vx=edge=="W" and sign or 0,vy=edge=="N" and sign or 0},
        wall={tilex=x,tiley=y,edge=edge,minOffset=0,maxOffset=0}}
    c.x1,c.x2=-2,2
    for _,direction in ipairs({-1,1}) do
        for n=1,4 do
            local offset=n*direction
            if not solidWall(getSquare(x+(edge=="N" and offset or 0),y+(edge=="W" and offset or 0),z),edge) then break end
            if direction<0 then c.wall.minOffset=offset else c.wall.maxOffset=offset end
        end
    end
    c.wallMinX,c.wallMaxX=c.wall.minOffset-0.5,c.wall.maxOffset+0.5
    c.x1,c.x2=math.min(c.x1,c.wallMinX),math.max(c.x2,c.wallMaxX)
    if not W.contains(c,px,py,0) then return nil,"Move closer sideways to the selected wall's practice area." end
    local valid,reason=W.valid(c,getSquare,px,py)
    if not valid then return nil,reason end
    return c
end
function W.find(px,py,z,wx,wy,getSquare)
    if not finite(wx) or not finite(wy) or not finite(px) or not finite(py) or not finite(z) or z~=math.floor(z)
        or math.abs(wx-px)>20 or math.abs(wy-py)>20 then return nil,"Aim near a solid wall within 14 tiles of its face." end
    local best,bestDistance,reason,reasonDistance
    for x=math.floor(wx)-3,math.floor(wx)+3 do
        for y=math.floor(wy)-3,math.floor(wy)+3 do
            for _,edge in ipairs({"N","W"}) do
                if solidWall(getSquare(x,y,z),edge) then
                    local c,err=W.select(px,py,z,{x=x,y=y,edge=edge},getSquare)
                    if c then
                        local ox,oy=c.frame.originX,c.frame.originY
                        local distance=(wx-ox)^2+(wy-oy)^2
                        if not bestDistance or distance<bestDistance then best,bestDistance=c,distance end
                    else
                        local distance=(wx-x)^2+(wy-y)^2
                        if not reasonDistance or distance<reasonDistance then reason,reasonDistance=err,distance end
                    end
                end
            end
        end
    end
    if best then return best end
    return nil,reason or "Aim near a solid wall on your floor; doors, windows and fences cannot be used."
end
return PTWall
