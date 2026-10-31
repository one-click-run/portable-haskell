# Third-party notices

Release archives produced by this repository redistribute the following open-source tools:

- [GHC](https://www.haskell.org/ghc/) — BSD-3-Clause
- [cabal-install](https://www.haskell.org/cabal/) — BSD-3-Clause
- [Haskell Language Server](https://haskell-language-server.readthedocs.io/) — Apache-2.0
- [Stack](https://docs.haskellstack.org/) — BSD-3-Clause
- [Haskell for Visual Studio Code](https://github.com/haskell/vscode-haskell) — MIT
- [Haskell Syntax Highlighting](https://github.com/haskell/vscode-haskell-syntax-highlighting) — BSD-3-Clause

The build workflow obtains compiler tools through GHCup and pinned VSIX inputs
from the organization-hosted `vscode-extensions` Release. Exact VSIX hashes and
upstream projects are recorded in `SOURCE-MANIFEST.json`. This project does not
claim ownership of those tools.

