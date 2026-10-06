function require() end
ISBaseTimedAction = {}
function ISBaseTimedAction:derive() local t={}; t.__index=t; setmetatable(t,{__index=self}); return t end
function ISBaseTimedAction:new(character) return setmetatable({character=character},{__index=self}) end
function ISBaseTimedAction:perform() ItemMock.performed=true end
ItemMock={sent=0,equipped=0,queued={}}
function ItemMock.item(kind)
    local i={kind=kind,condition=4,max=4,repair=0,times=0,headTimes=0,blood=0,mod={},name=kind,weight=1,slot=-1}
    function i:getFullType() return self.kind end
    function i:getContainer() return self.container end
    function i:getAttachedSlot() return self.slot end
    function i:getConditionMax() return self.max end
    function i:setConditionMax(v) self.max=v end
    function i:getCondition() return self.condition end
    function i:setConditionNoSound(v) self.condition=v end
    function i:getHaveBeenRepaired() return self.repair end
    function i:setHaveBeenRepaired(v) self.repair=v end
    function i:copyTimesRepairedFrom(v) self.times=v.repair; self.repair=v.repair end
    function i:copyTimesHeadRepairedFrom(v) self.repair=v.repair; self.times=v.repair end
    function i:isFavorite() return self.favorite end
    function i:setFavorite(v) self.favorite=v end
    function i:getBloodLevel() if self.kind=="PlayableTennis.SportsTennisRacket" then return 0 end return self.blood end
    function i:setBloodLevel(v) if self.kind~="PlayableTennis.SportsTennisRacket" then self.blood=v end end
    function i:hasModData() return true end
    function i:getModData() return self.mod end
    function i:copyModData(v) for k,x in pairs(v) do self.mod[k]=x end end
    function i:isCustomName() return self.customName end
    function i:setCustomName(v) self.customName=v end
    function i:getName() return self.name end
    function i:setName(v) self.name=v end
    function i:isCustomWeight() return self.customWeight end
    function i:setCustomWeight(v) self.customWeight=v end
    function i:getActualWeight() return self.weight end
    function i:setActualWeight(v) self.weight=v end
    return i
end
function instanceItem(kind) if ItemMock.failFactory then return nil end return ItemMock.item(kind) end
function ItemMock.player()
    local p={inventory={items={}}}
    function p.inventory:AddItem(item) self.items[item]=true; item.container=self end
    function p.inventory:Remove(item) self.items[item]=nil; item.container=nil end
    function p.inventory:contains(item) return self.items[item] == true end
    function p:isDead() return self.dead end
    function p:getVehicle() return self.vehicle end
    function p:getInventory() return self.inventory end
    function p:getPrimaryHandItem() return self.primary end
    function p:getSecondaryHandItem() return self.secondary end
    function p:setPrimaryHandItem(v) self.primary=v end
    function p:setSecondaryHandItem(v) self.secondary=v end
    return p
end
function sendReplaceItemInContainer() ItemMock.sent=ItemMock.sent+1 end
function replaceItemInContainer() end
function sendEquip() ItemMock.equipped=ItemMock.equipped+1 end
ISTimedActionQueue={add=function(a) ItemMock.queued[#ItemMock.queued+1]=a end}
Events={OnFillInventoryObjectContextMenu={Add=function(fn) ItemMock.menu=fn end}}
function getSpecificPlayer() return ItemMock.current end
function getText(key) return key end


