# 发布包来源与复现

这份文档回答两个问题：Release 中的 ZIP 是怎样产生的，以及第三方如何独立重跑同一份构建配方。

## 现行发布包的身份

- Release：[`toolchain`](https://github.com/one-click-run/portable-haskell/releases/tag/toolchain)
- 产物：`portable-haskell-ghc-9.10.3-windows-x86_64.zip`
- 构建仓库提交：`30b4ed2787c0718f99c536227100d93c5b3dd908`
- 成功的公开构建：[GitHub Actions run 41210151390](https://github.com/one-click-run/portable-haskell/actions/runs/41210151390)
- GHC：`9.10.3`
- cabal-install：`3.16.1.0`
- Haskell Language Server：`2.14.0.0`
- Stack：`3.11.1`
- GHCup Windows x86-64：SHA-256 `94da902a2853b1de1df509d04da900a05258480759efdb4f654e66956b6f30db`

以上数据不是事后手写的推测。它们同时记录在 ZIP 内的
`SOURCE-MANIFEST.json`，也以 `*.source-manifest.json` 独立附在 Release 上。
`*.spdx.json` 是 SPDX 2.3 SBOM，`*.sha256` 则校验整个 ZIP。

## 自动构建实际做了什么

1. GitHub Actions 检出上面的仓库提交，并下载 GHCup。
2. 工作流计算并记录当次使用的 GHCup SHA-256；本仓库的现行版本复现入口会要求该哈希与发布记录一致。
3. `scripts/build-toolchain.ps1` 让 GHCup 将四个固定版本隔离安装到 `.build/payload`，不会从维护者电脑复制已有工具。
4. 脚本只保留与 GHC `9.10.3` 匹配的 HLS server，然后用该 GHC 自带的 Clang 编译
   `native/Launch-Haskell-LSP.c`。这个原生入口解决 VS Code/Node 在 Windows 上不能把
   `.cmd` 直接作为 LSP 子进程启动的问题；ZIP 同时保留完全相同的 C 源码。
5. `SOURCE-MANIFEST.json` 记录原生入口的源码路径、编译器说明、源码 SHA-256 和 EXE SHA-256，
   构建还从本组织的 `vscode-extensions` Release 获取 manifest 固定的两个 VSIX，逐个校验
   SHA-256，然后加入示例、许可证和离线说明。运行时不再访问 Marketplace。
6. 未压缩目录先执行 `Enter-PortableHaskell.ps1 -Check`。
7. 目录被压缩为 ZIP，并生成 SHA-256、来源清单和 SPDX SBOM。
8. 工作流把网络代理指向不可用端口，从本地 ZIP 安装并编译、运行 Hello World，执行真实 LSP 握手，
   并通过 Node `spawn(..., {shell:false})` 模拟 VS Code 的启动方式。
9. 发布后，工作流再从公开 Release 运行一次相同的一行安装器、编译和 LSP 测试。

流程的可执行定义分别是
[`release-toolchain.yml`](.github/workflows/release-toolchain.yml) 和
[`build-toolchain.ps1`](scripts/build-toolchain.ps1)。文档与代码冲突时，以构建提交中的代码和产物内 manifest 为准。

## 在 Windows 上复现

要求：PowerShell 5.1 或 7、Git、7-Zip（可选；缺少时使用 PowerShell 自带压缩）和足够的磁盘空间。构建过程需要联网取得上游输入；生成的工具链运行时不需要联网。

```powershell
git clone https://github.com/one-click-run/portable-haskell.git
cd portable-haskell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\reproduce-release.ps1
```

复现脚本固定了现行发布使用的四个版本和 GHCup 哈希。它会拒绝哈希不符的 GHCup。如果原下载地址日后被替换或消失，可以把已保存且哈希匹配的文件传给脚本：

```powershell
.\scripts\reproduce-release.ps1 -Ghcup .\inputs\ghcup.exe
```

结果写入 `dist\`。完成后至少应检查：

```powershell
Get-Content .\dist\*.sha256
Get-Content .\dist\*.source-manifest.json
Get-Content .\dist\*.spdx.json
```

## 怎样审计已经发布的 ZIP

下载 ZIP 及相邻的 `.sha256`，然后执行：

```powershell
$zip = '.\portable-haskell-ghc-9.10.3-windows-x86_64.zip'
$expected = ((Get-Content "$zip.sha256" -Raw) -split '\s+')[0]
$actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw "SHA-256 mismatch" }
```

解压后，可将包内 `SOURCE-MANIFEST.json`、`SBOM.spdx.json` 与 Release 上的同名独立附件对照。构建所用脚本则由 manifest 的 `repositoryCommit` 精确定位。

## “可复现”在这里的准确含义

本项目承诺的是：构建配方公开、主要输入有明确版本、关键引导程序有哈希、构建过程可由第三方重跑，且结果能通过相同的功能和离线测试。

目前**不承诺 ZIP 逐字节相同**。ZIP 条目时间戳、GitHub runner 镜像、压缩器版本，以及 GHCup 的上游元数据都可能让重新生成的 ZIP 哈希不同。因此，Release 的 `.sha256` 用于验证“下载到的是否为我们发布的原包”，不能用来断言任意时刻的重建结果必须有同一个哈希。

为了抵抗上游链接失效，正式运行所需的完整 ZIP 及校验文件由 `one-click-run` 自己的 Release 托管；复现脚本依赖网络，只承担可审计和可重建职责，不是用户安装时的依赖。
