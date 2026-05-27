# Your First SSH Script

By the end of this tutorial, you will have a working custom platform script that connects to a Linux host over SSH, verifies that the service account can log in with `CheckSystem`, and validates a managed account password with `CheckPassword`.

## What You'll Build

You will build a minimal custom platform script with two operations:

- `CheckSystem` — connects over SSH and verifies the service account can log in.
- `CheckPassword` — connects over SSH and attempts login with the managed account credentials.

This is intentionally small. It is the quickest way to get from zero to a working SSH platform before you add more advanced features.

## Prerequisites

Before you start, make sure you have:

- A Linux target with SSH access. A VM or container is fine.
- An SPP appliance and the `safeguard-ps` PowerShell module. If you have not used that workflow before, read [Development Workflow](development-workflow.md).
- Basic familiarity with JSON.

## Step 1: Create the Script Skeleton

Create a new file named `MyFirstSshPlatform.json` and start with this minimal structure:

```json
{
  "Id": "MyFirstSshPlatform",
  "BackEnd": "Scriptable",
  "CheckSystem": {
    "Parameters": [],
    "Do": []
  }
}
```

Here is what each top-level field means:

- `Id` — the internal identifier for the script.
- `BackEnd` — always `"Scriptable"` for a custom platform script.
- `CheckSystem` — one operation in your script. Each operation has a `Parameters` array and a `Do` block.

Think of `Parameters` as the inputs SPP passes to the operation and `Do` as the list of commands the script engine runs.

## Step 2: Add Parameters for CheckSystem

Next, define the SSH connection parameters that SPP will auto-populate when the operation runs:

```json
"CheckSystem": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
    { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": false } },
    { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "HostKey": { "Type": "String", "Required": false } },
    { "RequestTerminal": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
  ],
  "Do": []
}
```

These parameters give your script the basic information it needs to open an SSH session:

- `Address` — the target hostname or IP address from the asset.
- `Port` — the SSH port. It defaults to `22`.
- `Timeout` — the SSH connection timeout in seconds.
- `FuncUserName` / `FuncPassword` — the service account credentials from the asset.
- `CheckHostKey` / `HostKey` — SSH host key verification settings.
- `RequestTerminal` — whether the connection should request a PTY.

For this first script, you do not need any custom parameters. The built-in SSH parameters are enough.

## Step 3: Write the CheckSystem Do Block

Now add the actual work for `CheckSystem`:

```json
"Do": [
  {
    "Connect": {
      "ConnectionObjectName": "Global:SshConnection",
      "Type": "Ssh",
      "NetworkAddress": "%Address%",
      "Port": "%Port%",
      "Login": "%FuncUserName%",
      "Password": "%FuncPassword::$%",
      "RequestTerminal": "%RequestTerminal%",
      "CheckHostKey": "%CheckHostKey%",
      "Hostkey": "%HostKey::$%",
      "Timeout": "%Timeout%"
    }
  },
  {
    "Disconnect": { "ConnectionObjectName": "SshConnection" }
  },
  {
    "Return": { "Value": true }
  }
]
```

This is the smallest useful `CheckSystem` implementation:

- `Connect` opens an SSH connection using the parameter values.
- `%ParameterName%` inserts the value of a parameter at runtime.
- `%FuncPassword::$%` means "use the password value, or an empty string if it is null." That makes the field safe even when a password is not supplied.
- `Global:SshConnection` creates a connection object that can be reused elsewhere in the script if you later add helper functions.
- `Hostkey` is the `Connect` property name, and it is fed from the `HostKey` parameter.
- `Disconnect` closes the connection cleanly.
- `Return` with `true` tells SPP the operation succeeded.

At this point, your script proves one thing: the target is reachable over SSH and the service account can authenticate.

## Step 4: Add CheckPassword

Next, add a second operation to the same script. `CheckPassword` needs the same SSH connection settings plus the managed account credentials:

```json
"CheckPassword": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
    { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": false } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "AccountPassword": { "Type": "Secret", "Required": true } },
    { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "HostKey": { "Type": "String", "Required": false } },
    { "RequestTerminal": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
  ],
  "Do": [
    {
      "Connect": {
        "ConnectionObjectName": "Global:SshConnection",
        "Type": "Ssh",
        "NetworkAddress": "%Address%",
        "Port": "%Port%",
        "Login": "%AccountUserName%",
        "Password": "%AccountPassword::$%",
        "RequestTerminal": "%RequestTerminal%",
        "CheckHostKey": "%CheckHostKey%",
        "Hostkey": "%HostKey::$%",
        "Timeout": "%Timeout%"
      }
    },
    {
      "Disconnect": { "ConnectionObjectName": "SshConnection" }
    },
    {
      "Return": { "Value": true }
    }
  ]
}
```

Here is what is new:

