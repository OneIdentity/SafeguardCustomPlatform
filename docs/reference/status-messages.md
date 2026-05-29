[← Documentation](../README.md)

# Status Messages Reference

Status messages are the predefined, operator-visible progress updates that a custom platform script publishes with the `Status` command while an operation runs.

The scripting engine shows these messages in the task UI and task log, substituting any `Message.Parameters` into the localized message template named by `Message.Name`.

> **Important:** `Status` reports progress and context, but it does **not** by itself decide whether an operation succeeds. The scripting engine still evaluates the operation result from what the script returns or throws.

---

## How the scripting engine evaluates success and failure

Across the current docs and samples, operation outcome is driven by the operation result, not by the status message text:

| Script outcome | Meaning | Typical result |
| --- | --- | --- |
| `Return { "Value": true }` | The operation completed successfully | Task success |
| `Return { "Value": false }` | The operation completed, but the answer is a clean failure such as invalid credentials or account not found | Task failure |
| `Throw` or an unhandled command exception | The operation could not complete normally | Task error |
| Discovery/output commands such as `WriteDiscoveredAccount` or `WriteResponseObject` | The operation returns discovery data or a response payload | Operation-specific result |

That matches the current reference docs for operations such as `CheckSystem`, `CheckPassword`, and `ChangePassword`, and the error-handling guidance for `Return false` versus `Throw`.

---

## Status payload shape

```json
{
  "Status": {
    "Type": "Checking",
    "Percent": 60,
    "Message": {
      "Name": "AssetTestingConnectionWithAddress",
      "Parameters": [ "%AssetName%", "%Address%" ]
    }
  }
}
```

### `Status.Type` values used in current docs and samples

| Type | Typical use |
| --- | --- |
| `Connecting` | Opening an SSH, Telnet, or HTTP/API session |
| `Checking` | Validating connectivity, passwords, accounts, or prerequisites |
| `Changing` | Changing passwords, keys, memberships, or account state |
| `Discovering` | Discovering accounts, services, or SSH-key data |
| `Failure` | Explicit final failure state in some HTTP samples |

### Notes

- `Message.Name` is a predefined message ID, not free-form text.
- `Message.Parameters` are positional. Follow the same parameter order used in existing samples.
- Current scripts use `Status`, not a separate `SetStatusMessage` keyword.

---

## How to set status in SSH scripts vs HTTP scripts

The command shape is the same for both transports. What changes is **where** you publish the update.

### SSH scripts

SSH and Telnet samples usually publish status immediately before or after `Connect`, `Send`, `Receive`, or `ExecuteCommand` steps.

From `SampleScripts/SSH/GenericLinux.json`:

```json
{
  "Status": {
    "Type": "Checking",
    "Percent": 50,
    "Message": {
      "Name": "LookingUpUser",
      "Parameters": [ "%AccountUserName%" ]
    }
  }
}
```

Typical SSH pattern:

1. Publish a connection status.
2. Run the remote command or prompt flow.
3. Publish a more specific status if the result is a clean failure.
4. `Return false` or `Throw`.

### HTTP scripts

HTTP samples usually publish status around authentication requests, account lookups, and change requests.

From `SampleScripts/HTTP/CustomTwitter.json`:

```json
{
  "Status": {
    "Type": "Checking",
    "Percent": 20,
    "Message": {
      "Name": "LoggingInToService",
      "Parameters": [ "%AssetName%", "%AccountUserName%" ]
    }
  }
}
```

Typical HTTP pattern:

1. Publish a login or connection status before `Request`.
2. Inspect `StatusCode` or parsed response content.
3. Publish a specific failure status for known outcomes.
4. `Return false` for expected failures or `Throw` for unexpected errors.

---

## Recognized `Message.Name` values

The tables below collect every `Message.Name` value currently used in this repository's docs and sample scripts. Because `Message.Name` is a predefined engine message ID rather than free text, this is the practical reference set available in the repo today.

