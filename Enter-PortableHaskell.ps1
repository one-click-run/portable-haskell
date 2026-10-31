param(
    [string[]]$Command,
    [switch]$Check
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = $PSScriptRoot

function Add-Path([string]$Path) {
    if ($Path -and (Test-Path -LiteralPath $Path)) {
        $env:PATH = "$Path;$env:PATH"
    }
}

$data = Join-Path $root "data"
$env:CABAL_DIR = Join-Path $data "cabal"
$env:STACK_ROOT = Join-Path $data "stack"
$env:GHCUP_USE_XDG_DIRS = "1"
$env:XDG_CACHE_HOME = Join-Path $data "xdg-cache"
$env:XDG_CONFIG_HOME = Join-Path $data "xdg-config"
$env:XDG_DATA_HOME = Join-Path $data "xdg-data"
$env:XDG_STATE_HOME = Join-Path $data "xdg-state"

@($env:CABAL_DIR, $env:STACK_ROOT, $env:XDG_CACHE_HOME, $env:XDG_CONFIG_HOME, $env:XDG_DATA_HOME, $env:XDG_STATE_HOME) |
    ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

# Add the bundled tools first. Each GHCup isolated install has its own bin folder.
@("ghc\bin", "cabal\bin", "hls\bin", "stack\bin") |
    ForEach-Object { Add-Path (Join-Path $root $_) }

# GHC's Windows distribution includes the matching MinGW toolchain. Discover it
# instead of encoding a version-specific path, so the whole folder can move.
$gcc = Get-ChildItem -LiteralPath (Join-Path $root "ghc") -Filter "gcc.exe" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($gcc) {
    Add-Path $gcc.Directory.FullName
}

if ($Check) {
    foreach ($tool in @("ghc", "ghci", "cabal", "haskell-language-server-wrapper", "stack")) {
        $resolved = Get-Command $tool -ErrorAction SilentlyContinue
        if (-not $resolved) {
            throw "Missing tool: $tool"
        }
        Write-Host ("{0}: {1}" -f $tool, $resolved.Source)
    }
    & ghc --numeric-version
    & cabal --numeric-version
    exit 0
}

if ($Command -and $Command.Count -gt 0) {
    & $Command[0] @($Command | Select-Object -Skip 1)
    exit $LASTEXITCODE
}

$host.UI.RawUI.WindowTitle = "Portable Haskell"
Write-Host "Portable Haskell environment" -ForegroundColor Green
Write-Host ("GHC:   " + (& ghc --numeric-version))
Write-Host ("Cabal: " + (& cabal --numeric-version))
Write-Host "This folder can be moved; the current session does not modify the system PATH." -ForegroundColor DarkGray
& $env:ComSpec /K "prompt (portable-haskell) `$P`$G"

