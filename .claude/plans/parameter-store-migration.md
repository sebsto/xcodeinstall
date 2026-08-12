# Plan: Migrate secrets backend from AWS Secrets Manager to SSM Parameter Store

Status: proposed (not implemented)
Date: 2026-08-12

## Context

`xcodeinstall` stores two secrets in AWS Secrets Manager when run with `-s <region>`:

| Secret name | Content |
|---|---|
| `xcodeinstall-apple-credentials` | `AppleCredentialsSecret` JSON (Apple ID username + password) |
| `xcodeinstall-apple-session-token` | `AppleSessionSecret` JSON (raw `Set-Cookie` strings + `AppleSession`) |

Secrets Manager bills $0.40 per secret per month plus $0.05 per 10,000 API calls, so ~$0.80/month per region for two secrets that are read a handful of times. SSM Parameter Store stores standard-tier parameters at no charge, and standard-throughput API interactions are free. See [Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/) and [Systems Manager pricing](https://aws.amazon.com/systems-manager/pricing/). (Pricing details rephrased for compliance with licensing restrictions.)

The tool only ever uses three Secrets Manager operations — `CreateSecret`, `PutSecretValue`, `GetSecretValue` — with no rotation, no cross-account resource policies, and no automatic versioning requirements. Nothing in that usage needs Secrets Manager.

## Measured secret sizes (real account, profile `pro`, us-east-1, 2026-08-12)

This matters because standard-tier Parameter Store caps a value at 4 KB (4096 bytes) where Secrets Manager allows 64 KB.

```
xcodeinstall-apple-credentials      73 bytes
xcodeinstall-apple-session-token  2282 bytes   immediately after `authenticate`  (3 cookies)
                                  2808 bytes   after a later `download`          (5 cookies)
```

Both session figures are real observations, not estimates: 2282 bytes was measured on a freshly written session right after a live `authenticate`, and 2808 bytes is a retained earlier version of the same secret that had accumulated the download-flow cookies.

Breakdown of the fresh 2282-byte session:

| Component | Bytes |
|---|---|
| `rawCookies` (3 cookies) | 1301 |
| `session` object | 947 |
| — `scnt` | 446 |
| — `xAppleIdSessionId` | 240 |
| — `itcServiceKey` | 138 |
| — `hashcash` | 58 |

Cookies after `authenticate`: `myacinfo` 1149, `dslang` 76, `site` 72.
Cookies added later by the download flow: `ADCDownloadAuth` 384, `DSESSIONID` 137 — which is exactly the 526-byte gap between the two versions.

### Interpretation

Peak observed size is 2808 bytes, or 69% of the 4096-byte standard-tier limit, leaving 1288 bytes of headroom. Standard tier would very likely work in practice. Three things keep it from being a safe assumption:

1. **The MFA path is still unmeasured.** No observed session contains the `aasp` cookie that `idmsa.apple.com` sets during two-factor authentication. It appears in the `AuthenticationTests` and `SecretsHandlerTests` fixtures, and `SecretsHandlerTests.swift:127` asserts it survives the save/load round-trip, so it is retained when present — this account simply did not take that path. Real `aasp` values run several hundred bytes to ~1 KB, which would put an MFA-derived session at roughly 3.3–3.8 KB.
2. **`mergeCookies` grows monotonically.** `SecretsHandlerProtocol.mergeCookies` replaces same-name cookies and appends new ones but never prunes expired entries. The 2282 → 2808 jump is that mechanism working as designed; any future Apple endpoint that sets a new cookie name enlarges the stored value permanently.
3. **`myacinfo` and `scnt` are variable-length tokens.** `myacinfo` is 1149 bytes here and is not fixed.

Conclusion: standard tier is a 30%-margin bet against an unmeasured MFA path and an append-only cookie jar. **Use `Tier: Intelligent-Tiering`.** AWS creates the parameter as standard (free) and only promotes it to advanced (8 KB limit, $0.05/parameter/month) if the value crosses 4 KB. Worst realistic case is $0.05/month for one parameter, still 8x cheaper than the $0.40 Secrets Manager charge, and it never hard-fails.

Caveat to document: promotion to the advanced tier is one-way. An advanced parameter cannot be reverted to standard.

## Design decisions

### `PutParameter(Overwrite: true)` replaces the create-then-retry machinery

`PutSecretValue` fails when the secret does not exist, which is why the current code carries `createSecret` and `executeRequestAndCreateWhenNotExist` — it catches `resourceNotFoundException`, creates the secret, and recurses up to `maxRetries` times. `PutParameter` with `Overwrite: true` is a single upsert, so all of that (~70 lines) is deleted.

Note what that machinery was implicitly doing: `authenticate` calls `clearSecrets()` first (`AuthenticateCommand.swift:199`), and that call is what created the session secret before `saveCookies` tried to read it. With an upsert, that ordering dependency disappears.

### `SecureString` with the default `aws/ssm` KMS key

Free and AWS-managed. Per the [SSM KMS documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/secure-string-parameter-kms-encryption.html), access-control policies cannot be attached to the default `aws/ssm` key and all principals in the account can use it, so no `kms:*` actions are needed in the IAM policy. **Verify empirically** before finalising the README — the same page requires `kms:Encrypt`/`kms:Decrypt` for customer-managed keys, and the README should mention that for users who want their own key.

### Parameter naming: hierarchy

Move to `/xcodeinstall/apple-credentials` and `/xcodeinstall/apple-session-token`, giving a clean IAM resource of `parameter/xcodeinstall/*`. This touches `AWSSecretsName` in `SecretsStorageAWS.swift`.

Alternative if you want a tighter diff: keep the flat `xcodeinstall-apple-credentials` names (Parameter Store permits `a-zA-Z0-9_.-` with no leading slash) and use `parameter/xcodeinstall-*` as the IAM resource. Either way existing users must re-enter their secrets, so the hierarchy costs nothing extra.

### CLI surface stays as-is

`-s/--secretmanager-region` and the `secretManagerRegion` key in `~/.xcodeinstall/config.json` keep their names. Renaming the flag is a breaking CLI change; renaming the config key silently discards every user's saved region and profile. Only the help text changes.

Optional, separable: add `--region` as an additional alias in `CLIMain.swift` and `CLIStoreSecrets.swift` (ArgumentParser accepts multiple `name:` entries).

## Verified Soto API facts

Checked against `.build/checkouts/soto`:

- `SotoSSM` is a published product (`soto/Package.swift:375`).
- `SSM.PutParameterRequest(description:name:overwrite:tier:type:value:)` — `SSM_shapes.swift:12475`.
- `SSM.ParameterTier.intelligentTiering` — `SSM_shapes.swift:677`.
- `SSM.ParameterType.secureString` — `SSM_shapes.swift:683`.
- `SSM.GetParameterRequest(name:withDecryption:)`, result is `GetParameterResult.parameter?.value` — `SSM_shapes.swift:7774`.
- `SSMErrorType.parameterNotFound` (`SSM_shapes.swift:16378`) with `==` defined at `SSM_shapes.swift:16472`, matching the existing `SecretsManagerErrorType` comparison style.
- `PutParameter` returns `version: Int64?` (replaces the `versionId`/`name` logging).
- `Tags` and `Overwrite` are mutually exclusive on `PutParameter`, so no tagging — which also retires the speculative `secretsmanager:TagResource` note.

## Implementation Steps

### 1. Swap the Soto product

**Modify:** `Package.swift`

`.product(name: "SotoSecretsManager", package: "soto")` → `.product(name: "SotoSSM", package: "soto")`

### 2. Rewrite the SDK wrapper

**Modify:** `Sources/xcodeinstall/Secrets/SecretsStorageAWS+Soto.swift`

- `import SotoSecretsManager` → `import SotoSSM`
- Rename `smClient: SecretsManager?` → `ssmClient: SSM?` across the stored property, the private `init`, and both `forRegion` overloads
- Delete `createSecret`, `executeRequestAndCreateWhenNotExist`, and `maxRetries`
- Keep unchanged: `wrapCredentialError`, `shutdown`/`isShutdown`/`deinit`, the credential-provider selector chain, and `Region(awsRegionName:)` validation. None of it is service-specific.

```swift
func updateSecret<T: Secrets>(secretId: AWSSecretsName, newValue: T) async throws {
    do {
        guard let value = try newValue.string() else {
            throw SecretsStorageAWSError.invalidSecretValue(secretname: secretId.rawValue)
        }
        let request = SSM.PutParameterRequest(
            description: "xcodeinstall secret",
            name: secretId.rawValue,
            overwrite: true,
            tier: .intelligentTiering,
            type: .secureString,
            value: value
        )
        log.debug("Updating parameter \(secretId.rawValue)")
        let response = try await ssmClient?.putParameter(request)
        log.debug("\(secretId.rawValue) now at version \(response?.version ?? 0)")
    } catch {
        log.debug("Unexpected error while updating secrets\n\(error)")
        throw wrapCredentialError(error)
    }
}
```

```swift
func retrieveSecret<T: Secrets>(secretId: AWSSecretsName) async throws -> T {
    do {
        let request = SSM.GetParameterRequest(name: secretId.rawValue, withDecryption: true)
        log.debug("Retrieving parameter \(secretId.rawValue)")
        let response = try await ssmClient?.getParameter(request)

        guard let secret = response?.parameter?.value else {
            // unchanged empty-secret fallback
        }
        // unchanged switch on secretId
    } catch let error as SSMErrorType where error == .parameterNotFound {
        log.debug("Parameter \(secretId.rawValue) does not exist in AWS Parameter Store")
        throw error
    } catch {
        log.debug("Unexpected error while retrieving secrets\n\(error)")
        throw wrapCredentialError(error)
    }
}
```

`SecretsStorageAWSError` needs a new `invalidSecretValue(secretname:)` case (or reuse `secretDoesNotExist`) since the guard replaces a previously implicit optional unwrap.

### 3. Fix the concrete error type in the authenticate flow

**Modify:** `Sources/xcodeinstall/xcodeInstall/AuthenticateCommand.swift`

This will not compile otherwise. Line 8 imports `SotoSecretsManager` solely so line ~125 can catch `SecretsManagerErrorType == .resourceNotFoundException` and transparently prompt for credentials when the secret is absent.

- `import SotoSecretsManager` → `import SotoSSM`
- `catch let error as SotoSecretsManager.SecretsManagerErrorType where error == .resourceNotFoundException` → `catch let error as SSMErrorType where error == .parameterNotFound`
- Reword the four user-facing "AWS Secrets Manager" strings

No other call site depends on the concrete error type: `HTTPClient.swift:84,107` and `DownloadManager.swift:61` all call `loadSession`/`loadCookies` with `try?`.

### 4. Update names and stale comments

**Modify:** `Sources/xcodeinstall/Secrets/SecretsStorageAWS.swift`

- `AWSSecretsName` raw values → `/xcodeinstall/apple-credentials`, `/xcodeinstall/apple-session-token`
- Permission comment (lines 71–74) → `ssm:PutParameter`, `ssm:GetParameter`
- Comment at lines 100–102 references the Secrets Manager 30-day deletion policy as the reason `clearSecrets` writes an empty session instead of deleting. Parameter Store deletes immediately, but keep the current behaviour anyway: writing an empty session avoids needing `ssm:DeleteParameter`. Reword the comment to say that.

### 5. Update the IAM policy file

**Modify:** `iam/ec2-policy.json`

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "xcodeinstall",
            "Effect": "Allow",
            "Action": [
                "ssm:PutParameter",
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:*:000000000000:parameter/xcodeinstall/*"
        }
    ]
}
```

### 6. Update the tests

**Modify:** `Tests/xcodeinstallTests/Secrets/AWSSecretsHandlerSotoTest.swift`

Replace the injected `SecretsManager(client:endpoint:)` with `SSM(client:endpoint:)` passed as `ssmClient:`, and swap the import. Localstack supports Parameter Store, so `SotoTestEnvironment` needs no change. The three region-validation tests need no logic change.

`Tests/xcodeinstallTests/Secrets/MockedSecretsHandler.swift` mocks `SecretsStorageAWSSDKProtocol`, whose signature is unchanged — no edit needed.

### 7. Update the README

**Modify:** `README.md`

IAM content appears twice and both copies need the policy from step 5:
- ~line 450: section heading, ~452 intro, ~455 the policy JSON
- ~line 502: prose, ~505 the same policy inside the `cat << EOF > ec2-policy.json` heredoc
- ~line 474: prose describing what the role grants

Then the ~30 "AWS Secrets Manager" mentions: line 11 tagline, 23, 28, 54, 56, 58 (motivation section), 139, 162, 169, 208–209/286–287/327–328 (repeated `-s` flag help text), 217, 235, 237, 255, 257, 261, 268.

Add a migration note: nothing carries over from Secrets Manager, so existing users must re-run `storesecrets` and `authenticate`, and should delete the old secrets (`aws secretsmanager delete-secret --secret-id xcodeinstall-apple-credentials`) or keep paying $0.40/month each. Mention the Intelligent-Tiering behaviour and the one-way advanced-tier promotion.

### 8. Optional cleanup

`scripts/e2e-test.sh` lines 10 and 61 — comment and output strings only, no functional impact.

## Verification

1. `swift build` — catches the `SotoSSM` swap and the `AuthenticateCommand` error-type change.
2. `swift test` — the Soto suite plus the mocked handler suite.
3. Manual against the real account with profile `pro`: `storesecrets`, then `authenticate` through a full MFA flow, then `list` and `download` to confirm the session round-trips.
4. After the MFA round-trip, re-measure the stored value and record whether Intelligent-Tiering promoted it:
   ```
   aws ssm get-parameter --profile pro --name /xcodeinstall/apple-session-token \
       --with-decryption --query 'Parameter.Value' --output text | wc -c
   aws ssm describe-parameters --profile pro \
       --parameter-filters "Key=Name,Values=/xcodeinstall/" --query 'Parameters[].[Name,Tier]'
   ```
   The one gap in the current measurements is a session captured through an actual two-factor prompt, which is the only path that yields an `aasp` cookie. Force that path (fresh machine or cleared trust token) and measure it. If even that stays comfortably under 4096 bytes, pinning `.standard` becomes defensible; if Intelligent-Tiering promotes the parameter to advanced, say so in the README.
5. Confirm the IAM policy is sufficient with no `kms:*` actions, using a least-privilege role rather than the admin profile.

## Files touched

| File | Size of change |
|---|---|
| `Package.swift` | 1 line |
| `Sources/xcodeinstall/Secrets/SecretsStorageAWS+Soto.swift` | rewrite, net ~70 lines smaller |
| `Sources/xcodeinstall/xcodeInstall/AuthenticateCommand.swift` | import + 1 catch clause + 4 strings |
| `Sources/xcodeinstall/Secrets/SecretsStorageAWS.swift` | 2 raw values + comments |
| `Sources/xcodeinstall/Secrets/SecretsStorageAWSError.swift` | 1 new case |
| `iam/ec2-policy.json` | 2 actions + resource ARN |
| `Tests/xcodeinstallTests/Secrets/AWSSecretsHandlerSotoTest.swift` | client injection |
| `README.md` | 2 policy blocks + ~30 prose mentions + migration note |

`Tests/coverage.html` and `Tests/coverage.json` also contain matches but are generated artifacts.

## Open questions

1. Hierarchical `/xcodeinstall/*` names or keep the existing flat names?
2. Should `retrieveSecret` swallow `parameterNotFound` for `.appleSessionToken` and return an empty `AppleSessionSecret`? `SecretsStorageAWS.saveCookies` currently reads the session parameter and rethrows on failure, which is only safe because `clearSecrets()` runs first. Swallowing it for the session token (while still throwing for `.appleCredentials`, which `AuthenticateCommand` relies on) would remove that ordering dependency. Optional hardening; widens the diff.
3. Add `--region` as an alias for `-s/--secretmanager-region` now, or leave for a separate change?
