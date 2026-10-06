local function check(value,message) checks=(checks or 0)+1; assert(value,message) end
local function state(rev,x,bounces)
    return {session='render',slot=1,revision=rev,core={court={x1=0,x2=8,y1=0,y2=18,z=0,mode='tennis'},
        phase='rally',shotId=1,bounces=bounces or 0,ball={x=x,y=10,z=1},points={0,0},games={0,0},server=1}}
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
