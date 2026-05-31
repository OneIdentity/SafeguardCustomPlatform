[← SSH Samples](../README.md)

# Generic Linux with Account Discovery

This sample extends the generic Linux SSH password-management flow with account discovery. In addition to checking and changing passwords, it enumerates Unix accounts and group memberships and reports them back to Safeguard.

**Platform Script:** [`GenericLinuxWithDiscovery.json`](./GenericLinuxWithDiscovery.json)

## Target System

A generic Linux host with local accounts in `/etc/passwd`, password hashes in `/etc/shadow`, and standard Unix identity commands such as `id` and `awk`.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Verifies the service account can log in and access the required privileged data. |
| `CheckPassword` | Validates a managed-account password by comparing it to the `/etc/shadow` entry. |
| `ChangePassword` | Changes the managed-account password through the interactive `passwd` command. |
| `DiscoverAccounts` | Enumerates local accounts, UIDs, primary GIDs, and group memberships, then emits `WriteDiscoveredAccount` records. |
| `DiscoverSshHostKey` | Retrieves the SSH host key for trust-on-first-use style onboarding. |

## Prerequisites

- SPP version 6.0 or later
- A Linux host reachable over SSH
- A service account with enough privilege to read `/etc/shadow`, inspect `/etc/passwd`, and run the discovery pipeline commands (`grep`, `wc`, `cut`, `tr`, `id`, and `awk`)
- An account-discovery job in SPP if you want to use `DiscoverAccounts`

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./GenericLinuxWithDiscovery.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account and managed account(s)
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The password-management operations follow the same interactive SSH pattern as the generic Linux sample. `DiscoverAccounts` logs in, sets a predictable shell environment, counts candidate accounts in `/etc/passwd`, then runs a shell pipeline that combines `/etc/passwd` data with `id` output to collect each user's UID, primary group, and supplemental groups. It parses the resulting lines with regex, writes one discovered account per match, and can still return partial results if the command times out after producing some data.

## Parameters

- `DiscoveryQuery` - Required reserved parameter that enables account discovery in SPP
- `DelegationPrefix` - Privilege-elevation command used during password and discovery operations
- `UserKey` - Optional SSH private key for the service account
- `RequestTerminal` - Keeps the connection in interactive shell mode

## Limitations

- Discovers local `/etc/passwd` accounts only
- The discovery operation can return partial results when the remote command times out
- `FuncUserDomain` is declared for discovery but is not used by the sample's discovery login flow
- Password validation and change still depend on `/etc/shadow` access and Linux `passwd` prompts

## Related

- [Account Discovery Guide](../../../docs/guides/account-discovery.md)
- [SSH Platforms Guide](../../../docs/guides/ssh-platforms.md)
- [Operations Reference](../../../docs/reference/operations.md)
