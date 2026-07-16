# Vendored xterm.js

This directory contains the full local copies of the `xterm.js` browser package
used by `test-v86.html`, plus the upstream package tarballs used to populate it.

## Offline packaging

- Runtime assets are loaded only from local paths under `vendor/xterm/`.
- Upstream `LICENSE`, `README.md`, `package.json`, built assets, and source files
  are all present locally under `vendor/xterm/packages/`.
- Original npm tarballs are preserved under `vendor/xterm/upstream/` so the
  exact shipped packages remain available in the offline bundle.

## Current packages

- `@xterm/xterm@6.0.0`
- `@xterm/addon-fit@0.11.0`

Both packages are MIT licensed. See the package-local `LICENSE` files.

## Refreshing the vendor copy

1. Download the replacement npm tarballs on a machine with registry access.
2. Run:

```bash
./scripts/vendor-xterm.sh /path/to/xterm-xterm-<version>.tgz /path/to/xterm-addon-fit-<version>.tgz
```

3. Update `vendor/xterm/manifest.json` to match the new versions.
4. Sanity-check `test-v86.html` against the same stable runtime paths.
