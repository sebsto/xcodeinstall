# App-Specific Passwords: Not Viable for Developer Portal Authentication

**Issue:** [#56](https://github.com/sebsto/xcodeinstall/issues/56)
**Status:** Won't fix — not possible due to Apple platform limitations

## Summary

App-specific passwords **cannot** be used to authenticate with Apple Developer Portal endpoints (`idmsa.apple.com/appleauth`). They are scoped exclusively to iCloud data access (mail, contacts, calendars stored in iCloud).

## Why It Doesn't Work

1. **Scope limitation**: Apple's documentation states app-specific passwords are for "third-party apps that need information like mail, contacts, and calendars that you store in iCloud." They do not grant access to developer services.

2. **2FA is mandatory**: App-specific passwords require 2FA as a prerequisite — they are not a 2FA bypass mechanism. All Apple developer accounts now require 2FA.

3. **SRP authentication requires the real password**: The `idmsa.apple.com/appleauth/auth/signin/init` endpoint uses Secure Remote Password protocol which requires the actual Apple ID password.

4. **Industry-wide limitation**: No tool in the ecosystem (fastlane/spaceship, xcodes, xcode-install) supports app-specific passwords for developer portal authentication.

## What About App Store Connect API Keys?

App Store Connect API Keys (`.p8` JWT-based auth) bypass 2FA entirely but **only cover App Store Connect endpoints** (builds, TestFlight, metadata). They do **not** cover `developer.apple.com/services-account/` download endpoints used by xcodeinstall.

## CI/Automation Strategies

| Approach | Viable? | Notes |
|----------|---------|-------|
| App-specific password | No | Scoped to iCloud only |
| App Store Connect API Key | No | Doesn't cover developer downloads |
| Session cookie persistence | **Yes** | Authenticate once with 2FA, reuse cookies for days/weeks |
| Pre-generated session (`spaceauth`-style) | **Yes** | Serialize validated session to env var for CI |

## Recommended Approach

**Session cookie persistence** is the only viable strategy for CI automation with xcodeinstall:

1. Authenticate interactively once (with 2FA)
2. Trust the session — Apple issues long-lived cookies
3. Persist and reuse those cookies until they expire (typically days to weeks)
4. Re-authenticate when the session expires

This is what xcodeinstall already implements. The fix in PR #133 ensures cookies from the trust step are properly saved, maximizing session lifetime.
