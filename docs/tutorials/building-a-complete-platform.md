[← Tutorials](README.md)

# Building a Complete Platform

This tutorial picks up where [Your First SSH Script](your-first-ssh-script.md) left off. You already have a working platform with `CheckSystem`, `CheckPassword`, and `ChangePassword`. Now you'll add account discovery, reusable functions, error handling, and structured logging to turn it into a production-quality platform.

## Prerequisites

- Completed [Your First SSH Script](your-first-ssh-script.md) — you should have a working script with `CheckSystem`, `CheckPassword`, and `ChangePassword`
- A Linux target with SSH access and at least two local user accounts
- SPP with `safeguard-ps` installed

## What You'll Add

| Capability | What it does |
| --- | --- |
| `DiscoverAccounts` | Automatically finds local accounts on the system |
| Reusable `Functions` | Eliminates duplicated connection logic across operations |
| `Try`/`Catch` error handling | Makes operations resilient instead of crashing on unexpected output |
| Status messages | Reports progress back to SPP during long-running operations |

## Step 1: Add DiscoverAccounts

Account discovery lets SPP automatically find accounts on the managed system instead of requiring manual entry. The operation connects, queries the system for accounts, and reports each one back using `WriteDiscoveredAccount`.

Because discovery only reads data (no interactive prompts), it works well with `ExecuteCommand` in batch mode (`RequestTerminal: false`):

```json
"DiscoverAccounts": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
    { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": false } },
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
        "Command": "awk -F: '$3 >= 1000 && $7 !~ /nologin|false/ {print $1}' /etc/passwd",
        "ResultVariable": "Result"
      }
    },
    {
      "Condition": {
        "If": "(Result.rc != 0)",
        "Then": { "Do": [
          { "Throw": { "Message": "Failed to query accounts: %{ Result.Stderr }%" } }
        ] }
      }
    },
    {
      "ForEach": {
        "Item": "acct",
        "In": "%{ Result.Stdout.Split('\\n') }%",
        "Do": [
          {
            "Condition": {
              "If": "acct != ''",
              "Then": { "Do": [
                { "WriteDiscoveredAccount": { "AccountName": "%acct%" } }
              ] }
            }
          }
        ]
      }
    },
    {
      "Disconnect": { "ConnectionObjectName": "SshConnection" }
    }
  ]
}
```

Key points:

- **`RequestTerminal: false`** — batch mode sends a command and captures stdout/stderr directly, without needing `Send`/`Receive` prompt matching.
- **`ExecuteCommand`** — runs a single command and returns `Result.Stdout`, `Result.Stderr`, and `Result.rc` (exit code).
- **`ForEach`** — iterates over the split output, one account name per line.
- **`WriteDiscoveredAccount`** — reports each account to SPP. This is how discovery populates the account list.
- The `awk` filter keeps only real user accounts (UID ≥ 1000, active shell).

Test discovery from SPP's web UI under **Asset Management > Discovery**, or trigger it with:

```powershell
Invoke-SafeguardAssetAccountDiscovery -AssetToUse "TestHost"
```

## Step 2: Extract Reusable Functions

Your script now has four operations, and three of them (`CheckSystem`, `CheckPassword`, `ChangePassword`) all contain similar connection logic. This is a maintenance burden. If you need to change the connection pattern, you'd have to update it in three places.

Extract the common login logic into a function:

```json
"LoginSsh": {
  "Parameters": [
    { "UserName": { "Type": "String", "Required": true } },
    { "Password": { "Type": "Secret", "Required": false } }
  ],
  "Do": [
    {
      "Connect": {
        "ConnectionObjectName": "Global:SshConnection",
        "Type": "Ssh",
        "NetworkAddress": "%Address%",
        "Port": "%Port%",
        "Login": "%UserName%",
        "Password": "%Password::$%",
        "RequestTerminal": "%RequestTerminal%",
        "CheckHostKey": "%CheckHostKey%",
        "Hostkey": "%HostKey::$%",
        "Timeout": "%Timeout%"
      }
    },
    { "Return": { "Value": true } }
  ]
}
```

Then simplify each operation to call the function:

```json
"CheckSystem": {
  "Parameters": [ ... ],
  "Do": [
    { "Function": { "Name": "LoginSsh", "Parameters": ["%FuncUserName%", "%FuncPassword%"] } },
    { "Disconnect": { "ConnectionObjectName": "SshConnection" } },
    { "Return": { "Value": true } }
  ]
}
```

Functions are defined as top-level keys in the script (alongside operations like `CheckSystem`). SPP distinguishes them from operations because they aren't in the list of recognized operation names. Functions can access variables from the calling operation's `Parameters` that are marked `Global:` or passed explicitly.

## Step 3: Add Error Handling with Try/Catch

Without error handling, any unexpected output (a different prompt format, a timeout, an unexpected error message) causes the entire operation to fail with a generic error. Wrapping critical sections in `Try`/`Catch` gives you control over failure behavior:

