param([switch]$Check)

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
foreach ($toolRoot in @("ghc", "cabal", "hls", "stack")) {
    Get-ChildItem -LiteralPath (Join-Path $root $toolRoot) -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty DirectoryName -Unique | ForEach-Object { Add-PortablePath $_ }
}

$workspace = Join-Path $root "examples\hello"
$lspLauncher = Join-Path $root "Launch-Haskell-LSP.cmd"
if (-not (Test-Path -LiteralPath $lspLauncher -PathType Leaf)) { throw "HLS launcher is missing: $lspLauncher" }
$settingsPath = Join-Path $workspace ".vscode\settings.json"
$settings = [ordered]@{
    "haskell.manageHLS" = "PATH"
    "haskell.serverExecutablePath" = $lspLauncher
    "haskell.checkProject" = $false
}
[IO.File]::WriteAllText($settingsPath, (($settings | ConvertTo-Json) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
$writtenSettings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
if ($writtenSettings.'haskell.serverExecutablePath' -ne $lspLauncher) {
    throw "VS Code settings do not point at the bundled HLS launcher."
}
if ($Check) {
    Write-Host "VS Code HLS configuration OK: $lspLauncher" -ForegroundColor Green
    exit 0
}

$code = Get-Command code.cmd -ErrorAction SilentlyContinue
if (-not $code) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"),
        (Join-Path $env:ProgramFiles "Microsoft VS Code\bin\code.cmd")
    )
    $codePath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($codePath) { $code = Get-Item -LiteralPath $codePath }
}
if (-not $code) { throw "Microsoft Visual Studio Code was not found. Install VS Code and try again." }

$codePath = if ($code.Source) { $code.Source } else { $code.FullName }
$extensions = @(& $codePath --list-extensions)
if ($extensions -notcontains "haskell.haskell") {
    Write-Warning "The VS Code extension haskell.haskell is not installed. The example will open, but HLS integration will be unavailable."
}
& $codePath --new-window $workspace
if ($LASTEXITCODE -ne 0) { throw "VS Code failed to start (exit code $LASTEXITCODE)." }
