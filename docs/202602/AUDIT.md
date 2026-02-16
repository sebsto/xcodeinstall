# xcodeinstall Codebase Audit

**Date:** 2026-02-16
**Version audited:** 0.17.2 (commit af2e108)
**Swift version:** 6.2 with strict concurrency (`defaultIsolation(MainActor.self)`)

---

## 1. Architecture Overview

### Module Map

```
CLI-driver/        ArgumentParser commands (@main entry point)
    │                  Parses CLI args, wires dependencies, delegates to xcodeInstall/
    │
    ▼
xcodeInstall/      Business logic commands (XCodeInstall class + extensions)
    │                  Orchestrates workflows: auth, list, download, install
    │
    ├──► API/          Network layer (HTTPClient, AppleAuthenticator, AppleDownloader)
    │                     Talks to Apple Developer Portal APIs
    │
    ├──► Secrets/      Credential & session storage
    │                     Two backends: SecretsStorageFile (local) & SecretsStorageAWS (Soto)
    │
    ├──► CLI/          UI abstractions (DisplayProtocol, ReadLineProtocol, ProgressBar)
    │                     Noora-backed implementations for terminal I/O
    │
    └──► Utilities/    FileHandler, ShellOutput, HexEncoding, Array+AsyncMap
```

### Dependency Graph

```
CLI-driver ──► xcodeInstall ──► API ──► Secrets
                    │               │
                    │               └──► Utilities (FileHandler)
                    │
                    └──► CLI (DisplayProtocol, ReadLineProtocol, ProgressBar)
                    │
                    └──► Utilities (FileHandler, ShellOutput)
```

### Data Flow

1. **Authentication:** `CLIAuthenticate` → `XCodeInstall.authenticate()` → `CLIAuthenticationDelegate` (prompts user) → `AppleAuthenticator.authenticate()` → Apple APIs (service key → hashcash → SRP/password → MFA) → session saved via `SecretsHandlerProtocol`
2. **List:** `CLIList` → `XCodeInstall.list()` → `AppleDownloader.list()` → Apple API or cache → `DownloadListParser` (filter/sort/enrich) → display
3. **Download:** `CLIDownload` → `XCodeInstall.download()` → list + user selection → `AppleDownloader.download()` → `DownloadManager` (URLSession delegate + KVO progress) → file saved to `~/.xcodeinstall/download/`
4. **Install:** `CLIInstall` → `XCodeInstall.install()` → `ShellInstaller.install()` → XIP uncompress + move to `/Applications`, or DMG mount + pkg install via `sudo`

### Boundary Assessment

**No circular dependencies.** The layering is clean and unidirectional. The one concern is that `CLI-driver/CLIMain.swift` serves as the composition root, which is appropriate, but the `XCodeInstaller` factory method there is doing substantial work (~40 lines of wiring). This is acceptable for a project of this size.

**`Environment.swift`** defines focused dependency protocols (`FileHandling`, `CLIInterface`, `SecretStoring`, `ShellExecuting`, `Networking`) and the `AppDependencies` struct. These focused protocols are declared but **never used as constraints anywhere** — all code passes around `AppDependencies` directly. They are dead abstractions.

---

## 2. Design Review

### Protocol Usage

| Protocol | Conformances | Justified? |
|----------|-------------|------------|
| `AppleAuthenticatorProtocol` | `AppleAuthenticator`, `MockedAppleAuthentication` | Yes — enables test mocking of auth |
| `AppleDownloaderProtocol` | `AppleDownloader`, `MockedAppleDownloader` | Yes — same reason |
| `SecretsHandlerProtocol` | `SecretsStorageFile`, `SecretsStorageAWS`, `MockedSecretsHandler` | Yes — two real backends + mock |
| `SecretsStorageAWSSDKProtocol` | `SecretsStorageAWSSoto`, `MockedSecretsStorageAWSSDK` | Yes — isolates Soto SDK |
| `FileHandlerProtocol` | `FileHandler`, `MockedFileHandler` | Yes — file system mocking |
| `URLSessionProtocol` | `URLSession`, `MockedURLSession` | Yes — network mocking |
| `DisplayProtocol` | `NooraDisplay`, `MockedDisplay` | Yes — UI mocking |
| `ReadLineProtocol` | `NooraReadLine`, `MockedReadLine` | Yes — input mocking |
| `CLIProgressBarProtocol` | `CLIProgressBar`, `MockedProgressBar` | Yes — progress mocking |
| `ShellExecuting` | `SystemShell`, `MockedShell` | Yes — shell mocking |
| `InstallerProtocol` | `ShellInstaller` | **Questionable** — single conformance, never used as a type constraint |
| `DispatchSemaphoreProtocol` | `DispatchSemaphore` | **Dead code** — not used anywhere |
| `DownloadManagerProtocol` | None (declared but unused) | **Dead code** — zero conformances |
| `AuthenticationDelegate` | `CLIAuthenticationDelegate`, mock in tests | Yes — delegates MFA UI to caller |
| `FileHandling`, `CLIInterface`, `SecretStoring`, `Networking` | Never used as constraints | **Dead abstractions** — declared in `Environment.swift` but nothing consumes them |

**Verdict:** Most protocols are justified by the testing strategy. Four are dead code: `DispatchSemaphoreProtocol`, `DownloadManagerProtocol`, `InstallerProtocol` (single conformance, never used polymorphically), and the focused dependency protocols in `Environment.swift`.

### Dependency Injection Approach

The DI approach is **consistent and practical**:
- `AppDependencies` struct holds all injectable dependencies
- `CLIMain.XCodeInstaller()` is the composition root (factory method)
- Every CLI command has the dual `run()` / `run(with:)` pattern: production calls `run()` which delegates to `run(with: nil)`, tests call `run(with: mockDeps)`

**One issue:** `InstallCommand.swift` and `DownloadCommand.swift` create `FileHandler(log: self.log)` directly instead of using `self.deps.fileHandler`, partially bypassing DI. This makes those code paths untestable with mocked file handlers.

### The `Environment.swift` / `AppDependencies` Design

`AppDependencies` is a flat struct with 10 properties. This is fine for the current scale but has some design friction:
- The `let`/`var` split is intentional and well-designed: `let` for stable infrastructure that never changes after construction (`fileHandler`, `urlSessionData`, `shell`, `log`), `var` for services that tests need to replace after construction (`display`, `readLine`, `progressBar`, `secrets`, `authenticator`, `downloader`). `MockedEnvironment` mirrors this same pattern.
- `secrets` is `Optional<SecretsHandlerProtocol>` while all others are non-optional — the install command doesn't need secrets, but every constructor must still provide it
- The focused protocols (`FileHandling`, `CLIInterface`, etc.) in the same file were likely intended for a future refactor but are currently unused

### CLI-driver / xcodeInstall Command Split

The split is **reasonable and worth keeping**:
- `CLI-driver/` handles ArgumentParser concerns (command configuration, option parsing, factory wiring)
- `xcodeInstall/` handles business logic (what to do after arguments are parsed)

