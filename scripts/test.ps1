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
Push-Location $GamePath
try {
& $java -cp $cp LuaHarness $core (Join-Path $repo 'tests/core.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/server-bootstrap.lua') $core (Join-Path $mod 'media/lua/server/PT_Server.lua') (Join-Path $repo 'tests/server.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Server tests failed' }
& $java -cp $cp LuaHarness (Join-Path $repo 'tests/client-bootstrap.lua') (Join-Path $mod 'media/lua/client/PT_Client.lua') (Join-Path $repo 'tests/client.test.lua')
if ($LASTEXITCODE -ne 0) { throw 'Client tests failed' }
$lua = @(Get-ChildItem (Join-Path $mod 'media/lua') -Recurse -Filter '*.lua' | ForEach-Object FullName)
& $java '-DcompileOnly=true' -cp $cp LuaHarness @lua
if ($LASTEXITCODE -ne 0) { throw 'Production Lua syntax failed' }
} finally { Pop-Location }
$en = Get-Content (Join-Path $mod 'media/lua/shared/Translate/EN/Sandbox.json') -Raw | ConvertFrom-Json
$ko = Get-Content (Join-Path $mod 'media/lua/shared/Translate/KO/Sandbox.json') -Raw | ConvertFrom-Json
if (Compare-Object @($en.PSObject.Properties.Name) @($ko.PSObject.Properties.Name)) { throw 'Translation keys differ' }
$errors = $null
foreach ($file in Get-ChildItem $PSScriptRoot -Filter '*.ps1') {
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$null,[ref]$errors)
    if ($errors.Count) { throw "PowerShell parse error: $($file.Name)" }
}
Write-Output 'PASS production Lua syntax, sandbox translations, PowerShell syntax'
