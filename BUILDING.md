# Building and auditing a release

For the exact inputs, public build log, Chinese step-by-step explanation, audit
commands, and reproduction entry point for the current release, see
[`REPRODUCING.md`](REPRODUCING.md).

The published archive is assembled by `scripts/build-toolchain.ps1`. The
workflow passes exact versions for GHC, cabal-install, HLS, and Stack; floating
GHCup aliases are not used for official releases.

The build downloads GHCup, records its observed SHA-256, and asks GHCup to
install every component into an isolated payload. GHCup verifies the upstream
archives against its metadata. The script removes HLS servers that do not match
the bundled GHC. It then compiles `sources/Launch-Haskell-LSP.c` with the Clang
shipped inside that same GHC distribution. This small native launcher is needed
because VS Code's Node process cannot spawn a `.cmd` file as an LSP executable
on Windows. The C source is copied into the ZIP, and both source and executable
hashes are recorded in `SOURCE-MANIFEST.json` before the self-check and ZIP step.

Each archive contains:

- `SOURCE-MANIFEST.json`, with exact resolved component versions and build input;
- `SBOM.spdx.json`, an SPDX 2.3 software bill of materials;
- `THIRD_PARTY_NOTICES.md` and upstream license files;
- `OFFLINE-GUARANTEE.md`, defining what works without the network.
- `sources/Launch-Haskell-LSP.c`, the exact source used for the native VS Code
  launcher included as `Launch-Haskell-LSP.exe`.

The same manifest and SBOM are also separate Release assets. To rebuild with a
preserved GHCup executable, pass its local path and checksum:

```powershell
.\scripts\build-toolchain.ps1 `
  -GhcVersion 9.10.3 -CabalVersion 3.16.1.0 `
  -HlsVersion 2.14.0.0 -StackVersion 3.11.1 `
  -Ghcup .\inputs\ghcup.exe `
  -GhcupSha256 '<sha256>'
```

This is an auditable, rebuildable recipe. It does not yet claim that ZIP files
created on different machines are byte-for-byte reproducible, because archive
timestamps and upstream Windows binary layouts may differ.