### Connection and authentication

| Status value | Meaning | When it's returned | Example context |
| --- | --- | --- | --- |
| `AssetConnecting` | Starting an asset or API connection | Before an HTTP/API authentication request | `OneLogin_GRC_JIT_addon.json` / `ApiAuth` |
| `AssetConnected` | Asset or API connection succeeded | After token acquisition or initial connect step succeeds | `OneLogin_GRC_JIT_addon.json` / `ApiAuth` |
| `AssetConnectingWithAddress` | Starting a connection with asset and address context | Before SSH or Telnet `Connect` | `GenericLinux.json` / `LoginSsh` |
| `AssetTestingConnection` | Running a connection test | During `CheckSystem` without a separate asset-name parameter | `GenericRacfTn3270.json` / `CheckSystem` |
| `AssetTestingConnectionWithAddress` | Running a connection test with address details | During `CheckSystem` after login/setup | `GenericLinux.json` / `ValidateAccount` |
| `AssetConnectFailedWithAddress` | Connection failed and no detailed reason was captured | `Connect` or host-key discovery failed with an empty exception | `GenericLinuxWithSSHKeySupport.json` / `DiscoverHostKeyForAsset` |
| `AssetConnectFailedWithReason` | Connection failed and a reason string is available | A connect or reconnect step failed and only address/reason are reported | `GenericLinuxWithSSHKeySupport.json` / `TestNewAuthorizedKey` |
| `AssetConnectFailedWithReasonAndAddress` | Connection failed with asset, address, and reason details | Caught connect failure in SSH or Telnet flows | `LinuxSshBatchModeExample.json` / `ConnectToAsset` |
| `SystemLoginCheck` | Verifying login immediately after transport connection | After connect, before doing operation-specific work | `LinuxSshBatchModeExample.json` / `ConnectToAsset` |
| `LoggingInToService` | Authenticating to a remote HTTP service or portal | Before account or service login requests | `CustomFacebook.json` / `Login` |
| `LoggingInWithAccountFailed` | Login failed for the target account | The login request completed but authentication was not accepted | `CustomTwitter.json` / `CheckAccountLogin` |
| `ConnectionFailed` | HTTP request or login step hit a connection-level failure | A `Request` threw in a `Try`/`Catch` block | `CustomFacebook.json` / `Login` |
| `FuncAccountLoginFailed` | Service account login failed | The service account reached the system but was not authorized to log in | `GenericRacfTn3270.json` / `LoginRacf` |
| `AccountLoginFailed` | Managed-account login failed | The managed account reached the system but could not log in | `GenericRacfTn3270.json` / `LoginRacf` |
| `VerifyingPassword` | Password verification is in progress | Just before comparing a password hash or running a password check | `GenericLinux.json` / `ValidatePassword` |
| `PasswordCheckFailedLockedOrDisabled` | Password check found a locked or disabled account | The account lookup shows the account cannot be used normally | `Pattern-WindowsSshBasic.json` / `CheckPassword` |
| `AccountLocked` | The account is locked | Authentication succeeded far enough to reveal a lock state | `CustomTwitter.json` / `ChangePassword` |
| `AccountVerificationRequested` | Extra verification was requested | The service challenged the login with an additional verification step | `CustomTwitter.json` / `ChangePassword` |
| `AccountHasLoginApprovalsEnabled` | Login-approval workflow blocks automation | A portal login succeeded, but an approval gate prevents continuation | `CustomFacebook.json` / `Login` |
| `AccessRestricted` | The service restricted access after authentication | The change flow hit a service-side access restriction | `CustomTwitter.json` / `ChangePasswordInternal` |

### Lookup, password change, and privilege failures

