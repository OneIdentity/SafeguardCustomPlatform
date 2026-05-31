[← HTTP Samples](../README.md)

# WordPress Password Management (Basic Auth API)

This sample manages WordPress users through the REST API using HTTP Basic authentication. It is a straightforward API example for environments where the site exposes authenticated REST endpoints for user administration.

## Target System

WordPress user accounts exposed through the WordPress REST API.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Uses the service account to call the REST API settings endpoint and verify connectivity and privileges. |
| `CheckPassword` | Uses the managed account credentials with Basic auth to call `/users/me/` and confirm the password works. |
| `ChangePassword` | Uses the service account to enumerate users, locate the target user, and post a new password to that user's REST endpoint. |

## Prerequisites

- SPP 6.0 or later
- A WordPress site reachable from SPP with the REST API enabled
- The JSON Basic Authentication plugin (or equivalent Basic-auth support) installed on the site
- A service account with permission to read settings and update WordPress users; use HTTPS because Basic auth sends credentials on every request

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./WordPressHttp.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account, managed account(s), and the `APIURL` path for the site's REST API
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The script chooses HTTP or HTTPS from `UseSsl`, builds a request object, and attaches Basic authentication. `CheckSystem` calls `%APIURL%/settings`, while `CheckPassword` calls `%APIURL%/users/me/` with the managed account's credentials. For password changes it first calls `%APIURL%/users?per_page=100`, finds the matching user, then posts a JSON body containing the new password to that user's endpoint and interprets the returned HTTP status.

## Parameters

- `APIURL`: Required REST path below the site root, such as `wp-json/wp/v2`.
- `UseSsl`: Uses HTTPS when `true`; strongly recommended for production.
- `SkipServerCertValidation`: Ignores certificate validation errors when enabled.

## Limitations

- This sample requires Basic-auth support on the WordPress REST API; stock WordPress does not enable this by default.
- `ChangePassword` only searches the first `100` users because the sample uses `per_page=100`.
- User lookup in `ChangePassword` compares the configured account name to the `name` field returned by the API, so the Safeguard account name must match that value.

## Related

- [HTTP platform patterns](../../../docs/guides/http-platforms.md)
- [HTTP auth reference](../../../docs/reference/commands/http-auth.md)
- [Testing and debugging](../../../docs/guides/testing-and-debugging.md)
