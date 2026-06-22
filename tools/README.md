# tools/

Tooling for the SafeguardCustomPlatform repo.

| Script | Purpose | Audience |
|---|---|---|
| `TestTool.ps1` | Original human-facing upload + trigger script. Edit-in-place script with hard-coded variables. | Humans |
| `Build-SamplesIndex.ps1` | Regenerates `docs/agent-reference/samples-index.md` from `samples/` and `templates/`. | CI + agents |
| `Test-AgentLinks.ps1` | Validates relative links in `AGENTS.md` and `.agents/skills/*/SKILL.md` against `docs/agent-reference/`. | CI |
| `Invoke-PlatformDevLoop.ps1` | Structured dev-loop wrapper: validate → import → trigger → fetch task log. JSON output, phase-indexed exit codes. | Agents (the `safeguard-ps-operations` skill) and humans |

The remainder of this document covers `Invoke-PlatformDevLoop.ps1`.

---

## Invoke-PlatformDevLoop.ps1

Wraps the iterative custom-platform dev loop into a single call. Always emits
one JSON document on stdout describing each phase, and exits with a
phase-indexed exit code. Designed to be cited line-for-line by the
`safeguard-ps-operations` agent skill.

### Modes

Selected by mutually-exclusive switches. Specifying more than one is a
programmer error and throws.

| Mode | Switch | What runs | Appliance contact |
|---|---|---|---|
| **SchemaOnly** | `-SchemaOnly` | local `Test-Json` against `schema/custom-platform-script.schema.json` | none |
| **ValidateOnly** | `-ValidateOnly` | schema + `Test-SafeguardCustomPlatformScript` | yes (no writes) |
| **NoTrigger** | `-NoTrigger` | schema + `Test-…` + `Import-SafeguardCustomPlatformScript` | yes (writes platform script) |
| **FullLoop** | _(default)_ | schema + `Test-…` + `Import-…` + trigger + fetch task log | yes (writes platform script + runs trigger) |

### Parameters

| Parameter | Required for | Notes |
|---|---|---|
| `-ScriptFile` | every mode | Path to the custom-platform JSON. |
| `-PlatformToEdit` | NoTrigger, FullLoop | Custom platform name or numeric ID to import the script into. |
| `-Operation` | FullLoop | `CheckPassword` (uses `Test-SafeguardAssetAccountPassword`) or `ChangePassword` (uses `Invoke-SafeguardAssetAccountPasswordChange`). Both pass `-ExtendedLogging`. |
| `-AccountToUse` | FullLoop | Account name or ID. Pass-through to the trigger cmdlet. |
| `-AssetToUse` | optional | Asset disambiguator. Pass-through. |
| `-AssetPartition` / `-AssetPartitionId` | optional | Asset-partition disambiguators. Pass-through. |
| `-SchemaFile` | optional | Override JSON Schema path. Defaults to `<repo>/schema/custom-platform-script.schema.json` relative to this script. |
| `-Appliance`, `-AccessToken`, `-Insecure` | optional | Pass-through to safeguard-ps cmdlets. Usually you connect once via `Connect-Safeguard -DeviceCode` (or `-Browser`) and let the cached `$Global:SafeguardSession` carry through. |

### Authentication

`Invoke-PlatformDevLoop.ps1` does **not** call `Connect-Safeguard` itself.
Connect once before invoking, preferring `-DeviceCode` (PKCE; prints a
verification URL and short code rather than launching a local browser),
falling back to `-Browser` if the appliance does not have the Device Code
grant enabled:

```powershell
Connect-Safeguard -Appliance <host> -Insecure -DeviceCode
```

If you bypass the cached session by passing `-AccessToken`, that token is
forwarded to every safeguard-ps cmdlet the script calls.

### Output JSON shape

One JSON document on stdout per invocation. Verbose progress (the
`[validate] …`, `[import] …`, `[trigger] …`, `[log] …` lines) goes to
stderr so stdout stays parseable. Top-level shape:

