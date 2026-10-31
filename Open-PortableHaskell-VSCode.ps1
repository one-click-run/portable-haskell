param(
    [switch]$Check,
    [string]$CodePath = $env:ONE_CLICK_RUN_VSCODE,
    [switch]$CheckExtensions
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$data = Join-Path $root "data"

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

function Read-BundledExtensionManifest {
    $manifestPath = Join-Path $root "vscode-extensions\extensions.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Bundled extension manifest is missing: $manifestPath" }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    foreach ($extension in $manifest.extensions) {
        $vsix = Join-Path (Split-Path -Parent $manifestPath) $extension.file
        if (-not (Test-Path -LiteralPath $vsix -PathType Leaf)) { throw "Bundled VSIX is missing: $vsix" }
        $actual = (Get-FileHash -LiteralPath $vsix -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $extension.sha256) { throw "Bundled VSIX checksum mismatch: $($extension.file)" }
    }
    return $manifest
}

function Install-BundledExtensions([string]$VSCode, $Manifest) {
    $versionText = @(& $VSCode --version 2>&1)[0]
    if ($LASTEXITCODE -ne 0 -or -not $versionText) { throw "VS Code could not report its version." }
    if ([version]$versionText -lt [version]$Manifest.minimumVSCodeVersion) {
        throw "VS Code $versionText is too old. This portable environment requires VS Code $($Manifest.minimumVSCodeVersion) or newer."
    }

    $userData = Join-Path $data "vscode-user-data"
    $extensionsDir = Join-Path $data "vscode-extensions"
    $userSettingsDir = Join-Path $userData "User"
    New-Item -ItemType Directory -Path $extensionsDir, $userSettingsDir -Force | Out-Null
    $settingsPath = Join-Path $userSettingsDir "settings.json"
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
        $isolatedSettings = [ordered]@{
            "extensions.autoCheckUpdates" = $false
            "extensions.autoUpdate" = $false
            "telemetry.telemetryLevel" = "off"
        }
        [IO.File]::WriteAllText($settingsPath, (($isolatedSettings | ConvertTo-Json) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
    }

    $installed = @(& $VSCode --user-data-dir $userData --extensions-dir $extensionsDir --list-extensions --show-versions 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "VS Code could not inspect the portable extension directory." }
    foreach ($extension in $Manifest.extensions) {
        $expected = "$($extension.id)@$($extension.version)"
        if ($installed -notcontains $expected) {
            $vsix = Join-Path $root "vscode-extensions\$($extension.file)"
            & $VSCode --user-data-dir $userData --extensions-dir $extensionsDir --install-extension $vsix --force | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "Offline installation failed for $expected." }
        }
    }
    $installed = @(& $VSCode --user-data-dir $userData --extensions-dir $extensionsDir --list-extensions --show-versions 2>&1)
    foreach ($extension in $Manifest.extensions) {
        $expected = "$($extension.id)@$($extension.version)"
        if ($installed -notcontains $expected) { throw "Portable extension verification failed: $expected" }
    }
    return [pscustomobject]@{ UserData = $userData; Settings = $settingsPath; Extensions = $extensionsDir }
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
$extensionManifest = Read-BundledExtensionManifest
if ($Check) {
    Write-Host "VS Code HLS workspace configuration OK: $workspaceFile" -ForegroundColor Green
    Write-Host "Bundled VSIX checksums OK." -ForegroundColor Green
    exit 0
}

$resolvedCode = Find-VSCode $CodePath
$portableCode = Install-BundledExtensions $resolvedCode $extensionManifest
if ($CheckExtensions) {
    Write-Host "Offline VS Code extension installation OK: $($portableCode.Extensions)" -ForegroundColor Green
    exit 0
}
& $resolvedCode --user-data-dir $portableCode.UserData --extensions-dir $portableCode.Extensions --new-window $workspaceFile
if ($LASTEXITCODE -ne 0) { throw "VS Code failed to start (exit code $LASTEXITCODE)." }
