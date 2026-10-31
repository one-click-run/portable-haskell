$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$files = @(
    "init.ps1",
    "Enter-PortableHaskell.ps1",
    "Launch-Haskell-LSP.ps1",
    "Open-PortableHaskell-VSCode.ps1",
    "scripts\build-toolchain.ps1",
    "scripts\reproduce-release.ps1"
)

foreach ($file in $files) {
    $path = Join-Path $repoRoot $file
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Error "${file}: $_" }
        throw "PowerShell syntax validation failed for $file"
    }
    Write-Host "Syntax OK: $file"
}

& node --check (Join-Path $repoRoot "scripts\test-node-spawn.js")
if ($LASTEXITCODE -ne 0) { throw "JavaScript syntax validation failed for scripts\test-node-spawn.js" }
Write-Host "Syntax OK: scripts\test-node-spawn.js"
& node --check (Join-Path $repoRoot "scripts\test-hls-hover.js")
if ($LASTEXITCODE -ne 0) { throw "JavaScript syntax validation failed for scripts\test-hls-hover.js" }
Write-Host "Syntax OK: scripts\test-hls-hover.js"

$init = Get-Content -LiteralPath (Join-Path $repoRoot "init.ps1") -Raw
foreach ($required in @("Get-FileHash", "SHA-256", "browser_download_url", "Enter-PortableHaskell.ps1", "--continue-at", "--retry-all-errors", '$Archive', '$localArchive')) {
    if (-not $init.Contains($required)) {
        throw "init.ps1 is missing required installer behavior: $required"
    }
}
foreach ($required in @("Expand-ToolchainArchive", "tar.exe", "Checking the extracted toolchain", '$installationComplete')) {
    if (-not $init.Contains($required)) {
        throw "init.ps1 is missing resilient extraction behavior: $required"
    }
}
foreach ($required in @('$vscodeLauncher', 'Open-PortableHaskell-VSCode.ps1')) {
    if (-not $init.Contains($required)) { throw "init.ps1 is missing the VS Code entry point: $required" }
}
$vscodeEntry = Get-Content -LiteralPath (Join-Path $repoRoot "Open-PortableHaskell-VSCode.ps1") -Raw
foreach ($required in @("Portable-Haskell.code-workspace", "ONE_CLICK_RUN_VSCODE", "haskell.haskell", "--list-extensions")) {
    if (-not $vscodeEntry.Contains($required)) { throw "VS Code entry point is missing prerequisite or isolation behavior: $required" }
}
if ($vscodeEntry.Contains('.vscode\settings.json')) { throw "VS Code entry point must not modify folder settings." }
if ($init -match '(?m)^\s*Expand-Archive\b') {
    throw "init.ps1 must not use the unreliable Windows PowerShell Expand-Archive path."
}

$launcher = Get-Content -LiteralPath (Join-Path $repoRoot "Enter-PortableHaskell.ps1") -Raw
foreach ($required in @("CABAL_DIR", "STACK_ROOT", "XDG_CACHE_HOME", '$PSScriptRoot')) {
    if (-not $launcher.Contains($required)) {
        throw "Portable launcher is missing required isolation behavior: $required"
    }
}
foreach ($forbidden in @("Invoke-WebRequest", "Invoke-RestMethod", "curl.exe", "cabal update", "stack setup")) {
    if ($launcher.Contains($forbidden)) {
        throw "Portable launcher contains forbidden runtime network behavior: $forbidden"
    }
}

foreach ($requiredFile in @("OFFLINE-GUARANTEE.md", "BUILDING.md", "REPRODUCING.md")) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $requiredFile))) {
        throw "Missing release documentation: $requiredFile"
    }
}
foreach ($requiredFile in @(
    "Launch-Haskell-LSP.cmd",
    "native\Launch-Haskell-LSP.c",
    "scripts\test-node-spawn.js",
    "scripts\test-hls-hover.js",
    "examples\hello\hello.cabal",
    "examples\hello\hie.yaml",
    "examples\hello\.vscode\extensions.json"
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $requiredFile))) {
        throw "Missing VS Code integration file: $requiredFile"
    }
}

Write-Host "All repository tests passed." -ForegroundColor Green

