[← HTTP Samples](../README.md)

# Facebook Password Management (HTTP Form)

This sample validates and changes Facebook account passwords by replaying Facebook's browser-based login and security forms. It is a form-scraping example for sites that do not expose a supported administrative API.

## Target System

Facebook user accounts accessed through the public web interface.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckPassword` | Opens the Facebook login form, submits the managed account credentials, and succeeds only when the redirect pattern indicates a normal authenticated session. |
| `ChangePassword` | Signs in with the current password, opens the security/password page, submits the password-change form, logs out, and verifies the new password by logging in again. |

## Prerequisites

- SPP 6.0 or later
- Outbound HTTPS access from SPP to `https://www.facebook.com`
- The managed account must use password-based sign-in only; checkpoint, login approvals, MFA prompts, or CAPTCHA must be disabled
- Managed account username/email and current password; no separate service account is required

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./CustomFacebook.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure the managed account(s); no separate service account is required
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The script fetches the no-script Facebook login page, extracts the login form, and posts the supplied credentials. For password change, it navigates to the security settings page, fills in the current, new, and confirmation password fields, submits the form, logs out, and then signs in again with the new password to confirm the rotation succeeded.

## Parameters

- `Timeout`: Optional operation timeout in seconds. Default: `30`.
- `AssetName`: Friendly name used in status messages. Default: `Facebook`.

## Limitations

- This sample depends on Facebook's current HTML form fields and redirect behavior, so UI changes can break it without warning.
- It does not handle checkpoint flows, login approvals, MFA, CAPTCHA, or other interactive challenges.
- `ChangePassword` returns `false` if the current and new password are identical.

## Related

- [HTTP platform patterns](../../../docs/guides/http-platforms.md)
- [Forms command reference](../../../docs/reference/commands/forms.md)
- [Testing and debugging](../../../docs/guides/testing-and-debugging.md)
