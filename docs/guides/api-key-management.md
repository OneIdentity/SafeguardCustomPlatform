# API Key Management

Safeguard can manage API keys, bearer tokens, client secrets, and similar application credentials the same way it manages passwords. For a custom platform, that usually means validating the current key with `CheckApiKey` and rotating it with `ChangeApiKey`.

## Table of Contents

- [What API key management means](#what-api-key-management-means)
- [Operations involved](#operations-involved)
- [Key parameters and feature flag](#key-parameters-and-feature-flag)
- [HTTP-based implementation pattern](#http-based-implementation-pattern)
- [Returning the rotated key to Safeguard](#returning-the-rotated-key-to-safeguard)
- [Illustrative JSON examples](#illustrative-json-examples)
- [How API key rotation differs from password rotation](#how-api-key-rotation-differs-from-password-rotation)
- [Common scenarios](#common-scenarios)
- [Error handling](#error-handling)
- [Best practices](#best-practices)
- [See also](#see-also)

## What API key management means

In this context, API key management means Safeguard is responsible for the lifecycle of a non-password secret that a cloud service, SaaS platform, or web application uses for authentication.

Typical examples include:

- cloud-service API tokens
- application-specific client secrets
- bearer tokens used by admin APIs
- AWS-style access keys

The pattern is the same as password management at a high level:

1. Safeguard stores the current secret.
2. Safeguard runs a check operation to verify the secret still works.
3. Safeguard runs a change operation to rotate the secret.
4. Safeguard stores the replacement value for future use.

The important difference is that many APIs do **not** let Safeguard choose the new secret value. Instead, the target system generates a new key and returns it once.

## Operations involved

API key platforms typically implement two operations documented in the [Operations Reference](../reference/operations.md):

- **`CheckApiKey`** - verify that the currently stored API key still works, usually by making a harmless authenticated API call such as `GET /me`, `GET /whoami`, or `GET /validate`.
- **`ChangeApiKey`** - rotate or regenerate the API key by calling the target system's management API.

A common workflow looks like this:

1. Authenticate to the target's admin API by using service credentials such as `FuncUserName` and `FuncPassword`.
2. Identify the account, application, or client whose key is being managed.
3. Call the target endpoint that creates, rotates, or regenerates a key.
4. Capture the new key value from the response.
5. Verify that the new key works.
6. Return the new key to Safeguard so it can be stored.

## Key parameters and feature flag

> [!NOTE]
> This guide uses `ApiKey` and `NewApiKey` as logical names for the current and rotated secret. When you implement a production script, declare the exact reserved parameter names and types documented in [Reserved Parameters](../reference/reserved-parameters.md) and [Operations Reference](../reference/operations.md).

The important values in an API key workflow are:

| Logical value | Purpose |
| --- | --- |
| `ApiKey` | The current key or token Safeguard already has stored and wants to validate or replace. |
| `NewApiKey` | The new key value that must be written back so Safeguard can store it after rotation. |
| `FuncUserName` / `FuncPassword` | Service or admin credentials used to authenticate to the target system's management API. |
| `Address` | Base address of the target API. |

Safeguard automatically derives the **`ApiKeyFl`** feature flag when your script defines **`CheckApiKey`**. In practice, you almost always pair `CheckApiKey` with `ChangeApiKey` so the platform can both validate and rotate API credentials.

## HTTP-based implementation pattern

Most API key platforms are HTTP-based. The usual pattern is:

1. Set the base URL.
2. Authenticate to the admin API.
3. Call the rotation endpoint.
4. Parse the response body.
5. Save the returned key into a secret variable.
6. Make a second authenticated call with the new key to prove it works.
7. Write the new value back to Safeguard.

That pattern matches the HTTP request flow described in [HTTP/REST API Platforms](http-platforms.md): build a request, add headers or auth, send the request, inspect the response, and branch on success or failure.

A few practical choices matter:

- Use a **non-destructive** endpoint for `CheckApiKey`.
- Use the **admin API** for `ChangeApiKey`, not the key being rotated, unless the target requires self-service rotation.
- Capture the returned secret **immediately** if the API only reveals it once.
- Mark returned secrets with `IsSecret` or `ContainsSecret` so they do not leak into logs.

## Returning the rotated key to Safeguard

For API key rotation, it is not enough to keep the new key in a local variable. The script must write the rotated value to a response object that Safeguard captures.

A common pattern is:

```json
[
  {
    "SetItem": {
      "Name": "RotatedApiKey",
      "Value": "%{RotateResponseJson.api_key}%",
      "IsSecret": true
    }
  },
  {
    "SetItem": {
      "Name": "ResponseData",
      "Value": {
        "NewApiKey": "%RotatedApiKey%"
      },
      "IsSecret": true
    }
  },
  {
    "WriteResponseObject": {
      "Value": "%ResponseData%"
    }
  }
]
```

That is the handoff point between your script and Safeguard. If the target generates the new secret, your script must extract it from the HTTP response and write it back explicitly.

For the output command details, see [Output Commands](../reference/commands/output.md).

## Illustrative JSON examples

These examples show the shape of the workflow. Adjust URLs, headers, and parameter names to match the target system and the exact reserved parameter contract you are implementing.

### `CheckApiKey`

This example validates the current key by calling a safe authenticated endpoint.

```json
"CheckApiKey": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "ApiKey": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "BaseAddress": { "Address": "https://%Address%" } },
    { "NewHttpRequest": { "ObjectName": "CheckRequest" } },
    {
      "Headers": {
        "RequestObjectName": "CheckRequest",
        "AddHeaders": {
          "Authorization": "Bearer %ApiKey%",
          "Accept": "application/json"
        }
      }
    },
    {
      "Request": {
        "RequestObjectName": "CheckRequest",
        "ResponseObjectName": "CheckResponse",
        "Verb": "GET",
        "Url": "api/v1/me"
      }
    },
    {
      "Condition": {
        "If": "CheckResponse.StatusCode == 200",
        "Then": {
          "Do": [
            { "Return": { "Value": true } }
          ]
        },
        "Else": {
          "Do": [
            { "Throw": { "Value": "API key check failed: HTTP %{CheckResponse.StatusCode}%" } }
          ]
        }
      }
    }
  ]
}
```

### `ChangeApiKey`

This example authenticates with admin credentials, calls a rotation endpoint, verifies the returned key, and writes it back.

```json
"ChangeApiKey": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": true } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "ApiKey": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "BaseAddress": { "Address": "https://%Address%" } },
    {
      "SetItem": {
        "Name": "TokenRequestBody",
        "Value": {
          "grant_type": "client_credentials",
          "client_id": "%FuncUserName%",
          "client_secret": "%FuncPassword%"
        },
        "IsSecret": true
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
        },
        "IsSecret": true
      }
    },
    {
      "ExtractJsonObject": {
        "JsonObjectName": "TokenResponse",
        "Name": "TokenJson",
        "ContainsSecret": true
      }
    },
    {
      "SetItem": {
        "Name": "AdminToken",
        "Value": "%{TokenJson.access_token}%",
        "IsSecret": true
      }
    },
    { "NewHttpRequest": { "ObjectName": "RotateRequest" } },
    {
      "Headers": {
        "RequestObjectName": "RotateRequest",
        "AddHeaders": {
          "Authorization": "Bearer %AdminToken%",
          "Accept": "application/json"
        }
      }
    },
    {
      "Request": {
        "RequestObjectName": "RotateRequest",
        "ResponseObjectName": "RotateResponse",
        "Verb": "POST",
        "Url": "api/admin/users/%AccountUserName%/keys/rotate",
        "SubstitutionInUrl": true
      }
    },
    {
      "ExtractJsonObject": {
        "JsonObjectName": "RotateResponse",
        "Name": "RotateResponseJson",
        "ContainsSecret": true
      }
    },
    {
      "SetItem": {
        "Name": "RotatedApiKey",
        "Value": "%{RotateResponseJson.api_key}%",
        "IsSecret": true
      }
    },
    { "NewHttpRequest": { "ObjectName": "VerifyRequest" } },
    {
      "Headers": {
        "RequestObjectName": "VerifyRequest",
        "AddHeaders": {
          "Authorization": "Bearer %RotatedApiKey%",
          "Accept": "application/json"
        }
      }
    },
    {
      "Request": {
        "RequestObjectName": "VerifyRequest",
        "ResponseObjectName": "VerifyResponse",
        "Verb": "GET",
        "Url": "api/v1/me"
      }
    },
    {
      "Condition": {
        "If": "VerifyResponse.StatusCode != 200",
        "Then": {
          "Do": [
            { "Throw": { "Value": "Rotated key verification failed: HTTP %{VerifyResponse.StatusCode}%" } }
          ]
        }
      }
    },
    {
      "SetItem": {
        "Name": "ResponseData",
        "Value": {
          "NewApiKey": "%RotatedApiKey%"
        },
        "IsSecret": true
      }
    },
    {
      "WriteResponseObject": {
        "Value": "%ResponseData%"
      }
    },
    { "Return": { "Value": true } }
  ]
}
```

If the target API allows caller-supplied secrets, you can send `NewApiKey` in the request body instead of extracting a server-generated value from the response. That is less common than target-generated rotation.

## How API key rotation differs from password rotation

| Topic | Password rotation | API key rotation |
| --- | --- | --- |
| Who usually creates the new value? | Safeguard usually generates it and passes it in. | The target system often generates it and returns it once. |
| Validation method | Interactive login or password change flow. | Authenticated API call using a header or bearer token. |
| Change model | Set the account's password to a new known value. | Create, regenerate, or revoke a key through an API. |
| Rollback options | Often reset the old password again if needed. | Often depends on whether old and new keys can overlap temporarily. |

This is why API key scripts usually need stronger response parsing and response-writing logic than basic password change scripts.

## Common scenarios

API key management is especially useful for:

- **AWS access keys** - rotate long-lived programmatic credentials used by automation.
- **Cloud-service API tokens** - rotate tokens for SaaS administration or integration accounts.
- **Application-specific secrets** - manage client secrets, integration tokens, or internal service keys used by custom web applications.

Some targets return more than one value. For example, an AWS-style credential may include both an identifier and a secret. In those cases, design the response object and parameter contract to capture every value Safeguard must preserve.

## Error handling

Expect API-specific failures and handle them deliberately.

### Expired or revoked keys

A `CheckApiKey` call commonly fails with `401 Unauthorized` or `403 Forbidden` when the stored key has expired or been revoked. Treat that as an authentication failure, not a transport failure.

### Rate limiting

Many cloud platforms throttle create or rotate operations.

Watch for:

- `429 Too Many Requests`
- `503 Service Unavailable`
- `Retry-After` response headers

If the target publishes a retry window, honor it. Keep retries bounded so one failing asset does not stall the entire job.

### Partial rotation failures

The hardest failures are partial ones, for example:

- the target created a new key but your verification call failed
- the new key works but the old key was not revoked
- the target revoked the old key before the script captured the replacement
- the target returned the new key once, but the script threw an error before writing the response object

Design your script so these cases produce a clear error message and never report success unless Safeguard can safely store a working replacement key.

## Best practices

- **Verify the new key before reporting success.** Make a real authenticated API call with the rotated key.
- **Prefer overlap when the target supports it.** Create the new key, validate it, then revoke the old one.
- **Capture one-time secrets immediately.** Some APIs only show the secret value in the creation response.
- **Keep secrets masked.** Use `IsSecret` and `ContainsSecret` when storing or parsing returned credentials.
- **Log identifiers, not secrets.** Log usernames, key IDs, URLs, and HTTP status codes, but never log the actual token value.
- **Use a safe validation endpoint.** `CheckApiKey` should not mutate the target.
- **Plan for rollback.** API key rotation can fail between creation and validation — leaving you with a new key that doesn't work and an old key that may have been revoked. Defend against this:

  1. **Keep the old key alive** — don't revoke it until the new key is verified. Most APIs allow multiple active keys simultaneously (e.g., AWS allows two access keys per IAM user).
  2. **Verify before reporting** — after creating the new key, make an authenticated API call with it before writing it to the response. If verification fails, revoke the new key and return `false`.
  3. **Handle "create succeeded but verify timed out"** — some APIs have propagation delay (especially distributed systems). Add a brief `Wait` and retry verification once before concluding failure.
  4. **If you must revoke-then-create** (single-key systems), accept the inherent risk window and keep it as short as possible. Log clearly so that manual recovery is straightforward if the script fails mid-rotation.
  5. **Never return success if verification failed** — Safeguard will store the new key value you report. If that key is actually invalid, the account becomes unmanageable until manual correction.

  ```json
  {
    "Command": "Condition",
    "Expression": "%verifyStatus% != 200",
    "Do": [
      {
        "Command": "Log",
        "Value": "New key verification failed (HTTP %verifyStatus%). Revoking new key and keeping old key active."
      },
      {
        "Command": "Request",
        "Url": "%BaseUrl%/api-keys/%newKeyId%",
        "Method": "DELETE"
      },
      {
        "Command": "Return",
        "Value": "false"
      }
    ]
  }
  ```
- **Handle target-specific limits.** Respect throttling, propagation delay, and eventual consistency behavior.
- **Use the least-privileged admin credential possible.** The service credential should be able to rotate only the keys it truly needs to manage.

## See also

- [Operations Reference](../reference/operations.md)
- [Reserved Parameters](../reference/reserved-parameters.md)
- [HTTP/REST API Platforms](http-platforms.md)
- [Your First HTTP Script](../getting-started/your-first-http-script.md)
- [Output Commands](../reference/commands/output.md)