This cleanly separates "how the user invokes it" from "what it does." The only concern is that each CLI-driver file is very thin (10-30 lines of real logic), which is slightly over-structured but not harmful.

### Error Handling Strategy

Error handling is **inconsistent across commands**:

| Command | Strategy |
|---------|----------|
| `authenticate` | Catches specific `AuthenticationError` cases, displays user-friendly messages, does not re-throw |
| `list` | Catches specific `DownloadError` and `SecretsStorageAWSError` cases, displays messages, **re-throws** |
| `download` | Catches specific errors, displays messages, does not re-throw |
| `install` | Catches specific `InstallerError` cases, displays messages, does not re-throw, calls `exit(0)` on empty input |
| `signout` | **No error handling** — propagates everything to caller |
| `storeSecrets` | Catches `SecretsStorageAWSError`, displays, re-throws |

The mix of swallowing vs. re-throwing errors means the calling CLI-driver layer has unpredictable behavior. Since all commands are invoked from ArgumentParser's `run()`, uncaught errors will print a generic error message. A consistent strategy would improve UX.

---

## 3. Implementation Quality

### Dead Code

| Item | Location | Type |
|------|----------|------|
| `DispatchSemaphoreProtocol` + `DispatchSemaphore` extension | `API/DispatchSemaphore.swift` | Entire file is dead code |
| `DownloadManagerProtocol` | `API/DownloadManager.swift:13-15` | Protocol declared, zero conformances |
| `InstallerProtocol` | `API/Install.swift:16-24` | Never used as a type constraint |
| `FileHandling`, `CLIInterface`, `SecretStoring`, `Networking` protocols | `Environment.swift:30-64` | Declared but never constrained against |
| `SecretsHandlerTestsProtocol` | `Tests/.../SecretsHandlerTests.swift` | Declared but never enforced |
| Commented-out code in `InstallSupportedFiles.swift:59-69` | `API/InstallSupportedFiles.swift` | Old non-generic implementation left as comment |
| Commented-out code in `InstallDownloadListExtension.swift:41-43` | `API/InstallDownloadListExtension.swift` | Obsolete filter step |
| Commented-out `list()` function | `SecretsStorageAWS+Soto.swift:103-107` | Unused AWS list function |
| `awsSDK` property on `MockedEnvironment` | `Tests/.../EnvironmentMock.swift` | Declared, never used in `toDeps()` |
| `getMFATypeOK()` function in `CLIAuthTest.swift` | Test file | Defined but never called |

### Force Unwraps and Unsafe Patterns

| Location | Code | Risk |
|----------|------|------|
| `HTTPClient.swift:153` | `(response as? HTTPURLResponse)!.statusCode` | Crash if response isn't HTTP (unlikely but possible) |
| `HTTPClient.swift:174` | `URL(string: url)!` | Crash on malformed URL strings |
| `DownloadManager.swift:121` | `URL(string: url)!` | Same — duplicated `request()` method |
| `Authentication+Hashcash.swift:38` | `session.hashcash!` | Safe due to preceding `if` but unnecessary — could use `guard let` |
| `Authentication+SRP.swift:48` | `SRPKey(base64: B)!` | Crash if server returns invalid base64 |
| `Authentication+SRP.swift:133` | `Data(base64Encoded: salt)!` | Crash if salt is invalid base64 |
| `SecretsStorageAWS+Soto.swift:237` | `as! T` force cast | Crash if generic type doesn't match — has FIXME |
| `StoreSecretsCommand.swift:18` | `self.deps.secrets!` | Crash if no secrets backend configured |
| `InstallCommand.swift:40` (final catch) | `fileToInstall!` | Theoretically safe but risky in a catch-all |
| `AppleCredentialsSecret.swift:41` | `fatalError("Can not create...")` | Crash on invalid UTF-8 string |
| `AppleSessionSecret.swift:80` | `fatalError("Can not create...")` | Same pattern |
| `SecretsHandler.swift:179` | `fatalError("Cookie string has no name...")` | Crash on malformed cookie |
| `PBKDF2.pbkdf2:188` | `fatalError()` | Crash if password isn't valid UTF-8 |

### Async/Await vs. Legacy Concurrency

The codebase has been **thoroughly modernized to async/await**. The only legacy artifact is `DispatchSemaphore.swift`, which defines a `DispatchSemaphoreProtocol` that is never used. The `DownloadManager` correctly uses `URLSessionDownloadDelegate` with `AsyncThrowingStream` and KVO — a well-implemented bridge between delegate-based and structured concurrency APIs. The `nonisolated(unsafe)` on `progressObservation` is properly documented with its safety invariant.

### Code Duplication

1. **`request()` method duplicated** between `HTTPClient.swift:166-193` and `DownloadManager.swift:114-136` — identical logic for building `URLRequest` from URL string, method, body, and headers.

2. **`promptForCredentials()` duplicated** between `AuthenticateCommand.swift:144-184` and `StoreSecretsCommand.swift:34-57` — both prompt for Apple ID username/password, but return different types (`AppleCredentialsSecret` vs. `[String]`).

3. **Session header extraction duplicated** between `Authentication+UsernamePassword.swift:28-29` and `Authentication+SRP.swift:94-95` — both extract `X-Apple-ID-Session-Id` and `scnt` from response headers.

4. **File existence check pattern** repeated across `InstallPkg.swift:25-28`, `InstallCLTools.swift:25-28`, `InstallCLTools.swift:78-81`, and `InstallXcode.swift:76-79` — same guard/log/throw pattern.

5. **Copy-initializers** on `DownloadList.File` and `DownloadList.Download` (`init(from:existInCache:)`, `init(from:replaceWith:)`) manually copy 8-10 fields. These could be simplified.

### Naming Inconsistencies

| Issue | Location |
|-------|----------|
| `unsuported` (typo, should be `unsupported`) | `InstallSupportedFiles.swift:17` |
| `accountneedUpgrade` (should be `accountNeedUpgrade`) | `DownloadListData.swift:23` |
| File header says "File.swift" for many files | `Authentication+SRP.swift`, `Authentication+UsernamePassword.swift`, `Authentication+Hashcash.swift`, `ShellOutput.swift`, `Array+AsyncMap.swift` |
| File header says "CLIAuthenticate.swift" | `CLIDownload.swift`, `CLIList.swift` |
| File header says "Helper.swift" | `SecretsHandler.swift` |
| `XCodeInstaller` factory named with PascalCase | `CLIMain.swift:67` — methods should be camelCase in Swift |
| `getAppleServicekey` lowercase 'k' | `Authentication.swift:258` |
| `SUDOCOMMAND`, `HDIUTILCOMMAND` etc. SCREAMING_CASE | `Install.swift:50-52` — Swift convention is camelCase for constants |
| Typo: "torough" | `XcodeInstallCommand.swift:25` |
| Typo: "attemp" | `InstallCommand.swift:27` |
| Typo: "omited" | `CLIDownload.swift`, `CLIInstall.swift` |
| Typo: "INCOMMING" | `URLLogger.swift:52` |
| Typo: "Unknwon" | `List.swift:90` |
| Typo: "Aftre" | `SecretsStorageAWS+Soto.swift:134` |
| Typo: "abording" | `SecretsStorageAWS+Soto.swift:134` |
| Typo: "ourselevs" | `SecretsStorageAWS+Soto.swift:165` |
| Typo: "installtion" | `InstallSupportedFiles.swift:25` |