- `AccountUserName` / `AccountPassword` are the managed account credentials that SPP auto-populates for password verification.
- This operation authenticates directly as the managed account.
- If `Connect` succeeds, the password is valid.
- If `Connect` fails because the password is wrong or the account cannot log in, the script engine reports the failure automatically.

This is a deliberately simple pattern. Production-ready Linux platforms often use helper functions, imports, delegation logic, and stronger error handling, but this direct-login version is ideal for learning the basics.

## Step 5: The Complete Script

Here is the full script with both operations in one file:

```json
{
  "Id": "MyFirstSshPlatform",
  "BackEnd": "Scriptable",
  "CheckSystem": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
      { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": false } },
      { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
      { "HostKey": { "Type": "String", "Required": false } },
      { "RequestTerminal": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
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
          "RequestTerminal": "%RequestTerminal%",
          "CheckHostKey": "%CheckHostKey%",
          "Hostkey": "%HostKey::$%",
          "Timeout": "%Timeout%"
        }
      },
      {
        "Disconnect": { "ConnectionObjectName": "SshConnection" }
      },
      {
        "Return": { "Value": true }
      }
    ]
  },
  "CheckPassword": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
      { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": false } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AccountPassword": { "Type": "Secret", "Required": true } },
      { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
      { "HostKey": { "Type": "String", "Required": false } },
      { "RequestTerminal": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
    ],
    "Do": [
      {
        "Connect": {
          "ConnectionObjectName": "Global:SshConnection",
          "Type": "Ssh",
          "NetworkAddress": "%Address%",
          "Port": "%Port%",
          "Login": "%AccountUserName%",
          "Password": "%AccountPassword::$%",
          "RequestTerminal": "%RequestTerminal%",
          "CheckHostKey": "%CheckHostKey%",
          "Hostkey": "%HostKey::$%",
          "Timeout": "%Timeout%"
        }
      },
      {
        "Disconnect": { "ConnectionObjectName": "SshConnection" }
      },
      {
        "Return": { "Value": true }
      }
    ]
  }
}
```

If you compare this with a production-ready sample such as [`GenericLinux.json`](../../SampleScripts/SSH/GenericLinux.json), you will notice that the sample adds reusable functions, richer validation, better error handling, and support for more SSH scenarios. Start with the minimal version here, then grow into those patterns later.

## Step 6: Validate and Upload

Validate the script locally first, then create the custom platform in SPP:

```powershell
# Validate locally
Test-SafeguardCustomPlatformScript ".\MyFirstSshPlatform.json"

# Create the platform with the script
New-SafeguardCustomPlatform -Name "My First SSH Platform" -ScriptFile ".\MyFirstSshPlatform.json"
```

Validation is your first checkpoint. If `Test-SafeguardCustomPlatformScript` fails, fix the JSON before you upload anything.

## Step 7: Create a Test Asset and Account

Once the platform exists, create a test asset and a test account:

```powershell
New-SafeguardCustomPlatformAsset "My First SSH Platform" "10.0.0.1" -ServiceAccountCredentialType Password -ServiceAccountName "root"
New-SafeguardAssetAccount "10.0.0.1" "testuser"
Set-SafeguardAssetAccountPassword -AssetToUse "10.0.0.1" -AccountToUse "testuser"
```

In this example:

- The asset uses `root` as the service account for `CheckSystem`.
- `testuser` is the managed account you will verify with `CheckPassword`.
- `Set-SafeguardAssetAccountPassword` securely prompts you for the managed account password.

## Step 8: Test It

Now run both tests and inspect the task log output:

```powershell
# Test connectivity (CheckSystem)
Test-SafeguardAsset "10.0.0.1" -ExtendedLogging

# Test password verification (CheckPassword)
Test-SafeguardAssetAccountPassword "10.0.0.1" "testuser" -ExtendedLogging

# Review the logs
Get-SafeguardTaskLog
```

Start with `CheckSystem`. If that fails, fix connectivity or service-account issues before you test `CheckPassword`.

## What Happens When It Fails

When your first script does not work, start with the simplest explanation:

- Connection timeout — verify network access to the host and confirm the SSH port is open.
- Host key mismatch — accept the correct host key or temporarily set `CheckHostKey` to `false` while testing.
- Authentication failure — verify the service account credentials on the asset and the managed account password on the account.
- Script validation error — check your JSON syntax, parameter names, and commas carefully.

During development, always run tests with `-ExtendedLogging` and review `Get-SafeguardTaskLog` so you can see exactly where the operation failed.

## Next Steps

Once this minimal script works, you are ready to extend it:

- Add `ChangePassword` by following the SSH patterns in the [SSH platforms guide](../guides/ssh-platforms.md).
- Add error handling with `Try` / `Catch` blocks.
- Explore the full [`GenericLinux.json`](../../SampleScripts/SSH/GenericLinux.json) sample for production-ready patterns such as imports, error handling, and `sudo`-based flows.
- Read the [Operations Reference](../reference/operations.md) to see the other operations you can implement.
