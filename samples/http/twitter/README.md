# Twitter Password Management (HTTP Form)

This sample validates and changes Twitter account passwords by walking the site's login and settings forms over HTTP. It also detects several common challenge states that prevent unattended password management.

## Target System

Twitter/X user accounts accessed through the web interface.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckPassword` | Loads the login page, submits the managed account credentials, and returns success only when the login completes without an error redirect. |
| `ChangePassword` | Signs in, detects login-challenge or locked-account conditions, posts the password-change form from the settings page, and checks for the expected confirmation redirect. |

## Prerequisites

- SPP 6.0 or later
- Outbound HTTPS access from SPP to `https://twitter.com`
- The managed account must support direct username/password sign-in without extra verification prompts
- Managed account username and current password; no separate service account is required

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./CustomTwitter.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure the managed account(s); no separate service account is required
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The script first resets internal flags for login challenge and account-locked detection. It then fetches the Twitter login form, submits the current credentials, and inspects redirect targets to detect login errors, verification challenges, or locked accounts. For password changes it opens `settings/password`, fills the current and new password fields, posts the update, and treats the password-reset confirmation redirect as success.

## Parameters

- `Timeout`: Optional operation timeout in seconds. Default: `30`.
- `AssetName`: Friendly name used in status messages. Default: `Twitter`.

## Limitations

- This sample depends on Twitter's current login and settings pages, so HTML or redirect-flow changes can break it.
- Login challenges, login verification, locked accounts, and access-restriction flows are detected and reported as failures rather than being automated.
- The sample assumes password-based authentication only.

## Related

- [HTTP platform patterns](../../../docs/guides/http-platforms.md)
- [Forms command reference](../../../docs/reference/commands/forms.md)
- [Testing and debugging](../../../docs/guides/testing-and-debugging.md)