### Secrets Layer Separation

The Secrets layer has **clean separation** between:
- `SecretsHandlerProtocol` — the contract consumed by all other layers
- `SecretsStorageFile` — local file-based implementation
- `SecretsStorageAWS` — AWS facade that delegates to `SecretsStorageAWSSDKProtocol`
- `SecretsStorageAWSSoto` — Soto SDK implementation

The layering `SecretsStorageAWS` → `SecretsStorageAWSSDKProtocol` → `SecretsStorageAWSSoto` adds an extra indirection level that enables mocking without a real AWS connection. This is well-designed.

One concern: `SecretsStorageFile` throws `SecretsStorageAWSError.invalidOperation` for `retrieveAppleCredentials()` and `storeAppleCredentials()`. Using an AWS-specific error type for a file-based storage backend is misleading. A generic `SecretsStorageError` would be more appropriate.

### Other Issues

- **`exit(0)` calls** in `InstallCommand.swift:73` and `DownloadCommand.swift:72` — hard process exits that bypass Swift cleanup, `defer` blocks, and structured concurrency teardown.
- **No bounds checking** on user-selected indices in `InstallCommand.swift:78` (`installableFiles[num]`), `DownloadCommand.swift:67` (`parsedList[num]`), and `DownloadCommand.swift:105` (`download.files[0]`).
- **`DateFormatter` created per-call** in `String.toDate()` (`DownloadListParser.swift`) — `DateFormatter` is expensive to create; should be a static constant.
- **Hardcoded Xcode version default** `"26"` in `CLIList.swift:43` — needs manual updates each year.
- **Password logging risk:** `URLLogger.swift` has a `_filterPassword` function that redacts `"password":` fields, but the regex only matches JSON format. Passwords could leak in other log formats.

---

## 4. Test Coverage Analysis

### Coverage Map

| Source File | Has Tests? | Test File(s) | Quality |
|-------------|-----------|--------------|---------|
| `Authentication.swift` | Yes | `AuthenticationTests.swift` | Good — tests service key retrieval, response handling |
| `Authentication+MFA.swift` | Yes | `AuthenticationMFATest.swift` | Good — tests MFA type parsing, 2FA flows, SMS verify |
| `Authentication+SRP.swift` | Yes | `AuthenticationSRPTest.swift`, `SRPTest.swift` | Good — tests SRP flow, crypto primitives |
| `Authentication+UsernamePassword.swift` | Partial | `AuthenticationTests.swift` | Tested via `startAuthentication` but not isolated |
| `Authentication+Hashcash.swift` | Yes | `SRPTest.swift` | Good — deterministic hashcash tests |
| `Download.swift` | Yes | `DownloadTests.swift` | Partial — tests download initiation but not stream |
| `DownloadManager.swift` | Partial | via `DownloadTests.swift` | Mock only — `MockDownloadManager` doesn't test real delegate logic |
| `DownloadListData.swift` | Yes | `ListTest.swift`, `DownloadListParserTest.swift` | Good — JSON parsing, filtering, sorting |
| `HTTPClient.swift` | Yes | `HTTPClientTests.swift`, `URLRequestCurlTest.swift` | Good — request building, cURL output |
| `Install.swift` | Yes | `InstallTest.swift` | Good — dispatch logic, file matching |
| `InstallXcode.swift` | Partial | `InstallTest.swift` | Tests verify shell commands, not actual XIP/move |
| `InstallCLTools.swift` | Partial | `InstallTest.swift` | File-not-exist case only (macOS-gated) |
| `InstallPkg.swift` | Partial | `InstallTest.swift` | Verified via shell command recording |
| `InstallSupportedFiles.swift` | Yes | `InstallTest.swift` | Good — tests xCode, CLTools, unsupported cases |
| `InstallDownloadListExtension.swift` | Indirect | via `InstallTest.swift` | Used in `fileMatch` tests |
| `List.swift` | Yes | `ListTest.swift` | Comprehensive — 8 test cases including errors |
| `URLLogger.swift` | No | — | **Not tested** |
| `URLRequestExtension.swift` | Yes | `URLRequestCurlTest.swift` | Good |
| `DispatchSemaphore.swift` | No | — | Dead code, no tests needed |
| `NooraDisplay.swift` | No | — | Thin wrapper, low risk |
| `NooraReadLine.swift` | No | — | Thin wrapper, low risk |
| `ProgressBar.swift` | No | — | **Not tested** — has non-trivial logic (ANSI codes, percentage calculation) |
| `Protocols.swift` | N/A | — | Protocol definitions only |
| `CLIAuthenticate.swift` | Yes | `CLIAuthTest.swift` | Good — tests full auth flow with mocks |
| `CLIDownload.swift` | Yes | `CLIDownloadTest.swift` | Good — tests download flow |
| `CLIInstall.swift` | Yes | `CLIInstallTest.swift` | Good |
| `CLIList.swift` | Yes | `CLIListTest.swift` | Good |
| `CLIMain.swift` | Indirect | — | Factory tested via all CLI tests |
| `CLIStoreSecrets.swift` | Partial | `CLIStoreSecretsTest.swift` | Has a test function **missing `@Test` attribute** — won't run |
| `AuthenticateCommand.swift` | Yes | `CLIAuthTest.swift` | Good — delegate pattern tested |
| `DownloadCommand.swift` | Yes | `CLIDownloadTest.swift` | Good |
| `DownloadListParser.swift` | Yes | `DownloadListParserTest.swift` | Good — parsing, enriching, pretty-printing |
| `InstallCommand.swift` | Yes | `CLIInstallTest.swift` | Good |
| `ListCommand.swift` | Yes | `CLIListTest.swift` | Good |
| `SignOutCommand.swift` | Indirect | — | Tested through CLI layer |
| `StoreSecretsCommand.swift` | Partial | `CLIStoreSecretsTest.swift` | See note about missing `@Test` |
| `XcodeInstallCommand.swift` | N/A | — | Class definition, tested through all commands |
| `SecretsHandler.swift` | Yes | `SecretsHandlerTests.swift` | Good — cookie merge, session round-trip |
| `SecretsStorageAWS.swift` | Yes | `AWSSecretsHandlerTest.swift` | Good — via mocked SDK |
| `SecretsStorageAWS+Soto.swift` | Partial | `AWSSecretsHandlerSotoTest.swift` | Init tested, `testCreateSecret` disabled |
| `SecretsStorageFile.swift` | Yes | `FileSecretsHandlerTest.swift` | Good — same base tests as AWS |
| `FileHandler.swift` | Yes | `FileHandlerTests.swift` | Good — move, fileExists, checkFileSize |
| `Array+AsyncMap.swift` | Indirect | Used in `DownloadListParser` tests | Not directly tested |
| `HexEncoding.swift` | Yes | `SRPTest.swift` | Tested via `hexDigest()` |
| `ShellOutput.swift` | N/A | — | Type alias + convenience extension only |

