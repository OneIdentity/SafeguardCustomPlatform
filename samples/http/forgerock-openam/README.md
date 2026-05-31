[← HTTP Samples](../README.md)

# ForgeRock AM Password Management (HTTP API)

This sample manages ForgeRock AM/OpenAM users through the REST API for a specific realm. It uses header-based authentication to validate credentials and to set a user's `userpassword` attribute.

**Platform Script:** [`Forgerock_OpenAM.json`](./Forgerock_OpenAM.json)

## Target System

ForgeRock AM / OpenAM user accounts in a target realm.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Authenticates the service account against the realm's `/authenticate` endpoint to verify connectivity and credentials. |
| `CheckPassword` | Authenticates the managed account against the same realm endpoint to verify the current password. |
| `ChangePassword` | Authenticates with the service account and updates the target user's `userpassword` through the realm's user API. |

## Prerequisites

- SPP 6.0 or later
- ForgeRock AM/OpenAM 7.5 or later recommended; this sample was tested with AM 7.5
- Network access from SPP to the AM endpoint and realm
- A service account with permission to authenticate and update users in the target realm

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./Forgerock_OpenAM.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account and managed account(s), including the target `Realm`
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The script builds an HTTP or HTTPS base address from `Address`, `Port`, and `UseSsl`. `CheckSystem` and `CheckPassword` call `openam/json/realms/%Realm%/authenticate` with `Accept-API-Version`, `X-OpenAM-Username`, and `X-OpenAM-Password` headers. `ChangePassword` first authenticates the service account, then sends a `PUT` to `openam/json/realms/%Realm%/users/%Username%` with a JSON body containing the new `userpassword` value.

## Parameters

- `Realm`: Required ForgeRock realm name used in all API paths.
- `Address`: AM host name or address.
- `Port`: Optional custom port to append to the address.
- `UseSsl`: Uses HTTPS when `true`; HTTP when `false`.
- `SkipServerCertValidation`: Ignores certificate validation errors when enabled.

## Limitations

- The sample updates only the `userpassword` field in the specified realm.
- It relies on the ForgeRock AM API paths and headers shown in the sample and may need adjustment for different deployments or custom paths.
- Password policy failures are surfaced only through the returned HTTP status/error.

## Related

- [HTTP platform patterns](../../../docs/guides/http-platforms.md)
- [Request command reference](../../../docs/reference/commands/request.md)
- [Testing and debugging](../../../docs/guides/testing-and-debugging.md)
