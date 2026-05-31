[← SSH Samples](../README.md)

# Generic Linux Password Management

This sample manages local Linux account passwords over SSH using an interactive shell. It verifies service-account access, validates managed-account passwords against `/etc/shadow`, and changes passwords with `passwd`.

**Platform Script:** [`GenericLinux.json`](./GenericLinux.json)

## Target System

A generic Linux host with local accounts in `/etc/passwd` and password hashes in `/etc/shadow`.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Logs in with the service account, initializes the shell, and verifies that the service account can read the required shadow entry through the configured delegation command. |
| `CheckPassword` | Confirms the managed account exists, reads its `/etc/shadow` entry, and compares the supplied password to the stored hash. |
| `ChangePassword` | Runs `passwd` for the target account, handles interactive prompts, and submits the new password. |
| `DiscoverSshHostKey` | Retrieves the SSH host key so it can be stored on the asset. |

## Prerequisites

- SPP version 6.0 or later
- A Linux host reachable over SSH
- A service account that can log in over SSH and use `sudo` (or another `DelegationPrefix`) to read `/etc/shadow` and run `passwd`
- If `sudo` prompts for a password, the service account password must be supplied; optional SSH key login is supported through `UserKey`

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./GenericLinux.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account and managed account(s)
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The script connects over SSH, flushes the login banner, and sets a predictable shell environment with a known `sudo` prompt. `CheckSystem` verifies delegation by looking up the service account in `/etc/shadow`. `CheckPassword` checks that the managed account exists in `/etc/passwd`, retrieves the shadow entry through the delegation command, and uses `CompareShadowHash` to validate the supplied password. `ChangePassword` drives the interactive `passwd` flow, handling optional `sudo` and current-password prompts before sending the new password twice.

## Parameters

- `DelegationPrefix` - Command used for privilege elevation, typically `sudo`
- `RequestTerminal` - Controls whether SSH requests a PTY; defaults to `true` for interactive flows
- `UserKey` - Optional SSH private key for the service account login

## Limitations

- Designed for local Unix accounts backed by `/etc/passwd` and `/etc/shadow`
- Assumes interactive `passwd` prompts match the regexes in the sample
- Password validation requires enough privilege to read `/etc/shadow`
- Expired-password or forced-password-change login banners cause login validation to fail

## Related

- [SSH Platforms Guide](../../../docs/guides/ssh-platforms.md)
- [Operations Reference](../../../docs/reference/operations.md)
- [SPP Compatibility Matrix](../../../docs/reference/compatibility.md)