### Critical Untested Paths

1. **`DownloadManager` / `DownloadDelegate`** — The real download delegate with KVO progress, file moves, error page detection, and stream management is completely untested. `MockDownloadManager` replaces all this logic.
2. **`ProgressBar` rendering** — The ANSI escape code logic, percent calculation, and clear/complete behavior have no tests. A divide-by-zero bug exists when `total` is 0.
3. **`CLIStoreSecretsTest.testPromptForCredentials`** — Missing `@Test` attribute means this test never executes.

### Mock Quality Assessment

**Well-designed mocks:**
- `MockedSecretsStorageAWSSDK` — uses `Mutex` for thread safety, properly implements all CRUD operations in-memory
- `SecretsHandlerTestsBase<T>` — generic test base enables identical test scenarios across File and AWS backends
- `MockedShell` / `MockedRunRecorder` — cleanly records shell commands for verification

**Problematic mocks:**
- `MockedAppleDownloader.list(force:)` — contains ~40 lines of business logic duplicating `AppleDownloader.list()`. Tests validate the mock's behavior, not the production code's. Changes to production error handling won't be caught.
- `MockedDisplay` — only captures the last `display()` call. Multi-step UI flows can only assert the final output.
- `MockedReadLine` — calls `fatalError()` when inputs are exhausted. Should fail the test gracefully instead.
- `MockDownloadManager` — has a `shouldFail` property that "does not throw errors" per a FIXME comment.

---

## 5. Simplification Opportunities

### Remove Dead Abstractions

- **Delete `API/DispatchSemaphore.swift`** entirely — `DispatchSemaphoreProtocol` is never used.
- **Delete `DownloadManagerProtocol`** from `DownloadManager.swift` — zero conformances.
- **Delete `InstallerProtocol`** from `Install.swift` — single conformance, never used polymorphically. `ShellInstaller` can stand on its own.
- **Delete the focused dependency protocols** (`FileHandling`, `CLIInterface`, `SecretStoring`, `Networking`) from `Environment.swift` — never used as constraints. If a future refactor wants them, they can be re-added then.
- **Delete `SecretsHandlerTestsProtocol`** from `SecretsHandlerTests.swift` — declared but never referenced.

### Consolidate Install Files

The current split of `Install.swift` + `InstallXcode.swift` + `InstallCLTools.swift` + `InstallPkg.swift` + `InstallSupportedFiles.swift` + `InstallDownloadListExtension.swift` creates 6 files for ~350 total lines. The files are all extensions of `ShellInstaller` or related types.

**Recommendation:** Merge into 2 files:
- `Install.swift` — `ShellInstaller` class, `InstallerError`, `SupportedInstallation`, `install()`, `fileMatch()`, `installPkg()`
- `InstallXcode.swift` — `installXcode()`, `uncompressXIP()`, `moveApp()`, `installCommandLineTools()`, `mountDMG()`, `unmountDMG()`

Keep `InstallDownloadListExtension.swift` separate since it extends `DownloadList`, not `ShellInstaller`.

### Merge Small Related Files

- **`Authentication+UsernamePassword.swift`** (37 lines) could merge into `Authentication.swift` — it's a single method.
- **`Authentication+Hashcash.swift`** (159 lines) is substantial enough to stay separate.
- **`ShellOutput.swift`** (22 lines) could merge into `Environment.swift` since `SystemShell` already lives there.

### Eliminate the Duplicate `request()` Method

`DownloadManager.swift:114-136` duplicates `HTTPClient.swift:166-193`. Extract into a shared free function or static method:

```swift
static func buildRequest(for url: String, method: HTTPVerb, body: Data?, headers: [String: String]?) -> URLRequest
```

### Replace Custom `SupportedInstallation` Logic

`InstallSupportedFiles.swift` uses an over-engineered generic approach with parallel arrays, `enumerated()`, `compactMap`, and `filter` — plus 10 lines of commented-out simpler code that does the same thing. The commented-out code is clearer:

```swift
if file.hasPrefix("Command Line Tools for Xcode") && file.hasSuffix(".dmg") {
    return .xCodeCommandLineTools
} else if file.hasPrefix("Xcode") && file.hasSuffix(".xip") {
    return .xCode
} else {
    return .unsupported
}
```

### Simplify `DownloadList.File` Copy Initializers

The manual field-by-field copy in `init(from:existInCache:)` and `Download.init(from:replaceWith:)` could be simplified. Since these are Codable structs, a factory method approach might be cleaner, but the simplest fix is to just accept the verbosity and note that it's a consequence of `Codable` structs with custom decoding.

### Standard Library Replacements

- **`String.toDate()`** creates a new `DateFormatter` every call. Use a static `DateFormatter` or switch to `Date.ISO8601FormatStyle` / `Date.ParseStrategy`.
- **`String * Int` operator** in `ProgressBar.swift` — could use `String(repeating:count:)` from the standard library instead.
- **`Array.asyncMap`** in `Array+AsyncMap.swift` — this is already a clean utility. No standard library replacement exists yet, so keep it.

---

## 6. Action Plan

### Implementation Protocol for Agents

Each chunk below is an independent unit of work. An AI coding agent will implement each chunk. Follow these rules strictly:

**Before starting a chunk:**
1. Run `git checkout main` to ensure you start from a clean main branch.
2. Create a new branch: `git checkout -b audit/chunk-NN` (e.g., `audit/chunk-01`, `audit/chunk-02`).
3. Read every file listed in the chunk's **Files** section before making any changes.

**While implementing:**
4. Make only the changes described in the chunk. Do not refactor surrounding code, add comments, or fix unrelated issues.
5. **Force unwrap rule:** When replacing a force unwrap (`!`), determine whether nil represents a *user error* or a *programming error*. If the value should never be nil due to prior logic or mandatory CLI arguments, use `guard let … else { preconditionFailure("descriptive message") }`. Only use `throw` for cases where nil is a legitimate runtime condition the user can cause.
6. After all changes are made, the code **must compile**: run `swift build` and verify it succeeds with zero errors.
7. After build passes, **all tests must pass**: run `swift test` and verify all 115 tests pass (or more, if the chunk adds tests).
8. If build or tests fail, fix the issue before considering the chunk complete. Do not move on with failures.

