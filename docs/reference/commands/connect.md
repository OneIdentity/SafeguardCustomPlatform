[← Command Reference](index.md)

# Connect and Disconnect

`Connect` opens an SSH or Telnet session and stores it in a named connection object. `Disconnect` closes that object when the script is done with the session.

Use `Connect` at the start of a function or operation, reuse the connection with `Send`, `Receive`, or `ExecuteCommand`, and always clean up with `Disconnect`.

## Global scope pattern

A common SSH pattern is to create the connection as `Global:ConnectSsh` in one function and then reuse the same object later as `ConnectSsh` from `Send`, `Receive`, `ExecuteCommand`, or `Disconnect`.

## `Connect`

Opens a remote connection. Operation parameters are often named `Address`, `UserName`, or `Protocol`, but the command itself uses `NetworkAddress`, `Login`, and `Type`.

### Syntax

```json
{
  "Connect": {
    "ConnectionObjectName": "Global:ConnectSsh",
    "Type": "Ssh",
    "NetworkAddress": "%Address%",
    "Port": "%Port%",
    "Login": "%UserName%",
    "Password": "%Password::$%",
    "UserKey": "%UserKey::$%",
    "RequestTerminal": "%RequestTerminal%",
    "CheckHostKey": "%CheckHostKey%",
    "HostKey": "%HostKey::$%",
    "Timeout": "%Timeout%",
    "SoftwareVersionVariableName": "GLOBAL:ServerSoftwareName"
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `ConnectionObjectName` | String | Yes | Variable name that receives the connection object. Prefix with `Global:` or `GLOBAL:` when later functions must reuse it. |
| `Type` | String | Yes | Connection type. Common values are `Ssh` and `Telnet`. |
| `NetworkAddress` | String expression | Yes | Target host or IP address. Scripts usually pass `%Address%` here. |
| `Port` | Integer expression | No | Remote port number. |
| `Login` | String expression | Yes | Login name for the connection. Scripts usually pass `%UserName%` or `%FuncUserName%`. |
| `Password` | Secret expression | No | Password used for password-based authentication. |
| `UserKey` | Secret expression | No | SSH private key content used for key-based authentication. |
| `RequestTerminal` | Boolean expression | No | Request an interactive terminal (PTY). Default is `true`. Set it to `false` for `ExecuteCommand`. |
| `CheckHostKey` | Boolean expression | No | Validate the remote SSH host key against `HostKey`. Default is `true`. |
| `HostKey` | String or secret expression | No | Expected SSH host key value. Required when `CheckHostKey` is `true`. |
| `AutoAdjustCiphers` | Boolean | No | Broadens SSH algorithm negotiation for older systems. Some scripts surface this behavior through a custom variable such as `Global:EnableAllCiphers`. |
| `Timeout` | Integer expression | No | Connection timeout value. `0` or an omitted value falls back to the engine default. |
| `SoftwareVersionVariableName` | String | No | Variable that receives the server software banner reported during connection setup. |

## `Disconnect`

Closes an existing connection object.

### Syntax

```json
{ "Disconnect": { "ConnectionObjectName": "ConnectSsh" } }
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `ConnectionObjectName` | String | Yes | Existing connection object to close. Use the same name created by `Connect`. |

## Examples

### SSH connection with password authentication

From `samples/ssh/generic-linux/GenericLinux.json`:

```json
{
  "Connect": {
    "ConnectionObjectName": "Global:ConnectSsh",
    "Type": "Ssh",
    "Port": "%Port%",
    "NetworkAddress": "%Address%",
    "Login": "%UserName%",
    "Password": "%Password::$%",
    "RequestTerminal": "%RequestTerminal%",
    "CheckHostKey": "%CheckHostKey%",
    "HostKey": "%HostKey::$%",
    "Timeout": "%Timeout%"
  }
}
{ "Receive": { "ConnectionObjectName": "ConnectSsh", "BufferName": "LoginCheckBuffer" } }
```

### SSH connection with key authentication

From `samples/ssh/restricted-authorized-key/RestrictedAuthorizedKeyExample.json`:

```json
{
  "Connect": {
    "ConnectionObjectName": "Global:ConnectSsh",
    "Type": "Ssh",
    "Port": "%Port%",
    "NetworkAddress": "%Address%",
    "Login": "%FuncUserName%",
    "RequestTerminal": false,
    "UserKey": "%UserKey::$%",
    "CheckHostKey": "%CheckHostKey%",
    "HostKey": "%HostKey::$%",
    "Timeout": "%Timeout%",
    "SoftwareVersionVariableName": "GLOBAL:ServerSoftwareName"
  }
}
```

### Telnet connection

From `samples/telnet/cisco-ios/GenericCiscoIosTelnet.json`:

```json
{
  "Connect": {
    "ConnectionObjectName": "Global:TelnetConnection",
    "Type": "Telnet",
    "Port": "%Port%",
    "NetworkAddress": "%Address%",
    "Login": "%ConnectUsername%",
    "Timeout": "%Timeout%"
  }
}
```

## Notes

> `RequestTerminal` defaults to `true`. Keep that default for interactive `Send`/`Receive` sessions, and set it to `false` for `ExecuteCommand` batch mode.

> If `CheckHostKey` is `true`, the script engine requires a `HostKey` value before it will connect.

> The connection object is just a variable. A common pattern is to create `Global:ConnectSsh` in one function, then refer to the same object later as `ConnectSsh` from other functions.

## Cross-References

- [Commands Index](index.md)
- [Send and Receive](send-receive.md)
- [ExecuteCommand](execute-command.md)
- [SSH Host Key](ssh-host-key.md)
- [Variables](../variables.md)
