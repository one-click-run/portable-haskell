param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\dist"),
    [string]$Ghcup
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version Latest

$expectedGhcupSha256 = "94da902a2853b1de1df509d04da900a05258480759efdb4f654e66956b6f30db"
$downloadedGhcup = $false
if (-not $Ghcup) {
    $Ghcup = Join-Path ([IO.Path]::GetTempPath()) "portable-haskell-ghcup-$expectedGhcupSha256.exe"
    if (-not (Test-Path -LiteralPath $Ghcup)) {
        Invoke-WebRequest -UseBasicParsing `
            -Uri "https://downloads.haskell.org/~ghcup/x86_64-mingw64-ghcup.exe" `
            -OutFile $Ghcup
        $downloadedGhcup = $true
    }
}

$actualGhcupSha256 = (Get-FileHash -LiteralPath $Ghcup -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualGhcupSha256 -ne $expectedGhcupSha256) {
    if ($downloadedGhcup) { Remove-Item -LiteralPath $Ghcup -Force }
    throw "GHCup SHA-256 mismatch. Expected $expectedGhcupSha256, got $actualGhcupSha256. The published input may have moved; use -Ghcup with a preserved matching file."
}

& (Join-Path $PSScriptRoot "build-toolchain.ps1") `
    -GhcVersion "9.10.3" `
    -CabalVersion "3.16.1.0" `
    -HlsVersion "2.14.0.0" `
    -StackVersion "3.11.1" `
    -OutputDirectory $OutputDirectory `
    -Ghcup $Ghcup `
    -GhcupSha256 $expectedGhcupSha256
if ($LASTEXITCODE -ne 0) { throw "Release reproduction failed with exit code $LASTEXITCODE." }
