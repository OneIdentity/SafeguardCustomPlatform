# Platform Feature Flags

SPP uses platform feature flags to decide what a custom platform advertises. Those flags control which built-in fields appear on Assets and Accounts, which workflows SPP offers, and which profile settings become relevant.

> [!IMPORTANT]
> **Feature flags are automatic.** You do not configure them manually. When you upload a script, SPP validates its operations and reserved parameter names, then derives the platform's feature flags from that content.

For operation syntax, see the [Operations Reference](../reference/operations.md). For the exact reserved parameter names SPP recognizes, see [Reserved Parameters](../reference/reserved-parameters.md). For the commands used inside `Do` blocks, see the [Commands Reference](../reference/commands/index.md).

## Quick Reference

Use this table when you want to know, "What do I add to my script to make SPP expose this capability?"

| Capability | Flag | Add this to your script |
| --- | --- | --- |
| Check passwords | `PasswordFl` | `CheckPassword` with `AccountPassword` |
| Rotate passwords | `AccountPasswordFl` | `ChangePassword` with `AccountPassword` and `NewPassword` |
| Manage SSH keys | `SshKeyFl` | `CheckSshKey` |
| Manage API keys | `ApiKeyFl` | `CheckApiKey` |
| File-based workflows | `FileFeatureFl` | Nothing — always enabled |
| Discover SSH host keys | `SshHostKeyFl` | `DiscoverSshHostKey` |
| Discover accounts | `AccountDiscoveryFl` | `DiscoverAccounts` |
| Discover services | `ServiceDiscoveryFl` | `DiscoverServices` |
| Enable or disable accounts | `SuspendRestoreAccountFl` | `EnableAccount` or `DisableAccount` |
| Elevate or demote accounts | `ElevateDemoteAccountFl` | `ElevateAccount` or `DemoteAccount` |
| Discover authorized keys | `DiscoverSshKeyFl` | `DiscoverAuthorizedKeys` |
| Discover local assets | `LocalAssetDiscoveryFl` | Not available for custom platforms |
| Update dependent systems | `DependentSystemFl` | `UpdateDependentSystem` |
| Use custom dependency commands | `CustomDependencyFl` | `UpdateDependentSystem` with `DependentCommand` |
| Show the Port field | `PortFl` | Any operation with `Port` |
| Show the SSH Port field | `SshPortFl` | Any operation with `SshPort` |
| Show the SSL/TLS field | `UseSslFl` | Any operation with `UseSsl` |
| Show the Timeout field | `TimeoutFl` | Any operation with `Timeout` |
| Show the Check Host Key field | `CheckHostKeyFl` | Any operation with `CheckHostKey` |

## How Feature Flags Work

When you upload a custom platform script:

1. SPP validates the operations in the script.
2. SPP scans the declared parameter names for reserved names such as `AccountPassword`, `NewPassword`, `Port`, and `UseSsl`.
3. SPP computes the platform feature flags from that validation result.
4. SPP enables the matching built-in UI fields, behaviors, and workflows.

This means your script is the capability definition. If the required operation or parameter is missing, the flag is not set and the related UI or workflow does not appear.

## Complete Flag Mapping

This is the definitive mapping between script content and feature flags.

| Flag | Derived From |
| --- | --- |
| `PasswordFl` | `CheckPassword` operation with `AccountPassword` parameter |
| `SshKeyFl` | `CheckSshKey` operation present |
| `ApiKeyFl` | `CheckApiKey` operation present |
| `FileFeatureFl` | Always `true` for all custom platforms |
| `AccountPasswordFl` | `ChangePassword` operation with `AccountPassword` and `NewPassword` |
| `SshHostKeyFl` | `DiscoverSshHostKey` operation present |
| `AccountDiscoveryFl` | `DiscoverAccounts` operation present |
| `ServiceDiscoveryFl` | `DiscoverServices` operation present |
| `SuspendRestoreAccountFl` | `EnableAccount` or `DisableAccount` operation present |
| `ElevateDemoteAccountFl` | `ElevateAccount` or `DemoteAccount` operation present |
| `DiscoverSshKeyFl` | `DiscoverAuthorizedKeys` operation present |
| `LocalAssetDiscoveryFl` | `DiscoverAssets` plus internal `IsSystemOwned` flag (**not available to custom platforms**) |
| `DependentSystemFl` | `UpdateDependentSystem` operation present |
| `CustomDependencyFl` | `UpdateDependentSystem` with `DependentCommand` parameter |
| `PortFl` | Any operation with `Port` parameter |
| `SshPortFl` | Any operation with `SshPort` parameter |
| `UseSslFl` | Any operation with `UseSsl` parameter |
| `TimeoutFl` | Any operation with `Timeout` parameter |
| `CheckHostKeyFl` | Any operation with `CheckHostKey` parameter |

