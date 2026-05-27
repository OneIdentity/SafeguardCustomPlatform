# DiscoverSshHostKey

`DiscoverSshHostKey` performs the SSH handshake needed to read the remote host key before any login occurs.

Use it inside the `DiscoverSshHostKey` or `RetrieveSshHostKey` operations to capture the asset's trusted host key, optionally record the server software banner, and then return the discovered value with `WriteResponseObject`.

## Syntax

```json
{
  "DiscoverSshHostKey": {
    "HostKeyVariableName": "HostKey",
    "SoftwareVersionVariableName": "GLOBAL:ServerSoftwareName",
    "Port": "%Port%",
    "NetworkAddress": "%Address%",
    "Timeout": "%Timeout%"
  }
}
```

## Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `HostKeyVariableName` | String | Yes | Variable that receives the discovered host key value. |
| `SoftwareVersionVariableName` | String | No | Variable that receives the server software banner reported during negotiation. |
| `NetworkAddress` | String expression | Yes | Target host or IP address. Scripts usually pass `%Address%` here. |
| `Port` | Integer expression | No | SSH port number. |
| `AutoAdjustCiphers` | Boolean | No | Broadens SSH algorithm negotiation for older systems. Some scripts expose this through a custom variable such as `EnableAllCiphers`. |
| `Timeout` | Integer expression | No | Discovery timeout value. |

## Typical operation pattern

```json
{
  "DiscoverSshHostKey": {
    "HostKeyVariableName": "HostKey",
    "Port": "%Port%",
    "NetworkAddress": "%Address%",
    "Timeout": "%Timeout%"
  }
}
{ "WriteResponseObject": { "Value": "%HostKey::$%" } }
```

## Examples

### Asset host-key discovery with software version capture

From `SampleScripts/SSH/GenericLinuxWithSSHKeySupport.json`:

```json
{
  "DiscoverSshHostKey": {
    "HostKeyVariableName": "HostKey",
    "SoftwareVersionVariableName": "GLOBAL:ServerSoftwareName",
    "Port": "%Port%",
    "NetworkAddress": "%Address%",
    "Timeout": "%Timeout%"
  }
}
{ "WriteResponseObject": { "Value": "%HostKey::$%" } }
```

### Minimal host-key discovery

From `SampleScripts/SSH/LinuxSshBatchModeExample.json`:

```json
{
  "DiscoverSshHostKey": {
    "HostKeyVariableName": "HostKey",
    "Port": "%Port%",
    "NetworkAddress": "%Address%",
    "Timeout": "%Timeout%"
  }
}
{ "WriteResponseObject": { "Value": "%HostKey::$%" } }
```

## Notes

> `DiscoverSshHostKey` does not require `Login`, `Password`, or `UserKey`. It only performs the pre-authentication SSH negotiation needed to read the host key.

> The command writes the discovered value into `HostKeyVariableName`; returning it to the platform is a separate step, usually `WriteResponseObject`.

> `RetrieveSshHostKey` implementations are commonly identical to `DiscoverSshHostKey` implementations. The operation name changes, but the command usage is the same.

## Cross-References

- [Commands Index](index.md)
- [Connect and Disconnect](connect.md)
- [Operations](../operations.md)
- [Variables](../variables.md)
