# Implementation Plan: Persistent Config for `-s` and `-p` Options

## Context

Currently, users who work with AWS Secrets Manager must provide `-s` (AWS region) and `-p` (AWS profile) options on every command. This is repetitive and error-prone. This feature adds automatic persistence of these options to `~/.xcodeinstall/config.json`, so users only need to specify them once.

**User Experience:**
```bash
# First time - explicitly provide options
xcodeinstall authenticate -s us-west-2 -p myprofile

# Later - options automatically loaded
xcodeinstall list
# Output: "Using saved settings: -s us-west-2 -p myprofile"

# Override when needed
xcodeinstall list -s us-east-1  # Uses us-east-1, keeps saved -p myprofile
```

## Implementation Approach

### Design Principles
1. **Automatic & silent**: Save happens automatically when `-s` or `-p` are provided
2. **CLI precedence**: Command-line arguments always override saved values
3. **Transparent**: Info message displays when using saved settings
4. **Fail-safe**: Corrupted or missing config files don't break commands
5. **Minimal changes**: Leverage existing patterns (JSON + Codable, FileHandler conventions)

### Architecture
- **Config file**: `~/.xcodeinstall/config.json` (matches existing directory structure)
- **Format**: JSON with Codable protocol (matches `DownloadList` pattern)
- **Integration point**: `MainCommand.XCodeInstaller()` factory method (CLIMain.swift:74-128)
- **Loading**: Before dependency creation (line ~91)
- **Saving**: After determining effective values (before line 99)
- **Display**: After loading, show info message for non-overridden values

## Critical Files & Changes

### 1. NEW FILE: `Sources/xcodeinstall/Utilities/ConfigHandler.swift`

Create config persistence handler following existing patterns.

**Structure:**
```swift
// Protocol for testability
protocol ConfigHandlerProtocol: Sendable {
    func saveConfig(_ config: PersistentConfig) throws
    func loadConfig() -> PersistentConfig?
    nonisolated func configPath() -> URL
}

// Config data model
struct PersistentConfig: Codable, Sendable {
    var secretManagerRegion: String?
    var profileName: String?
}

// Implementation
struct ConfigHandler: ConfigHandlerProtocol {
    private let log: Logger
    private let baseDirectory: URL

    // saveConfig(): Creates directory if needed, encodes to JSON
    // loadConfig(): Returns nil on missing/corrupted file (graceful degradation)
    // configPath(): Returns baseDirectory.appendingPathComponent("config.json")
}
```

**Key behaviors:**
- `saveConfig()` creates `~/.xcodeinstall` directory if it doesn't exist
- `loadConfig()` returns `nil` (not throws) for missing/corrupted files
- Uses `JSONEncoder`/`JSONDecoder` matching FileHandler patterns
- Logs debug messages for troubleshooting
- Uses `await` in CLIMain due to Swift concurrency requirements

### 2. MODIFY: `Sources/xcodeinstall/CLI-driver/CLIMain.swift`

Update `XCodeInstaller()` factory method (lines 74-128) to integrate config loading/saving.

