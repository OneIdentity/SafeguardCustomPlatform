# Logging and Status Commands

Write diagnostic messages and update the task status shown to users.

Use these commands when you need more visibility during a run. `Log` adds operator-facing detail to the task log, while `Status` updates progress and localized status text in the UI. For status-message IDs and their wording, see [Status Messages](../status-messages.md).

## `Log`

Use `Log` to add a message to the task log from script logic.

### Syntax

```json
{
  "Log": {
    "Text": "Entered root shell"
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Text` | Value or expression | No | Message text written to the operation log. |

### Examples

#### Log a state transition

From `SampleScripts/SSH/vCenterServerAppliance.json`:

```json
{ "Log": { "Text": "Entered root shell" } }
```

#### Log a task-specific warning

From `SampleScripts/HTTP/OneLogin_GRC_JIT_addon.json`:

```json
{
  "Log": {
    "Text": "ChangePassword does not do anything. A dummy password is set on the Account by OneLogin but in practice these Accounts will only have TOTP configured and used. Do not use the ChangePassword task."
  }
}
```

## `Trace` (diagnostic pattern)

Current scripts and current engine source do not expose a separate `Trace` command. Use `Log` for explicit script-authored diagnostics, and enable extended logging when you need the engine's debug-level trace output around command execution.

### Syntax

```json
{ "Log": { "Text": "Entered root shell" } }
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Text` | Value or expression | No | Closest script-authored equivalent to a trace message in current scripts. |

### Example

From `SampleScripts/SSH/vCenterServerAppliance.json`:

```json
{ "Log": { "Text": "No users discovered" } }
```

## `SetStatusMessage` (`Status`)

Use `Status` to publish progress and a localized message while the task is running. This is what end users see in the UI during longer checks, changes, or discovery operations.

### Syntax

```json
{
  "Status": {
    "Type": "Checking",
    "Percent": 60,
    "Message": {
      "Name": "AssetTestingConnectionWithAddress",
      "Parameters": [ "%AssetName%", "%Address%" ]
    }
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Type` | Status enum | Yes | Status category such as `Connecting`, `Checking`, `Changing`, or `Discovering`. |
| `Percent` | Integer | Yes | Completion percentage from `0` to `100`. |
| `Message.Name` | Message ID enum | Yes | Predefined status message identifier from the platform task engine. |
| `Message.Parameters` | Array of values or expressions | No | Values inserted into the localized status message. |

### Examples

#### Report connection-test progress

From `SampleScripts/SSH/GenericLinux.json`:

```json
{
  "Status": {
    "Type": "Checking",
    "Percent": 60,
    "Message": {
      "Name": "AssetTestingConnectionWithAddress",
      "Parameters": [ "%AssetName%", "%Address%" ]
    }
  }
}
```

#### Report discovery progress

From `SampleScripts/SSH/GenericLinuxWithDiscovery.json`:

```json
{
  "Status": {
    "Type": "Discovering",
    "Percent": 75,
    "Message": {
      "Name": "DiscoveringAccounts",
      "Parameters": [ "%AssetName%" ]
    }
  }
}
```

## Notes

> Current script-authored logging exposes only `Log.Text`; severity is not configurable from the command itself in the current engine source.

> There is no separate `SetStatusMessage` keyword in current scripts; status updates use `Status`.

## Cross-References

- [Commands Index](index.md)
- [Utilities](utilities.md)
- [Status Messages](../status-messages.md)
- [Variables](../variables.md)
