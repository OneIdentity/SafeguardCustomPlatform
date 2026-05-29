[← Documentation](../README.md)

# Reserved Parameters Reference

Reserved parameters are parameter names that SPP recognizes specially. When a custom platform script declares one of these names, SPP understands what value the script is asking for and, in most cases, auto-populates it at runtime from the asset, account, profile, or generated credential context.

The key insight is simple: **for auto-populated reserved parameters, the administrator does not type the value into the Custom Script Parameters UI**. Declaring the reserved name is enough.

This page focuses on the reserved names that are most useful to custom platform authors.

## Quick Reference

| Category | SystemOwned | Visible in Custom Params UI | Value Source | Example |
| --- | :---: | :---: | --- | --- |
| **Auto-populated reserved** | ✅ true | ❌ Hidden | Standard entity fields | `AccountPassword`, `Address`, `FuncUserName`, `Instance` |
| **Reserved but NOT mapped** | ❌ false | ✅ Shown | Admin sets per-asset | `Environment`, `AdminGroupName` |
| **True custom** | ❌ false | ✅ Shown | Admin sets per-asset | `MyApiEndpoint`, `TenantUrl` |

For readability, the examples on this page use a compact `Name`/`Type` JSON form. See [Script Structure](script-structure.md) for the exact upload format and [Operations](operations.md) for where these parameters are typically used.

```json
{
  "Parameters": [
    {"Name": "AccountPassword", "Type": "Secret"},
    {"Name": "Address", "Type": "String"},
    {"Name": "Environment", "Type": "String"},
    {"Name": "TenantUrl", "Type": "String"}
  ]
}
```

---

## How Auto-Population Works

When a script declares a reserved parameter name, SPP uses that name as a contract.

1. **At script upload time**
   - SPP recognizes the parameter name.
   - Auto-mapped reserved parameters are marked `SystemOwned = true`.
   - Related feature flags are set and built-in UI fields are enabled when applicable.

2. **At runtime**
   - SPP checks which reserved parameters the operation requires.
   - It pulls the values from internal storage or generated credential context.
   - Those values are passed to the platform task engine.

3. **In the Asset editor UI**
   - System-owned parameters are filtered out of the **Custom Script Parameters** section.
   - Admins configure the underlying asset/account/profile fields instead.
   - Only true custom parameters, plus the two manual reserved exceptions, remain visible there.

> **You don't configure these — SPP provides them from your Asset/Account/Profile setup.**

A few reserved names also influence UI exposure through [Feature Flags](../guides/feature-flags.md). For example, declaring access-key or instance-related parameters can cause the matching built-in asset fields to appear.

---

## Complete Parameter Reference

### Core Credentials

These are the most common reserved parameters for password-based platforms.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `AccountUserName` | String | `Account.Name` | Account name on the managed account |
| `AccountPassword` | Secret | `Account.CurrentPassword` | Managed by SPP from the vault |
| `NewPassword` | Secret | SPP-generated password | N/A — generated from the password profile |
| `OldPassword` | Secret | Previous managed password context | N/A — previous password being replaced |
| `FuncUserName` | String | `Asset.ServiceAccount.Name` | Service account assigned to the asset |
| `FuncPassword` | Secret | `Asset.ServiceAccount.Password` | Managed by SPP from the vault |
| `Address` | String | `Asset.NetworkAddress` | Network Address field on the asset |
| `AssetName` | String | `Asset.DisplayName` | Asset name / display name |
| `Port` | Integer | `Platform.Port` or asset override | Port field on the asset or script default |
| `Timeout` | Integer | `Platform.Timeout` | Timeout field or script default |

**Example:**

```json
{
  "Parameters": [
    {"Name": "Address", "Type": "String"},
    {"Name": "FuncUserName", "Type": "String"},
    {"Name": "FuncPassword", "Type": "Secret"},
    {"Name": "AccountUserName", "Type": "String"},
    {"Name": "AccountPassword", "Type": "Secret"},
    {"Name": "NewPassword", "Type": "Secret"}
  ]
}
```

### Account Identity

Use these when the target system needs more than just the account name.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `AccountId` | String | `Asset.NetworkAddress` | Network Address field on the asset |
| `AccountNamespace` | String | `Account.Namespace` | Account namespace when the account is created |
| `AccountDn` | String | `Account.DistinguishedName` | Directory-backed account identity |
| `DomainName` | String | `Asset.DomainName` or account domain context | Domain field on the asset/account |
| `NetBiosname` | String | Account NetBIOS domain context | Domain-backed account information |
| `ObjectSid` | String | Account SID context | Directory/domain account identity |
| `Environment` | String | **NOT mapped** | Admin types it in Custom Script Parameters per asset |

### Service Account Authentication

