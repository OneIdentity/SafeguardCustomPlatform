[← HTTP Samples](../README.md)

# Okta Discovery and Group Restore (HTTP API)

This sample combines password validation, password reset, account discovery, and group-membership restore/suspend workflows for Okta. It uses an Okta API token for administrative operations and the `/authn` endpoint for end-user password checks.

**Platform Script:** [`Okta_WithDiscoveryAndGroupMembershipRestore.json`](./Okta_WithDiscoveryAndGroupMembershipRestore.json)

## Target System

Okta users and group memberships in an Okta tenant.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Looks up a known user with the administrative API token to confirm the tenant is reachable and the token works. |
| `CheckPassword` | Calls `api/v1/authn` with the managed account credentials to verify the current password. |
| `ChangePassword` | Resolves the target user ID and updates the password through the Okta Users API. |
| `EnableAccount` | Adds the user back to the configured Okta groups selected by the `Group1`-`Group5` rules. |
| `DisableAccount` | Removes the user from the configured Okta groups selected by the `Group1`-`Group5` rules. |
| `DiscoverAccounts` | Pages through Okta users, reads each user's group memberships, and writes discovered accounts with group data back to Safeguard. |

## Prerequisites

- SPP 6.0 or later
- Network access from SPP to the Okta tenant URL configured in `Address`
- An Okta API token with rights to read users and groups, change passwords, and add/remove users from groups
- `FuncUsername` must be the login name of an existing Okta user for `CheckSystem`; `FuncPassword` is the Okta API token used as the `SSWS` authorization value

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./Okta_WithDiscoveryAndGroupMembershipRestore.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account, managed account(s), and any group restore rules you want to use
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

Administrative operations build an `Authorization: SSWS %FuncPassword%` header and call the Okta Users and Groups APIs. Password checks use `api/v1/authn` with the managed account username and password. `EnableAccount` and `DisableAccount` evaluate up to five group rules, where each rule can target `<all>` accounts or accounts whose usernames contain any comma-separated substring, then add or remove memberships with `api/v1/groups/%GroupId%/users/%UserId%`. Discovery calls `api/v1/users`, follows Okta pagination via the `Link` header, fetches each user's groups, and writes discovered accounts plus group memberships.

## Parameters

- `FuncPassword`: Okta API token used for all administrative API calls.
- `FuncUsername`: Existing Okta username used only by `CheckSystem`.
- `Group1Name`-`Group5Name`: Optional Okta groups to add back on restore or remove on suspend.
- `Group1Members`-`Group5Members`: `<all>` or comma-separated username fragments used to decide which accounts map to each group.
- `SearchCriteria`: Optional raw Okta `search=` expression used during discovery.
- `ResultsPageLimit`: Users fetched per discovery request. Default: `25`.
- `UseSsl` / `SkipServerCertValidation`: Control HTTPS usage and certificate validation.

## Limitations

- The sample was tested with ACTIVE Okta users.
- `EnableAccount` and `DisableAccount` change group membership only; they do not activate or deactivate the Okta user object itself.
- Discovery is capped by Okta's page size behavior; the script forces any requested page size above `200` back to `200`.
- Group matching is substring-based and limited to five configured group rules, so choose member patterns carefully to avoid unintended matches.
- Okta discovery does not list deactivated users by default.

## Related

- [HTTP platform patterns](../../../docs/guides/http-platforms.md)
- [Account discovery guide](../../../docs/guides/account-discovery.md)
- [Operations reference](../../../docs/reference/operations.md)
- [Testing and debugging](../../../docs/guides/testing-and-debugging.md)
