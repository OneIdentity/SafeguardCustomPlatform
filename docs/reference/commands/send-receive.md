[← Command Reference](index.md)

# Send and Receive

`Send` writes text to an interactive terminal session, and `Receive` reads terminal output into a variable.

Together they form the standard SSH or Telnet loop for prompt-driven tasks: connect, send a command, receive output, react to the prompt, and repeat until the operation is complete.

Interactive tasks usually alternate `Send` and `Receive` after `Connect` opens a session with `RequestTerminal: true`.

## `Send`

Writes text to an open interactive connection.

### Syntax

```json
{
  "Send": {
    "ConnectionObjectName": "ConnectSsh",
    "Buffer": "%DelegationPrefix% passwd %AccountUserName%",
    "ContainsSecret": false
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `ConnectionObjectName` | String | Yes | Existing interactive connection object. |
| `Buffer` | String expression | Yes | Text to send to the remote session. |
| `ContainsSecret` | Boolean | No | Masks the outgoing buffer in logs. Default is `false`. |
| `EndOfDataSuffix` | String expression | No | Overrides the connection's normal end-of-data suffix for this send. |

## `Receive`

Reads output from an open interactive connection and stores it in a buffer variable.

### Syntax

```json
{
  "Receive": {
    "ConnectionObjectName": "ConnectSsh",
    "BufferName": "CmdResponse",
    "ExpectTimeout": 10000,
    "ExpectRegex": "([Nn]ew.*[Pp]assword:)",
    "TimeoutResultVariableName": "Global:CmdTimedOut"
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `ConnectionObjectName` | String | Yes | Existing interactive connection object. |
| `BufferName` | String | Yes | Variable that receives the captured output. |
| `ExpectRegex` | String expression | No | Regular expression to wait for before returning. |
| `ExpectOptions` | Enum array | No | Regex options such as `IgnoreCase`, `Multiline`, or `Singleline`. |
| `ExpectTimeout` | Integer expression | No | Wait time, in milliseconds, before the receive attempt times out. |
| `Append` | Boolean | No | Appends new output to the current value of `BufferName` instead of replacing it. Default is `false`. |
| `ContainsSecret` | Boolean | No | Masks the captured output and stores the buffer as secret. Default is `false`. |
| `TimeoutResultVariableName` | String | No | Variable that starts as `false` and flips to `true` if the expected text is not seen before timeout. |

## Examples

### Set up the shell and flush the banner

From `samples/ssh/generic-linux/GenericLinux.json`:

```json
{
  "Send": {
    "ConnectionObjectName": "ConnectSsh",
    "Buffer": "unset TERM; stty -echo; LANG=C; LC_ALL=C; SUDO_PROMPT='SUDO password for %p:'; export LANG LC_ALL SUDO_PROMPT; echo \"INIT_CHECK=$?\""
  }
}
{ "Receive": { "ConnectionObjectName": "ConnectSsh", "BufferName": "FlushBuffer" } }
```

### Use `%DelegationPrefix%` and answer a sudo prompt

From `samples/ssh/generic-linux/GenericLinux.json`:

```json
{
  "Send": {
    "ConnectionObjectName": "ConnectSsh",
    "Buffer": "%DelegationPrefix% egrep -q '^(%FuncUserName%):' /etc/shadow; echo \"CHECKSYS=$?\""
  }
}
{ "Receive": { "ConnectionObjectName": "ConnectSsh", "ContainsSecret": true, "BufferName": "ReturnStatus" } }
{
  "Condition": {
    "If": "Regex.IsMatch(ReturnStatus, @\"SUDO password for\")",
    "Then": {
      "Do": [
        { "Send": { "ConnectionObjectName": "ConnectSsh", "Buffer": "%FuncPassword%", "ContainsSecret": true } },
        { "Receive": { "ConnectionObjectName": "ConnectSsh", "ContainsSecret": true, "BufferName": "ReturnStatus" } }
      ]
    }
  }
}
```

### Interactive password-change loop

From `samples/ssh/generic-linux/GenericLinux.json`:

```json
{ "Send": { "ConnectionObjectName": "ConnectSsh", "Buffer": "%NewPassword%", "ContainsSecret": true } }
{
  "Receive": {
    "ConnectionObjectName": "ConnectSsh",
    "BufferName": "PasswdAttempt",
    "ExpectRegex": "([Nn]ew.*[Pp]assword:)",
    "ExpectTimeout": 10000
  }
}
```

## Notes

> `Send` and `Receive` require an interactive connection. Create it with `Connect` and keep `RequestTerminal` set to `true`.

> When `ExpectRegex` is set and `ExpectTimeout` is omitted or negative, the script engine falls back to the task `Timeout` variable and converts it to milliseconds.

> If `ExpectTimeout` is positive but `ExpectRegex` is empty, `Receive` waits for any output and returns what it collected.

> `ContainsSecret` protects both logging and stored variable values. Use it whenever the outgoing text or captured buffer includes passwords, host keys, or hash material.

## Cross-References

- [Commands Index](index.md)
- [Connect and Disconnect](connect.md)
- [ExecuteCommand](execute-command.md)
- [Variables](../variables.md)