These reserved names extend the service-account connection context beyond username/password.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `FuncAccountDn` | String | `Asset.ServiceAccount.DistinguishedName` | Service account directory identity |
| `FuncUserDomain` | String | `Asset.ServiceAccount.Domain` | Domain-backed service account |
| `FuncUserNetBiosName` | String | `Asset.ServiceAccount.NetBiosName` | NetBIOS domain for the service account |
| `FuncUserAccessKeyId` | String | `Asset.AccessKeyId` | Access Key ID field that appears when the script declares it |
| `FuncUserAccessKey` | Secret | `Asset.SecretKey` | Access Key Secret field that appears alongside the ID |
| `UserKey` | Secret | Service-account private SSH key | Service account SSH key assigned in SPP |
| `Instance` | String | `Asset.Instance` | Instance field that appears when the script declares it |
| `Protocol` | String | Platform/asset connection transport | Protocol selection in platform context |
| `SshPort` | Integer | `Platform.SessionSshPort` | Platform-level SSH session port or script default |

### Connection, TLS, and Proxy Settings

These names let a script consume built-in connection controls instead of inventing custom parameters.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `UseSsl` | Boolean | Platform/asset SSL setting | SSL/TLS enabled setting |
| `SkipServerCertValidation` | Boolean | Platform/asset TLS validation setting | Certificate-validation behavior |
| `CheckHostKey` | Boolean | Platform/asset SSH host-key validation setting | Whether to validate the SSH host key |
| `HostKey` | String | Stored/discovered SSH host key | Host key value on the asset/platform |
| `HttpProxyUri` | String | Platform/asset proxy settings | HTTP proxy URI |
| `HttpProxyPort` | Integer | Platform/asset proxy settings | HTTP proxy port |
| `HttpProxyUserName` | String | Platform/asset proxy settings | HTTP proxy username |
| `HttpProxyPassword` | Secret | Platform/asset proxy settings | HTTP proxy password |
| `TacacsSecret` | Secret | Network-device authentication secret | TACACS secret where applicable |

### SSH Keys

These parameters are used for SSH-key check, change, discovery, and related workflows.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `AccountSshKey` | String | `Account.PublicSshKey` | Managed by SPP |
| `AccountSshKeyComment` | String | `Account.SshKeyComment` | Managed by SPP |
| `PrivateSshKey` | Secret | `Account.PrivateSshKey` | Managed by SPP from the vault |
| `NewSshKey` | String | SPP-generated public key | N/A — generated from the SSH key profile |
| `NewSshKeyComment` | String | SPP-generated comment | N/A — generated by SPP |
| `NewSshPrivateKey` | Secret | SPP-generated private key | N/A — generated by SPP |
| `NewSshKeyType` | String | Generated SSH key profile type | Key type from the SSH key profile |
| `OldPrivateSshKey` | Secret | `Account.OldPrivateSshKey` | Managed by SPP from the vault |
| `OldSshKey` | String | Existing authorized key context | Current key being replaced or removed |
| `SshKeyFingerprint` | String | `Account.SshKeyFingerprint` | Managed by SPP |

> The generated private-key parameter is `NewSshPrivateKey`.

**Example:**

```json
{
  "Parameters": [
    {"Name": "AccountUserName", "Type": "String"},
    {"Name": "PrivateSshKey", "Type": "Secret"},
    {"Name": "NewSshKey", "Type": "String"},
    {"Name": "NewSshPrivateKey", "Type": "Secret"},
    {"Name": "NewSshKeyType", "Type": "String"}
  ]
}
```

### Dependent System Updates

These are used by `UpdateDependentSystem` and related dependency-aware workflows.

> Older wiki content may use shorter dependency names such as `DependentUsername` and `DependentPassword`. This reference uses the more explicit `DependentAccount*` naming shown in current custom-platform guidance.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `DependentAccountUserName` | String | `DependentAccount.Name` | Dependent account name |
| `DependentAccountPassword` | Secret | `DependentAccount.Password` | Managed by SPP from the vault |
| `DependentNewPassword` | Secret | SPP-generated password for the dependent update | N/A |
| `DependentCommand` | String | `Profile.ChangeSchedule.CustomDependencyCommands` | Custom Dependency configuration in the change profile |
| `DependentAltUsername` | String | `Account.AltLoginName` | Alternate Login Name on the dependent account |
| `DependentAccountType` | String | `DependencyRelationship.Type` | Dependency type when accounts are linked |
| `DependentUserNamespace` | String | `Account.Namespace` | Namespace of the dependent account |
| `CommandArguments` | String | `Profile.ChangeSchedule.CustomDependencyCommands` | Custom Dependency command arguments |
| `StdinArguments` | Array | `Profile.ChangeSchedule.CustomDependencyCommands` | Custom Dependency stdin payload |
| `ReportExitStatus` | Boolean | `Profile.ChangeSchedule.CustomDependencyCommands` | Whether to include exit-code reporting |
| `ChangeService` | Boolean | Change-profile dependency settings | Whether Windows services should be updated |
| `ChangeTask` | Boolean | Change-profile dependency settings | Whether scheduled tasks should be updated |
| `ChangeIis` | Boolean | Change-profile dependency settings | Whether IIS application pools should be updated |
| `ChangeComPlus` | Boolean | Change-profile dependency settings | Whether COM+ applications should be updated |
| `RestartService` | Boolean | Change-profile dependency settings | Whether updated dependent services should restart |

### Dependent System SSH Keys

