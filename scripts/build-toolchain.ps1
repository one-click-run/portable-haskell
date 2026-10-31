param(
    [string]$GhcVersion = "recommended",
    [string]$CabalVersion = "recommended",
    [string]$HlsVersion = "recommended",
    [string]$StackVersion = "recommended",
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\dist"),
    [string]$Ghcup = "ghcup"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version Latest

function Invoke-GhcupInstall([string]$Tool, [string]$Version, [string]$Destination) {
    Write-Host "Installing $Tool $Version into $Destination"
    & $Ghcup --cache install $Tool $Version --isolate $Destination
    if ($LASTEXITCODE -ne 0) {
        throw "ghcup failed to install $Tool $Version"
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildRoot = Join-Path $repoRoot ".build"
$payload = Join-Path $buildRoot "payload"
if (Test-Path -LiteralPath $buildRoot) {
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $payload, $OutputDirectory | Out-Null

Invoke-GhcupInstall "ghc" $GhcVersion (Join-Path $payload "ghc")
Invoke-GhcupInstall "cabal" $CabalVersion (Join-Path $payload "cabal")
Invoke-GhcupInstall "hls" $HlsVersion (Join-Path $payload "hls")
Invoke-GhcupInstall "stack" $StackVersion (Join-Path $payload "stack")

Copy-Item -LiteralPath (Join-Path $repoRoot "Enter-PortableHaskell.ps1") -Destination $payload
Copy-Item -LiteralPath (Join-Path $repoRoot "LICENSE") -Destination $payload
Copy-Item -LiteralPath (Join-Path $repoRoot "THIRD_PARTY_NOTICES.md") -Destination $payload
Copy-Item -LiteralPath (Join-Path $repoRoot "examples") -Destination $payload -Recurse

# Validate the actual isolated layouts before spending time compressing them.
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $payload "Enter-PortableHaskell.ps1") -Check
if ($LASTEXITCODE -ne 0) {
    throw "The unpacked portable environment failed its smoke test."
}

$ghcExe = Join-Path $payload "ghc\bin\ghc.exe"
if (-not (Test-Path -LiteralPath $ghcExe)) {
    throw "GHC isolated install does not contain ghc.exe at the expected location."
}
$resolvedGhcVersion = (& $ghcExe --numeric-version).Trim()
$assetName = "portable-haskell-ghc-$resolvedGhcVersion-windows-x86_64.zip"
$archive = Join-Path $OutputDirectory $assetName
if (Test-Path -LiteralPath $archive) {
    Remove-Item -LiteralPath $archive -Force
}

$sevenZip = Get-Command 7z -ErrorAction SilentlyContinue
Push-Location $payload
try {
    if ($sevenZip) {
        & $sevenZip.Source a -tzip -mx=5 $archive ".\*"
        if ($LASTEXITCODE -ne 0) { throw "7-Zip failed." }
    } else {
        Compress-Archive -Path ".\*" -DestinationPath $archive -CompressionLevel Optimal
    }
} finally {
    Pop-Location
}

$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
$checksumPath = "$archive.sha256"
[IO.File]::WriteAllText($checksumPath, "$hash  $assetName`n", [Text.UTF8Encoding]::new($false))
Write-Host "Created $archive"
Write-Host "Created $checksumPath"

