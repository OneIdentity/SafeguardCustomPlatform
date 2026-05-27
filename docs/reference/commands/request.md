# Request

`Request` sends an HTTP request and optionally stores the response object for later parsing, status checks, header inspection, or follow-up logic.

It is the core HTTP command: build or reference a request object, choose the verb and URL, then inspect the response in later commands.

## Syntax

```json
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "SystemResponse",
    "Verb": "POST",
    "Url": "api/v1/users/%UserId%",
    "SubstitutionInUrl": true,
    "IgnoreServerCertAuthentication": "%SkipServerCertValidation%",
    "AllowRedirect": true,
    "PersistCookies": true,
    "IsSecret": false,
    "UrlIsSecret": false,
    "ProxyIp": "%ProxyHost%",
    "ProxyPort": "%ProxyPort%",
    "ProxyUser": "%ProxyUser%",
    "ProxyPassword": "%ProxyPassword%",
    "Content": {
      "ContentObjectName": "UpdateJson",
      "ContentType": "application/json"
    }
  }
}
```

## Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `RequestObjectName` | String | Yes | Name of the HTTP request object to use. Create it first with `NewHttpRequest` when you need headers or auth. |
| `ResponseObjectName` | String | No | Variable name that receives the response object. |
| `Verb` | String | Yes | HTTP method. Supported values are `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD`, `OPTIONS`, and `TRACE`. |
| `Url` | String | Yes | Relative URL (when a base address is set) or a fully qualified URL. |
| `SubstitutionInUrl` | Boolean | No | When `true`, `%Name%` and `%{ expression }%` syntax inside `Url` is resolved before the request is sent. Default is `false`. |
| `IgnoreServerCertAuthentication` | Boolean expression | No | Skip server certificate validation for HTTPS requests. Default is `false`. |
| `AllowRedirect` | Boolean | No | Follow redirect responses automatically. Default is `true`. |
| `PersistCookies` | Boolean | No | Keep response cookies in the shared HTTP session for later requests. Default is `true`. |
| `IsSecret` | Boolean | No | Masks the stored response object and response-body logging. Default is `false`. |
| `UrlIsSecret` | Boolean | No | Masks the URL in logs. Default is `false`. |
| `ProxyIp` | String | No | Proxy host or IP address. |
| `ProxyPort` | Integer | No | Proxy port. |
| `ProxyUser` | String | No | Proxy username. |
| `ProxyPassword` | Secret | No | Proxy password. |
| `Content.ContentObjectName` | String | No | Variable containing the body object to serialize and send. |
| `Content.ContentType` | String | No | MIME type applied to the serialized body, for example `application/json` or `application/x-www-form-urlencoded`. |

## Response object

When `ResponseObjectName` is set, later expressions can read these commonly used properties:

| Property | Description |
| --- | --- |
| `StatusCode` | HTTP status code enum, commonly checked as `SystemResponse.StatusCode == 200` or `StatusCode.ToString()`. |
| `Content` | Response body as a string. |
| `ContentType` | Response content type, such as `application/json`. |
| `Headers` | Header dictionary, for example `LoginPostResponse.Headers["Location"][0]`. |
| `Cookies` | Parsed cookies returned by the response. |
| `RequestUri` | Final request URI. |
| `RequestUriAbsoluteUriQueryParams` | Parsed query-string values from the request URI. |

## Examples

### Simple GET request with Basic auth context

From `SampleScripts/HTTP/WordPressHttp.json`:

```json
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "SystemResponse",
    "Verb": "GET",
    "Url": "%{APIURL}%/settings",
    "SubstitutionInUrl": true,
    "IgnoreServerCertAuthentication": "%{SkipServerCertValidation}%",
    "Content": {
      "ContentType": "application/json"
    }
  }
}
```

### POST a JSON body to an API

From `SampleScripts/HTTP/Okta_WithDiscoveryAndGroupMembershipRestore.json`:

```json
{
  "SetItem": {
    "Name": "UpdateJson",
    "Value": {
      "credentials": {
        "password": "%NewPassword%"
      }
    }
  }
}
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "SystemResponse",
    "Verb": "POST",
    "Url": "api/v1/users/%UserId%",
    "SubstitutionInUrl": true,
    "IgnoreServerCertAuthentication": "%SkipServerCertValidation%",
    "Content": {
      "ContentType": "application/json",
      "ContentObjectName": "UpdateJson"
    }
  }
}
```

### Inspect redirect headers after a login form post

From `SampleScripts/HTTP/CustomTwitter.json`:

```json
{
  "Request": {
    "Verb": "Post",
    "Url": "sessions",
    "RequestObjectName": "LoginPostRequest",
    "ResponseObjectName": "Global:LoginPostResponse",
    "AllowRedirect": false,
    "Content": {
      "ContentObjectName": "LoginForm",
      "ContentType": "application/x-www-form-urlencoded"
    }
  }
}
{
  "Condition": {
    "If": "LoginPostResponse.StatusCode.ToString().Equals(\"Redirect\") && LoginPostResponse.Headers[\"Location\"][0].StartsWith(\"https://twitter.com/login/error\")",
    "Then": {
      "Do": [
        { "Return": { "Value": false } }
      ]
    }
  }
}
```

## Notes

> If no `BaseAddress` is set, `Url` must be a fully qualified `http://` or `https://` address.

> `ContentType` is only applied when `ContentObjectName` is present. An empty `Content` block is allowed, but it does not create a body by itself.

> `PersistCookies` defaults to `true`, which is why multi-step browser-style flows in the Twitter and ForgeRock samples can log in first and then reuse the session in later `Request` calls.

> `SubstitutionInUrl` defaults to `false`. Turn it on when the URL contains `%Address%`, `%UserId%`, or `%{ expression }%` fragments.

## Cross-References

- [Commands Index](index.md)
- [HTTP Request Setup](http-setup.md)
- [HTTP Authentication](http-auth.md)
- [Cookies](cookies.md)
- [Forms](forms.md)
- [JSON](json.md)
- [Variables](../variables.md)
