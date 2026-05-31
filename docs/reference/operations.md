[← Documentation](../README.md)

# Operations Reference

Operations are the named entry points in a custom platform script that SPP invokes when performing specific tasks. Each operation you include in your script tells SPP what your platform can do — SPP automatically derives [feature flags](../concepts/feature-flags.md) from the operations present.

This page documents all 19 available operations across 8 categories.

## Quick Reference

| Category | Operation | Credential Context | Feature Flag Set |
| --- | --- | --- | --- |
| [Connection](#checksystem) | `CheckSystem` | Service account | — |
| [Password](#checkpassword) | `CheckPassword` | Managed account (+ service account for SSH) | `PasswordFl` |
| [Password](#changepassword) | `ChangePassword` | Managed account (+ service account for SSH) | `AccountPasswordFl` |
| [SSH Keys](#checksshkey) | `CheckSshKey` | Managed account (+ service account) | `SshKeyFl` |
| [SSH Keys](#changesshkey) | `ChangeSshKey` | Managed account (+ service account) | `SshKeyFl` |
| [SSH Keys](#discoversshHostkey) | `DiscoverSshHostKey` | None (asset-level) | `SshHostKeyFl` |
| [SSH Keys](#retrievesshhostkey) | `RetrieveSshHostKey` | None (asset-level) | `SshHostKeyFl` |

| [SSH Keys](#discoverauthorizedkeys) | `DiscoverAuthorizedKeys` | Managed account (+ service account) | `DiscoverSshKeyFl` |
| [SSH Keys](#removeauthorizedkey) | `RemoveAuthorizedKey` | Managed account (+ service account) | `DiscoverSshKeyFl` |
| [Discovery](#discoveraccounts) | `DiscoverAccounts` | Service account | `AccountDiscoveryFl` |
| [Discovery](#discoverservices) | `DiscoverServices` | Service account | `ServiceDiscoveryFl` |
| [JIT Access](#enableaccount) | `EnableAccount` | Service account + managed account | `SuspendRestoreAccountFl` |
| [JIT Access](#disableaccount) | `DisableAccount` | Service account + managed account | `SuspendRestoreAccountFl` |
| [JIT Access](#elevateaccount) | `ElevateAccount` | Service account + managed account | `ElevateDemoteAccountFl` |
| [JIT Access](#demoteaccount) | `DemoteAccount` | Service account + managed account | `ElevateDemoteAccountFl` |
| [Dependencies](#updatedependentsystem) | `UpdateDependentSystem` | Service account + dependent account | `DependentSystemFl` |
| [API Keys](#checkapikey) | `CheckApiKey` | Service account + managed account | `ApiKeyFl` |
| [API Keys](#changeapikey) | `ChangeApiKey` | Service account + managed account | `ApiKeyFl` |
| [Files](#checkfile) | `CheckFile` | Service account + managed account | — |
| [Files](#changefile) | `ChangeFile` | Service account + managed account | — |

> **Note:** `FileFeatureFl` is always set to `true` for all custom platforms regardless of whether `CheckFile`/`ChangeFile` operations are present.

---

## Credential Contexts

Before diving into individual operations, understand how SPP maps credentials:

| Credential | Parameters | Source | Description |
| --- | --- | --- | --- |
| **Service account** | `FuncUserName`, `FuncPassword` | Asset's service account | The privileged account used to connect to the target system |
| **Managed account** | `AccountUserName`, `AccountPassword` | The specific account being managed | The account whose password/key is being checked or changed |
| **New credential** | `NewPassword`, `NewSshKey`, etc. | SPP-generated | The replacement credential SPP creates |

### Credential Patterns by Transport

**HTTP platforms** typically use only one credential set per operation because authentication happens via API tokens or direct login:
- `CheckSystem` → `FuncUserName`/`FuncPassword` (service account validates API connectivity)
- `CheckPassword` → `AccountUserName`/`AccountPassword` (managed account logs in directly)
- `ChangePassword` → `FuncUserName`/`FuncPassword` + `AccountUserName` + `NewPassword` (service account performs the change via API)

**SSH platforms** typically use BOTH credential sets in account-level operations because they must first SSH into the system with a privileged service account and then operate on the managed account:
- `CheckSystem` → `FuncUserName`/`FuncPassword` only (no managed account in context)
- `CheckPassword` → `FuncUserName`/`FuncPassword` (SSH login) + `AccountUserName`/`AccountPassword` (verify via `su` or `passwd`)
- `ChangePassword` → `FuncUserName`/`FuncPassword` (SSH login) + `AccountUserName`/`AccountPassword` + `NewPassword`

**Self-service platforms** (where the managed account authenticates itself directly) may omit `CheckSystem` entirely and use only `AccountUserName`/`AccountPassword` in their operations.

---

## Connection

### CheckSystem

Tests connectivity to the target system using the asset's service account. This is the only operation that runs purely at the asset level — no managed account is in context.

**Triggered by:** Test Connection button in SPP UI, or scheduled connection health checks.

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account username |
| `FuncPassword` | Secret | Service account password |

**Common optional parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Port` | Integer | Connection port (default varies by transport) |
| `Timeout` | Integer | Connection timeout in seconds |
| `CheckHostKey` | Boolean | Whether to verify SSH host key |
| `HostKey` | String | Expected SSH host key fingerprint |
| `UseSsl` | Boolean | Whether to use SSL/TLS |

**Feature flags derived:** `PortFl`, `TimeoutFl`, `UseSslFl`, `CheckHostKeyFl`, `SshPortFl` (based on which optional parameters are declared)

**Return value:** `true` if connection succeeds; throw an error on failure.

**Example (SSH):**

```json
"CheckSystem": {
  "Parameters": [
    { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
    { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": false } },
    { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "HostKey": { "Type": "String", "Required": false } }
  ],
  "Do": [
    { "Connect": { "Type": "Ssh", "Port": "%Port%", "NetworkAddress": "%Address%", "Login": "%FuncUserName%", "Password": "%FuncPassword%", "CheckHostKey": "%CheckHostKey%", "Hostkey": "%HostKey%", "Timeout": "%Timeout%" } },
    { "Disconnect": {} },
    { "Return": { "Value": true } }
  ]
}
```

**Example (HTTP):**

```json
"CheckSystem": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "BaseAddress": { "Address": "https://%Address%" } },
    { "NewHttpRequest": { "ObjectName": "AuthReq" } },
    { "Request": { "Verb": "Post", "Url": "/api/auth", "RequestObjectName": "AuthReq", "ResponseObjectName": "AuthResp", "Content": { "ContentType": "application/json", "Body": "{\"client_id\":\"%FuncUserName%\",\"client_secret\":\"%FuncPassword%\"}" } } },
    { "Condition": { "If": "AuthResp.StatusCode.ToString().Equals(\"OK\")", "Then": { "Do": [{ "Return": { "Value": true } }] }, "Else": { "Do": [{ "Throw": { "Value": "Authentication failed" } }] } } }
  ]
}
```

**Tips:**
- `CheckSystem` is optional. Self-service HTTP platforms often omit it.
- Keep this operation lightweight — it should validate connectivity quickly.
- For SSH, connecting and immediately disconnecting is sufficient.
- For HTTP, a simple authentication request or health endpoint check works well.

---

## Password Management

### CheckPassword

Verifies that the stored password for a managed account is still valid on the target system.

**Triggered by:** Check Password task (scheduled or manual), password verification after change.

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `AccountUserName` | String | Username of the managed account |
| `AccountPassword` | Secret | Current password of the managed account |

**Additional SSH parameters (typical):**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `FuncUserName` | String | Service account for SSH login |
| `FuncPassword` | Secret | Service account password |
| `Port` | Integer | SSH port |
| `Timeout` | Integer | Connection timeout |

**Feature flags derived:** `PasswordFl` (requires `AccountPassword` parameter to be present)

**Return value:** `true` if the password is valid; `false` or throw on failure.

**Example (HTTP — direct login):**

```json
"CheckPassword": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "AccountPassword": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "BaseAddress": { "Address": "https://%Address%" } },
    { "NewHttpRequest": { "ObjectName": "LoginReq" } },
    { "Request": { "Verb": "Post", "Url": "/api/login", "RequestObjectName": "LoginReq", "ResponseObjectName": "LoginResp", "Content": { "ContentType": "application/json", "Body": "{\"username\":\"%AccountUserName%\",\"password\":\"%AccountPassword%\"}" } } },
    { "Condition": { "If": "LoginResp.StatusCode.ToString().Equals(\"OK\")", "Then": { "Do": [{ "Return": { "Value": true } }] }, "Else": { "Do": [{ "Return": { "Value": false } }] } } }
  ]
}
```

**Example (SSH — service account + managed account):**

```json
"CheckPassword": {
  "Parameters": [
    { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
    { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": false } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "AccountPassword": { "Type": "Secret", "Required": true } },
    { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "HostKey": { "Type": "String", "Required": false } }
  ],
  "Do": [
    { "Connect": { "Type": "Ssh", "Port": "%Port%", "NetworkAddress": "%Address%", "Login": "%FuncUserName%", "Password": "%FuncPassword%", "CheckHostKey": "%CheckHostKey%", "Hostkey": "%HostKey%", "Timeout": "%Timeout%" } },
    { "Send": { "Text": "su - %AccountUserName%\n" } },
    { "Receive": { "Regex": "[Pp]assword:" } },
    { "Send": { "Text": "%AccountPassword%\n" } },
    { "Receive": { "Regex": "\\$|#", "ResultVariable": "SuResult" } },
    { "Disconnect": {} },
    { "Return": { "Value": true } }
  ]
}
```

### ChangePassword

Changes the password for a managed account on the target system.

**Triggered by:** Change Password task (scheduled rotation or manual), password reset.

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `AccountUserName` | String | Username of the managed account |
| `AccountPassword` | Secret | Current password of the managed account |
| `NewPassword` | Secret | New password (generated by SPP) |

**Additional SSH parameters (typical):**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `FuncUserName` | String | Service account for SSH login |
| `FuncPassword` | Secret | Service account password |
| `Port` | Integer | SSH port |
| `Timeout` | Integer | Connection timeout |

**Feature flags derived:** `AccountPasswordFl` (requires both `AccountPassword` and `NewPassword` parameters)

**Return value:** `true` if the password was changed successfully; throw on failure.

**Example (HTTP — API-based change):**

```json
"ChangePassword": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": true } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "AccountPassword": { "Type": "Secret", "Required": true } },
    { "NewPassword": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "Function": { "Name": "Login", "Parameters": ["%Address%", "%FuncUserName%", "%FuncPassword%"], "ResultVariable": "LoginOk" } },
    { "Condition": { "If": "!LoginOk", "Then": { "Do": [{ "Throw": { "Value": "Service account login failed" } }] } } },
    { "NewHttpRequest": { "ObjectName": "ChangeReq" } },
    { "Request": { "Verb": "Put", "Url": "/api/users/%AccountUserName%/password", "RequestObjectName": "ChangeReq", "ResponseObjectName": "ChangeResp", "Content": { "ContentType": "application/json", "Body": "{\"new_password\":\"%NewPassword%\"}" } } },
    { "Condition": { "If": "ChangeResp.StatusCode.ToString().Equals(\"OK\")", "Then": { "Do": [{ "Return": { "Value": true } }] }, "Else": { "Do": [{ "Throw": { "Value": "Password change failed: %ChangeResp.StatusCode%" } }] } } }
  ]
}
```

**Example (SSH — service account changes managed account password):**

```json
"ChangePassword": {
  "Parameters": [
    { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
    { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": false } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "AccountPassword": { "Type": "Secret", "Required": true } },
    { "NewPassword": { "Type": "Secret", "Required": true } },
    { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "HostKey": { "Type": "String", "Required": false } }
  ],
  "Do": [
    { "Connect": { "Type": "Ssh", "Port": "%Port%", "NetworkAddress": "%Address%", "Login": "%FuncUserName%", "Password": "%FuncPassword%", "CheckHostKey": "%CheckHostKey%", "Hostkey": "%HostKey%", "Timeout": "%Timeout%" } },
    { "Send": { "Text": "sudo passwd %AccountUserName%\n" } },
    { "Receive": { "Regex": "[Nn]ew.*[Pp]assword:" } },
    { "Send": { "Text": "%NewPassword%\n" } },
    { "Receive": { "Regex": "[Rr]etype|[Rr]e-enter|[Cc]onfirm" } },
    { "Send": { "Text": "%NewPassword%\n" } },
    { "Receive": { "Regex": "success|updated" } },
    { "Disconnect": {} },
    { "Return": { "Value": true } }
  ]
}
```

**Tips:**
- SSH scripts connect as the service account (`FuncUserName`) and use `sudo passwd` or similar to change the managed account's password.
- HTTP scripts may authenticate as the service account and call an admin API, or authenticate as the managed account and call a "change my password" endpoint.
- Always verify the change succeeded before returning `true`.

---

## SSH Key Management

### CheckSshKey

Verifies that the stored SSH public key for a managed account is present in the target system's authorized keys.

**Triggered by:** Check SSH Key task.

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account for SSH login |
| `AccountUserName` | String | Account whose authorized keys to check |
| `OldSshKey` | String | The SSH public key expected to be present |

**Feature flags derived:** `SshKeyFl`

**Return value:** `true` if the key is found in the account's authorized keys; `false` otherwise.

**Example:**

```json
"CheckSshKey": {
  "Parameters": [
    { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
    { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": false } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "OldSshKey": { "Type": "String", "Required": true } },
    { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "HostKey": { "Type": "String", "Required": false } }
  ],
  "Do": [
    { "Connect": { "Type": "Ssh", "Port": "%Port%", "NetworkAddress": "%Address%", "Login": "%FuncUserName%", "Password": "%FuncPassword%", "CheckHostKey": "%CheckHostKey%", "Hostkey": "%HostKey%", "Timeout": "%Timeout%" } },
    { "ExecuteCommand": { "Command": "grep -F '%OldSshKey%' /home/%AccountUserName%/.ssh/authorized_keys", "ResultVariable": "GrepResult" } },
    { "Condition": { "If": "GrepResult.Contains(OldSshKey)", "Then": { "Do": [{ "Return": { "Value": true } }] }, "Else": { "Do": [{ "Return": { "Value": false } }] } } }
  ]
}
```

### ChangeSshKey

Replaces an SSH key in a managed account's authorized keys store — adding the new key and removing the old one.

**Triggered by:** Change SSH Key task (scheduled rotation or manual).

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account for SSH login |
| `AccountUserName` | String | Account whose key to change |
| `NewSshKey` | String | New SSH public key to install |
| `OldSshKey` | String | Previous SSH public key to remove |

**Common optional parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `NewSshPrivateKey` | Secret | New private key (if script needs it for verification) |
| `NewSshKeyType` | String | Key type: RSA, ED25519, ECDSA |

**Feature flags derived:** `SshKeyFl`

**Return value:** `true` if the key was rotated successfully.

### DiscoverSshHostKey

Retrieves the SSH host key fingerprint of the target system during asset creation or on demand.

**Triggered by:** Asset creation wizard, Discover SSH Host Key task.

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |

**Common optional parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Port` | Integer | SSH port (default 22) |
| `Timeout` | Integer | Connection timeout |

**Feature flags derived:** `SshHostKeyFl`

**Return value:** The host key fingerprint string. Uses the built-in `DiscoverSshHostKey` command.

**Example:**

```json
"DiscoverSshHostKey": {
  "Parameters": [
    { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
    { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
    { "Address": { "Type": "String", "Required": true } }
  ],
  "Do": [
    { "DiscoverSshHostKey": { "NetworkAddress": "%Address%", "Port": "%Port%", "Timeout": "%Timeout%" } },
    { "Return": { "Value": true } }
  ]
}
```

**Tips:**
- This operation does NOT require authentication — it's a pre-authentication key exchange.
- The built-in `DiscoverSshHostKey` command (same name as the operation) handles the low-level negotiation.
- The `ResolveAssetName` import library can be used to resolve asset names before connection.
- No `FuncUserName`/`FuncPassword` needed since host key discovery doesn't require login.

### RetrieveSshHostKey

Retrieves the SSH host key from a system that is already configured as an asset.

**Triggered by:** Retrieve SSH Host Key task, scheduled host key refresh.

**Required parameters:** Same as `DiscoverSshHostKey`.

**Feature flags derived:** `SshHostKeyFl` (same flag as `DiscoverSshHostKey`)

**Implementation:** Typically identical to `DiscoverSshHostKey`. Many scripts share the same implementation for both.

### DiscoverAuthorizedKeys

Discovers all SSH public keys configured in a managed account's authorized keys store.

**Triggered by:** SSH Key Discovery job.

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account for SSH login |
| `AccountUserName` | String | Account whose authorized keys to enumerate |

**Feature flags derived:** `DiscoverSshKeyFl`

**Return value:** Reports discovered keys back to SPP. The script reads the authorized_keys file and reports each key found.

### RemoveAuthorizedKey

Removes a specific SSH public key from a managed account's authorized keys store.

**Triggered by:** Remove Authorized Key action (after discovering unmanaged keys).

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account for SSH login |
| `AccountUserName` | String | Account whose key to remove |
| `OldSshKey` | String | The specific key to remove |

**Feature flags derived:** `DiscoverSshKeyFl` (same flag as `DiscoverAuthorizedKeys`)

**Return value:** `true` if the key was removed successfully.

---

## Discovery

### DiscoverAccounts

Discovers accounts on the target system that SPP can manage. Returns a list of account names found on the system.

**Triggered by:** Account Discovery job (scheduled or manual).

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account for authentication |
| `FuncPassword` | Secret | Service account password |

**Common optional parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `DiscoveryQuery` | Object | Filter criteria for which accounts to discover |
| `DelegationPrefix` | String | Privilege escalation command (e.g., `sudo`) |

**Feature flags derived:** `AccountDiscoveryFl`

**Return value:** Reports discovered accounts back to SPP. For SSH platforms, typically parses `/etc/passwd` or uses `getent passwd`. For HTTP platforms, calls an API that lists users.

**Example (SSH):**

```json
"DiscoverAccounts": {
  "Parameters": [
    { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": false } },
    { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "HostKey": { "Type": "String", "Required": false } }
  ],
  "Do": [
    { "Connect": { "Type": "Ssh", "Port": "%Port%", "NetworkAddress": "%Address%", "Login": "%FuncUserName%", "Password": "%FuncPassword%", "CheckHostKey": "%CheckHostKey%", "Hostkey": "%HostKey%" } },
    { "ExecuteCommand": { "Command": "getent passwd | cut -d: -f1", "ResultVariable": "AccountList" } },
    { "Disconnect": {} },
    { "Return": { "Value": "%AccountList%" } }
  ]
}
```

### DiscoverServices

Discovers services (Windows services, systemd units, etc.) running on the target system that may use managed credentials.

**Triggered by:** Service Discovery job (scheduled or manual).

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account for authentication |
| `FuncPassword` | Secret | Service account password |

**Feature flags derived:** `ServiceDiscoveryFl`

**Return value:** Reports discovered services back to SPP, including which accounts they run under.

---

## JIT Access (Just-In-Time)

JIT operations manage temporary access elevation. They are triggered by SPP's access request workflow — when a user's access request is approved, SPP calls the appropriate enable/elevate operation, and when access expires or is revoked, it calls disable/demote.

### EnableAccount

Activates or unsuspends a managed account, granting the user access.

**Triggered by:** Access request approval (account enable policy), manual account enable.

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account for API authentication |
| `FuncPassword` | Secret | Service account password/secret |
| `AccountUserName` | String | Account to enable |

**Feature flags derived:** `SuspendRestoreAccountFl`

**Return value:** `true` if the account was enabled successfully.

### DisableAccount

Deactivates or suspends a managed account, revoking access.

**Triggered by:** Access request expiration, manual account disable, access revocation.

**Required parameters:** Same as `EnableAccount`.

**Feature flags derived:** `SuspendRestoreAccountFl`

**Return value:** `true` if the account was disabled successfully.

### ElevateAccount

Grants elevated privileges to a managed account (e.g., adding to an admin group, assigning a privileged role).

**Triggered by:** Access request approval (privilege elevation policy).

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account for API authentication |
| `FuncPassword` | Secret | Service account password/secret |
| `AccountUserName` | String | Account to elevate |

**Common optional parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `AdminGroupName` | String | Target admin/privileged group name |
| `PrivilegeGroupMembership` | Array | List of groups/roles to grant |

**Feature flags derived:** `ElevateDemoteAccountFl`

**Return value:** `true` if the account was elevated successfully.

### DemoteAccount

Removes elevated privileges from a managed account (e.g., removing from admin group, revoking a privileged role).

**Triggered by:** Access request expiration, manual privilege revocation.

**Required parameters:** Same as `ElevateAccount`.

**Feature flags derived:** `ElevateDemoteAccountFl`

**Return value:** `true` if the account was demoted successfully.

**Tips for JIT operations:**
- These operations typically use HTTP (calling management APIs) rather than SSH.
- Enable/Disable and Elevate/Demote are paired — if you implement one, implement its counterpart.
- The access request workflow in SPP handles timing; your script just performs the action.
- Use `FuncUserName`/`FuncPassword` as the admin API credentials and `AccountUserName` to identify the target account.

---

## Dependencies

### UpdateDependentSystem

Updates a dependent system after a password change on the primary account. For example, after changing a service account password, this operation updates all Windows services or scheduled tasks that use that account.

**Triggered by:** Automatic cascading update after a successful `ChangePassword` on an account with linked dependent systems.

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the dependent system |
| `FuncUserName` | String | Service account for connecting to the dependent system |
| `FuncPassword` | Secret | Service account password |

**Dependent account parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `DependentAltUsername` | String | Alternate username for the dependent account |
| `DependentAccountType` | String | Type/category of dependent account |
| `DependentUserNamespace` | String | Namespace for the dependent user |

**Custom dependency parameters (for `ExecuteDependentCommand`):**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `DependentCommand` | String | Custom command to execute (triggers `CustomDependencyFl`) |
| `CommandArguments` | String | Arguments for the command |
| `StdinArguments` | Array | Stdin arguments piped to the command |
| `ReportExitStatus` | Boolean | Whether to report exit code in results |

**Feature flags derived:** `DependentSystemFl`; additionally `CustomDependencyFl` if `DependentCommand` parameter is present.

**Return value:** `true` if the dependent system was updated successfully.

**Tips:**
- Use the [`ExecuteDependentCommand`](commands/execute-dependent-command.md) command within this operation to run arbitrary commands on the dependent system via SSH.
- The `DependentCommand` parameter enables the "Custom Dependency" configuration in SPP's UI.
- Multiple dependent systems can be linked to a single account — SPP calls this operation once per dependent system.

---

## API Key Management

### CheckApiKey

Verifies that the stored API key for a managed account is still valid.

**Triggered by:** Check API Key task (scheduled or manual).

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the API |
| `FuncUserName` | String | Service account / client ID |
| `FuncPassword` | Secret | Service account secret / client secret |
| `AccountUserName` | String | The account whose API key to verify |
| `AccountPassword` | Secret | The API key to verify |

**Feature flags derived:** `ApiKeyFl`

**Return value:** `true` if the API key is valid; `false` or throw if invalid.

**Example:**

```json
"CheckApiKey": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": true } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "AccountPassword": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "BaseAddress": { "Address": "https://%Address%" } },
    { "NewHttpRequest": { "ObjectName": "KeyCheckReq" } },
    { "Headers": { "ObjectName": "KeyCheckReq", "Headers": [{ "Name": "X-API-Key", "Value": "%AccountPassword%" }] } },
    { "Request": { "Verb": "Get", "Url": "/api/v1/verify", "RequestObjectName": "KeyCheckReq", "ResponseObjectName": "KeyCheckResp" } },
    { "Condition": { "If": "KeyCheckResp.StatusCode.ToString().Equals(\"OK\")", "Then": { "Do": [{ "Return": { "Value": true } }] }, "Else": { "Do": [{ "Return": { "Value": false } }] } } }
  ]
}
```

### ChangeApiKey

Rotates an API key — generates a new key and invalidates the old one.

**Triggered by:** Change API Key task (scheduled rotation or manual).

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the API |
| `FuncUserName` | String | Service account / client ID |
| `FuncPassword` | Secret | Service account secret / client secret |
| `AccountUserName` | String | The account whose API key to rotate |
| `AccountPassword` | Secret | The current API key |
| `NewPassword` | Secret | The new API key (generated by SPP or returned by the API) |

**Feature flags derived:** `ApiKeyFl`

**Return value:** `true` if the key was rotated successfully.

**Tips:**
- Some APIs generate the new key server-side (you call "rotate" and get a new key back). In this case, SPP provides `NewPassword` but your script may need to capture the API-generated key instead.
- `AccountPassword` holds the current API key (same parameter used for passwords — SPP treats it as the current credential).
- Use `FuncUserName`/`FuncPassword` as the admin credentials that have permission to rotate other users' keys.

---

## File Management

### CheckFile

Verifies that a file-based credential on the target system matches what SPP has stored.

**Triggered by:** Check File task.

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account for authentication |
| `FuncPassword` | Secret | Service account password |
| `AccountUserName` | String | Account that owns the file |
| `FileBase64String` | Secret | Base64-encoded content of the expected file |

**Feature flags derived:** None directly (see note below).

**Return value:** `true` if the file content matches.

> **Note:** `FileFeatureFl` is always set to `true` for all custom platforms, regardless of whether `CheckFile`/`ChangeFile` operations are present in the script. This is a hardcoded behavior in SPP.

### ChangeFile

Replaces a file-based credential on the target system with new content.

**Triggered by:** Change File task.

**Required parameters:**

| Parameter | Type | Purpose |
| --- | --- | --- |
| `Address` | String | Network address of the target system |
| `FuncUserName` | String | Service account for authentication |
| `FuncPassword` | Secret | Service account password |
| `AccountUserName` | String | Account that owns the file |
| `FileBase64String` | Secret | Base64-encoded content of the new file |

**Return value:** `true` if the file was replaced successfully.

**Tips:**
- The file content is passed as a Base64-encoded string in `FileBase64String`.
- Your script must decode the Base64 content and write it to the appropriate location.
- Common use cases: TLS certificates, configuration files with embedded secrets, Kerberos keytabs.
- For SSH platforms, connect with the service account and write the file.
- For HTTP platforms, upload the file content via an API.

---

## Feature Flags Summary

SPP automatically derives these feature flags when you upload a script. You never set them manually.

| Flag | How It's Derived |
| --- | --- |
| `PasswordFl` | `CheckPassword` operation with `AccountPassword` parameter |
| `AccountPasswordFl` | `ChangePassword` operation with both `AccountPassword` and `NewPassword` parameters |
| `SshKeyFl` | `CheckSshKey` operation present |
| `SshHostKeyFl` | `DiscoverSshHostKey` operation present |
| `DiscoverSshKeyFl` | `DiscoverAuthorizedKeys` operation present |
| `AccountDiscoveryFl` | `DiscoverAccounts` operation present |
| `ServiceDiscoveryFl` | `DiscoverServices` operation present |
| `SuspendRestoreAccountFl` | `EnableAccount` or `DisableAccount` operation present |
| `ElevateDemoteAccountFl` | `ElevateAccount` or `DemoteAccount` operation present |
| `DependentSystemFl` | `UpdateDependentSystem` operation present |
| `CustomDependencyFl` | `UpdateDependentSystem` with `DependentCommand` parameter |
| `ApiKeyFl` | `CheckApiKey` operation present |
| `FileFeatureFl` | Always `true` (hardcoded for all platforms) |
| `PortFl` | Any operation with `Port` parameter |
| `SshPortFl` | Any operation with `SshPort` parameter |
| `UseSslFl` | Any operation with `UseSsl` parameter |
| `TimeoutFl` | Any operation with `Timeout` parameter |
| `CheckHostKeyFl` | Any operation with `CheckHostKey` parameter |

For a detailed guide on how feature flags affect platform behavior in the SPP UI, see [Feature Flags Guide](../concepts/feature-flags.md).

---

## Choosing Which Operations to Implement

### Minimum Viable Platform

At minimum, implement one operation. The most common starting points:

| Use Case | Minimum Operations |
| --- | --- |
| Password management | `CheckPassword` + `ChangePassword` |
| SSH key management | `CheckSshKey` + `ChangeSshKey` |
| API key rotation | `CheckApiKey` + `ChangeApiKey` |
| JIT access only | `EnableAccount` + `DisableAccount` |

### Recommended for Production

For a production-quality password management platform:

| Operation | Purpose |
| --- | --- |
| `CheckSystem` | Validates connectivity before operations |
| `CheckPassword` | Verifies stored credentials |
| `ChangePassword` | Rotates passwords |
| `DiscoverAccounts` | Finds accounts to manage |
| `DiscoverSshHostKey` | (SSH only) Captures host fingerprint |

### Full-Featured Platform

A comprehensive platform might implement all relevant operations:

```json
{
  "Id": "FullFeaturedLinux",
  "BackEnd": "Scriptable",
  "CheckSystem": { ... },
  "CheckPassword": { ... },
  "ChangePassword": { ... },
  "CheckSshKey": { ... },
  "ChangeSshKey": { ... },
  "DiscoverSshHostKey": { ... },
  "RetrieveSshHostKey": { ... },
  "DiscoverAccounts": { ... },
  "DiscoverAuthorizedKeys": { ... },
  "RemoveAuthorizedKey": { ... },
  "UpdateDependentSystem": { ... }
}
```

---

## See Also

- [Script Structure](script-structure.md) — JSON structure overview
- [Reserved Parameters](reserved-parameters.md) — complete auto-populated parameter reference
- [Feature Flags Guide](../concepts/feature-flags.md) — how operations determine platform capabilities
- [Commands Index](commands/index.md) — all available commands for implementing operations
- [SSH Platforms Guide](../guides/ssh-platforms.md) — patterns for SSH-based implementations
- [HTTP Platforms Guide](../guides/http-platforms.md) — patterns for HTTP-based implementations