| Status value | Meaning | When it's returned | Example context |
| --- | --- | --- | --- |
| `LookingUpUser` | Looking up the target account | Before checking, changing, or managing a user | `GenericLinux.json` / `ValidatePassword` |
| `LookingUpGroup` | Looking up a role or group | Before membership validation or assignment/removal | `OneLogin_GRC_JIT_addon.json` / role lookup logic |
| `ChangingPassword` | Password change is in progress | At the start of a password-change flow | `CustomFacebook.json` / `ChangePassword` |
| `CurrentAndNewPasswordsAreIdentical` | The new password matches the current password | A change request is rejected before calling the remote system | `CustomFacebook.json` / `ChangePassword` |
| `AccountNotFound` | The target account was not found | Lookup completed cleanly, but the user does not exist | `GenericLinux.json` / `ChangeUserPassword` |
| `AccountNotFoundOnly` | Alternate account-not-found status | A sample reports only the missing-account condition before throwing | `OneLogin_GRC_JIT_addon.json` / account lookup logic |
| `InvalidPasswordForAccount` | The supplied password value was rejected for that account | The target system rejected the password value as invalid | `GenericRacfTn3270.json` / `ChangePassword` |
| `PasswordChangeFailed` | Generic password change failure | The change path completed, but the target system did not accept the update | `GenericLinuxWithDiscovery.json` / `ChangeUserPassword` |
| `PasswordFailedComplexity` | Password failed the target system's complexity rules | The system returned a complexity/policy-specific rejection | `vCenterServerAppliance.json` / password reset flow |
| `PasswordTooShort` | Password is too short | The target system returned a minimum-length failure | `GenericCiscoIosTelnet.json` / `ChangeEnableTypePassword` |
| `PasswordTooLong` | Password is too long | The target system returned a maximum-length failure | `GenericCiscoIosTelnet.json` / `ChangeEnableTypePassword` |
| `PasswordTooWeak` | Password is too weak | The system rejected the password as weak or low quality | `GenericLinuxWithSSHKeySupport.json` / `ChangeUserPassword` |
| `InsufficientDelegationPrivileges` | Delegated or `sudo` access is not sufficient | The helper account cannot read or change the required data | `GenericLinux.json` / `ValidatePassword` |
| `InsufficientPrivilegesAccessPassword` | Connected user cannot access password data | The session lacks permission to read or update password information | `WordPressHttp.json` / `ChangePassword` |
| `InsufficientPrivilegesChangePassword` | Connected user cannot reach the required privilege level to change a password | The script can connect but cannot reach the shell, role, or privilege level needed for password change work | `vCenterServerAppliance.json` / privilege checks |
| `InsufficientPrivilegesToAccess` | Required mode or protected area cannot be accessed | A Telnet flow cannot enter the required mode, such as Cisco enable mode | `GenericCiscoIosTelnet.json` / enable-mode checks |
| `GroupNotFound` | The target group or role was not found | Membership logic could not find the configured role/group | `OneLogin_GRC_JIT_addon.json` / role lookup logic |

### Discovery and reporting

| Status value | Meaning | When it's returned | Example context |
| --- | --- | --- | --- |
| `DiscoveringAccounts` | Account discovery is running | Before enumerating or parsing discovered accounts | `GenericLinuxWithDiscovery.json` / `DiscoverAccountsOnHost` |
| `DiscoverAccountsFiltering` | Discovery is filtering the account list | After fetching accounts and before applying additional filtering/enrichment | `Okta_WithDiscoveryAndGroupMembershipRestore.json` / discovery flow |
| `DiscoveredAccounts` | Accounts were discovered | After counting accounts during discovery | `GenericLinuxWithDiscovery.json` / `DiscoverAccountsOnHost` |
| `DiscoveringServices` | Service discovery is running | Before enumerating running services | `Pattern-GenericLinuxServiceDiscovery.json` / `DiscoverServices` |
| `ExpectedResponseTimeout` | Timed out waiting for an expected marker and no usable results were parsed | A long-running discovery command exceeded the wait window | `GenericLinuxWithDiscovery.json` / `DiscoverAccountsOnHost` |
| `ExpectedResponseTimeoutWithPartialResults` | Timed out, but partial results were available | Discovery timed out after returning some usable account data | `GenericLinuxWithDiscovery.json` / `DiscoverAccountsOnHost` |
| `UnexpectedDataReceived` | Output or response data was not what the script expected | Parse, command, or API validation failed but the script could still report diagnostics | `LinuxSshBatchModeExample.json` / `CheckSystem` |

