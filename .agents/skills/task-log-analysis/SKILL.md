---
name: task-log-analysis
description: >-
  Use when an operation has run and produced an extended task log that
  must be classified and turned into a next step. Pulls or accepts the
  extended task-log JSON, classifies the failure phase
  (connect / auth / parse / operation / unknown), extracts actionable
  signals, and recommends the next iteration. Backed by the
  failure-pattern catalog at docs/agent-reference/failure-patterns.md,
  which ships empty and is grown only from real runs.
---

# task-log-analysis

## Pre-flight

Before turning a task log into a fix, consult [`AGENTS.md`](../../../AGENTS.md) for the iterative debug-loop budget (3 same-signature failures or 10 total iterations, whichever first). Each iteration must produce a changed draft; if this skill cannot articulate what changed since the prior log, escalate early instead of grinding.

## Scope

This skill takes an extended task log produced by SPP and turns it into a structured next step:

1. Pull the log (full-loop) or accept a saved JSON file (author-only).
2. Classify the failure phase: `connect | auth | parse | operation | unknown`.
3. Extract the actionable signal (the first mismatch-class entry, the offending `Send`/`Receive` pair, the failing HTTP status code, etc.).
4. Recommend the next iteration: which skill to re-engage, which assumption to test, which probe to re-run.

It is the only skill that is allowed to read raw task-log JSON and surface conclusions; other skills request analysis through this one.

## Modes

- **full-loop** — fetches the log live via [`safeguard-ps-operations`](../safeguard-ps-operations/SKILL.md) (`Get-SafeguardTaskLog -TaskId <GUID>` under the hood; the dev-loop wrapper already does this in its `log` phase).
- **author-only** — accepts a task-log JSON file the operator saved earlier and reads it from disk. Useful for retrospective analysis with no appliance available.
- **probe-only** — fails closed.

## Inputs

The skill consumes the JSON document produced by [`tools/Invoke-PlatformDevLoop.ps1`](../../../tools/Invoke-PlatformDevLoop.ps1), or any `Get-SafeguardTaskLog` result the operator saved as JSON. The relevant fields are documented with real-output examples in [`tools/README.md`](../../../tools/README.md) ("phases[2] (trigger) data" and "phases[3] (log) data").

Two layers of evidence matter:

- **`phases[2].data.taskLog`** — the structured array (`Timestamp`, `Status`, `Message`) that `safeguard-ps` attaches to `Ex.SafeguardLongRunningTaskException` on a trigger failure. The first non-`Queued`/`Running` `Status` value usually pins the failure phase; the last entry is the user-visible summary.
- **`phases[3].data.log`** — the per-named-log entries (`Recorded`, `Level`, `Event`) from `Get-SafeguardTaskLog`. Sections are separated by synthetic `--- <logName> ---` entries inserted by safeguard-ps. The two log names produced by SPP for platform tasks are stable string constants `Operation` and `SshCommunication` (cited in [`tools/README.md`](../../../tools/README.md) "phases[3] data"; defined in `PangaeaAppliance\src\Common\Common.Rsms\Rsms.Public\Constants\Logging.cs:14-15`, mapped in [`docs/agent-reference/rsms-engine-map.md`](../../../docs/agent-reference/rsms-engine-map.md)).

Read both. The `Operation` log shows what the platform script intended; `SshCommunication` (when present) shows the raw frames so a `Send`/`Receive` mismatch becomes diagnosable.

### Fetching a task log directly: `Get-SafeguardTaskLog` parameter shape

Two non-obvious facts about the cmdlet:

- **No-args vs `-TaskId` return entirely different shapes.** With no arguments, `Get-SafeguardTaskLog` returns a flat array of recent task-ID GUID strings across **all** tasks the session can see — a discovery call, not a log-fetching call. With `-TaskId <guid>` it returns the actual `{Recorded, Level, Event}` records for that task.
- **Section headers come through with empty `Level`.** The synthetic `--- <logName> ---` separator entries SPP inserts between named logs (`Operation`, `SshCommunication`) carry empty `Level`. Treat any record whose `Level` is empty as a section delimiter, not as a real log event, and use it to know which named log the surrounding records belong to.

When the operator only has an asset/account and no task GUID, do not enumerate every recent task ID and parse JSON looking for the account name — ask the operator to re-trigger with `-ExtendedLogging`. The trigger output emits the new GUID directly.

## Classification flow

