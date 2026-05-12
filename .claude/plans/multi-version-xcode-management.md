# Plan: Multi-Version Xcode Management (Issue #11)

## Context

Currently `xcodeinstall install` always moves extracted Xcode to `/Applications/Xcode.app`, overwriting any existing installation. This feature adds versioned installations (`/Applications/Xcode-{version}.app`) with a symlink (`/Applications/Xcode.app -> Xcode-{version}.app`) and a new `switch` subcommand to change the active version.

## Implementation Steps

### 1. Create `XcodeVersionExtractor` utility

**New file:** `Sources/xcodeinstall/Utilities/XcodeVersionExtractor.swift`

- Pure struct with a single `static func extractVersion(from filename: String) -> String?`
- Strip `.xip` extension, strip `Xcode` prefix (handles `Xcode_`, `Xcode `, `Xcode-`)
- Normalize spaces/underscores to hyphens for filesystem safety
- Handle betas: `"Xcode 14 beta 5.xip"` → `"14-beta-5"`
- Handle RCs: `"Xcode_14.0.1_Release_Candidate.xip"` → `"14.0.1-Release-Candidate"`
- Return `nil` if nothing meaningful remains

### 2. Extend `FileHandlerProtocol`

**Modify:** `Sources/xcodeinstall/Utilities/FileHandler.swift`

Add to protocol:
```swift
func createSymlink(at link: URL, pointingTo target: URL) throws
func listInstalledXcodes() throws -> [String]
```

Implementation:
- `createSymlink`: Remove existing item at `link`, create relative symbolic link (just the target filename, not absolute path)
- `listInstalledXcodes`: List `/Applications` entries matching `Xcode-*.app`, return sorted. Note: this is a simple prefix/suffix match — manually installed apps like `Xcode-beta.app` will appear. Acceptable for now; can tighten with version-plist validation later if needed.

### 3. Add new `InstallerError` cases

**Modify:** `Sources/xcodeinstall/API/Install.swift`

Add:
- `xcodeSelectFailed`
- `noInstalledXcodeVersions`
- `xcodeVersionNotInstalled(String)`

### 4. Modify `moveApp` and `installXcode`

**Modify:** `Sources/xcodeinstall/API/InstallXcode.swift`

- Change `moveApp(at:)` → `moveApp(at:version:)` with `version: String?` parameter
- When version is provided: destination is `/Applications/Xcode-{version}.app`
- When version is nil: destination is `/Applications/{filename}` (current behavior)
- **Important:** The returned `String` path drives the PKG install loop (`"\(installedFile)/Contents/resources/Packages/\(pkg)"`). The versioned rename is safe because the return value reflects the new path, but all callers and tests that assert on `moveApp`'s return value must be updated to expect the versioned path.
- Add `activateXcode(version:)` method that:
  1. Creates symlink `/Applications/Xcode.app` → `Xcode-{version}.app`
  2. Runs `sudo xcode-select -s /Applications/Xcode-{version}.app`
- Update `installXcode(at:version:)` to accept a `version: String` parameter (already resolved by caller)
  1. Pass version to `moveApp`
  2. After PKG installs, call `activateXcode`
  3. Add one more step to progress bar (symlink+xcode-select)
- No prompting or extraction logic here — `ShellInstaller` just receives the version from the caller

### 5. Add `--version` flag to `CLIInstall.swift` and thread through

**Modify:** `Sources/xcodeinstall/CLI-driver/CLIInstall.swift`

- Add `@Option(name: .shortAndLong, help: "Override the Xcode version identifier (e.g., '16.2'). Auto-detected from filename if omitted.") var version: String?`
- Pass `version` to `xci.install(file: name, version: version)`

**Modify:** `Sources/xcodeinstall/xcodeInstall/InstallCommand.swift`

- Update `install(file:)` → `install(file:version:)` with `version: String?` parameter
- If `version` is provided (from CLI flag), use it directly
- Otherwise, extract from filename via `XcodeVersionExtractor`
- If extraction also returns nil, prompt user: "Could not determine Xcode version. Please enter version (e.g., 14.0.1):"
- Pass resolved version to `ShellInstaller.install(file:version:)`
- Update `ShellInstaller.install(file:)` signature to accept `version: String`

### 6. Create `CLISwitch.swift` subcommand

**New file:** `Sources/xcodeinstall/CLI-driver/CLISwitch.swift`

