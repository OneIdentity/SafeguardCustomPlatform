[← Documentation](../README.md)

# Script Structure Reference

A custom platform script is a single JSON file that tells SPP how to connect to a target system, verify credentials, and change passwords or keys. This page documents the complete JSON structure.

## Top-Level Keys

Every script is a JSON object with the following possible top-level keys:

| Key | Required | Description |
| --- | --- | --- |
| `Id` | Yes | Unique identifier for the platform. SPP uses this internally. |
| `BackEnd` | Yes | Always `"Scriptable"`. |
| `Meta` | No | Free-form object for documentation (author, version, notes). SPP ignores it. |
| `Imports` | No | Array of built-in function library names to include. |
| `Functions` | No | Array of reusable function definitions callable from operations. |
| *Operations* | At least one | One or more named operations (see [Operations](#operations) below). |

### Minimal Example

```json
{
  "Id": "MyPlatform",
  "BackEnd": "Scriptable",
  "CheckPassword": {
    "Parameters": [...],
    "Do": [...]
  },
  "ChangePassword": {
    "Parameters": [...],
    "Do": [...]
  }
}
```

## Id

A short string that uniquely identifies the platform type. SPP stores this value alongside the uploaded script. Use PascalCase with no spaces.

```json
"Id": "MyCustomLinux"
```

## BackEnd

Always set to `"Scriptable"`. This tells SPP to execute the script through the custom platform scripting engine.

```json
"BackEnd": "Scriptable"
```

## Meta

An optional free-form object for human-readable metadata. SPP does not process this block — it exists purely for documentation purposes.

```json
"Meta": {
  "Filename": "MyPlatform.json",
  "Description": "Manages passwords on the Acme portal via HTTPS form posts",
  "Version": "1.0 - 2025-03-15"
}
```

You can add any keys you like. Common choices include `Filename`, `Description`, `Version`, `Author`, `Prerequisite`, and `Warning`.

## Operations

Operations are the named entry points that SPP calls. Each operation is a top-level key whose value is an object with `Parameters` and `Do`.

### Structure of an Operation

```json
"CheckPassword": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "AccountPassword": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "Connect": { ... } },
    { "Return": { "Value": true } }
  ]
}
```

- **Parameters** — An array of parameter definitions. Each element is a single-key object where the key is the parameter name and the value describes it.
- **Do** — An ordered array of commands to execute.

### Available Operations

| Category | Operation | Triggered By |
| --- | --- | --- |
| Connection | `CheckSystem` | Test Connection (asset-level, uses service account credentials) |
| Password | `CheckPassword` | Check Password (account-level, uses managed account credentials) |
| Password | `ChangePassword` | Change Password (account-level) |
| SSH Keys | `CheckSshKey` | Check SSH Key |
| SSH Keys | `ChangeSshKey` | Change SSH Key |
| SSH Keys | `DiscoverSshHostKey` | Discover SSH Host Key during asset creation |
| SSH Keys | `RetrieveSshHostKey` | Retrieve SSH Host Key |
| SSH Keys | `DiscoverAuthorizedKeys` | Discover Authorized Keys for an account |
| SSH Keys | `RemoveAuthorizedKey` | Remove a specific authorized key |
| Discovery | `DiscoverAccounts` | Account Discovery job |
| Discovery | `DiscoverServices` | Service Discovery job |
| JIT Access | `EnableAccount` | Enable an account (JIT provisioning) |
| JIT Access | `DisableAccount` | Disable an account |
| JIT Access | `ElevateAccount` | Elevate account privileges |
| JIT Access | `DemoteAccount` | Demote account privileges |
| Dependencies | `UpdateDependentSystem` | Update a dependent system after password change |
| API Keys | `CheckApiKey` | Check API key validity |
| API Keys | `ChangeApiKey` | Rotate an API key |
| Files | `CheckFile` | Check a file-based credential |
| Files | `ChangeFile` | Change a file-based credential |

You only implement the operations your platform needs. SPP derives feature flags from which operations are present in the script.

### Credential Mapping

SPP populates operation parameters from different credential sources depending on the parameter name:

| Parameter prefix | Source | Available in |
| --- | --- | --- |
| `FuncUserName`, `FuncPassword` | Asset's service account | Any operation (`CheckSystem`, `CheckPassword`, `ChangePassword`, etc.) |
| `AccountUserName`, `AccountPassword` | Managed account | Account-level operations (`CheckPassword`, `ChangePassword`, etc.) |
| `NewPassword` | SPP-generated new password | `ChangePassword` |
| `Address` | Asset's network address | All operations |

A script can use both `FuncUserName`/`FuncPassword` and `AccountUserName`/`AccountPassword` in the same operation. For example, an SSH script's `ChangePassword` connects with the service account (`FuncUserName`) and then changes the managed account's (`AccountUserName`) password. Only `CheckSystem` is limited to service account credentials — it runs at the asset level with no specific managed account in context.

For the complete list of reserved parameter names and their auto-population rules, see [Reserved Parameters](reserved-parameters.md).

## Parameters

Each parameter definition is a single-key object in the `Parameters` array:

```json
{ "AccountUserName": { "Type": "String", "Required": true } }
```

### Parameter Properties

| Property | Required | Description |
| --- | --- | --- |
| `Type` | Yes | Data type: `String`, `Integer`, `Secret`, or `Boolean` |
| `Required` | No | Whether SPP must supply a value. Defaults to `false`. |
| `DefaultValue` | No | Value used when SPP does not supply one. |
| `Description` | No | Human-readable description (shown in SPP UI for custom parameters). |

### Parameter Types

| Type | JSON representation | Notes |
| --- | --- | --- |
| `String` | `"value"` | General text. |
| `Integer` | `30` | Whole numbers (often used for timeouts and ports). |
| `Secret` | `"value"` | Treated as sensitive — masked in logs. Use for passwords, keys, tokens. |
| `Boolean` | `true` / `false` | Flags and toggles. Case-insensitive in scripts (`boolean` also works). |

### Reserved vs Custom Parameters

- **Reserved parameters** have well-known names (`AccountUserName`, `FuncPassword`, `Address`, `NewPassword`, etc.) that SPP populates automatically from asset and account configuration.
- **Custom parameters** have names you define. SPP displays them in the asset's Custom Properties section of the UI so administrators can provide values per-asset.

## Do Blocks

The `Do` array is an ordered list of commands. Each command is a single-key object:

```json
"Do": [
  { "Connect": { "Address": "%Address%", "Port": "%Port%", ... } },
  { "Send": { "Text": "show version\n" } },
  { "Receive": { "Regex": ".*#" } },
  { "Return": { "Value": true } }
]
```

Commands execute in sequence. If a command throws an error (or a `Throw` command is reached), the operation fails and SPP records the error.

### Variable Substitution

Use `%ParameterName%` to reference parameter values inside command arguments:

```json
{ "Send": { "Text": "%AccountUserName%\n" } }
```

Variables defined by commands (e.g., `ResultVariable`) are also referenced with `%Name%` or by their bare name in expressions.

### Command Categories

Commands fall into several categories. Each is documented in detail in the [Commands Reference](commands/index.md).

| Category | Commands |
| --- | --- |
| Flow control | `Condition`, `ForEach`, `Switch`, `Try`, `Return`, `Throw` |
| Functions | `Function` (call a defined function) |
| Variables | `SetItem`, `Eval` |
| Logging | `Log`, `Status`, `Comment` |
| SSH | `Connect`, `Disconnect`, `Send`, `Receive`, `ExecuteCommand` |
| HTTP setup | `BaseAddress`, `NewHttpRequest`, `HttpAuth`, `Headers` |
| HTTP execution | `Request` |
| HTTP response | `ExtractJsonObject`, `WriteResponseObject` |
| HTML forms | `ExtractFormData`, `SetFormValue` |
| Cryptography | `ComparePasswordHash` |
| SSH host keys | `DiscoverSshHostKey` (command form) |

## Functions

Functions are reusable blocks of logic defined in the top-level `Functions` array. They can be called from any operation's `Do` block.

### Structure

```json
"Functions": [
  {
    "Name": "Login",
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "UserName": { "Type": "String", "Required": true } },
      { "Password": { "Type": "Secret", "Required": true } }
    ],
    "Do": [
      { "BaseAddress": { "Address": "https://%Address%" } },
      { "NewHttpRequest": { "ObjectName": "LoginRequest" } },
      { "Request": { ... } },
      { "Return": { "Value": true } }
    ]
  }
]
```

- **Name** — The function name used when calling it.
- **Parameters** — Parameter definitions local to this function (same format as operation parameters).
- **Do** — The command sequence to execute.

### Calling a Function

```json
{ "Function": { "Name": "Login", "Parameters": [ "%Address%", "%UseSsl%", "%UserName%", "%Password%" ], "ResultVariable": "LoginResult" } }
```

Parameters are passed positionally. The optional `ResultVariable` captures the function's return value.

### Important

`Functions` is an **array** of objects, not a dictionary:

```json
// ✅ Correct
"Functions": [
  { "Name": "Login", "Parameters": [...], "Do": [...] },
  { "Name": "Logout", "Parameters": [...], "Do": [...] }
]

// ❌ Wrong — this format is not valid
"Functions": {
  "Login": { ... },
  "Logout": { ... }
}
```

## Imports

`Imports` is an optional array of built-in function library names. When present, SPP loads these libraries and makes their functions available to your script, as if they were defined in your own `Functions` array.

```json
"Imports": [ "ResolveAssetName" ]
```

Imported functions are maintained by One Identity as part of SPP. They provide tested implementations of common patterns (e.g., asset name resolution for Telnet/TN3270 platforms). You call imported functions the same way you call your own — with the `Function` command.

For available library names and their contents, see [Imports](imports.md).

## Complete Example

Here is a complete script showing all structural elements together:

```json
{
  "Id": "AcmePortal",
  "BackEnd": "Scriptable",
  "Meta": {
    "Description": "Manages passwords on the Acme web portal",
    "Version": "1.0"
  },
  "CheckPassword": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AccountPassword": { "Type": "Secret", "Required": true } }
    ],
    "Do": [
      { "Function": { "Name": "Login", "Parameters": [ "%Address%", "%AccountUserName%", "%AccountPassword%" ], "ResultVariable": "LoginOk" } },
      { "Condition": { "If": "LoginOk", "Then": { "Do": [ { "Return": { "Value": true } } ] }, "Else": { "Do": [ { "Throw": { "Value": "Login failed" } } ] } } }
    ]
  },
  "ChangePassword": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AccountPassword": { "Type": "Secret", "Required": true } },
      { "NewPassword": { "Type": "Secret", "Required": true } }
    ],
    "Do": [
      { "Function": { "Name": "Login", "Parameters": [ "%Address%", "%AccountUserName%", "%AccountPassword%" ], "ResultVariable": "LoginOk" } },
      { "Condition": { "If": "!LoginOk", "Then": { "Do": [ { "Throw": { "Value": "Login failed" } } ] } } },
      { "Comment": { "Text": "Navigate to change password page and submit new password..." } },
      { "Return": { "Value": true } }
    ]
  },
  "Functions": [
    {
      "Name": "Login",
      "Parameters": [
        { "Address": { "Type": "String", "Required": true } },
        { "UserName": { "Type": "String", "Required": true } },
        { "Password": { "Type": "Secret", "Required": true } }
      ],
      "Do": [
        { "BaseAddress": { "Address": "https://%Address%" } },
        { "NewHttpRequest": { "ObjectName": "LoginReq" } },
        { "Request": { "Verb": "Post", "Url": "/api/login", "RequestObjectName": "LoginReq", "ResponseObjectName": "LoginResp", "Content": { "ContentType": "application/json", "Body": "{\"username\":\"%UserName%\",\"password\":\"%Password%\"}" } } },
        { "Condition": { "If": "LoginResp.StatusCode.ToString().Equals(\"OK\")", "Then": { "Do": [ { "Return": { "Value": true } } ] }, "Else": { "Do": [ { "Return": { "Value": false } } ] } } }
      ]
    }
  ]
}
```

## Key Rules

1. **JSON must be valid.** Use a JSON validator during development. SPP rejects scripts with syntax errors on upload.
2. **Operations you include determine platform capabilities.** SPP derives feature flags automatically — you never set them manually.
3. **Parameter names are case-sensitive.** `AccountUserName` and `accountusername` are different parameters.
4. **`Secret` parameters are masked in logs.** Always use type `Secret` for passwords, keys, and tokens.
5. **Order matters in `Do` blocks.** Commands execute sequentially, top to bottom.
6. **Functions are defined once, called many times.** Extract repeated logic (login flows, pagination) into functions.

## See Also

- [Operations Reference](operations.md) — detailed documentation for each operation
- [Reserved Parameters](reserved-parameters.md) — complete list of auto-populated parameters
- [Custom Parameters](custom-parameters.md) — defining platform-specific configuration
- [Commands Index](commands/index.md) — all available commands
