[← Command Reference](index.md)

# JSON

`ExtractJsonObject` parses JSON text into an object that later commands and expressions can inspect.

Use it after an API call when the response body contains JSON, or against a string variable that already holds JSON text.

## Syntax

```json
{
  "ExtractJsonObject": {
    "JsonObjectName": "SystemResponse",
    "Name": "UserResponseJson",
    "ContainsSecret": false
  }
}
```

## Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `JsonObjectName` | String | Yes | Source variable. This can be a response object or a string variable containing JSON text. |
| `Name` | String | Yes | Variable name for the parsed JSON object. |
| `ContainsSecret` | Boolean | No | Masks the stored JSON object in logs. Default is `false`. |

## Property access

After parsing, expressions can inspect the object directly.

```json
{ "SetItem": { "Name": "UserId", "Value": "%{ GetUserResponseJson.id }%" } }
{ "Return": { "Value": "%{ ParsedUsers[0].id }%" } }
{ "Condition": { "If": "User.name.Value == AccountUserName" } }
```

## Examples

### Parse a WordPress users response into a collection

From `samples/http/wordpress/WordPressHttp.json`:

```json
{
  "SetItem": { "Name": "ParsedUsers", "Value": "" }
}
{
  "ExtractJsonObject": {
    "JsonObjectName": "SystemUsers",
    "Name": "ParsedUsers"
  }
}
{
  "ForEach": {
    "CollectionName": "ParsedUsers",
    "ElementName": "User",
    "Body": {
      "Do": [
        {
          "Condition": {
            "If": "User.name.Value == AccountUserName"
          }
        }
      ]
    }
  }
}
```

### Parse an Okta API response and return a property

From `samples/http/okta-discovery/Okta_WithDiscoveryAndGroupMembershipRestore.json`:

```json
{
  "ExtractJsonObject": {
    "JsonObjectName": "SystemResponse",
    "Name": "GetUserResponseJson"
  }
}
{
  "Condition": {
    "If": "SystemResponse.StatusCode == 200",
    "Then": {
      "Do": [
        { "Return": { "Value": "%{GetUserResponseJson.id}%" } }
      ]
    }
  }
}
```

### Parse ForgeRock authentication output

From `samples/http/forgerock-openam/Forgerock_OpenAM.json`:

```json
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "SystemResponse",
    "Verb": "POST",
    "Url": "%url%",
    "SubstitutionInUrl": true,
    "IgnoreServerCertAuthentication": "%SkipServerCertValidation%",
    "Content": {
      "ContentType": "application/json"
    }
  }
}
{
  "ExtractJsonObject": {
    "JsonObjectName": "SystemResponse",
    "Name": "AuthResponseJson"
  }
}
```

## Notes

> When `JsonObjectName` points to a response object, the response content type must be `application/json`. If the endpoint returns another content type, parse the raw string yourself first.

> `ExtractJsonObject` also accepts a plain string variable, which is useful when JSON text is built or cleaned up before parsing.

> Parsed JSON values are typically accessed with `%{ Object.Property }%`, `%{ Array[0] }%`, or the `.Value` access pattern shown in older samples.

## Cross-References

- [Commands Index](index.md)
- [Request](request.md)
- [HTTP Request Setup](http-setup.md)
- [Variables](../variables.md)
