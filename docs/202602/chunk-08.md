# Chunk 08: Unify `promptForCredentials` Implementations

## Files changed

- `Sources/xcodeinstall/xcodeInstall/StoreSecretsCommand.swift` -- modified -- Changed `promptForCredentials()` return type from `[String]` to `AppleCredentialsSecret` and updated `storeSecrets()` call site
- `Tests/xcodeinstallTests/CLI/CLIStoreSecretsTest.swift` -- modified -- Updated test assertions to use `.username`/`.password` instead of `[0]`/`[1]`

## Changes made

1. Changed the return type of `XCodeInstall.promptForCredentials()` in `StoreSecretsCommand.swift` from `[String]` to `AppleCredentialsSecret`. The method now returns `AppleCredentialsSecret(username: username, password: password)` directly instead of `[username, password]`.

2. Simplified the `storeSecrets()` method in the same file: removed the intermediate `input` variable and the manual `AppleCredentialsSecret(username: input[0], password: input[1])` construction. The `promptForCredentials()` return value is now used directly as `credentials`.

3. Updated the test `testPromptForCredentials` in `CLIStoreSecretsTest.swift` to assert against the new `AppleCredentialsSecret` return type, using `result.username == "username"` and `result.password == "password"` instead of the previous array-index-based assertions (`result.count == 2`, `result[0]`, `result[1]`).

## Build result

- `swift build`: PASS

## Test result

- `swift test`: PASS -- 116 tests in 14 suites

## Issues encountered

- None

## Deviations from plan

- Chose Option B (change return type, keep separate implementations) rather than Option A (have `StoreSecretsCommand` call `CLIAuthenticationDelegate`'s version). The two methods have meaningfully different display messages: `StoreSecretsCommand` shows an AWS-specific message while `CLIAuthenticationDelegate` shows different messages based on a `storingToAWS` flag. They also live on different types (`XCodeInstall` vs `CLIAuthenticationDelegate`), making delegation awkward without restructuring. Option B achieves the main goal of eliminating the type-unsafe `[String]` return type with minimal changes.
