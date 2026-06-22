---
name: safeguard-ps-operations
description: >-
  Use when the agent must drive a live SPP appliance through safeguard-ps
  to validate, import, trigger, and inspect a custom platform script.
  Covers Connect-Safeguard -DeviceCode (preferred) / -Browser (fallback)
  auth, the cmdlet menu (Test- / Import- / Export- / asset / account /
  trigger), idempotency, extended-logging triggers, task-log JSON
  retrieval, and how to call tools/Invoke-PlatformDevLoop.ps1 instead of
  re-implementing the loop. All cmdlet syntax must be sourced from
  Get-Help <Cmdlet> -Full against the installed module, never paraphrased
  from memory.
---

# safeguard-ps-operations

## Pre-flight

Before invoking any cmdlet covered by this skill, consult [`AGENTS.md`](../../../AGENTS.md) for the active workflow algorithm (new-platform vs enhance-platform) and the iterative debug-loop budget. Single-skill entry points (e.g., "just import this script") still run inside one of those workflows; do not bypass the orchestration layer.

## Scope

This skill is the `safeguard-ps` wrapper. It owns:

- Authenticating to a Safeguard for Privileged Passwords (SPP) appliance.
- Validating, importing, and exporting custom platform scripts.
- Creating or updating the asset and account used for testing.
- Triggering operations (`CheckPassword`, `ChangePassword`, …) with extended logging.
- Fetching the resulting task-log JSON for [`task-log-analysis`](../task-log-analysis/SKILL.md).

It is the **only** skill that directly calls `safeguard-ps`. Other skills request operations through this one.

## Modes

- **full-loop** — every operation in this skill is in scope.
- **author-only** — only `Test-SafeguardCustomPlatformScript` and `Export-SafeguardCustomPlatformScript` (when applied to a local file via `-OutFile`) are usable; everything else requires an appliance and **fails closed** with a clear message.
- **probe-only** — fails closed. Use [`target-probing`](../target-probing/SKILL.md) instead.

## Grounding rule (mandatory)

Every cmdlet, parameter name, and parameter-set described to the operator MUST come from `Get-Help <Cmdlet> -Full` against the **installed** `safeguard-ps` module. Do not paraphrase from memory, vendor docs, or prior conversations.

Before invoking any cmdlet you have not used in the current session, the agent runs `Get-Help` itself — do not ask the operator to run it and paste output back:

```powershell
Get-Help <Cmdlet> -Full | Out-String -Width 200
```

`Out-String -Width 200` matters: in narrow shells the parameter table wraps and `Required?` / `Position?` columns shift, making it easy to misread a switch as a valued parameter. Pin the width.

If a cmdlet's parameter is a `[switch]` and the value comes from a variable, use the colon form (`-Insecure:$ins`, not `-Insecure $ins`). PowerShell silently swallows the latter on switches and the cmdlet ends up with the parameter's default — usually `$false` — which is rarely what the agent wanted. The value bound to the colon must be a `[bool]`.

Sibling cmdlets are not symmetric. `Test-` and `Invoke-` pairs diverge in parameter names; `New-SafeguardCustomPlatform` accepts `-ScriptFile` directly with no separate `Import-` step; `Get-SafeguardTaskLog` with no arguments returns a flat GUID array and only returns `{Recorded, Level, Event}` records when given `-TaskId <guid>`. Run `Get-Help` on every cmdlet's first use in the session, even when a sibling was just used.

## Authentication

### PowerShell version: prefer 7+, warn and continue otherwise

safeguard-ps targets PS 7. Several cmdlets behave better there (cleaner error records, no Windows-PowerShell-only quirks). Before calling any cmdlet:

```powershell
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Running on PowerShell $($PSVersionTable.PSVersion). PowerShell 7+ is recommended for safeguard-ps; continuing anyway."
}
```

Do not block on the version. If only PS 5.1 is available, the agent emits the warning once and proceeds.

### Module presence: check, don't ask

Before invoking any cmdlet, verify `safeguard-ps` is installed **and at least version 8.4.3**:

```powershell
Get-Module -ListAvailable -Name safeguard-ps |
  Sort-Object Version -Descending |
  Select-Object -First 1 -ExpandProperty Version
```

