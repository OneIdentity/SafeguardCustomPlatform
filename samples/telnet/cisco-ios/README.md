[← Telnet Samples](../README.md)

# Cisco IOS Password Management (Telnet)

This sample manages local Cisco IOS credentials over Telnet. It can validate accounts, change local user passwords, and rotate the device's enable password while preserving the existing password style and privilege context.

**Platform Script:** [`GenericCiscoIosTelnet.json`](./GenericCiscoIosTelnet.json)

## Target System

Cisco IOS network devices that expose Telnet and local `username` / `enable` configuration entries.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Logs in with the service account, enters enable mode, and verifies that the referenced account or enable entry exists in the running configuration. |
| `CheckPassword` | Logs in with the service account, confirms the target account exists, then performs a second Telnet login with the managed account credentials to verify the password. |
| `ChangePassword` | Logs in with the service account, detects whether the target is an `enable` password or a local `username`, updates the configuration, and saves it with `write mem`. |

## Prerequisites

- SPP 6.0 or later
- Telnet access from SPP to the Cisco IOS device on the configured port
- A service account with permission to enter enable mode and run `configure terminal`
- Optional `EnablePwd` if the service account does not already land in privileged exec mode

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./GenericCiscoIosTelnet.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account, managed account(s), and `EnablePwd` if the device prompts for it
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The script connects over Telnet, sends the login credentials, and enters enable mode. It uses `show config | include` to find the target account definition, then branches based on whether the match is an `enable` password or a local `username` entry. For enable passwords it preserves `secret` versus `password`; for local users it preserves privilege and secret-level information and, if required by IOS, removes and recreates the username. After a successful change it exits config mode, runs `write mem`, and returns success.

## Parameters

- `EnablePwd`: Optional enable-mode password used by `SetupEnvironment`.
- `Timeout`: Telnet connection and receive timeout. Default: `20`.
- `Port`: Telnet port. Default: `23`.
- `AssetName`: Optional display name used in status messages; if blank, the imported `ResolveAssetName` helper can populate it.

## Limitations

- This sample uses Telnet only. Prefer SSH in production whenever the device supports it.
- It assumes Cisco IOS command syntax and prompt behavior, including `show config | include`, `configure terminal`, and `write mem`.
- The script writes the configuration immediately after a change.

## Related

- [Connect command reference](../../../docs/reference/commands/connect.md)
- [Send/Receive command reference](../../../docs/reference/commands/send-receive.md)
- [Testing and debugging](../../../docs/guides/testing-and-debugging.md)
