param(
    [switch]$Install,
    [string]$ModsPath = (Join-Path $env:USERPROFILE 'Zomboid/mods')
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Join-Path $repo 'Contents/mods/PlayableTennis'
$base = if ($Install) { [IO.Path]::GetFullPath($ModsPath) } else { Join-Path $repo '.stage/Contents/mods' }
if ($base -match '(?i)steamapps[\\/]workshop') { throw 'Subscribed Workshop content is read-only' }
New-Item -ItemType Directory -Path $base -Force | Out-Null
$target = [IO.Path]::GetFullPath((Join-Path $base 'PlayableTennis'))
if ((Split-Path $target -Parent) -ne [IO.Path]::GetFullPath($base).TrimEnd('\','/')) { throw 'Target escaped destination' }
if (Test-Path -LiteralPath $target) {
    $info = Join-Path $target '42/mod.info'
    if (-not (Test-Path $info) -or (Get-Content $info -Raw) -notmatch '(?m)^id=PlayableTennis\s*$') { throw 'Existing folder is not owned by this mod' }
    $backup = Join-Path $repo ('.build/backups/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '/PlayableTennis')
    New-Item -ItemType Directory -Path (Split-Path $backup -Parent) -Force | Out-Null
    Move-Item -LiteralPath $target -Destination $backup
}
Copy-Item -LiteralPath $source -Destination $target -Recurse
$count = 0
foreach ($file in Get-ChildItem $source -Recurse -File) {
    $relative = [IO.Path]::GetRelativePath($source,$file.FullName)
    $copy = Join-Path $target $relative
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $copy).Hash) { throw "Hash mismatch: $relative" }
    $count++
}
Write-Output "PASS $count identical files at $target"
