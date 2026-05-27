# ExecuteCommand

`ExecuteCommand` runs a remote command over SSH batch mode and writes the results into named variables.

It is the batch-mode alternative to interactive `Send`/`Receive`: one call sends the command, optional stdin, and captures stdout, stderr, and exit status without walking terminal prompts yourself.

> `ExecuteCommand` is available in SPP 7.4 and later.

## Syntax

```json
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "%runcmd%",
    "Stdin": "%{ StdinArgs }%",
    "BufferName": "Stdout",
    "StderrBufferName": "Stderr",
    "ExitStatusBufferName": "rc",
    "CommandContainsSecret": "%{ CommandContainsSecret }%",
    "InputContainsSecret": false,
    "OutputContainsSecret": "%{ OutputContainsSecret }%"
  }
}
```

## Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `ConnectionObjectName` | String expression | Yes | Open SSH connection object. The connection must have been created with `RequestTerminal: false`. |
| `Command` | String expression | Yes | Remote command to execute. Variable substitution and expressions are resolved before execution. |
| `BufferName` | String expression | Yes | Variable that receives stdout. Despite the generic name, this is the stdout buffer. |
| `StderrBufferName` | String expression | No | Variable that receives stderr output. |
| `ExitStatusBufferName` | String expression | No | Variable that receives the numeric process exit status. |
| `Stdin` | Array expression | No | Array of strings written to stdin, in order. |
| `Timeout` | Integer expression | No | Per-command timeout override. |
| `CommandContainsSecret` | Boolean expression | No | Masks the command text in logs. |
| `InputContainsSecret` | Boolean expression | No | Masks stdin values in logs. |
| `OutputContainsSecret` | Boolean expression | No | Masks stdout and stderr in logs. |
| `SuppressExceptions` | Boolean expression | No | Prevents command exceptions from immediately failing the step so the script can inspect return data itself. |

## Structured result pattern

`ExecuteCommand` itself writes variables; scripts commonly wrap those variables into an object before returning from a helper function.

```json
{ "SetItem": { "Name": "rc", "Value": 1 } }
{ "SetItem": { "Name": "Stdout", "Value": "" } }
{ "SetItem": { "Name": "Stderr", "Value": "" } }
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "%runcmd%",
    "Stdin": "%{ StdinArgs }%",
    "BufferName": "Stdout",
    "StderrBufferName": "Stderr",
    "ExitStatusBufferName": "rc"
  }
}
{
  "Return": {
    "Value": { "rc": "%{ rc }%", "Stdout": "%{ Stdout }%", "Stderr": "%{ Stderr }%" }
  }
}
```

## Examples

### `RunCommand` wrapper from the batch-mode Linux sample

From `SampleScripts/SSH/LinuxSshBatchModeExample.json`:

```json
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "%runcmd%",
    "Stdin": "%{ StdinArgs }%",
    "BufferName": "Stdout",
    "StderrBufferName": "Stderr",
    "ExitStatusBufferName": "rc",
    "CommandContainsSecret": "%{ CommandContainsSecret }%",
    "InputContainsSecret": false,
    "OutputContainsSecret": "%{ OutputContainsSecret }%"
  }
}
```

### Connect for batch mode first

From `SampleScripts/SSH/LinuxSshBatchModeExample.json`:

```json
{
  "Connect": {
    "ConnectionObjectName": "Global:ConnectSsh",
    "Type": "Ssh",
    "Port": "%Port%",
    "NetworkAddress": "%Address%",
    "Login": "%FuncUserName%",
    "RequestTerminal": false,
    "Password": "%FuncPassword::$%",
    "UserKey": "%UserKey::$%",
    "CheckHostKey": "%CheckHostKey%",
    "HostKey": "%HostKey::$%",
    "Timeout": "%Timeout%"
  }
}
```

### Execute a sudo command with SSH key authentication

From `SampleScripts/SSH/RestrictedAuthorizedKeyExample.json`:

```json
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "sudo %Cmd%",
    "Stdin": "%{ StdinArgs }%",
    "BufferName": "Stdout",
    "StderrBufferName": "Stderr",
    "ExitStatusBufferName": "rc",
    "CommandContainsSecret": "%{ CommandContainsSecret }%",
    "InputContainsSecret": false,
    "OutputContainsSecret": "%{ OutputContainsSecret }%"
  }
}
```

## Notes

> `ExecuteCommand` is SSH-only and expects a non-interactive connection. If the connection was opened with `RequestTerminal: true`, the command fails with an interactive-session error.

> `BufferName` is required. If you also need stderr or exit status, set `StderrBufferName` and `ExitStatusBufferName` explicitly.

> `Stdin` values are joined using the connection's end-of-data suffix, which is why password-change examples pass an array such as `[ "%{ NewPassword }%", "%{ NewPassword }%" ]`.

> Unlike `Send`/`Receive`, the command does not build a result object for you. The wrapper function pattern above is the usual way to return `rc`, `Stdout`, and `Stderr` together.

## Cross-References

- [Commands Index](index.md)
- [Connect and Disconnect](connect.md)
- [Send and Receive](send-receive.md)
- [Variables](../variables.md)
