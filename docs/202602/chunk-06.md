# Chunk 06: Add Bounds Checking on User Selection

## Files changed

- `Sources/xcodeinstall/xcodeInstall/InstallCommand.swift` — modified — added bounds check before indexing `installableFiles[num]`
- `Sources/xcodeinstall/xcodeInstall/DownloadCommand.swift` — modified — added bounds checks before indexing `parsedList[num]` and `parsedList[num].files[fileNum]`

## Changes made

1. In `InstallCommand.swift`, added a guard statement in `promptForFile()` after parsing the user's integer input (`num`) and before accessing `installableFiles[num]`. The guard checks `num >= 0, num < installableFiles.count` and throws `CLIError.invalidInput` if out of bounds.

2. In `DownloadCommand.swift`, added a guard statement in `askFile()` after the first `askUser()` call and before accessing `parsedList[num]`. The guard checks `num >= 0, num < parsedList.count` and throws `CLIError.invalidInput` if out of bounds.

3. In `DownloadCommand.swift`, added a guard statement in `askFile()` after the second `askUser()` call (for file selection within a multi-file download) and before accessing `parsedList[num].files[fileNum]`. The guard checks `fileNum >= 0, fileNum < parsedList[num].files.count` and throws `CLIError.invalidInput` if out of bounds.

## Build result

- `swift build`: PASS

## Test result

- `swift test`: PASS — 116 tests in 14 suites

## Issues encountered

- None

## Deviations from plan

- None