**After completing a chunk:**
9. **Do NOT commit.** Leave the changes unstaged. The user will review the diff and commit manually.
10. **Write a summary file** at `docs/202602/chunk-NN.md` (e.g., `chunk-01.md`, `chunk-02.md`). The file must contain:
    - Chunk number and title
    - List of files changed (added, modified, deleted)
    - Brief description of each change made
    - Build result (`swift build` output — pass/fail)
    - Test result (`swift test` output — number of tests, pass/fail)
    - Any issues encountered and how they were resolved
    - Any deviations from the plan and why
11. Report to the user: which files were changed, what was done, and confirm both `swift build` and `swift test` passed.

**Dependency handling:**
- Some chunks have dependencies on others (noted in each chunk). If a chunk depends on another that hasn't been merged to main yet, skip it and move to the next independent chunk.
- The user will merge completed chunks to main between sessions.

**Baseline (as of 2026-02-16):**
- Branch: `main`, commit `af2e108`
- `swift build`: compiles cleanly
- `swift test`: 115 tests, all passing

---

### Chunk 1: Remove Dead Code and Fix Typos

**Branch:** `audit/chunk-01`

**Files to read first:**
- `Sources/xcodeinstall/API/DispatchSemaphore.swift` — entire file, delete it
- `Sources/xcodeinstall/API/DownloadManager.swift` — line 13 (`DownloadManagerProtocol`)
- `Sources/xcodeinstall/API/Install.swift` — line 16 (`InstallerProtocol`)
- `Sources/xcodeinstall/Environment.swift` — lines 30, 35, 42, 60 (unused protocols `FileHandling`, `CLIInterface`, `SecretStoring`, `Networking`)
- `Tests/xcodeinstallTests/Secrets/SecretsHandlerTests.swift` — line 16 (`SecretsHandlerTestsProtocol`)
- `Sources/xcodeinstall/API/InstallSupportedFiles.swift` — lines 61-67 (commented-out code)
- `Sources/xcodeinstall/API/InstallDownloadListExtension.swift` — lines 41-43 (commented-out code)

**Step-by-step changes:**

1. **Delete** `Sources/xcodeinstall/API/DispatchSemaphore.swift` entirely.

2. **Remove dead protocols** (delete the declaration only, not surrounding code):
   - `DownloadManagerProtocol` at `DownloadManager.swift:13`
   - `InstallerProtocol` at `Install.swift:16`
   - `FileHandling`, `CLIInterface`, `SecretStoring`, `Networking` from `Environment.swift` (lines 30, 35, 42, 60 respectively)
   - `SecretsHandlerTestsProtocol` at `SecretsHandlerTests.swift:16`

3. **Remove commented-out code:**
   - `InstallSupportedFiles.swift:61-67`
   - `InstallDownloadListExtension.swift:41-43`

4. **Fix typo `unsuported` → `unsupported`** (rename the enum case and all references):
   - `InstallSupportedFiles.swift`: lines 17, 46, 52, 57, 66
   - `Install.swift`: lines 81, 99
   - `Tests/xcodeinstallTests/API/InstallTest.swift`: line 33

5. **Fix typo `accountneedUpgrade` → `accountNeedUpgrade`** (rename enum case and all references):
   - `API/DownloadListData.swift`: lines 23, 48
   - `API/List.swift`: line 82
   - `xcodeInstall/ListCommand.swift`: line 71
   - `Tests/xcodeinstallTests/API/ListTest.swift`: line 190
   - `Tests/xcodeinstallTests/API/MockedNetworkClasses.swift`: line 153

6. **Fix misnamed file header comments** (line 2 of each file — change the filename in the comment to match the actual filename):
   - `xcodeInstall/XcodeInstallCommand.swift` — says "XcodeInstall.swift"
   - `API/Authentication+MFA.swift` — says "AuthenticationMFA.swift"
   - `API/URLRequestExtension.swift` — says "ExtensionURLRequest.swift"
   - `API/DownloadListData.swift` — says "DownloadData.swift"
   - `API/Download.swift` — says "List.swift"
   - `API/Authentication+SRP.swift` — says "File.swift"
   - `API/Authentication+Hashcash.swift` — says "File.swift"
   - `API/Authentication+UsernamePassword.swift` — says "File.swift"
   - `CLI-driver/CLIMain.swift` — says "CLI.swift"
   - `CLI-driver/CLIDownload.swift` — says "CLIAuthenticate.swift"
   - `CLI-driver/CLIList.swift` — says "CLIAuthenticate.swift"
   - `Secrets/SecretsHandler.swift` — says "Helper.swift"
   - `Secrets/SecretsStorageAWS+Soto.swift` — says "SecretsStorageAWSSoto.swift"
   - `Utilities/FileHandler.swift` — says "FileManagerExtension.swift"
   - `Utilities/Array+AsyncMap.swift` — says "File.swift"
   - `Utilities/ShellOutput.swift` — says "File.swift"

7. **Fix minor typos** (in comments/strings only — not identifiers):
   - `xcodeInstall/XcodeInstallCommand.swift:27` — "torough" → "thorough"
   - `xcodeInstall/InstallCommand.swift:36` — "attemp" → "attempt"
   - `CLI-driver/CLIDownload.swift:31` — "omited" → "omitted"
   - `CLI-driver/CLIInstall.swift:29` — "omited" → "omitted"
   - `Utilities/FileHandler.swift:128` — "omited" → "omitted"
   - `API/URLLogger.swift:52` — "INCOMMING" → "INCOMING"
   - `API/List.swift:90` — "Unknwon" → "Unknown"

**Verification:** `swift build` then `swift test` — expect 115 tests passing. These are all renames and deletions with no behavioral change.

**Effort:** Small
**Dependencies:** None
**Benefit:** Reduces cognitive load, eliminates confusion, fixes naming inconsistencies. Safe refactor with zero behavioral changes.

### Chunk 2: Fix the Missing `@Test` Attribute and Test Issues

**Branch:** `audit/chunk-02`

**Files to read first:**
- `Tests/xcodeinstallTests/CLI/CLIStoreSecretsTest.swift` — line 65 (`testPromptForCredentials`)
- `Tests/xcodeinstallTests/CLI/CLIAuthTest.swift` — line 153 (`getMFATypeOK()`)
- `Tests/xcodeinstallTests/EnvironmentMock.swift` — line 85 (`awsSDK`)

**Step-by-step changes:**

1. **Add `@Test` attribute** to `testPromptForCredentials` at `CLIStoreSecretsTest.swift:65`. Look at the other test functions in the same file for the exact annotation style (e.g., `@Test("description")`).

2. **Delete `getMFATypeOK()`** at `CLIAuthTest.swift:153`. This function is dead code in this file. Note: a function with the same name exists in `AuthenticationMFATest.swift` — leave that one alone, it is actively called.

3. **Remove `awsSDK` property** from `MockedEnvironment` at `EnvironmentMock.swift:85`. Grep for any references to `awsSDK` in the test files before deleting — it should be unused.

**Verification:** `swift build` then `swift test` — expect **116 tests** passing (one more than baseline, because `testPromptForCredentials` now actually runs).

