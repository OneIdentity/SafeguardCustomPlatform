# Flow Control Commands

Branch, loop, and exit execution inside `Do` blocks.

Use these patterns when a script needs to choose between paths, iterate over results, or stop early. In current scripts, `If`/`Else` is expressed with `Condition`, and while-style looping is expressed with `For`. Expressions inside these commands can use both `%VariableName%` and `%{ expression }%` syntax; see [Variables](../variables.md).

## `If` / `ElseIf` / `Else` (`Condition`)

Use `Condition` when a single expression decides whether a block runs. `Else` is optional. There is no separate `ElseIf` property in current scripts; chain another `Condition` inside `Else.Do` when you need that pattern.

### Syntax

```json
{
  "Condition": {
    "If": "Regex.IsMatch(LoginCheckBuffer, @\"(You are required to change your password)|(Your password has expired)|(Check for other error messages here)\")",
    "Then": {
      "Do": [
        { "Function": { "Name": "LogoutSsh" } },
        { "Return": { "Value": false } }
      ]
    }
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `If` | Boolean expression | Yes | Expression the script engine evaluates. Use `%VariableName%` or `%{ expression }%` values inside it as needed. |
| `Then` | Operation block | Yes | Commands to run when `If` evaluates to `true`. |
| `Else` | Operation block | No | Commands to run when `If` evaluates to `false`. Nest another `Condition` here for an `ElseIf` pattern. |

### Examples

#### Simple conditional return

From `SampleScripts/SSH/GenericLinux.json`:

```json
{
  "Condition": {
    "If": "Regex.IsMatch(LoginCheckBuffer, @\"(You are required to change your password)|(Your password has expired)|(Check for other error messages here)\")",
    "Then": {
      "Do": [
        { "Function": { "Name": "LogoutSsh" } },
        { "Return": { "Value": false } }
      ]
    }
  }
}
```

#### `Else` branch inside a default handler

From `SampleScripts/HTTP/WordPressHttp.json`:

```json
{
  "Condition": {
    "If": "Content.Contains(\"invalid_username\")",
    "Then": {
      "Do": [
        { "Status": { "Type": "Checking", "Percent": 80, "Message": { "Name": "AccountNotFound", "Parameters": [ "%AccountUserName%" ] } } },
        { "Throw": { "Value": "Account %AccountUserName% not found" } }
      ]
    },
    "Else": {
      "Do": [
        { "Return": { "Value": false } }
      ]
    }
  }
}
```

## `Switch` / `Case` / `Default`

Use `Switch` when one value needs to be matched against multiple cases. String `CaseValue` entries support either literal equality or regular-expression matching.

### Syntax

```json
{
  "Switch": {
    "MatchValue": "%ReturnStatus%",
    "Cases": [
      {
        "CaseValue": "CHECKSYS=0",
        "Do": [
          { "Return": { "Value": true } }
        ]
      },
      {
        "CaseValue": "(CHECKSYS=[1-9]+.*)|(Permission denied)",
        "Do": [
          { "Status": { "Type": "Checking", "Percent": 80, "Message": { "Name": "InsufficientPrivilegesAccessPassword" } } }
        ]
      }
    ],
    "DefaultCase": {
      "Do": [
        { "Return": { "Value": false } }
      ]
    }
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `MatchValue` | Value or expression | Yes | Value to compare against the `Cases` list. |
| `Cases` | Array of case blocks | Yes | Ordered list of cases. Each case has a required `CaseValue` and a `Do` block. |
| `DefaultCase` | Operation block | No | Fallback block when no case matches. |

### Examples

#### Switch on a returned terminal status

From `SampleScripts/SSH/GenericLinux.json`:

```json
{
  "Switch": {
    "MatchValue": "%ReturnStatus%",
    "Cases": [
      {
        "CaseValue": "CHECKSYS=0",
        "Do": [
          { "Return": { "Value": true } }
        ]
      },
      {
        "CaseValue": "(incorrect password attempts)|(Sorry, try again)|(Check for other error messages here)",
        "Do": [
          { "Status": { "Type": "Checking", "Percent": 80, "Message": { "Name": "InsufficientDelegationPrivileges", "Parameters": [ "%DelegationPrefix%" ] } } }
        ]
      },
      {
        "CaseValue": "(CHECKSYS=[1-9]+.*)|(Permission denied)",
        "Do": [
          { "Status": { "Type": "Checking", "Percent": 80, "Message": { "Name": "InsufficientPrivilegesAccessPassword" } } }
        ]
      }
    ]
  }
}
```

#### Default-case fallback logic

From `SampleScripts/HTTP/WordPressHttp.json`:

```json
{
  "Switch": {
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
    ],
    "DefaultCase": {
      "Do": [
        { "Condition": {
            "If": "Content.Contains(\"invalid_username\")",
            "Then": {
              "Do": [
                { "Status": { "Type": "Checking", "Percent": 80, "Message": { "Name": "AccountNotFound", "Parameters": [ "%AccountUserName%" ] } } },
                { "Throw": { "Value": "Account %AccountUserName% not found" } }
              ]
            },
            "Else": {
              "Do": [
                { "Return": { "Value": false } }
              ]
            }
          }
        }
      ]
    }
  }
}
```

## `While` (`For`)

Use `For` as a while-style loop by supplying `Condition` and `Body` and omitting `Before` and `End`. The engine enforces a maximum-iteration guard; if `MaxIterations` is omitted, the current default limit is 1,000,000 iterations.

### Syntax

```json
{
  "For": {
    "Condition": "match.Success",
    "Body": {
      "Do": [
        { "SetItem": { "Name": "GroupNames", "Value": "%{match.Groups[\"groupname\"].Captures.Cast<Capture>().Select(c => c.Value).ToArray()}%" } },
        { "WriteDiscoveredAccount": {
            "Name": "%{match.Groups[\"uname\"].Value}%",
            "UserId": "%{match.Groups[\"uid\"].Value}%",
            "GroupId": "%{match.Groups[\"gid\"].Value}%",
            "Groups": "%{match.Groups[\"groupid\"].Captures.Cast<Capture>().Select((groupIdCapture,index) =>new DiscoveredGroup(GroupNames[index], groupIdCapture.Value))}%"
          }
        },
        { "SetItem": { "Name": "match", "Value": "%{match.NextMatch()}%" } }
      ]
    }
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Before` | Expression | No | Expression to run once before the loop starts. |
| `Condition` | Boolean expression | No | Loop guard. When omitted, the loop continues until `Break`, `Return`, or `MaxIterations` stops it. |
| `End` | Expression | No | Expression to run after each iteration. |
| `MaxIterations` | Integer expression | No | Safety cap that overrides the default maximum loop count. |
| `Body` | Operation block | Yes | Commands to run for each iteration. |

### Example

From `SampleScripts/SSH/GenericLinuxWithDiscovery.json`:

```json
{
  "For": {
    "Condition": "match.Success",
    "Body": {
      "Do": [
        { "SetItem": { "Name": "GroupNames", "Value": "%{match.Groups[\"groupname\"].Captures.Cast<Capture>().Select(c => c.Value).ToArray()}%" } },
        { "WriteDiscoveredAccount": {
            "Name": "%{match.Groups[\"uname\"].Value}%",
            "UserId": "%{match.Groups[\"uid\"].Value}%",
            "GroupId": "%{match.Groups[\"gid\"].Value}%",
            "Groups": "%{match.Groups[\"groupid\"].Captures.Cast<Capture>().Select((groupIdCapture,index) =>new DiscoveredGroup(GroupNames[index], groupIdCapture.Value))}%"
          }
        },
        { "SetItem": { "Name": "match", "Value": "%{match.NextMatch()}%" } }
      ]
    }
  }
}
```

## `ForEach`

Use `ForEach` when a variable already contains an enumerable collection and you want one element bound into the loop body each time.

### Syntax

```json
{
  "ForEach": {
    "CollectionName": "SelectGroupsOfUserResult",
    "ElementName": "GroupName",
    "Body": {
      "Do": [
        {
          "Function": {
            "Name": "GetGroupId",
            "Parameters": [ "%Address%", "%{GroupName}%", "%FuncPassword%", "%{SkipServerCertValidation}%", "%{UseSsl}%" ],
            "ResultVariable": "GetGroupIdResult"
          }
        }
      ]
    }
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `CollectionName` | String | Yes | Existing variable name that resolves to an enumerable collection. |
| `ElementName` | String | Yes | Variable name assigned to the current element during each iteration. |
| `Body` | Operation block | Yes | Commands to run for each element. |
| `MaxIterations` | Integer expression | No | Safety cap that overrides the default maximum loop count. |

### Example

From `SampleScripts/HTTP/Okta_WithDiscoveryAndGroupMembershipRestore.json`:

```json
{
  "ForEach": {
    "CollectionName": "SelectGroupsOfUserResult",
    "ElementName": "GroupName",
    "Body": {
      "Do": [
        {
          "Function": {
            "Name": "GetGroupId",
            "Parameters": [ "%Address%", "%{GroupName}%", "%FuncPassword%", "%{SkipServerCertValidation}%", "%{UseSsl}%" ],
            "ResultVariable": "GetGroupIdResult"
          }
        },
        {
          "Condition": {
            "If": "GetGroupIdResult.GetType() != System.Boolean",
            "Then": {
              "Do": [
                { "Comment": { "Text": "Group exists and can be processed" } }
              ]
            }
          }
        }
      ]
    }
  }
}
```

## `Return` and `Break`

Use `Return` to exit the current function or operation and optionally pass back a value. `Break` uses the same model but signals an early loop exit instead of a function return.

### Syntax

```json
{ "Return": { "Value": true } }
```

```json
{ "Break": {} }
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Value` | Value or expression | No | Optional value returned by `Return`. `Break` uses the same field, but loop bodies usually omit it. |

### Example

From `SampleScripts/Telnet/GenericCiscoIosTelnet.json`:

```json
{
  "Condition": {
    "If": "!ConnectResult",
    "Then": {
      "Do": [
        { "Comment": { "Text": "Able to connect, unable to log in" } },
        { "Return": { "Value": false } }
      ]
    }
  }
}
```

## Cross-References

- [Commands Index](index.md)
- [Functions](functions.md)
- [Error Handling](error-handling.md)
- [Variables](../variables.md)
- [Script Structure](../script-structure.md)
