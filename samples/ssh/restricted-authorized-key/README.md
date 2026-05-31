# Linux with Restricted Authorized Key Service Account

This sample demonstrates a least-privilege SSH design where the service account authenticates only with a restricted authorized key. It uses non-interactive command execution plus passwordless `sudo` to validate and rotate local Linux account passwords.

## Target System

A Linux host where the Safeguard service account uses a restricted SSH key and passwordless `sudo` for a tightly limited command set.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Verifies the service account can resolve the target user through `sudo /usr/bin/id`. |
| `CheckPassword` | Reads the managed account's `/etc/shadow` entry with `sudo` and compares the supplied password to the stored hash. |
| `ChangePassword` | Runs `sudo /usr/bin/passwd <user>` non-interactively by sending the new password on stdin. |
| `DiscoverSshHostKey` | Retrieves the SSH host key for the asset. |

## Prerequisites

- SPP version 7.4 or later
- A Linux host reachable over SSH
- A restricted service-account key configured in `UserKey`
- Passwordless `sudo` rights for the exact commands the sample runs, including `/usr/bin/id`, `/usr/bin/cat /etc/shadow`, and `/usr/bin/passwd <user>`

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./RestrictedAuthorizedKeyExample.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account and managed account(s)
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The connection is opened with `RequestTerminal: false`, and every remote command is executed through a helper that always prefixes the command with `sudo`. `CheckSystem` resolves the target account, `CheckPassword` reads the shadow entry and compares it in-script, and `ChangePassword` drives `passwd` by supplying the new password twice on stdin. Unlike the broader batch-mode sample, this example intentionally fails if `sudo` requests a password, which keeps it aligned with a restricted-key, passwordless-sudo design.

## Parameters

- `UserKey` - Required SSH private key for the restricted service account

## Limitations

- Requires SPP 7.4 or later because it depends on `ExecuteCommand`
- Assumes passwordless `sudo`; the sample throws an error if `sudo` prompts for a password
- Uses fixed Linux command paths and manages only local accounts backed by `/etc/shadow`
- The restricted key policy must still allow the exact `sudo` commands used by the sample

## Related

- [SSH Platforms Guide](../../../docs/guides/ssh-platforms.md)
- [SSH Key Management Guide](../../../docs/guides/ssh-key-management.md)
- [SPP Compatibility Matrix](../../../docs/reference/compatibility.md)