```jsonc
{
  "mode": "SchemaOnly|ValidateOnly|NoTrigger|FullLoop",
  "scriptFile": "<absolute path>",
  "schemaFile": "<absolute path>",
  "platform":   "<name or null>",
  "operation":  "CheckPassword|ChangePassword|null",
  "account":    "<name or null>",
  "phases":     [ <validatePhase>, <importPhase>, <triggerPhase>, <logPhase> ],
  "exitCode":   <int>,
  "startedAt":  "<ISO8601 UTC>",
  "endedAt":    "<ISO8601 UTC>"
}
```

Every phase has the same skeleton:

```jsonc
{
  "name":       "validate|import|trigger|log",
  "status":     "success|failed|skipped",
  "durationMs": <int>,
  "error":      "<message>" | null,
  "data":       <phase-specific payload> | null
}
```

#### `phases[0]` (validate) `data`

* SchemaOnly: `{ "schemaOnly": true }`.
* ValidateOnly / NoTrigger / FullLoop: the platform-preview object returned
  by `Test-SafeguardCustomPlatformScript`. Notable fields include
  `SupportedOperations` (array of operation names), `ConnectionProperties`
  (boolean capability flags), `PasswordFeatureProperties`,
  `CustomScriptProperties.Parameters` (flat list of `{Name, DefaultValue,
  Type, TaskName}`).

  Excerpt from a real run against `samples/ssh/generic-linux/GenericLinux.json`:

  ```jsonc
  {
    "Id": 0,
    "PlatformType": "Custom",
    "Name": "ExampleLinuxScript",
    "SupportedOperations": [
      "TestConnection", "CheckPassword", "ChangePassword", "DiscoverSshHostKey"
    ],
    "CustomScriptProperties": {
      "HasScript": true,
      "Parameters": [
        { "Name": "Port", "DefaultValue": "22", "Type": "Integer", "TaskName": "TestConnection" },
        { "Name": "FuncUserName", "DefaultValue": "", "Type": "String", "TaskName": "TestConnection" },
        // ...
      ]
    }
  }
  ```

#### `phases[1]` (import) `data`

The updated custom-platform object as returned by
`Import-SafeguardCustomPlatformScript` (which internally re-reads the
platform after the PUT). Same shape as the validate preview but with
real `Id` and the platform's configured display name.

Failure example (real output, exit 2):

```jsonc
{
  "name": "import",
  "status": "failed",
  "durationMs": 38,
  "error": "Unable to find custom platform matching 'NoSuchPlatform_DevLoopTest_123'",
  "data": null
}
```

#### `phases[2]` (trigger) `data`

```jsonc
{
  "taskId":            "<GUID>",      // extracted from the Information stream
  "outputText":        "<multi-line success summary>",
  "informationStream": [ "<each Write-Host line>" ]
}
```

The **task GUID is not on the cmdlet's return value.** safeguard-ps's
`Wait-LongRunningTask` emits the line
`See extended logs: Get-SafeguardTaskLog <GUID>` via `Write-Host`
(Information stream, 6). The script captures that stream with
`-InformationVariable` and regex-matches `Get-SafeguardTaskLog\s+<GUID>` to
extract the ID. The cmdlet's return value (`outputText`) is the
human-readable status summary — useful for display, but not parseable.

Real success excerpt (CheckPassword against an Ubuntu 24.04 asset):

```text
Task completed successfully.
 6/2/2026 11:55:35 PM       Queued       Queuing task.
 6/2/2026 11:55:35 PM       Running      Starting task.
 6/2/2026 11:55:35 PM       Checking     Verifying Password.
 6/2/2026 11:55:35 PM       Connecting   Connecting with asset ubtu2404-1.dan.test (...)
 ...
 6/2/2026 11:55:38 PM       Finalizing   The password for account root matches the password on the asset.
 6/2/2026 11:55:38 PM       Success      Task completed successfully.
```

On task **failure**, safeguard-ps throws `Ex.SafeguardLongRunningTaskException`
(constructed by `New-LongRunningTaskException`) which carries a typed
`TaskLog` array. The dev-loop
script catches that, surfaces `error = exception message`, and adds a
`taskLog` field with the structured entries.

