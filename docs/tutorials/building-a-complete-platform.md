# Building a Complete Platform

This tutorial takes you from a minimal custom platform script to a full-featured one with multiple operations. By the end, you'll have a platform that can check connectivity, validate passwords, change passwords, and discover accounts — all over SSH.

## Prerequisites

- Completed [Your First SSH Script](your-first-ssh-script.md) (or equivalent knowledge)
- A Linux target with SSH access and at least two user accounts
- SPP with `safeguard-ps` installed

## What You'll Build

A complete Linux SSH platform with these operations:

| Operation | Purpose |
| --- | --- |
| `CheckSystem` | Verify the service account can connect |
| `CheckPassword` | Validate a managed account's password |
| `ChangePassword` | Rotate a managed account's password |
| `DiscoverAccounts` | Find local accounts on the system |

## Step 1: Start with CheckSystem and CheckPassword

If you followed the first SSH tutorial, you already have a script with these two operations. If not, start with:

```json
{
  "Id": "MyCompletePlatform",
  "BackEnd": "Scriptable",
  "CheckSystem": {
    "Parameters": [
      { "Address": "" },
      { "Port": "22" },
      { "FuncUserName": "" },
      { "FuncPassword": "" }
    ],
    "Do": [
      { "Connect": { "Address": "%Address%", "Port": "%Port%", "UserName": "%FuncUserName%", "Password": "%FuncPassword%", "RequestTerminal": true } },
      { "Send": { "Text": "echo connected\n" } },
      { "Receive": { "Regex": "connected" } },
      { "Disconnect": {} }
    ]
  },
  "CheckPassword": {
    "Parameters": [
      { "Address": "" },
      { "Port": "22" },
      { "AccountUserName": "" },
      { "AccountPassword": "" }
    ],
    "Do": [
      { "Connect": { "Address": "%Address%", "Port": "%Port%", "UserName": "%AccountUserName%", "Password": "%AccountPassword%", "RequestTerminal": true } },
      { "Disconnect": {} }
    ]
  }
}
```

Upload and test:
```powershell
Import-SafeguardCustomPlatformScript -FilePath .\MyCompletePlatform.json
Test-SafeguardAssetConnection -AssetToUse "TestHost" -ExtendedLogging
Test-SafeguardAssetAccountPassword -AssetToUse "TestHost" -AccountToUse "testuser" -ExtendedLogging
```

## Step 2: Add ChangePassword

The `ChangePassword` operation connects with the service account (which has privileges to change other users' passwords) and runs `passwd`:

```json
"ChangePassword": {
  "Parameters": [
    { "Address": "" },
    { "Port": "22" },
    { "FuncUserName": "" },
    { "FuncPassword": "" },
    { "AccountUserName": "" },
    { "AccountPassword": "" },
    { "NewPassword": "" }
  ],
  "Do": [
    { "Connect": { "Address": "%Address%", "Port": "%Port%", "UserName": "%FuncUserName%", "Password": "%FuncPassword%", "RequestTerminal": true } },
    { "Send": { "Text": "sudo passwd %AccountUserName%\n" } },
    { "Receive": { "Regex": "[Nn]ew password:|[Pp]assword:" } },
    { "Send": { "Text": "%NewPassword%\n" } },
    { "Receive": { "Regex": "[Rr]etype|[Rr]e-enter|[Cc]onfirm|[Nn]ew password:" } },
    { "Send": { "Text": "%NewPassword%\n" } },
    { "Receive": { "Regex": "successfully|updated|\\$|#" } },
    { "Disconnect": {} }
  ]
}
```

Key points:
- `ChangePassword` connects with the **service account** (`FuncUserName`/`FuncPassword`), not the managed account.
- SPP provides `NewPassword` — you don't generate it yourself.
- The `Receive` patterns must match your target's `passwd` prompts.

Test with:
```powershell
Invoke-SafeguardAssetAccountPasswordChange -AssetToUse "TestHost" -AccountToUse "testuser"
```

## Step 3: Add DiscoverAccounts

The `DiscoverAccounts` operation connects and lists local accounts, then reports each one back to SPP using `WriteDiscoveredAccount`:

```json
"DiscoverAccounts": {
  "Parameters": [
    { "Address": "" },
    { "Port": "22" },
    { "FuncUserName": "" },
    { "FuncPassword": "" }
  ],
  "Do": [
    { "Connect": { "Address": "%Address%", "Port": "%Port%", "UserName": "%FuncUserName%", "Password": "%FuncPassword%", "RequestTerminal": false } },
    { "ExecuteCommand": { "Command": "awk -F: '$3 >= 1000 && $7 !~ /nologin|false/ {print $1}' /etc/passwd", "Output": "accounts" } },
    { "Split": { "Text": "%accounts.StdOut%", "Delimiter": "\n", "Output": "accountList" } },
    {
      "ForEach": {
        "Item": "acct",
        "In": "%accountList%",
        "Do": [
          {
            "Condition": {
              "If": "acct != ''",
              "Then": {
                "Do": [
                  { "WriteDiscoveredAccount": { "AccountName": "%acct%" } }
                ]
              }
            }
          }
        ]
      }
    },
    { "Disconnect": {} }
  ]
}
```

Key points:
- Uses `ExecuteCommand` (batch mode with `RequestTerminal: false`) instead of interactive Send/Receive.
- Filters `/etc/passwd` for real user accounts (UID >= 1000, no nologin shell).
- Calls `WriteDiscoveredAccount` once per account — this is how SPP learns about discovered accounts.

## Step 4: Put It All Together

Your complete script now has four operations. Upload the final version and verify all operations work:

```powershell
# Re-upload (replaces the previous version)
Import-SafeguardCustomPlatformScript -FilePath .\MyCompletePlatform.json

# Test each operation
Test-SafeguardAssetConnection -AssetToUse "TestHost" -ExtendedLogging
Test-SafeguardAssetAccountPassword -AssetToUse "TestHost" -AccountToUse "testuser" -ExtendedLogging
Invoke-SafeguardAssetAccountPasswordChange -AssetToUse "TestHost" -AccountToUse "testuser"
```

Account discovery runs on a schedule configured in SPP — you can trigger it manually from the web UI under **Asset Management > Discovery**.

## What SPP Knows About Your Platform

Because your script contains these four operations, SPP automatically sets these feature flags:

| Flag | Set because |
| --- | --- |
| `PasswordFl` | `CheckPassword` is present |
| `AccountPasswordFl` | `ChangePassword` is present |
| `AccountDiscoveryFl` | `DiscoverAccounts` is present |

You never configure these manually — they're derived from your script. See [Feature Flags](../concepts/feature-flags.md) for the full list.

## Next Steps

From here you can extend your platform further:

- **SSH key management** — Add `CheckSshKey`, `ChangeSshKey`, `DiscoverAuthorizedKeys`. See [SSH Key Management Guide](../guides/ssh-key-management.md).
- **Host key discovery** — Add `DiscoverSshHostKey`. See the [generic-linux-with-discovery](../../samples/ssh/generic-linux-with-discovery/) sample.
- **Error handling** — Wrap operations in `Try`/`Catch` for resilient behavior. See [Error Handling Guide](../guides/error-handling.md).
- **Import libraries** — Use `Imports` to pull in reusable SSH functions. See [Imports Reference](../reference/imports.md).

For a production-ready example of everything combined, study the [GenericLinuxWithSSHKeySupport](../../samples/ssh/generic-linux-ssh-keys/) sample.
