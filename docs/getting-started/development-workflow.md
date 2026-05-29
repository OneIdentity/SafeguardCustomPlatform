[← Documentation](../README.md)

# Development Workflow

This guide walks through the full development loop for building, validating, uploading, testing, and refining a Safeguard custom platform script. The [`safeguard-ps` PowerShell module](https://github.com/OneIdentity/safeguard-ps) is the primary workflow because it provides purpose-built cmdlets for the standard custom platform tasks.

## Prerequisites

Before you start, make sure you have:

- Access to a Safeguard for Privileged Passwords (SPP) appliance running v6.0 or later.
- An account with the `AssetAdmin` or `ApplianceAdmin` role.
- The [`safeguard-ps` PowerShell module](https://github.com/OneIdentity/safeguard-ps).
- A test target system. Never begin development against production assets or credentials.

Most of the examples in this guide assume you connect once at the start of your session. The examples use `-Insecure`, which is common in development environments.

```powershell
Connect-Safeguard -Appliance "spp.lab.local" -IdentityProvider local -Username "admin" -Insecure
```

## The Development Lifecycle

Custom platform development is an iterative loop:

1. Write or edit your JSON script.
2. Validate it locally with `Test-SafeguardCustomPlatformScript`.
3. Create or update the custom platform in SPP.
4. Create a test asset that uses the custom platform.
5. Add a test account.
6. Run focused tests with extended logging.
7. Review the task logs.
8. Fix issues and repeat from step 1.

In practice, you will repeat this cycle many times while you refine connectivity, parsing, authentication, and error handling.

## Writing Your Script

Start with a known-good base whenever possible.

- Begin from a template in `SampleScripts/Templates/` or adapt an existing sample script that is close to your target system.
- Use a JSON-aware editor so syntax errors are caught before upload.
- Refer to [Script Structure](../reference/script-structure.md) for the required format, top-level keys, operations, and `Do` blocks.
- Validate early with `Test-SafeguardCustomPlatformScript` before you even create a custom platform on the appliance.

### Practical guidance

- Implement one operation at a time.
- Start with `CheckSystem` to verify connectivity and authentication basics.
- Add password or key rotation operations only after the basic connection flow works.
- Keep sample values generic so the script can be reused across multiple test assets.

## Validating Your Script

Use `Test-SafeguardCustomPlatformScript` as a dry run before uploading anything to SPP. It parses the JSON, validates the script, and returns a preview of the operations and properties the script would produce. If the script is invalid, the cmdlet throws an error with details about what to fix.

```powershell
$preview = Test-SafeguardCustomPlatformScript ".\MyScript.json"
$preview
```

A typical validation workflow looks like this:

1. Edit `MyScript.json`.
2. Run `Test-SafeguardCustomPlatformScript ".\MyScript.json"`.
3. Review the preview or fix the reported validation error.
4. Only upload the script after validation succeeds.

This is the fastest way to catch structural problems before you create or update anything on the appliance.

## Creating the Platform

Once the script validates cleanly, create the custom platform and upload the script in one step.

```powershell
New-SafeguardCustomPlatform -Name "My Custom Linux" -ScriptFile ".\MyScript.json"
```

If your platform needs session support, create it with the session-related options at the same time:

```powershell
New-SafeguardCustomPlatform -Name "My Custom Linux" -ScriptFile ".\MyScript.json" -AllowSessionRequests -SshSessionPort 22
```

Web UI path: **Asset Management → Platforms → Custom Platforms → Add**.

You can verify the result afterward with `Get-SafeguardCustomPlatform "My Custom Linux"`.

## Updating the Script

During development you usually keep the same custom platform and replace only the script.

```powershell
Import-SafeguardCustomPlatformScript "My Custom Linux" -ScriptFile ".\MyScript.json"
```

You can also target the platform by ID:

```powershell
Import-SafeguardCustomPlatformScript 10001 -ScriptFile ".\MyScript.json"
```

Web UI path: **Asset Management → Platforms → Custom Platforms**, open the platform, then upload the new script.

## Creating a Test Asset

Once the platform exists, attach it to a non-production asset so you can run real tasks safely.

```powershell
New-SafeguardCustomPlatformAsset "My Custom Linux" "10.0.0.1"
```

If the platform needs a service account, include it when you create the asset:

```powershell
New-SafeguardCustomPlatformAsset "My Custom Linux" "10.0.0.1" -ServiceAccountCredentialType Password -ServiceAccountName "svc_admin"
```

If the script defines custom parameters, you can provide them explicitly:

```powershell
New-SafeguardCustomPlatformAsset "My Custom Linux" "10.0.0.1" -CustomScriptParameters @(@{Name="RequestTerminal";Value="False"})
```

If you omit `-CustomScriptParameters`, the cmdlet discovers the platform's custom parameters and prompts for values interactively. To change parameters later on an existing asset, use `Set-SafeguardCustomPlatformAssetParameter`.

Web UI path: **Asset Management → Assets → Add Asset**.

Use a dedicated test asset so changes to the script cannot affect production systems or live credentials.

## Adding a Test Account

Add an account that the platform can manage on the test asset.

```powershell
New-SafeguardAssetAccount "Test Target" "testuser" -Description "Test account for development"
Set-SafeguardAssetAccountPassword -AssetToUse "Test Target" -AccountToUse "testuser"
```

`Set-SafeguardAssetAccountPassword` prompts for the password securely.

Web UI path: open the asset, go to **Accounts**, then choose **Add Account**.

Use a disposable test account whenever possible so password and key rotation tests are safe to repeat.

## Testing Operations

Run the smallest useful test first, and always use extended logging during development.

```powershell
# CheckSystem
Test-SafeguardAsset "Test Target" -ExtendedLogging

# CheckPassword
Test-SafeguardAssetAccountPassword "Test Target" "testuser" -ExtendedLogging

# ChangePassword
Invoke-SafeguardAssetAccountPasswordChange "Test Target" "testuser"
```

Recommended order during development:

1. Run `Test-SafeguardAsset` to confirm the script can connect and identify the target system.
2. Run `Test-SafeguardAssetAccountPassword` to verify account authentication.
3. Run `Invoke-SafeguardAssetAccountPasswordChange` only after the first two operations are stable.

Web UI path: **Asset Management → Assets**, select the asset or account, then use the relevant **Actions** command.

## Reading Task Logs

Task logs are your primary feedback loop. Use them to understand validation issues, connection failures, command output, parsing problems, and unexpected responses from the target system.

Detailed script traces depend on having run the task with `-ExtendedLogging`. During development, use extended logging on your test runs so the log contains enough detail to diagnose failures.

```powershell
# List available task logs
Get-SafeguardTaskLog

# Get the full log for a specific task
Get-SafeguardTaskLog "ed51c2b3-4fd2-11f1-b56c-dcad45f4455d"

# Get a specific log section
Get-SafeguardTaskLog "ed51c2b3-4fd2-11f1-b56c-dcad45f4455d" -LogName Operation
```

If a task is still running or appears stuck, `Get-SafeguardRunningTask` can show in-progress work and `Stop-SafeguardRunningTask <taskId>` can cancel a stuck task.

Web UI path: **Administrative Tools → Activity Center**.

## Iterating

Once you identify a problem, update the script and run the cycle again.

1. Fix the issue in the JSON script.
2. Validate it again with `Test-SafeguardCustomPlatformScript`.
3. Upload the updated script to the same custom platform with `Import-SafeguardCustomPlatformScript`.
4. Re-run the relevant test task with extended logging.
5. Review the new logs.
6. Repeat until the operation behaves consistently.

A typical iteration looks like this:

```powershell
Test-SafeguardCustomPlatformScript ".\MyScript.json"
Import-SafeguardCustomPlatformScript "My Custom Linux" -ScriptFile ".\MyScript.json"
Test-SafeguardAsset "Test Target" -ExtendedLogging
```

Change one thing at a time so each test result is easy to interpret.

## Tips

- Use `Test-SafeguardCustomPlatformScript` before every upload.
- Always test with `-ExtendedLogging` during development.
- Start with `CheckSystem` to validate basic connectivity before testing password operations.
- Use `Export-SafeguardCustomPlatformScript "My Custom Linux"` to confirm what script is currently stored on the appliance.
- Use `Get-SafeguardCustomPlatform "My Custom Linux"` to confirm the platform details SPP derived from your script.
- Keep a dedicated test asset and account for development.
- Never develop first against production credentials or production targets.
- If upload validation fails, read the error carefully. SPP usually tells you exactly what is wrong.
- Use `Set-SafeguardCustomPlatformAssetParameter` when you need to adjust custom parameters on an existing test asset.
- Change one thing at a time when debugging so each test result is easy to interpret.

## Next Steps

- [Your First SSH Script](your-first-ssh-script.md) — Build a working SSH script step by step.
- [Your First HTTP Script](your-first-http-script.md) — Build a working HTTP script step by step.
- [Testing and Debugging](testing-and-debugging.md) — Deep dive into debugging techniques.
