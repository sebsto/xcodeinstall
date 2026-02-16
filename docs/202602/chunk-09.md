# Chunk 09: Make `SecretsStorageFile` Error Type Generic

## Files changed

- `Sources/xcodeinstall/Secrets/SecretsHandler.swift` -- modified -- Added new `SecretsStorageError` enum with `invalidOperation` case
- `Sources/xcodeinstall/Secrets/SecretsStorageFile.swift` -- modified -- Changed throws from `SecretsStorageAWSError.invalidOperation` to `SecretsStorageError.invalidOperation`
- `Sources/xcodeinstall/Secrets/SecretsStorageAWS.swift` -- modified -- Removed `invalidOperation` case from `SecretsStorageAWSError` enum
- `Sources/xcodeinstall/xcodeInstall/AuthenticateCommand.swift` -- modified -- Updated catch clause from `SecretsStorageAWSError.invalidOperation` to `SecretsStorageError.invalidOperation`

## Changes made

1. Created a new generic `SecretsStorageError` enum in `SecretsHandler.swift` with a single `invalidOperation` case and a `LocalizedError` conformance providing the same error description as the removed case. This enum is placed in `SecretsHandler.swift` as a shared location accessible to all secrets storage backends.

2. Updated `SecretsStorageFile.swift` lines 146 and 149 to throw `SecretsStorageError.invalidOperation` instead of `SecretsStorageAWSError.invalidOperation` for the `retrieveAppleCredentials()` and `storeAppleCredentials()` methods.

3. Removed the `invalidOperation` case from `SecretsStorageAWSError` in `SecretsStorageAWS.swift`, along with its `errorDescription` switch case. The remaining AWS-specific cases (`invalidRegion`, `secretDoesNotExist`, `noCredentialProvider`) are unaffected.

4. Updated the catch clause in `AuthenticateCommand.swift` line 120 to catch `SecretsStorageError.invalidOperation` instead of `SecretsStorageAWSError.invalidOperation`.

## Build result

- `swift build`: PASS

## Test result

- `swift test`: PASS -- 116 tests in 14 suites

## Issues encountered

- None

## Deviations from plan

- None
