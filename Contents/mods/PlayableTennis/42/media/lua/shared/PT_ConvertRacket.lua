require "TimedActions/ISBaseTimedAction"

-- complete() is invoked by B42's native action authority, never by the menu.
PT_ConvertRacket = ISBaseTimedAction:derive("PT_ConvertRacket")

function PT_ConvertRacket.targetType(item)
    if not item then return nil end
    local kind = item:getFullType()
    if kind == "Base.TennisRacket" then return "PlayableTennis.SportsTennisRacket" end
    if kind == "PlayableTennis.SportsTennisRacket" then return "Base.TennisRacket" end
end

function PT_ConvertRacket:isValid()
    return not self.done and self.character and not self.character:isDead()
        and not self.character:getVehicle() and self.item
        and PT_ConvertRacket.targetType(self.item) ~= nil
        and self.item:getContainer() == self.character:getInventory()
        and self.character:getInventory():contains(self.item)
        and self.item:getAttachedSlot() == -1
end

function PT_ConvertRacket:perform()
    ISBaseTimedAction.perform(self)
end

function PT_ConvertRacket:complete()
    -- Revalidate ownership even when a queued action was valid at its start.
    if not self:isValid() then return false end
    local old = self.item
    local replacement = instanceItem(PT_ConvertRacket.targetType(old))
    if not replacement then return false end
    replacement:setConditionMax(old:getConditionMax())
    replacement:setConditionNoSound(old:getCondition())
    replacement:setHaveBeenRepaired(old:getHaveBeenRepaired())
    replacement:copyTimesRepairedFrom(old)
    replacement:copyTimesHeadRepairedFrom(old)
    replacement:setFavorite(old:isFavorite())
    replacement:setBloodLevel(old:getBloodLevel())
    if old:hasModData() then replacement:copyModData(old:getModData()) end
    -- Normal InventoryItem blood accessors are no-ops in B42; retain weapon
    -- blood in our own modData while the racket is a non-weapon sports item.
    if old:getFullType() == "Base.TennisRacket" then
        replacement:getModData().PT_WeaponBlood = old:getBloodLevel()
    else
        local blood = old:getModData().PT_WeaponBlood
        if type(blood) == "number" and blood == blood then
            replacement:setBloodLevel(math.max(0, math.min(1, blood)))
        end
        replacement:getModData().PT_WeaponBlood = nil
    end
    if old:isCustomName() then
        replacement:setName(old:getName())
        replacement:setCustomName(true)
    end
    if old:isCustomWeight() then
        replacement:setActualWeight(old:getActualWeight())
        replacement:setCustomWeight(true)
    end
    local primary = self.character:getPrimaryHandItem() == old
    local secondary = self.character:getSecondaryHandItem() == old
    local inventory = self.character:getInventory()
    inventory:AddItem(replacement)
    if primary then self.character:setPrimaryHandItem(replacement) end
    if secondary then self.character:setSecondaryHandItem(replacement) end
    inventory:Remove(old)
    self.done = true
    sendReplaceItemInContainer(inventory, old, replacement)
    replaceItemInContainer(inventory, old, replacement)
    if primary or secondary then sendEquip(self.character) end
    return true
end

function PT_ConvertRacket:getDuration() return 1 end

function PT_ConvertRacket:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end


