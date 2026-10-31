param(
    [string]$GhcVersion = "9.10.3",
    [string]$CabalVersion = "3.16.1.0",
    [string]$HlsVersion = "2.14.0.0",
    [string]$StackVersion = "3.11.1",
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\dist"),
    [string]$Ghcup = "ghcup",
    [string]$GhcupSha256 = "unknown"
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
Copy-Item -LiteralPath (Join-Path $repoRoot "OFFLINE-GUARANTEE.md") -Destination $payload
Copy-Item -LiteralPath (Join-Path $repoRoot "examples") -Destination $payload -Recurse

$ghcExe = Join-Path $payload "ghc\bin\ghc.exe"
if (-not (Test-Path -LiteralPath $ghcExe)) {
    throw "GHC isolated install does not contain ghc.exe at the expected location."
}
$resolvedGhcVersion = (& $ghcExe --numeric-version).Trim()

# GHCup's HLS archive contains servers for every supported GHC. A portable
# bundle ships one GHC, so retain only its matching server and the wrapper.
$hlsExecutables = @(Get-ChildItem -LiteralPath (Join-Path $payload "hls") -Filter "haskell-language-server-*.exe" -Recurse)
$hlsExecutables | Where-Object {
    $_.BaseName -ne "haskell-language-server-wrapper" -and
    $_.BaseName -notlike "haskell-language-server-$resolvedGhcVersion*"
} | Remove-Item -Force

$matchingHls = @(Get-ChildItem -LiteralPath (Join-Path $payload "hls") -Filter "haskell-language-server-$resolvedGhcVersion*.exe" -Recurse)
$hlsWrapper = @(Get-ChildItem -LiteralPath (Join-Path $payload "hls") -Filter "haskell-language-server-wrapper.exe" -Recurse)
if ($matchingHls.Count -eq 0 -or $hlsWrapper.Count -eq 0) {
    throw "HLS does not contain both a wrapper and a server for GHC $resolvedGhcVersion."
}

$cabalExe = Get-ChildItem -LiteralPath (Join-Path $payload "cabal") -Filter "cabal.exe" -Recurse | Select-Object -First 1
$stackExe = Get-ChildItem -LiteralPath (Join-Path $payload "stack") -Filter "stack.exe" -Recurse | Select-Object -First 1
if (-not $cabalExe -or -not $stackExe) { throw "Could not resolve the isolated Cabal or Stack executable." }
$resolvedCabalVersion = (& $cabalExe.FullName --numeric-version).Trim()
$hlsVersionLine = (& $hlsWrapper[0].FullName --version | Select-Object -First 1)
$resolvedHlsVersion = [regex]::Match($hlsVersionLine, '\d+\.\d+\.\d+\.\d+').Value
$resolvedStackVersion = ((& $stackExe.FullName --numeric-version | Select-Object -First 1)).Trim()
if (-not $resolvedHlsVersion) { throw "Could not parse the HLS version from: $hlsVersionLine" }

$manifest = [ordered]@{
    schema = "https://one-click-run.github.io/source-manifest/v1"
    project = "one-click-run/portable-haskell"
    platform = "windows-x86_64"
    offlineRuntime = $true
    repositoryCommit = $(if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { (git -C $repoRoot rev-parse HEAD).Trim() })
    buildInput = [ordered]@{
        name = "GHCup"
        source = "https://downloads.haskell.org/~ghcup/x86_64-mingw64-ghcup.exe"
        sha256 = $GhcupSha256
    }
    components = @(
        [ordered]@{ name = "GHC"; version = $resolvedGhcVersion; source = "ghcup"; license = "BSD-3-Clause" },
        [ordered]@{ name = "cabal-install"; version = $resolvedCabalVersion; source = "ghcup"; license = "BSD-3-Clause" },
        [ordered]@{ name = "haskell-language-server"; version = $resolvedHlsVersion; source = "ghcup"; license = "Apache-2.0" },
        [ordered]@{ name = "stack"; version = $resolvedStackVersion; source = "ghcup"; license = "BSD-3-Clause" }
    )
}
$manifestJson = $manifest | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText((Join-Path $payload "SOURCE-MANIFEST.json"), $manifestJson + "`n", [Text.UTF8Encoding]::new($false))

$spdxPackages = @($manifest.components | ForEach-Object {
    [ordered]@{
        SPDXID = "SPDXRef-Package-" + ($_.name -replace '[^A-Za-z0-9.-]', '-')
        name = $_.name
        versionInfo = $_.version
        downloadLocation = "NOASSERTION"
        filesAnalyzed = $false
        licenseConcluded = $_.license
        licenseDeclared = $_.license
        copyrightText = "NOASSERTION"
    }
})
$sbom = [ordered]@{
    spdxVersion = "SPDX-2.3"
    dataLicense = "CC0-1.0"
    SPDXID = "SPDXRef-DOCUMENT"
    name = "portable-haskell-$resolvedGhcVersion-windows-x86_64"
    documentNamespace = "https://github.com/one-click-run/portable-haskell/releases/tag/toolchain/spdx/$resolvedGhcVersion"
    creationInfo = [ordered]@{ created = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"); creators = @("Tool: one-click-run portable-haskell build-toolchain.ps1") }
    packages = $spdxPackages
}
[IO.File]::WriteAllText((Join-Path $payload "SBOM.spdx.json"), ($sbom | ConvertTo-Json -Depth 8) + "`n", [Text.UTF8Encoding]::new($false))

# Validate the actual isolated layouts before spending time compressing them.
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $payload "Enter-PortableHaskell.ps1") -Check
if ($LASTEXITCODE -ne 0) {
    throw "The unpacked portable environment failed its smoke test."
}

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
Copy-Item -LiteralPath (Join-Path $payload "SOURCE-MANIFEST.json") -Destination (Join-Path $OutputDirectory "$assetName.source-manifest.json") -Force
Copy-Item -LiteralPath (Join-Path $payload "SBOM.spdx.json") -Destination (Join-Path $OutputDirectory "$assetName.spdx.json") -Force
Write-Host "Created $archive"
Write-Host "Created $checksumPath"

