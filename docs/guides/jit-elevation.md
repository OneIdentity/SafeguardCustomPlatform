[← Guides](README.md)

# JIT Elevation and Account Lifecycle Operations

## Table of Contents

- [What JIT elevation means in Safeguard](#what-jit-elevation-means-in-safeguard)
- [How access requests trigger JIT operations](#how-access-requests-trigger-jit-operations)
- [The four operations](#the-four-operations)
- [Feature flags and parameters](#feature-flags-and-parameters)
- [Implementation patterns for SSH platforms](#implementation-patterns-for-ssh-platforms)
- [Implementation patterns for HTTP platforms](#implementation-patterns-for-http-platforms)
- [Idempotency and pairing](#idempotency-and-pairing)
- [Error handling and recovery](#error-handling-and-recovery)
- [End-user experience](#end-user-experience)
- [Real-world examples](#real-world-examples)
- [Related references](#related-references)

## What JIT elevation means in Safeguard

In Safeguard, **just-in-time (JIT) elevation** means the target account is kept in its lower-privilege or disabled state until access is actually approved. When the access request becomes active, SPP calls your custom platform script to grant the temporary privilege or re-enable the account. When the request is checked in, expires, or is revoked, SPP calls the matching operation to remove that access again.

In other words, SPP owns the **workflow and timing**, while your script owns the **target-side change**.

Typical JIT patterns include:

- adding a Linux account to an admin group for the duration of a request
- assigning a cloud or SaaS admin role through a REST API
- enabling a disabled account only while the request is active
- combining enable/disable with elevate/demote so the account is both activated and granted extra privileges only when needed

> [!IMPORTANT]
> Treat JIT access as a temporary state transition. Your script should make the minimum change needed for the request, and the paired operation should cleanly reverse it.

## How access requests trigger JIT operations

The JIT lifecycle is driven by SPP's access request workflow, not by end users calling your script directly.

### Elevate / demote flow

1. A user submits an access request in SPP.
2. The request is approved or auto-approved.
3. When the request becomes active, SPP calls `ElevateAccount`.
4. The user starts the session or uses the checked-out access.
5. When the request ends, is checked in, expires, or is revoked, SPP calls `DemoteAccount` automatically.

### Enable / disable flow

1. The managed account is normally kept disabled or suspended.
2. A user requests access in SPP.
3. When the request becomes active, SPP calls `EnableAccount`.
4. The user works with the now-enabled account.
5. When the request ends, SPP calls `DisableAccount` to suspend it again.

This matches the JIT guidance in the [operations reference](../reference/operations.md), where these operations are described as access-request-driven entry points.

## The four operations

These operations come in two pairs.

| Operation | Purpose | Common target action | Auto-derived feature flag |
| --- | --- | --- | --- |
| `ElevateAccount` | Grant temporary elevated privilege | Add to admin group, assign admin role, add sudoers entry | `ElevateDemoteAccountFl` |
| `DemoteAccount` | Remove the temporary privilege | Remove from group, revoke role, remove sudoers entry | `ElevateDemoteAccountFl` |
| `EnableAccount` | Re-enable an account for use | Activate user, unlock user, clear disabled flag | `SuspendRestoreAccountFl` |
| `DisableAccount` | Suspend the account after use | Disable user, lock account, set inactive flag | `SuspendRestoreAccountFl` |

A good mental model is:

- **Enable/Disable** controls whether the account can be used at all.
- **Elevate/Demote** controls what the account can do while it is enabled.

You can implement one pair without the other, but many JIT designs use both.

## Feature flags and parameters

SPP derives JIT capability flags from the operations present in the script:

- `ElevateDemoteAccountFl` is set when `ElevateAccount` or `DemoteAccount` is present.
- `SuspendRestoreAccountFl` is set when `EnableAccount` or `DisableAccount` is present.

You do not set these flags manually. They are inferred from your operation definitions. See [Operations](../reference/operations.md) for the full operation list.

### Key parameters

These are the parameters you will use most often in JIT scripts.

| Parameter | Source | Typical use |
| --- | --- | --- |
| `AccountUserName` | Auto-populated by SPP | The target account to enable, disable, elevate, or demote |
| `AdminGroupName` | Reserved, but manually configured | A single group or role name to grant or revoke |
| `PrivilegeGroupMembership` | JIT workflow context | Multiple groups or roles to add or remove |
| `FuncUserName` / `FuncPassword` | Auto-populated service account | Credentials used to make the target-side change |
| `Address` | Auto-populated asset address | SSH host or API endpoint |

A few practical notes:

- `AccountUserName` is the current reserved parameter name documented in [Reserved Parameters](../reference/reserved-parameters.md).
- `AdminGroupName` is useful when each asset or account maps to one fixed elevated group.
- `PrivilegeGroupMembership` is better when a request can map to multiple groups or roles.
- Older sample scripts may use legacy names such as `AccountUsername` or `FuncUsername`. Prefer the current reserved names in new scripts.

### Standard connection parameters

Use the normal transport parameters in addition to the JIT-specific ones.

**SSH platforms** typically include:

- `Address`
- `Port`
- `Timeout`
- `FuncUserName`
- `FuncPassword` or `UserKey`
- `CheckHostKey`
- `HostKey`

**HTTP platforms** typically include:

- `Address`
- `FuncUserName`
- `FuncPassword`
- `UseSsl`
- `SkipServerCertValidation`
- `HttpProxyUri`, `HttpProxyPort`, `HttpProxyUserName`, `HttpProxyPassword` when needed

For the complete reserved-parameter list, see [Reserved Parameters](../reference/reserved-parameters.md). For transport-specific guidance, see [SSH Platforms](ssh-platforms.md) and [HTTP Platforms](http-platforms.md).

### Minimal JIT operation skeleton

This is the minimal shape of a JIT-capable platform definition:

```json
{
  "ElevateAccount": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AdminGroupName": { "Type": "String", "Required": false } }
    ],
    "Do": [
      { "Return": { "Value": true } }
    ]
  },
  "DemoteAccount": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AdminGroupName": { "Type": "String", "Required": false } }
    ],
    "Do": [
      { "Return": { "Value": true } }
    ]
  },
  "EnableAccount": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } }
    ],
    "Do": [
      { "Return": { "Value": true } }
    ]
  },
  "DisableAccount": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } }
    ],
    "Do": [
      { "Return": { "Value": true } }
    ]
  }
}
```

In a real platform, the `Do` blocks perform the actual privilege change on the target.

## Implementation patterns for SSH platforms

SSH-backed JIT platforms usually log in with a service account and then run commands against the target account. See [SSH Platforms](ssh-platforms.md) for the transport patterns themselves.

### Common SSH elevation patterns

| Pattern | Elevate | Demote | Notes |
| --- | --- | --- | --- |
| Linux group membership | `usermod -aG admin user` | `gpasswd -d user admin` | Common for sudo/admin groups |
| Alternate group command | `gpasswd -a user admin` | `gpasswd -d user admin` | Often simpler than editing `/etc/group` directly |
| Sudoers drop-in | Create `/etc/sudoers.d/user-jit` | Remove `/etc/sudoers.d/user-jit` | Prefer a dedicated drop-in over editing `/etc/sudoers` inline |
| Directory-backed access via SSH | Run `net ads`, `realm`, `adcli`, PowerShell, or vendor tooling remotely | Reverse the same membership change | Useful when the only control plane you have is a privileged bastion host |

### Example: elevate by Linux group membership

This pattern checks membership first, then adds the user only if needed.

```json
{
  "ElevateAccount": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
      { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AdminGroupName": { "Type": "String", "Required": true } },
      { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
      { "HostKey": { "Type": "String", "Required": false } }
    ],
    "Do": [
      {
        "Connect": {
          "ConnectionObjectName": "Global:SshConnection",
          "Type": "Ssh",
          "NetworkAddress": "%Address%",
          "Port": "%Port%",
          "Login": "%FuncUserName%",
          "Password": "%FuncPassword::$%",
          "RequestTerminal": false,
          "CheckHostKey": "%CheckHostKey%",
          "Hostkey": "%HostKey::$%",
          "Timeout": "%Timeout%"
        }
      },
      {
        "ExecuteCommand": {
          "ConnectionObjectName": "SshConnection",
          "Command": "id -nG %AccountUserName% | grep -qw %AdminGroupName%",
          "BufferName": "Stdout",
          "StderrBufferName": "Stderr",
          "ExitStatusBufferName": "MembershipRc"
        }
      },
      {
        "Condition": {
          "If": "MembershipRc != 0",
          "Then": {
            "Do": [
              {
                "ExecuteCommand": {
                  "ConnectionObjectName": "SshConnection",
                  "Command": "sudo /usr/sbin/usermod -aG %AdminGroupName% %AccountUserName%",
                  "BufferName": "ElevateStdout",
                  "StderrBufferName": "ElevateStderr",
                  "ExitStatusBufferName": "ElevateRc"
                }
              },
              {
                "Condition": {
                  "If": "ElevateRc != 0",
                  "Then": {
                    "Do": [
                      { "Throw": { "Value": "Failed to add user to admin group: %ElevateStderr%" } }
                    ]
                  }
                }
              }
            ]
          }
        }
      },
      { "Disconnect": { "ConnectionObjectName": "SshConnection" } },
      { "Return": { "Value": true } }
    ]
  }
}
```

### Example: demote by removing the same membership

```json
{
  "DemoteAccount": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
      { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AdminGroupName": { "Type": "String", "Required": true } }
    ],
    "Do": [
      {
        "Function": {
          "Name": "RunSshCommand",
          "Parameters": [
            "%Address%",
            "%FuncUserName%",
            "%FuncPassword%",
            "id -nG %AccountUserName% | grep -qw %AdminGroupName%"
          ],
          "ResultVariable": "MembershipRc"
        }
      },
      {
        "Condition": {
          "If": "MembershipRc == 0",
          "Then": {
            "Do": [
              {
                "Function": {
                  "Name": "RunSshCommand",
                  "Parameters": [
                    "%Address%",
                    "%FuncUserName%",
                    "%FuncPassword%",
                    "sudo /usr/bin/gpasswd -d %AccountUserName% %AdminGroupName%"
                  ],
                  "ResultVariable": "DemoteRc"
                }
              },
              {
                "Condition": {
                  "If": "DemoteRc != 0",
                  "Then": {
                    "Do": [
                      { "Throw": { "Value": "Failed to remove user from admin group" } }
                    ]
                  }
                }
              }
            ]
          }
        }
      },
      { "Return": { "Value": true } }
    ]
  }
}
```

### Example commands for enable / disable

- Enable: `usermod -U user`, `passwd -u user`, or vendor-specific unlock command
- Disable: `usermod -L user`, `passwd -l user`, or vendor-specific disable command

If your platform uses account expiration instead of locking, enabling and disabling might be implemented by changing an expiry timestamp rather than a lock flag.

> [!NOTE]
> If the target account may already have durable admin access, do not use a shared production group for JIT. Prefer a **dedicated JIT-only group or sudoers drop-in** so `DemoteAccount` can remove it safely without stripping pre-existing permissions.

## Implementation patterns for HTTP platforms

HTTP-backed JIT platforms are usually the cleanest option when the target exposes an admin API. See [HTTP Platforms](http-platforms.md) for request-building, authentication, JSON parsing, cookies, and proxy handling.

### Common HTTP patterns

| Operation type | Typical REST action |
| --- | --- |
| `ElevateAccount` | `POST` or `PUT` to assign a role, add a user to a group, or attach a policy |
| `DemoteAccount` | `DELETE`, `PATCH`, or `PUT` to remove that role or membership |
| `EnableAccount` | `POST` or `PATCH` to activate, unlock, or enable a user |
| `DisableAccount` | `POST` or `PATCH` to suspend, deactivate, or disable a user |

### Example: add and remove a role through an API

```json
{
  "ElevateAccount": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AdminGroupName": { "Type": "String", "Required": true } },
      { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
      { "SkipServerCertValidation": { "Type": "Boolean", "Required": false, "DefaultValue": false } }
    ],
    "Do": [
      { "BaseAddress": { "Address": "https://%Address%" } },
      { "NewHttpRequest": { "ObjectName": "TokenRequest" } },
      {
        "Request": {
          "Verb": "POST",
          "Url": "/api/auth/token",
          "RequestObjectName": "TokenRequest",
          "ResponseObjectName": "TokenResponse",
          "Content": {
            "ContentType": "application/json",
            "Body": "{\"username\":\"%FuncUserName%\",\"password\":\"%FuncPassword%\"}"
          }
        }
      },
      { "ExtractJsonObject": { "JsonObjectName": "TokenResponse", "Name": "TokenJson" } },
      { "NewHttpRequest": { "ObjectName": "ElevateRequest" } },
      {
        "Headers": {
          "RequestObjectName": "ElevateRequest",
          "AddHeaders": {
            "Authorization": "Bearer %{TokenJson.access_token}%",
            "Accept": "application/json"
          }
        }
      },
      {
        "Request": {
          "Verb": "POST",
          "Url": "/api/users/%AccountUserName%/roles/%AdminGroupName%",
          "SubstitutionInUrl": true,
          "RequestObjectName": "ElevateRequest",
          "ResponseObjectName": "ElevateResponse"
        }
      },
      {
        "Condition": {
          "If": "ElevateResponse.StatusCode.ToString().Equals(\"OK\") || ElevateResponse.StatusCode.ToString().Equals(\"Conflict\")",
          "Then": { "Do": [{ "Return": { "Value": true } }] },
          "Else": { "Do": [{ "Throw": { "Value": "Failed to assign role: %ElevateResponse.StatusCode%" } }] }
        }
      }
    ]
  }
}
```

For the inverse operation, call the corresponding `DELETE`, `PATCH`, or provider-specific endpoint and treat `NotFound` or an "already removed" response as success.

### Example: enable and disable through an API

```json
{
  "EnableAccount": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } }
    ],
    "Do": [
      { "Function": { "Name": "ActivateUser", "Parameters": ["%Address%", "%FuncUserName%", "%FuncPassword%", "%AccountUserName%"], "ResultVariable": "Activated" } },
      { "Condition": { "If": "Activated != true", "Then": { "Do": [{ "Throw": { "Value": "Failed to enable account" } }] } } },
      { "Return": { "Value": true } }
    ]
  },
  "DisableAccount": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } }
    ],
    "Do": [
      { "Function": { "Name": "DeactivateUser", "Parameters": ["%Address%", "%FuncUserName%", "%FuncPassword%", "%AccountUserName%"], "ResultVariable": "Deactivated" } },
      { "Condition": { "If": "Deactivated != true", "Then": { "Do": [{ "Throw": { "Value": "Failed to disable account" } }] } } },
      { "Return": { "Value": true } }
    ]
  }
}
```

## Idempotency and pairing

JIT operations should be **idempotent**.

That means:

- `ElevateAccount` should succeed if the account is already elevated.
- `DemoteAccount` should succeed if the account is already demoted.
- `EnableAccount` should succeed if the account is already enabled.
- `DisableAccount` should succeed if the account is already disabled.

This matters because retries happen. A request may be replayed after a timeout, an admin may rerun a failed task, or the target may already be in the desired state because of a previous partial success.

### Practical idempotency rules

- **Check before you change.** Query current role membership, group membership, or enabled state first.
- **Treat already-in-desired-state responses as success.** Examples: HTTP `409 Conflict` on add, HTTP `404 Not Found` on remove, exit code meaning "not a member," or a user already active/inactive.
- **Use dedicated JIT entitlements.** Do not remove baseline access that predated the request.
- **Make the reverse operation truly symmetrical.** If elevate adds two roles, demote should remove those same two roles.

### Pairing guidance

Although SPP can derive a feature flag from either side of a pair, in practice you should implement both sides together:

- If you implement `ElevateAccount`, also implement `DemoteAccount`.
- If you implement `DemoteAccount`, also implement `ElevateAccount`.
- If you implement `EnableAccount`, also implement `DisableAccount`.
- If you implement `DisableAccount`, also implement `EnableAccount`.

An unpaired implementation usually creates operational drift: access is granted but not removed, or removed without a clean path to re-enable it.

## Error handling and recovery

JIT scripts often fail in the awkward middle ground between "nothing changed" and "everything changed." Plan for that explicitly.

### Partial elevation

A common example is multi-group or multi-role elevation:

- role A was assigned successfully
- role B failed
- the request is now only partially elevated

Recommended handling:

1. Log exactly which changes succeeded and which failed.
2. Decide whether to **rollback** the changes that already succeeded or **fail fast and require rerun**.
3. Throw an error when the required end state was not reached.
4. Keep demotion idempotent so the cleanup operation can be retried safely.

For high-value admin access, failing the task is usually better than silently leaving the account in a half-elevated state.

### Timeout during demotion

Demotion failures are especially important because they can leave standing privilege behind.

If `DemoteAccount` times out:

- return a failure so the task is visible to operators
- design the demotion logic so it can be retried safely
- make membership checks explicit so a rerun removes only what is still present
- log enough detail to support manual cleanup if necessary

### Suggested logging pattern

Useful log messages include:

- which account was targeted
- which group or role was being added or removed
- which API endpoint or command was executed
- whether the target was already in the desired state
- whether a rollback was attempted

## End-user experience

From the requester's point of view, this is simple:

1. They request access through SPP's normal access request workflow.
2. SPP handles approval, scheduling, and expiration.
3. Your custom platform script performs the actual privilege change on the target system.
4. When the request ends, SPP calls the reverse operation to clean up.

The user never needs to know whether the target-side change was done with SSH commands, REST API calls, directory tooling on a bastion host, or cloud-provider role APIs.

## Real-world examples

### OneLogin JIT

The repository already includes a JIT-focused OneLogin sample:

- [`../../samples/http/onelogin-jit/OneLogin_GRC_JIT_addon.json`](../../samples/http/onelogin-jit/OneLogin_GRC_JIT_addon.json)
- [`../../samples/http/README.md`](../../samples/http/README.md)

That sample is useful because it implements both pairs:

- `EnableAccount` / `DisableAccount`
- `ElevateAccount` / `DemoteAccount`

It also demonstrates a multi-role approach using `PrivilegeGroupMembership` rather than a single `AdminGroupName`.

### Linux group membership

A classic SSH implementation is:

- elevate with `usermod -aG` or `gpasswd -a`
- demote with `gpasswd -d`
- optionally combine with `usermod -U` and `usermod -L` for enable/disable

This works well when you want a temporary `sudo`, `wheel`, or application-admin group assignment.

### Cloud IAM role assignment

Cloud and SaaS platforms often map naturally to HTTP-based JIT:

- assign a temporary admin role, policy, or group membership on approval
- remove that role, policy, or membership on expiration
- enable the account only for the request window if the provider supports activation or suspension

The exact endpoint differs by provider, but the pattern is the same as any other `POST`/`DELETE` or `PUT`/`PATCH` role-management workflow.

## Related references

- [Operations](../reference/operations.md)
- [Reserved Parameters](../reference/reserved-parameters.md)
- [SSH Platforms](ssh-platforms.md)
- [HTTP Platforms](http-platforms.md)
