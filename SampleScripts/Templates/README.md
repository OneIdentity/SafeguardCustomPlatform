# Pattern Templates

These scripts are **pattern templates** — they illustrate recommended approaches
for common integration scenarios. They are _not_ tested against live targets and
should not be deployed without modification.

Use them as a reference when building your own platform scripts, or copy a
minimal starter and expand from there.

## Minimal Starters

| File | Description |
|------|-------------|
| `TemplateSshMinimal.json` | Bare-bones SSH script with CheckSystem only. Copy and expand. |
| `TemplateHttpMinimal.json` | Bare-bones HTTP script with CheckSystem only. Copy and expand. |

## Pattern Scripts

| File | Demonstrates |
|------|-------------|
| `Pattern-GenericRestApiBasicAuth.json` | REST API integration using Basic authentication. |
| `Pattern-GenericRestApiBearerToken.json` | REST API integration using OAuth2 Bearer tokens. |
| `Pattern-GenericRestApiKeyRotation.json` | API key rotation workflow with rollback safety. |
| `Pattern-GenericHttpAccountDiscovery.json` | HTTP-based account discovery using paginated API responses. |
| `Pattern-GenericHttpJitElevation.json` | Just-In-Time privilege elevation via HTTP API. |
| `Pattern-GenericLinuxFull.json` | Full Linux SSH workflow: check, change, discover. |
| `Pattern-GenericLinuxDependentSystem.json` | Dependent system updates after a password change. |
| `Pattern-GenericLinuxFileManagement.json` | File-based credential management over SSH. |
| `Pattern-GenericLinuxServiceDiscovery.json` | Service and asset discovery on Linux hosts. |
| `Pattern-WindowsSshBasic.json` | Windows management via OpenSSH (non-WinRM). |

## Functional Samples

For production-ready scripts tested against real targets, see the parent
directories:

- [SSH/](../SSH/) — Linux, AIX, macOS, and Windows-over-SSH samples
- [HTTP/](../HTTP/) — Facebook, OneLogin, Duo, and other HTTP-based platforms
- [Telnet/](../Telnet/) — TN3270 mainframe samples
