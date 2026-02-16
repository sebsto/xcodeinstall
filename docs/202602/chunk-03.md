# Chunk 03: Eliminate Duplicate `request()` Method

## Files Changed

- **Modified:** `Sources/xcodeinstall/API/HTTPClient.swift`
  - Extracted the body of `HTTPClient.request(for:method:withBody:withHeaders:)` into a new package-internal free function `buildURLRequest(for:method:withBody:withHeaders:)`, placed below the `HTTPClient` class.
  - `HTTPClient.request()` now delegates to `buildURLRequest()`.

- **Modified:** `Sources/xcodeinstall/API/DownloadManager.swift`
  - Replaced the duplicated body of `DownloadManager.request(for:method:withBody:withHeaders:)` with a single-line delegation to the shared `buildURLRequest()` function.

## Changes Made

The `request()` method was identically duplicated between `HTTPClient` (lines 166-193) and `DownloadManager` (lines 110-132). Both methods had the same signature, same logic (URL construction, HTTP method, body, headers), and same force unwrap on `URL(string:)`.

The fix introduces a single shared free function `buildURLRequest()` at package-internal scope in `HTTPClient.swift`. Both `HTTPClient.request()` and `DownloadManager.request()` now delegate to it. The method signatures on both types are preserved so all existing call sites (production and test) continue to work without modification.

## Build Result

`swift build` passed with zero errors.

## Test Result

`swift test` passed: 116 tests in 14 suites, all passing.

## Issues Encountered

None.

## Deviations from Plan

The plan offered two options: (A) a shared helper function, or (B) inlining the URL request construction in `DownloadManager.download()`. Option A was chosen as recommended. The plan suggested both `HTTPClient` and `DownloadManager` could call the shared function, which is exactly what was implemented. Both types retain their `request()` methods as thin wrappers so that existing test code calling `dm.request()` and `client.request()` continues to work without changes.
