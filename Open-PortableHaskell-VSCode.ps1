param(
    [switch]$Check,
    [string]$CodePath = $env:ONE_CLICK_RUN_VSCODE,
    [switch]$InstallMissingExtension
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$data = Join-Path $root "data"
$extensionId = "haskell.haskell"

function Add-PortablePath([string]$Path) {
    if ($Path -and (Test-Path -LiteralPath $Path)) { $env:PATH = "$Path;$env:PATH" }
}

function Find-VSCode([string]$RequestedPath) {
    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
            throw "ONE_CLICK_RUN_VSCODE does not point to a file: $RequestedPath"
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }
    foreach ($commandName in @("code.cmd", "code.exe")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) { return $(if ($command.Source) { $command.Source } else { $command.Path }) }
    }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"),
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\Code.exe"),
        (Join-Path $env:ProgramFiles "Microsoft VS Code\bin\code.cmd"),
        (Join-Path $env:ProgramFiles "Microsoft VS Code\Code.exe")
    )
    $match = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
    if ($match) { return $match }
    throw "Microsoft Visual Studio Code was not found. Install VS Code, or set ONE_CLICK_RUN_VSCODE to code.cmd or Code.exe."
}

function Test-OrInstallExtension([string]$VSCode, [string]$Extension) {
    $installed = @(& $VSCode --list-extensions 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "VS Code could not list installed extensions (exit code $LASTEXITCODE)." }
    if ($installed -contains $Extension) { return }

    Write-Warning "Required VS Code extension '$Extension' is not installed."
    $install = $InstallMissingExtension
    if (-not $install -and [Environment]::UserInteractive) {
        $answer = Read-Host "Install it now from the VS Code Marketplace? This requires network access. [y/N]"
        $install = $answer -match '^(?i:y|yes)$'
    }
    if (-not $install) {
        throw "The required extension is missing. Install it with: `"$VSCode`" --install-extension $Extension"
    }
    & $VSCode --install-extension $Extension
    if ($LASTEXITCODE -ne 0) { throw "VS Code failed to install extension '$Extension' (exit code $LASTEXITCODE)." }
    $installed = @(& $VSCode --list-extensions 2>&1)
    if ($LASTEXITCODE -ne 0 -or $installed -notcontains $Extension) {
        throw "VS Code reported success, but extension '$Extension' is still unavailable."
    }
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
$mainFile = Join-Path $workspace "Main.hs"
$lspLauncher = Join-Path $root "Launch-Haskell-LSP.exe"
if (-not (Test-Path -LiteralPath $mainFile -PathType Leaf)) { throw "Bundled Haskell example is missing: $mainFile" }
if (-not (Test-Path -LiteralPath $lspLauncher -PathType Leaf)) { throw "HLS launcher is missing: $lspLauncher" }

# These settings belong only to this dedicated workspace. User settings and
# the example folder's normal .vscode settings are never modified.
$workspaceFile = Join-Path $root "Portable-Haskell.code-workspace"
$workspaceDefinition = [ordered]@{
    folders = @([ordered]@{ path = $workspace })
    settings = [ordered]@{
        "haskell.manageHLS" = "PATH"
        "haskell.serverExecutablePath" = $lspLauncher
        "haskell.checkProject" = $false
    }
}
[IO.File]::WriteAllText($workspaceFile, (($workspaceDefinition | ConvertTo-Json -Depth 8) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
$writtenWorkspace = Get-Content -LiteralPath $workspaceFile -Raw | ConvertFrom-Json
if ($writtenWorkspace.settings.'haskell.serverExecutablePath' -ne $lspLauncher) {
    throw "The dedicated VS Code workspace does not point at the bundled HLS launcher."
}
if ($Check) {
    Write-Host "VS Code HLS workspace configuration OK: $workspaceFile" -ForegroundColor Green
    exit 0
}

$resolvedCode = Find-VSCode $CodePath
Test-OrInstallExtension $resolvedCode $extensionId
& $resolvedCode --new-window $workspaceFile
if ($LASTEXITCODE -ne 0) { throw "VS Code failed to start (exit code $LASTEXITCODE)." }
