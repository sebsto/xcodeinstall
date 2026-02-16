# Chunk 07: Consolidate Install Files

## Files changed

- `Sources/xcodeinstall/API/Install.swift` -- modified -- Added `Subprocess` import, `SupportedInstallation` enum (with simplified `supported()` logic), and `installPkg()` method
- `Sources/xcodeinstall/API/InstallXcode.swift` -- modified -- Added `installCommandLineTools()`, `mountDMG()`, and `unmountDMG()` methods from InstallCLTools.swift
- `Sources/xcodeinstall/API/InstallPkg.swift` -- deleted -- Content merged into Install.swift
- `Sources/xcodeinstall/API/InstallSupportedFiles.swift` -- deleted -- Content merged into Install.swift
- `Sources/xcodeinstall/API/InstallCLTools.swift` -- deleted -- Content merged into InstallXcode.swift

## Changes made

1. Merged `InstallPkg.swift` into `Install.swift`: Moved the `installPkg(atURL:)` method into the `ShellInstaller` class body in `Install.swift`. Added the required `import Subprocess`. Deleted `InstallPkg.swift`.

2. Merged `InstallSupportedFiles.swift` into `Install.swift`: Moved the `SupportedInstallation` enum into `Install.swift`, placed between `InstallerError` and `ShellInstaller`. Simplified the `supported()` method from the over-engineered generic array-based approach (with parallel arrays, `enumerated()`, `compactMap`, and `filter`) to direct if/else logic. Deleted `InstallSupportedFiles.swift`.

3. Merged `InstallCLTools.swift` into `InstallXcode.swift`: Moved `installCommandLineTools(atPath:)`, `mountDMG(atURL:)`, and `unmountDMG(volume:)` into the `ShellInstaller` extension in `InstallXcode.swift`. Deleted `InstallCLTools.swift`.

4. Kept `InstallDownloadListExtension.swift` separate as planned, since it extends `DownloadList` rather than `ShellInstaller`.

5. Result: 3 install files instead of 6: `Install.swift`, `InstallXcode.swift`, `InstallDownloadListExtension.swift`.

## Build result

- `swift build`: PASS

## Test result

- `swift test`: PASS -- 116 tests in 14 suites

## Issues encountered

- None

## Deviations from plan

- None
