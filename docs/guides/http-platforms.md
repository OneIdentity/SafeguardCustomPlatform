[← Documentation](../README.md)

# HTTP/REST API Platforms

HTTP-based custom platforms let Safeguard call a target system's web API instead of opening an SSH session. This guide shows the patterns that work well for REST APIs, token-based authentication, browser-style forms, and discovery operations.

## Table of Contents

- [How HTTP platforms work](#how-http-platforms-work)
- [Authentication patterns](#authentication-patterns)
  - [Basic authentication](#basic-authentication)
  - [Bearer and OAuth2 tokens](#bearer-and-oauth2-tokens)
  - [API keys in headers](#api-keys-in-headers)
  - [Cookie-based authentication](#cookie-based-authentication)
- [Common end-to-end flow](#common-end-to-end-flow)
- [Using `Request` with common HTTP methods](#using-request-with-common-http-methods)
- [Working with JSON responses](#working-with-json-responses)
- [Working with HTML forms](#working-with-html-forms)
- [Cookie management](#cookie-management)
- [HTTPS and TLS considerations](#https-and-tls-considerations)
- [Pagination patterns for discovery](#pagination-patterns-for-discovery)
- [Error handling and retries](#error-handling-and-retries)
- [Proxy support](#proxy-support)
- [Related references](#related-references)

## How HTTP platforms work

An HTTP platform operation is just a sequence of script-engine commands that build requests, send them, inspect the response, and return success or failure.

The usual building blocks are:

1. Set a base URL with [`BaseAddress`](../reference/commands/http-setup.md).
2. Create a request object with [`NewHttpRequest`](../reference/commands/http-setup.md).
3. Add auth or headers with [`HttpAuth`](../reference/commands/http-auth.md) or [`Headers`](../reference/commands/http-setup.md).
4. Send the call with [`Request`](../reference/commands/request.md).
5. Inspect `StatusCode`, headers, cookies, or response content.
6. Parse JSON with [`ExtractJsonObject`](../reference/commands/json.md) or HTML forms with [`ExtractFormData`](../reference/commands/forms.md).
7. Branch with `Condition`, loop with `For`/`ForEach`, and fail with `Throw`.

A few practical rules matter:

- Safeguard is making web requests, not automating a browser. It does not execute JavaScript.
- Variables, request objects, and cookies live for the current operation run.
- `BaseAddress` stays in effect until another `BaseAddress` command changes it.
- `Request` persists cookies by default, which is why multi-step login flows work without manually copying cookies on every step.

A minimal HTTP request flow looks like this:

```json
[
  { "BaseAddress": { "Address": "https://%Address%" } },
  { "NewHttpRequest": { "ObjectName": "SystemRequest" } },
  {
    "Request": {
      "RequestObjectName": "SystemRequest",
      "ResponseObjectName": "SystemResponse",
      "Verb": "GET",
      "Url": "api/status",
      "Content": {
        "ContentType": "application/json"
      }
    }
  },
  {
    "Condition": {
      "If": "SystemResponse.StatusCode == 200",
      "Then": {
        "Do": [
          { "Return": { "Value": true } }
        ]
      },
      "Else": {
        "Do": [
          { "Throw": { "Value": "Unexpected HTTP status %{SystemResponse.StatusCode}%" } }
        ]
      }
    }
  }
]
```

## Authentication patterns

Use the authentication style that matches the target API. The command syntax changes depending on whether the API expects credentials, a token, custom headers, or a session cookie.

### Basic authentication

For APIs that accept a username and password on every request, use [`HttpAuth`](../reference/commands/http-auth.md) with `Type: "Basic"`.

```json
[
  { "BaseAddress": { "Address": "https://%Address%" } },
  { "NewHttpRequest": { "ObjectName": "SystemRequest" } },
  {
    "HttpAuth": {
      "RequestObjectName": "SystemRequest",
      "Type": "Basic",
      "Credentials": {
        "Login": "%FuncUsername%",
        "Password": "%FuncPassword%"
      }
    }
  },
  {
    "Request": {
      "RequestObjectName": "SystemRequest",
      "ResponseObjectName": "SystemResponse",
      "Verb": "GET",
      "Url": "api/v1/me"
    }
  }
]
```

This is the pattern used by `SampleScripts/HTTP/WordPressHttp.json`.

> [!IMPORTANT]
> [`HttpAuth`](../reference/commands/http-auth.md) currently supports `Basic` and `Digest`. For `Bearer` tokens and most API-key schemes, add the header yourself with [`Headers`](../reference/commands/http-setup.md).

### Bearer and OAuth2 tokens

Many REST APIs require a login call or OAuth2 token exchange first, then an `Authorization: Bearer ...` header on later requests.

A common pattern is:

1. `POST` to `/oauth2/token` or another login endpoint.
2. Parse the JSON response.
3. Save `access_token` into a variable.
4. Add `Authorization: Bearer %AccessToken%` to a new request object.
5. Use that request object for the real operation.

```json
[
  { "BaseAddress": { "Address": "https://%Address%" } },
  {
    "SetItem": {
      "Name": "TokenRequestBody",
      "Value": {
        "grant_type": "client_credentials",
        "client_id": "%FuncUsername%",
        "client_secret": "%FuncPassword%"
      }
    }
  },
  { "NewHttpRequest": { "ObjectName": "TokenRequest" } },
  {
    "Request": {
      "RequestObjectName": "TokenRequest",
      "ResponseObjectName": "TokenResponse",
      "Verb": "POST",
      "Url": "oauth2/token",
      "Content": {
        "ContentObjectName": "TokenRequestBody",
        "ContentType": "application/json"
      }
    }
  },
  { "ExtractJsonObject": { "JsonObjectName": "TokenResponse", "Name": "TokenJson" } },
  {
    "SetItem": {
      "Name": "AccessToken",
      "Type": "secret",
      "Value": "%{TokenJson.access_token}%"
    }
  },
  { "NewHttpRequest": { "ObjectName": "ApiRequest" } },
  {
    "Headers": {
      "RequestObjectName": "ApiRequest",
      "AddHeaders": {
        "Authorization": "Bearer %AccessToken%",
        "Accept": "application/json"
      }
    }
  },
  {
    "Request": {
      "RequestObjectName": "ApiRequest",
      "ResponseObjectName": "ApiResponse",
      "Verb": "GET",
      "Url": "api/v1/users/me"
    }
  }
]
```

This is the same overall shape used in `SampleScripts/HTTP/OneLogin_GRC_JIT_addon.json`, which stores a token and then sends `Authorization: "Bearer %AccessToken%"` on later `Request` commands.

### API keys in headers

If the API expects an API key instead of a bearer token, add it with [`Headers`](../reference/commands/http-setup.md).

```json
[
  { "BaseAddress": { "Address": "https://%Address%" } },
  { "NewHttpRequest": { "ObjectName": "SystemRequest" } },
  {
    "Headers": {
      "RequestObjectName": "SystemRequest",
      "AddHeaders": {
        "Authorization": "SSWS %FuncPassword%",
        "Accept": "application/json"
      }
    }
  },
  {
    "Request": {
      "RequestObjectName": "SystemRequest",
      "ResponseObjectName": "SystemResponse",
      "Verb": "GET",
      "Url": "api/v1/users/%ParsedUser%",
      "SubstitutionInUrl": true
    }
  }
]
```

That is the same style used in `SampleScripts/HTTP/Okta_WithDiscoveryAndGroupMembershipRestore.json`.

The header name can be anything the API requires:

- `Authorization: Bearer ...`
- `Authorization: SSWS ...`
- `X-API-Key: ...`
- `X-OpenAM-Username` / `X-OpenAM-Password`

### Cookie-based authentication

Some systems do not expose a clean REST login endpoint. Instead, they expect the same form-post flow a browser would use:

1. `GET` the login page.
2. Extract the form.
3. Read hidden values such as CSRF tokens if needed.
4. Fill username and password fields.
5. `POST` the form.
6. Reuse the resulting cookies on later requests.

This is the pattern used by `SampleScripts/HTTP/CustomTwitter.json` and `SampleScripts/HTTP/CustomFacebook.json`.

## Common end-to-end flow

Most API-backed platforms follow this high-level sequence:

`login -> get token or session -> perform operation -> optionally logout`

A compact token-based example looks like this:

```json
[
  { "BaseAddress": { "Address": "https://%Address%" } },
  { "Function": { "Name": "ApiLogin", "ResultVariable": "AccessToken" } },
  { "NewHttpRequest": { "ObjectName": "ChangeRequest" } },
  {
    "Headers": {
      "RequestObjectName": "ChangeRequest",
      "AddHeaders": {
        "Authorization": "Bearer %AccessToken%"
      }
    }
  },
  {
    "SetItem": {
      "Name": "ChangeBody",
      "Value": {
        "password": "%NewPassword%"
      }
    }
  },
  {
    "Request": {
      "RequestObjectName": "ChangeRequest",
      "ResponseObjectName": "ChangeResponse",
      "Verb": "PUT",
      "Url": "api/v1/users/%AccountId%/password",
      "SubstitutionInUrl": true,
      "Content": {
        "ContentObjectName": "ChangeBody",
        "ContentType": "application/json"
      }
    }
  },
  {
    "Condition": {
      "If": "ChangeResponse.StatusCode == 200 || ChangeResponse.StatusCode == 204",
      "Then": {
        "Do": [
          { "Function": { "Name": "ApiLogout", "Parameters": [ "%AccessToken%" ] } },
          { "Return": { "Value": true } }
        ]
      },
      "Else": {
        "Do": [
          { "Function": { "Name": "ApiLogout", "Parameters": [ "%AccessToken%" ] } },
          { "Throw": { "Value": "Password change failed: HTTP %{ChangeResponse.StatusCode}%" } }
        ]
      }
    }
  }
]
```

For session-cookie systems, replace `ApiLogin` with a login-page request plus form submission, and let the cookie jar carry the session into later requests.

## Using `Request` with common HTTP methods

[`Request`](../reference/commands/request.md) supports all common HTTP verbs. For most HTTP platforms, you will use `GET`, `POST`, `PUT`, and `DELETE`.

### GET

Use `GET` for health checks, identity lookups, and discovery.

```json
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "SystemResponse",
    "Verb": "GET",
    "Url": "api/v1/users/%UserId%",
    "SubstitutionInUrl": true
  }
}
```

### POST

Use `POST` to log in, create resources, or send action requests.

```json
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "CreateResponse",
    "Verb": "POST",
    "Url": "api/v1/users",
    "Content": {
      "ContentObjectName": "CreateBody",
      "ContentType": "application/json"
    }
  }
}
```

### PUT

Use `PUT` when the API expects a full update or a password/state change request.

```json
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "UpdateResponse",
    "Verb": "PUT",
    "Url": "api/v1/users/%UserId%",
    "SubstitutionInUrl": true,
    "Content": {
      "ContentObjectName": "UpdateBody",
      "ContentType": "application/json"
    }
  }
}
```

### DELETE

Use `DELETE` to remove memberships, revoke sessions, or clean up temporary resources.

```json
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "DeleteResponse",
    "Verb": "DELETE",
    "Url": "api/v1/users/%UserId%/sessions/%SessionId%",
    "SubstitutionInUrl": true
  }
}
```

Practical tips:

- Set `SubstitutionInUrl: true` when the URL contains `%Variable%` or `%{ expression }%` fragments.
- Use `AllowRedirect: false` when redirects are meaningful, such as form-login success vs. failure.
- Use a fresh request object when different steps need different auth headers.
- Store the response with `ResponseObjectName` whenever later commands need `StatusCode`, `Headers`, `Content`, or `Cookies`.

## Working with JSON responses

[`ExtractJsonObject`](../reference/commands/json.md) parses a JSON response so your script can read properties, branch on values, and loop through arrays.

Typical JSON workflow:

1. Send the request.
2. Parse the response into a named object.
3. Read fields into variables or use them directly in expressions.
4. Branch with `Condition` or iterate with `ForEach`.

```json
[
  {
    "Request": {
      "RequestObjectName": "SystemRequest",
      "ResponseObjectName": "SystemResponse",
      "Verb": "GET",
      "Url": "api/v1/users/%ParsedUser%",
      "SubstitutionInUrl": true
    }
  },
  {
    "ExtractJsonObject": {
      "JsonObjectName": "SystemResponse",
      "Name": "GetUserResponseJson"
    }
  },
  {
    "Condition": {
      "If": "SystemResponse.StatusCode == 200",
      "Then": {
        "Do": [
          { "SetItem": { "Name": "UserId", "Value": "%{GetUserResponseJson.id}%" } }
        ]
      },
      "Else": {
        "Do": [
          { "Throw": { "Value": "Lookup failed: HTTP %{SystemResponse.StatusCode}%" } }
        ]
      }
    }
  }
]
```

For collections, combine `ExtractJsonObject` with `ForEach`:

```json
[
  { "ExtractJsonObject": { "JsonObjectName": "SystemUsers", "Name": "ParsedUsers" } },
  {
    "ForEach": {
      "CollectionName": "ParsedUsers",
      "ElementName": "User",
      "Body": {
        "Do": [
          {
            "Condition": {
              "If": "User.name.Value == AccountUserName",
              "Then": {
                "Do": [
                  { "SetItem": { "Name": "UserId", "Value": "%{User.id.Value}%" } }
                ]
              }
            }
          }
        ]
      }
    }
  }
]
```

Use this pattern for:

- Extracting token fields such as `access_token`
- Finding the correct account ID before a password change
- Reading API-specific state values before deciding whether to return success
- Enumerating users or groups during discovery

> [!NOTE]
> When `JsonObjectName` points to a response object, the endpoint must actually return JSON. If the system returns HTML or plain text, parse that differently.

## Working with HTML forms

Use [`ExtractFormData`](../reference/commands/forms.md), [`GetFormValue`](../reference/commands/forms.md), and [`SetFormValue`](../reference/commands/forms.md) when the target behaves like a traditional web application instead of a REST API.

This is common for:

- Login pages
- Password-change pages
- Systems that require hidden anti-CSRF inputs
- Older admin portals with HTML forms but no documented API

A standard form-login sequence looks like this:

```json
[
  {
    "Request": {
      "Verb": "GET",
      "Url": "login",
      "RequestObjectName": "LoginRequest",
      "ResponseObjectName": "LoginResponse",
      "AllowRedirect": true
    }
  },
  { "ExtractFormData": { "ResponseObjectName": "LoginResponse", "FormObjectName": "LoginForm" } },
  {
    "Condition": {
      "If": "LoginForm == null",
      "Then": {
        "Do": [
          { "Throw": { "Value": "Login form not found" } }
        ]
      }
    }
  },
  {
    "GetFormValue": {
      "FormObjectName": "LoginForm",
      "InputName": "csrf_token",
      "VariableName": "CsrfToken",
      "ContainsSecret": true
    }
  },
  {
    "SetFormValue": {
      "FormObjectName": "LoginForm",
      "CreateForm": "DoNotCreate",
      "InputName": "username",
      "Value": "%AccountUserName%"
    }
  },
  {
    "SetFormValue": {
      "FormObjectName": "LoginForm",
      "CreateForm": "DoNotCreate",
      "InputName": "password",
      "Value": "%AccountPassword%",
      "IsSecret": true
    }
  },
  {
    "Request": {
      "Verb": "POST",
      "Url": "sessions",
      "RequestObjectName": "LoginPostRequest",
      "ResponseObjectName": "LoginPostResponse",
      "AllowRedirect": false,
      "Content": {
        "ContentObjectName": "LoginForm",
        "ContentType": "application/x-www-form-urlencoded"
      }
    }
  }
]
```

Practical guidance:

- Use `XPath` on `ExtractFormData` when the page contains more than one form.
- Use `GetFormValue` for hidden fields you want to inspect or log safely.
- Use `CreateForm: "DoNotCreate"` when a missing field should be treated as a real failure.
- Set `AllowRedirect: false` if the application signals login success or failure through the `Location` header.

If the page depends on JavaScript to build the real request, inspect the browser traffic and target the underlying HTTP endpoint directly. Safeguard cannot run the page's JavaScript for you.

For a full walkthrough, see [Your First Form Script](../getting-started/your-first-form-script.md).

## Cookie management

Most form flows do not need explicit cookie commands because [`Request`](../reference/commands/request.md) keeps cookies automatically unless you set `PersistCookies: false`.

Use [`GetCookie`](../reference/commands/cookies.md), [`SetCookie`](../reference/commands/cookies.md), and [`ClearCookie`](../reference/commands/cookies.md) only when you need direct control over the cookie jar.

### Read a session cookie

```json
{
  "GetCookie": {
    "Name": "sessionid",
    "Domain": "https://%Address%",
    "Path": "/",
    "VariableName": "SessionCookie"
  }
}
```

### Seed or overwrite a cookie

```json
{
  "SetCookie": {
    "Name": "MyCookie",
    "Domain": "%Address%",
    "Path": "/",
    "Value": "%SeedValue%",
    "Secure": true
  }
}
```

### Clear cookies on logout or before retrying

```json
{
  "ClearCookie": {
    "Name": ["sessionid", "remember_me"],
    "Domain": "%Address%",
    "Path": "/"
  }
}
```

Cookie commands are helpful when:

- The application requires a seed cookie before login
- You must copy one cookie value into a header or another request parameter
- You want to clear stale cookies before retrying authentication
- You want logout to fully remove the local session state before returning

## HTTPS and TLS considerations

For most HTTP platforms, add the reserved `UseSsl` parameter and use it to choose `https://` or `http://` in `BaseAddress`.

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
```

Why this matters:

- `UseSsl` gives administrators a built-in platform/asset setting instead of a one-off custom parameter.
- Including `UseSsl` also enables the related built-in connection behavior for SSL-aware platforms.
- The same script can work in both HTTP and HTTPS environments.

When using HTTPS, you will often pair `UseSsl` with `SkipServerCertValidation` during development:

```json
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "SystemResponse",
    "Verb": "GET",
    "Url": "api/status",
    "IgnoreServerCertAuthentication": "%SkipServerCertValidation%"
  }
}
```

Use `SkipServerCertValidation` only when you deliberately need to ignore certificate validation, such as in a lab or while testing self-signed certificates.

## Pagination patterns for discovery

Discovery operations often need more than one request because the API returns results in pages.

Two patterns are common.

### Offset/limit pagination

Build a URL with `limit` and an offset or page number, then loop until the current page is empty.

```json
[
  { "SetItem": { "Name": "Page", "Value": 1 } },
  { "SetItem": { "Name": "HasMore", "Value": true } },
  {
    "For": {
      "Condition": "HasMore",
      "Body": {
        "Do": [
          { "SetItem": { "Name": "Url", "Value": "%{\"api/v1/users?page=\" + Page + \"&limit=100\"}%" } },
          {
            "Request": {
              "RequestObjectName": "SystemRequest",
              "ResponseObjectName": "PageResponse",
              "Verb": "GET",
              "Url": "%Url%",
              "SubstitutionInUrl": true
            }
          },
          { "ExtractJsonObject": { "JsonObjectName": "PageResponse", "Name": "UsersPage" } },
          {
            "Condition": {
              "If": "UsersPage.Count == 0",
              "Then": {
                "Do": [
                  { "SetItem": { "Name": "HasMore", "Value": false } }
                ]
              },
              "Else": {
                "Do": [
                  {
                    "ForEach": {
                      "CollectionName": "UsersPage",
                      "ElementName": "User",
                      "Body": {
                        "Do": [
                          { "WriteDiscoveredAccount": { "Name": "%{User.profile.login}%" } }
                        ]
                      }
                    }
                  },
                  { "SetItem": { "Name": "Page", "Value": "%{Page + 1}%" } }
                ]
              }
            }
          }
        ]
      }
    }
  }
]
```

### Link-header or cursor pagination

Some APIs return a `Link` header or a `next` cursor instead of page numbers. `SampleScripts/HTTP/Okta_WithDiscoveryAndGroupMembershipRestore.json` shows this style: it reads the `Link` header and loops until there is no next link.

Use this pattern when:

- The response header contains a `next` URL
- The JSON body contains `nextCursor`, `nextToken`, or similar
- The API explicitly says page numbers are not stable

For discovery code, keep the request loop separate from the per-record logic. That makes it easier to retry a single page fetch without duplicating record-processing code.

## Error handling and retries

HTTP scripts usually fail in one of two ways:

1. The request throws because of a network, TLS, proxy, or parse problem.
2. The request succeeds but returns an unexpected status code such as `401`, `403`, `404`, `429`, or `500`.

Handle both.

### Check status codes explicitly

Do not treat “request completed” as “operation succeeded.” Always inspect `StatusCode`.

```json
{
  "Condition": {
    "If": "SystemResponse.StatusCode == 200 || SystemResponse.StatusCode == 204",
    "Then": {
      "Do": [
        { "Return": { "Value": true } }
      ]
    },
    "Else": {
      "Do": [
        { "Throw": { "Value": "Request failed: HTTP %{SystemResponse.StatusCode}%" } }
      ]
    }
  }
}
```

### Wrap risky steps in `Try`/`Catch`

Use [`Try`](../reference/commands/error-handling.md) when the request itself can throw and you want to reword the error or clean up first.

```json
{
  "Try": {
    "Do": [
      {
        "Request": {
          "RequestObjectName": "SystemRequest",
          "ResponseObjectName": "SystemResponse",
          "Verb": "GET",
          "Url": "api/status"
        }
      }
    ],
    "Catch": [
      { "Throw": { "Value": "HTTP request failed: %Exception%" } }
    ]
  }
}
```

### Retry only transient failures

Retries make sense for temporary conditions such as throttling or service unavailability. They usually do **not** help for `400`, `401`, `403`, or `404` unless your script first refreshes auth or changes the request.

```json
[
  { "SetItem": { "Name": "RetryCount", "Value": 0 } },
  { "SetItem": { "Name": "Done", "Value": false } },
  {
    "For": {
      "Condition": "!Done && RetryCount < 3",
      "Body": {
        "Do": [
          {
            "Request": {
              "RequestObjectName": "SystemRequest",
              "ResponseObjectName": "SystemResponse",
              "Verb": "GET",
              "Url": "api/status"
            }
          },
          {
            "Switch": {
              "MatchValue": "%{SystemResponse.StatusCode.ToString()}%",
              "Cases": [
                {
                  "CaseValue": "(OK)|(NoContent)",
                  "Do": [
                    { "SetItem": { "Name": "Done", "Value": true } },
                    { "Return": { "Value": true } }
                  ]
                },
                {
                  "CaseValue": "(TooManyRequests)|(ServiceUnavailable)|(BadGateway)|(GatewayTimeout)",
                  "Do": [
                    { "Wait": { "Seconds": 2 } },
                    { "SetItem": { "Name": "RetryCount", "Value": "%{RetryCount + 1}%" } }
                  ]
                }
              ],
              "DefaultCase": {
                "Do": [
                  { "Throw": { "Value": "Non-retryable HTTP status %{SystemResponse.StatusCode}%" } }
                ]
              }
            }
          }
        ]
      }
    }
  },
  { "Throw": { "Value": "Request failed after retries" } }
]
```

For more on branching and loops, see [Flow Control](../reference/commands/flow-control.md) and [Error Handling](../reference/commands/error-handling.md).

## Proxy support

HTTP platforms can pass proxy settings directly on each [`Request`](../reference/commands/request.md).

The `Request` command fields are:

- `ProxyIp`
- `ProxyPort`
- `ProxyUser`
- `ProxyPassword`

In Safeguard, the built-in reserved connection parameters are typically:

- `HttpProxyUri`
- `HttpProxyPort`
- `HttpProxyUserName`
- `HttpProxyPassword`

That means the usual pattern is to map the reserved parameters into the `Request` fields:

```json
{
  "Request": {
    "RequestObjectName": "SystemRequest",
    "ResponseObjectName": "SystemResponse",
    "Verb": "GET",
    "Url": "api/v1/users",
    "ProxyIp": "%HttpProxyUri%",
    "ProxyPort": "%HttpProxyPort%",
    "ProxyUser": "%HttpProxyUserName%",
    "ProxyPassword": "%HttpProxyPassword%"
  }
}
```

If your team prefers custom parameter names such as `ProxyAddress`, `ProxyPort`, `ProxyUsername`, and `ProxyPassword`, you can still map those values into the same `Request` fields. The important part is that the `Request` command itself expects `ProxyIp`, `ProxyPort`, `ProxyUser`, and `ProxyPassword`.

Use proxy parameters when:

- The SPP appliance must reach the target API through an outbound web proxy
- The proxy requires authentication
- Different environments need different proxy routes

## Related references

Use this guide together with the command reference pages:

- [`Request`](../reference/commands/request.md)
- [`HTTP Request Setup`](../reference/commands/http-setup.md)
- [`HTTP Authentication`](../reference/commands/http-auth.md)
- [`Cookies`](../reference/commands/cookies.md)
- [`Forms`](../reference/commands/forms.md)
- [`JSON`](../reference/commands/json.md)
- [`Flow Control`](../reference/commands/flow-control.md)
- [`Error Handling`](../reference/commands/error-handling.md)
- [Your First HTTP Script](../getting-started/your-first-http-script.md)
- [Your First Form Script](../getting-started/your-first-form-script.md)

When you are building a new HTTP platform, start simple: verify connectivity with one authenticated `GET`, confirm the response parsing works, and only then add multi-step login, pagination, retries, and cleanup logic.