**Effort:** Small
**Dependencies:** None
**Benefit:** Ensures all intended tests actually run. Eliminates dead test code.

### Chunk 3: Eliminate Duplicate `request()` Method

**Branch:** `audit/chunk-03`

**Files to read first:**
- `Sources/xcodeinstall/API/HTTPClient.swift` — lines 166-193 (the `request()` method)
- `Sources/xcodeinstall/API/DownloadManager.swift` — lines 114-136 (the duplicate `request()` method)

**Step-by-step changes:**

1. **Read both methods carefully.** Compare them to understand what differs (if anything). The `HTTPClient` version may have additional parameters or logic.

2. **Choose one of these approaches** (prefer the simplest):
   - **Option A (preferred):** Make `DownloadManager.request()` call a shared helper. Add a package-internal free function (e.g., `func buildURLRequest(for:method:body:headers:) -> URLRequest`) in `HTTPClient.swift` and have both call it.
   - **Option B:** Since `DownloadManager` only calls `request()` once (line 73), inline the URL request construction there and delete the `request()` method entirely.

3. **Verify** that `DownloadManager.download()` still works — it calls `self.request(for:withHeaders:)` at line 73.

**Verification:** `swift build` then `swift test` — expect 115 tests passing. No behavioral change.

**Effort:** Small
**Dependencies:** None
**Benefit:** DRY — single source of truth for URL request construction.

### Chunk 4: Fix Direct `FileHandler` Construction (DI Bypass)

**Branch:** `audit/chunk-04`

**Files to read first:**
- `Sources/xcodeinstall/xcodeInstall/InstallCommand.swift` — lines 34, 102 (`FileHandler(log:)` direct construction)
- `Sources/xcodeinstall/xcodeInstall/DownloadCommand.swift` — full file (verify whether it also bypasses DI)
- `Sources/xcodeinstall/Utilities/FileHandler.swift` — confirm `downloadDirectory()` is part of `FileHandlerProtocol`

**Step-by-step changes:**

1. In `InstallCommand.swift:34`, replace `FileHandler(log: self.log).downloadDirectory()` with `self.deps.fileHandler.downloadDirectory()`.

2. In `InstallCommand.swift:102`, same replacement if `FileHandler(log:)` is constructed directly there.

3. Check `DownloadCommand.swift` for any similar direct construction. (Initial investigation found none — it already uses `self.deps.fileHandler` — but verify.)

4. Grep for `FileHandler(log:` across all of `Sources/xcodeinstall/` to catch any other bypass sites.

**Verification:** `swift build` then `swift test` — expect 115 tests passing. Behavioral change: install commands now use the injected file handler, which means tests with mocked file handlers will cover these paths.

**Effort:** Small
**Dependencies:** None
**Benefit:** Ensures file handler operations go through the injected dependency, improving testability.

### Chunk 5: Replace `exit(0)` Calls with Proper Error Flow

**Branch:** `audit/chunk-05`

**Files to read first:**
- `Sources/xcodeinstall/xcodeInstall/InstallCommand.swift` — line 97 (`exit(0)`)
- `Sources/xcodeinstall/xcodeInstall/DownloadCommand.swift` — line 146 (`exit(0)`)
- `Sources/xcodeinstall/CLI-driver/CLIError.swift` or wherever `CLIError` is defined — to see existing cases

**Step-by-step changes:**

1. **Read the `CLIError` enum** to understand existing cases. Add a new case `userCancelled` if one doesn't already exist.

