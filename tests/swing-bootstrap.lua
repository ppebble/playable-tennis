function require() end
ISBaseTimedAction = {}
function ISBaseTimedAction:derive() local t={}; t.__index=t; setmetatable(t,{__index=self}); return t end
function ISBaseTimedAction:new(character) return setmetatable({character=character},{__index=self}) end
function ISBaseTimedAction:setActionAnim(name, models) self.anim=name; self.models=models; self.modelsAtAnim=self.handModels end
function ISBaseTimedAction:setOverrideHandModels(primary, secondary) self.handModels={primary=primary,secondary=secondary} end
function ISBaseTimedAction:setAnimVariable(name, value) self.variables=self.variables or {}; self.variables[name]=value end
SwingMock={queue={queue={}}}
ISTimedActionQueue={}
function ISTimedActionQueue.getTimedActionQueue() return SwingMock.queue end
function ISTimedActionQueue.add(action) table.insert(SwingMock.queue.queue, action) end
