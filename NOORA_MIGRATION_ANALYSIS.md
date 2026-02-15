# Migration Analysis: Replace CLIlib with Noora + internalized CLI layer

## Goal

Remove the dependency on `CLIlib` (sebsto/CLIlib). Replace it with:
- **Noora** (tuist/Noora) for display and user input — isolated as an implementation detail
- **Internalized progress bar** code (copied from CLIlib) for progress bars — no Noora equivalent with matching API shape
- **Clean local protocols** owned by this project, so the business logic never imports Noora

The CLI-driver layer (ArgumentParser commands) and business logic layer (xcodeInstall/) stay structurally unchanged.

---

## What CLIlib provides today

All source lives in `.build/checkouts/CLIlib/Sources/CLIlib/`:

| CLIlib type | Used where | Migration target |
|-------------|-----------|-----------------|
| `DisplayProtocol` (protocol) | Everywhere via `deps.display` | New local protocol in `Sources/xcodeinstall/CLI/` |
| `Display` (struct) | `CLIMain.swift` instantiation | Replaced by `NooraDisplay` adapter |
| `ReadLineProtocol` (protocol) | Everywhere via `deps.readLine` | New local protocol in `Sources/xcodeinstall/CLI/` |
| `ReadLine` (struct) | `CLIMain.swift` instantiation | Replaced by `NooraReadLine` adapter |
| `ProgressUpdateProtocol` (protocol) | `CLIProgressBar`, `ShellInstaller`, mocks | Internalized into `Sources/xcodeinstall/CLI/` |
| `ProgressBarType` (enum) | `CLIProgressBar`, `DownloadCommand`, `InstallCommand` | Internalized into `Sources/xcodeinstall/CLI/` |
| `ProgressBar` (class) | `CLIProgressBar` | Internalized into `Sources/xcodeinstall/CLI/` |
| `OutputBuffer` (protocol + FileHandle ext) | `CLIProgressBar` | Internalized into `Sources/xcodeinstall/CLI/` |
| `DispatchSemaphoreProtocol` | `Sources/xcodeinstall/API/DispatchSemaphore.swift` (local copy already exists) | Already local, no action |

---

## New protocol design

The protocols can be cleaned up from the CLIlib legacy. Key changes:

### DisplayProtocol → add `style` parameter

```swift
enum DisplayStyle {
    case normal
    case success
    case error(nextSteps: [String] = [])
    case warning
    case info
}

protocol DisplayProtocol: Sendable {
    func display(_ msg: String, terminator: String, style: DisplayStyle)
}

// default arguments for backward compat — existing call sites compile unchanged
extension DisplayProtocol {
    func display(_ msg: String, terminator: String = "\n") {
        display(msg, terminator: terminator, style: .normal)
    }
    func display(_ msg: String, style: DisplayStyle) {
        display(msg, terminator: "\n", style: style)
    }
}
```

This lets call sites progressively migrate from emoji-prefixed strings to typed styles:
```swift
// before
display("✅ Authenticated.")
display("🛑 Session expired.")

// after
display("Authenticated.", style: .success)
display("Session expired.", style: .error(nextSteps: ["Run xcodeinstall authenticate"]))
```

### ReadLineProtocol → keep as-is, simplify

```swift
protocol ReadLineProtocol: Sendable {
    func readLine(prompt: String, silent: Bool) -> String?
}
```

No changes needed. The protocol is clean.

### ProgressUpdateProtocol + CLIProgressBarProtocol → keep as-is

```swift
protocol ProgressUpdateProtocol: Sendable {
    func update(step: Int, total: Int, text: String)
    func complete(success: Bool)
    func clear()
}

enum ProgressBarType {
    case percentProgressAnimation
    case countingProgressAnimation
    case countingProgressAnimationMultiLine
}

protocol CLIProgressBarProtocol: ProgressUpdateProtocol {
    func define(animationType: ProgressBarType, message: String)
}
```

No Noora involvement. The `ProgressBar` class, `OutputBuffer` protocol, and `FileHandle` extension are copied from CLIlib as-is.

---

## New directory structure

```
Sources/xcodeinstall/CLI/
├── Protocols.swift              # DisplayProtocol, DisplayStyle, ReadLineProtocol
├── ProgressBar.swift            # ProgressUpdateProtocol, ProgressBarType, CLIProgressBarProtocol,
│                                # ProgressBar, OutputBuffer, CLIProgressBar (moved from CLI-driver/)
├── NooraDisplay.swift           # DisplayProtocol impl backed by Noora (imports Noora)
└── NooraReadLine.swift          # ReadLineProtocol impl backed by Noora (imports Noora)
```

Only `NooraDisplay.swift` and `NooraReadLine.swift` import Noora. Everything else is pure Swift.

---

## Noora adapter implementations

### NooraDisplay