## What Each Flag Enables

### Password and Credential Workflows

- **`PasswordFl`**
  - Enables password verification behavior for managed accounts.
  - Makes SPP treat the platform as one that can validate an existing account password.
  - In practice, add `CheckPassword` with `AccountPassword` when you want manual or scheduled password checks.

- **`AccountPasswordFl`**
  - Enables password change and rotation workflows.
  - Makes password profile and scheduled password-change settings meaningful for this platform.
  - In practice, add `ChangePassword` with both `AccountPassword` and `NewPassword`.

- **`SshKeyFl`**
  - Enables SSH key management behavior for accounts that use this platform.
  - Makes SSH-key-oriented workflows and related account handling available.
  - The flag is derived from `CheckSshKey`; for a complete SSH key rotation solution, you will usually also add `ChangeSshKey`.

- **`ApiKeyFl`**
  - Enables API key management behavior for the platform.
  - Makes API-key check and related workflows available.
  - The flag is derived from `CheckApiKey`; for full rotation, pair it with `ChangeApiKey`.

- **`FileFeatureFl`**
  - Keeps file-based platform capability enabled for custom platforms.
  - No special script content is required to set this flag.
  - File-specific behavior still depends on the file operations you implement.

### Discovery and SSH Trust Workflows

- **`SshHostKeyFl`**
  - Enables SSH host-key discovery and related trust workflows.
  - Makes it possible for the platform to advertise SSH host-key handling.
  - Add `DiscoverSshHostKey` when you want SPP to retrieve host-key material from the target.

- **`AccountDiscoveryFl`**
  - Enables account discovery workflows.
  - Makes account-discovery jobs and their related discovery settings available for the platform.
  - Add `DiscoverAccounts` to emit discovered accounts.

- **`ServiceDiscoveryFl`**
  - Enables service discovery workflows.
  - Makes service-discovery behavior available where SPP supports it for the platform.
  - Add `DiscoverServices` when you need to discover Windows services, scheduled tasks, or similar service objects.

- **`DiscoverSshKeyFl`**
  - Enables authorized-key discovery workflows.
  - Makes SPP treat the platform as one that can inspect existing authorized keys.
  - Add `DiscoverAuthorizedKeys` when you want to discover keys already present for an account.

- **`LocalAssetDiscoveryFl`**
  - Would enable local asset discovery behavior.
  - Custom platforms cannot set the internal `IsSystemOwned` condition required for this flag.
  - Treat this capability as unavailable for custom platform authors today.

### Access and Privilege Workflows

- **`SuspendRestoreAccountFl`**
  - Enables account enable/disable behavior.
  - Makes suspend and restore style workflows available when SPP needs to toggle account access.
  - Add `EnableAccount`, `DisableAccount`, or both.

- **`ElevateDemoteAccountFl`**
  - Enables elevate and demote workflows.
  - Makes JIT-style privilege escalation and rollback behavior available for the platform.
  - Add `ElevateAccount`, `DemoteAccount`, or both.

### Dependency Workflows

- **`DependentSystemFl`**
  - Enables dependent-system update behavior.
  - Makes dependency-related settings in change workflows meaningful for the platform.
  - Add `UpdateDependentSystem` when password changes must also update downstream systems.

- **`CustomDependencyFl`**
  - Enables custom dependency command behavior.
  - Makes the custom dependency configuration in the change profile relevant because SPP can pass `DependentCommand` values into the script.
  - Add `DependentCommand` to the `UpdateDependentSystem` operation when you want the script to react to profile-defined dependency commands.

### Built-In Connection Fields

- **`PortFl`**
  - Shows the built-in **Port** field on the asset or platform configuration.
  - Lets your script consume `Port` as a reserved connection parameter instead of inventing a custom field.
  - Add `Port` to any operation that needs a configurable port.

- **`SshPortFl`**
  - Shows the built-in **SSH Port** field used for SSH session handling.
  - Useful when the platform needs an SSH session port that is distinct from the generic `Port` field.
  - Add `SshPort` to any operation that needs it.

- **`UseSslFl`**
  - Shows the built-in **Use SSL** or TLS-related setting.
  - Lets administrators control HTTPS or TLS behavior through a built-in field.
  - Add `UseSsl` to any operation that should honor that setting.

