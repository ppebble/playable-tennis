require "PT_ConvertRacket"
require "TimedActions/ISTimedActionQueue"

PT_RacketMenu = {}

function PT_RacketMenu.convert(player, item)
    local action = PT_ConvertRacket:new(player, item)
    if action:isValid() then ISTimedActionQueue.add(action) end
end

function PT_RacketMenu.fill(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    if not player then return end
    for _, entry in ipairs(items) do
        local item = entry
        if type(entry) == "table" and entry.items then item = entry.items[1] end
        local target = PT_ConvertRacket.targetType(item)
        if target then
            local action = PT_ConvertRacket:new(player, item)
            if action:isValid() then
                local key = target == "Base.TennisRacket" and "ContextMenu_PT_WeaponRacket" or "ContextMenu_PT_SportsRacket"
                context:addOption(getText(key), player, PT_RacketMenu.convert, item)
                return
            end
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(PT_RacketMenu.fill)
