function require() end
ClientMock = {time=10000,sent={},focused=false,draws={}}
function getSoundManager() return {playUISound=function(_,name) ClientMock.sound=name end} end
function getTimestampMs() return ClientMock.time end
function isClient() return true end
local p={getX=function() return 3 end,getY=function() return 4 end,getZ=function() return 0 end}
function getSpecificPlayer() return p end
function sendClientCommand(player,module,command,args)
    ClientMock.sent[#ClientMock.sent+1]={command=command,args=args}
end
Keyboard={KEY_J=1,KEY_K=2,KEY_LEFT=3,KEY_RIGHT=4}
function isKeyDown(key) return ClientMock.key==key end
function getCore() return {isDoingTextEntry=function() return ClientMock.focused end,
    getScreenWidth=function() return 1280 end,getScreenHeight=function() return 720 end} end
UIFont={Small=1}
function isoToScreenX(_,x,y,z) return x*10-y*10 end
function isoToScreenY(_,x,y,z) return x*5+y*5-z*30 end
Events={}
for _,name in ipairs({'OnServerCommand','OnFillWorldObjectContextMenu','OnKeyPressed','OnGameStart','OnTick'}) do
    local event={}
    event.Add=function(fn) event.callback=fn end
    Events[name]=event
end
ISPanel={}
function ISPanel:derive() local t={}; setmetatable(t,{__index=self}); t.__index=t; return t end
function ISPanel:new(x,y,w,h) return setmetatable({width=w,height=h},{__index=self}) end
function ISPanel:initialise() end
function ISPanel:instantiate() end
function ISPanel:setWantMouseEvents(value) self.mouseEvents=value end
function ISPanel:addToUIManager() end
function ISPanel:removeFromUIManager() end
function ISPanel:setWidth(v) self.width=v end
function ISPanel:setHeight(v) self.height=v end
function ISPanel:drawLine2() end
function ISPanel:drawText() end
function ISPanel:drawRect(x,y,w,h) ClientMock.draws[#ClientMock.draws+1]={x=x,y=y,w=w,h=h} end
function ClientMock.menu()
    return {options={},addOption=function(self,name,target,callback,arg)
        local option={name=name,target=target,callback=callback,arg=arg}; self.options[#self.options+1]=option; return option
    end,addSubMenu=function(self,root,menu) self.submenu=menu end}
end
ISContextMenu={getNew=function() return ClientMock.menu() end}