- **`TimeoutFl`**
  - Shows the built-in **Timeout** field.
  - Lets administrators tune connection or request timeout behavior through a built-in field.
  - Add `Timeout` to any operation that should use a configurable timeout.

- **`CheckHostKeyFl`**
  - Shows the built-in **Check Host Key** setting for SSH trust validation.
  - Lets administrators control whether the script should validate the target host key.
  - Add `CheckHostKey` to any SSH-based operation that should respect this platform setting.

## How to Enable a Flag

Use this checklist when a UI field or workflow is missing.

| If you want to enable... | Add to your script | Notes |
| --- | --- | --- |
| `PasswordFl` | `CheckPassword` + `AccountPassword` | Use the exact reserved parameter name `AccountPassword`. |
| `AccountPasswordFl` | `ChangePassword` + `AccountPassword` + `NewPassword` | Usually paired with a password profile for rotation. |
| `SshKeyFl` | `CheckSshKey` | Add `ChangeSshKey` too if you want actual key rotation. |
| `ApiKeyFl` | `CheckApiKey` | Add `ChangeApiKey` too if you want actual key rotation. |
| `FileFeatureFl` | Nothing | This flag is always on. |
| `SshHostKeyFl` | `DiscoverSshHostKey` | See [Operations Reference](../reference/operations.md#discoversshhostkey). |
| `AccountDiscoveryFl` | `DiscoverAccounts` | Use the discovery output commands documented in the [Commands Reference](../reference/commands/index.md). |
| `ServiceDiscoveryFl` | `DiscoverServices` | Pair with the right discovery output from your `Do` block. |
| `SuspendRestoreAccountFl` | `EnableAccount` or `DisableAccount` | Add both if you need full suspend/restore support. |
| `ElevateDemoteAccountFl` | `ElevateAccount` or `DemoteAccount` | Add both if you need full elevate/demote support. |
| `DiscoverSshKeyFl` | `DiscoverAuthorizedKeys` | Pair with the matching key-management operations as needed. |
| `DependentSystemFl` | `UpdateDependentSystem` | Use this when downstream systems must be updated after a credential change. |
| `CustomDependencyFl` | `UpdateDependentSystem` + `DependentCommand` | `DependentCommand` must use the exact reserved name. |
| `PortFl` | `Port` parameter in any operation | `Port` is a reserved parameter documented in [Reserved Parameters](../reference/reserved-parameters.md#core-credentials). |
| `SshPortFl` | `SshPort` parameter in any operation | Use when you need the SSH-session port specifically. |
| `UseSslFl` | `UseSsl` parameter in any operation | Good for HTTP or TLS-aware platforms. |
| `TimeoutFl` | `Timeout` parameter in any operation | Common on `CheckSystem`, `CheckPassword`, and HTTP request workflows. |
| `CheckHostKeyFl` | `CheckHostKey` parameter in any operation | Common on SSH `Connect`-based operations. |
| `LocalAssetDiscoveryFl` | You cannot enable this in a custom platform | Custom platforms cannot supply the required internal flag. |

## Troubleshooting

> [!TIP]
> When a feature flag does not appear after upload, the problem is usually the operation name or parameter name.

- **Verify the operation name is supported and spelled exactly right.** Use the [Operations Reference](../reference/operations.md).
- **Verify the parameter name is the exact reserved name SPP expects.** Use the [Reserved Parameters](../reference/reserved-parameters.md). For example, `AccountPassword` works, but a custom name such as `UserPassword` will not set `PasswordFl`.
- **Check both the operation and the parameter requirement.** Some flags need only an operation, while others require a specific reserved parameter too.
- **Re-upload the script after changes.** Feature flags are recomputed during validation of the uploaded script content.
- **Check the `Do` block only after the feature prerequisites are correct.** The feature flag comes from the operation and parameter declaration, not from the detailed command logic inside `Do`.
- **For discovery and dependency workflows, confirm that your implementation also uses the correct output or command patterns.** See the [Commands Reference](../reference/commands/index.md).
- **Do not expect `LocalAssetDiscoveryFl` to appear.** That capability depends on an internal condition custom platforms cannot set.

## Notes

> [!NOTE]
> `FileFeatureFl` is always `true` for custom platforms. You do not need to add anything to your script for that flag.

> [!WARNING]
> `LocalAssetDiscoveryFl` requires an internal `IsSystemOwned` condition that custom platforms cannot set. Even if you add discovery logic, this specific flag is not currently available for custom platforms.