Use these when the dependent system workflow updates SSH-key material instead of, or in addition to, passwords.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `DependentSshKey` | String | `DependentAccount.PublicSshKey` | Managed by SPP |
| `DependentSshKeyComment` | String | `DependentAccount.PublicSshKeyComment` | Managed by SPP |
| `DependentSshPrivateKey` | Secret | `DependentAccount.PrivateSshKey` | Managed by SPP from the vault |
| `DependentSshKeyType` | String | `DependentAccount.PublicSshKeyType` | Managed by SPP |

### JIT Access and Privilege Elevation

These parameters support enable/disable, elevate/demote, and network-device privilege workflows.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `AdminGroupName` | String | **NOT mapped** | Admin types it in Custom Script Parameters per asset |
| `PrivilegeLevel` | String | Elevation workflow context | Requested privilege or role level |
| `PrivilegeGroupMembership` | Array | Elevation workflow context | Groups used for elevate/demote workflows |
| `DelegationPrefix` | String | Platform privilege-elevation context | Escalation prefix such as `sudo` |
| `PrivilegedUser` | String | Platform/network-device privilege context | Privileged identity such as `enable` or `expert` |
| `EnablePassword` | Secret | Network-device enable-mode secret | Enable-mode password on network devices |
| `NetworkDeviceEnablePassword` | Secret | Network-device enable-mode secret | Network device enable password |

### File Management

`CheckFile` and `ChangeFile` use a file payload rather than a password or SSH key.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `FileBase64String` | Secret | `Account.SecureFileBase64` | Managed by SPP from the vault |

### Discovery

Discovery operations receive filters and context from SPP rather than from handwritten custom fields.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `SearchString` | String | `Profile.AssetDiscoveryConditions` | Discovery-profile search condition |
| `DiscoveryQuery` | Object | Discover Accounts filter object | Discovery profile and request filters |
| `ServiceDiscoveryQuery` | Object | Discover Services filter object | Discovery profile and request filters |
| `DomainName` | String | `Asset.DomainName` | Domain field on the asset |

### API Keys and Application Credentials

These reserved names are used by [Operations](operations.md) such as `CheckApiKey` and `ChangeApiKey`.

| Parameter | Type | Auto-Source | What Admin Configures |
| --- | --- | --- | --- |
| `ApiKeyId` | String | API key object stored in SPP | API key selected on the managed account |
| `ApiKeyName` | String | API key object stored in SPP | Friendly API key name in SPP |
| `ApplicationName` | String | Account/application context in SPP | Application or account name |
| `ClientId` | String | API key application/client context | Target-side client or app-registration ID |
| `ClientSecret` | String | API key secret stored in SPP | Secret value being checked or pushed |
| `ClientSecretId` | String | API key target-side identifier | Target-side secret/object ID |
| `KeyLifetime` | Integer | API key lifetime context | Desired lifetime in days |

---

## The Two Manual Exceptions

Two reserved names are special because they are **reserved**, but **not auto-mapped**:

- `Environment`
- `AdminGroupName`

They behave like custom parameters in the UI:

- `SystemOwned` is **false**
- they remain visible in **Custom Script Parameters**
- the admin types the value per asset

They still have value as reserved names because they carry expected semantics and avoid looking like arbitrary script-specific fields.

**Example:**

```json
{
  "Parameters": [
    {"Name": "Environment", "Type": "String"},
    {"Name": "AdminGroupName", "Type": "String"}
  ]
}
```

> Use these when you want the SPP-recognized meaning of the name, but the value still needs to be supplied manually for each asset.

---

## Reserved vs. Custom Parameters

Use a **reserved parameter** when the value already exists somewhere in SPP or when the name has product-level meaning.

Typical cases:

- account identity and credential values already managed by SPP
- asset connection settings such as address, port, proxy, and host-key controls
- generated secrets such as `NewPassword` or `NewSshKey`
- profile-driven dependency or discovery context

Use a **custom parameter** when the value is specific to your target system and SPP has no built-in field for it.

Typical cases:

- tenant-specific API URLs
- application-specific realm names
- custom headers or workflow toggles
- vendor-specific switches that are not standard across platforms

Custom platforms have an advantage over built-in/system platforms: they can freely mix reserved names with truly custom names.

```json
{
  "Parameters": [
    {"Name": "Address", "Type": "String"},
    {"Name": "FuncUserAccessKeyId", "Type": "String"},
    {"Name": "FuncUserAccessKey", "Type": "Secret"},
    {"Name": "TenantUrl", "Type": "String"},
    {"Name": "MyApiEndpoint", "Type": "String"}
  ]
}
```

In that example:

- `Address`, `FuncUserAccessKeyId`, and `FuncUserAccessKey` are reserved
- `TenantUrl` and `MyApiEndpoint` are true custom parameters

For more on defining non-reserved parameters, see [Custom Parameters](custom-parameters.md).

---

## Cross-References

- [Operations](operations.md) — which operations use which reserved parameters
- [Custom Parameters](custom-parameters.md) — defining your own non-reserved names
- [Feature Flags](../guides/feature-flags.md) — how reserved parameters and operations light up built-in behavior and UI
