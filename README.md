# portable-haskell

在当前目录生成完整、便携的 Windows Haskell 开发环境。

所谓便携，是指 GHC、GHCi、Cabal、Haskell Language Server、Stack 及其配置和缓存都位于一个可移动目录中。它不会永久修改系统 `PATH`，可以复制、改名或直接删除。

目前仅支持 Windows x86-64。

## 使用

在希望创建环境的目录中打开 PowerShell，执行：

```powershell
irm "https://raw.githubusercontent.com/one-click-run/portable-haskell/main/init.ps1" | iex
```

安装完成后，双击生成的 `OCR-portable-haskell-<版本>.cmd`。

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

## 环境内容

- GHC / GHCi
- cabal-install
- Haskell Language Server
- Stack
- GHC 附带的 MinGW 工具链
- `examples/hello/Main.hs` 示例

进入环境后可以运行：

```console
ghc --version
ghci
cabal update
ghc examples\hello\Main.hs -o hello.exe
```

## 维护者发布工具链

1. 打开仓库的 **Actions** 页面。
2. 选择 **Publish toolchain**。
3. 输入版本，或保留 `recommended`。
4. 运行工作流。

工作流会通过 GHCup 隔离安装各工具、执行烟雾测试、生成 ZIP 与 SHA-256，并上传到固定的 `toolchain` Release。安装器会自动列出该 Release 中所有兼容资产。

## 安全与来源

安装器只从 `one-click-run/portable-haskell` Release 下载工具链，并要求相邻的 SHA-256 文件存在且匹配。工具链构建来源和第三方许可证见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 许可证

本仓库中的安装、启动和构建脚本采用 MIT 许可证。打包的第三方工具继续使用各自的上游许可证。
