checks=0
local function ok(value,message) checks=checks+1; assert(value,message) end
local function near(value,expected,message) ok(math.abs(value-expected)<0.000001,message..": "..tostring(value)) end
local function minute(p,settings) for i=1,60 do PTTraining.advance(p,1,settings) end end
for _,scale in ipairs({0,0.5,1,2}) do
    local p=TrainingMock.player()
    minute(p,{FitnessXPMultiplier=scale,NimbleXPMultiplier=scale})
    near(p.xp.Fitness or 0,20*scale,"Fitness proportional")
    near(p.xp.Nimble or 0,3*scale,"Nimble proportional")
    if scale==0 then ok(p.calls==0,"zero sends no XP calls") end
end
for _,value in ipairs({"2",0/0,math.huge,-math.huge}) do
    local p=TrainingMock.player()
    minute(p,{FitnessXPMultiplier=value,NimbleXPMultiplier=value})
    near(p.xp.Fitness,20,"invalid default Fitness")
    near(p.xp.Nimble,3,"invalid default Nimble")
end
local p=TrainingMock.player()
minute(p,nil)
near(p.xp.Fitness,20,"missing settings default")
near(p.xp.Nimble,3,"missing settings default Nimble")
p.dead=true
minute(p,{})
near(p.xp.Fitness,20,"dead player gets no XP")
near(p.xp.Nimble,3,"dead player gets no Nimble XP")
PTTraining.advance(nil,1,{})
local s=TrainingMock.player()
PTTraining.advance(s,100000,{})
near(s.xp.Fitness,20/6,"stalled delta bounded")
local xp=s.xp.Fitness
for _,seconds in ipairs({0,-1,0/0,math.huge,"10"}) do PTTraining.advance(s,seconds,{}) end
near(s.xp.Fitness,xp,"invalid elapsed ignored")
minute(s,{FitnessXPMultiplier=-1,NimbleXPMultiplier=-1})
near(s.xp.Fitness,xp,"negative multiplier disabled")
local r=TrainingMock.player()
minute(r,{FitnessXPMultiplier=101,NimbleXPMultiplier=1000})
near(r.xp.Fitness,2000,"Fitness multiplier cap")
near(r.xp.Nimble,300,"Nimble multiplier cap")
local q=TrainingMock.player()
minute(q,{FitnessXPMultiplier=0,NimbleXPMultiplier=2})
near(q.xp.Fitness or 0,0,"Fitness independent disable")
near(q.xp.Nimble,6,"Nimble independent setting")
ok(PTTraining.update==nil,"no delayed fatigue hook")
print("Training tests passed: "..checks)