8.4.3 is the floor because earlier versions lack `-ExtendedLogging` on `Invoke-SafeguardAssetSshHostKeyDiscovery` — without it, host-key-discovery failures emit only the surface 60307 error and persist no task log, leaving the agent with nothing to diagnose. `tools/Invoke-PlatformDevLoop.ps1` enforces this floor at startup and refuses to run against older modules.

If the module is missing or below 8.4.3, ask the operator **once** for permission to install or upgrade:

```powershell
Install-Module -Name safeguard-ps -Scope CurrentUser -Force
```

Latest stable from PowerShell Gallery is the default. Do not ask "is `safeguard-ps` available" or "which version do you have" first — check, then proceed or ask once.

### Connect: prefer `-DeviceCode`, fall back to `-Browser`, then `-Insecure` on TLS error

Connect with PKCE only — no password-in-script recipes; no `-Username`/`-Password` parameters in agent flows. Prefer **`-DeviceCode`**: it prints a verification URL and short code instead of launching a local browser, which is the lower-friction default for terminal sessions and works in headless / SSH / CI contexts. Fall back to `-Browser` only if the appliance does not have the Device Code grant enabled (firmware < 7.4 or grant disabled in Appliance Management):

```powershell
Connect-Safeguard -Appliance <host> -DeviceCode
# or, if Device Code is not enabled on this appliance:
Connect-Safeguard -Appliance <host> -Browser
```

The verification URL and short code only appear on the cmdlet's stdout and the code expires in minutes. The agent must surface both to the operator when calling `Connect-Safeguard -DeviceCode` — the operator cannot complete the login otherwise.

Both forms block until the PKCE callback completes; await the cmdlet's own success/failure rather than asking the operator "are you logged in yet?". On a TLS/cert error (self-signed cert, mismatched CN — common on lab appliances), ask **once** for permission to retry with `-Insecure`:

```powershell
Connect-Safeguard -Appliance <host> -Insecure -DeviceCode
```

Do not pre-ask whether the appliance has a valid certificate. Try secure; the error message tells both the operator and the agent unambiguously when `-Insecure` is needed.

**Omit `-IdentityProvider` by default.** `Connect-Safeguard` with no `-IdentityProvider` lets the appliance discover the user's provider from their username at PKCE time, which works for local, certificate, and every external provider (AD, LDAP, OIDC, SAML) the appliance has configured. Hardcoding `-IdentityProvider local` breaks login for any user not in the local IdP, which is the common case in production. Pass `-IdentityProvider` only when the operator has explicitly named the provider, or when a prior login failed with a provider-mismatch error.

### Persist the session across iterations — serialize the token, never keep a long-running shell

**Login budget = 1 per session.** Each `Connect-Safeguard -DeviceCode` (or `-Browser`) costs the operator real time and attention. Connect exactly once.

**Long-running interactive PowerShell sessions are banned in agent flows.** They wedge on PSReadLine prediction, swallow `$ConfirmPreference` prompts, return stale back-buffer through `read_powershell`, and routinely cost a re-login when the agent has to kill them. Do not start a persistent shell to hold `$Global:SafeguardSession`. Do not invoke `Connect-Safeguard` as an async command kept alive across iterations.

The only correct shape is short-lived sync `powershell -Command { ... }` calls. `$Global:SafeguardSession` holds **a short-lived bearer token, not a permanent credential** — valid for the rest of the session (typically several hours), safe to serialize to the gitignored per-session state directory, expires on its own.

**Step 1 — connect once and serialize, in the same process.** The connect call and the serialization step **must run in the same PowerShell process**: `$Global:SafeguardSession` dies with the process that called `Connect-Safeguard`, so a "connect in shell A, serialize in shell B" split silently throws the token away and burns a login.

Do **not** pipe the cmdlet to `Out-Null` — the verification URL and short code are printed on its host stream as it waits for the device-code callback, and `Out-Null` (or any output redirection that suppresses host writes) hides them from the operator. The cmdlet's return value is the session object, which the agent does not need because `$Global:SafeguardSession` is the durable artifact.

`Out-Null` is the *first* trap; sync stdout buffering is the *second*. In any agent runtime that captures a sync shell's stdout and delivers it only after the command returns — every `powershell` tool call in this CLI works this way, and CI runners and `Tee-Object`-to-file behave similarly — the verification block sits in the buffer until the cmdlet completes, which is after the operator has already missed the 300-second window. "Let stdout pass through" is *not* enough on its own. Run the connect + serialize sequence as one short-lived **async** invocation and read its stream as the device-code block lands, then echo the URL, the code, and the 300-second expiry to the operator the moment they appear.

