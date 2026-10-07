-- A remote B42 client does not load server/BuildingObjects/ISBuildingObject.
-- Fail dependencies explicitly instead of inventing that server-only class.
function require(name) if name=="PT_Text" and PTText then return PTText end; if name=="PT_Core" and PTCore then return PTCore end; error("Client-unavailable dependency: "..name) end
ISBuildingObject=nil
SelectorMock={events={},right=false,highlights={},time=1000}
local M=SelectorMock
function getTimestampMs() return M.time end
M.cell={getDrag=function(self) return self.drag end,setDrag=function(self,value)
    local previous=self.drag; self.drag=value
 if previous and rawget(previous,"deactivate") then previous.deactivate(previous) end
end}
function getCell() return M.cell end
function isMouseButtonDown() return M.right end
function screenToIsoX(_,x,y,z) return x end
function screenToIsoY(_,x,y,z) return y end
function addAreaHighlightForPlayer(...) M.highlights[#M.highlights+1]={...} end
Keyboard={KEY_ESCAPE=1}
Events={}
for _,name in ipairs({"OnTick","OnKeyPressed","OnDisconnect","OnMainMenuEnter","OnDoTileBuilding2","OnMouseDown"}) do
    Events[name]={Add=function(fn) M.events[name]=fn end}
end
M.player={z=0,getZ=function(self) return self.z end,getPlayerNum=function() return 0 end,
    isDead=function(self) return self.dead end}
