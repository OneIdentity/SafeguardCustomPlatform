# Generic Linux with SSH Key Support

This sample adds SSH authorized-key management to the generic Linux password-management flow. It can discover existing keys, check whether a specific key is installed, add a new key, optionally test the matching private key, and remove an old key.

## Target System

A Linux or Unix host that uses OpenSSH-style `AuthorizedKeysFile` paths for managed accounts.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Verifies the service account can log in and access the required privileged data. |
| `CheckPassword` | Validates a managed-account password by comparing it to the `/etc/shadow` hash. |
| `ChangePassword` | Changes the managed-account password with interactive `passwd`. |
| `CheckSshKey` | Resolves the target authorized-key files and reports whether `OldSshKey` is already installed. |
| `ChangeSshKey` | Resolves the key files, appends `NewSshKey`, optionally tests `NewSshPrivateKey`, and removes `OldSshKey`. |
| `DiscoverAuthorizedKeys` | Reads the resolved authorized-key files, parses valid key lines, and emits discovered SSH keys. |
| `DiscoverSshHostKey` | Retrieves the SSH host key for the target asset. |

## Prerequisites

- SPP version 6.0 or later
- A Linux/OpenSSH host reachable over SSH
- A service account that can run `sshd -T -C`, `id`, and the required file-management commands (`mkdir`, `touch`, `cp`, `cat`, `tee`, `mv`, `chown`, `chmod`) through `sudo` or the configured `DelegationPrefix`
- Managed accounts that store SSH keys in standard OpenSSH authorized-keys files

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./GenericLinuxWithSSHKeySupport.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account and managed account(s)
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The script starts with the same interactive SSH login and shell initialization as the generic Linux sample. For SSH key workflows, it discovers the managed account's UID, GID, home directory, and effective `AuthorizedKeysFile` templates by running `sshd -T -C ...`, with a fallback to `%h/.ssh/authorized_keys %h/.ssh/authorized_keys2`. It resolves those templates to concrete paths, reads and parses valid OpenSSH key lines, and uses that data for check and discovery operations. During `ChangeSshKey`, it backs up the primary key file, appends the new public key, restores ownership and permissions, optionally tests login with `NewSshPrivateKey`, and then removes the old key from whichever file currently contains it.

## Parameters

- `OldSshKey` - Existing public key to verify or remove
- `NewSshKey` - New public key to install
- `NewSshPrivateKey` - Optional private key used to test the newly installed public key
- `DelegationPrefix` - Privilege-elevation command used for shadow access and file updates
- `UserKey` - Optional SSH private key for the service account login

## Limitations

- Does not implement a standalone `RemoveAuthorizedKey` operation
- Installs new keys into the first resolved authorized-keys path
- Key parsing is limited to the key types explicitly handled in `ParseKey`
- Removal is line-oriented text processing and may remove duplicate matching entries
- Assumes `sshd -T -C` is available on the target host

## Related

- [SSH Key Management Guide](../../../docs/guides/ssh-key-management.md)
- [SSH Platforms Guide](../../../docs/guides/ssh-platforms.md)
- [SPP Compatibility Matrix](../../../docs/reference/compatibility.md)
