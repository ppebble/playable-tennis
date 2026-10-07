local function check(value,message) checks=(checks or 0)+1; assert(value,message) end
local function state(rev,x,bounces)
    return {session='render',slot=1,revision=rev,core={court={x1=0,x2=8,y1=0,y2=18,z=0,mode='tennis'},
        phase='rally',clock=rev*0.1,shotId=1,bounces=bounces or 0,ball={x=x,y=10,z=1},points={0,0},games={0,0},server=1}}
end
Events.OnGameStart.callback()
PTClient.receive('state',state(1,1))
ClientMock.time=ClientMock.time+100
PTClient.receive('state',state(2,3,1))
ClientMock.time=ClientMock.time+25
local x=PTClient.ballPosition()
check(x==1.5,'floor contact remains continuous at quarter interval')
ClientMock.renderFrame()
check(#ClientMock.worldDraws==2,'world frame draws shadow and ball without UI refresh')
ClientMock.time=ClientMock.time+25
ClientMock.renderFrame()
check(ClientMock.worldDraws[4].x>ClientMock.worldDraws[2].x,'ball advances on subsequent world frame')
ClientMock.zoom=2
ClientMock.renderFrame()
check(ClientMock.worldDraws[6].x==ClientMock.worldDraws[4].x*2,'world framebuffer restores zoomed coordinates')
check(ClientMock.worldDraws[6].w==12,'world sprite keeps six screen pixels after zoom')
ClientMock.time=ClientMock.time+1000
check(PTClient.ballPosition()==3,'missing packets freeze at authoritative sample')
ClientMock.worldDraws={}
ClientMock.renderPlayer={}
ClientMock.renderFrame()
check(#ClientMock.worldDraws==0,'other local viewport receives no player-zero ball')
ClientMock.renderPlayer=nil
PTClient.receive('left',{session='render'})
ClientMock.renderFrame()
check(#ClientMock.worldDraws==0,'leaving clears all ball presentation')
-- A wall reflection with identical snapshot positions must travel in and out.
local reflected=state(1,1); reflected.session='reflection'; reflected.core.court.mode='wall'
reflected.core.ball.y=0.5; reflected.core.ball.vy=-10
PTClient.receive('state',reflected)
ClientMock.time=ClientMock.time+100
reflected=state(2,1); reflected.session='reflection'; reflected.core.court.mode='wall'
reflected.core.ball.y=0.5; reflected.core.ball.vy=10
PTClient.receive('state',reflected)
for _,sample in ipairs({{0,0.5},{25,0.25},{50,0},{75,0.25},{100,0.5}}) do
    ClientMock.time=PTClient.receivedAt+sample[1]
    local _,y=PTClient.ballPosition()
    check(math.abs(y-sample[2])<0.000001,'wall reflection follows travel path at '..sample[1]..'ms')
end
check(PTClient.core.ball.y==0.5 and PTClient.core.ball.vy==10,'render smoothing never mutates authoritative ball')

-- Packet arrivals vary, but presentation follows the fixed simulation timeline.
PTClient.receive('left',{session='reflection'})
local base=ClientMock.time
local function jitter(rev,clock,x,arrival)
    ClientMock.time=base+arrival
    local packet=state(rev,x); packet.session='jitter'; packet.core.clock=clock
    PTClient.receive('state',packet)
end
jitter(1,0,0,0)
jitter(2,0.1,1,100)
ClientMock.time=base+175
check(math.abs(PTClient.ballPosition()-0.75)<0.000001,'presentation uses server clock between packets')
jitter(3,0.2,2,180)
check(math.abs(PTClient.ballPosition()-0.8)<0.000001,'early packet does not reset interpolation backwards')
ClientMock.time=base+210
check(math.abs(PTClient.ballPosition()-1.1)<0.000001,'irregular arrival retains constant visual speed')
jitter(4,0.3,3,325)
check(math.abs(PTClient.ballPosition()-2.25)<0.000001,'late packet keeps timestamp path')
for i=5,20 do jitter(i,(i-1)*0.1,i-1,(i-1)*100) end
check(#PTClient.ballSamples<=8,'presentation queue has bounded memory')
ClientMock.time=base+10000
check(PTClient.ballPosition()==19,'long silence never invents future ball motion')
PTClient.receive('left',{session='jitter'})
check(PTClient.ballSamples==nil and PTClient.ballPosition()==nil,'leave clears buffered trajectory')
-- A sampled floor contact must visibly reach the ground, not float across it.
base=ClientMock.time
local packet=state(1,0); packet.session='floor'; packet.core.clock=0
packet.core.ball={x=0,y=10,z=0.06225,vz=-1}
PTClient.receive('state',packet)
ClientMock.time=base+100
packet=state(2,1,1); packet.session='floor'; packet.core.clock=0.1
packet.core.ball={x=1,y=10,z=0.06225,vz=1}
PTClient.receive('state',packet)
ClientMock.time=base+150
local _,_,height=PTClient.ballPosition()
check(math.abs(height)<0.000001,'floor interpolation reaches actual contact height')
packet=state(3,8); packet.session='floor'; packet.core.clock=0.2; packet.core.shotId=2
PTClient.receive('state',packet)
check(PTClient.ballPosition()==8 and #PTClient.ballSamples==1,'accepted new stroke resets old trajectory')

-- Tennis horizontal speed changes at the bounce, not gradually between packets.
PTClient.receive('left',{session='floor'})
base=ClientMock.time
packet=state(1,0); packet.session='slow-bounce'; packet.core.clock=0
packet.core.ball={x=0,y=10,z=0.06225,vz=-1,vx=20,vy=-20}
PTClient.receive('state',packet)
ClientMock.time=base+100
packet=state(2,1.2,1); packet.session='slow-bounce'; packet.core.clock=0.1
packet.core.ball={x=1.2,y=8.8,z=0.06225,vz=1,vx=4,vy=-4}
PTClient.receive('state',packet)
for _,sample in ipairs({{125,0.5,9.5},{150,1,9},{175,1.1,8.9},{200,1.2,8.8}}) do
    ClientMock.time=base+sample[1]
    local x,y=PTClient.ballPosition()
    check(math.abs(x-sample[2])<0.000001 and math.abs(y-sample[3])<0.000001,
        'bounce preserves incoming/outgoing horizontal speeds at '..sample[1]..'ms')
end
check(PTClient.core.ball.vx==4 and PTClient.core.ball.x==1.2,'bounce rendering never changes authoritative state')
