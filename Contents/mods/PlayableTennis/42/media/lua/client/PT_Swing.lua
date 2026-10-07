require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

-- Cosmetic only: no attack event, weapon substitution, or damage callback.
-- No complete() callback: B42 uses its custom remote animation sync path.
PT_SwingAction = ISBaseTimedAction:derive("PT_SwingAction")
function PT_SwingAction:isValid()
    local item = self.character:getPrimaryHandItem()
    return not self.character:isDead() and not self.character:getVehicle()
        and item and item:getFullType() == "PlayableTennis.SportsTennisRacket"
end
function PT_SwingAction:start()
    self.action:setUseProgressBar(false)
    self.action:setBlockMovementEtc(false)
    self:setActionAnim("PT_TennisSwing")
    -- Log the first started action, not merely a click queued by the client.
    if not PTSwing.loggedStart then
        PTSwing.loggedStart = true
        print("[PlayableTennis] swing started (selection-priority-1): action="
            ..tostring(self.character:getVariableString("PerformingAction"))
            .." rightMask="..tostring(self.character:getVariableString("RightHandMask")))
    end
end
function PT_SwingAction:adjustMaxTime(time) return time end
function PT_SwingAction:new(character)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk, o.stopOnRun, o.stopOnAim = false, false, false
    -- One second of follow-through; never speed up the clip to fit hit cooldown.
    o.maxTime = 30
    o.ptSportsSwing = true
    return o
end

PTSwing = { lastPlayer = nil, lastAt = nil }
function PTSwing.play(character, timestamp)
    if not character then return false, "no-player" end
    local action = PT_SwingAction:new(character)
    if not action:isValid() then return false, "equipment-or-state" end
    if PTSwing.lastPlayer == character and PTSwing.lastAt
        and timestamp - PTSwing.lastAt < 250 then return false, "cooldown" end
    -- Do not interrupt or queue behind eating, equipping, or other real actions.
    local queue = ISTimedActionQueue.getTimedActionQueue(character)
    if #queue.queue==1 and queue.queue[1].ptSportsSwing then return false, "swing-active" end
    if #queue.queue > 0 then return false, "busy" end
    PTSwing.lastPlayer, PTSwing.lastAt = character, timestamp
    ISTimedActionQueue.add(action)
    return true
end
return PTSwing
