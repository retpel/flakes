# lite-xl

[Lite XL](https://lite-xl.com/) from upstream's "addons" release, as a real
`Lite XL.app` (`$out/Applications`) plus a `bin/lite-xl` launcher. Compared with
nixpkgs' `lite-xl` (base release, no bundle) it adds ~100 language plugins
(Nix, Go, Rust, TOML, YAML, shell, ...), ~50 colour schemes and the `widget`
library. Core and plugins come from one release, so they always match.

Apple Silicon only (the upstream arm64 dmg). The bundle is ad-hoc signed
upstream and left untouched (`dontFixup`). Home Manager and nix-darwin link
`Applications/*.app` into the usual app folders.

Your own config (`init.lua`, extra plugins, colours) still goes in
`~/.config/lite-xl/`. `update.sh` bumps to the latest upstream release.
