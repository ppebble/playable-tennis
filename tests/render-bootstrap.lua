Events.OnPostRender={Add=function(fn) ClientMock.renderFrame=fn end}
function getPlayer() return ClientMock.renderPlayer or ClientMock.player end
function getCore() return {isDoingTextEntry=function() return false end,getZoom=function() return ClientMock.zoom or 1 end} end
function getRenderer() return {render=function(_,texture,x,y,w,h,r,g,b,a,consumer)
    ClientMock.worldDraws=ClientMock.worldDraws or {}
    table.insert(ClientMock.worldDraws,{x=x,y=y,w=w,h=h})
end} end