| Phase | What it means | Where it shows up |
| --- | --- | --- |
| **connect** | Could not establish the underlying transport. SSH: TCP reset, host-key mismatch, timeout. HTTP: DNS/TLS/connect-refused. | Earliest entries in `Operation` or `phases[2].data.taskLog`. SSH-side host-key issues surface as `SshHostKeyMismatch` `Status`. |
| **auth** | Transport up, credentials rejected. SSH: `Permission denied`, `passwd`-prompt-after-banner. HTTP: 401/403, login-form re-presentation. | Look for `PasswordMismatch`, `SshKeyMismatch`, `ApiKeyMismatch` `Status` values (from the stable `TaskStatus` enum, see [`tools/README.md`](../../../tools/README.md) "phases[2] data" closing paragraph), or HTTP status codes in `Operation` events. |
| **parse** | Connection and auth succeeded but a `Receive`/`ExtractJsonObject`/`ExtractFormData`/regex did not match what came back. | `Operation` shows the script proceeding past auth; the failure event is a parse/regex error, often with the buffer contents inline. |
| **operation** | The script ran, the target accepted it, but the action did not produce the desired state (password not actually changed, account not found by discovery, etc.). | The trigger may even report success; the follow-up `CheckPassword` then mismatches. Compare across two task logs in this case. |
| **unknown** | Nothing above fits. | Stop and ask the operator. Do not invent a category. |

The first three buckets are mutually exclusive; `operation` can co-occur (e.g., auth succeeded but operation failed because the account does not exist).

## Signal extraction

For each failure, surface to the operator (and to whichever skill is taking the next step):

- The classified phase.
- The exact `Status` and `Message` of the first mismatch-class entry.
- The exact `Event` text of the last `Operation` entry before the failure.
- For SSH parse failures: the corresponding `SshCommunication` `Send` and `Receive` pair (look for adjacent `Send :` / `Receive :` events bracketing the failure timestamp).
- For HTTP failures: the `Verb`, `Url`, response status code, and (when present) response body excerpt.
- The script changes, if any, that distinguish this iteration from the previous one. If the answer is "no change", that is itself the signal — the loop is stuck and should escalate.

Do not paraphrase the messages; quote them verbatim. The catalog below matches on substrings.

**Catch-block masking rule.** When the operation returns a clean verdict (e.g., `PasswordMismatch`, `CheckResult: false`, a sentinel error string) and the log shows a `Try`/`Catch` fired earlier in the operation, the verdict is the catch's fallback value, **not** the target's answer. Read the caught exception text from the inner `Operation` events (typically `Exception evaluating expression …`, `Command X failed with an error …`, or `An error was thrown in the try block …`) before drawing target-side conclusions. Verdict-shaped script bugs are the failure mode this rule guards against.

## Failure-pattern catalog

The catalog is [`docs/agent-reference/failure-patterns.md`](../../../docs/agent-reference/failure-patterns.md). It **ships empty by design**. Rows are added only from real extended task logs; rows mined from prose guides or invented from memory are explicitly not acceptable.

When the catalog is empty, this skill falls back to the classification flow above and asks the operator for guidance on signatures it has not seen before. When it has rows, this skill matches the extracted signature substring against the `signature` column and surfaces the recommended fix; an exact-or-near match shortens the next iteration to a targeted change.

If a real failure is observed that the catalog does not cover, the agent **proposes a new row** at the end of the loop — signature, phase, likely cause, recommended fix, first-observed date and target type — and asks the operator to confirm before adding it. Confirmation lives outside this skill (the row is added to `failure-patterns.md` by hand or in a follow-up commit).

## Recommendation routing

Hand the result back to the right skill:

- `connect` failures with host-key / SSL mismatches → re-run probes via [`target-probing`](../target-probing/SKILL.md) to capture the new fingerprint, then update the script.
- `connect` / `auth` failures with credential issues → confirm the service-account credential with the operator before any further appliance call. Do not retry blindly (credential lockout risk; the probe-safety contract in [`target-probing`](../target-probing/SKILL.md) applies even outside probing).
- `auth` failures with HTTP 401 after a token exchange → revisit [`script-authoring`](../script-authoring/SKILL.md) for the `http-api` two-step token-handling shape; common cause is reusing a single `RequestObjectName` across token-fetch and operation calls.
- `parse` failures → revisit `script-authoring`; cross-reference the failing `Receive`/regex against the analogous sample.
- `operation` failures (target accepted but state did not change) → revisit [`strategy-selection`](../strategy-selection/SKILL.md). The wrong pattern may have been chosen (e.g., interactive `passwd` over batch SSH succeeds visibly but does not actually rotate).
- `unknown` → stop and ask.

## Escalation

This skill never silently retries. When the loop budget is exhausted or two consecutive iterations produce the same signature without a meaningful script change, surface to the operator:

- The full classification result.
- Every signature seen in this loop.
- The set of changes attempted between iterations.
- A specific, narrow next question (e.g., *"Run `passwd -S <user>` on the target and paste the output — the task log shows the change command exited 0 but `CheckPassword` still mismatches, which is consistent with the account being locked"*).

This is the loop-budget backstop from [`AGENTS.md`](../../../AGENTS.md): the desktop operator is the final arbiter; do not fabricate progress.

