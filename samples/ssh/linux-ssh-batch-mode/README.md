[← SSH Samples](../README.md)

# Linux SSH Batch Mode Example

This sample shows how to manage Linux passwords without an interactive shell by using `ExecuteCommand`. It is a good starting point for targets where non-interactive command execution is more reliable than prompt-driven `Send` and `Receive` flows.

## Target System

A Linux host where the service account can run the required commands through non-interactive SSH.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Verifies the service account exists and can be resolved with `/usr/bin/id`. |
| `CheckPassword` | Reads the target account's `/etc/shadow` entry and compares the supplied password hash locally in the script. |
| `ChangePassword` | Runs `/usr/bin/passwd <user>` by passing the new password on stdin through `ExecuteCommand`. |
| `DiscoverSshHostKey` | Retrieves the SSH host key for the target asset. |

## Prerequisites

- SPP version 7.4 or later
- A Linux host reachable over SSH
- A service account that can run `/usr/bin/cat /etc/shadow` and `/usr/bin/passwd <user>` via `sudo` or the configured `DelegationPrefix`
- If the delegation command requires a password, the service account password must be available so the sample can retry with `sudo -S`

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./LinuxSshBatchModeExample.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account and managed account(s)
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The script connects with `RequestTerminal: false` and wraps every remote command in a helper that captures stdout, stderr, and exit code. `CheckSystem` and `CheckPassword` call `/usr/bin/id` and `/usr/bin/cat /etc/shadow` non-interactively, retrying with `sudo -S` when a password prompt is detected. `ChangePassword` pipes the new password twice into `passwd`, then checks stderr for the expected success message. Because the sample never relies on an interactive prompt loop, it is much shorter than the interactive SSH examples.

## Parameters

- `DelegationPrefix` - Optional privilege-elevation command, typically `sudo`
- `UserKey` - Optional SSH private key for the service account login

## Limitations

- Requires SPP 7.4 or later because it depends on `ExecuteCommand`
- Uses fixed Linux command paths such as `/usr/bin/id`, `/usr/bin/cat`, and `/usr/bin/passwd`
- Still depends on `/etc/shadow` access, so it manages local Linux accounts only
- The password-change success check is based on the expected `passwd` output text

## Related

- [SSH Platforms Guide](../../../docs/guides/ssh-platforms.md)
- [Operations Reference](../../../docs/reference/operations.md)
- [SPP Compatibility Matrix](../../../docs/reference/compatibility.md)
