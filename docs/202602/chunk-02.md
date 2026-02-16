# Chunk 02: Fix the Missing `@Test` Attribute and Test Issues

## Files changed

- `Tests/xcodeinstallTests/CLI/CLIStoreSecretsTest.swift` -- modified -- Added `@Test("Test Prompt For Credentials")` attribute to `testPromptForCredentials` function
- `Tests/xcodeinstallTests/CLI/CLIAuthTest.swift` -- modified -- Deleted dead `getMFATypeOK()` function (lines 153-198)
- `Tests/xcodeinstallTests/EnvironmentMock.swift` -- modified -- Removed unused `awsSDK` property from `MockedEnvironment`

## Changes made

1. Added `@Test("Test Prompt For Credentials")` attribute to the `testPromptForCredentials` function at `CLIStoreSecretsTest.swift:65`. Without this attribute, the Swift Testing framework did not discover or execute this test. The annotation style matches other tests in the same file (e.g., `@Test("Test Store Secrets")`).

2. Deleted the `private func getMFATypeOK() -> String` function from `CLIAuthTest.swift` (lines 153-198). This function was dead code -- never called anywhere in the file. A separate function with the same name exists in `AuthenticationMFATest.swift` and is actively used there; that one was left untouched.

3. Removed the `var awsSDK: SecretsStorageAWSSDKProtocol?` property from `MockedEnvironment` in `EnvironmentMock.swift` (line 85). This property was declared but never read or written anywhere -- it was not used in `toDeps()` or any test setup code. References to `awsSDK` elsewhere in tests (e.g., `secretsHandler.awsSDK`) refer to the production `SecretsStorageAWS.awsSDK` property, not this mock property.

## Build result

- `swift build`: PASS

## Test result

- `swift test`: PASS -- 116 tests in 14 suites

## Issues encountered

- None

## Deviations from plan

- None
