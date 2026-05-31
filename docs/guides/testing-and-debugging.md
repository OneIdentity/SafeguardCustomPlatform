[← Documentation](../README.md)

# Testing and Debugging

Testing a custom platform script is not a purely local workflow. You need a real SPP appliance, a test asset, and a managed account already configured to use your custom platform so SPP can execute the operation in context.

The [`safeguard-ps` PowerShell module](https://github.com/OneIdentity/safeguard-ps) gives you the API access you need to connect, upload a revised script, trigger a task, and inspect the resulting logs.

## Prerequisites

Before you start, make sure you have:

- The [`safeguard-ps` PowerShell module](https://github.com/OneIdentity/safeguard-ps) installed.
- Network access to your SPP appliance.
- A test asset and managed account already configured with your custom platform.
- A non-production target system so you can test safely.

Install the module if needed:

```powershell
Install-Module safeguard-ps
```

For the operations you can test, see the [Operations Reference](../reference/operations.md).

## Connect to SPP

Open PowerShell and connect to the appliance:

```powershell
Connect-Safeguard -Appliance <your-appliance> -IdentityProvider local -Username admin
```

If your lab appliance uses a self-signed certificate, add `-Insecure` during development.

## Upload Your Script

Upload (or replace) a script on an existing custom platform by name or ID:

```powershell
Import-SafeguardCustomPlatformScript "My Custom Platform" .\MyPlatform.json
```

During iterative development, you will usually upload the same platform many times.

To confirm that the appliance now has the script you expect, export it back immediately after upload:

```powershell
Export-SafeguardCustomPlatformScript "My Custom Platform"
```

That quick read-back check catches bad file paths, stale content, and "uploaded the wrong JSON" mistakes early.

You can also validate a script without uploading it (dry-run):

```powershell
Test-SafeguardCustomPlatformScript .\MyPlatform.json
```

This returns the platform object preview (operations, parameters, feature flags) or throws an error with details about what is wrong.

## Trigger Operations with Extended Logging

Use the dedicated test cmdlets instead of raw API calls. Each accepts `-ExtendedLogging` to capture detailed trace output.

```powershell
# Test connectivity to the asset
Test-SafeguardAsset "My Test Asset" -ExtendedLogging

# Check password for a specific account
Test-SafeguardAssetAccountPassword "My Test Asset" "root" -ExtendedLogging

# Check SSH key for a specific account
Test-SafeguardAssetAccountSshKey "My Test Asset" "svcaccount" -ExtendedLogging
```

Run one operation at a time while you debug. Start with the smallest safe operation first, then move to state-changing operations such as `ChangePassword` only after the basic flow is stable.

For the full list of supported operations, see [Operations Reference](../reference/operations.md). For the command vocabulary used inside your `Do` blocks, see the [Commands Reference](../reference/commands/index.md).

## Reading Task Logs

After running a test with `-ExtendedLogging`, retrieve the extended log data:

```powershell
# List all available task logs
Get-SafeguardTaskLog

# Get all logs for a specific task
Get-SafeguardTaskLog "ed51c2b3-4fd2-11f1-b56c-dcad45f4455d"

# Get a specific log section
Get-SafeguardTaskLog "ed51c2b3-4fd2-11f1-b56c-dcad45f4455d" -LogName Operation
```

These logs are your primary debugging output. Depending on the task and log section, they can show:

- Step-by-step command execution.
- Variable values and evaluated expressions.
- Remote output returned by the target system.
- Error messages, thrown exceptions, and failure context.

If you are not sure which log section you need, start with the task response and the Activity Center in SPP, then retrieve the specific log names reported for that task.

## Extended Logging

Adding `?extendedLogging=true` tells SPP to collect a much more detailed trace for the task.

Use extended logging when you need to:

- Debug a failing operation.
- Understand the exact flow through your `Do` block.
- Confirm that variables, conditions, and remote responses look the way you expect.
- Compare a successful run with a failing run.

> [!IMPORTANT]
> Extended logging can capture sensitive values, command output, prompts, or other diagnostic data you would not want in routine production logs. Use it only in development or test environments, and treat the resulting logs as sensitive.

## Common Testing Patterns

### Iterative development loop

The normal workflow is:

1. Edit the JSON script.
2. Upload the updated script.
3. Trigger one operation with extended logging.
4. Read the task logs.
5. Fix the script and repeat.

A typical loop looks like this:

```powershell
Import-SafeguardCustomPlatformScript "My Custom Platform" .\MyPlatform.json

Test-SafeguardAssetAccountPassword "My Test Asset" "root" -ExtendedLogging

Get-SafeguardTaskLog
```

### Testing individual operations

Do not jump straight to the most destructive workflow.

- Start with connection-oriented checks first.
- Then test read-only account operations such as `CheckPassword`.
- Only then test state-changing operations such as `ChangePassword`, `ChangeSshKey`, `EnableAccount`, or `DisableAccount`.

That order makes it much easier to isolate whether the failure is in connectivity, authentication, parsing, or the action itself.

### Verifying feature flags after upload

After an upload, inspect the derived flags:

```powershell
Get-SafeguardCustomPlatform "My Custom Platform" | Format-List DisplayName, *Fl*
```

You can also check the custom parameters the platform exposes:

```powershell
Get-SafeguardCustomPlatformScriptParameter "My Custom Platform"
```

If a capability is missing, compare the uploaded script against the rules in [Platform Feature Flags](../concepts/feature-flags.md). Many "why does SPP not show this option?" problems are really operation-name or reserved-parameter-name problems.

## Tips

- Always start with `extendedLogging=true` while the script is still under development.
- Read the script back after upload so you know the appliance has the content you think it has.
- Test one operation at a time.
- Keep a dedicated test asset and account for repeatable debugging.
- If you change parameter defaults in the script, existing assets keep the previously stored values. Update those assets manually if you want the new defaults to take effect.
- When an operation fails, compare the failing task log with a known-good task log for the same operation.

## Next Steps

- [Operations Reference](../reference/operations.md) for the full operation list.
- [Platform Feature Flags](../concepts/feature-flags.md) for verifying derived capabilities after upload.
- [Troubleshooting](../guides/troubleshooting.md) for deeper error-resolution guidance.
- [Commands Reference](../reference/commands/index.md) for the commands available inside `Do` blocks.