**Changes:**
```swift
public static func XCodeInstaller(
    with deps: AppDependencies? = nil,
    for region: String? = nil,
    profileName: String? = nil,
    verbose: Bool
) async throws -> XCodeInstall {

    // Lines 81-90: Existing logger setup and deps check (unchanged)

    // NEW: Load saved config
    let baseDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".xcodeinstall")
    let configHandler = await ConfigHandler(log: logger, baseDirectory: baseDirectory)
    let savedConfig = await configHandler.loadConfig()

    // NEW: Merge CLI args with saved config (CLI takes precedence)
    let effectiveRegion = region ?? savedConfig?.secretManagerRegion
    let effectiveProfile = profileName ?? savedConfig?.profileName

    // NEW: Display info message for loaded (non-overridden) settings
    let display = NooraDisplay()
    if effectiveRegion != nil || effectiveProfile != nil {
        var savedParts: [String] = []
        if let r = effectiveRegion, region == nil {
            savedParts.append("-s \(r)")
        }
        if let p = effectiveProfile, profileName == nil {
            savedParts.append("-p \(p)")
        }
        if !savedParts.isEmpty {
            await display.display(
                "Using saved settings: \(savedParts.joined(separator: " "))",
                style: .info
            )
        }
    }

    // NEW: Save config if CLI args provided (merge with existing)
    if region != nil || profileName != nil {
        let newConfig = PersistentConfig(
            secretManagerRegion: region ?? savedConfig?.secretManagerRegion,
            profileName: profileName ?? savedConfig?.profileName
        )
        try? await configHandler.saveConfig(newConfig)
        logger.debug("Saved config")
    }

    let fileHandler = await FileHandler(log: logger)
    let urlSession = URLSession.shared

    var secrets: SecretsHandlerProtocol
    var authenticator: AppleAuthenticatorProtocol
    var downloader: AppleDownloaderProtocol

    // CHANGE: Use effectiveRegion instead of region
    if let effectiveRegion {
        let awsSecrets = try await SecretsStorageAWS(
            region: effectiveRegion,
            profileName: effectiveProfile,  // CHANGE: Use effectiveProfile
            log: logger
        )
        secrets = awsSecrets
    } else {
        secrets = await SecretsStorageFile(log: logger)
    }

    // Lines 106-127: Existing authenticator/downloader/deps setup
    // CHANGE: Reuse display instance instead of creating new NooraDisplay()
    let deps = await AppDependencies(
        fileHandler: fileHandler,
        display: display,  // Reuse instance
        readLine: NooraReadLine(),
        progressBar: CLIProgressBar(),
        secrets: secrets,
        authenticator: authenticator,
        downloader: downloader,
        urlSessionData: urlSession,
        shell: SystemShell(),
        log: logger
    )

    return await XCodeInstall(log: logger, deps: deps)
}
```

**Logic flow:**
1. Load saved config (if exists)
2. Compute effective values: CLI args override saved values
3. Display info message for loaded (non-overridden) values only
4. Save new config if CLI args provided (merge with existing saved values)
5. Use effective values for dependency creation

**Swift Concurrency Notes:**
- ConfigHandler methods are called with `await` due to Swift 6 actor isolation requirements
- The `display` instance is created early and reused to avoid creating multiple NooraDisplay instances
- ConfigHandler's `loadConfig()` and `saveConfig()` methods are not marked as `nonisolated` because they use `Codable`, which requires actor isolation

### 3. NEW FILE: `Tests/xcodeinstallTests/Utilities/ConfigHandlerTests.swift`

Unit tests for ConfigHandler covering:
- Save and load cycle
- Load non-existent file (returns nil)
- Load corrupted JSON (returns nil)
- Partial config (only region, no profile)
- Overwrite existing config
- Config path validation

**Test pattern:**
```swift
import Testing
import Foundation
@testable import xcodeinstall

@Suite("ConfigHandler Tests")
final class ConfigHandlerTests {
    @Test("Save and load config")
    func testSaveAndLoad() throws {
        // Use temporary directory for tests
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        // ... test implementation
        // Cleanup temp directory
    }

    // Additional tests: testLoadNonExistent, testLoadCorrupted,
    // testPartialConfig, testOverwrite
}
```

## Edge Cases & Error Handling

### 1. Corrupted config file
- `loadConfig()` catches decode errors, logs warning, returns nil
- CLI proceeds as if no config exists
- User can fix by deleting file or providing new values

### 2. Missing directory
- `saveConfig()` creates `~/.xcodeinstall` directory if needed
- Follows FileHandler.baseFilePath() pattern (lines 52-64)

### 3. Write permission errors
- Save wrapped in `try?` - failure is non-fatal
- Command succeeds, but settings aren't persisted
- Acceptable: rare case, user retains manual control

### 4. Concurrent access
- Last write wins (no file locking needed)
- Low risk: users unlikely to run multiple auth commands simultaneously

