[← Guides](README.md)

# Troubleshooting

When a custom platform operation fails, start here.

For the exact PowerShell cmdlets, REST calls, and UI steps for running operations with extended logging, see [Testing and Debugging](../guides/testing-and-debugging.md).

## Quick Triage

Use this table first. It covers the failure modes people usually search for.

| Error / Symptom | Cause | Fix |
| --- | --- | --- |
| `Definition was not a valid json object` | Malformed JSON such as trailing commas, unescaped strings, or missing brackets | Validate the file with a JSON linter before upload. Common culprits are a trailing comma after the last array element and unescaped backslashes in regex patterns. |
| `LibraryNotFoundException` | Script references an import library name that does not exist | Check spelling in the `Import` array and use only available system libraries. |
| Duplicate function warnings | A function is defined more than once, for example in the script and in an imported library | Rename your function or remove the import if you are intentionally overriding it. |
| Parameter type mismatch | A reserved parameter is declared with the wrong `Type`, such as `Port` as `String` instead of `Integer` | Check [Reserved Parameters](../reference/reserved-parameters.md) and correct both the parameter name and type. |
| Operation timeout | The target system is unreachable or responding too slowly | Check network connectivity, increase the `Timeout` parameter, and verify `Address` and `Port`. |
| Task failure with no useful error | Default logging is too sparse to show where the script failed | Re-run the same operation with `?extendedLogging=true` or PowerShell `-ExtendedLogging` so the task log includes command-by-command detail. |
| Feature flags not appearing after upload | The script is missing the required operation and parameter combination for that flag | See [Feature Flags](../concepts/feature-flags.md) for the exact operation and reserved parameter each flag requires. |
| `Function not found` at runtime | A call references a function that is not defined in the script or any imported library | Check the function name spelling and verify the required import library is listed. |
| Connection refused or timeout on `Connect` | Wrong port, firewall policy, or target service is not running | Verify the `Port` parameter, confirm network reachability, and make sure the target service is listening. |
| Password change succeeds but `CheckPassword` fails | The new password was not actually applied on the target | Review the `ChangePassword` logic and verify the password-change command returned a successful exit status. |
| Script works in test but fails in production | Production uses different network paths, credentials, or parameter defaults | Compare the parameter values and connection path used by the test asset and the production asset. |
| `If you upload a new version with different defaults, existing asset defaults are NOT changed` | Existing assets keep the defaults they already stored when they were created or last edited | After changing defaults in the script, manually update existing assets or recreate them so they pick up the new defaults. |

## Debugging Workflow

1. **Enable extended logging.**
   Use the same operation that is failing, but run it with extended logging enabled. See [Testing and Debugging](../guides/testing-and-debugging.md) for the full workflow.

   ```powershell
   Test-SafeguardAsset "Test Target" -ExtendedLogging
   Test-SafeguardAssetAccountPassword "Test Target" "testuser" -ExtendedLogging
   ```

2. **Trigger the failing operation.**
   Reproduce the exact failure on a test asset or account so the log captures the real command path.

3. **Read the task log.**
   Pull the task log immediately after the failure.

   ```powershell
   Get-SafeguardTaskLog
   Get-SafeguardTaskLog "<taskId>" -LogName Operation
   ```

4. **Find the failing command in the log.**
   Look for the last command that started successfully and the first error, timeout, or unexpected response that follows it.

5. **Check the error message and variable state.**
   Confirm which values were passed into the failing command, especially non-secret values such as `Address`, `Port`, `UseSsl`, operation-specific paths, and parsed response fields.

6. **Fix the script and re-upload.**
   Validate the JSON again, upload the revised script, and repeat the same test.

   ```powershell
   Test-SafeguardCustomPlatformScript ".\MyScript.json"
   Import-SafeguardCustomPlatformScript "My Custom Platform" -ScriptFile ".\MyScript.json"
   ```

## Reading Extended Logs

Extended logs are easiest to read when you treat them as a timeline.

- **Task header and context**
  - Confirms which operation ran and which asset or account was in scope.
  - Helps you verify that you reproduced the correct failure.

- **Status and script log messages**
  - `Status` entries show where the task thinks it is in the workflow.
  - `Log` entries are the script's own diagnostic messages.
  - Use them to narrow the failure to a specific phase such as connect, authenticate, parse, or change.

- **Command trace**
  - Shows the commands the script engine executed in order.
  - This is where you usually spot the failing `Connect`, `Request`, `ExecuteCommand`, `Function`, or `Condition` branch.
  - See the [Commands Reference](../reference/commands/index.md) if you need a refresher on what a command is supposed to do.

- **Command result or exception**
  - This is where timeouts, connection failures, parse errors, and thrown errors usually appear.
  - Focus on the first real error, not the cascade of follow-on failures after it.

### How to identify which command failed

1. Find the first explicit error or timeout in the log.
2. Scroll upward to the most recent command trace entry before that error.
3. Treat that command as the primary suspect.
4. Then verify whether the inputs to that command were correct.

A failed `Connect` usually points to connectivity, SSH host-key, TLS, or credential setup. A failed `Request` usually points to URL, auth, proxy, or response-format problems. A failed `ExecuteCommand` usually points to shell syntax, privilege level, prompt handling, or command exit status.

### How to see variable values at each step

Extended logging often shows resolved command inputs. Use that to confirm whether placeholders such as `%Address%`, `%Port%`, or `%UseSsl%` expanded to the values you expected.

When the built-in trace is still not enough, add temporary `Log` commands around the suspect area and print only non-secret values.

```json
{ "Log": { "Text": "Address=%Address%, Port=%Port%, AccountUserName=%AccountUserName%" } }
```

Do not log secrets such as passwords, private keys, or tokens.

## Common Patterns

### Validate JSON before upload

Do not wait for upload to tell you the file is malformed.

```powershell
jq empty .\MyScript.json
Get-Content .\MyScript.json -Raw | ConvertFrom-Json | Out-Null
```

If either command fails, fix the JSON before you test anything else.

### Test connectivity outside the script

Before blaming the script, verify that the target is reachable from the same network path and on the same port.

```powershell
ssh -p 22 admin@example-host
Invoke-WebRequest https://example-host:443/health
```

If these fail, fix connectivity first. The script cannot recover from a blocked port, bad DNS, or a stopped service.

### Check reserved parameter auto-population

If a script behaves as if values are missing, verify that you used the exact reserved parameter names and types documented in [Reserved Parameters](../reference/reserved-parameters.md). Then confirm the expected values actually exist on the asset, account, or profile.

Good examples to verify are `Address`, `Port`, `Timeout`, `AccountUserName`, `FuncUserName`, and `UseSsl`. If a built-in field or workflow is missing, compare the script against [Feature Flags](../concepts/feature-flags.md) and [Operations Reference](../reference/operations.md).

## Getting Help

- Browse the [SafeguardCustomPlatform repository](https://github.com/OneIdentity/SafeguardCustomPlatform) for sample scripts and existing documentation.
- Ask questions in the [One Identity Community forums](https://www.oneidentity.com/community/).
- Keep these references open while debugging:
  - [Testing and Debugging](../guides/testing-and-debugging.md)
  - [Reserved Parameters](../reference/reserved-parameters.md)
  - [Feature Flags](../concepts/feature-flags.md)
  - [Operations Reference](../reference/operations.md)
  - [Commands Reference](../reference/commands/index.md)
