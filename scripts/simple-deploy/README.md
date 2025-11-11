# Simple Deployment

This simplified deployment process replaces the complex multi-script approach with a single script.

## Usage

```bash
./scripts/simple-deploy/release.sh 0.15.0
```

## What it does

1. **Updates version** in `Sources/xcodeinstall/Version.swift`
2. **Builds fat binary** (arm64 + x86_64) using Swift Package Manager
3. **Creates GitHub release** with the binary attached
4. **Generates Homebrew formula** with correct URLs and checksums
5. **Updates homebrew-macos tap** (if directory exists)

## Requirements

- `gh` CLI tool installed and authenticated
- `../homebrew-macos` directory for the tap (optional)
- Swift toolchain with cross-compilation support

## Differences from old approach

- **Single script** instead of 6+ separate scripts
- **No bottle building** - uses source compilation in Homebrew
- **Simpler checksums** - same binary hash for all platforms
- **Direct binary upload** to GitHub releases
- **Automatic formula generation** with embedded build instructions

This approach is much simpler but still provides the same end result: a working Homebrew formula that can install xcodeinstall on macOS.