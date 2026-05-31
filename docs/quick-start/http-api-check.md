# Quick Start: HTTP API Check

Get a working custom platform that validates connectivity to a REST API over HTTP in under 5 minutes.

## What You'll Get

A minimal platform script that sends an HTTP request to an API endpoint to verify that the system is reachable and credentials are valid.

## Steps

### 1. Copy the Minimal Template

Download or copy [`TemplateHttpMinimal.json`](../../templates/TemplateHttpMinimal.json) and rename it (e.g., `MyApiCheck.json`).

### 2. Customize the Endpoint

Open the file and update the `CheckSystem` operation to hit your API's health or authentication endpoint. For example, if your API uses Basic Auth:

```json
"CheckSystem": {
  "Parameters": [
    { "Address": "" },
    { "FuncUserName": "" },
    { "FuncPassword": "" }
  ],
  "Do": [
    { "BaseAddress": "https://%Address%" },
    { "NewHttpRequest": { "Name": "req" } },
    { "HttpAuth": { "Type": "Basic", "UserName": "%FuncUserName%", "Password": "%FuncPassword%", "Request": "req" } },
    { "Request": { "Method": "GET", "Url": "/api/v1/health", "Request": "req" } },
    {
      "Condition": {
        "If": "Response.StatusCode != 200",
        "Then": { "Do": [{ "Throw": { "Message": "System check failed: HTTP %Response.StatusCode%" } }] }
      }
    }
  ]
}
```

Replace `/api/v1/health` with your target's actual endpoint.

### 3. Upload to SPP

```powershell
Import-SafeguardCustomPlatformScript -FilePath .\MyApiCheck.json
```

### 4. Create an Asset

1. In the SPP web UI, go to **Asset Management > Assets > Add**
2. Set the platform to your new custom platform
3. Set the network address to the API hostname
4. Assign a service account with API credentials (username/password or token)

### 5. Test

```powershell
Test-SafeguardAssetConnection -AssetToUse "MyApiServer" -ExtendedLogging
```

If it reports success, SPP can reach your API.

## Next Steps

- Add `CheckPassword` and `ChangePassword` — see [Your First HTTP Script](../tutorials/your-first-http-script.md)
- Learn about HTTP authentication patterns — see [HTTP Platforms Guide](../guides/http-platforms.md)
- Study a production-ready sample — see [WordPress HTTP](../../samples/http/wordpress/)
