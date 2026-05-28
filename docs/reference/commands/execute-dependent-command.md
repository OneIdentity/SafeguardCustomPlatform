# ExecuteDependentCommand

`ExecuteDependentCommand` runs a configured SSH command during an `UpdateDependentSystem` workflow and captures the resolved command, stdout, stderr, and exit status in variables.

When one password change must be propagated to another system, SPP calls `UpdateDependentSystem` once per linked dependency. In that operation, SPP injects dependency-aware reserved parameters such as `DependentAccountUserName`, `DependentAccountPassword`, `DependentNewPassword`, `DependentCommand`, `CommandArguments`, and `StdinArguments`. Your script opens an SSH batch connection to the dependent asset and uses `ExecuteDependentCommand` to run the custom dependency command that performs the actual update.

## Syntax

```json
{
  "ExecuteDependentCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "DependentCommand": "%DependentCommand::$%",
    "CommandArguments": "%CommandArguments::$%",
    "StdinArguments": "%{ StdinArguments }%",
    "BufferName": "OutputBuffer",
    "StderrBufferName": "ErrBuf",
    "ExitStatusBufferName": "rc",
    "CommandBufferName": "ResolvedCommand",
    "Timeout": "%Timeout%",
    "LogCommand": true,
    "LogCommandArguments": false,
    "LogStdin": false,
    "LogStdout": false
  }
}
```

## Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `ConnectionObjectName` | String expression | Yes | Open SSH connection object. Create it first with [`Connect`](connect.md) and `RequestTerminal: false`. |
| `Timeout` | Integer expression | No | Per-command timeout override. If the timeout expires, the connection is closed and command output may be lost. |
| `BufferName` | String expression | Yes | Variable that receives stdout. |
| `ExitStatusBufferName` | String expression | Yes | Variable that receives the numeric process exit status. |
| `StderrBufferName` | String expression | Yes | Variable that receives stderr. Some utilities still write non-fatal output to stderr. |
| `Type` | Enum | No | Fixed as `Ssh` internally. Custom-platform scripts do not normally set this value. |
| `CommandBufferName` | String expression | Yes | Variable that receives the fully resolved command string, after interpolation. |
| `DependentCommand` | String expression | Yes | Command to execute on the dependent system. In most `UpdateDependentSystem` scripts this comes from the reserved `DependentCommand` parameter. |
| `CommandArguments` | String expression | No | Optional command-line arguments appended after `DependentCommand`. |
| `StdinArguments` | Array expression | No | Optional list of strings written to stdin, in order. |
| `LogStdin` | Boolean expression | No | If `true`, stdin content is written to logs. Keep this `false` when stdin carries secrets. |
| `LogStdout` | Boolean expression | No | If `true`, stdout is written to logs. |
| `LogCommand` | Boolean expression | No | If `true`, the resolved command text is written to logs. |
| `LogCommandArguments` | Boolean expression | No | If `true`, resolved command arguments are written to logs. |

## How It Works

1. SPP invokes [`UpdateDependentSystem`](../operations.md#updatedependentsystem) once for each linked dependent system and injects dependency-aware reserved parameters for the dependent account and custom dependency settings.
2. The parent operation opens an SSH connection to the dependent asset, typically with [`Connect`](connect.md) and `RequestTerminal: false`.
3. `ExecuteDependentCommand` resolves `DependentCommand`, `CommandArguments`, and `StdinArguments`, including `%VariableName%` and `%{ expression }%` interpolation. See [Variables](../variables.md) for the substitution rules.
4. The script engine runs that command over the existing SSH batch connection. If `CommandBufferName` is set, the fully resolved command is also stored for later inspection, with logging controlled by `LogCommand` and `LogCommandArguments`.
5. Stdout, stderr, and exit status are written to the named buffers so the calling script can validate results, log details, or throw an error.

> `ExecuteDependentCommand` does **not** dispatch into another custom-platform script. The parent `UpdateDependentSystem` operation stays in control; SPP provides the dependent-account context, and this command runs the configured SSH command on the dependent asset.

## Examples

### Pass through the custom dependency settings from the change profile

This is the common pattern used by the built-in Unix custom dependency helper: pass the reserved parameters straight through, then inspect `rc`, `OutputBuffer`, and `ErrBuf` afterward.

```json
{
  "ExecuteDependentCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "BufferName": "OutputBuffer",
    "ExitStatusBufferName": "rc",
    "StderrBufferName": "ErrBuf",
    "CommandBufferName": "ResolvedCommand",
    "DependentCommand": "%DependentCommand::$%",
    "CommandArguments": "%CommandArguments::$%",
    "StdinArguments": "%{ StdinArguments }%",
    "LogCommand": "%{ LogCommand }%",
    "LogCommandArguments": "%{ LogCommandArguments }%",
    "LogStdin": "%{ LogStdin }%",
    "LogStdout": "%{ LogStdout }%"
  }
}
```

### Build arguments from dependent-account context

This pattern is useful when your script owns the helper command and derives arguments from the dependent account that SPP resolved for the current `UpdateDependentSystem` call.

```json
{
  "SetItem": {
    "Name": "DependentArgs",
    "Value": "\"%DependentAccountUserName%\" \"%DependentAltUsername%\" \"%DependentUserNamespace%\" \"%DependentAccountType%\""
  }
}
{
  "ExecuteDependentCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "DependentCommand": "/usr/local/bin/update-dependent-password",
    "CommandArguments": "%DependentArgs%",
    "BufferName": "OutputBuffer",
    "ExitStatusBufferName": "rc",
    "StderrBufferName": "ErrBuf",
    "CommandBufferName": "ResolvedCommand"
  }
}
```

### Fail the operation when the dependent command returns a non-zero exit code

```json
{
  "Condition": {
    "If": "rc != 0",
    "Then": {
      "Do": [
        {
          "Throw": {
            "Value": "Dependent update failed. Command: %ResolvedCommand% Error: %ErrBuf::$%"
          }
        }
      ]
    }
  }
}
```

## Cross-References

- [Commands Index](index.md)
- [Operations](../operations.md#updatedependentsystem)
- [Variables](../variables.md)
- [Reserved Parameters](../reserved-parameters.md#dependent-system-updates)
- [Connect and Disconnect](connect.md)
- [ExecuteCommand](execute-command.md)
