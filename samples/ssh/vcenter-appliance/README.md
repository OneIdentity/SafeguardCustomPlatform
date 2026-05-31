[← SSH Samples](../README.md)

# VMware vCenter Server Appliance Password Management

This sample manages privileged accounts on VMware vCenter Server Appliance over SSH. It can validate the appliance configuration, rotate vCenter SSO administrator passwords, keep `root` synchronized when required, and discover members of the `Administrators` group.

## Target System

A VMware vCenter Server Appliance (VCSA) with SSH and shell access enabled.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Logs in to the appliance, confirms that `root` is a `superAdmin`, and verifies the shell can be entered successfully. |
| `CheckPassword` | Attempts SSH login using the supplied account password against the appliance's `root` login, matching the sample's root/SSO password-sync assumption. |
| `ChangePassword` | Resets the target SSO user password with `dir-cli`; when rotating the functional administrator account, it also updates `root` to keep the passwords synchronized. |
| `DiscoverAccounts` | Lists members of the VCSA `Administrators` group and emits them as discovered accounts, excluding service principals. |
| `DiscoverSshHostKey` | Retrieves the SSH host key for the asset. |

## Prerequisites

- SPP version 6.0 or later
- A vCenter Server Appliance reachable over SSH with appliance shell access enabled
- A Safeguard service account configured per the sample's assumption that `root` and `Administrator@vsphere.local` share the same password
- Permission to run `/usr/lib/vmware-vmafd/bin/dir-cli` and the appliance password update commands from the SSH session

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./vCenterServerAppliance.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account and managed account(s)
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The sample always connects over SSH as `root`, enters the appliance shell, and checks that `root` has the expected `superAdmin` role. For password rotation, it first resets the SSO account with `dir-cli password reset --account <user>`, authenticating that command by sending the service-account password. If the account being rotated is the same functional administrator account used by Safeguard, the script exits the shell and runs `localaccounts.user.password.update` so the `root` password stays in sync. `DiscoverAccounts` uses `dir-cli group list --name Administrators` and filters out service principals before writing discovered accounts.

## Parameters

- No sample-specific custom parameters beyond the standard SSH connection and account fields

## Limitations

- The sample hard-codes SSH login as `root`
- It assumes `root` and `Administrator@vsphere.local` use the same password
- `CheckPassword` validates the root login path, not an arbitrary SSO account in isolation
- Discovery is limited to members of the `Administrators` group and omits service principals

## Related

- [Account Discovery Guide](../../../docs/guides/account-discovery.md)
- [SSH Platforms Guide](../../../docs/guides/ssh-platforms.md)
- [Testing and Debugging Guide](../../../docs/guides/testing-and-debugging.md)
