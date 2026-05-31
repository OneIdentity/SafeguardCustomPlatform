# Linux Application Password in a Text Configuration File

This sample changes an application password stored in a plain-text configuration file on Linux over SSH. It is intended for simple legacy applications where password rotation means replacing a single `prefix + password` line in a file.

## Target System

A Linux host that stores an application password in a text file that can be updated with shell tools such as `sed`.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Verifies the service account can log in and access the target host with the required delegation command. |
| `CheckPassword` | Present in the sample, but currently returns `false` immediately and is not implemented. |
| `ChangePassword` | Rewrites the configured file by replacing the line that starts with `ApplicationPasswordPrefix` and moving the updated file into place. |
| `DiscoverSshHostKey` | Retrieves the SSH host key for the asset. |

## Prerequisites

- SPP version 6.0 or later
- A Linux host reachable over SSH
- A service account that can use `sudo` (or another `DelegationPrefix`) to edit the application configuration file
- The path, filename, and password-line prefix for the target configuration file

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./LinuxApplicationTextConfig.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account and managed account(s)
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

After connecting over SSH, the script prepares a predictable shell prompt and `sudo` prompt. `ChangePassword` builds the full target path from `ApplicationFilePath` and `ApplicationFileName`, then runs a `sed` replacement that rewrites the line beginning with `ApplicationPasswordPrefix` into a `.new` file and renames that file back over the original. The flow is intentionally simple: it does not parse an application-specific format, it just performs a prefix-based text replacement. `CheckPassword` logs that it is not implemented and exits before performing any validation.

## Parameters

- `ApplicationFilePath` - Directory path that contains the configuration file
- `ApplicationFileName` - Name of the file to update
- `ApplicationPasswordPrefix` - Leading text that identifies the password line to replace
- `DelegationPrefix` - Privilege-elevation command used to edit the file
- `UserKey` - Optional SSH private key for the service account

## Limitations

- Assumes the password is stored as a single text line that starts with `ApplicationPasswordPrefix`
- `CheckPassword` is not implemented in this sample
- The sample performs a raw text substitution and is not format-aware
- Because the full path is built by concatenation, `ApplicationFilePath` should include any required trailing path separator

## Related

- [SSH Platforms Guide](../../../docs/guides/ssh-platforms.md)
- [Custom Parameters Reference](../../../docs/reference/custom-parameters.md)
- [Testing and Debugging Guide](../../../docs/guides/testing-and-debugging.md)
