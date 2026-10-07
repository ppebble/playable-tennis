-- Only dependencies unrelated to this dispatch are stubbed. Load the actual
-- installed ISBaseObject and ISBuildingObject files in the next harness steps.
function require() end
for _,name in ipairs({"OnDoTileBuilding3","OnDestroyIsoThumpable","RenderOpaqueObjectsInWorld"}) do
    Events[name]={Add=function()end}
end
function getSpecificPlayer() return SelectorMock.player end
function SelectorMock.player:isBuildButtonDown() return SelectorMock.down end
function SelectorMock.player:isBuildButtonReleased() return SelectorMock.released end