Real failure-path output (CheckPassword against an account whose stored
password was deliberately wrong):

```jsonc
{
  "name":       "trigger",
  "status":     "failed",
  "durationMs": 4590,
  "error":      "The current account password does not match the password on the asset.",
  "data": {
    "taskId":            "3e5c7705-5eea-11f1-bfb2-df700470d6bc",
    "informationStream": [
      " 6/3/2026 1:19:18 AM        Queued       Queuing task.",
      " 6/3/2026 1:19:19 AM        Connecting   Connecting with asset ubtu2404-1.dan.test (...)",
      " 6/3/2026 1:19:21 AM        PasswordMismatch The password for account root does not match the password on the asset.",
      " 6/3/2026 1:19:21 AM        PasswordMismatch The current account password does not match the password on the asset.",
      "See extended logs: Get-SafeguardTaskLog 3e5c7705-5eea-11f1-bfb2-df700470d6bc"
    ],
    "taskLog": [
      { "Timestamp": "6/3/2026 1:19:18 AM", "Status": "Queued",           "Message": "Queuing task." },
      { "Timestamp": "6/3/2026 1:19:19 AM", "Status": "Connecting",       "Message": "Connecting with asset ubtu2404-1.dan.test (...)" },
      { "Timestamp": "6/3/2026 1:19:21 AM", "Status": "PasswordMismatch", "Message": "The password for account root does not match the password on the asset." },
      { "Timestamp": "6/3/2026 1:19:21 AM", "Status": "PasswordMismatch", "Message": "The current account password does not match the password on the asset." }
    ]
  }
}
```

The `taskLog` element shape is fixed: `{ Timestamp, Status, Message }`,
defined by
`PangaeaAppliance\src\Data\Transfer\V2\PlatformTasks\TaskLog.cs`. `Status`
is an enum (`PangaeaAppliance\src\Data\Transfer\V2\PlatformTasks\TaskStatus.cs`)
with 25 stable values including `Queued`, `Running`, `Checking`,
`Connecting`, `Changing`, `Saving`, `Finalizing`, `Success`, `Failure`,
`Cancelled`, `Skipped`, `PasswordMismatch`, `SshHostKeyMismatch`,
`SshKeyMismatch`, `ApiKeyMismatch`, `FileMismatch`, `Discovering`,
`Submitted`, and assorted `Service*`/`Task*` outcomes. The first
mismatch-class entry typically pins the failure to a specific
account/asset; the last entry is the summary message that is also
surfaced as the phase `error`.

#### `phases[3]` (log) `data`

```jsonc
{
  "taskId": "<GUID>",
  "log":    [ <log entry>, <log entry>, ... ]
}
```

`log` is the array returned by `Get-SafeguardTaskLog -TaskId <GUID>`. Each
entry has shape `{Recorded, Level, Event}`. The appliance exposes named
logs via two endpoints (`GET /Core/v4/TaskLogs/{taskId}` lists the available
log names; `GET /Core/v4/TaskLogs/{taskId}/{logName}` returns the events
for that named log). When `Get-SafeguardTaskLog` is called without a
`-LogName`, safeguard-ps's `Get-SafeguardTaskLog` iterates the listed
logs and emits a synthetic separator entry between each:

```jsonc
{ "Recorded": "", "Level": "", "Event": "--- <logName> ---" }
```

The two log names produced by SPP for platform tasks are stable string
constants:

* `Operation` — high-level platform-script execution log
* `SshCommunication` — raw SSH transport-level frames (when applicable)

Both are defined in
`PangaeaAppliance\src\Common\Common.Rsms\Rsms.Public\Constants\Logging.cs:14-15`
(see [`docs/agent-reference/rsms-engine-map.md`](../docs/agent-reference/rsms-engine-map.md)
for the full cross-repo contract map — these constants moved out of the old
`Hercules\Source\Rsms.Public\…` path).

Real entry shapes:

