function require() end
ClientMock = {time=10000,sent={},focused=false,draws={},buttons={}}
PTCourtSelector={isActive=function() return ClientMock.selecting or false end,
    blocksInput=function() return ClientMock.selecting or ClientMock.selectionCooldown or false end,
    cancel=function() ClientMock.selecting=false end,
    begin=function(p,callback) ClientMock.selecting=true; ClientMock.selectCourt=callback end}
PTSwing={play=function() ClientMock.swings=(ClientMock.swings or 0)+1 end}
function getSoundManager() return {playUISound=function(_,name) ClientMock.sound=name end} end
function getTimestampMs() return ClientMock.time end
function isClient() return true end
local p={getX=function(self) return self.x or 3 end,getY=function(self) return self.y or 4 end,getZ=function() return 0 end}
ClientMock.player=p
function p:isDead() return self.dead or false end
function p:getVehicle() return self.vehicle end
function p:isBannedAttacking() return self.banned or false end
function p:setBannedAttacking(value) self.banned=value end
function p:getPrimaryHandItem()
    if self.noRacket then return nil end
    return {getFullType=function() return self.primaryType or "PlayableTennis.SportsTennisRacket" end,getCondition=function() return 10 end}
end
function p:getSecondaryHandItem() if self.noBall then return nil end; return {getFullType=function() return self.secondaryType or "Base.TennisBall" end} end
function getSpecificPlayer() return p end
function sendClientCommand(player,module,command,args)
    ClientMock.sent[#ClientMock.sent+1]={command=command,args=args}
end
Keyboard={KEY_J=1,KEY_K=2,KEY_LEFT=3,KEY_RIGHT=4}
function isKeyDown(key) return ClientMock.key==key end
function isMouseButtonDown(button) return ClientMock.buttons[button] or false end
function getMouseX() return ClientMock.mouseX or 4 end
function getMouseY() return ClientMock.mouseY or 12 end
function screenToIsoX(_,x,y,z) return x end
function screenToIsoY(_,x,y,z) return y end
function getCore() return {isDoingTextEntry=function() return ClientMock.focused end,
    getScreenWidth=function() return ClientMock.screenWidth or 1280 end,getScreenHeight=function() return 720 end} end
UIFont={Small=1,Large=2}
function getTextManager() return {MeasureStringX=function(_,font,text) return #text*(font==2 and 14 or 7) end,getFontHeight=function(_,font) return font==2 and 28 or 16 end} end
function isoToScreenX(_,x,y,z) return x*10-y*10 end
function isoToScreenY(_,x,y,z) return x*5+y*5-z*30 end
Events={}
for _,name in ipairs({'OnServerCommand','OnFillWorldObjectContextMenu','OnKeyPressed','OnMouseDown','OnPlayerUpdate','OnPlayerDeath','OnDisconnect','OnMainMenuEnter','OnGameStart','OnCreatePlayer','OnTick'}) do
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
function ISPanel:drawLine2(x,y,x2,y2) ClientMock.lines=ClientMock.lines or {}; ClientMock.lines[#ClientMock.lines+1]={x=x,y=y,x2=x2,y2=y2} end
function ISPanel:drawText() end
function ISPanel:drawTextZoomed(text,x,y,zoom,r,g,b,a,font)
    ClientMock.texts=ClientMock.texts or {}
    table.insert(ClientMock.texts,{text=text,x=x,y=y,zoom=zoom,font=font})
    self:drawText(text,x,y,r,g,b,a,font)
end
function ISPanel:drawRect(x,y,w,h) ClientMock.draws[#ClientMock.draws+1]={x=x,y=y,w=w,h=h} end
function ClientMock.menu()
    return {options={},addOption=function(self,name,target,callback,arg)
        local option={name=name,target=target,callback=callback,arg=arg}; self.options[#self.options+1]=option; return option
    end,addSubMenu=function(self,root,menu) self.submenu=menu end}
end
ISContextMenu={getNew=function() return ClientMock.menu() end}
