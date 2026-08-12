# Plan: Migrate secrets backend from AWS Secrets Manager to SSM Parameter Store

Status: **implemented** ✅
Date: 2026-08-12

## Context

`xcodeinstall` stored two secrets in AWS Secrets Manager when run with `-s <region>`:

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

### Interpretation

Peak observed size is 2808 bytes, or 69% of the 4096-byte standard-tier limit, leaving 1288 bytes of headroom. **Intelligent-Tiering** was chosen: AWS creates the parameter as standard (free) and only promotes it to advanced (8 KB limit, $0.05/parameter/month) if the value crosses 4 KB.

Caveat documented in README: promotion to the advanced tier is one-way.

## Design decisions (as implemented)

### `PutParameter(Overwrite: true)` replaces the create-then-retry machinery

`PutParameter` with `Overwrite: true` is a single upsert, eliminating the old `createSecret` + `executeRequestAndCreateWhenNotExist` retry loop (~70 lines deleted).

### `SecureString` with the default `aws/ssm` KMS key

Free and AWS-managed. No `kms:*` actions are needed in the IAM policy.

### Parameter naming: hierarchy

Implemented as `/xcodeinstall/apple-credentials` and `/xcodeinstall/apple-session-token`, giving a clean IAM resource of `parameter/xcodeinstall/*`.

### CLI flag renamed (breaking change)

`--secretmanager-region` was renamed to `--secret-region`. The short form `-s` is unchanged. The `PersistentConfig` JSON key was renamed from `secretManagerRegion` to `secretRegion`. Migration instructions are documented in the README.

## Implementation summary

| File | Change |
|---|---|
| `Package.swift` | `SotoSecretsManager` → `SotoSSM` |
| `Sources/xcodeinstall/Secrets/SecretsStorageAWS+Soto.swift` | Rewritten: `SSM` client, `PutParameter`/`GetParameter`, no retry logic |
| `Sources/xcodeinstall/Secrets/SecretsStorageAWS.swift` | Parameter names updated, comments updated |
| `Sources/xcodeinstall/Secrets/SecretsStorageAWSError.swift` | Added `invalidSecretValue`, `noCredentialProvider` cases with diagnostic messages |
| `Sources/xcodeinstall/xcodeInstall/AuthenticateCommand.swift` | `import SotoSSM`, catch `SSMErrorType.parameterNotFound`, user-facing strings updated |
| `Sources/xcodeinstall/xcodeInstall/StoreSecretsCommand.swift` | User-facing strings updated |
| `Sources/xcodeinstall/CLI-driver/CLIMain.swift` | Flag renamed to `--secret-region`, config key to `secretRegion` |
| `Sources/xcodeinstall/CLI-driver/CLIStoreSecrets.swift` | Flag renamed |
| `Sources/xcodeinstall/CLI-driver/CLIAuthenticate.swift` | Uses `cloudOption.secretRegion` |
| `Sources/xcodeinstall/CLI-driver/CLIDownload.swift` | Uses `cloudOption.secretRegion` |
| `Sources/xcodeinstall/CLI-driver/CLIList.swift` | Uses `cloudOption.secretRegion` |
| `Sources/xcodeinstall/Utilities/ConfigHandler.swift` | `PersistentConfig.secretRegion` |
| `Sources/xcodeinstall/CLI/CredentialPrompt.swift` | **New**: shared `promptForAppleCredentials` helper (deduplicates credential prompting) |
| `iam/ec2-policy.json` | `ssm:PutParameter`, `ssm:GetParameter`, resource `parameter/xcodeinstall/*` |
| `Tests/xcodeinstallTests/Secrets/AWSSecretsHandlerSotoTest.swift` | `SSM` client injection |
| `Tests/xcodeinstallTests/Utilities/ConfigHandlerTests.swift` | Uses `secretRegion` key |
| `README.md` | Full rewrite of AWS sections, migration callout, IAM policy |
| `scripts/e2e-test.sh` | Comments and strings updated |

## Verification

- `swift build` ✅
- `swift test` — all 205 tests pass ✅

## Resolved decisions

1. **Hierarchical names** — implemented (`/xcodeinstall/*`).
2. **`retrieveSecret` on missing session** — kept existing behavior (throws, caller handles). The `clearSecrets()` call before `authenticate` ensures the parameter exists.
3. **CLI flag rename** — implemented as a breaking change with migration docs rather than keeping the old name.
