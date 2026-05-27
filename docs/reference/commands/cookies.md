# Cookies

`GetCookie`, `SetCookie`, and `ClearCookie` let a script inspect or manipulate the HTTP cookie jar directly.

Most browser-style login flows do not need these commands on every step because `Request` persists cookies automatically by default. Use the explicit cookie commands when you need to seed, inspect, or remove cookie values yourself.

## Automatic session behavior

A typical login flow simply relies on `Request` with the default `PersistCookies: true`.

From `SampleScripts/HTTP/CustomTwitter.json`:

```json
{
  "Request": {
    "Verb": "Get",
    "Url": "login",
    "RequestObjectName": "LoginRequest",
    "ResponseObjectName": "Global:LoginResponse",
    "AllowRedirect": true
  }
}
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
```

The cookies issued by the first response stay available to later requests in the same task unless you disable `PersistCookies`.

## `GetCookie`

Reads a cookie value into a variable.

### Syntax

```json
{
  "GetCookie": {
    "Name": "sessionid",
    "Domain": "example.com",
    "Path": "/",
    "VariableName": "SessionCookie"
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Name` | String expression | Yes | Cookie name to look up. |
| `Domain` | String expression | Yes | Cookie domain, such as `example.com` or `https://example.com`. |
| `Path` | String expression | No | Cookie path. |
| `VariableName` | String | Yes | Variable that receives the cookie value. The value is stored as secret. |

## `SetCookie`

Creates or overwrites a cookie entry in the shared cookie jar.

### Syntax

```json
{
  "SetCookie": {
    "Name": "aws-at-main",
    "Domain": "amazon.com",
    "Path": "/",
    "Value": "",
    "Secure": true
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Name` | String expression | Yes | Cookie name to create or overwrite. |
| `Domain` | String expression | Yes | Cookie domain. |
| `Path` | String expression | No | Cookie path. |
| `Value` | String expression | No | Cookie value. |
| `Secure` | Boolean expression | No | Marks the cookie as secure and uses `https://` when the domain is not already fully qualified. |

## `ClearCookie`

Expires one or more cookies in the shared cookie jar.

### Syntax

```json
{
  "ClearCookie": {
    "Name": ["sessionid", "remember_me"],
    "Domain": "example.com",
    "Path": "/"
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Name` | String or string array expression | Yes | Cookie name, or an array of cookie names, to expire. |
| `Domain` | String expression | Yes | Cookie domain to clear from. |
| `Path` | String expression | No | Cookie path. |

## Examples

### Seed cookies before a console login flow

From the built-in `System/Aws.json` platform definition:

```json
{
  "SetCookie": {
    "Name": "aws-userInfo-signed",
    "Domain": "amazon.com",
    "Path": "/",
    "Value": "",
    "Secure": true
  }
}
{
  "SetCookie": {
    "Name": "aws-creds",
    "Domain": "signin.aws.amazon.com",
    "Path": "/",
    "Value": "",
    "Secure": true
  }
}
```

### Read a cookie into a secret variable

```json
{
  "GetCookie": {
    "Name": "iPlanetDirectoryPro",
    "Domain": "https://%Address%",
    "Path": "/openam",
    "VariableName": "SessionCookie"
  }
}
```

### Clear multiple cookies before retrying login

```json
{
  "ClearCookie": {
    "Name": ["iPlanetDirectoryPro", "amlbcookie"],
    "Domain": "%Address%",
    "Path": "/openam"
  }
}
```

## Notes

> `Request` persists cookies automatically unless you set `PersistCookies` to `false`. Manual cookie commands are usually only needed for special cases.

> `GetCookie` stores the retrieved value as a secret variable, so it is masked in logs.

> `ClearCookie.Name` can be a single string or an array of cookie names.

> For secure cookies, prefer a fully qualified `https://` domain when reading with `GetCookie`. A bare domain is treated as `http://` for lookup.

## Cross-References

- [Commands Index](index.md)
- [Request](request.md)
- [HTTP Request Setup](http-setup.md)
- [Forms](forms.md)
- [Variables](../variables.md)
