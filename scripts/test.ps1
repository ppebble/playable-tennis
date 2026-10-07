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
& $Javac -d $build (Join-Path $repo 'tests/SwingAnimationTest.java')
if ($LASTEXITCODE -ne 0) { throw 'Native swing test compilation failed' }
& $Javac -d $build (Join-Path $repo 'tests/TrainingNativeTest.java')
if ($LASTEXITCODE -ne 0) { throw 'Native training XP test compilation failed' }
$java = Join-Path $GamePath 'jre64/bin/java.exe'
& $Javac -d $build (Join-Path $repo 'tests/CourtPropertiesNativeTest.java')
if ($LASTEXITCODE -ne 0) { throw 'Native court property test compilation failed' }
$cp = "$build;$(Join-Path $GamePath 'projectzomboid.jar')"
$core = Join-Path $mod 'media/lua/shared/PT_Core.lua'
$wall = Join-Path $mod 'media/lua/shared/PT_Wall.lua'
$text = Join-Path $mod 'media/lua/client/PT_Text.lua'
# Feed the real translation JSON into the Kahlua presentation tests.
$translationFixture = Join-Path $build 'translation-data.lua'
$fixtureLines = @('TranslationData = {}')
foreach ($language in @('EN','KO')) {
    $fixtureLines += 'TranslationData.' + $language + ' = {'
    $translations = Get-Content (Join-Path $mod "media/lua/shared/Translate/$language/ContextMenu.json") -Raw | ConvertFrom-Json
    foreach ($property in $translations.PSObject.Properties) {
        $fixtureLines += '[' + ($property.Name | ConvertTo-Json -Compress) + '] = ' + ($property.Value | ConvertTo-Json -Compress) + ','
    }
    $fixtureLines += '}'
}
[IO.File]::WriteAllLines($translationFixture, $fixtureLines, [Text.UTF8Encoding]::new($false))
Push-Location $GamePath
try {
& $java -cp $cp CourtPropertiesNativeTest
if ($LASTEXITCODE -ne 0) { throw 'Native court property API verification failed' }
& $java -cp $cp TrainingNativeTest
if ($LASTEXITCODE -ne 0) { throw 'Native training XP verification failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/training-bootstrap.lua') (Join-Path $mod 'media/lua/server/PT_Training.lua') (Join-Path $repo 'tests/training.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Training XP tests failed' }
& $java -cp $cp OverlayHitTest
if ($LASTEXITCODE -ne 0) { throw 'Native UI hit testing failed' }
& $java -cp $cp SwingAnimationTest $mod
if ($LASTEXITCODE -ne 0) { throw 'Native swing animation selection failed' }
& $java -cp $cp LuaHarness $wall $core (Join-Path $repo 'tests/core.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }
& $java -cp $cp LuaHarness $wall (Join-Path $repo 'tests/wall.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Wall geometry tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/server-bootstrap.lua') $core $wall (Join-Path $mod 'media/lua/server/PT_Server.lua') (Join-Path $repo 'tests/server.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Server tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/client-bootstrap.lua') $core $wall $text (Join-Path $mod 'media/lua/client/PT_Client.lua') (Join-Path $repo 'tests/client.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Client tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/client-bootstrap.lua') (Join-Path $repo 'tests/render-bootstrap.lua') $core $wall $text (Join-Path $mod 'media/lua/client/PT_Client.lua') (Join-Path $repo 'tests/render.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Per-frame ball rendering tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/swing-bootstrap.lua') (Join-Path $mod 'media/lua/client/PT_Swing.lua') (Join-Path $repo 'tests/swing.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Cosmetic swing tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/selector-bootstrap.lua') $core $text (Join-Path $mod 'media/lua/client/PT_CourtSelector.lua') (Join-Path $repo 'tests/selector.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Court rectangle selection tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/client-bootstrap.lua') (Join-Path $repo 'tests/selector-client-bootstrap.lua') $core $wall $text (Join-Path $mod 'media/lua/client/PT_CourtSelector.lua') (Join-Path $mod 'media/lua/client/PT_Client.lua') (Join-Path $repo 'tests/selector-client.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Remote-client selector startup integration failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/client-bootstrap.lua') (Join-Path $repo 'tests/selector-client-bootstrap.lua') $core $wall $text (Join-Path $mod 'media/lua/client/PT_CourtSelector.lua') (Join-Path $mod 'media/lua/client/PT_Client.lua') $translationFixture (Join-Path $repo 'tests/localization.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'English/Korean presentation localization failed' }

& $java -cp $cp LuaHarness (Join-Path $repo 'tests/selector-bootstrap.lua') $core (Join-Path $repo 'tests/selector-native-bootstrap.lua') (Join-Path $GamePath 'media/lua/shared/ISBaseObject.lua') (Join-Path $GamePath 'media/lua/server/BuildingObjects/ISBuildingObject.lua') $text (Join-Path $mod 'media/lua/client/PT_CourtSelector.lua') (Join-Path $repo 'tests/selector-native.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Native singleplayer cursor dispatch failed' }
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
if ($itemScript -notmatch 'AttachmentType\s*=\s*Racket\s*,') { throw 'Sports racket must use the native racket equipment attachment type' }
foreach ($property in @('PrimaryAnimMask','SecondaryAnimMask')) {
    if ($itemScript -notmatch "$property\s*=\s*PT_TennisRacket\s*,") { throw "Missing normal-item hand model mask: $property" }
}
$swingPath = Join-Path $mod 'media/AnimSets/player/maskingright/PT_RacketStroke.xml'
[xml]$swing = Get-Content $swingPath -Raw
$node = $swing.animNode
if ([int]$node.m_ConditionPriority -ne 1) { throw 'Owned swing must win native bag/aim node selection' }
if ($node.m_AnimName -ne 'Bob_Attack1Hand01_Hit' -or $node.m_Events) { throw 'Running swing must use event-free native one-handed clip' }
$conditions = @{}
foreach ($condition in $node.m_Conditions) { $conditions[$condition.m_Name] = $condition.m_Value }
if ($conditions.PerformingAction -ne 'RemoveBushLongBlade' -or $conditions.PT_RacketStroke -ne 'true' -or $conditions.Count -ne 2) { throw 'Running mask must belong only to the tennis action' }
$nodeWeights = @{}
foreach ($bone in $node.m_SubStateBoneWeights) { $nodeWeights[$bone.boneName] = [double]$bone.weight }
if ($nodeWeights.Bip01 -ne 0 -or $nodeWeights.Bip01_R_Clavicle -ne 1 -or $nodeWeights.Bip01_Prop1 -ne 1 -or $nodeWeights.Count -ne 3) { throw 'Running swing must mask all bones except right arm and racket prop' }
if ([double]$node.m_SpeedScale -ne 1 -or $node.m_Looped -ne 'false') { throw 'Running swing must play once at normal speed' }
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
$releaseLua = Get-ChildItem (Join-Path $mod 'media/lua') -Recurse -Filter '*.lua'
foreach ($file in $releaseLua) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    if ($text -match 'startSolo|feedTestTarget|enableTestTarget|refreshTestTarget|returnFromTestTarget|feedReceiverReady|SOLO TEST|TEST RETURN TARGET|getAnimationDebug|loggedPlayback|loggedStart') {
        throw "Development feature remains in release: $($file.Name)"
    }
}
$payload = Get-ChildItem (Join-Path $repo 'Contents') -Recurse -File
if ($payload | Where-Object { $_.Name -match '\.test\.|bootstrap|\.java$|\.class$' }) {
    throw 'Development test files must stay outside release Contents'
}
Write-Output 'PASS release excludes test commands, target simulation, animation diagnostics and test payloads'
