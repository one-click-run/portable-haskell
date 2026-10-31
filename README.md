# portable-haskell

在当前目录生成完整、便携的 Windows Haskell 开发环境。

所谓便携，是指 GHC、GHCi、Cabal、Haskell Language Server、Stack 及其配置和缓存都位于一个可移动目录中。它不会永久修改系统 `PATH`，可以复制、改名或直接删除。

发布包承诺的工具、标准库、语言服务器和示例在下载完成后均可离线使用。启动器不检查更新，也不会自动下载任何内容。

目前仅支持 Windows x86-64。

## 使用

在希望创建环境的目录中打开 PowerShell，执行：

```powershell
irm "https://raw.githubusercontent.com/one-click-run/portable-haskell/main/init.ps1" | iex
```

安装完成后，双击生成的 `OCR-portable-haskell-<版本>.cmd`。

完全离线的目标机器可以先从 Release 复制 ZIP 和相邻的 `.sha256` 文件，再运行：

```powershell
.\init.ps1 -Archive .\portable-haskell-ghc-9.10.3-windows-x86_64.zip
```

也可以无交互指定 Release 资产和安装名称：

```powershell
$env:ONE_CLICK_RUN_PORTABLE_HASKELL_SELECTED_ASSET = "portable-haskell-ghc-9.12.4-windows-x86_64.zip"
$env:ONE_CLICK_RUN_PORTABLE_HASKELL_INSTALL_NAME = "work"
irm "https://raw.githubusercontent.com/one-click-run/portable-haskell/main/init.ps1" | iex
```

## 特性

- 单脚本安装，普通用户不需要预装 GHCup、GHC 或 Cabal。
- 工具链 ZIP 和 SHA-256 校验文件托管在本组织的 GitHub Release。
- 安装器在解压前强制校验 SHA-256。
- 所有配置、包缓存和 Stack 数据均保存在便携目录的 `data` 中。
- 启动器根据自身位置动态寻找工具链，不写死绝对路径。
- 工具链由 GitHub Actions 从 GHCup 校验过的上游二进制构建，过程可审计、可复现。
- 每个发布包内含精确版本来源清单 `SOURCE-MANIFEST.json`、SPDX SBOM 和离线能力说明。

## 环境内容

- GHC / GHCi
- cabal-install
- Haskell Language Server
- Stack
- GHC 附带的 MinGW 工具链
- `examples/hello/Main.hs` 示例

为控制下载体积，发布包只保留与包内 GHC 精确匹配的 HLS 服务器，不携带其他 GHC 版本的 HLS 二进制文件。

进入环境后可以运行：

```console
ghc --version
ghci
ghc examples\hello\Main.hs -o hello.exe
```

`cabal update`、安装发布包之外的依赖，以及 Stack 获取未缓存 snapshot，属于用户明确发起的联网操作；它们不在离线承诺范围内，也绝不会由启动器自动执行。完整边界见 [OFFLINE-GUARANTEE.md](OFFLINE-GUARANTEE.md)。

## 维护者发布工具链

1. 打开仓库的 **Actions** 页面。
2. 选择 **Publish toolchain**。
3. 输入版本，或保留 `recommended`。
4. 运行工作流。

工作流使用明确版本通过 GHCup 隔离安装各工具，生成来源清单和 SBOM，执行本地归档离线安装与编译测试，再生成 ZIP 与 SHA-256 并上传到固定的 `toolchain` Release。上传后还会从公开 Release 重新运行一行安装器。构建和审计说明见 [BUILDING.md](BUILDING.md)。

## 安全与来源

在线模式下，安装器只从 `one-click-run/portable-haskell` Release 下载工具链，并要求相邻的 SHA-256 文件存在且匹配；离线模式接受本地 ZIP 和校验文件。工具链构建来源和第三方许可证见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。本项目承诺“可审计、可重建”，暂不宣称不同机器生成的 ZIP 能逐字节一致。

## 许可证

本仓库中的安装、启动和构建脚本采用 MIT 许可证。打包的第三方工具继续使用各自的上游许可证。
