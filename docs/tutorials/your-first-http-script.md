[← Tutorials](README.md)

# Your First HTTP Script

By the end of this tutorial, you will have a working custom platform script that connects to a REST API over HTTP or HTTPS, verifies API connectivity with `CheckSystem`, validates managed account credentials with `CheckPassword`, and rotates the password with `ChangePassword`.

## What You'll Build

You will build a minimal custom platform script with three operations:

- `CheckSystem` — makes an authenticated HTTP request to verify the service account can reach the API.
- `CheckPassword` — makes an authenticated HTTP request to verify the managed account credentials are valid.
- `ChangePassword` — authenticates as the service account and sends a password-update request for the managed account.

This is intentionally small. It is the quickest way to get from zero to a working HTTP platform that can test connectivity, validate credentials, and perform a basic password rotation.

## Prerequisites

Before you start, make sure you have:

- A target system with a REST API that supports authentication such as Basic Auth.
- An SPP appliance and the `safeguard-ps` PowerShell module. If you have not used that workflow before, read [Development Workflow](development-workflow.md).
- Basic familiarity with JSON and REST APIs.

## Step 1: Create the Script Skeleton

Create a new file named `MyFirstHttpPlatform.json` and start with this minimal structure:

```json
{
  "Id": "MyFirstHttpPlatform",
  "BackEnd": "Scriptable",
  "CheckSystem": {
    "Parameters": [],
    "Do": []
  }
}
```

The basics are the same as SSH:

- `Id` — the internal identifier for the script.
- `BackEnd` — always `"Scriptable"` for a custom platform script.
- `CheckSystem` — one operation in your script. Each operation has a `Parameters` array and a `Do` block.

Think of `Parameters` as the inputs SPP passes to the operation and `Do` as the list of commands the script engine runs.

## Step 2: Add Parameters for CheckSystem

Next, define the values `CheckSystem` needs to connect to the API:

```json
"CheckSystem": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUsername": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": true } },
    { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
  ],
  "Do": []
}
```

Here is what each parameter does:

- `Address` — the target hostname or IP address. SPP auto-populates this from the asset's network address.
- `FuncUsername` / `FuncPassword` — the service account credentials on the asset. SPP auto-populates these when `CheckSystem` runs.
- `UseSsl` — a custom parameter that lets you switch between HTTPS and HTTP.

For a first HTTP script, these four parameters are enough to prove the API is reachable and the credentials work.

## Step 3: Write the CheckSystem Do Block

Now add the actual HTTP workflow. HTTP-based platforms usually follow the same pattern every time:

1. Set a base address.
2. Create a request object.
3. Add authentication.
4. Send the request.
5. Inspect the response.

Build it one piece at a time.

### 1. Set the base address

`BaseAddress` tells the script engine the root URL for all requests:

```json
{ "BaseAddress": { "Address": "https://%Address%" } }
```

This first example assumes HTTPS so you can see the simplest possible form. In the assembled block below, you will make it respect `UseSsl` so the same script can work with either HTTPS or HTTP.

### 2. Create a request object

`NewHttpRequest` initializes a reusable request object:

```json
{ "NewHttpRequest": { "ObjectName": "ApiRequest" } }
```

### 3. Add authentication

`HttpAuth` attaches credentials to the request:

```json
{ "HttpAuth": { "RequestObjectName": "ApiRequest", "Type": "Basic", "Credentials": { "Login": "%FuncUsername%", "Password": "%FuncPassword%" } } }
```

### 4. Send the request

`Request` executes the HTTP call:

```json
{
  "Request": {
    "RequestObjectName": "ApiRequest",
    "ResponseObjectName": "ApiResponse",
    "Verb": "GET",
    "Url": "/api/status",
    "Content": {
      "ContentType": "application/json"
    }
  }
}
```

`ResponseObjectName` is important because it stores the result so later commands can inspect `StatusCode`, headers, and response content.

### 5. Check the response

Use a `Condition` to verify the call succeeded:

```json
{
  "Condition": {
    "If": "ApiResponse.StatusCode.ToString() == \"200\"",
    "Then": {
      "Do": [
        { "Return": { "Value": true } }
      ]
    },
    "Else": {
      "Do": [
        { "Throw": { "Value": "CheckSystem failed: HTTP %{ApiResponse.StatusCode.ToString()}%" } }
      ]
    }
  }
}
```

### Complete `CheckSystem` Do block

Here is the full `Do` block assembled together. This version uses `UseSsl` so the same script works with either `https://` or `http://`:

```json
"Do": [
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
  },
  { "NewHttpRequest": { "ObjectName": "ApiRequest" } },
  { "HttpAuth": { "RequestObjectName": "ApiRequest", "Type": "Basic", "Credentials": { "Login": "%FuncUsername%", "Password": "%FuncPassword%" } } },
  {
    "Request": {
      "RequestObjectName": "ApiRequest",
      "ResponseObjectName": "ApiResponse",
      "Verb": "GET",
      "Url": "/api/status",
      "Content": {
        "ContentType": "application/json"
      }
    }
  },
  {
    "Condition": {
      "If": "ApiResponse.StatusCode.ToString() == \"200\"",
      "Then": {
        "Do": [
          { "Return": { "Value": true } }
        ]
      },
      "Else": {
        "Do": [
          { "Throw": { "Value": "CheckSystem failed: HTTP %{ApiResponse.StatusCode.ToString()}%" } }
        ]
      }
    }
  }
]
```

This pattern is the core of most simple HTTP platforms:

- `BaseAddress` defines the root URL.
- `NewHttpRequest` creates a request object you can configure.
- `HttpAuth` adds the authentication details.
- `Request` sends the call and stores the response.
- `Condition` turns the HTTP status code into a clear success or failure.

At this point, your script proves one thing: the service account can reach the API and authenticate successfully.

## Step 4: Add CheckPassword

Next, add a second operation that uses the managed account credentials instead of the service account credentials:

```json
"CheckPassword": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "AccountPassword": { "Type": "Secret", "Required": true } },
    { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
  ],
  "Do": [
    { "BaseAddress": { "Address": "https://%Address%" } },
    { "NewHttpRequest": { "ObjectName": "ApiRequest" } },
    { "HttpAuth": { "RequestObjectName": "ApiRequest", "Type": "Basic", "Credentials": { "Login": "%AccountUserName%", "Password": "%AccountPassword%" } } },
    {
      "Request": {
        "RequestObjectName": "ApiRequest",
        "ResponseObjectName": "ApiResponse",
        "Verb": "GET",
        "Url": "/api/users/me",
        "Content": {
          "ContentType": "application/json"
        }
      }
    },
    {
      "Condition": {
        "If": "ApiResponse.StatusCode.ToString() == \"200\"",
        "Then": {
          "Do": [
            { "Return": { "Value": true } }
          ]
        },
        "Else": {
          "Do": [
            { "Throw": { "Value": "CheckPassword failed: HTTP %{ApiResponse.StatusCode.ToString()}%" } }
          ]
        }
      }
    }
  ]
}
```

What changed:

- `CheckPassword` uses `AccountUserName` and `AccountPassword`, which SPP auto-populates from the managed account.
- It calls a user-specific endpoint such as `/api/users/me` to confirm the credentials work for that account.
- A `200` response means the password is valid. Any other status means the check failed.

Just like `CheckSystem`, the final combined script below uses `UseSsl` to choose HTTPS or HTTP for this operation too.

## Step 5: Add ChangePassword

`ChangePassword` is the operation SPP uses when it rotates a managed account password. For a REST API, that usually means the service account authenticates first and then sends an administrative request to update the managed account's password.

Unlike `CheckPassword`, which authenticates **as the managed account** to prove the existing password works, `ChangePassword` usually authenticates **as the service account** because changing another user's password normally requires admin privileges.

Add this operation:

```json
"ChangePassword": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "FuncUsername": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": true } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "NewPassword": { "Type": "Secret", "Required": true } },
    { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
  ],
  "Do": [
    {
      "Condition": {
        "If": "UseSsl",
        "Then": { "Do": [{ "BaseAddress": { "Address": "https://%Address%" } }] },
        "Else": { "Do": [{ "BaseAddress": { "Address": "http://%Address%" } }] }
      }
    },
    { "NewHttpRequest": { "ObjectName": "ChangeRequest" } },
    { "HttpAuth": { "RequestObjectName": "ChangeRequest", "Type": "Basic", "Credentials": { "Login": "%FuncUsername%", "Password": "%FuncPassword%" } } },
    {
      "Request": {
        "RequestObjectName": "ChangeRequest",
        "ResponseObjectName": "ChangeResponse",
        "Verb": "PUT",
        "Url": "/api/users/%AccountUserName%/password",
        "Content": {
          "ContentType": "application/json",
          "Body": "{\"password\": \"%NewPassword%\"}"
        }
      }
    },
    {
      "Condition": {
        "If": "ChangeResponse.StatusCode.ToString() == \"200\" || ChangeResponse.StatusCode.ToString() == \"204\"",
        "Then": { "Do": [{ "Return": { "Value": true } }] },
        "Else": { "Do": [{ "Throw": { "Value": "ChangePassword failed: HTTP %{ChangeResponse.StatusCode.ToString()}%" } }] }
      }
    }
  ]
}
```

