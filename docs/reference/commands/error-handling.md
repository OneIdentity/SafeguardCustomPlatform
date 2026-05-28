# Error Handling Commands

Handle recoverable failures and re-raise errors when execution should stop.

Use `Try` when a step can fail in an expected way and the script should clean up, publish a clearer status, or transform the error before stopping. Inside `Catch`, the script engine exposes the caught value as `%Exception%`, which you can inspect directly or use inside `%{ expression }%`.

## `Try` / `Catch`

Wrap risky work in `Try`. If the `Do` block throws an error, the optional `Catch` block runs with `%Exception%` populated. `Finally` is also supported and always runs after `Do` or `Catch`.

### Syntax

```json
{
  "Try": {
    "Do": [
      {
        "Connect": {
          "ConnectionObjectName": "Global:ConnectSsh",
          "Type": "Ssh",
          "Port": "%Port%",
          "NetworkAddress": "%Address%",
          "Login": "%UserName%",
          "Password": "%Password::$%",
          "RequestTerminal": "%RequestTerminal%",
          "UserKey": "%LoginKey::$%",
          "CheckHostKey": "%CheckHostKey%",
          "Hostkey": "%HostKey::$%",
          "Timeout": "%Timeout%"
        }
      }
    ],
    "Catch": [
      { "Throw": { "Value": "SSH Connection Error: %Exception%" } }
    ]
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Do` | Operation block | Yes | Commands to run inside the protected block. |
| `Catch` | Operation block | No | Commands to run when the `Do` block throws an error. `%Exception%` is available inside this block. |
| `Finally` | Operation block | No | Cleanup block that always runs after `Do` or `Catch`. |

### Examples

#### Wrap a connection attempt

From `SampleScripts/SSH/GenericLinux.json`:

```json
{
  "Try": {
    "Do": [
      {
        "Connect": {
          "ConnectionObjectName": "Global:ConnectSsh",
          "Type": "Ssh",
          "Port": "%Port%",
          "NetworkAddress": "%Address%",
          "Login": "%UserName%",
          "Password": "%Password::$%",
          "RequestTerminal": "%RequestTerminal%",
          "UserKey": "%LoginKey::$%",
          "CheckHostKey": "%CheckHostKey%",
          "Hostkey": "%HostKey::$%",
          "Timeout": "%Timeout%"
        }
      }
    ],
    "Catch": [
      { "Throw": { "Value": "SSH Connection Error: %Exception%" } }
    ]
  }
}
```

#### Clean up before failing

From `SampleScripts/HTTP/CustomFacebook.json`:

```json
{
  "Try": {
    "Do": [
      { "Function": { "Name": "ChangeUserPassword", "ResultVariable": "CheckResult" } },
      { "Return": { "Value": "%CheckResult%" } }
    ],
    "Catch": [
      { "Function": { "Name": "Logout" } },
      { "Throw": { "Value": "Error changing password" } }
    ]
  }
}
```

## `Rethrow` (`Throw`)

Use `Throw` inside a `Catch` block to re-raise the current error or to wrap it in a clearer message. If you want to preserve the original caught value, pass `%Exception%` directly.

### Syntax

```json
{ "Throw": { "Value": "%Exception%" } }
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Value` | Value or expression | No | Error payload to raise. In a catch block, `%Exception%` rethrows the original caught value. |

### Example

From `SampleScripts/SSH/GenericLinux.json`:

```json
{
  "Catch": [
    { "Throw": { "Value": "SSH Connection Error: %Exception%" } }
  ]
}
```

## Notes

> `Try` must include a `Do` block and at least one of `Catch` or `Finally`.

> `Finally` cannot `Return` or `Break`. If it throws, its error replaces any earlier result.

> There is no separate `Rethrow` keyword in current scripts; rethrow behavior uses `Throw`.

## Cross-References

- [Commands Index](index.md)
- [Flow Control](flow-control.md)
- [Functions](functions.md)
- [Variables](../variables.md)
