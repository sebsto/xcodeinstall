# Chunk 05: Replace `exit(0)` Calls with Proper Error Flow

## Files changed

- `Sources/xcodeinstall/CLI-driver/CLIMain.swift` — modified — added `userCancelled` case to `CLIError` enum
- `Sources/xcodeinstall/xcodeInstall/InstallCommand.swift` — modified — replaced `exit(0)` with `throw CLIError.userCancelled` and added catch clause
- `Sources/xcodeinstall/xcodeInstall/DownloadCommand.swift` — modified — replaced `exit(0)` with `throw CLIError.userCancelled` and added catch clause

## Changes made

1. Added `case userCancelled` to the `CLIError` enum in `CLIMain.swift` (line 19).
2. In `InstallCommand.swift:promptForFile()`, replaced `exit(0)` with `throw CLIError.userCancelled` on the empty-input cancellation path (line 99).
3. In `InstallCommand.swift:install()`, added a `catch CLIError.userCancelled { return }` clause before the `CLIError.invalidInput` catch so that user cancellation exits silently without an error message (line 41-42).
4. In `DownloadCommand.swift:askUser()`, replaced `exit(0)` with `throw CLIError.userCancelled` on the empty-input cancellation path (line 148).
5. In `DownloadCommand.swift:download()`, added a `catch CLIError.userCancelled { return }` clause before the `CLIError.invalidInput` catch so that user cancellation exits silently without an error message (line 88-89).

## Build result

- `swift build`: PASS

## Test result

- `swift test`: PASS — 116 tests in 14 suites

## Issues encountered

- None

## Deviations from plan

- None. The plan suggested checking whether the CLI-driver level needed changes. After reading `CLIInstall.swift` and `CLIDownload.swift`, no changes were needed there because both `install()` and `download()` already have their own `do/catch` blocks that handle the error internally. The `userCancelled` error is caught and silently returns before it can propagate to the CLI-driver layer.
