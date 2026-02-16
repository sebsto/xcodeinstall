# Chunk 10: Improve Mock Quality -- Fix `MockedAppleDownloader`

## Files changed

- `Tests/xcodeinstallTests/API/MockedNetworkClasses.swift` -- modified -- replaced `MockedAppleDownloader.list(force:)` production logic duplication with configurable stub properties (`nextListResult`, `nextListError`, `nextListSource`); removed `urlSession` and `secrets` stored properties
- `Tests/xcodeinstallTests/EnvironmentMock.swift` -- modified -- changed `MockedEnvironment.downloader` from a computed property (creating a new mock each time) to a stored `var` of type `MockedAppleDownloader`
- `Tests/xcodeinstallTests/API/ListTest.swift` -- modified -- updated all 7 `force: true` test cases to configure the mock directly via `nextListResult`/`nextListError`/`nextListSource` instead of wiring up `MockedURLSession` data; removed now-unused `prepareResponse` helper method
- `Tests/xcodeinstallTests/API/DownloadTests.swift` -- modified -- removed now-unused `setSessionData` helper method

## Changes made

1. Replaced the ~55-line `MockedAppleDownloader.list(force:)` method that duplicated production error handling logic (status code checking, cookie validation, JSON decoding, resultCode switching) with a simple configurable stub: if `nextListError` is set, throw it; if `nextListResult` is set, return it with `nextListSource`; otherwise fall through to loading test data from disk (preserving default cache behavior for tests that don't configure the mock).
2. Removed `urlSession` and `secrets` stored properties from `MockedAppleDownloader` since the simplified mock no longer needs them.
3. Changed `MockedEnvironment.downloader` from a computed property to a stored `var` typed as `MockedAppleDownloader`, allowing tests to configure the mock's properties before use.
4. Updated `testListForce` to load test data, decode it, and set it as `nextListResult` with `nextListSource = .network`.
5. Updated `testListForceParsingError`, `testListForceAuthenticationError`, `testListForceUnknownError`, `testListForceNon200Code`, `testListForceNoCookies`, and `testAccountNeedsUpgrade` to set `nextListError` directly with the expected error.
6. Removed `prepareResponse` from `ListTest.swift` and `setSessionData` from `DownloadTests.swift` as they became dead code after the mock simplification.
7. Left the `download(file:)` method unchanged -- it already uses a simple `MockDownloadManager` stub without duplicating production logic.

## Build result

- `swift build`: PASS

## Test result

- `swift test`: PASS -- 116 tests in 14 suites

## Issues encountered

- None

## Deviations from plan

- The plan suggested using `fatalError("MockedAppleDownloader.nextListResult not set")` when `nextListResult` is nil. Instead, a default fallback was implemented that loads from test data (same as the original `force: false` path). This preserves backward compatibility with existing tests that rely on the default cache behavior without explicitly setting `nextListResult` (e.g., `testListNoForce`, CLI list/download tests).
- The plan mentioned also simplifying `download(file:)` "if it also duplicates production logic." It does not -- it already delegates to `MockDownloadManager` which is a simple stub -- so it was left unchanged.
- Removed `prepareResponse` and `setSessionData` helper methods that became dead code as a direct result of the mock simplification, even though the plan did not explicitly mention removing them.