2. In `InstallCommand.swift:97`, replace `exit(0)` with `throw CLIError.userCancelled` (or `return` if the function's control flow allows it). Read the surrounding context to understand what happens after the `exit(0)` — it's in a user-cancellation path where the user chose not to proceed.

3. In `DownloadCommand.swift:146`, same replacement. Read the context — likely also a user cancellation.

4. **Handle the new error at the CLI-driver level** if needed. Check the CLI-driver files (`CLIInstall.swift`, `CLIDownload.swift`) to see if their `run()` methods catch errors. If `CLIError.userCancelled` should be a silent exit (no error message), add a catch clause that simply returns.

**Verification:** `swift build` then `swift test` — expect 115 tests passing. The behavioral change is that user cancellations now go through normal error flow instead of hard-killing the process.

**Effort:** Small
**Dependencies:** None
**Benefit:** Eliminates hard process exits that bypass cleanup and structured concurrency teardown.

### Chunk 6: Add Bounds Checking on User Selection

**Branch:** `audit/chunk-06`

**Files to read first:**
- `Sources/xcodeinstall/xcodeInstall/InstallCommand.swift` — line 102 (`installableFiles[num]` — no bounds check)
- `Sources/xcodeinstall/xcodeInstall/DownloadCommand.swift` — lines 120, 132 (`parsedList[num].files[0]` and `parsedList[num].files[fileNum]` — no bounds checks)

**Step-by-step changes:**

1. In `InstallCommand.swift`, find the line where `num` is used to index into `installableFiles` (line 102). Add a guard before the access:
   ```swift
   guard num >= 0, num < installableFiles.count else {
       throw CLIError.invalidInput
   }
   ```

2. In `DownloadCommand.swift`, find the lines where `num` indexes `parsedList` (line 120) and `fileNum` indexes `parsedList[num].files` (line 132). Add bounds guards before each access.

3. **Read the surrounding code** to understand how `num` is obtained (likely from `Int(readLine)` or similar). Place the guard after the integer parsing but before the array access.

**Verification:** `swift build` then `swift test` — expect 115 tests passing. No existing test exercises invalid input, so this is purely defensive.

**Effort:** Small
**Dependencies:** None
**Benefit:** Prevents array-index-out-of-bounds crashes on invalid user input.

### Chunk 7: Consolidate Install Files

**Branch:** `audit/chunk-07`

**Files to read first (read ALL before making changes):**
- `Sources/xcodeinstall/API/Install.swift` — `ShellInstaller` class, `InstallerError`, `SupportedInstallation` enum
- `Sources/xcodeinstall/API/InstallPkg.swift` — `installPkg()` extension
- `Sources/xcodeinstall/API/InstallXcode.swift` — `installXcode()`, `uncompressXIP()`, `moveApp()` extensions
- `Sources/xcodeinstall/API/InstallCLTools.swift` — `installCommandLineTools()`, `mountDMG()`, `unmountDMG()` extensions
- `Sources/xcodeinstall/API/InstallSupportedFiles.swift` — `SupportedInstallation.supported()`, `fileMatch()`
- `Sources/xcodeinstall/API/InstallDownloadListExtension.swift` — `DownloadList` extensions (keep separate)
- `Tests/xcodeinstallTests/API/InstallTest.swift` — to understand what's tested

**Step-by-step changes:**

1. **Merge `InstallPkg.swift` into `Install.swift`:** Move the `installPkg()` method into the `Install.swift` file as part of the `ShellInstaller` extension (or directly in the class body). Delete `InstallPkg.swift`.

2. **Merge `InstallSupportedFiles.swift` into `Install.swift`:** Move `SupportedInstallation.supported()` and `fileMatch()` into `Install.swift`. Delete `InstallSupportedFiles.swift`.

3. **Merge `InstallCLTools.swift` into `InstallXcode.swift`:** Move `installCommandLineTools()`, `mountDMG()`, `unmountDMG()` into `InstallXcode.swift`. Delete `InstallCLTools.swift`.

4. **Simplify `SupportedInstallation.supported()`:** Replace the generic array-based approach with direct if/else logic (the commented-out code that was removed in Chunk 1 shows the simpler approach):
   ```swift
   if file.hasPrefix("Command Line Tools for Xcode") && file.hasSuffix(".dmg") {
       return .xCodeCommandLineTools
   } else if file.hasPrefix("Xcode") && file.hasSuffix(".xip") {
       return .xCode
   } else {
       return .unsupported  // note: fixed spelling from Chunk 1
   }
   ```

5. **Keep `InstallDownloadListExtension.swift` separate** — it extends `DownloadList`, not `ShellInstaller`.

6. **Result:** 3 files instead of 6: `Install.swift`, `InstallXcode.swift`, `InstallDownloadListExtension.swift`.

**Verification:** `swift build` then `swift test` — expect 115 tests passing (or 116 if Chunk 2 is merged). All test references should still work since only file boundaries changed, not type/method names.

**Effort:** Medium
**Dependencies:** Chunk 1 (the `unsuported` → `unsupported` rename must be merged first, otherwise you'll be working with the old spelling)
**Benefit:** Reduces file count, simplifies navigation. The current split creates unnecessary indirection for 350 lines of code.

### Chunk 8: Unify `promptForCredentials` Implementations

**Branch:** `audit/chunk-08`

**Files to read first:**
- `Sources/xcodeinstall/xcodeInstall/AuthenticateCommand.swift` — lines 144-184 (`promptForCredentials()` in `CLIAuthenticationDelegate`)
- `Sources/xcodeinstall/xcodeInstall/StoreSecretsCommand.swift` — find the `promptForCredentials()` method (returns `[String]`)
- `Sources/xcodeinstall/Secrets/SecretsHandler.swift` — find `AppleCredentialsSecret` struct definition

**Step-by-step changes:**

1. **Read both `promptForCredentials` implementations** and compare them. They both prompt for username and password using `deps.readLine`.

2. **Have `StoreSecretsCommand.promptForCredentials()` return `AppleCredentialsSecret`** instead of `[String]`. This eliminates the type-unsafe array return.

3. **Option A (preferred):** If the two implementations are nearly identical, delete the one in `StoreSecretsCommand` and have it call `CLIAuthenticationDelegate`'s version (passing `storingToAWS: true`).

4. **Option B:** If they differ enough to keep separate, at minimum change the return type to `AppleCredentialsSecret`.

5. **Update all call sites** of `StoreSecretsCommand.promptForCredentials()` to use the new return type (likely accessing `.username`/`.password` instead of `[0]`/`[1]`).

**Verification:** `swift build` then `swift test` — expect 115+ tests passing. The `CLIStoreSecretsTest` tests should still pass with the new return type.

**Effort:** Small
**Dependencies:** None
**Benefit:** Eliminates duplication and the type-unsafe `[String]` return type.

### Chunk 9: Make `SecretsStorageFile` Error Type Generic

**Branch:** `audit/chunk-09`

**Files to read first:**
- `Sources/xcodeinstall/Secrets/SecretsStorageFile.swift` — find where it throws `SecretsStorageAWSError.invalidOperation`
- `Sources/xcodeinstall/Secrets/SecretsStorageAWS.swift` — find the `SecretsStorageAWSError` enum definition
- `Sources/xcodeinstall/xcodeInstall/AuthenticateCommand.swift` — line 120 (catches `SecretsStorageAWSError.invalidOperation`)
- Grep for all references to `SecretsStorageAWSError` across Sources and Tests

**Step-by-step changes:**

1. **Create a generic error type** `SecretsStorageError` (or similar) with a case `invalidOperation` that both backends can use. Place it in a shared location (e.g., `SecretsHandler.swift` or a new section of `SecretsStorageFile.swift`).

2. **Update `SecretsStorageFile`** to throw the new generic error instead of `SecretsStorageAWSError.invalidOperation`.

3. **Update catch clauses** that currently catch `SecretsStorageAWSError.invalidOperation` (found in `AuthenticateCommand.swift:120` and potentially elsewhere) to catch the new generic error.

4. **Keep `SecretsStorageAWSError`** for AWS-specific errors that only the AWS backend throws. Only move the `invalidOperation` case to the generic type.

5. **Grep for all references** to ensure nothing is missed.

**Verification:** `swift build` then `swift test` — expect 115+ tests passing. The secrets handler tests should still pass since the behavior is unchanged.

**Effort:** Small
**Dependencies:** None
**Benefit:** Eliminates the misleading pattern where a file-based storage throws AWS-specific errors.

### Chunk 10: Improve Mock Quality — Fix `MockedAppleDownloader`

**Branch:** `audit/chunk-10`

**Files to read first:**
- `Tests/xcodeinstallTests/API/MockedNetworkClasses.swift` — find `MockedAppleDownloader` and its `list(force:)` method
- `Sources/xcodeinstall/API/List.swift` — the production `list(force:)` method that the mock reimplements
- `Tests/xcodeinstallTests/CLI/CLITests.swift` — find tests that use `MockedAppleDownloader`
- `Tests/xcodeinstallTests/API/DownloadTests.swift` — find tests that use `MockedAppleDownloader`

**Step-by-step changes:**

1. **Read `MockedAppleDownloader.list(force:)`** and compare to the production version. Identify what production logic is duplicated in the mock (error handling, caching, etc.).

2. **Simplify to a configurable stub** (Option A — preferred for this codebase's test style):
   - Add stored properties to `MockedAppleDownloader`: `var nextListResult: DownloadList?`, `var nextListError: Error?`, `var nextListSource: ListSource = .cache`
   - Replace the body of `list(force:)` with:
     ```swift
     if let error = nextListError { throw error }
     guard let list = nextListResult else { fatalError("MockedAppleDownloader.nextListResult not set") }
     return (list, nextListSource)
     ```

3. **Update all test files** that construct `MockedAppleDownloader` to set `nextListResult` with the appropriate test data. Read each test to understand what data it expects.

4. **Do the same for `download(file:)`** if it also duplicates production logic.

**Verification:** `swift build` then `swift test` — expect 115+ tests passing. Every test that uses the mock must still pass — if any fail, the mock's return data needs adjustment.

**Effort:** Medium
**Dependencies:** None
**Benefit:** Tests will verify production code behavior rather than mock behavior. Reduces maintenance burden when production error handling changes.

### Chunk 11: Add `DownloadDelegate` Tests

**Branch:** `audit/chunk-11`

**Files to read first:**
- `Sources/xcodeinstall/API/DownloadManager.swift` — the entire file, especially `DownloadDelegate` (line 149 onwards). Note: `DownloadDelegate` is `private` — you'll need to make it `internal` (or package-scoped) to test it, or test via the `DownloadManager.download()` public API.
- `Tests/xcodeinstallTests/API/DownloadTests.swift` — existing download tests, to match style
- `Tests/xcodeinstallTests/EnvironmentMock.swift` — mock patterns used in existing tests

**Step-by-step changes:**

1. **Decide the testing approach:**
   - **Option A (integration):** Test through `DownloadManager.download()` with a local HTTP server or mocked URL session. More realistic but heavier.
   - **Option B (unit — preferred):** Change `DownloadDelegate` from `private` to `internal` (remove the `private` keyword). Then test it directly by calling its delegate methods with constructed inputs.

2. **Add tests to the existing `DownloadTests.swift`** (or create `DownloadManagerTest.swift` if it's cleaner):
   - Test `didFinishDownloadingTo` with a real temp file — create a temp file, call the delegate method, verify the file was moved to the destination.
   - Test error page detection — create a small file containing `<Error>` or `AccessDenied`, call `didFinishDownloadingTo`, verify the continuation finishes with `DownloadError.authenticationRequired`.
   - Test file move failure — call `didFinishDownloadingTo` with a non-existent source path, verify the continuation finishes with an error.
   - Test `didCompleteWithError` with an error — verify the continuation finishes with that error.
   - Test `didCompleteWithError` with `nil` error — verify nothing happens (completion was already handled by `didFinishDownloadingTo`).

3. **Use Swift Testing framework** (`@Test`, `#expect`) consistent with the rest of the test suite.

**Verification:** `swift build` then `swift test` — expect 115+ tests passing plus the new tests. The new tests should cover the previously untested download delegate paths.

**Effort:** Medium
**Dependencies:** None
**Benefit:** The download delegate is a critical path with no test coverage. It handles file moves, error detection, and stream termination.

### Chunk 12: Static `DateFormatter` in `DownloadListParser`

**Branch:** `audit/chunk-12`

**Files to read first:**
- `Sources/xcodeinstall/xcodeInstall/DownloadListParser.swift` — lines 148-150 (`String.toDate()` extension that creates a new `DateFormatter` each call) and lines 61, 62, 118, 121 (call sites)

**Step-by-step changes:**

1. **Read `String.toDate()`** at line ~148. It creates a `DateFormatter` with a specific format on every invocation.

2. **Create a static `DateFormatter`** as a stored property. Two options:
   - **Option A (preferred):** Add a `private static let` property on the extension or in file scope:
     ```swift
     private let iso8601Formatter: DateFormatter = {
         let f = DateFormatter()
         f.dateFormat = "MM/dd/yy HH:mm"  // match the existing format
         return f
     }()
     ```
   - **Option B:** Use `nonisolated(unsafe) static let` if concurrency warnings arise.

3. **Update `toDate()`** to use the static formatter instead of creating a new one.

4. **Check the date format string** carefully — copy it exactly from the existing code.

**Verification:** `swift build` then `swift test` — expect 115+ tests passing. The `DownloadListParser Tests` suite exercises `toDate()` indirectly.

**Effort:** Small
**Dependencies:** None
**Benefit:** Minor performance improvement when processing large download lists.

### Chunk 13: Consistent Error Handling Strategy

**Branch:** `audit/chunk-13`

**Files to read first (read ALL command files to understand the current error handling pattern):**
- `Sources/xcodeinstall/xcodeInstall/AuthenticateCommand.swift` — `authenticate()` method catches and displays errors (the model to follow)
- `Sources/xcodeinstall/xcodeInstall/ListCommand.swift` — `list()` method, check if it catches or re-throws
- `Sources/xcodeinstall/xcodeInstall/DownloadCommand.swift` — `download()` method, check error handling
- `Sources/xcodeinstall/xcodeInstall/InstallCommand.swift` — `install()` method, check error handling
- `Sources/xcodeinstall/xcodeInstall/StoreSecretsCommand.swift` — `storeSecrets()` method, check error handling
- `Sources/xcodeinstall/CLI-driver/CLIAuthenticate.swift` — CLI-driver `run()`, check how it handles errors from the command layer
- `Sources/xcodeinstall/CLI-driver/CLIList.swift` — same
- `Sources/xcodeinstall/CLI-driver/CLIDownload.swift` — same
- `Sources/xcodeinstall/CLI-driver/CLIInstall.swift` — same
- `Sources/xcodeinstall/CLI-driver/CLIStoreSecrets.swift` — same

**Step-by-step changes:**

1. **Audit the current pattern:** Map out which commands catch-and-display vs. which re-throw. `AuthenticateCommand` is the reference — it catches specific errors and displays user-friendly messages.

2. **For commands that re-throw to the CLI-driver:** Move the error handling into the command-level method. Catch domain-specific errors (e.g., `DownloadError`, `CLIError`, `InstallerError`) and display formatted messages. Only re-throw truly unexpected errors.

3. **Simplify CLI-driver `run()` methods:** Once command-level methods handle their own errors, the CLI-driver should only need to call the command method and let unexpected errors propagate to ArgumentParser's default handler.

4. **Ensure consistent display style:** All user-facing errors should use `display(message, style: .error())`. Success messages should use `.success`. Security-related messages should use `.security`.

5. **Do not change the error types themselves** — only change where they are caught and displayed.

**Verification:** `swift build` then `swift test` — expect 115+ tests passing. Test the CLI manually with `swift run xcodeinstall --help` to ensure the tool still works.

**Effort:** Medium
**Dependencies:** None (but benefits from Chunk 5 being merged first, as `userCancelled` error handling ties in)
**Benefit:** Consistent UX — users always see formatted error messages rather than raw error dumps from ArgumentParser.

---

## Summary of Findings

**What's well-designed:**
- The overall layered architecture with clean unidirectional dependencies
- The DI approach via `AppDependencies` and the dual `run()`/`run(with:)` pattern
- The `SecretsStorageAWS` → `SecretsStorageAWSSDKProtocol` → `SecretsStorageAWSSoto` layering
- The `AuthenticationDelegate` protocol for decoupling MFA UI from auth logic
- The `DownloadManager`/`DownloadDelegate` implementation using modern structured concurrency
- The `SecretsHandlerTestsBase<T>` generic test pattern for testing multiple storage backends
- Swift 6.2 adoption with strict concurrency settings
- Good test coverage overall — most critical paths are tested

**What needs attention:**
- Dead code and unused protocols add cognitive overhead
- Force unwraps in several places create crash risks
- Inconsistent error handling strategy across commands
- `MockedAppleDownloader` duplicates production logic, weakening test reliability
- `exit(0)` calls bypass cleanup
- No bounds checking on user array selections
- Missing `@Test` attribute means one test never runs
