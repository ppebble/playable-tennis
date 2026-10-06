-- Host mocks only. Production core/server are loaded by the Java Kahlua runner.
ServerMock = { time=10000, db={}, packets={}, players={}, squares={} }
function isClient() return false end
function isServer() return true end
function getTimestampMs() return ServerMock.time end
function require(name) assert(name=="PT_Core" or name=="PT_Wall", "Unexpected dependency: "..name) end
Events = { OnClientCommand={Add=function(f) ServerMock.command=f end}, OnTick={Add=function(f) ServerMock.tick=f end} }
SandboxVars = { PlayableTennis={} }
ModData = {getOrCreate=function(name)
    ServerMock.db[name]=ServerMock.db[name] or {}; return ServerMock.db[name]
end}
IsoFlagType={}
for _,name in ipairs({"water","collideW","WallW","WindowW","windowW","DoorWallW","HoppableW","collideN","WallN","WindowN","windowN","DoorWallN","HoppableN"}) do IsoFlagType[name]=name end
function sendServerCommand(p,module,command,args)
    assert(module=="PlayableTennis"); assert(p and p.name, "A packet must target one player")
    ServerMock.packets[#ServerMock.packets+1]={player=p,command=command,args=args}
end
function ServerMock.square(x,y,z)
    local id=x..":"..y..":"..z
    if not ServerMock.squares[id] then
        ServerMock.squares[id]={flags={},floor=true,solid=false,
            has=function(self,name) return self.flags[name] or false end,
            getFloor=function(self) return self.floor end,
            isSolid=function(self) return self.solid end,
            isSolidTrans=function(self) return self.trans or false end}
    end
    return ServerMock.squares[id]
end
function getCell() return {getGridSquare=function(_,x,y,z) return ServerMock.square(x,y,z) end} end
function getOnlinePlayers() return {size=function() return #ServerMock.players end,get=function(_,i) return ServerMock.players[i+1] end} end
function getSpecificPlayer() return ServerMock.players[1] end
function ServerMock.player(name,x,y)
    local p={name=name,x=x or 102,y=y or 100,z=0,ball=true,secondaryBall=true,condition=10,racket=true}
    function p:getUsername() return self.name end
    function p:getAccessLevel() return self.admin and "admin" or "" end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getZ() return self.z end
    function p:isDead() return self.dead or false end
    function p:getVehicle() return self.vehicle end
    function p:getPrimaryHandItem()
        if not self.racket then return nil end
        return {getFullType=function() return self.itemType or "PlayableTennis.SportsTennisRacket" end,getCondition=function() return self.condition end}
    end
    function p:getSecondaryHandItem()
        if not self.secondaryBall then return nil end
        return {getFullType=function() return self.secondaryType or "Base.TennisBall" end}
    end
    function p:getInventory() return {containsTypeRecurse=function(_,name) return name=="Base.TennisBall" and self.ball end} end
    ServerMock.players[#ServerMock.players+1]=p
    return p
end
function ServerMock.reset()
    ServerMock.time=10000; ServerMock.db={}; ServerMock.packets={}; ServerMock.players={}; ServerMock.squares={}
    SandboxVars.PlayableTennis={}
    PTServer.sessions={}; PTServer.members={}; PTServer.rates={}; PTServer.serial=0
    PTServer.lastTick=nil; PTServer.lastAudit=nil; PTServer.lastSend=nil; PTServer.accumulator=nil
end
