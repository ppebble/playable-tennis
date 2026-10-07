function require() end
ISBuildingObject={}
function ISBuildingObject:derive() return setmetatable({},{__index=self}) end
function ISBuildingObject:init() end
SelectorMock={events={},right=false,highlights={},time=1000}
local M=SelectorMock
function getTimestampMs() return M.time end
M.cell={getDrag=function(self) return self.drag end,setDrag=function(self,value)
    local previous=self.drag; self.drag=value
    if previous then previous:deactivate() end
end}
function getCell() return M.cell end
function isMouseButtonDown() return M.right end
function addAreaHighlightForPlayer(...) M.highlights[#M.highlights+1]={...} end
Keyboard={KEY_ESCAPE=1}
Events={}
for _,name in ipairs({"OnTick","OnKeyPressed","OnDisconnect","OnMainMenuEnter"}) do
    Events[name]={Add=function(fn) M.events[name]=fn end}
end
M.player={z=0,getZ=function(self) return self.z end,getPlayerNum=function() return 0 end,
    isDead=function(self) return self.dead end}