```json
{
  "Try": {
    "Do": [
      { "Send": { "ConnectionObjectName": "SshConnection", "Buffer": "sudo passwd %AccountUserName%" } },
      { "Receive": { "ConnectionObjectName": "SshConnection", "BufferName": "PromptResult", "ExpectRegex": "([Nn]ew.*[Pp]assword:)|([Pp]assword:)" } },
      { "Send": { "ConnectionObjectName": "SshConnection", "Buffer": "%NewPassword%", "ContainsSecret": true } },
      { "Receive": { "ConnectionObjectName": "SshConnection", "BufferName": "PromptResult", "ExpectRegex": "([Rr]etype|[Rr]e-enter|[Cc]onfirm).*[Pp]assword:" } },
      { "Send": { "ConnectionObjectName": "SshConnection", "Buffer": "%NewPassword%", "ContainsSecret": true } },
      { "Receive": { "ConnectionObjectName": "SshConnection", "BufferName": "ChangeResult", "ExpectRegex": "(updated successfully)|(\\$\\s*$)|(#\\s*$)" } }
    ],
    "Catch": {
      "Do": [
        { "Log": { "Text": "ChangePassword failed: %{Exception.Message}%" } },
        { "Disconnect": { "ConnectionObjectName": "SshConnection" } },
        { "Return": { "Value": false } }
      ]
    }
  }
}
```

The `Catch` block runs when any command in the `Try` block throws — whether from a `Receive` timeout, a connection drop, or an explicit `Throw`. This lets you:

- Log the failure reason for troubleshooting
- Disconnect cleanly instead of leaving orphaned sessions
- Return `false` to signal the operation failed without crashing the entire task

## Step 4: Add Status Messages

For operations that take time (connecting, changing passwords, running discovery), status messages keep the SPP UI informed about progress:

```json
{ "Status": { "Type": "Changing", "Percent": 10, "Message": { "Name": "ConnectingToHost", "Parameters": ["%Address%"] } } }
```

Add these at key points in your operations:

```json
"ChangePassword": {
  "Do": [
    { "Status": { "Type": "Changing", "Percent": 10, "Message": { "Name": "ConnectingToHost", "Parameters": ["%Address%"] } } },
    { "Function": { "Name": "LoginSsh", "Parameters": ["%FuncUserName%", "%FuncPassword%"] } },
    { "Status": { "Type": "Changing", "Percent": 40, "Message": { "Name": "ChangingPassword", "Parameters": ["%AccountUserName%"] } } },
    ...password change logic...,
    { "Status": { "Type": "Changing", "Percent": 90, "Message": { "Name": "DisconnectingFromHost" } } },
    { "Disconnect": { "ConnectionObjectName": "SshConnection" } },
    { "Return": { "Value": true } }
  ]
}
```

The `Percent` values give SPP a progress bar. The `Message` `Name` values are status message keys — see [Status Messages Reference](../reference/status-messages.md) for the full list of built-in keys.

## Step 5: Verify Everything

Upload and run through all operations:

```powershell
Import-SafeguardCustomPlatformScript -FilePath .\MyCompletePlatform.json

# CheckSystem
Test-SafeguardAssetConnection -AssetToUse "TestHost" -ExtendedLogging

# CheckPassword
Test-SafeguardAssetAccountPassword -AssetToUse "TestHost" -AccountToUse "testuser" -ExtendedLogging

# ChangePassword
Invoke-SafeguardAssetAccountPasswordChange -AssetToUse "TestHost" -AccountToUse "testuser"

# DiscoverAccounts — trigger from the web UI or wait for the configured schedule
```

Review logs with `Get-SafeguardTaskLog` after each test. With error handling in place, failures will show your custom log messages instead of raw exceptions.

## What SPP Knows About Your Platform

Because your script contains these operations, SPP automatically derives feature flags:

| Flag | Set because |
| --- | --- |
| `PasswordFl` | `CheckPassword` is present |
| `AccountPasswordFl` | `ChangePassword` is present |
| `AccountDiscoveryFl` | `DiscoverAccounts` is present |

You never configure these manually — they're derived from your script content. See [Feature Flags](../concepts/feature-flags.md) for the full list.

## Next Steps

From here you can extend your platform further:

- **SSH key management** — Add `CheckSshKey`, `ChangeSshKey`, `DiscoverAuthorizedKeys`. See [SSH Key Management Guide](../guides/ssh-key-management.md).
- **Host key discovery** — Add `DiscoverSshHostKey`. See the [generic-linux-with-discovery](../../samples/ssh/generic-linux-with-discovery/) sample.
- **Import libraries** — Use `Imports` to share functions across multiple platform scripts. See [Imports Reference](../reference/imports.md).
- **Dependent systems** — Add `UpdateDependentSystem` to propagate password changes. See the [dependent systems template](../../templates/Pattern-GenericLinuxDependentSystem.json).

For a production-ready example of everything combined, study the [GenericLinuxWithSSHKeySupport](../../samples/ssh/generic-linux-ssh-keys/) sample.