```
Connect-Safeguard -Appliance <host> -Insecure -DeviceCode
$Global:SafeguardSession |
  ConvertTo-Json -Depth 5 |
  Set-Content "$env:USERPROFILE\.copilot\session-state\<id>\files\sg-session.json" -Encoding utf8
```

If `Connect-Safeguard` is called on its own without the serialize step in the same process, the token is lost and the next cmdlet call will prompt for `-Appliance`, hanging the agent and forcing a second login. That is a defect (see "Why explicit threading…" below), not a recoverable state.

**Step 2 — every subsequent cmdlet is its own fresh sync call.** Re-hydrate the saved session, normalize `Insecure` to a `[bool]` once, then thread `Appliance`, `AccessToken`, and the bool through every call:

```
$s = Get-Content "<session-state>\sg-session.json" | ConvertFrom-Json
$ins = [bool]$s.Insecure.IsPresent   # required: $s.Insecure does not bind to -Insecure directly after JSON roundtrip
Get-SafeguardCustomPlatform -Appliance $s.Appliance -Insecure:$ins -AccessToken $s.AccessToken <name>
Invoke-SafeguardAssetAccountPasswordChange -Appliance $s.Appliance -Insecure:$ins -AccessToken $s.AccessToken `
  -AssetToUse <id> -AccountToUse <id> -ExtendedLogging
