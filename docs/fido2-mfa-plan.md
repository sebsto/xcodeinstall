# FIDO2 / Physical Security Key MFA: Implementation Plan

**Issue:** [#138](https://github.com/sebsto/xcodeinstall/issues/138)
**Status:** Analyzed — not implemented. This document is a roadmap for a future contributor with a YubiKey and time to develop and test the feature.

## Summary

When an Apple ID has only FIDO2 security keys (e.g. YubiKey) registered as the second factor, `xcodeinstall authenticate` currently fails with a misleading "no verification methods are available" error. Apple's `/appleauth/auth` endpoint returns an `fsaChallenge` payload that xcodeinstall does not understand. The browser flow at `developer.apple.com` works (Apple uses standard W3C WebAuthn / CTAP2), so the gap is purely client-side.

Implementing this is a significant new feature. Fastlane's `spaceship` does not implement it either, so there is no existing reference to port. The maintainer does not currently own a YubiKey to test against and does not have time to develop and validate this end-to-end. This document captures everything a contributor needs to pick the work up.

## Why this is non-trivial

1. **No reference implementation.** A full-repo search of `fastlane/fastlane` for `fsaChallenge`, `FIDO`, `webauthn`, `keyHandle`, `rpId`, `allowedCredentials`, `passkey`, `security_key` returns zero matches. The dispatcher in `spaceship/lib/spaceship/two_step_or_factor_client.rb` only handles `trustedDevices` (HSA) and `trustedPhoneNumbers` (HSA2); anything else hits a generic raise.

2. **Apple's FIDO2 endpoint is undocumented.** The exact URL and payload shape for submitting the WebAuthn assertion back to `idmsa.apple.com` is not published anywhere we found. A contributor must capture it from a real browser session before any Swift code can be written (see Step 2 below).

3. **Apple's `AuthenticationServices` framework is unsuitable for a CLI.** `ASAuthorizationSecurityKeyPublicKeyCredentialProvider` requires a GUI presentation anchor, an active app event loop, and Associated Domains matching the relying party (`apple.com`) — none of which work from a CLI binary signing in to Apple's portal. So we have to talk to the security key ourselves.

## What the response actually looks like

When `signin/complete` returns 409, a follow-up `GET /appleauth/auth` returns:

```json
{
  "cancelled": false,
  "accountName": "<apple_id>",
  "keyNames": ["FIDO2 - Key 1", "FIDO2 - Key 2"],
  "requirePrf": false,
  "passkeyAutofill": false,
  "fsaChallenge": {
    "challenge": "<base64url challenge>",
    "keyHandles": ["<base64url credentialId 1>", "<base64url credentialId 2>"],
    "rpId": "apple.com",
    "allowedCredentials": "<credentialId 1>,<credentialId 2>"
  }
}
```

This is essentially a WebAuthn `PublicKeyCredentialRequestOptions`. The browser feeds it to the platform's WebAuthn API, the YubiKey signs the challenge after a touch, and the browser POSTs the assertion (`clientDataJSON`, `authenticatorData`, `signature`, `userHandle`, `credentialId`) back to Apple.

## Implementation roadmap

### 1. Recognize the FSA flow

**File:** `Sources/xcodeinstall/API/Authentication+MFA.swift`

Extend `MFAType` so the existing `getMFAType()` (which already runs against `https://idmsa.apple.com/appleauth/auth`) decodes the FSA shape too. All new fields must be optional so the existing trusted-device / SMS responses still decode cleanly:

```swift
struct FSAChallenge: Codable {
    let challenge: String
    let keyHandles: [String]
    let rpId: String
    let allowedCredentials: String
}

struct MFAType: Codable {
    // … existing fields …
    let keyNames: [String]?
    let fsaChallenge: FSAChallenge?
    let requirePrf: Bool?
    let passkeyAutofill: Bool?
}
```

In `buildMFAOptions(from:)` emit a new option `.securityKey(challenge:, keyNames:)` when `fsaChallenge` is present.

**File:** `Sources/xcodeinstall/API/Authentication.swift`

Add the case to `enum MFAOption` (currently lines 132–135) and a dispatch branch in `performMFA` (currently lines 189–214) that calls a new `verifySecurityKey(challenge:)` method.

### 2. Capture the verification endpoint (hard prerequisite)

Before writing any Swift, capture what `developer.apple.com` posts after the user's browser has driven the YubiKey:

1. Sign in to `developer.apple.com` in Safari with a security-key-only account.
2. Open Web Inspector → Network, or run `mitmproxy` between the browser and `*.apple.com`.
3. Record the request that follows the local key touch. Expected:
   - URL: likely `https://idmsa.apple.com/appleauth/auth/verify/security/key` or similar.
   - Method: probably `POST`.
   - Headers: `X-Apple-Id-Session-Id`, `scnt`, `X-Apple-Widget-Key`, `Content-Type: application/json`.
   - Body: base64url-encoded `clientDataJSON`, `authenticatorData`, `signature`, `userHandle`, `credentialId`.
4. Note the response shape and any `Set-Cookie` headers. The trust step that follows (`/appleauth/auth/2sv/trust`) is already handled in `trustSession()` and should not need changes.

Without this capture, every payload field is a guess.

### 3. Drive the security key from Swift — keep two options open

Both options below produce identical on-the-wire output. The choice is a code-volume vs. install-burden tradeoff. Pick during implementation based on testing experience.

#### Option A — Bridge to Yubico's `libfido2`

- BSD-licensed C library, available via `brew install libfido2`.
- Add a system-library target in `Package.swift` exposing the C headers, then a thin Swift wrapper that calls `fido_dev_open`, `fido_assert_new`, `fido_assert_set_clientdata_hash`, `fido_assert_set_rp`, `fido_assert_allow_cred`, `fido_dev_get_assert`, and reads out `fido_assert_authdata_ptr`, `fido_assert_sig_ptr`, `fido_assert_user_id_ptr`.
- ~150–300 lines of Swift glue.
- Pros: mature, used by every other CLI security-key tool.
- Cons: users must `brew install libfido2`. Document this in `README.md`.

#### Option B — Pure-Swift CTAP2 over USB-HID via `IOHIDManager`

- Open the FIDO HID device (`usagePage 0xF1D0`, `usage 0x0001`) using `IOHIDManager`.
- Implement CTAP-HID framing (init, channel ID, fragmentation) and CTAP2 `authenticatorGetAssertion` (CBOR-encoded request, CBOR-decoded response).
- ~800–1200 lines plus CBOR codec (or pull in a `swift-cbor`-style dependency).
- Pros: zero install-time burden, single binary.
- Cons: substantial code surface and maintenance burden.

#### Decision criteria

- Prefer minimal code, accept a `brew` prerequisite → **Option A**.
- Want `xcodeinstall` to remain a single binary with no native deps → **Option B**.

#### Option C — `AuthenticationServices` (rejected)

`ASAuthorizationSecurityKeyPublicKeyCredentialProvider` is the right answer for GUI apps but not for a CLI: it requires a presentation anchor (`NSWindow`/`UIWindow`), an active app event loop, and Associated Domains matching `apple.com`. Don't go down this path.

### 4. Assemble and send the WebAuthn assertion

Regardless of which backend produces `authenticatorData` + `signature`:

1. Build `clientDataJSON`:
   ```json
   {"type":"webauthn.get","challenge":"<fsaChallenge.challenge>","origin":"https://idmsa.apple.com","crossOrigin":false}
   ```
   SHA-256 it to get `clientDataHash` — this is what the key actually signs.
2. For each `keyHandle` in `fsaChallenge.keyHandles`, base64url-decode and pass as an allowed credential to the key. The key returns the credentialId of the one it actually used.
3. POST the assertion to the endpoint captured in Step 2, with `X-Apple-Id-Session-Id` and `scnt` headers. Body: base64url-encoded `clientDataJSON`, `authenticatorData`, `signature`, `userHandle`, `credentialId`.
4. On 200/204, call the existing `trustSession()` (`Authentication+MFA.swift:307`) — the trust step is identical to the HSA2 path.
5. Map errors:
   - 400 → `AuthenticationError.invalidPinCode` (semantically: bad assertion).
   - 412 → `AuthenticationError.accountNeedsRepair`.
   - Other → `AuthenticationError.unexpectedHTTPReturnCode`.
   - Consider adding `AuthenticationError.securityKeyDeclined` / `securityKeyTimeout` for local key-side failures (user didn't touch the key, no key plugged in, etc.).

### 5. CLI delegate UX

**File:** `Sources/xcodeinstall/xcodeInstall/AuthenticateCommand.swift`

Update `CLIAuthenticationDelegate.requestMFACode(options:)` (currently line 26) to handle `.securityKey`:

- In the multi-option menu, render: `"  N. Security key (\(keyNames.joined(separator: \", \")))"`.
- When chosen, do not prompt for a code; print `"Touch your security key now…"` and return `(option, "")`. The authenticator's `verifySecurityKey` does the actual I/O — the existing `(option: MFAOption, code: String)` return type accommodates this since `code` is unused in the security-key branch.

### 6. Tests

Mirror the existing MFA test patterns under `Tests/xcodeinstallTests/`.

- Decoder test: feed the redacted JSON from issue #138 into `JSONDecoder().decode(MFAType.self, …)` and assert `fsaChallenge` is populated.
- Option-builder test: assert `buildMFAOptions` returns `.securityKey` when only `fsaChallenge` is present, and still returns the existing options when the response is HSA2-shaped.
- Mock the assertion-producer (a `SecurityKeyAssertionProducing` protocol) so neither libfido2 nor `IOHIDManager` is exercised in CI. Verify the POST body shape against the captured-from-browser reference.
- A real end-to-end test that drives a YubiKey is not feasible in CI — document it as a manual verification step.

## Critical files

| File | Why it matters |
|---|---|
| `Sources/xcodeinstall/API/Authentication+MFA.swift` | `MFAType`, `getMFAType`, `buildMFAOptions`, `trustSession` |
| `Sources/xcodeinstall/API/Authentication.swift` | `enum MFAOption` (line 132) and `performMFA` (line 189) |
| `Sources/xcodeinstall/xcodeInstall/AuthenticateCommand.swift` | `CLIAuthenticationDelegate.requestMFACode` (line 26) |
| `Package.swift` | System-library target for `libfido2` (Option A) |
| `docs/app-specific-passwords-analysis.md` | Style/structure reference for this kind of analysis doc |

## Manual verification (when implemented)

1. Account with only FIDO2 keys registered → `swift run xcodeinstall authenticate --verbose` → expect a "Touch your security key now…" prompt → key blinks → `Authenticated.` Subsequent `xcodeinstall list` / `download` succeed against the persisted session.
2. Regression: account with trusted phone numbers only → existing SMS / trusted-device flow unchanged.
3. Account with both → menu shows all options; each works independently.

## Workaround for users today

If your Apple ID has only security keys registered, register a trusted phone number or a trusted Apple device on your account so the existing SMS / trusted-device flow can be used. App-specific passwords and App Store Connect API keys are not viable substitutes for developer-portal authentication — see `docs/app-specific-passwords-analysis.md`.
