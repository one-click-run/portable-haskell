param(
    [string]$SelectedAsset = $env:ONE_CLICK_RUN_PORTABLE_HASKELL_SELECTED_ASSET,
    [string]$InstallName = $env:ONE_CLICK_RUN_PORTABLE_HASKELL_INSTALL_NAME,
    [string]$Repository = $(if ($env:ONE_CLICK_RUN_PORTABLE_HASKELL_REPOSITORY) { $env:ONE_CLICK_RUN_PORTABLE_HASKELL_REPOSITORY } else { "one-click-run/portable-haskell" }),
    [string]$ReleaseTag = $(if ($env:ONE_CLICK_RUN_PORTABLE_HASKELL_RELEASE_TAG) { $env:ONE_CLICK_RUN_PORTABLE_HASKELL_RELEASE_TAG } else { "toolchain" }),
    [switch]$Force = ($env:ONE_CLICK_RUN_PORTABLE_HASKELL_FORCE -eq "1")
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Set-StrictMode -Version Latest

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Select-Asset($Assets) {
    if ($SelectedAsset) {
        $match = @($Assets | Where-Object { $_.name -eq $SelectedAsset })
        if ($match.Count -ne 1) {
            throw "Release 中不存在资产: $SelectedAsset"
        }
        return $match[0]
    }

    if (@($Assets).Count -eq 1) {
        return @($Assets)[0]
    }

    $grid = Get-Command Out-GridView -ErrorAction SilentlyContinue
    if ($grid -and [Environment]::UserInteractive) {
        return $Assets | Select-Object name, size, updated_at, browser_download_url |
            Out-GridView -Title "选择 portable-haskell 工具链" -OutputMode Single
    }

    Write-Host "可用工具链："
    for ($i = 0; $i -lt @($Assets).Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), @($Assets)[$i].name)
    }
    $choice = Read-Host "请输入序号"
    $index = 0
    if (-not [int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt @($Assets).Count) {
        throw "选择无效。"
    }
    return @($Assets)[$index - 1]
}

if ($env:PROCESSOR_ARCHITECTURE -ne "AMD64" -and $env:PROCESSOR_ARCHITEW6432 -ne "AMD64") {
    throw "目前仅支持 Windows x86-64。"
}

$installBase = (Get-Location).Path
$headers = @{ Accept = "application/vnd.github+json"; "User-Agent" = "one-click-run-portable-haskell" }
$apiUrl = "https://api.github.com/repos/$Repository/releases/tags/$ReleaseTag"

Write-Step "读取 $Repository 的 $ReleaseTag Release"
$release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
$zipAssets = @($release.assets | Where-Object { $_.name -match '^portable-haskell-.*-windows-x86_64\.zip$' })
if ($zipAssets.Count -eq 0) {
    throw "Release 中没有 Windows x86-64 工具链。维护者需要先运行 Publish toolchain 工作流。"
}

$asset = Select-Asset $zipAssets
if (-not $asset) {
    Write-Host "未选择工具链，安装已取消。"
    return
}

$versionLabel = $asset.name -replace '^portable-haskell-', '' -replace '-windows-x86_64\.zip$', ''
if (-not $InstallName) {
    $InstallName = $versionLabel
}
if ($InstallName -notmatch '^[A-Za-z0-9._-]+$') {
    throw "安装名称只能包含字母、数字、点、下划线和连字符。"
}

$folderName = "OCR-portable-haskell-$InstallName"
$destination = Join-Path $installBase $folderName
$launcher = Join-Path $installBase "$folderName.cmd"
if ((Test-Path -LiteralPath $destination) -or (Test-Path -LiteralPath $launcher)) {
    if (-not $Force) {
        throw "目标 $folderName 已存在。请更换安装名称；如确需覆盖，设置 ONE_CLICK_RUN_PORTABLE_HASKELL_FORCE=1。"
    }
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    if (Test-Path -LiteralPath $launcher) {
        Remove-Item -LiteralPath $launcher -Force
    }
}

$checksumName = "$($asset.name).sha256"
$checksumAsset = @($release.assets | Where-Object { $_.name -eq $checksumName })
if ($checksumAsset.Count -ne 1) {
    throw "缺少校验文件 $checksumName，拒绝安装未经校验的工具链。"
}

$work = Join-Path $installBase ".$folderName.installing"
$archive = Join-Path $work $asset.name
$staging = Join-Path $work "payload"
try {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
    New-Item -ItemType Directory -Path $work, $staging | Out-Null

    Write-Step "下载 $($asset.name)"
    Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $archive
    $checksumText = (Invoke-WebRequest -Uri $checksumAsset[0].browser_download_url -Headers $headers).Content
    $expected = ([regex]::Match($checksumText, '(?i)\b[0-9a-f]{64}\b')).Value.ToLowerInvariant()
    if (-not $expected) {
        throw "无法解析 SHA-256 校验文件。"
    }
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        throw "SHA-256 校验失败。期望 $expected，实际 $actual。"
    }

    Write-Step "解压工具链"
    Expand-Archive -LiteralPath $archive -DestinationPath $staging
    if (-not (Test-Path -LiteralPath (Join-Path $staging "Enter-PortableHaskell.ps1"))) {
        throw "工具链归档结构无效。"
    }
    Move-Item -LiteralPath $staging -Destination $destination

    $launcherContent = @"
@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0$folderName\Enter-PortableHaskell.ps1"
"@
    [IO.File]::WriteAllText($launcher, $launcherContent, [Text.UTF8Encoding]::new($false))
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Step "安装完成"
Write-Host "双击 $folderName.cmd 即可进入便携式 Haskell 环境。" -ForegroundColor Green

