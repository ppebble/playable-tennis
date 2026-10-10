param(
    [string]$Destination = (Join-Path $env:USERPROFILE 'Zomboid/Workshop/PlayableTennis')
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Join-Path $repo 'Contents/mods/PlayableTennis'
$assets = Join-Path $repo 'workshop'
$destinationPath = [IO.Path]::GetFullPath($Destination)
if ($destinationPath -match '(?i)steamapps[\\/]workshop') { throw 'Subscribed Workshop content is read-only' }
$metadataPath = Join-Path $destinationPath 'workshop.txt'
# Keep an existing Workshop ID and visibility when refreshing a prepared upload.
$id = ''
$visibility = 'public'
if (Test-Path -LiteralPath $metadataPath) {
    $existing = Get-Content -LiteralPath $metadataPath -Raw
    if ($existing -notmatch '(?m)^title=Playable Tennis\r?$') { throw 'Destination belongs to another Workshop item' }
    if ($existing -match '(?m)^id=(\d+)\r?$') { $id = $Matches[1] }
    if ($existing -match '(?m)^visibility=([^\r\n]+)') { $visibility = $Matches[1] }
}
$mods = Join-Path $destinationPath 'Contents/mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$target = Join-Path $mods 'PlayableTennis'
New-Item -ItemType Directory -Path $target -Force | Out-Null
Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $target -Recurse -Force
foreach ($name in @('preview.png','preview.gif')) {
    Copy-Item -LiteralPath (Join-Path $assets $name) -Destination (Join-Path $destinationPath $name) -Force
}
$metadata = @('version=1', "id=$id", 'title=Playable Tennis')
$metadata += Get-Content -LiteralPath (Join-Path $assets 'description-en.txt') | ForEach-Object { 'description=' + $_ }
$metadata += @('tags=Build 42;Multiplayer', "visibility=$visibility")
[IO.File]::WriteAllLines($metadataPath, $metadata, [Text.UTF8Encoding]::new($false))
$count = 0
foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File) {
    $copy = Join-Path $target ([IO.Path]::GetRelativePath($source, $file.FullName))
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $copy).Hash) { throw "Hash mismatch: $copy" }
    $count++
}
Write-Output "PASS $count identical mod files; English description, PNG preview and original GIF staged at $destinationPath. No upload performed."
