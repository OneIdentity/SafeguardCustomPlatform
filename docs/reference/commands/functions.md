# Function Commands

Define reusable blocks and call them from operations or other functions.

Functions keep larger scripts readable by moving repeated logic into named blocks. Definitions live in the top-level `Functions` array, and calls happen inside `Do` blocks with the `Function` command. Arguments can include `%VariableName%` substitutions or `%{ expression }%` expressions; see [Variables](../variables.md).

## Function definition

Use the top-level `Functions` array to define reusable blocks that can be called from operations or from other functions.

### Syntax

```json
{
  "Functions": [
    {
      "Name": "HandleResponse",
      "Parameters": [
        { "StatusCode": { "Type": "String", "Required": true } },
        { "Content": { "Type": "String", "Required": true } },
        { "AccountUserName": { "Type": "String", "Required": true } }
      ],
      "Do": [
        { "Switch": {
            "MatchValue": "%{StatusCode}%",
            "Cases": [
              {
                "CaseValue": "(OK)|(NoContent)",
                "Do": [
                  { "Return": { "Value": true } }
                ]
              }
            ]
          }
        }
      ]
    }
  ]
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Name` | String | Yes | Function name. Current validation follows the same naming rules as variables. |
| `Parameters` | Array of parameter definitions | No | Ordered input parameters exposed inside the function body. |
| `Do` | Array of commands | Yes | Commands that run when the function is called. |

### Function parameter definition fields

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| Parameter name (object key) | String | Yes | Name exposed inside the function body, for example `StatusCode` or `AccountUserName`. |
| `Type` | Data type | Yes | Parameter type such as `String`, `Secret`, or `Integer`. |
| `Required` | Boolean | No | Whether the caller must supply a value. Defaults to `true`. |
| `DefaultValue` | Any | No | Default value used when the caller omits an optional parameter. |
| `Description` | String | No | Optional documentation text for the parameter definition. |

### Example

From `SampleScripts/HTTP/WordPressHttp.json`:

```json
{
  "Name": "HandleResponse",
  "Parameters": [
    { "StatusCode": { "Type": "String", "Required": true } },
    { "Content": { "Type": "String", "Required": true } },
    { "AccountUserName": { "Type": "String", "Required": true } }
  ],
  "Do": [
    { "Switch": {
        "MatchValue": "%{StatusCode}%",
        "Cases": [
          {
            "CaseValue": "(OK)|(NoContent)",
            "Do": [
              { "Return": { "Value": true } }
            ]
          },
          {
            "CaseValue": "Forbidden",
            "Do": [
              { "Status": { "Type": "Changing", "Percent": 80, "Message": { "Name": "InsufficientPrivilegesAccessPassword" } } },
              { "Return": { "Value": false } }
            ]
          }
        ]
      }
    }
  ]
}
```

## Call (`Function`)

Use the `Function` command inside a `Do` block to invoke a named function. In current scripts, arguments are passed as an ordered `Parameters` array, and a returned value can be stored in `ResultVariable`.

### Syntax

```json
{
  "Function": {
    "Name": "ConnectTelnet",
    "Parameters": [ "%FuncUserName%", "%FuncPassword%" ],
    "ResultVariable": "ConnectResult"
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Name` | String | Yes | Name of the function to call. |
| `Parameters` | Array of values or expressions | No | Ordered argument values passed to the function definition. |
| `ResultVariable` | String | No | Variable name that receives the function's return value. |
| `IsSecret` | Boolean | No | Masks the stored return value when `ResultVariable` is used. Default is `false`. |

### Examples

#### Call a helper and capture its result

From `SampleScripts/Telnet/GenericCiscoIosTelnet.json`:

```json
{
  "Function": {
    "Name": "ConnectTelnet",
    "Parameters": [ "%FuncUserName%", "%FuncPassword%" ],
    "ResultVariable": "ConnectResult"
  }
}
```

#### Call a function with a secret argument

From `SampleScripts/SSH/GenericLinuxWithSSHKeySupport.json`:

```json
{
  "Function": {
    "Name": "LoginSsh",
    "ResultVariable": "LoginResult",
    "Parameters": [ "%FuncUserName%", "%FuncPassword%", "%UserKey::$%" ]
  }
}
```

## Notes

> Return values come from `Return`, not from the last expression in the body.

> Function calls store the return payload only when `ResultVariable` is set. Without it, the function still runs, but the returned value is discarded unless a surrounding `Return` or error path uses it directly.

> There is no separate `Call` keyword in current scripts; invocation uses the `Function` command.

## Cross-References

- [Commands Index](index.md)
- [Flow Control](flow-control.md)
- [Error Handling](error-handling.md)
- [Variables](../variables.md)
- [Script Structure](../script-structure.md)