### SSH-key lifecycle

| Status value | Meaning | When it's returned | Example context |
| --- | --- | --- | --- |
| `CheckSshKey` | Checking whether an SSH key is configured | Before searching authorized-key files for a specific key | `GenericLinuxWithSSHKeySupport.json` / `FindKeyInAnyFile` |
| `DiscoveringAuthKeyFileTemplates` | Discovering authorized-key file templates | After reading `sshd_config` and before resolving templates | `GenericLinuxWithSSHKeySupport.json` / `ResolveKeyTemplates` |
| `DiscoveringAuthKeyFiles` | Discovering concrete authorized-key file paths | After template expansion, before reading the files | `GenericLinuxWithSSHKeySupport.json` / `ResolveKeyTemplates` |
| `DiscoverKeyFile` | Reading one authorized-key file | Before reading a specific key file from disk | `GenericLinuxWithSSHKeySupport.json` / `GetKeyFileContents` |
| `DiscoveredAuthKeys` | Counted keys in one file | After parsing one authorized-key file | `GenericLinuxWithSSHKeySupport.json` / `ReportKeysFromFile` |
| `TotalDiscoveredAuthKeys` | Counted keys across all files | After reporting all valid keys for an account | `GenericLinuxWithSSHKeySupport.json` / `ReportSshKeys` |
| `InstallingSshKey` | Installing a new SSH key | Before appending the new key to an authorized-key file | `GenericLinuxWithSSHKeySupport.json` / `ConfigureNewKey` |
| `NoKeyToAdd` | No new key was supplied | A change-key path was called without a new key value | `GenericLinuxWithSSHKeySupport.json` / `ConfigureNewKey` |
| `SshKeyConfiguredInFile` | The key is already present in a file | The script found the requested key in an existing authorized-key file | `GenericLinuxWithSSHKeySupport.json` / `ConfigureNewKey` |
| `RemovingOldSshKey` | Removing an old SSH key | Before deleting a previously configured key | `GenericLinuxWithSSHKeySupport.json` / `RemoveOldKey` |
| `NoKeyToRemove` | No old key was supplied | A remove-old-key step had nothing to remove | `GenericLinuxWithSSHKeySupport.json` / `RemoveOldKey` |
| `TestingKeyForServiceUser` | Testing the new key for the service user | Before reconnecting with the new key material | `GenericLinuxWithSSHKeySupport.json` / `TestNewAuthorizedKey` |
| `NewSshKeyTestFailed` | New SSH key validation failed | The reconnect test with the new key did not succeed | `GenericLinuxWithSSHKeySupport.json` / `TestNewAuthorizedKey` |

### JIT account-state and membership changes

| Status value | Meaning | When it's returned | Example context |
| --- | --- | --- | --- |
| `EnablingAccount` | Enabling or restoring an account | Before sending the enable/reactivate request | `OneLogin_GRC_JIT_addon.json` / `ActivateUser` |
| `DisablingAccount` | Disabling or suspending an account | Before sending the disable/deactivate request | `OneLogin_GRC_JIT_addon.json` / `DeactivateUser` |
| `ElevatingAccount` | Elevating an account by granting a role or membership | Before adding the account to a target role/group | `OneLogin_GRC_JIT_addon.json` / role-assignment flow |
| `DemotingAccount` | Demoting an account by removing a role or membership | Before removing the account from a target role/group | `OneLogin_GRC_JIT_addon.json` / role-removal flow |
| `AccountMembershipElevated` | Role or membership was granted successfully | After a successful elevate/add-membership request | `OneLogin_GRC_JIT_addon.json` / role-assignment flow |
| `AccountMembershipElevateFailed` | Role or membership grant failed | After an elevate/add-membership request did not succeed | `OneLogin_GRC_JIT_addon.json` / role-assignment flow |
| `AccountMembershipDemoted` | Role or membership was removed successfully | After a successful demote/remove-membership request | `OneLogin_GRC_JIT_addon.json` / role-removal flow |
| `AccountMembershipDemoteFailed` | Role or membership removal failed | After a demote/remove-membership request did not succeed | `OneLogin_GRC_JIT_addon.json` / role-removal flow |

