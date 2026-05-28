# Output Commands

Write the final value that the platform consumes after the script finishes.

Use output commands when a task must return a host key, discovery record, or other response payload. These commands are typically the last step in a `Do` block, after variables and expressions have already shaped the data you want to return.

## `WriteResponseObject`

Use `WriteResponseObject` to emit a final response value or object.

### Syntax

```json
{
  "WriteResponseObject": {
    "Value": "%HostKey::$%"
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Value` | Value or expression | No | Object, string, or other value to write to the final response payload. |

### Example

From `SampleScripts/SSH/GenericLinuxWithDiscovery.json`:

```json
{ "WriteResponseObject": { "Value": "%HostKey::$%" } }
```

## `WriteResponseProperty` (supported pattern)

Current scripts and current engine source do not expose a separate `WriteResponseProperty` command. When you need named properties in the response, build the object first and then emit it with `WriteResponseObject`.

### Syntax

```json
{
  "SetItem": {
    "Name": "ResponseData",
    "Value": {
      "HostKey": "%HostKey::$%"
    }
  }
}
{
  "WriteResponseObject": {
    "Value": "%ResponseData%"
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `SetItem.Name` | String | Yes | Variable that will hold the response object you are assembling. |
| `SetItem.Value` | Object, value, or expression | Yes | Object containing the named properties you want to return. |
| `WriteResponseObject.Value` | Value or expression | Yes | Variable or expression that resolves to the completed response object. |

### Example

Sample scripts typically return the completed value directly rather than writing individual properties. For example, `SampleScripts/SSH/GenericLinuxWithDiscovery.json` returns the discovered host key in one step:

```json
{ "WriteResponseObject": { "Value": "%HostKey::$%" } }
```

## Notes

> Multiple output-oriented commands can be used in a discovery task. For example, discovery functions may emit many `WriteDiscoveredAccount` records, while a host-key retrieval operation usually emits a single `WriteResponseObject` value.

> There is no separate `WriteResponseProperty` keyword in current scripts; compose an object first, then return it with `WriteResponseObject`.

## Cross-References

- [Commands Index](index.md)
- [Utilities](utilities.md)
- [SSH Host Key](ssh-host-key.md)
- [Variables](../variables.md)