- `struct SwitchVersion: AsyncParsableCommand` with `commandName: "switch"` (avoids Swift keyword conflict)
- `@Argument var version: String?` — optional positional argument
- Follows same pattern as other subcommands: creates `XCodeInstaller`, calls `xci.switchVersion(to:)`
- Command abstract/help text must note that `sudo` is required (for `xcode-select -s`), so users expect a password prompt when running `xcodeinstall switch` standalone

### 7. Create `SwitchCommand.swift` business logic

**New file:** `Sources/xcodeinstall/xcodeInstall/SwitchCommand.swift`

`XCodeInstall.switchVersion(to version: String?)`:
- Call `fileHandler.listInstalledXcodes()` to get installed versions
- If empty, display warning and throw
- If `version` is nil: display list and prompt user interactively to select one
- Validate selected version exists as `/Applications/Xcode-{version}.app`
- Create `ShellInstaller` and call `activateXcode(version:)`
- Display success message

### 8. Register subcommand

**Modify:** `Sources/xcodeinstall/CLI-driver/CLIMain.swift`

Add `SwitchVersion.self` to the `subcommands` array.

### 9. Update mock and tests

**Modify:** `Tests/xcodeinstallTests/` mock files — add `createSymlink`/`listInstalledXcodes` to `MockedFileHandler`

**New file:** `Tests/xcodeinstallTests/Utilities/XcodeVersionExtractorTests.swift` — test version parsing

**Modify:** `Tests/xcodeinstallTests/API/InstallTest.swift` — update `testMoveApp` for new signature, add test for `activateXcode`

**New file:** `Tests/xcodeinstallTests/API/ActivateXcodeTest.swift` — test `activateXcode` including:
- Happy path: symlink doesn't exist yet, creates it
- Symlink already exists (pointing to older version), replaces it
- `/Applications/Xcode.app` is a real directory (not a symlink) — verify we stop and prompt user rather than overwriting

**New file:** `Tests/xcodeinstallTests/CLI/CLISwitchTest.swift` — test switch subcommand

## Key Files

| File | Action |
|------|--------|
| `Sources/xcodeinstall/Utilities/XcodeVersionExtractor.swift` | Create |
| `Sources/xcodeinstall/Utilities/FileHandler.swift` | Modify |
| `Sources/xcodeinstall/API/Install.swift` | Modify |
| `Sources/xcodeinstall/API/InstallXcode.swift` | Modify |
| `Sources/xcodeinstall/xcodeInstall/InstallCommand.swift` | Modify |
| `Sources/xcodeinstall/CLI-driver/CLIInstall.swift` | Modify (pass version) |
| `Sources/xcodeinstall/CLI-driver/CLISwitch.swift` | Create |
| `Sources/xcodeinstall/CLI-driver/CLIMain.swift` | Modify |
| `Sources/xcodeinstall/xcodeInstall/SwitchCommand.swift` | Create |
| Test files (mock, extractor tests, switch tests) | Create/Modify |

## Design Decisions

- **Existing non-symlink Xcode.app** — Before creating the symlink, check if `/Applications/Xcode.app` exists and is NOT already a symlink. If it's a real app bundle, stop and ask the user what to do (display a prompt: "An existing Xcode.app was found that is not a symlink. Would you like to rename it to Xcode-{detected-version}.app, or abort?"). Detect version via `Xcode.app/Contents/version.plist` (key `CFBundleShortVersionString`). Never overwrite silently.
- **Relative symlinks** — `Xcode.app -> Xcode-14.0.1.app` (not absolute paths), matching the issue example
- **Interactive prompt on version extraction failure** — user provides version string
- **Interactive prompt for `switch`** — when no argument given, list versions and prompt for selection
- **xcode-select** — always run after symlink creation to keep system state consistent
- **Version threading** — extract version in `InstallCommand` (has access to `readLine` for prompting), pass it down to `ShellInstaller`

## Verification

1. `swift build` compiles without errors
2. `swift test` passes all existing + new tests
3. Manual test: `xcodeinstall install --name Xcode_16.2.xip` → installs as `/Applications/Xcode-16.2.app` with symlink
4. Manual test: `xcodeinstall switch` → lists installed versions, prompts selection, updates symlink + xcode-select
5. Manual test: `xcodeinstall switch 16.2` → directly switches without prompt
