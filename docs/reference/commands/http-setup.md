[← Command Reference](index.md)

# HTTP Request Setup

`NewHttpRequest`, `BaseAddress`, and `Headers` are the setup commands that shape an HTTP call before `Request` sends it.

Use them together when you need reusable request objects, a shared URL prefix, or explicit request headers.

## Typical sequence

```json
{
  "BaseAddress": { "Address": "https://%Address%" }
}
{
  "NewHttpRequest": { "ObjectName": "SystemRequest" }
}
{
  "Headers": {
    "RequestObjectName": "SystemRequest",
    "AddHeaders": {
      "Accept": "application/json",
      "Authorization": "SSWS %FuncPassword%"
    }
  }
}
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "SystemResponse",
    "Verb": "GET",
    "Url": "api/v1/users/%ParsedUser%",
    "SubstitutionInUrl": true,
    "IgnoreServerCertAuthentication": "%SkipServerCertValidation%"
  }
}
```

## `NewHttpRequest`

Creates an empty named request object that later commands can configure.

### Syntax

```json
{ "NewHttpRequest": { "ObjectName": "SystemRequest" } }
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `ObjectName` | String | Yes | Variable name for the request object. |

## `BaseAddress`

Sets the shared base URL for later relative `Request.Url` values.

### Syntax

```json
{ "BaseAddress": { "Address": "https://%Address%" } }
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Address` | String | Yes | Base URL prefix, such as `https://example.com` or `http://%Address%:%Port%`. |

## `Headers`

Adds one or more headers to a named request object.

### Syntax

```json
{
  "Headers": {
    "RequestObjectName": "SystemRequest",
    "AddHeaders": {
      "Accept-API-Version": "resource=2.0, protocol=1.0",
      "X-OpenAM-Username": "%AccountUsername%",
      "X-OpenAM-Password": "%AccountPassword%"
    }
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `RequestObjectName` | String | Yes | Existing request object to modify. |
| `AddHeaders` | Object | No | Header name/value map to add to the request object. Values support variable substitution and expressions. |

## Examples

### Build a WordPress request object after selecting HTTP or HTTPS

From `SampleScripts/HTTP/WordPressHttp.json`:

```json
{
  "Condition": {
    "If": "UseSsl",
    "Then": {
      "Do": [
        { "BaseAddress": { "Address": "https://%Address%" } }
      ]
    },
    "Else": {
      "Do": [
        { "BaseAddress": { "Address": "http://%Address%" } }
      ]
    }
  }
}
{
  "NewHttpRequest": { "ObjectName": "SystemRequest" }
}
```

### Add token-style authorization before an API request

From `SampleScripts/HTTP/Okta_WithDiscoveryAndGroupMembershipRestore.json`:

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

### Set multiple custom headers for an authentication endpoint

From `SampleScripts/HTTP/Forgerock_OpenAM.json`:

```json
{
  "Headers": {
    "RequestObjectName": "SystemRequest",
    "AddHeaders": {
      "Accept-API-Version": "resource=2.0, protocol=1.0",
      "X-OpenAM-Username": "%AccountUsername%",
      "X-OpenAM-Password": "%AccountPassword%"
    }
  }
}
```

## Notes

> `BaseAddress` is stored in the current script context, not inside a single request object. Once set, later relative `Url` values resolve against it until another `BaseAddress` command changes it.

> `Headers` and `HttpAuth` expect a real request object. In practice, create it first with `NewHttpRequest`.

> Add each header name once per request object. The request object stores headers in a dictionary, so attempting to add the same header again in a later `Headers` command can fail.

## Cross-References

- [Commands Index](index.md)
- [Request](request.md)
- [HTTP Authentication](http-auth.md)
- [Cookies](cookies.md)
- [Variables](../variables.md)