Key points:

- `FuncUsername` / `FuncPassword` are the service-account credentials used for the admin API call.
- `AccountUserName` identifies the managed account whose password SPP is rotating.
- `NewPassword` is the new password value generated by SPP and passed into the operation.
- This simplified admin-driven example does **not** send `AccountPassword`. If your API requires the old password too, add `AccountPassword` and include it in the request body.

The `Do` block follows the standard HTTP password-change pattern:

1. Choose `https://` or `http://` with `UseSsl`.
2. Create a new request object.
3. Authenticate the request with Basic Auth using the service account.
4. Send a `PUT` request to `/api/users/%AccountUserName%/password`.
5. Treat `200` or `204` as success and throw a clear error for anything else.

The JSON request body is constructed inline as a string:

```json
"Body": "{\"password\": \"%NewPassword%\"}"
```

The `%NewPassword%` variable is expanded before the request is sent, so the API receives real JSON such as `{"password": "N3wP@ssw0rd!"}`. Many APIs use a slightly different shape, such as including both the old and new password in the body.

Some APIs use `POST` instead of `PUT`, or require a different body format. The pattern stays the same: authenticate as the admin, send the password-change request, and verify the success status code.

## Step 6: The Complete Script

Here is the full script with all three operations in one file:

```json
{
  "Id": "MyFirstHttpPlatform",
  "BackEnd": "Scriptable",
  "CheckSystem": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "FuncUsername": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
    ],
    "Do": [
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
      },
      { "NewHttpRequest": { "ObjectName": "ApiRequest" } },
      { "HttpAuth": { "RequestObjectName": "ApiRequest", "Type": "Basic", "Credentials": { "Login": "%FuncUsername%", "Password": "%FuncPassword%" } } },
      {
        "Request": {
          "RequestObjectName": "ApiRequest",
          "ResponseObjectName": "ApiResponse",
          "Verb": "GET",
          "Url": "/api/status",
          "Content": {
            "ContentType": "application/json"
          }
        }
      },
      {
        "Condition": {
          "If": "ApiResponse.StatusCode.ToString() == \"200\"",
          "Then": {
            "Do": [
              { "Return": { "Value": true } }
            ]
          },
          "Else": {
            "Do": [
              { "Throw": { "Value": "CheckSystem failed: HTTP %{ApiResponse.StatusCode.ToString()}%" } }
            ]
          }
        }
      }
    ]
  },
  "CheckPassword": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AccountPassword": { "Type": "Secret", "Required": true } },
      { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
    ],
    "Do": [
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
      },
      { "NewHttpRequest": { "ObjectName": "ApiRequest" } },
      { "HttpAuth": { "RequestObjectName": "ApiRequest", "Type": "Basic", "Credentials": { "Login": "%AccountUserName%", "Password": "%AccountPassword%" } } },
      {
        "Request": {
          "RequestObjectName": "ApiRequest",
          "ResponseObjectName": "ApiResponse",
          "Verb": "GET",
          "Url": "/api/users/me",
          "Content": {
            "ContentType": "application/json"
          }
        }
      },
      {
        "Condition": {
          "If": "ApiResponse.StatusCode.ToString() == \"200\"",
          "Then": {
            "Do": [
              { "Return": { "Value": true } }
            ]
          },
          "Else": {
            "Do": [
              { "Throw": { "Value": "CheckPassword failed: HTTP %{ApiResponse.StatusCode.ToString()}%" } }
            ]
          }
        }
      }
    ]
  },
  "ChangePassword": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "FuncUsername": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "NewPassword": { "Type": "Secret", "Required": true } },
      { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
    ],
    "Do": [
      {
        "Condition": {
          "If": "UseSsl",
          "Then": { "Do": [{ "BaseAddress": { "Address": "https://%Address%" } }] },
          "Else": { "Do": [{ "BaseAddress": { "Address": "http://%Address%" } }] }
        }
      },
      { "NewHttpRequest": { "ObjectName": "ChangeRequest" } },
      { "HttpAuth": { "RequestObjectName": "ChangeRequest", "Type": "Basic", "Credentials": { "Login": "%FuncUsername%", "Password": "%FuncPassword%" } } },
      {
        "Request": {
          "RequestObjectName": "ChangeRequest",
          "ResponseObjectName": "ChangeResponse",
          "Verb": "PUT",
          "Url": "/api/users/%AccountUserName%/password",
          "Content": {
            "ContentType": "application/json",
            "Body": "{\"password\": \"%NewPassword%\"}"
          }
        }
      },
      {
        "Condition": {
          "If": "ChangeResponse.StatusCode.ToString() == \"200\" || ChangeResponse.StatusCode.ToString() == \"204\"",
          "Then": { "Do": [{ "Return": { "Value": true } }] },
          "Else": { "Do": [{ "Throw": { "Value": "ChangePassword failed: HTTP %{ChangeResponse.StatusCode.ToString()}%" } }] }
        }
      }
    ]
  }
}
```

