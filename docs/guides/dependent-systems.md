# Dependent Systems Guide

## Table of Contents

- [What dependent systems are](#what-dependent-systems-are)
- [How the workflow runs](#how-the-workflow-runs)
- [The `UpdateDependentSystem` operation](#the-updatedependentsystem-operation)
- [Feature flags](#feature-flags)
- [Reserved parameters you will use](#reserved-parameters-you-will-use)
- [A practical `UpdateDependentSystem` skeleton](#a-practical-updatedependentsystem-skeleton)
- [When to use `ExecuteDependentCommand`](#when-to-use-executedependentcommand)
- [SSH implementation patterns](#ssh-implementation-patterns)
- [HTTP implementation patterns](#http-implementation-patterns)
- [Custom dependency commands from the Change Profile](#custom-dependency-commands-from-the-change-profile)
- [How admins configure dependent relationships in SPP](#how-admins-configure-dependent-relationships-in-spp)
- [Error handling and task outcomes](#error-handling-and-task-outcomes)
- [Related references](#related-references)

## What dependent systems are

In Safeguard, a **dependent system** is any downstream system that also uses the credential from a primary account. When the primary account password or key changes, those downstream systems must be updated so they keep working.

Common examples include:

- Windows services, IIS app pools, COM+ applications, and scheduled tasks
- Linux or Unix services restarted with `systemctl restart`
- Config files that store a password, SSH key, or connection string
- Other applications that cache API credentials or service-account secrets

The goal is simple: **rotate the primary credential without breaking everything that depends on it**.

## How the workflow runs

This is the normal dependent-update flow in SPP:

1. The primary account credential changes on Asset A.
2. SPP looks up the dependent relationships configured for that account and profile.
3. For each dependent asset or account, SPP calls `UpdateDependentSystem` with the new credential context.
4. Your script updates the dependent system so it starts using the new password or key.

If one primary account has multiple dependencies, SPP calls `UpdateDependentSystem` once per dependency.

## The `UpdateDependentSystem` operation

[`UpdateDependentSystem`](../reference/operations.md#updatedependentsystem) is the custom-platform entry point for dependent updates. SPP calls it **after the primary change succeeds**.

Use it when your platform needs to do one or more of these things on a downstream system:

- rewrite a service account password in local configuration
- restart a service after the credential update
- call an API to replace a stored secret
- run an administrator-configured helper command on the dependent asset

The operation usually runs with:

- the dependent asset connection context (`Address`, `FuncUserName`, `FuncPassword`)
- the dependent account context (`DependentAccountUserName`, `DependentAccountPassword`, `DependentNewPassword`)
- optional dependency metadata such as alternate username, account type, namespace, or custom command settings

## Feature flags

SPP derives dependency-related feature flags from the script content:

| Flag | How it is set | Why it matters |
| --- | --- | --- |
| `DependentSystemFl` | Declare `UpdateDependentSystem` | Tells SPP the platform supports dependent-system updates. |
| `CustomDependencyFl` | Declare `DependentCommand` inside `UpdateDependentSystem` | Tells SPP the platform can receive a Change Profile custom dependency command. |

For the exact mapping, see [Platform Feature Flags](feature-flags.md) and [Operations Reference](../reference/operations.md#updatedependentsystem).

## Reserved parameters you will use

The full list lives in [Reserved Parameters](../reference/reserved-parameters.md#dependent-system-updates). These are the ones you will reach for most often.

### Core dependent credential context

| Parameter | Purpose |
| --- | --- |
| `DependentAccountUserName` | Username of the dependent account being updated. |
| `DependentAccountPassword` | Current credential currently in use on the dependent side. |
| `DependentNewPassword` | New password SPP wants the dependent system to start using. |

### Dependent SSH key context

| Parameter | Purpose |
| --- | --- |
| `DependentSshKey` | Current dependent public SSH key. |
| `DependentSshKeyComment` | Current dependent key comment. |
| `DependentSshPrivateKey` | Current dependent private SSH key. |
| `DependentSshKeyType` | Current dependent SSH key type. |

### Custom dependency and metadata parameters

| Parameter | Purpose |
| --- | --- |
| `DependentCommand` | Custom command text configured in the Change Profile. |
| `CommandArguments` | Command-line arguments configured with the custom dependency command. |
| `StdinArguments` | Ordered stdin lines piped to the command. |
| `ReportExitStatus` | Whether the command's exit code should be treated as task result data. |
| `DependentAltUsername` | Alternate username for the dependent account. |
| `DependentAccountType` | Type or category of dependent account. |
| `DependentUserNamespace` | Namespace for the dependent user. Useful for Kubernetes-style or multi-tenant targets. |

> If you declare one of these names, SPP recognizes it as a reserved parameter and populates it from dependency and profile data instead of expecting the admin to type it into Custom Script Parameters.

## A practical `UpdateDependentSystem` skeleton

This example shows the common SSH batch-mode pattern: connect to the dependent asset, run the configured custom dependency command, optionally honor `ReportExitStatus`, then return success.

```json
{
  "UpdateDependentSystem": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
      { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": false } },
      { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
      { "HostKey": { "Type": "String", "Required": false } },
      { "DependentAccountUserName": { "Type": "String", "Required": true } },
      { "DependentNewPassword": { "Type": "Secret", "Required": true } },
      { "DependentCommand": { "Type": "String", "Required": false } },
      { "CommandArguments": { "Type": "String", "Required": false } },
      { "StdinArguments": { "Type": "Array", "Required": false } },
      { "ReportExitStatus": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
    ],
    "Do": [
      {
        "Connect": {
          "ConnectionObjectName": "Global:ConnectSsh",
          "Type": "Ssh",
          "NetworkAddress": "%Address%",
          "Port": "%Port%",
          "Login": "%FuncUserName%",
          "Password": "%FuncPassword::$%",
          "RequestTerminal": false,
          "CheckHostKey": "%CheckHostKey%",
          "HostKey": "%HostKey::$%",
          "Timeout": "%Timeout%"
        }
      },
      {
        "ExecuteDependentCommand": {
          "ConnectionObjectName": "ConnectSsh",
          "DependentCommand": "%DependentCommand::$%",
          "CommandArguments": "%CommandArguments::$%",
          "StdinArguments": "%{ StdinArguments }%",
          "BufferName": "Stdout",
          "StderrBufferName": "Stderr",
          "ExitStatusBufferName": "rc",
          "CommandBufferName": "ResolvedCommand"
        }
      },
      {
        "Condition": {
          "If": "ReportExitStatus && rc != 0",
          "Then": {
            "Do": [
              {
                "Throw": {
                  "Value": "Dependent update failed. Command: %ResolvedCommand% Error: %Stderr::$%"
                }
              }
            ]
          }
        }
      },
      { "Disconnect": { "ConnectionObjectName": "ConnectSsh" } },
      { "Return": { "Value": true } }
    ]
  }
}
```

Use this pattern when the dependent update is fundamentally "run a command on the dependent asset with SPP-provided inputs." For more detail, see [`ExecuteDependentCommand`](../reference/commands/execute-dependent-command.md).

## When to use `ExecuteDependentCommand`

[`ExecuteDependentCommand`](../reference/commands/execute-dependent-command.md) is the fastest path when:

- the dependent target is reachable over SSH
- the admin should be able to configure the exact helper command in the Change Profile
- your script mostly needs to pass through `DependentCommand`, `CommandArguments`, and `StdinArguments`
- the update can be treated like a single remote command with stdout, stderr, and exit status

It resolves the configured command, runs it on an existing SSH batch connection, and gives your script the resolved command text, stdout, stderr, and numeric exit code.

Prefer **custom logic** instead of `ExecuteDependentCommand` when:

- you need several steps, branching, or retries
- the target is HTTP-based rather than SSH-based
- you want the command path to be fixed in the script rather than admin-supplied
- the update must combine dependency data with additional API calls, file edits, or validation

> `ExecuteDependentCommand` does **not** invoke another custom-platform script. It runs a command on the dependent asset inside the current `UpdateDependentSystem` operation.

## SSH implementation patterns

If the dependent target is Linux, Unix, or a Windows SSH host, the most common patterns are:

### Restart a service after replacing the secret

A helper script updates the config file, then the platform restarts the service.

```json
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "sudo systemctl restart my-application",
    "BufferName": "RestartOut",
    "StderrBufferName": "RestartErr",
    "ExitStatusBufferName": "restartRc"
  }
}
```

### Update a config file that stores the password

Typical examples include `.env` files, YAML configuration, or application-specific secrets files. A helper command might:

- replace the old password with `%DependentNewPassword%`
- write a new connection string that embeds the updated secret
- reload or restart the process afterward

A common Change Profile command for this looks like:

```json
{
  "DependentCommand": "/usr/local/bin/update-app-secret",
  "CommandArguments": "\"%DependentAccountUserName%\" \"/etc/my-app/appsettings.json\"",
  "StdinArguments": ["%DependentNewPassword%"],
  "ReportExitStatus": true
}
```

### Update a connection string on the dependent host

When the application stores a DSN or JDBC-style string, keep the parsing logic in your helper script and let SPP supply the new secret. This keeps the custom platform small and makes the target-specific parsing easier to test outside SPP.

For broader SSH guidance, see [SSH Platforms Guide](ssh-platforms.md).

## HTTP implementation patterns

Not every dependent system is best updated with SSH. If the downstream service exposes an API, implement the update directly in `UpdateDependentSystem`.

This example pushes the new password into a downstream configuration API.

```json
{
  "UpdateDependentSystem": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "DependentAccountUserName": { "Type": "String", "Required": true } },
      { "DependentAltUsername": { "Type": "String", "Required": false } },
      { "DependentAccountType": { "Type": "String", "Required": false } },
      { "DependentUserNamespace": { "Type": "String", "Required": false } },
      { "DependentNewPassword": { "Type": "Secret", "Required": true } }
    ],
    "Do": [
      { "BaseAddress": { "Address": "https://%Address%" } },
      { "NewHttpRequest": { "ObjectName": "UpdateReq" } },
      {
        "Headers": {
          "ObjectName": "UpdateReq",
          "Headers": [
            { "Name": "X-Admin-User", "Value": "%FuncUserName%" },
            { "Name": "X-Admin-Secret", "Value": "%FuncPassword%" }
          ]
        }
      },
      {
        "Request": {
          "Verb": "Put",
          "Url": "/api/dependent-accounts/%DependentAccountUserName%",
          "RequestObjectName": "UpdateReq",
          "ResponseObjectName": "UpdateResp",
          "Content": {
            "ContentType": "application/json",
            "Body": "{\"username\":\"%DependentAccountUserName%\",\"altUsername\":\"%DependentAltUsername%\",\"accountType\":\"%DependentAccountType%\",\"namespace\":\"%DependentUserNamespace%\",\"newPassword\":\"%DependentNewPassword%\"}"
          }
        }
      },
      {
        "Condition": {
          "If": "!UpdateResp.StatusCode.ToString().Equals(\"OK\")",
          "Then": {
            "Do": [
              { "Throw": { "Value": "Dependent API update failed: %UpdateResp.StatusCode%" } }
            ]
          }
        }
      },
      { "Return": { "Value": true } }
    ]
  }
}
```

This pattern is a good fit when the downstream service stores API credentials, application secrets, or other connection settings in its own control plane.

## Custom dependency commands from the Change Profile

A **custom dependency command** is administrator-supplied runtime behavior. The admin configures it in the Change Profile UI, and SPP passes the values into your script through reserved parameters.

That means:

- `DependentCommand` contains the command text
- `CommandArguments` contains the command-line arguments
- `StdinArguments` contains ordered stdin lines
- `ReportExitStatus` tells your script whether a non-zero exit code should be treated as a failure signal

This is useful when you want one reusable custom platform but different customers need different helper scripts on their dependent assets.

Important practical notes:

- Safeguard does **not** validate the command for you.
- The command must already exist on the dependent asset and be reachable by the service account.
- Keep secrets in `StdinArguments` when possible instead of command-line arguments.
- Quote `CommandArguments` correctly when arguments may contain spaces.

## How admins configure dependent relationships in SPP

### UI overview

At a high level, admins configure dependent updates in two places:

1. **On the asset:** define which accounts are dependent on that asset.
   - In the SPP web client, go to **Asset Management > Assets**.
   - Open the asset.
   - Use the **Account Dependencies** tab to add the dependent account relationship.

2. **On the profile:** define what should happen when the primary credential changes.
   - Go to **Asset Management > Partitions**.
   - Open the relevant **Password Profile** or **SSH Key Profile**.
   - On **Change Password** or **Change SSH Key**, enable the built-in dependent actions you want.
   - For Linux, Unix, and Windows SSH platforms, use the **Dependent Systems** tab to configure a custom command, command-line arguments, stdin arguments, and exit-status behavior.

Common built-in profile options include updating services, restarting services, updating scheduled tasks, and updating IIS or COM+ applications.

On Linux and Unix, dependent relationships are typically configured manually. Safeguard can run custom dependency commands there, but it does not automatically discover services or dependencies for you.

### API overview

For API-driven administration, the important endpoints are:

- `GET /v4/Assets/{id}/DependentAccounts` - list the dependent accounts for an asset
- `PUT /v4/Assets/{id}/DependentAccounts` - replace the dependent-account set on an asset
- `PUT /v4/Assets/{id}/DependentAccounts/{operation}` - add or remove dependent accounts
- `POST /v4/Assets/{id}/UpdateDependentAsset` - manually trigger a dependent update using the current profile settings

Profile-side custom dependency settings are represented in schedule/profile API models such as `ScheduleCustomDependency`, which includes command text, command-line arguments, stdin argument lists, and `ReportExitStatus`.

## Error handling and task outcomes

Design `UpdateDependentSystem` as a **follow-up** step, not as the primary change itself.

A good implementation should:

- fail fast when the downstream update is required for correctness
- capture stdout, stderr, and exit code for troubleshooting
- throw clear errors that tell the operator what dependent system failed and why
- avoid logging secrets unless you intentionally opt in

A few important Safeguard behaviors to keep in mind:

- `UpdateDependentSystem` runs after the primary credential change has already succeeded.
- If the dependent update fails, SPP marks that dependent update task as failed.
- SPP does **not** roll back the already-completed primary password or key change.
- If `ReportExitStatus` is `false` for a post/fail custom dependency command, the command can ignore non-zero exit codes and still report success.

In practice, that means your script should make failures easy to diagnose. Include enough context in thrown errors to identify the asset, account, command, or downstream API call that failed, but do not include raw secrets.

## Related references

- [Operations Reference](../reference/operations.md#updatedependentsystem)
- [Reserved Parameters](../reference/reserved-parameters.md#dependent-system-updates)
- [ExecuteDependentCommand](../reference/commands/execute-dependent-command.md)
- [SSH Platforms Guide](ssh-platforms.md)
