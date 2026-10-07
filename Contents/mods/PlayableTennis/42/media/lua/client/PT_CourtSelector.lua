require "BuildingObjects/ISBuildingObject"

PTCourtSelector = PTCourtSelector or {}
local S = PTCourtSelector
local Cursor = ISBuildingObject:derive("PT_CourtSelectionCursor")

-- Use the ranch designation's native area highlight, with inclusive picked
-- tiles converted to exclusive far edges only once at this boundary.
function S.rectangle(x1, y1, x2, y2, z)
    local r = {x1=math.min(x1,x2), y1=math.min(y1,y2),
        x2=math.max(x1,x2)+1, y2=math.max(y1,y2)+1, z=z, mode="tennis"}
    local w, h = r.x2-r.x1, r.y2-r.y1
    return r, w>=6 and w<=14 and h>=12 and h<=30
end

function S.isActive()
    return S.cursor ~= nil
end

function S.blocksInput()
    return S.isActive() or getTimestampMs() < (S.blockedUntil or 0)
end

function S.cancel()
    local cursor = S.cursor
    if not cursor then return end
    S.blockedUntil = getTimestampMs() + 250
    S.cursor = nil
    if getCell():getDrag(cursor.player) == cursor then
        getCell():setDrag(nil, cursor.player)
    end
end

function Cursor:deactivate()
    if S.cursor == self then
        S.blockedUntil = getTimestampMs() + 250
        S.cursor = nil
    end
end

function Cursor:isValid(square)
    if not square or square:getZ() ~= self.z or self.character:isDead() then return false end
    if not self.startX then return true end
    local _, valid = S.rectangle(self.startX,self.startY,square:getX(),square:getY(),self.z)
    return valid
end

-- No building action, walking, item consumption, or native world mutation.
function Cursor:tryBuild(x,y,z)
    self:create(x,y,z)
end

function Cursor:create(x,y,z)
    if z ~= self.z then return end
    if not self.startX then
        self.startX,self.startY = x,y
        return
    end
    local r, valid = S.rectangle(self.startX,self.startY,x,y,z)
    if not valid then return end
    local callback = self.callback
    S.cancel()
    callback(r)
end

function Cursor:render(x,y,z,square)
    if z ~= self.z then return end
    local r, valid = S.rectangle(self.startX or x,self.startY or y,x,y,z)
    local red,green = 0.2,0.9
    if self.startX and not valid then red,green=1,0.2 end
    addAreaHighlightForPlayer(self.player,r.x1,r.y1,r.x2,r.y2,z,red,green,0.3,0.45)
    if getTextManager and getMouseX then
        local label = tostring(r.x2-r.x1).." x "..tostring(r.y2-r.y1).."  (6-14 x 12-30)"
        getTextManager():DrawString(UIFont.Small,getMouseX()+18,getMouseY()+18,label,red,green,0.3,1)
    end
end

function S.begin(character, callback)
    if not character or character:isDead() or type(callback)~="function" then return false end
    S.cancel()
    local cursor = setmetatable({}, {__index=Cursor})
    cursor:init()
    cursor.character,cursor.player = character,character:getPlayerNum()
    cursor.z = math.floor(character:getZ())
    cursor.callback = callback
    cursor.noNeedHammer,cursor.skipBuildAction = true,true
    cursor.rightWasDown = isMouseButtonDown(1)
    S.cursor = cursor
    getCell():setDrag(cursor,cursor.player)
    return true
end

local function update()
    local cursor = S.cursor
    if not cursor then return end
    local right = isMouseButtonDown(1)
    if cursor.character:isDead() or math.floor(cursor.character:getZ())~=cursor.z
        or (right and not cursor.rightWasDown) then S.cancel(); return end
    cursor.rightWasDown = right
end

Events.OnTick.Add(update)
Events.OnKeyPressed.Add(function(key)
    if key==Keyboard.KEY_ESCAPE then S.cancel() end
end)
Events.OnDisconnect.Add(S.cancel)
Events.OnMainMenuEnter.Add(S.cancel)