Get-SafeguardTaskLog -Appliance $s.Appliance -Insecure:$ins -AccessToken $s.AccessToken -TaskId <guid>
```

Every safeguard-ps cmdlet that takes `-Appliance` also accepts `-AccessToken`. Threading those three through every call eliminates the dependency on `$Global:SafeguardSession` entirely — output returns cleanly via stdout, no PSReadLine wedging, no confirmation prompts swallowing inputs. Pulling `Insecure` from the session (rather than hardcoding `-Insecure`) keeps the agent honest: if the operator connected with a valid cert, the saved value is `$false` and every call validates.

#### Why explicit threading and not "just re-hydrate the session global"

Two superficially-simpler shortcuts do **not** work. Documented here so the next agent does not re-discover them the hard way:

- **`Connect-Safeguard` has no parameter set that accepts an existing access token.** `Get-Help Connect-Safeguard -Full` lists seven parameter sets (Resource Owner, Credential, PKCE, Browser, Certificate, Gui, DeviceCode); every one performs a fresh login. `-NoSessionVariable` is the inverse direction (return the token instead of caching it); it does not consume one.
- **Assigning to `$Global:SafeguardSession` directly does not re-hydrate the session.** Writing `$Global:SafeguardSession = Get-Content sg-session.json | ConvertFrom-Json` populates the global with the right shape, but cmdlets that use the session variable still emit `No current Safeguard login session.` and prompt for `-Appliance`, hanging non-interactive runs. The cmdlets evidently consult a module-private variable that only `Connect-Safeguard` itself can set.

If a future cmdlet is found that **only** reads the session variable and refuses `-AccessToken`, the correct response is to file a defect against safeguard-ps to add the parameter set — not to spin up a long-running shell to host the cmdlet.

Treat `sg-session.json` like any other secret: write it only under the per-session state directory, never commit it, never paste it into chat or task-log output. Delete it at the end of the session. The bearer token redacts itself naturally on expiry; a stale file cannot be used to attack the appliance later. Never log `$Global:SafeguardSession`, the access token, or any password parameter to operator-visible output.

If the agent finds itself about to call `Connect-Safeguard` a second time in the same session, **stop**. The token in `sg-session.json` is still good unless the operator rebooted the appliance or several hours have passed; re-read it. A second login is a defect, not a workaround.

This pattern is verified in [`tools/README.md`](../../../tools/README.md) ("Authentication" section). `tools/Invoke-PlatformDevLoop.ps1` itself does not call `Connect-Safeguard`; the operator connects once and the wrapper picks up `$Global:SafeguardSession` (when invoked from a session that has it cached) or `-AccessToken` plumbed through.

## Cmdlet menu

The cmdlets this skill calls, all sourced from `Get-Help`. The shapes below are recap; consult `Get-Help` for parameter details.

| Cmdlet | Purpose | Used by |
| --- | --- | --- |
| `Connect-Safeguard -DeviceCode` (or `-Browser`) | PKCE login. Caches `$Global:SafeguardSession`. `-DeviceCode` prints a verification URL and short code; `-Browser` launches a local browser. | Skill bootstrap. |
| `Test-SafeguardCustomPlatformScript` | Server-side dry-run of a script. POSTs to `Core/Platforms/ValidateScript/Raw`; returns the platform-preview object the script would produce. | `Invoke-PlatformDevLoop.ps1` validate phase. |
| `Import-SafeguardCustomPlatformScript` | PUTs the script to `Core/Platforms/{Id}/Script/Raw`, then re-reads the platform via `Get-SafeguardCustomPlatform`. | `Invoke-PlatformDevLoop.ps1` import phase. |
| `Export-SafeguardCustomPlatformScript` | Pulls the deployed JSON back. **Source of truth for the enhance-platform workflow** — on-disk samples are starting points and may have drifted. | Manual call before authoring an enhancement. |
| `Get-SafeguardCustomPlatform` | Looks up a platform by name or ID. Used to confirm the platform exists before import. | Idempotency checks. |
| `Test-SafeguardAssetAccountPassword` | Triggers `CheckPassword` (`POST Core/v4/AssetAccounts/{id}/CheckPassword?extendedLogging=true`). | `Invoke-PlatformDevLoop.ps1` trigger phase. |
| `Invoke-SafeguardAssetAccountPasswordChange` | Triggers `ChangePassword` (`POST Core/v4/AssetAccounts/{id}/ChangePassword?extendedLogging=true`). | `Invoke-PlatformDevLoop.ps1` trigger phase. |
| `Get-SafeguardTaskLog` | Pulls the extended task log. Without `-LogName`, iterates available logs and emits a synthetic `--- <logName> ---` separator entry between sections. | `Invoke-PlatformDevLoop.ps1` log phase. |

Endpoint paths and the separator/redaction behavior are documented with appliance-source citations in [`tools/README.md`](../../../tools/README.md) ("Cmdlet citations" and `phases[3] data` sections).

Asset and account create/update cmdlets (`New-SafeguardAsset`, `Edit-SafeguardAsset`, `New-SafeguardAssetAccount`, `Edit-SafeguardAssetAccount`) are out of this skill's mandatory loop — operators usually create those once, by hand, against the test appliance. If the workflow needs them, source their syntax from `Get-Help` at use time and treat create-or-update as **idempotent**: look up first, edit if it exists, create if it does not. Do not re-create on every iteration.

### Discovery setup is a prerequisite, not a cmdlet call

A freshly-onboarded asset will reject `Invoke-SafeguardAssetAccountDiscovery` with error 60392 until an Account Discovery Schedule and Rule are wired to it. The recipe — schedule + rule + asset-attach, plus the `-DiscoveryType` ValidateSet and the `Add-SafeguardAccountDiscoveryRule` param-set trap — is in [`docs/agent-reference/failure-patterns.md`](../../../docs/agent-reference/failure-patterns.md) under *Discovery-trigger errors*. Read it before the first discovery trigger on a new platform; do not wait for 60392 to fire.

## Always trigger with extended logging

Every trigger cmdlet must pass `-ExtendedLogging`. The `See extended logs: Get-SafeguardTaskLog <GUID>` line that the dev-loop script regex-matches to extract the task ID is **only emitted when `-ExtendedLogging` is set** (see `tools/Invoke-PlatformDevLoop.ps1` lines 178–196 for the extraction logic and lines 282–298 of [`tools/README.md`](../../../tools/README.md) for the appliance-side rationale).

If the operator triggered an operation without `-ExtendedLogging`, the task ID cannot be reliably recovered; ask them to re-trigger.

## Cmdlet quirks

Cmdlet quirks observed across runs:

- **`-TaskId` requires a `[guid]` cast.** `Get-SafeguardTaskLog -TaskId "<id-string>"` rejects a bare string. Cast at the call site: `Get-SafeguardTaskLog -TaskId ([guid]$id)`.
- **Task-log GUID lists are lexicographic, not chronological.** v1 GUIDs from the appliance are not time-ordered; sorting and taking the "last" item finds the wrong task. To identify the task a trigger just produced, **diff** the GUID set before and after the trigger and pick the new entry.
- **`SshCommunication` sub-log is empty for non-script-engine paths.** Built-in operations such as host-key discovery (`Invoke-SafeguardAssetSshHostKeyDiscovery`) run through a different runtime than scripted custom-platform operations; an empty `SshCommunication` array on those tasks is normal, not a failure signal. Read the `Operation` log for those.
- **Platform Tasks are async — wait for terminal state before reading downstream data.** Every operation triggered against the appliance is a Platform Task. Some `safeguard-ps` cmdlets (`Test-SafeguardAsset`, `Test-SafeguardAssetAccountPassword`, `Invoke-SafeguardAssetAccountPasswordChange`) wrap the trigger with internal polling and appear synchronous to the caller — the returned object reflects a terminal state. Others (`Invoke-SafeguardAssetAccountDiscovery` is the canonical case) return immediately with `RequestStatus.State = "Accepted"` and `PercentComplete = 0` because only the queueing step has completed. Inspect the return value: if `RequestStatus.State` is `Accepted` or `Running`, the task is not done. Querying `Get-…` cmdlets that consume results (`Get-SafeguardDiscoveredAccount`, etc.) before that returns zero rows that look like a script failure but are just an unfinished task. Either poll `RequestStatus.State` until it is no longer `Accepted`/`Running`, or pull the task log (using the GUID-diff approach above) and confirm a `Success` / failure record before consuming downstream data.
- **Hung non-auth cmdlet = skipped `Get-Help` on a cmdlet inferred from a sibling.** A `safeguard-ps` cmdlet that produces no output and never returns is almost always interactively prompting for a required parameter the agent did not supply — because the agent inferred parameter names from a sibling cmdlet instead of running `Get-Help`. Example: calling `Test-SafeguardAssetAccountPassword -AssetToTest <id>` when the real parameter is `-AssetToUse`, inferred from `Invoke-SafeguardAssetAccountPasswordChange`. Kill the call, run `Get-Help <Cmdlet> -Full | Out-String -Width 200`, fix the invocation. The grounding rule above is not optional for cmdlets that "look like" ones the agent just used. `Connect-Safeguard -DeviceCode` is the one explicit exception — it blocks by design until PKCE completes.
- **Saved-session rehydrate can hit `Read-Host` in non-interactive PS.** When restoring `$Global:SafeguardSession` from a serialized token, several cmdlets prompt for missing fields and hang. Fall back to direct API: `Invoke-WebRequest` with `Authorization: Bearer <token>`. Long-running endpoints return 202 with a `Location` header — poll until `RequestStatus.PercentComplete == 100`, then read `RequestStatus.State`.
- **Script re-import wipes any custom asset parameters the new script does not declare.** No separate cleanup step needed for cred-type or schema transitions.
- **Platform connection-properties flags auto-infer at script import.** `SupportsApiKeyAuthentication`, `SupportsPasswordAuthentication`, `SupportsApiKeyManagement`, etc., flip from the script's parameter usage and operation set. No manual `Edit-SafeguardCustomPlatform` flag flip needed.
- **ApiKey op triggers live below the account, not at it.** `POST Core/v4/AssetAccounts/{id}/ApiKeys/{keyId}/{Check|Change}ApiKey` — the AssetAccount-level path returns 405. One trigger per ApiKey row.

## Use `Invoke-PlatformDevLoop.ps1` instead of re-implementing the loop

The standard validate → import → trigger → log path is implemented once, in [`tools/Invoke-PlatformDevLoop.ps1`](../../../tools/Invoke-PlatformDevLoop.ps1). This skill calls that script rather than chaining cmdlets in prose.

| Sub-phase needed | Switch | Appliance contact |
| --- | --- | --- |
| Local schema check only (fast inner loop) | `-SchemaOnly` | none |
| Schema + appliance dry-run (no writes) | `-ValidateOnly` | yes |
| Schema + appliance dry-run + import (no trigger) | `-NoTrigger` | yes |
| Full loop incl. trigger and task-log fetch | _(default)_ | yes |

Output contract (one JSON document on stdout, phase-indexed exit code, programmer errors throw without JSON) is documented in [`tools/README.md`](../../../tools/README.md) ("Output JSON shape", "Exit-code contract"). The exit-code semantics are: `0` full success, `1` validate, `2` import, `3` trigger, `4` log fetch (script header lines 38–43, body block at lines 269–407).

When a hand-rolled cmdlet sequence is unavoidable (e.g., a one-off `Export-…` to capture deployed JSON), still emit progress to stderr and any structured result to stdout so callers can parse cleanly.

## Mandatory sequencing: validate before import, every time

Schema check → `Test-SafeguardCustomPlatformScript` → `Import-SafeguardCustomPlatformScript`. Always in that order. Never:

- Import a draft that has not been schema-validated locally (the fast inner loop catches malformed JSON cheaply).
- Import a draft that has not passed `Test-SafeguardCustomPlatformScript` against the appliance. The server-side dry-run catches imported-function arity errors, undeclared-variable references, and other things schema validation cannot. Skipping it leaks bad scripts onto the appliance and makes the iteration loop slower, not faster.
- "Just re-import to see if it works" after editing a draft that was last validated several edits ago.

The dev-loop wrapper enforces this sequence: `-SchemaOnly` is the schema check alone, `-ValidateOnly` runs schema + `Test-`, `-NoTrigger` runs schema + `Test-` + `Import-` (no trigger), and the default runs the full chain. Use the wrapper rather than chaining cmdlets in prose.

## Idempotency conventions

- **Platform lookups before import.** `Import-SafeguardCustomPlatformScript -PlatformToEdit <name|id>` errors with `Unable to find custom platform matching '<name>'` if the platform does not exist; the dev-loop wrapper surfaces this verbatim as the `import` phase error (see real failure example in [`tools/README.md`](../../../tools/README.md), exit-2 block). Confirm the platform exists once at the start of a session, then re-use the name.
- **Asset / account on new-platform workflow.** They cannot exist yet — the platform is new. Create directly without a pre-check; the new-platform workflow in [`AGENTS.md`](../../../AGENTS.md) is explicit about this. Do not waste a turn asking the operator "does this asset exist already?".
- **Asset / account on enhance-platform workflow.** Look up by name or ID; edit if found; create otherwise. Do not delete-then-create.
- **Triggers** are not idempotent in the strict sense (each run produces a new task log), but re-triggering after a failed run is safe — the prior task log persists.

## Error semantics this skill recognises

The dev-loop wrapper distinguishes three failure shapes:

1. **Programmer error** — the script throws and writes nothing to stdout. Examples: missing required parameter for the chosen mode, no active session, schema file not found. The agent treats these as bugs in its own invocation and fixes the call rather than re-running.
2. **Operational failure** — the script writes its JSON document and exits with a phase index (1–4). The agent reads the JSON, identifies the failed phase, and routes the result to the right next step (validate → script-authoring; import → check the platform name; trigger / log → [`task-log-analysis`](../task-log-analysis/SKILL.md)).
3. **Trigger failure with task log** — `safeguard-ps` raises `Ex.SafeguardLongRunningTaskException` carrying a typed `TaskLog` array. The wrapper surfaces this as `phases[2].status = "failed"` plus a structured `taskLog` field. A real failure example is captured in [`tools/README.md`](../../../tools/README.md) (`phases[2] data`, "Real failure-path output"). Even on trigger failure the wrapper still attempts the log fetch when a task GUID was extractable, so `phases[3]` is usually populated and the exit code stays `3`.

## Secret handling

- Do not write secret parameter values into evidence, status messages, or operator-visible output.
- SPP server-side already redacts known credential parameters as the literal string `**secret**` in returned task logs (constant `PangaeaAppliance\src\Platform\Platform.Rsms\Constants\ParameterConstants.cs:5`, cited in [`tools/README.md`](../../../tools/README.md), "Secret handling"; cross-repo map in [`docs/agent-reference/rsms-engine-map.md`](../../../docs/agent-reference/rsms-engine-map.md)). Do not attempt to recover real values from these markers.
- Custom-script authors who add new secret parameters must declare them with `Type: "Secret"` so the same redaction applies — see [`script-authoring`](../script-authoring/SKILL.md).

## Failing closed

This skill refuses to run any operation that requires appliance contact when the active mode is `author-only` or `probe-only`, or when there is no `Connect-Safeguard` session and no `-AccessToken` was supplied. The dev-loop wrapper enforces the same check at lines 235–250 of `tools/Invoke-PlatformDevLoop.ps1`. Surface the missing prerequisite to the operator; do not attempt a workaround.

