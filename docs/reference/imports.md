[← Reference](README.md)

# System Import Libraries Reference

## Table of Contents

- [Overview](#overview)
- [How imports work](#how-imports-work)
- [Available system libraries](#available-system-libraries)
- [Stability and compatibility](#stability-and-compatibility)
- [Usage example](#usage-example)
- [Important notes](#important-notes)
- [See also](#see-also)

## Overview

Imports are shared function libraries that are pre-installed on Safeguard's platform scripting engine. A custom platform script can reference these libraries instead of copying the same helper functions into its own top-level `Functions` array.

Add imports at the top level of the script JSON:

```json
"Imports": ["LibraryName"]
```

For where `Imports` fits in the overall JSON shape, see the [Script Structure Reference](script-structure.md#imports).

## How imports work

### Upload and validation

When you upload or validate a script, the scripting engine checks that every import name exists.

- If the library exists, validation continues normally.
- If the library does not exist, validation fails with `LibraryNotFoundException`.
- Customers cannot upload their own import libraries. Only the pre-installed system libraries are available.

### Runtime behavior

At runtime, the scripting engine expands the `Imports` list and merges the imported functions into your script's function namespace.

- Imported functions are callable from any `Do` block with the normal `Function` command.
- Imported functions can call each other.
- You can mix imported functions and your own local `Functions` in the same script.

## Available system libraries

These are the 17 generic SSH-oriented system libraries currently suitable for custom platform scripts. Function names below are the most useful entry points visible in the built-in libraries; many libraries also include lower-level helper functions.

| Library | Purpose | Key functions provided | Use when |
| --- | --- | --- | --- |
| `LinuxSshLogin` | Standard Linux SSH login/logout handling, shell setup, and shared validation. | `LoginSsh`, `LogoutSsh`, `SetUpEnvironment`, `VerifyDelegationPrefix` | Most Linux SSH platforms that need the built-in prompt handling, shell detection, and logout flow. |
| `LinuxSshFunctions` | Common Linux-specific SSH utility and account-management helpers. | `ValidateAccount`, `ValidatePassword`, `ChangeUserPassword`, `ChangeAccountMode`, `ChangeAccountMembershipList` | Implementing Linux `CheckSystem`, `CheckPassword`, `ChangePassword`, enable/disable, or privilege-change flows. |
| `DiscoverSshHostKey` | SSH host key discovery implementation. | `DiscoverHostKeyForAsset` | Implementing `DiscoverSshHostKey`. |
| `TestLoginSsh` | Shared SSH credential and key-login tests. | `TestLoginSsh`, `TestNewKey` | Implementing `CheckPassword`, `CheckSshKey`, or testing a newly installed SSH key. |
| `ChangeSshKeyCommon` | Common SSH key change plumbing, response parsing, and shell-safe key handling. | `CheckKeyChangeRequired`, `CheckKeyVars`, `Converse`, `AssignSshKeyToShellVariable` | Building any `ChangeSshKey` flow that should reuse the standard orchestration logic. |
| `UnixShellAuthorizedKeys` | Generic Unix `authorized_keys` discovery, check, and removal orchestration. | `InitializeSshConfigData`, `UnixShellDiscoverAuthorizedKeys`, `UnixShellCheckAuthorizedKey`, `UnixShellRemoveAuthorizedKey` | Standard Unix/Linux `DiscoverAuthorizedKeys`, `CheckSshKey`, and `RemoveAuthorizedKey` implementations. |
| `UnixShellAuthorizedKeysOpenSsh` | OpenSSH-specific parsing of `sshd_config` and `AuthorizedKeysFile` templates. | `GetSshdConfigurationOpenSsh`, `GetUsersKeystoreListOpenSsh`, `GetAuthKeysOpenSsh`, `CheckSshKeyOpenSsh` | The target uses normal OpenSSH behavior and you need OpenSSH-aware key-file discovery or checking. |
| `UnixShellChangeSshKey` | Generic Unix SSH key-change orchestrator. | `UnixCheckKeyActionRequired`, `InitSshEnvironmentVars`, `SetPermissions`, `UnixShellChangeSshKey` | Implementing `ChangeSshKey` on a standard Unix shell, usually alongside the OpenSSH-specific helpers. |
| `UnixShellChangeSshKeyOpenSsh` | OpenSSH-specific key add/remove, backup, rollback, and verification logic. | `ChangeSshKeyOpenSsh`, `ConfigureNewKeyOpenSsh`, `RemoveKeyOpenSsh`, `AddKeyToKeystoreOpenSsh` | `ChangeSshKey` on OpenSSH servers where you want the built-in file-handling behavior. |
| `UnixShellDiscoverAccounts` | Account discovery on Unix-like systems. | `RunCmd`, `DiscoverAccountsOnHost` | Implementing `DiscoverAccounts` by reading `/etc/passwd`, `id`, `getent`, or similar Unix account data. |
| `UnixShellSshFunctions` | General Unix SSH helpers for account membership changes. | `ChangeAccountMembershipList`, `ChangeAccountMembership` | Implementing Unix `ElevateAccount` / `DemoteAccount` or group-membership updates over SSH. |
| `ResolveAssetName` | Asset name resolution helper. | `ResolveAssetNameIfEmpty` | You want status messages to fall back from `AssetName` to `Address`, especially in multi-host or appliance scenarios. |
| `ReturnOperationResultSsh` | Standard SSH operation result formatting. | `ReturnOperationResult` | You want a helper to normalize helper-driven results to `True`, `False`, or `Error`. |
| `WindowsSshFunctions` | Windows-over-SSH login, validation, password change, and account-mode helpers. | `WinLoginInteractiveSsh`, `WinLoginBatchModeSsh`, `WinValidatePassword`, `WinChangeUserPassword`, `WinChangeAccountMode` | Managing Windows systems through OpenSSH instead of WinRM or HTTP. |
| `WindowsSshFunctionsDiscovery` | Windows account, service, dependency, and asset discovery via SSH. | `WinDiscoverAccountsOnHost`, `WinDiscoverServices`, `WinUpdateDependencies`, `WinDiscoverAssets` | Implementing Windows discovery or dependent-service update flows over SSH. |
| `WindowsSshFunctionsSshKey` | Windows OpenSSH key management. | `WinChangeSshKey`, `WinDiscoverAuthKeys`, `WinCheckAuthKey`, `WinRemoveAuthorizedKey` | Implementing `ChangeSshKey`, `CheckSshKey`, `DiscoverAuthorizedKeys`, or `RemoveAuthorizedKey` on Windows via SSH. |
| `UnixUpdateCustomDependency` | Shared dependent-command execution for Unix shells. | `UnixUpdateCustomDependency`, `CheckForErrors`, `ParseError` | Implementing `UpdateDependentSystem` with custom commands on Unix/Linux. |

## Stability and compatibility

These libraries are effectively frozen interfaces and are safe to depend on in custom platforms.

- `DiscoverSshHostKey` and `TestLoginSsh` have been unchanged since 2018.
- `LinuxSshLogin` is used by 23 built-in platforms, and `ResolveAssetName` is used by 25 built-in platforms.
- Because built-in platforms depend on these signatures, engineering cannot change them casually without breaking shipped platform definitions.
- Recent 2024 changes were non-breaking only: typo fixes, timing adjustments, and status-message text changes.

In practice, that means these imports behave like stable platform APIs, even though they are not versioned as a separate SDK.

## Usage example

Most SSH sample scripts in this repository inline equivalent helper logic. Imports let you replace that copied helper code with the built-in library version.

The example below imports `LinuxSshLogin` and uses its `LoginSsh` and `LogoutSsh` functions from `CheckSystem`.

```json
{
  "Id": "ImportedLinuxLoginExample",
  "BackEnd": "Scriptable",
  "Imports": ["LinuxSshLogin"],
  "CheckSystem": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "AssetName": { "Type": "String", "Required": false, "DefaultValue": "" } },
      { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
      { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": false } },
      { "UserKey": { "Type": "Secret", "Required": false } },
      { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
      { "HostKey": { "Type": "String", "Required": false } },
      { "RequestTerminal": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
    ],
    "Do": [
      {
        "Function": {
          "Name": "LoginSsh",
          "Parameters": ["%FuncUserName%", "%FuncPassword%", "%UserKey::$%"],
          "ResultVariable": "LoginResult"
        }
      },
      {
        "Condition": {
          "If": "!LoginResult",
          "Then": { "Do": [ { "Return": { "Value": false } } ] }
        }
      },
      { "Function": { "Name": "LogoutSsh" } },
      { "Return": { "Value": true } }
    ]
  }
}
```

If you need more than login/logout, you can import multiple libraries in the same script.

```json
"Imports": ["LinuxSshLogin", "DiscoverSshHostKey"]
```

## Important notes

- All documented imports are SSH-only. There are no HTTP import libraries.
- Import names are case-sensitive.
- A script can import multiple libraries.
- Imported functions can call each other internally, so it is normal to combine libraries such as `LinuxSshLogin` and `DiscoverSshHostKey` with `ResolveAssetName`.
- If you do not need shared logic, you do not need imports. All normal script commands remain available without them.
- Vendor-specific libraries also exist (Fortinet, Cisco, Junos, Tectia, and others), but they are intentionally excluded from this reference because they are not recommended for general custom platform use.

## See also

- [SSH Platforms Guide](../guides/ssh-platforms.md)
- [Script Structure Reference](script-structure.md)
- [Your First SSH Script](../tutorials/your-first-ssh-script.md)
- [SSH Key Management Guide](../guides/ssh-key-management.md)
- [Account Discovery Guide](../guides/account-discovery.md)
