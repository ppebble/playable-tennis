if isClient() then return end
PTTraining = {}
local function finite(value)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function multiplier(settings, name)
    local value=settings and settings[name]
    if not finite(value) then return 1 end
    return math.max(0,math.min(100,value))
end
-- The server admits only elapsed active rally time after a successful human stroke.
-- Award XP directly; native exerciseRepeat would also drain endurance and add fatigue.
function PTTraining.advance(player, seconds, settings)
    if not player or player:isDead() then return end
    if not finite(seconds) or seconds<=0 then return end
    seconds=math.min(seconds,10)
    local fitness=20*seconds/60*multiplier(settings,"FitnessXPMultiplier")
    local nimble=3*seconds/60*multiplier(settings,"NimbleXPMultiplier")
    if fitness>0 then addXp(player,Perks.Fitness,fitness) end
    if nimble>0 then addXp(player,Perks.Nimble,nimble) end
end
