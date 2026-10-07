require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

-- Native one-handed clip, without entering the combat or bush-removal action.
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
    self:setAnimVariable("PT_RacketStroke", true)
    self:setActionAnim("RemoveBushLongBlade")
    -- Log the first started action, not merely a click queued by the client.
    if not PTSwing.loggedStart then
        PTSwing.loggedStart = true
        print("[PlayableTennis] swing started (native-onehand): action="
            ..tostring(self.character:getVariableString("PerformingAction"))
            .." rightMask="..tostring(self.character:getVariableString("RightHandMask")))
    end
end
-- The native node emits Chop; only ISRemoveBush gives that event world effects.
-- This cosmetic action deliberately consumes it without changing the world.
function PT_SwingAction:animEvent(event, parameter) end
function PT_SwingAction:update()
    if PTSwing.loggedPlayback then return end
    self.ptDiagnosticTicks=(self.ptDiagnosticTicks or 0)+1
    if self.ptDiagnosticTicks<4 then return end
    PTSwing.loggedPlayback=true
    -- Sample after animation evaluation so the log contains actual layer nodes.
    local ok,debugText=pcall(function() return self.character:getAnimationDebug() end)
    if ok and debugText then
        local layers=tostring(debugText):match("^(.-)Variables:") or tostring(debugText)
        print("[PlayableTennis] swing playback: "..layers)
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