```jsonc
// Section header (synthesised by safeguard-ps, not the appliance)
{ "Recorded": "", "Level": "", "Event": "--- Operation ---" }
// Operation entry
{ "Recorded": "2026-06-02T23:55:35.4880454Z",
  "Level":    "Information",
  "Event":    "Initializing CheckPassword platform task 8c1e2bd4-…\r\n" }
// SshCommunication entry
{ "Recorded": "2026-06-02T23:55:36.6461523Z",
  "Level":    "Debug",
  "Event":    "Send : grep -q '^root:' /etc/passwd; echo \"CHECKUSER=$?\"\r\n" }
```

**Secret handling.** SPP server-side redacts known credential parameters as
the literal string `**secret**` before returning the log. The redaction
constant is defined in
`PangaeaAppliance\src\Platform\Platform.Rsms\Constants\ParameterConstants.cs:5`
(`public const string Secret = "**secret**"`; moved out of the old
`Hercules\Source\Hercules.DevKit\…` path — see
[`docs/agent-reference/rsms-engine-map.md`](../docs/agent-reference/rsms-engine-map.md)).
Agents should NOT attempt to recover real values from these markers.
Custom-script authors who introduce new secret parameters should declare
them with `Type: "Secret"` so SPP applies the same redaction.

The log fetch is best-effort even when the trigger fails: if the trigger
phase fails (status = failed, exit 3) **and** a task GUID was extracted,
the log phase still runs to capture the extended log. The exit code
remains 3 (the trigger failure), not 4.

#### Exit-4 error shape

`Get-SafeguardTaskLog` raises a terminating error when the task ID is not
recognised by the appliance:

```
OperationStopped: 404: Not Found -- 0: <no content in response>
```

The script catches that, sets `phases[3].status = "failed"` with that
message in `phases[3].error`, and exits 4. The same error path covers
the case where the trigger ran without `-ExtendedLogging`: in that mode
safeguard-ps's `Wait-LongRunningTask` only emits the
`See extended logs: <GUID>` Information-stream line when extended logging
is on, so the dev-loop script always passes
`-ExtendedLogging` to the trigger cmdlet — making this exit code primarily
a guard against transient appliance issues (revoked session, log-archive
churn) rather than a normal authoring failure.

### Exit-code contract

The script exits with the **index of the first failed phase**, or 0 on
full success. A skipped phase does not affect the exit code.

| Exit | Meaning | Verified |
|---|---|---|
| 0 | All non-skipped phases succeeded. | ✓ live (SchemaOnly, ValidateOnly, NoTrigger, FullLoop) |
| 1 | Validate phase failed (local schema OR appliance `Test-SafeguardCustomPlatformScript`). | ✓ live (local schema reject) |
| 2 | Import phase failed. | ✓ live (`Unable to find custom platform matching '<name>'`) |
| 3 | Trigger phase failed. | ✓ live (`PasswordMismatch` against ubtu2404-1.dan.test) |
| 4 | Log fetch phase failed. | ✓ via cmdlet probe (see below) |

The script emits its JSON on stdout **even on phase failure** so callers
can read structured details. The script throws (no JSON, non-zero PS exit
code) only on programmer error:

* mutually-exclusive mode switches both set
* `-ScriptFile` not readable
* `-SchemaFile` not found
* mode requires appliance contact and there is no `Connect-Safeguard`
  session and no `-AccessToken`
* mode requires `-PlatformToEdit`, `-Operation`, or `-AccountToUse` and
  the parameter is missing

### Examples (verified real output)

