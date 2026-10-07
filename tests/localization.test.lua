local function check(value,message) checks=(checks or 0)+1; assert(value,message) end
local language='KO'
function getTextOrNull(key) return TranslationData[language] and TranslationData[language][key] end
-- Every presentation dictionary entry resolves via native-style lookup in either language.
for key,english in pairs(TranslationData.EN) do
    if key~='ContextMenu_PT_WeaponRacket' and key~='ContextMenu_PT_SportsRacket' then
        language='KO'; check(PTText.get(english)==TranslationData.KO[key], 'Korean lookup '..key)
        language='EN'; check(PTText.get(english)==english, 'English lookup '..key)
    end
end
language='KO'
check(PTText.message('Double fault: Net. Point: player 2.')=='더블 폴트: 공이 네트에 걸렸습니다. 플레이어 2 득점.','nested point reason translated')
check(PTText.message('First fault: Out. Serve again.')=='첫 폴트: 아웃입니다. 다시 서브하세요.','first fault translated')
check(PTText.message('Two bounces. Practice ready; best 15.')=='공이 두 번 바운스했습니다. 다시 시작할 수 있습니다. 최고 기록 15.','wall restart translated')
check(PTText.message('Wall return: 8.')=='벽 리턴: 8.','wall count translated')
check(PTText.message('Player 2 wins.')=='플레이어 2 승리.','core winner translated')
check(PTText.message('Court width must be 8-10 and length 18-20 tiles (either orientation).')=='코트 너비 8~10칸, 길이 18~20칸으로 지정하세요. (남북·동서 방향 가능)','server court limits translated')
check(PTText.message('Move to the green serve box at the WEST (lower X) baseline.')=='서브 존으로 이동하여 서브하세요.','directional serve rejection translated')
local unusual='민수 %1 [bob] green serve box'
check(PTText.get('%1 Win',unusual)==unusual..' 승리','player names never reinterpreted as placeholders')
check(PTText.message('Unknown future error.')=='Unknown future error.','unknown server errors stay visible')
language='missing'
check(PTText.get('Join %1 (tennis)','court-7')=='Join court-7 (tennis)','missing locale has readable English fallback')
language='KO'
Events.OnGameStart.fire()
PTClient.courts={{id='court-7',mode='tennis',x1=0,y1=0,x2=8,y2=18,z=0}}
local menu=ClientMock.menu()
function ClientMock.player:getSquare() return {getX=function() return 3 end,getY=function() return 4 end} end
Events.OnFillWorldObjectContextMenu.fire(0,menu,{},false)
local options={}
for _,option in ipairs(menu.submenu.options) do options[option.name]=true end
check(options['내 코트 지정 / 다시 그리기'],'court drawing menu Korean')
check(options['참가 court-7 (테니스)'],'join menu Korean with unchanged court ID')
local s={session='ko',slot=1,revision=1,players={unusual,'Alex'},core={court=PTClient.courts[1],phase='ready',points={1,0},server=1,receiverReady=true}}
PTClient.receive('state',s)
local labels={}
PTClient.overlay.drawText=function(_,text) labels[#labels+1]=text end
local function rendered(text)
    for _,label in ipairs(labels) do if label==text then return true end end
    return false
end
PTClient.overlay:render()
check(rendered('서브 존') and rendered('리시브 존'),'world serve/receive labels Korean')
check(rendered('내 서브 차례'),'ready HUD translated')
check(rendered('15  |  0'),'point score unchanged')
PTClient.core.phase='finished'; PTClient.core.winner=1; labels={}; PTClient.overlay:render()
check(rendered(unusual..' 승리'),'winner name preserved in Korean HUD')
PTClient.core.court.mode='wall'; PTClient.core.rally=7; PTClient.core.bestRally=10; labels={}; PTClient.overlay:render()
check(rendered('랠리 7 | 최고 기록 10 | 깊이 18'),'wall metrics Korean')
PTClient.receive('error',{message='Ball is outside racket height (0.15 to 2.4).'})
labels={}; PTClient.overlay:render()
check(rendered('공이 너무 높거나 낮아 칠 수 없습니다.'),'raw server error translated at render boundary')
check(PTClient.message=='Ball is outside racket height (0.15 to 2.4).','translation never mutates authoritative payload')
language='EN'; labels={}; PTClient.overlay:render()
check(rendered('The ball is too high or too low to hit.'),'same payload supports another viewer language')
language='KO'
PTCourtSelector.begin(ClientMock.player,function() end)
local ok,reason=PTCourtSelector.cursor:validate(1,1,false)
check(not ok and reason=='코트 너비 8~10칸, 길이 18~20칸 (남북·동서 방향 가능)','selector limits Korean')
PTCourtSelector.cancel()

