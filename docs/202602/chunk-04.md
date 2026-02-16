# Chunk 04: Fix Direct `FileHandler` Construction (DI Bypass)

## Files changed

- `Sources/xcodeinstall/xcodeInstall/InstallCommand.swift` — modified — replaced direct `FileHandler(log:)` construction with `self.deps.fileHandler`

## Changes made

1. In `InstallCommand.swift` line 34, replaced `FileHandler(log: self.log).downloadDirectory()` with `self.deps.fileHandler.downloadDirectory()` so that when a file name is provided directly to the install command, the download directory is resolved through the injected dependency rather than a freshly constructed `FileHandler`.

2. In `InstallCommand.swift` line 102 (inside `promptForFile()`), replaced `FileHandler(log: self.log).downloadDirectory()` with `self.deps.fileHandler.downloadDirectory()` so that user-selected files are also resolved through the injected dependency.

3. Verified that `DownloadCommand.swift` does not have the same issue — it already uses `self.deps.fileHandler` throughout.

4. Grepped for all `FileHandler(log:` occurrences across `Sources/xcodeinstall/`. The remaining two sites (`SecretsStorageFile.swift` and `CLIMain.swift`) are outside the scope of this chunk: `CLIMain.swift` is the composition root where the `FileHandler` is constructed for injection, and `SecretsStorageFile.swift` is in the secrets layer which has its own construction context.

## Build result

- `swift build`: PASS

## Test result

- `swift test`: PASS — 116 tests in 14 suites

## Issues encountered

- None

## Deviations from plan

- None
