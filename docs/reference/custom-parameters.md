[← Reference](README.md)

# Custom Parameters Reference

Custom parameters are the **non-reserved** parameter names you define in a custom platform script. They are for target-system values that SPP does not already model as built-in asset, account, or profile fields.

The key advantage is simple: **custom platforms can declare non-reserved names, but system platforms cannot**. System platforms are validated against reserved names only. Custom platforms can freely mix reserved and custom parameters in the same operation.

## Quick Reference

| Behavior | System platforms | Custom platforms | Example |
| --- | :---: | :---: | --- |
| Reserved names only | ✅ Required | ❌ Not required | `Address`, `AccountPassword` |
| Non-reserved names allowed | ❌ No | ✅ Yes | `APIURL`, `Realm`, `RetryIntervalSeconds` |
| Value entry | Built-in fields / reserved mapping | **Custom Script Parameters** on the asset | Per-asset values |
| Script default supported | N/A for auto-mapped reserved values | ✅ Yes | `"DefaultValue": 5` |

For readability, the examples on this page use a compact `Name`/`Type` JSON form. See [Script Structure](script-structure.md) for the exact upload format and [Operations](operations.md) for where these parameters are typically used.

```json
{
  "Parameters": [
    {"Name": "Address", "Type": "String"},
    {"Name": "APIURL", "Type": "String"},
    {"Name": "Realm", "Type": "String"},
    {"Name": "RetryIntervalSeconds", "Type": "Integer", "DefaultValue": 5}
  ]
}
```

---

## Defining Custom Parameters

Define custom parameters in an operation's `Parameters` array exactly where you define reserved parameters. If the name is **not** a reserved parameter name, SPP treats it as a custom parameter.

```json
{
  "Parameters": [
    {"Name": "APIURL", "Type": "String"},
    {"Name": "Realm", "Type": "String"},
    {"Name": "RetryIntervalSeconds", "Type": "Integer", "DefaultValue": 5}
  ]
}
```

At runtime, SPP reads the configured asset value for each custom parameter and passes it to the platform task engine when the operation executes.

> Use custom parameters when the target platform needs values such as a tenant URL, API path, realm, toggle, or retry setting that SPP does not already expose through a reserved parameter.

---

## Supported Types

Custom parameters support the same core scalar types used throughout custom platform scripts.

| Type | Use for | Example |
| --- | --- | --- |
| `String` | URLs, realms, tenant IDs, base paths, vendor-specific names | `APIURL`, `Realm`, `TenantUrl` |
| `Secret` | Sensitive values that admins must supply but SPP does not auto-map | `ApiToken`, `ClientSecret` |
| `Boolean` | On/off toggles for script behavior | `UseSandbox` |
| `Integer` | Whole-number settings such as retry counts or page sizes | `RetryIntervalSeconds` |
| `Float` | Fractional values such as thresholds or multipliers | `BackoffMultiplier` |

> Use `Secret` for any value that should be treated as sensitive, even if it is not one of SPP's built-in reserved secrets.

---

## Default Values

You can provide a default by adding `DefaultValue` to the parameter definition.

```json
{
  "Parameters": [
    {"Name": "Realm", "Type": "String"},
    {"Name": "RetryIntervalSeconds", "Type": "Integer", "DefaultValue": 5}
  ]
}
```

In that example:

- `RetryIntervalSeconds` starts with a default of `5`
- `Realm` has no default, so the asset administrator (or API automation) must supply a value

If you omit `DefaultValue`, SPP does not invent a target-specific value for you. Required custom parameters still need a per-asset value before the operation can run successfully.

> Updating a script later with a different default does not retroactively change the values already stored on existing assets.

---

## How They Appear in SPP

On assets that use the custom platform, true custom parameters appear in the **Custom Script Parameters** section. The administrator sets the value per asset, either when the asset is created or later during asset editing.

| Parameter | Who sets it | Example value |
| --- | --- | --- |
| `APIURL` | Asset admin | `wp-json/wp/v2` |
| `Realm` | Asset admin | `alpha` |
| `RetryIntervalSeconds` | Asset admin | `5` |

Unlike auto-populated [Reserved Parameters](reserved-parameters.md), these values remain visible in the asset editor because SPP cannot derive them from built-in fields.

---

## API Access

The same values can be set through the Core API. When you automate asset creation or updates with `Invoke-SafeguardMethod`, populate the asset's `CustomScriptParameters` collection.

```json
{
  "CustomScriptParameters": [
    {"Name": "APIURL", "TaskName": "CheckPassword", "Type": "String", "Value": "wp-json/wp/v2"},
    {"Name": "RetryIntervalSeconds", "TaskName": "ElevateAccount", "Type": "Integer", "Value": "5"}
  ]
}
```

The important point is that custom parameter values live on the **asset**, not in the script JSON itself.

---

## Mixing Reserved and Custom

Custom platforms can combine built-in reserved parameters with script-specific custom ones in the same operation.

```json
{
  "Parameters": [
    {"Name": "Address", "Type": "String"},
    {"Name": "AccountUserName", "Type": "String"},
    {"Name": "AccountPassword", "Type": "Secret"},
    {"Name": "APIURL", "Type": "String"},
    {"Name": "RetryIntervalSeconds", "Type": "Integer", "DefaultValue": 5}
  ]
}
```

In that example:

- `Address`, `AccountUserName`, and `AccountPassword` are reserved
- `APIURL` and `RetryIntervalSeconds` are true custom parameters

This is the core flexibility advantage of custom platforms: you still get SPP's built-in mappings where they exist, while adding platform-specific values where they do not.

---

## Best Practices

- Use descriptive names such as `TenantUrl`, `APIURL`, or `RetryIntervalSeconds`.
- Prefer a [Reserved Parameters](reserved-parameters.md) name when SPP already has a built-in field or runtime mapping for that value.
- Use `Secret` for tokens, client secrets, and other sensitive values.
- Add defaults only for safe, broadly reusable values — not for tenant-specific or sensitive data.
- Document custom parameters clearly for asset administrators, ideally with `Description` text in the script and supporting admin guidance.

---

## Cross-References

- [Reserved Parameters](reserved-parameters.md) — built-in names that SPP recognizes specially
- [Operations](operations.md) — where parameters are declared and used
- [Script Structure](script-structure.md) — exact JSON layout for operation parameter definitions
