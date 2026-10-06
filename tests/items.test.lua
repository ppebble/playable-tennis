local n=0
local function check(v,msg) n=n+1; if not v then error(msg) end end
local p=ItemMock.player()
ItemMock.current=p
local old=ItemMock.item("Base.TennisRacket")
p.inventory:AddItem(old)
p.primary=old
old.condition=0; old.max=7; old.repair=5; old.times=5; old.blood=0.6
old.mod.ThirdParty={value=42}; old.favorite=true; old.customName=true; old.name="Mine"
old.customWeight=true; old.weight=1.2
local a=PT_ConvertRacket:new(p,old)
check(a:isValid(),"owned weapon valid")
a:perform()
check(p.primary==old and p.inventory:contains(old),"perform never swaps locally")
check(a:complete(),"server completion")
local sports=p.primary
check(sports:getFullType()=="PlayableTennis.SportsTennisRacket","sports type")
check(not p.inventory:contains(old) and p.inventory:contains(sports),"single replacement")
check(sports.condition==0 and sports.max==7,"broken and condition max preserved")
check(sports.repair==5 and sports.times==5,"repair counters")
check(sports.favorite and sports:getBloodLevel()==0 and sports.mod.PT_WeaponBlood==0.6,"native Normal blood no-op preserved via modData")
check(sports.mod.ThirdParty.value==42,"third party mod data")
check(sports.name=="Mine" and sports.customName,"custom name")
check(sports.weight==1.2 and sports.customWeight,"custom weight")
check(not a:complete(),"duplicate completion rejected")
check(not PT_ConvertRacket:new(p,old):complete(),"replayed stale item rejected")
check(ItemMock.sent==1 and ItemMock.equipped==1,"one replacement equip sync")
p.primary=nil; p.secondary=sports
check(PT_ConvertRacket:new(p,sports):complete(),"reverse conversion")
check(p.secondary.kind=="Base.TennisRacket" and not p.primary,"secondary hand preserved")
check(p.secondary.condition==0 and p.secondary.times==5,"roundtrip no repair exploit")
check(p.secondary:getBloodLevel()==0.6,"weapon blood restored after roundtrip")
check(p.secondary.mod.PT_WeaponBlood==nil,"weapon helper blood key removed")
local item=p.secondary
item.slot=1
check(not PT_ConvertRacket:new(p,item):isValid(),"attached hotbar rejected")
item.slot=-1; p.dead=true
check(not PT_ConvertRacket:new(p,item):isValid(),"dead rejected")
p.dead=false; p.vehicle=true
check(not PT_ConvertRacket:new(p,item):isValid(),"vehicle rejected")
p.vehicle=nil
local other=ItemMock.player()
check(not PT_ConvertRacket:new(other,item):complete(),"foreign inventory rejected")
local action=PT_ConvertRacket:new(p,item)
p.inventory:Remove(item)
check(not action:complete(),"removed while queued rejected")
p.inventory:AddItem(item)
ItemMock.failFactory=true
check(not action:complete() and p.inventory:contains(item),"factory failure preserves source")
ItemMock.failFactory=false
check(PT_ConvertRacket.targetType(ItemMock.item("Base.Axe"))==nil,"unrelated item rejected")
local opts={}
local menu={addOption=function(_,name,player,fn,it) opts[#opts+1]={name=name,player=player,fn=fn,item=it} end}
ItemMock.menu(0,menu,{{items={item}}})
check(#opts==1 and opts[1].name=="ContextMenu_PT_SportsRacket","stack inventory menu")
opts[1].fn(opts[1].player,opts[1].item)
check(#ItemMock.queued==1 and p.secondary==item,"menu only queues native action")
opts={}; ItemMock.menu(0,menu,{ItemMock.item("Base.TennisRacket")})
check(#opts==0,"world unowned hidden")
print("PASS items "..n)
checks=n