### 5. Empty string vs nil
- ArgumentParser treats `""` as empty string (not nil)
- Empty strings would be saved to config
- Consider adding validation to CloudOptions if this becomes an issue

### 6. Partial configs
- Both fields are optional, supporting partial configs
- Providing only `-s` preserves existing `-p` (and vice versa)
- Config merge: `region ?? savedConfig?.secretManagerRegion`

## Verification Steps

### Unit Tests
```bash
# Run ConfigHandler unit tests
swift test --filter ConfigHandlerTests
```

### Manual Integration Tests

1. **Initial save:**
   ```bash
   rm ~/.xcodeinstall/config.json  # Start fresh
   xcodeinstall authenticate -s us-west-2 -p myprofile
   cat ~/.xcodeinstall/config.json
   # Should show: {"secretManagerRegion":"us-west-2","profileName":"myprofile"}
   ```

2. **Auto-load with info message:**
   ```bash
   xcodeinstall list
   # Should display: "Using saved settings: -s us-west-2 -p myprofile"
   ```

3. **CLI override:**
   ```bash
   xcodeinstall list -s us-east-1
   # Should display: "Using saved settings: -p myprofile"
   # Should use us-east-1 (overridden), myprofile (loaded)
   ```

4. **Partial update:**
   ```bash
   xcodeinstall authenticate -p newprofile
   cat ~/.xcodeinstall/config.json
   # Should show: {"secretManagerRegion":"us-west-2","profileName":"newprofile"}
   # Region preserved, profile updated
   ```

5. **No config fallback:**
   ```bash
   rm ~/.xcodeinstall/config.json
   xcodeinstall list
   # Should work normally, no info message
   ```

6. **Corrupted config recovery:**
   ```bash
   echo "invalid json" > ~/.xcodeinstall/config.json
   xcodeinstall list --verbose
   # Should display warning in logs, proceed without config
   ```

7. **Existing commands still work:**
   ```bash
   # Verify no regression for commands without config
   xcodeinstall authenticate  # Without -s/-p
   xcodeinstall storesecrets -s us-west-2 -p prod  # Mandatory args
   ```

### Regression Testing
- Commands without config file work as before
- StoreSecrets command (mandatory `-s`/`-p`) still enforces requirements
- Verbose logging shows debug messages

## Implementation Status

✅ **Completed:**
1. Created `ConfigHandler.swift` with protocol and implementation (74 lines)
2. Added 7 unit tests for `ConfigHandler` - all passing
3. Modified `CLIMain.swift` XCodeInstaller() factory method with config integration
4. All 165 tests pass (including 7 new ConfigHandler tests)
5. Build successful with no compiler warnings or errors

**Implementation Details:**
- Used `await` for ConfigHandler method calls to satisfy Swift 6 concurrency requirements
- ConfigHandler methods use actor isolation (not `nonisolated`) because they work with `Codable` types
- Display instance is created early and reused throughout the function
- Config saving uses `try?` for non-fatal error handling
- Config loading returns `nil` on errors for graceful degradation

## Future Enhancements (Out of Scope)

- Explicit config management commands (`config show`, `config clear`)
- Multiple named profiles (`--save-as dev`, `--use-profile dev`)
- Environment variable fallback (`XCODEINSTALL_REGION`)
- Config file validation (check AWS region validity)
- Config encryption (though values are non-sensitive)

## Summary

This implementation provides seamless AWS Secrets Manager integration by:

✅ **Zero-friction UX** - Automatic save when options provided
✅ **User control** - CLI args always override saved settings
✅ **Transparency** - Info messages show when saved settings are used
✅ **Robust** - Graceful handling of missing/corrupted config files
✅ **Non-breaking** - Existing users unaffected, zero migration needed
✅ **Testable** - Protocol-based design supports unit testing
✅ **Extensible** - Structure supports future config enhancements

The implementation follows existing codebase patterns (JSON + Codable, FileHandler directory conventions, protocol-based design) and requires minimal changes to production code.
