param(
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
    [string]$Javac = 'C:\Users\ask13\.jdks\ms-21.0.8\bin\javac.exe'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo '.build'
$mod = Join-Path $repo 'Contents/mods/PlayableTennis/42'
New-Item -ItemType Directory -Path $build -Force | Out-Null
& $Javac -d $build (Join-Path $repo 'tests/LuaHarness.java')
if ($LASTEXITCODE -ne 0) { throw 'Harness compilation failed' }
& $Javac -d $build (Join-Path $repo 'tests/OverlayHitTest.java')
if ($LASTEXITCODE -ne 0) { throw 'Native UI test compilation failed' }
$java = Join-Path $GamePath 'jre64/bin/java.exe'
$cp = "$build;$(Join-Path $GamePath 'projectzomboid.jar')"
$core = Join-Path $mod 'media/lua/shared/PT_Core.lua'
$wall = Join-Path $mod 'media/lua/shared/PT_Wall.lua'
Push-Location $GamePath
try {
& $java -cp $cp OverlayHitTest
if ($LASTEXITCODE -ne 0) { throw 'Native UI hit testing failed' }
& $java -cp $cp LuaHarness $wall $core (Join-Path $repo 'tests/core.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }
& $java -cp $cp LuaHarness $wall (Join-Path $repo 'tests/wall.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Wall geometry tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/server-bootstrap.lua') $core $wall (Join-Path $mod 'media/lua/server/PT_Server.lua') (Join-Path $repo 'tests/server.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Server tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/client-bootstrap.lua') $core $wall (Join-Path $mod 'media/lua/client/PT_Client.lua') (Join-Path $repo 'tests/client.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Client tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/client-bootstrap.lua') (Join-Path $repo 'tests/render-bootstrap.lua') $core $wall (Join-Path $mod 'media/lua/client/PT_Client.lua') (Join-Path $repo 'tests/render.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Per-frame ball rendering tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/swing-bootstrap.lua') (Join-Path $mod 'media/lua/client/PT_Swing.lua') (Join-Path $repo 'tests/swing.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Cosmetic swing tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/selector-bootstrap.lua') (Join-Path $mod 'media/lua/client/PT_CourtSelector.lua') (Join-Path $repo 'tests/selector.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Court rectangle selection tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/items-bootstrap.lua') (Join-Path $mod 'media/lua/shared/PT_ConvertRacket.lua') (Join-Path $mod 'media/lua/client/PT_RacketMenu.lua') (Join-Path $repo 'tests/items.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Racket conversion tests failed' }
$lua = @(Get-ChildItem (Join-Path $mod 'media/lua') -Recurse -Filter '*.lua' | ForEach-Object FullName)
& $java '-DcompileOnly=true' -cp $cp LuaHarness @lua
if ($LASTEXITCODE -ne 0) { throw 'Production Lua syntax failed' }
} finally { Pop-Location }
foreach ($category in @('Sandbox','ItemName','ContextMenu')) {
    $en = Get-Content (Join-Path $mod "media/lua/shared/Translate/EN/$category.json") -Raw | ConvertFrom-Json
    $ko = Get-Content (Join-Path $mod "media/lua/shared/Translate/KO/$category.json") -Raw | ConvertFrom-Json
    if (Compare-Object @($en.PSObject.Properties.Name) @($ko.PSObject.Properties.Name)) { throw "$category translation keys differ" }
}
$itemScript = Get-Content (Join-Path $mod 'media/scripts/PT_Items.txt') -Raw
if ($itemScript -notmatch 'ItemType\s*=\s*base:normal\s*,' -or $itemScript -match '(MinDamage|MaxDamage|base:weapon)') {
    throw 'Sports racket must remain a non-weapon item'
}
foreach ($property in @('Icon','StaticModel','WorldStaticModel')) {
    if ($itemScript -notmatch "$property\s*=\s*TennisRacket\s*,") { throw "Missing native racket appearance: $property" }
}
foreach ($property in @('PrimaryAnimMask','SecondaryAnimMask')) {
    if ($itemScript -notmatch "$property\s*=\s*PT_TennisRacket\s*,") { throw "Missing normal-item hand model mask: $property" }
}
$swingPath = Join-Path $mod 'media/AnimSets/player/maskingright/PT_TennisSwing.xml'
[xml]$swing = Get-Content $swingPath -Raw
[xml]$actionSwing = Get-Content (Join-Path $mod 'media/AnimSets/player/actions/PT_TennisSwing.xml') -Raw
# Both layers need an owned node: actions otherwise selects Bob_EmoteSurrender;
# run/sprint exclude actions and require the maskingright node instead.
foreach ($node in @($swing.animNode, $actionSwing.animNode)) {
    if ($node.m_AnimName -ne 'Bob_Attack1Hand01_Hit' -or $node.m_Events) { throw 'Swing must use event-free native one-handed attack' }
    $nodeConditions = @{}
    foreach ($condition in $node.m_Conditions) { $nodeConditions[$condition.m_Name] = $condition.m_Value }
    if ($nodeConditions.PerformingAction -ne 'PT_TennisSwing' -or $nodeConditions.RightHandMask -ne 'PT_TennisRacket') { throw 'Both swing layers must match the sports action explicitly' }
    $nodeWeights = @{}
    foreach ($bone in $node.m_SubStateBoneWeights) { $nodeWeights[$bone.boneName] = [double]$bone.weight }
    if ($nodeWeights.Bip01 -ne 0 -or $nodeWeights.Bip01_R_Clavicle -ne 1 -or $nodeWeights.Bip01_Prop1 -ne 1 -or $nodeWeights.Count -ne 3) { throw 'Swing must mask all bones except right arm and racket prop' }
    if ([double]$node.m_SpeedScale -ne 1 -or $node.m_Looped -ne 'false') { throw 'Swing must play once at normal one-second speed' }
}
$conditions = @{}
foreach ($condition in $swing.animNode.m_Conditions) { $conditions[$condition.m_Name] = $condition.m_Value }
if ($conditions.RightHandMask -ne 'PT_TennisRacket' -or $conditions.PerformingAction -ne 'PT_TennisSwing') { throw 'Swing must be isolated to sports racket and active action' }
foreach ($state in @('idle','movement','aim','run','sprint')) {
    [xml]$tags = Get-Content (Join-Path $GamePath "media/actiongroups/player/$state/childTags.xml") -Raw
    if (@($tags.childTags.tag) -notcontains 'maskingright') { throw "Native state cannot display racket swing: $state" }
}
$weights = @{}
foreach ($bone in $swing.animNode.m_SubStateBoneWeights) { $weights[$bone.boneName] = [double]$bone.weight }
if ($weights.Bip01_R_Clavicle -ne 1 -or $weights.Bip01 -ne 0) { throw 'Swing must animate right arm without replacing locomotion' }
$errors = $null
foreach ($file in Get-ChildItem $PSScriptRoot -Filter '*.ps1') {
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$null,[ref]$errors)
    if ($errors.Count) { throw "PowerShell parse error: $($file.Name)" }
}
Write-Output 'PASS production Lua syntax, EN/KO translations, non-weapon item/appearance contract, PowerShell syntax'