---

## Common patterns

### Success path

Publish progress, do the work, then return success.

```json
[
  {
    "Status": {
      "Type": "Changing",
      "Percent": 50,
      "Message": {
        "Name": "ChangingPassword",
        "Parameters": [ "%AccountUserName%" ]
      }
    }
  },
  { "Return": { "Value": true } }
]
```

This is the common shape for a finished change operation once the remote system confirms success.

### Expected failure

When the script can answer cleanly, publish a specific status and return `false`.

```json
[
  {
    "Status": {
      "Type": "Checking",
      "Percent": 80,
      "Message": {
        "Name": "AccountNotFound",
        "Parameters": [ "%AccountUserName%" ]
      }
    }
  },
  { "Return": { "Value": false } }
]
```

Use this for outcomes such as invalid credentials, account-not-found checks, or policy failures that the script understood.

### Unexpected error

When a command fails unexpectedly, publish a status in `Catch` and then throw.

```json
{
  "Try": {
    "Do": [
      { "Connect": { "Type": "Ssh", "NetworkAddress": "%Address%" } }
    ],
    "Catch": [
      {
        "Status": {
          "Type": "Connecting",
          "Percent": 95,
          "Message": {
            "Name": "AssetConnectFailedWithReasonAndAddress",
            "Parameters": [ "%AssetName%", "%Address%", "%Exception%" ]
          }
        }
      },
      { "Throw": { "Value": "%Exception%" } }
    ]
  }
}
```

Use this when the operation could not complete normally and the task should end as an error, not a clean `false` result.

---

## Relationship to error handling

`Status` and error handling work together:

- Use [`Try`, `Catch`, and `Throw`](commands/error-handling.md) to control task outcome.
- Use `Status` inside those flows to give operators a localized, progress-aware explanation of what failed.
- For clean failures, pair a specific status with `Return false`.
- For unexpected failures, set a status and then `Throw`.
- If you replace a raw exception with a friendlier `Throw`, log `%Exception%` first so the original cause still appears in the task log.

---

## Tips

- **Reuse predefined IDs.** There is no evidence in the current docs or samples that arbitrary `Message.Name` values are supported. If you need custom text, use `Log`.
- **Keep `Percent` meaningful.** Current samples commonly use milestone values such as `10`, `20`, `50`, `80`, `90`, and `95`.
- **Match the phase with `Type`.** The same message family can appear under different operation phases, but `Type` should still describe the current step (`Connecting`, `Checking`, `Changing`, or `Discovering`).
- **Follow existing parameter order.** For example, `AssetConnectFailedWithReasonAndAddress` is passed as `[ "%AssetName%", "%Address%", "%Exception%" ]` in the current samples.
- **Use extended logging when debugging.** `Status` shows the operator-friendly summary, while `extendedLogging=true` gives command-by-command trace detail. See [Testing and Debugging](../getting-started/testing-and-debugging.md).

---

## Cross-References

- [Logging and Status Commands](commands/logging.md)
- [Error Handling Commands](commands/error-handling.md)
- [Operations Reference](operations.md)
- [Script Structure Reference](script-structure.md)
- [Testing and Debugging](../getting-started/testing-and-debugging.md)
