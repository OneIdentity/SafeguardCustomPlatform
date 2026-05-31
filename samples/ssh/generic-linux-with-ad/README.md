[← SSH Samples](../README.md)

# Generic Linux with Active Directory Service Account

This sample is the generic Linux SSH password-management script with an optional Active Directory-style login name for the service account. It appends `@domain` during SSH login, then uses the same local `/etc/passwd` and `/etc/shadow` workflow to validate and change managed-account passwords.

## Target System

A Linux host where the service account may authenticate as `user@domain`, while password management still targets local accounts on the host.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Logs in with the service account, optionally as `user@domain`, and verifies delegated access to the required shadow entry. |
| `CheckPassword` | Confirms the managed account exists locally and compares the supplied password to the `/etc/shadow` hash. |
| `ChangePassword` | Runs `passwd` for the managed account and handles the interactive password-change prompts. |
| `DiscoverSshHostKey` | Retrieves the SSH host key for asset trust configuration. |

## Prerequisites

- SPP version 6.0 or later
- A Linux host reachable over SSH
- If you use `FuncUserDomain`, the target must accept SSH logins in `user@domain` form
- A service account that can use `sudo` (or another `DelegationPrefix`) to read `/etc/shadow` and run `passwd`

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./GenericLinuxWithAD.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account and managed account(s)
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

`LoginSsh` optionally rewrites the SSH login to `%FuncUserName%@%FuncUserDomain%` before connecting. After login, the script sets a consistent shell environment and uses delegated commands to inspect `/etc/shadow`. Password validation and password change follow the same pattern as the generic Linux sample: check the local account in `/etc/passwd`, read or update the local password data, and react to `sudo` or `passwd` prompts as needed.

## Parameters

- `FuncUserDomain` - Optional domain suffix appended to the service account at SSH login time
- `DelegationPrefix` - Privilege-elevation command, typically `sudo`
- `RequestTerminal` - Keeps the connection in interactive shell mode for prompt-driven commands
- `UserKey` - Optional SSH private key for service-account authentication

## Limitations

- The AD-specific logic only affects the SSH login name; managed-account validation still relies on local `/etc/passwd` and `/etc/shadow`
- Assumes Linux `passwd` prompts and shadow-file format match the sample regexes
- Does not discover or manage directory accounts directly

## Related

- [SSH Platforms Guide](../../../docs/guides/ssh-platforms.md)
- [Custom Parameters Reference](../../../docs/reference/custom-parameters.md)
- [SPP Compatibility Matrix](../../../docs/reference/compatibility.md)
