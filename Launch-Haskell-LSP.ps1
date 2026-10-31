$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$data = Join-Path $root "data"

function Add-PortablePath([string]$Path) {
    if ($Path -and (Test-Path -LiteralPath $Path)) { $env:PATH = "$Path;$env:PATH" }
}

$env:CABAL_DIR = Join-Path $data "cabal"
$env:STACK_ROOT = Join-Path $data "stack"
$env:GHCUP_USE_XDG_DIRS = "1"
$env:XDG_CACHE_HOME = Join-Path $data "xdg-cache"
$env:XDG_CONFIG_HOME = Join-Path $data "xdg-config"
$env:XDG_DATA_HOME = Join-Path $data "xdg-data"
$env:XDG_STATE_HOME = Join-Path $data "xdg-state"
$env:ONE_CLICK_RUN_OFFLINE_RUNTIME = "1"
@($env:CABAL_DIR, $env:STACK_ROOT, $env:XDG_CACHE_HOME, $env:XDG_CONFIG_HOME, $env:XDG_DATA_HOME, $env:XDG_STATE_HOME) |
    ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

foreach ($toolRoot in @("ghc", "cabal", "hls", "stack")) {
    Get-ChildItem -LiteralPath (Join-Path $root $toolRoot) -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty DirectoryName -Unique | ForEach-Object { Add-PortablePath $_ }
}
$gcc = Get-ChildItem -LiteralPath (Join-Path $root "ghc") -Filter "gcc.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($gcc) { Add-PortablePath $gcc.DirectoryName }

$server = Get-ChildItem -LiteralPath (Join-Path $root "hls") -Filter "haskell-language-server-wrapper.exe" -Recurse | Select-Object -First 1
if (-not $server) { throw "Bundled Haskell Language Server is missing." }
& $server.FullName @args
exit $LASTEXITCODE
