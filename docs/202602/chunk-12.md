# Chunk 12: Static `DateFormatter` in `DownloadListParser`

## Files changed

- `Sources/xcodeinstall/xcodeInstall/DownloadListParser.swift` -- modified -- Replaced per-call `DateFormatter` creation in `String.toDate()` with a file-scope static constant

## Changes made

1. Added a `private let appleDownloadDateFormatter` at file scope, initialized via a closure that configures the `DateFormatter` with locale `"en_US_POSIX"` and date format `"MM-dd-yy HH:mm"` (matching the original format exactly).
2. Simplified `String.toDate()` to use the static formatter instead of creating a new `DateFormatter` on every invocation.

## Build result

- `swift build`: PASS

## Test result

- `swift test`: PASS -- 123 tests in 15 suites

## Issues encountered

- None

## Deviations from plan

- The audit plan suggested the date format might be `"MM/dd/yy HH:mm"`, but the actual format in the code is `"MM-dd-yy HH:mm"` (dashes, not slashes). The actual format was preserved exactly.
