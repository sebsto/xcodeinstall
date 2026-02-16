# Test Coverage Improvement Plan

## Current State

- **Overall line coverage:** 60.77% (2,328 / 3,831 lines)
- **Target:** 65-70% (need 162 to 354 more covered lines)
- **Test framework:** Swift Testing (`@Test`, `@Suite`, `#expect`)
- **Test count:** 123 tests in 15 suites (post chunk-13)

## Coverage by File (Sorted by Uncovered Lines)

| File | Covered | Total | Pct | Uncovered |
|------|---------|-------|-----|-----------|
| `API/InstallXcode.swift` | 25 | 216 | 11.6% | 191 |
| `Secrets/SecretsStorageAWS+Soto.swift` | 51 | 219 | 23.3% | 168 |
| `CLI/ProgressBar.swift` | 0 | 133 | 0.0% | 133 |
| `API/DownloadManager.swift` | 68 | 185 | 36.8% | 117 |
| `xcodeInstall/AuthenticateCommand.swift` | 127 | 231 | 55.0% | 104 |
| `API/List.swift` | 0 | 100 | 0.0% | 100 |
| `Utilities/FileHandler.swift` | 61 | 124 | 49.2% | 63 |
| `API/Authentication.swift` | 138 | 191 | 72.3% | 53 |
| `Secrets/SecretsStorageAWS.swift` | 124 | 175 | 70.9% | 51 |
| `xcodeInstall/DownloadCommand.swift` | 92 | 141 | 65.2% | 49 |
| `xcodeInstall/ListCommand.swift` | 39 | 84 | 46.4% | 45 |
| `xcodeInstall/InstallCommand.swift` | 68 | 111 | 61.3% | 43 |
| `Utilities/HexEncoding.swift` | 46 | 80 | 57.5% | 34 |
| `CLI-driver/CLIMain.swift` | 15 | 47 | 31.9% | 32 |
| `API/Download.swift` | 0 | 29 | 0.0% | 29 |
| `CLI/NooraDisplay.swift` | 0 | 25 | 0.0% | 25 |
| `CLI/NooraReadLine.swift` | 0 | 11 | 0.0% | 11 |

## Strategy

Focus on **testable code paths recently changed in chunk-13** (error handling in command files and CLI-driver), plus easily testable paths in utility and API code. Avoid paths requiring real system resources (actual XIP decompression, real AWS connections, real Noora terminal rendering).

All tests follow existing project patterns:
- Business logic tests create `XCodeInstall(log:, deps:)` with `MockedEnvironment().toDeps(log:)`
- CLI-driver tests parse commands and call `run(with: deps)`
- Error tests use `await #expect(throws: ErrorType.self) { ... }`
- Display assertions use `assertDisplay(env:, "expected message")`

---

## Priority 1: ListCommand.swift Error Paths (~30 lines)

**File:** `Tests/xcodeinstallTests/CLI/CLIListTest.swift`

`ListCommand.swift` is at 46.4% with 45 uncovered lines. The error catch blocks are entirely untested.

1. **`testListAuthenticationRequired`** -- `nextListError = DownloadError.authenticationRequired`, assert "Session expired"
2. **`testListAccountNeedUpgrade`** -- `nextListError = DownloadError.accountNeedUpgrade(errorCode: 2170, errorMessage: "upgrade needed")`, assert "Apple Portal error code : 2170"
3. **`testListNeedToAcceptTermsAndCondition`** -- assert "new Apple account, you need first to accept"
4. **`testListUnknownError`** -- `nextListError = DownloadError.unknownError(errorCode: 9999, errorMessage: "Something broke")`, assert "Unhandled download error"
5. **`testListSecretsStorageAWSError`** -- assert "AWS Error"
6. **`testListUnexpectedError`** -- generic `NSError`, assert "Unexpected error"
7. **`testListFromNetworkForced`** -- `nextListSource = .network`, `force: true`, assert "Forced download from Apple Developer Portal"
8. **`testListFromNetworkNotForced`** -- `force: false`, assert "No cache found, downloaded from Apple Developer Portal"

---

## Priority 2: AuthenticateCommand.swift Untested Paths (~50-70 lines)

**File:** `Tests/xcodeinstallTests/CLI/CLIAuthTest.swift`

`AuthenticateCommand.swift` is at 55% with 104 uncovered lines.

**`authenticate()` error branches:**

9. **`testAuthenticateServiceUnavailable`** -- assert "Requested authentication method is not available"
10. **`testAuthenticateUnableToRetrieveServiceKey`** -- assert "Can not connect to Apple Developer Portal"
11. **`testAuthenticateNotImplemented`** -- assert "SomeFeature is not yet implemented"
12. **`testAuthenticateSecretsStorageAWSError`** -- assert "AWS Error"
13. **`testAuthenticateUnexpectedError`** -- generic error, assert "Unexpected Error"

**`CLIAuthenticationDelegate` branches:**

14. **`testRequestMFACodeMultipleOptionsTrustedDevice`** -- two options, choose "1" (trusted device), provide code
15. **`testRequestMFACodeMultipleOptionsChooseSMS`** -- choose "2" (SMS), verify empty code returned
16. **`testRequestMFACodeInvalidChoice`** -- invalid input, expect `CLIError.invalidInput`
17. **`testRequestMFACodeSingleSMSOption`** -- single `.sms` option, provide code
18. **`testRequestMFACodeEmptyOptions`** -- empty array, expect `CLIError.invalidInput`
19. **`testRequestMFACodeNilReadLine`** -- nil readline, expect `CLIError.invalidInput`

