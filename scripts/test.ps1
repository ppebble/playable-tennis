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
$java = Join-Path $GamePath 'jre64/bin/java.exe'
$cp = "$build;$(Join-Path $GamePath 'projectzomboid.jar')"
$core = Join-Path $mod 'media/lua/shared/PT_Core.lua'
$wall = Join-Path $mod 'media/lua/shared/PT_Wall.lua'
Push-Location $GamePath
try {
& $java -cp $cp LuaHarness $core (Join-Path $repo 'tests/core.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }
& $java -cp $cp LuaHarness $wall (Join-Path $repo 'tests/wall.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Wall geometry tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/server-bootstrap.lua') $core $wall (Join-Path $mod 'media/lua/server/PT_Server.lua') (Join-Path $repo 'tests/server.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Server tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/client-bootstrap.lua') $core $wall (Join-Path $mod 'media/lua/client/PT_Client.lua') (Join-Path $repo 'tests/client.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Client tests failed' }
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
$errors = $null
foreach ($file in Get-ChildItem $PSScriptRoot -Filter '*.ps1') {
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$null,[ref]$errors)
    if ($errors.Count) { throw "PowerShell parse error: $($file.Name)" }
}
Write-Output 'PASS production Lua syntax, EN/KO translations, non-weapon item/appearance contract, PowerShell syntax'
