# Offline runtime guarantee

After the release ZIP and its adjacent SHA-256 file have been obtained, the
bundled GHC, GHCi, Cabal executable, Haskell Language Server, Stack executable,
MinGW toolchain, standard libraries, and included examples can be started,
compiled, and run without a network connection.

The launcher never downloads files, checks for updates, or contacts a package
index. It only configures paths inside its own directory.

This guarantee does not include packages that are absent from the archive.
Commands such as `cabal update`, `cabal install`, and Stack operations that need
an uncached snapshot or package are explicit requests for external content and
may use the network. The project never performs those operations automatically.

For an air-gapped installation, download the ZIP and `.sha256` file on another
machine, copy them together, and run:

```powershell
.\init.ps1 -Archive .\portable-haskell-ghc-<version>-windows-x86_64.zip
```

The installer verifies SHA-256 before extracting the archive.
