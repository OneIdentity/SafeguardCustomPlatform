[← HTTP Samples](../README.md)

# OneLogin JIT Account Lifecycle and Role Elevation

This sample is a JIT-focused add-on for OneLogin environments already managed through a separate Generic REST connector. It validates OAuth client credentials, enables or disables users, and elevates or demotes users by assigning or removing OneLogin roles.

## Target System

OneLogin users and role assignments used in Safeguard JIT access workflows.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Requests an OAuth access token with the configured client credentials, then revokes it to verify connectivity and credentials. |
| `ChangePassword` | Placeholder only; logs that password changes are not supported and returns `false`. |
| `EnableAccount` | Looks up the user by username and sets the OneLogin status to enabled. |
| `DisableAccount` | Looks up the user by username and sets the OneLogin status to disabled. |
| `ElevateAccount` | Resolves each requested OneLogin role in `PrivilegeGroupMembership`, assigns the user to those roles, and polls until the assignments are visible. |
| `DemoteAccount` | Resolves each requested OneLogin role in `PrivilegeGroupMembership`, removes the user from those roles, and polls until the removals are visible. |

## Prerequisites

- SPP 6.0 or later
- Network access from SPP to the OneLogin API endpoint in `Address`
- A separate OneLogin Generic REST connector already managing the base asset, account, and entitlement inventory
- OneLogin OAuth client credentials with rights to manage users and roles; configure the client ID as `FuncUsername` and the client secret as `FuncPassword`

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./OneLogin_GRC_JIT_addon.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account, managed account(s), and JIT role mappings for `PrivilegeGroupMembership`
5. Test with `Test-SafeguardAsset -ExtendedLogging`, then exercise the access-request workflows that call `EnableAccount`, `DisableAccount`, `ElevateAccount`, and `DemoteAccount`

## How It Works

The script authenticates with `auth/oauth2/v2/token` using client credentials and stores the returned bearer token. For account lifecycle operations it looks up the OneLogin user by username and sends a `PUT` to `api/2/users/%UserId%` with the desired status. For role elevation and demotion it resolves each role name to a role ID, adds or removes the user with `api/2/roles/%RoleId%/users`, and repeatedly checks role membership with `api/2/roles/%RoleId%/users?name=%Username%` until the change is visible. At the end of each run it revokes the access token with `auth/oauth2/revoke`.

## Parameters

- `PrivilegeGroupMembership`: Array of OneLogin role names to grant during elevate and remove during demote.
- `RetryIntervalSeconds`: Delay between role-membership verification polls. Default: `5`.
- `HttpProxyUri`, `HttpProxyPort`, `HttpProxyUserName`, `HttpProxyPassword`: Optional outbound proxy settings used on API calls.
- `SkipServerCertValidation`: Controls TLS certificate validation.

## Limitations

- `ChangePassword` is intentionally unsupported; OneLogin accounts in this design are expected to use TOTP or other non-password flows.
- The role-verification loop has no maximum retry count, so a stuck downstream provisioning problem can leave an elevate or demote task pending indefinitely.
- If one configured role cannot be found or updated, the script logs the failure and continues with the next role. Review extended logs carefully when multiple roles are requested.
- `ElevateAccount` requires the user to already be active; inactive users are rejected before any role assignment is attempted.

## Related

- [JIT elevation guide](../../../docs/guides/jit-elevation.md)
- [HTTP platform patterns](../../../docs/guides/http-platforms.md)
- [Reserved parameters reference](../../../docs/reference/reserved-parameters.md)
- [Testing and debugging](../../../docs/guides/testing-and-debugging.md)
