# Utility Commands

Set variables, annotate script intent, pause execution, and emit discovered-account records.

These commands support the everyday work around HTTP, SSH, and discovery logic. They are commonly used together with expression interpolation such as `%AccountUserName%` or `%{ match.NextMatch() }%`; see [Variables](../variables.md).

## `SetItem` / `Declare`

Use `SetItem` to create or replace a variable. `Declare` is an alias that uses the same model. Prefix the name with `Global:` when later functions or later blocks must reuse the value.

### Syntax

```json
{
  "SetItem": {
    "Name": "DiscoveryResult",
    "Value": true
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Name` | String | Yes | Variable name to create or replace. Prefix with `Global:` when the value must survive beyond the current local scope. |
| `Value` | Value or expression | No | Value to assign. This can be a string, number, boolean, array, object, or `%{ expression }%`. |
| `IsSecret` | Boolean | No | Masks the stored value in logging and variable output. Default is `false`. |

### Examples

#### Store a value at local scope

From `SampleScripts/SSH/GenericLinuxWithDiscovery.json`:

```json
{ "SetItem": { "Name": "DiscoveryResult", "Value": true } }
```

#### Update a parsed match object during discovery

From `SampleScripts/SSH/GenericLinuxWithDiscovery.json`:

```json
{ "SetItem": { "Name": "match", "Value": "%{match.NextMatch()}%" } }
```

## `Comment`

Use `Comment` to leave a note in the JSON without affecting runtime behavior.

### Syntax

```json
{ "Comment": { "Text": "Able to connect, unable to log in" } }
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Text` | String | No | Free-form note for script maintainers. |

### Example

From `SampleScripts/Telnet/GenericCiscoIosTelnet.json`:

```json
{
  "Comment": {
    "Text": "Able to connect, unable to log in"
  }
}
```

## `Delay` (`Wait`)

Use `Wait` when the script must pause before retrying or reading a follow-up response. The current engine parameter is `Seconds`, so use fractional seconds if you need sub-second timing.

### Syntax

```json
{ "Wait": { "Seconds": 1 } }
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Seconds` | Number expression | Yes | Delay length in seconds. This can be a literal number or an expression such as `%{RetrySeconds}%`. |

### Examples

#### Short fixed delay

From `SampleScripts/SSH/vCenterServerAppliance.json`:

```json
{ "Wait": { "Seconds": 1 } }
```

#### Delay driven by a retry variable

From `SampleScripts/HTTP/OneLogin_GRC_JIT_addon.json`:

```json
{ "Wait": { "Seconds": "%{RetrySeconds}%" } }
```

## `WriteDiscoveredAccount`

Use `WriteDiscoveredAccount` during account discovery to emit one discovered-account record back to the platform. If `FilterQuery` is omitted, the script engine falls back to the reserved discovery query for the current operation.

### Syntax

```json
{
  "WriteDiscoveredAccount": {
    "Name": "%{match.Groups[\"uname\"].Value}%",
    "UserId": "%{match.Groups[\"uid\"].Value}%",
    "GroupId": "%{match.Groups[\"gid\"].Value}%",
    "Groups": "%{match.Groups[\"groupid\"].Captures.Cast<Capture>().Select((groupIdCapture,index) =>new DiscoveredGroup(GroupNames[index], groupIdCapture.Value))}%"
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Name` | Value or expression | Yes | Discovered account name. |
| `UserId` | Value or expression | No | Account identifier on the target system. |
| `Sid` | Value or expression | No | Security identifier. When present, the engine derives the relative ID from it. |
| `GroupId` | Value or expression | No | Primary group identifier. |
| `Groups` | Value or expression | No | Group collection to attach to the discovered account. |
| `Roles` | Value or expression | No | Role collection to attach to the discovered account. |
| `Permissions` | Value or expression | No | Permission collection to attach to the discovered account. |
| `FilterQuery` | Account discovery query object | No | Optional filter override. When omitted, the current discovery query is used. |

### Example

From `SampleScripts/SSH/GenericLinuxWithDiscovery.json`:

```json
{
  "WriteDiscoveredAccount": {
    "Name": "%{match.Groups[\"uname\"].Value}%",
    "UserId": "%{match.Groups[\"uid\"].Value}%",
    "GroupId": "%{match.Groups[\"gid\"].Value}%",
    "Groups": "%{match.Groups[\"groupid\"].Captures.Cast<Capture>().Select((groupIdCapture,index) =>new DiscoveredGroup(GroupNames[index], groupIdCapture.Value))}%"
  }
}
```

## Notes

> `Declare` is an alias for `SetItem`; use whichever reads best in your script, but both resolve to the same engine behavior.

> There is no separate `Delay` keyword in current scripts; delay behavior uses `Wait`.

## Cross-References

- [Commands Index](index.md)
- [Logging and Status](logging.md)
- [Output](output.md)
- [Variables](../variables.md)
