function require() end
ISBaseTimedAction = {}
function ISBaseTimedAction:derive() local t={}; t.__index=t; setmetatable(t,{__index=self}); return t end
function ISBaseTimedAction:new(character) return setmetatable({character=character},{__index=self}) end
function ISBaseTimedAction:setActionAnim(name, models) self.anim=name; self.models=models end
SwingMock={queue={queue={}}}
ISTimedActionQueue={}
function ISTimedActionQueue.getTimedActionQueue() return SwingMock.queue end
function ISTimedActionQueue.add(action) table.insert(SwingMock.queue.queue, action) end
