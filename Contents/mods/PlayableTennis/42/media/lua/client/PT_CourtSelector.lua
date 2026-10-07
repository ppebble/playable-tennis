require "PT_Core"
PTCourtSelector = PTCourtSelector or {}
local S = PTCourtSelector
-- Remote clients cannot require server/BuildingObjects/ISBuildingObject.
-- Own only the native drag callbacks needed for a non-building selection.
local Cursor = {}
function Cursor:rotateMouse() end
function Cursor:rotateKey() end
function Cursor:getSprite() return nil end
function Cursor:reinit() self.build=false end
function Cursor:getAPrompt() return nil end
function Cursor:getBPrompt() return nil end
function Cursor:getYPrompt() return nil end
function Cursor:getLBPrompt() return nil end
function Cursor:getRBPrompt() return nil end
function Cursor:onJoypadPressButton() S.cancel() end
function Cursor:onJoypadDirUp() end
function Cursor:onJoypadDirDown() end
function Cursor:onJoypadDirLeft() end
function Cursor:onJoypadDirRight() end

-- Use the ranch designation's native area highlight, with inclusive picked
-- tiles converted to exclusive far edges only once at this boundary.
function S.rectangle(x1, y1, x2, y2, z)
    local r = {x1=math.min(x1,x2), y1=math.min(y1,y2),
        x2=math.max(x1,x2)+1, y2=math.max(y1,y2)+1, z=z, mode="tennis"}
    local w, h = r.x2-r.x1, r.y2-r.y1
    local limits=PTCore.courtLimits
    return r, w>=limits.minWidth and w<=limits.maxWidth and h>=limits.minLength and h<=limits.maxLength
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
    return self:validate(square:getX(),square:getY(),false)
end

function Cursor:validate(x,y,fresh)
    local r,valid=S.rectangle(self.startX or x,self.startY or y,x,y,self.z)
    if not valid then
        local limits=PTCore.courtLimits
        return false,"Court size: "..limits.minWidth.."-"..limits.maxWidth.." x "..limits.minLength.."-"..limits.maxLength
    end
    if not self.validator then return true end
    local t=getTimestampMs()
    if fresh or self.checkedX~=x or self.checkedY~=y or t>=(self.checkedUntil or 0) then
        self.checkedX,self.checkedY,self.checkedUntil=x,y,t+200
        self.checkedValid,self.checkedReason=self.validator(r)
    end
    return self.checkedValid,self.checkedReason
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
    local r = S.rectangle(self.startX,self.startY,x,y,z)
    local valid = self:validate(x,y,true)
    if not valid then return end
    local callback = self.callback
    S.cancel()
    callback(r)
end

function Cursor:render(x,y,z,square)
    if z ~= self.z then return end
    local r = S.rectangle(self.startX or x,self.startY or y,x,y,z)
    local valid,reason = self:validate(x,y,false)
    local red,green = 0.2,0.9
    if self.startX and not valid then red,green=1,0.2 end
    self.preview={court=r,red=red,green=green}
    if getTextManager and getMouseX then
        local label = tostring(r.x2-r.x1).." x "..tostring(r.y2-r.y1).."  "..(reason or "Click to submit court")
        getTextManager():DrawString(UIFont.Small,getMouseX()+18,getMouseY()+18,label,red,green,0.3,1)
    end
end

function S.begin(character, callback, validator)
    if not character or character:isDead() or type(callback)~="function" then return false end
    S.cancel()
    local cursor = setmetatable({}, {__index=Cursor})
    -- IsoCell.setDrag looks this callback up with rawget, not inheritance.
    cursor.deactivate = Cursor.deactivate
    cursor.build,cursor.canBeBuild,cursor.isLeftDown = false,false,false
    cursor.north,cursor.dragNilAfterPlace = false,false
    cursor.character,cursor.player = character,character:getPlayerNum()
    cursor.z = math.floor(character:getZ())
    cursor.callback = callback
    cursor.validator = validator
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

local function tileBuilding(cursor, isRender, x,y,z,square)
    if cursor~=S.cursor then return end
    -- Singleplayer loads the vanilla dispatcher; let it handle this cursor once.
    if type(DoTileBuilding)=="function" then return end
    if z~=cursor.z or not square then return end
    if isRender then cursor:render(x,y,z,square) end
end

local function mouseDown(x,y)
    local cursor=S.cursor
    if not cursor or type(DoTileBuilding)=="function" then return end
    if cursor.character:isDead() or math.floor(cursor.character:getZ())~=cursor.z then return end
    -- Current B42 IsoPlayer has no isBuildButtonReleased. OnMouseDown is
    -- emitted only for world clicks not consumed by UIManager.
    local tx=math.floor(screenToIsoX(cursor.player,x,y,cursor.z))
    local ty=math.floor(screenToIsoY(cursor.player,x,y,cursor.z))
    cursor:create(tx,ty,cursor.z)
end

Events.OnMouseDown.Add(mouseDown)
Events.OnDoTileBuilding2.Add(tileBuilding)
Events.OnTick.Add(update)
Events.OnKeyPressed.Add(function(key)
    if key==Keyboard.KEY_ESCAPE then S.cancel() end
end)
Events.OnDisconnect.Add(S.cancel)
Events.OnMainMenuEnter.Add(S.cancel)
