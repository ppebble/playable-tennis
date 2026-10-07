function isClient() return false end
Perks={Fitness="Fitness",Nimble="Nimble"}
function addXp(p,perk,amount) p.xp[perk]=(p.xp[perk] or 0)+amount; p.calls=p.calls+1 end
TrainingMock={}
function TrainingMock.player()
    local p={xp={},calls=0}
    function p:isDead() return self.dead end
    -- Fail immediately if training starts mutating endurance, muscle fatigue, or persistence.
    function p:getStats() error("Training must not access endurance") end
    function p:getBodyDamage() error("Training must not access muscle fatigue") end
    function p:getFitness() error("Training must not invoke exercise effects") end
    function p:getModData() error("XP requires no persisted fatigue state") end
    return p
end