```swift
import Noora

final class NooraDisplay: DisplayProtocol {
    private let noora = Noora()

    func display(_ msg: String, terminator: String, style: DisplayStyle) {
        switch style {
        case .normal:
            print(msg, terminator: terminator)
        case .success:
            noora.success(.alert(msg))
        case .error(let nextSteps):
            if nextSteps.isEmpty {
                noora.error(.alert(msg))
            } else {
                noora.error(.alert(msg, nextSteps: nextSteps))
            }
        case .warning:
            noora.warning(.alert(msg))
        case .info:
            noora.info(.alert(msg))
        }
    }
}
```

### NooraReadLine

```swift
import Noora

final class NooraReadLine: ReadLineProtocol {
    private let noora = Noora()

    func readLine(prompt: String, silent: Bool) -> String? {
        if silent {
            // Noora doesn't support password/silent input — use getpass directly
            return String(cString: getpass(prompt))
        } else {
            // Use Noora's textPrompt for visible input
            return noora.textPrompt(title: nil, prompt: prompt)
        }
    }
}
```

Note: need to verify `noora.textPrompt()` exact API signature once integrated. If it doesn't fit the simple `String?` return, fall back to `print(prompt); return Swift.readLine()` and revisit later.

---

## Impact on existing files

### Business logic (xcodeInstall/) — NO changes to code

These files call `deps.display.display(...)`, `deps.readLine.readLine(...)`, `deps.progressBar.update(...)` through the protocols. They never import CLIlib or Noora. Just remove `import CLIlib`:

- `XcodeInstallCommand.swift`
- `AuthenticateCommand.swift`
- `DownloadCommand.swift`
- `ListCommand.swift`
- `InstallCommand.swift`
- `StoreSecretsCommand.swift`
- `SignOutCommand.swift`

### API layer — just remove `import CLIlib`

These files use `CLIProgressBarProtocol` and `FileHandlerProtocol` etc. which will be locally defined. Just remove the import:

- `Authentication.swift`, `Authentication+MFA.swift`, `Authentication+Hashcash.swift`, `Authentication+SRP.swift`
- `HTTPClient.swift`, `URLLogger.swift`
- `Download.swift`, `List.swift`
- `Install.swift`, `InstallXcode.swift`, `InstallCLTools.swift`, `InstallPkg.swift`

### Secrets layer — just remove `import CLIlib`

- `SecretsStorageAWS.swift`, `SecretsStorageAWS+Soto.swift`, `SecretsStorageFile.swift`

### Utilities — just remove `import CLIlib`

- `FileHandler.swift`

### CLI-driver layer — minor wiring changes

- `CLIMain.swift` — replace `Display()` → `NooraDisplay()`, `ReadLine()` → `NooraReadLine()`, remove `import CLIlib`
- `CLIAuthenticate.swift`, `CLIDownload.swift`, `CLIList.swift`, `CLIInstall.swift`, `CLIStoreSecrets.swift` — remove `import CLIlib`
- `CLIProgressBar.swift` — **move to `Sources/xcodeinstall/CLI/ProgressBar.swift`**, remove `import CLIlib`

### Environment.swift — remove `import CLIlib`, no structural changes

`AppDependencies` keeps the same fields. The protocols are now locally defined.

### Tests — just remove `import CLIlib`

- `MockedCLIClasses.swift` — `MockedDisplay`, `MockedReadLine` stay as-is
- `MockedUtilitiesClasses.swift` — `MockedProgressBar` stays as-is (update `CLIlib.ProgressBarType` → `ProgressBarType`)
- `EnvironmentMock.swift`, `MockedNetworkClasses.swift`, `InstallTest.swift`, etc. — remove import

---

## Package.swift changes

```swift
// REMOVE:
.package(url: "https://github.com/sebsto/CLIlib/", branch: "main"),

// ADD:
.package(url: "https://github.com/tuist/Noora", .upToNextMajor(from: "0.15.0")),

// In target dependencies:
// REMOVE:
.product(name: "CLIlib", package: "CLIlib"),
// ADD:
.product(name: "Noora", package: "Noora"),
```

---

## Migration steps

1. Create `Sources/xcodeinstall/CLI/` directory
2. Create `Protocols.swift` — define `DisplayStyle`, `DisplayProtocol`, `ReadLineProtocol` with default argument extensions
3. Create `ProgressBar.swift` — internalize `ProgressUpdateProtocol`, `ProgressBarType`, `ProgressBar`, `OutputBuffer`, `CLIProgressBarProtocol`, and move `CLIProgressBar` class here
4. Create `NooraDisplay.swift` — Noora-backed `DisplayProtocol` implementation
5. Create `NooraReadLine.swift` — Noora-backed `ReadLineProtocol` implementation
6. Update `Package.swift` — add Noora, remove CLIlib
7. Remove `import CLIlib` from all source and test files
8. Update `CLIMain.swift` — instantiate `NooraDisplay()` and `NooraReadLine()` 
9. Delete `Sources/xcodeinstall/CLI-driver/CLIProgressBar.swift` (moved to CLI/)
10. Verify tests pass — mocks unchanged, protocols preserved

---

## What stays unchanged

- ArgumentParser command structure (all CLI-driver files)
- All business logic in `xcodeInstall/`
- All API layer code
- All test mocks (just remove `import CLIlib`)
- Progress bar UX (internalized, not Noora)
