# Safeguard Custom Platform JSON Schema

This schema adds editor-friendly **autocomplete**, **validation**, and **hover documentation** for Safeguard Custom Platform scripts.

## Automatic setup in VS Code

This repository includes `.vscode/settings.json`, so anyone who clones the repo in VS Code gets automatic schema association for `SampleScripts/**/*.json`.

## Manual setup for other editors

Any editor with JSON Schema support can point matching script files at:

`https://raw.githubusercontent.com/petrsnd/SafeguardCustomPlatform/main/schema/custom-platform-script.schema.json`

Useful docs:

- VS Code JSON Schema settings: https://code.visualstudio.com/docs/languages/json#_json-schemas-and-settings
- JetBrains custom JSON schemas: https://www.jetbrains.com/help/idea/json.html#ws_json_schema_add_custom

## Safe use of `$schema`

`$schema` can safely be added directly to script files. SPP ignores unknown top-level properties like `$schema` while still validating the rest of the script normally.

Example:

```json
{
  "$schema": "https://raw.githubusercontent.com/petrsnd/SafeguardCustomPlatform/main/schema/custom-platform-script.schema.json",
  "Id": "CustomFacebook",
  "BackEnd": "Scriptable",
  "CheckPassword": {
    "Parameters": [],
    "Do": []
  }
}
```