This combined version is still minimal, but it shows the full HTTP request and response patterns you will reuse in more advanced scripts.

## Step 7: Validate and Upload

Validate the script locally first, then create the custom platform in SPP:

```powershell
Test-SafeguardCustomPlatformScript ".\MyFirstHttpPlatform.json"
New-SafeguardCustomPlatform -Name "My First HTTP Platform" -ScriptFile ".\MyFirstHttpPlatform.json"
```

If validation fails, fix the JSON before you upload anything.

## Step 8: Create a Test Asset and Account

Once the platform exists, create a test asset and a test account:

```powershell
New-SafeguardCustomPlatformAsset "My First HTTP Platform" "api.example.com" -ServiceAccountCredentialType Password -ServiceAccountName "admin"
New-SafeguardAssetAccount "api.example.com" "testuser"
Set-SafeguardAssetAccountPassword -AssetToUse "api.example.com" -AccountToUse "testuser"
```

In this example, `admin` is the service account used by `CheckSystem` and `ChangePassword`, and `testuser` is the managed account validated by `CheckPassword` and updated by `ChangePassword`.

## Step 9: Test It

Now run the connectivity check, the account-password check, and finally a password change while you inspect the task log output:

```powershell
Test-SafeguardAsset "api.example.com" -ExtendedLogging
Test-SafeguardAssetAccountPassword "api.example.com" "testuser" -ExtendedLogging
Invoke-SafeguardAssetAccountPasswordChange -AssetToUse "api.example.com" -AccountToUse "testuser"
Get-SafeguardTaskLog
```

Start with `Test-SafeguardAsset`. If `CheckSystem` fails, fix connectivity or service-account issues before you test `CheckPassword`. Once both read-only checks work, run `Invoke-SafeguardAssetAccountPasswordChange` to exercise `ChangePassword`.

## What Happens When It Fails

When an HTTP platform fails, start with the status code and connection details:

- SSL certificate errors — add `"IgnoreServerCertAuthentication": true` to the `Request` while developing against self-signed certificates, then remove or disable it for production use.
- `401 Unauthorized` — the credentials are wrong or the authentication type does not match what the API expects.
- `403 Forbidden` — the service account authenticated, but it does not have permission to change another user's password.
- `404 Not Found` — the URL path is wrong. Verify the endpoint in the API documentation.
- Connection refused — check the address and confirm whether the target expects HTTPS or HTTP.
- Timeout — there may be a network access issue or the API may be slow. If needed, extend the script later with timeout handling.

During development, always run tests with `-ExtendedLogging` and review `Get-SafeguardTaskLog` so you can see where the request failed.

## Adapting to Your API

The example uses generic placeholder endpoints. To make it work with a real target:

- Change `/api/status`, `/api/users/me`, and `/api/users/%AccountUserName%/password` to the actual endpoints your API exposes.
- Switch the authentication type if needed, such as Bearer tokens or OAuth2. See the [HTTP Platforms Guide](../guides/http-platforms.md).
- Add custom parameters for API-specific values such as a base path, tenant ID, or API version.
- Adjust the password-change verb or request body if your API uses `POST`, expects the old password, or wraps the new password in a different JSON structure.
- Handle pagination, token exchange, or multi-step authentication flows for more complex APIs.

## Next Steps

Once this minimal script works, you can build on it:

- Add account discovery so SPP can onboard accounts automatically from the target system.
- Implement Bearer token authentication for OAuth2-based APIs.
- Add API-specific parameters such as a tenant ID, API version, or base path.
- Adapt `ChangePassword` to APIs that require the current password or a follow-up verification call.
- Explore the real-world [`WordPressHttp.json`](../../samples/http/wordpress/WordPressHttp.json) sample.
- Read the [Operations Reference](../reference/operations.md).