**`retrieveAppleCredentials()` paths:**

20. **`testAuthenticateWithAWSEmptyCredentials`** -- empty creds returned, interactive prompt, verify stored
21. **`testAuthenticateWithFileSecretsBackend`** -- throws `SecretsStorageError.invalidOperation`, interactive prompt
22. **`testAuthenticateWithUsernamePasswordMethod`** -- assert "Authenticating with username and password (likely to fail)"

---

## Priority 3: DownloadCommand.swift Error Paths (~25-30 lines)

**File:** `Tests/xcodeinstallTests/CLI/CLIDownloadTest.swift`

`DownloadCommand.swift` is at 65.2% with 49 uncovered lines.

23. **`testDownloadAuthenticationRequired`** -- assert "Session expired"
24. **`testDownloadUserCancelled`** -- empty string in ReadLine, verify silent return
25. **`testDownloadInvalidInput`** -- non-numeric string, assert "Invalid input"
26. **`testDownloadSecretsStorageAWSError`** -- assert "AWS Error"
27. **`testDownloadGenericError`** -- assert "Unexpected error"
28. **`testDownloadIncompleteFile`** -- `nextFileCorrect = false`, assert "incorrect size"
29. **`testAskFileOutOfBounds`** -- number >= list size, expect `CLIError.invalidInput`
30. **`testAskFileMultipleFiles`** -- download with multiple files, two readline inputs

---

## Priority 4: InstallCommand.swift Error Paths (~30-35 lines)

**File:** `Tests/xcodeinstallTests/CLI/CLIInstallTest.swift`

`InstallCommand.swift` is at 61.3% with 43 uncovered lines.

31. **`testInstallNoDownloadedList`** -- `FileHandlerError.noDownloadedList`, assert "no downloaded file"
32. **`testInstallXCodeXIPError`** -- assert "Can not expand XIP file"
33. **`testInstallXCodeMoveError`** -- assert "Can not move Xcode"
34. **`testInstallXCodePKGError`** -- assert "Can not install additional packages"
35. **`testInstallUnsupportedType`** -- assert "Unsupported installation type"
36. **`testInstallGenericError`** -- assert "Error while installing"
37. **`testPromptForFileUserCancelled`** -- empty string, expect `CLIError.userCancelled`
38. **`testPromptForFileInvalidInput`** -- non-numeric, expect `CLIError.invalidInput`
39. **`testPromptForFileOutOfBounds`** -- number >= count, expect `CLIError.invalidInput`

---

## Priority 5: SignOutCommand.swift Error Paths (~5 lines)

**File:** `Tests/xcodeinstallTests/CLI/CLIAuthTest.swift`

40. **`testSignoutSecretsStorageAWSError`** -- assert "AWS Error"
41. **`testSignoutGenericError`** -- assert "Unexpected error"

---

## Priority 6: CLI-Driver Error Path Tests (~15-20 lines)

Tests for `ExitCode.failure` wrapping and shutdown-on-error in CLI-driver.

42. **`testSignoutErrorReturnsExitCodeFailure`** -- expect `ExitCode.failure`, verify shutdown called
43. **`testListErrorReturnsExitCodeFailure`** -- expect `ExitCode.failure`, verify shutdown called
44. **`testStoreSecretsErrorReturnsExitCodeFailure`** -- expect `ExitCode.failure`, verify shutdown called

---

## Priority 7: StoreSecretsCommand.swift Error Paths (~9 lines)

**File:** `Tests/xcodeinstallTests/CLI/CLIStoreSecretsTest.swift`

45. **`testStoreSecretsAWSError`** -- assert "AWS Error"
46. **`testStoreSecretsGenericError`** -- assert "Unexpected error"

---

## Mock Changes Required

1. **`MockedAppleAuthentication`** -- Add `nextSignoutError: Error?`. In `signout()`, throw if set.
2. **`MockedAppleDownloader`** -- May need `nextDownloadError` for download failure tests.
3. **`MockedFileHandler`** -- Add `nextDownloadedFilesError: Error?`. In `downloadedFiles()`, throw if set.
4. **`MockedSecretsHandler`** -- May need per-method error properties (e.g., `nextStoreCredentialsError`).

---

## Expected Outcome

| Priority | Est. Lines Covered | Target File |
|----------|-------------------|-------------|
| P1: ListCommand errors | ~30 | CLIListTest.swift |
| P2: AuthenticateCommand paths | ~50-70 | CLIAuthTest.swift |
| P3: DownloadCommand errors | ~25-30 | CLIDownloadTest.swift |
| P4: InstallCommand errors | ~30-35 | CLIInstallTest.swift |
| P5: SignOutCommand errors | ~5 | CLIAuthTest.swift |
| P6: CLI-driver error paths | ~15-20 | Various CLI tests |
| P7: StoreSecrets errors | ~9 | CLIStoreSecretsTest.swift |
| **Total** | **~164-199** | |

**Projected coverage:** 65-66% after P1-P7, comfortably meeting the 65% target.

---

## Implementation Order

1. Start with **mock enhancements** (required by most tests)
2. P1 (ListCommand) -- highest coverage gain per test, only 1 test exists today
3. P2 (AuthenticateCommand) -- largest single file improvement
4. P3-P5 in order
5. P6-P7 (CLI-driver + StoreSecrets)

After P1-P5, run coverage report to check progress. If already at 65%, P6-P7 can be deprioritized.
