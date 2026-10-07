-- Run the real selector with the real client, without server Lua globals.
PTCourtSelector=nil
ISBuildingObject=nil
function require(name)
    assert(name~="BuildingObjects/ISBuildingObject", "Server dependency on remote client")
end
local cell={}
function cell:getDrag() return self.drag end
function cell:setDrag(value)
    local previous=self.drag
    self.drag=value
    if previous then previous:deactivate() end
end
function getCell() return cell end
function ClientMock.player:getPlayerNum() return 0 end
Keyboard.KEY_ESCAPE=99
Events.OnDoTileBuilding2={}
for _,event in pairs(Events) do
    event.callbacks={}
    event.Add=function(fn) table.insert(event.callbacks,fn) end
    event.fire=function(...) for _,fn in ipairs(event.callbacks) do fn(...) end end
end
