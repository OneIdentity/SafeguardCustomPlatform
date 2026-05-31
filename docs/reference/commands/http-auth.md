[← Command Reference](index.md)

# HTTP Authentication

`HttpAuth` applies built-in HTTP authentication settings to a named request object before `Request` sends it.

Current script-engine support is focused on `Basic` and `Digest` authentication. Token-style schemes are usually modeled with `Headers` instead.

## Supported authentication types

| Type | How it works | Extra fields |
| --- | --- | --- |
| `Basic` | Adds an `Authorization: Basic ...` header to the request object. | `Credentials.Login`, `Credentials.Password` |
| `Digest` | Stores credentials in the request object's credential cache for digest challenge/response flows. | `Credentials.Login`, `Credentials.Password`, `Credentials.Uri`, optional `Credentials.Domain` |

## Syntax

### Basic

```json
{
  "HttpAuth": {
    "RequestObjectName": "SystemRequest",
    "Type": "Basic",
    "Credentials": {
      "Login": "%FuncUsername%",
      "Password": "%FuncPassword%"
    }
  }
}
```

### Digest

```json
{
  "HttpAuth": {
    "RequestObjectName": "SystemRequest",
    "Type": "Digest",
    "Credentials": {
      "Login": "%FuncUserName%",
      "Password": "%FuncPassword%",
      "Uri": "%AddressGiven%/HTTP/Digest/",
      "Domain": "example"
    }
  }
}
```

## Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `RequestObjectName` | String | Yes | Existing request object to modify. |
| `Type` | String | Yes | Authentication type. Supported values are `Basic` and `Digest`. |
| `Credentials.Login` | String expression | Yes | Username or login name. |
| `Credentials.Password` | Secret expression | Yes | Password for the selected auth type. |
| `Credentials.Uri` | String expression | Digest only | Absolute URI used to build the digest credential cache entry. |
| `Credentials.Domain` | String expression | No | Optional domain for digest auth. |

## Examples

### Basic auth against a WordPress REST API

From `samples/http/wordpress/WordPressHttp.json`:

```json
{
  "NewHttpRequest": { "ObjectName": "SystemRequest" }
}
{
  "HttpAuth": {
    "RequestObjectName": "SystemRequest",
    "Type": "Basic",
    "Credentials": {
      "Login": "%FuncUsername%",
      "Password": "%FuncPassword%"
    }
  }
}
```

### Basic auth with managed-account credentials

From `samples/http/wordpress/WordPressHttp.json`:

```json
{
  "HttpAuth": {
    "RequestObjectName": "SystemRequest",
    "Type": "Basic",
    "Credentials": {
      "Login": "%AccountUserName%",
      "Password": "%AccountPassword%"
    }
  }
}
```

### Token-style authorization via `Headers`

From `samples/http/okta-discovery/Okta_WithDiscoveryAndGroupMembershipRestore.json`:

```json
{
  "Headers": {
    "RequestObjectName": "SystemRequest",
    "AddHeaders": {
      "Authorization": "SSWS %FuncPassword%"
    }
  }
}
```

## Notes

> `HttpAuth` does **not** currently implement `Bearer`, `NTLM`, or similar schemes. Use `Headers` to add `Authorization: Bearer ...`, `SSWS ...`, or other token formats.

> `Basic` auth writes an `Authorization` header directly onto the request object.

> `Digest` auth requires `Credentials.Uri` because the credential cache is keyed by URI.

## Cross-References

- [Commands Index](index.md)
- [HTTP Request Setup](http-setup.md)
- [Request](request.md)
- [Variables](../variables.md)