```powershell
# 1. Local schema check only — no appliance.
.\tools\Invoke-PlatformDevLoop.ps1 `
    -ScriptFile .\samples\ssh\generic-linux\GenericLinux.json `
    -SchemaOnly
# Exit 0; phases[0].status = success; phases 1..3 skipped.

# 2. Appliance dry-run (validate only).
Connect-Safeguard -Appliance 192.168.117.15 -Insecure -DeviceCode
.\tools\Invoke-PlatformDevLoop.ps1 `
    -ScriptFile .\samples\ssh\generic-linux\GenericLinux.json `
    -ValidateOnly -Insecure
# Exit 0; phases[0].data carries the full platform preview.

# 3. Validate + import, no trigger.
.\tools\Invoke-PlatformDevLoop.ps1 `
    -ScriptFile .\samples\ssh\generic-linux\GenericLinux.json `
    -PlatformToEdit "DELETELINUX" -NoTrigger -Insecure
# Exit 0; phases[1].data carries the updated platform object.

# 4. Full loop: CheckPassword with extended logging.
.\tools\Invoke-PlatformDevLoop.ps1 `
    -ScriptFile .\samples\ssh\generic-linux\GenericLinux.json `
    -PlatformToEdit "DELETELINUX" `
    -Operation CheckPassword -AccountToUse 10 -Insecure
# Exit 0; ~5s end-to-end against an SSH target;
# phases[2].data.taskId == phases[3].data.taskId; phases[3].data.log
# contains both SshCommunication and Operation sections.

# 5. Failure example: import into a non-existent platform.
.\tools\Invoke-PlatformDevLoop.ps1 `
    -ScriptFile .\samples\ssh\generic-linux\GenericLinux.json `
    -PlatformToEdit "NoSuchPlatform_DevLoopTest_123" -NoTrigger -Insecure
# Exit 2; phases[0]=success, phases[1]=failed
#   error: "Unable to find custom platform matching 'NoSuchPlatform_DevLoopTest_123'"

# 6. Failure example: CheckPassword with a wrong stored credential.
.\tools\Invoke-PlatformDevLoop.ps1 `
    -ScriptFile .\samples\ssh\generic-linux\GenericLinux.json `
    -PlatformToEdit "DELETELINUX" `
    -Operation CheckPassword -AccountToUse 10 -Insecure
# Exit 3; phases 0..1 = success, phase 2 (trigger) = failed with structured
# taskLog, phase 3 (log) = success (best-effort fetch still ran because
# the taskId was extractable from the Information stream).
```

### Versions verified

* PowerShell 7.6.2
* `safeguard-ps` 8.4.3 (minimum — enforced at script start; earlier versions lack `-ExtendedLogging` on `Invoke-SafeguardAssetSshHostKeyDiscovery`)
* SPP appliance reachable at the time of authoring.

### Cmdlet citations

Cmdlets the script calls. Syntax sourced from `Get-Help <Cmdlet> -Full`
against the installed module — not paraphrased from memory:

* `Test-Json` (`Microsoft.PowerShell.Utility`, PS 7+) — local schema check
* `Test-SafeguardCustomPlatformScript` — POSTs the script to `Core/Platforms/ValidateScript/Raw`; returns the platform-preview object the script would produce
* `Import-SafeguardCustomPlatformScript` — PUTs the script to `Core/Platforms/{Id}/Script/Raw`, then re-reads the platform via `Get-SafeguardCustomPlatform` and returns it
* `Test-SafeguardAssetAccountPassword` — CheckPassword trigger (calls `POST Core/v4/AssetAccounts/{id}/CheckPassword?extendedLogging=true`; appliance handler `AssetAccountsController_Tasks.cs::CheckPasswordAsync`)
* `Invoke-SafeguardAssetAccountPasswordChange` — ChangePassword trigger (calls `POST Core/v4/AssetAccounts/{id}/ChangePassword?extendedLogging=true`; appliance handler `AssetAccountsController_Tasks.cs::ChangePasswordAsync`)
* `Get-SafeguardTaskLog` — when no `-LogName` is given, calls `GET Core/TaskLogs/{taskId}` to list available logs, then iterates each via `GET Core/TaskLogs/{taskId}/{logName}`; emits a synthetic `--- <logName> ---` separator entry between sections

The trigger cmdlets call `Invoke-SafeguardMethod -LongRunningTask` under
the hood, which polls until `RequestStatus.PercentComplete == 100` and
emits the extended-log hint via `Write-Host` from `Wait-LongRunningTask`.
