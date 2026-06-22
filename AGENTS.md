# AGENTS.md — SafeguardCustomPlatform

Repository for Safeguard for Privileged Passwords (SPP) custom platform scripts. The repo holds the JSON schema (`schema/`), tested reference samples (`samples/`), pattern templates (`templates/`), human-facing documentation (`docs/`), and tooling (`tools/`) for authoring custom platforms.

This file is the agent orchestrator. Read it first.

## Project structure

- `AGENTS.md` (this file) — orchestrator: workflows + routing table.
- `.agents/` — `skills/` (one subdirectory per capability skill, each with a `SKILL.md`), `schemas/evidence.schema.json` (probing-evidence contract), `prompts/` (per-phase implementation prompts), `CONVENTIONS.md`.
- `schema/custom-platform-script.schema.json` — authoritative platform-script schema.
- `samples/` — tested production-grade samples (ssh, http, telnet).
- `templates/` — pattern templates and minimal starters.
- `docs/agent-reference/` — machine-first reference (samples-index, strategy-decision-tree, failure-patterns, vendor-doc-search-recipes). `docs/concepts|guides|reference|tutorials|quick-start/` are human-facing — keep untouched.
- `tools/` — `Invoke-PlatformDevLoop.ps1` (validate→import→trigger→log wrapper), `Build-SamplesIndex.ps1`, `Test-AgentLinks.ps1`, `TestTool.ps1` (human-facing).

## Custom platform mental model

A Safeguard custom platform script is a JSON document that teaches SPP how to manage credentials on a target system that SPP does not natively support. The script declares operations (`CheckSystem`, `CheckPassword`, `ChangePassword`, `DiscoverAccounts`, …), each defined as a list of scripting-engine commands (`Connect`, `Send`, `Receive`, `ExecuteCommand`, `Request`, `HttpAuth`, `ExtractJsonObject`, …).

SPP runs the script against an asset and an account: the asset supplies network address and a service-account credential; the account is the managed identity whose credential is being checked or rotated. The script returns a status (success, failure, error) and, in extended-logging mode, a structured task log describing each command's input and output.

Authoring a custom platform is iterative: draft the JSON, validate it against the schema, import it into a test appliance, trigger an operation with extended logging, read the task log, fix the script, repeat. The agent skill system is built around making this loop fast and grounded in real evidence.

## Cross-repo: the Rsms execution engine

The scripts authored here do not run in this repo. They are parsed, validated, and executed by the **Rsms** scriptable engine that ships inside the appliance, whose source lives in a separate repository: [`Kevin-Andrew/PangaeaAppliance`](https://github.com/Kevin-Andrew/PangaeaAppliance). Several contracts this repo depends on — the task-log shape, the status enum, the log-name constants, and the secret-redaction sentinel — are *defined there*, not here.

Two consequences shape how an agent should reason about compatibility:

- **The engine is authoritative; this repo's `schema/custom-platform-script.schema.json` is a convenience mirror that can drift.** When the local schema and the engine disagree, the engine wins. A clean local schema validation does not prove the engine will accept the script (see "`SchemaOnly` is not a correctness signal" below). The usual fix for a disagreement is to correct this repo's schema or sample, not the script under test.
- **A "compatibility bug" is almost always drift between the two repos** — the engine added, moved, renamed, or tightened a construct, and this repo's schema, samples, docs, or citations lagged. Resolving one means checking what the engine *actually* does at the relevant source location.

When a compatibility question arises — "is this verb real?", "does the engine accept this parameter type?", "why does the appliance reject a script that passes local schema validation?" — consult [`docs/agent-reference/rsms-engine-map.md`](docs/agent-reference/rsms-engine-map.md). It maps every authored construct (operations, `Do`-block verbs, parameter types, reserved variables, task-log/status contracts, the validation entry points) to the authoritative PangaeaAppliance source file and line. Its "Script validation" section is the highest-yield place to look for "schema accepts / engine rejects" classes of bug. Note that engine source paths move (the `Hercules\Source\*` tree was relocated under `src\`); the engine-map records the current paths and re-confirming against the live PangaeaAppliance tree before a high-stakes change is expected.

If a change in PangaeaAppliance is what broke the contract, the fix belongs in both places: update the engine-map citation here, and — when reachable — leave a note in the PangaeaAppliance Rsms project pointing back at this repo so the next engine change prompts a heads-up.

## Operating modes

The agent declares the active mode at the start of every session. Each skill declares the modes it supports and **fails closed** when invoked outside them.

| Mode | What is available | What works |
| --- | --- | --- |
| `author-only` | Repo only. No SPP appliance, no live target. | Schema validation, sample/template lookup, JSON drafting, strategy selection, log analysis from saved files. |
| `probe-only` | Operator's shell can reach the target with a service-account credential, but no SPP appliance. | Authoring + target probing. Live import/trigger does not run. |
| `full-loop` | Appliance + target both available. | The full validate → import → trigger → log-analyze loop. |

If the agent is unsure which mode applies, it asks the operator before proceeding.

## Question discipline

The agent's default posture is **act, then ask only when blocked**. Every up-front question costs operator time; the iterative debug loop already expects course-correction, so a wrong-but-recoverable choice usually beats a question. Concretely:

- **Ask only what is required to take the next action.** Do not pre-collect facts the next step doesn't yet need. Probing rarely needs the operator's deployment topology; authoring rarely needs port numbers.
- **Try, then ask on failure.** When two paths exist (secure vs `-Insecure`, module-installed vs not, asset-exists vs not), pick the safer/more-common path and try it. Ask only when the attempt errors out and the next step depends on the answer.
- **Ask for the service-account credential up front, with the credential kind first.** Gather what kind of credential the operator wants the platform to use — password, SSH key, API key, bearer token — *before* asking for the secret value, because the kind shapes everything else (probing technique, strategy selection, script auth shape). Ask for both in the same turn as the rest of requirements gathering, with a one-line note that the operator can rotate the secret after the workflow is done. Don't trade multiple turns for "do you have a credential / how would you like to provide it / …".
- **Treat `nonProductionAffirmed=true` as license to exercise the operations under test.** Once the operator affirms non-prod, the service account *is* a test account. The agent may run `CheckPassword`/`ChangePassword` against it as part of the workflow, with an up-front announcement that the password will be rotated as part of exercising `ChangePassword`. This is an announcement, not a per-probe consent gate. The probe-safety contract's destructive-probe rule still applies to operations beyond the service-account-on-this-target's password (key installs, account creation, sudo-that-mutates, etc.).
- **Do not ask "is this tool installed?".** Check first; if missing, ask once whether to install (e.g., `Install-Module safeguard-ps -Scope CurrentUser` from PowerShell Gallery, latest version).
- **Do not ask "does this asset exist?" on the new-platform workflow.** It cannot — the platform is new. Asset/account lookup is part of the enhance-platform workflow only.
- **Do not ask "are you logged in yet?".** `Connect-Safeguard -DeviceCode` (or `-Browser`) blocks until login completes (or fails); await the cmdlet's own signal rather than polling the operator. The token is long-lived — persist it once to the per-session state directory and rehydrate it for subsequent cmdlets, so re-login is rare. See `safeguard-ps-operations` for the persistence shape.
- **When yielding to the operator, surface what they need to act on.** The flip side of *act, then ask only when blocked*: when the next step requires the operator — device-code login, browser SSO, secret entry, a manual probe the agent cannot run — say what they need to do, where to look, and any time window, before yielding. A blocked operator who doesn't know they are blocked is the canonical silent iteration burn.

If the agent finds itself drafting a third clarifying question before any tool has run, that is the signal to stop, pick a default, and try.

## Notation: PowerShell vs API vs concept

See [`.agents/CONVENTIONS.md`](.agents/CONVENTIONS.md). Short version: `AGENTS.md` speaks concept (plain English); skills speak PowerShell (backticked cmdlets/switches) or API (backticked PascalCase fields).

## Authentication and safety

- **Use PowerShell 7+ when available; warn and continue otherwise.** safeguard-ps targets PS 7, and several cmdlets behave better there (cleaner error records, no Windows-PowerShell-only quirks). If only PS 5.1 is available, the agent emits a one-line warning and proceeds — do not block on the version.
- **Connect with `-DeviceCode` (preferred) or `-Browser` (fallback).** All `safeguard-ps` connections in agent flows use interactive PKCE — no password-in-script recipes. `-DeviceCode` prints a verification URL and short code rather than launching a local browser, which is the lower-friction default for terminal sessions. Fall back to `-Browser` only if the appliance does not have the Device Code grant enabled.
- **Never operate against a production target.** The operator must affirm the target is non-production before any probe or trigger runs. The affirmation is a soft control — responsibility rests with the operator. The agent does not (and cannot) verify environment classification independently.
- **Never log session tokens or secrets.** `$SafeguardSession`, target passwords, API keys, and private keys must not appear in evidence files, status messages, or operator-visible output.
- **Probe-safety contract.** The `target-probing` skill enforces a strict contract (read-only by default, per-probe consent for destructive probes beyond the service account, auth-attempt rate limit, fail-closed on lockout/throttle/MFA). See [`.agents/skills/target-probing/SKILL.md`](.agents/skills/target-probing/SKILL.md) for the full contract. Rotating the service account password as part of the workflow under test is announced up front but does not require per-probe consent (see *Question discipline*).
- **`SchemaOnly` is not a correctness signal.** Local schema validation only proves the JSON is well-formed and conformant. It does not catch undefined variables in `Do` blocks, regex that does not match in practice, or status-message ordering. Cross-reference samples for analogous patterns before treating green as ready-to-import.

## Sample and template index

The agent-facing index of every sample and template lives at [`docs/agent-reference/samples-index.md`](docs/agent-reference/samples-index.md) (generated by `tools/Build-SamplesIndex.ps1`; CI fails if stale). Use it to find a starting point by `(protocol, auth-scheme, operations)`. Telnet samples are excluded — telnet is out of scope for the agent skill system. Other agent-reference material lives alongside it in [`docs/agent-reference/`](docs/agent-reference/) (decision tree, failure-pattern catalog, vendor-doc search recipes).

## Workflow: new platform

Use this workflow when the operator's request is to build a custom platform that does not yet exist in the appliance.

1. **Gather requirements.** Classify intent (new vs enhance — this workflow is *new*), then collect what is missing:
   - **Platform display name** the operator wants the new platform to use on the appliance (e.g., `My Custom Linux`). **Required pre-condition: do not hand off to `strategy-selection` or draft any JSON until the operator has supplied this verbatim.** If unspecified, ask before proceeding — never invent a name from the protocol, vendor, or strategy choice. Renaming a platform mid-development costs a re-import.
   - Target system (vendor, product, version) and protocol (SSH or HTTP — telnet is out of scope).
   - **Operations needed.** SPP defines parallel operation families for each credential type: password (`CheckSystem`, `CheckPassword`, `ChangePassword`), SSH key (`CheckSshKey`, `ChangeSshKey`), API key (`CheckApiKey`, `ChangeApiKey`, `DiscoverApiKeys`), and file (`CheckFile`, `ChangeFile`), plus discovery operations (`DiscoverAccounts`, `DiscoverServices`, `DiscoverAssets`, `DiscoverSshHostKey`, `DiscoverAuthorizedKeys`). **Required pre-condition: do not hand off to `strategy-selection` or draft any JSON until the operator has confirmed the operation set verbatim.** Pick from the family that matches the credential intent — an API-key-only platform implements `CheckApiKey`/`ChangeApiKey` and nothing from the password family. Within a family, do not assume the full set: some platforms ship `Check*`-only at first, some skip `CheckSystem`, and every discovery operation requires an explicit yes. Each operation drafted but not requested is wasted iteration budget.
   - **Credential intent** — self-managed (the managed account rotates its own password) vs service-account (a separate account rotates the managed one).
   - **Service-account credential** — kind first (`password` / `ssh-key` / `api-key` / `bearer-token`), then the secret value or path. Per *Question discipline*, ask in this turn so probing isn't blocked later.
   - Any vendor documentation the operator can share (URL the agent fetches, or an excerpt pasted into the conversation — both first-class).
   Ask only what is missing. Do not re-ask for facts the operator already provided.
2. **Search samples-index + vendor docs.** Look up a starting point in [`docs/agent-reference/samples-index.md`](docs/agent-reference/samples-index.md) by `(protocol, auth-scheme, operations)`. If vendor docs are needed, use [`docs/agent-reference/vendor-doc-search-recipes.md`](docs/agent-reference/vendor-doc-search-recipes.md).
3. **Probe the target.** Hand off to [`target-probing`](.agents/skills/target-probing/SKILL.md). The skill enforces its own probe-safety contract and produces an evidence artifact conforming to [`.agents/schemas/evidence.schema.json`](.agents/schemas/evidence.schema.json). In `author-only` mode this step is skipped and the workflow proceeds with whatever the operator can supply by hand.
4. **Select a strategy.** Hand off to [`strategy-selection`](.agents/skills/strategy-selection/SKILL.md) with the probe evidence (or the operator-supplied substitute) and any vendor docs. Output: one of the four authoring patterns plus credential-intent and self-managed-vs-service-account.
5. **Author the JSON.** Hand off to [`script-authoring`](.agents/skills/script-authoring/SKILL.md). The skill mandates the fast inner loop: local schema validation against [`schema/custom-platform-script.schema.json`](schema/custom-platform-script.schema.json) before any appliance round-trip.
6. **Validate, import, and trigger.** Hand off to [`safeguard-ps-operations`](.agents/skills/safeguard-ps-operations/SKILL.md), which prefers [`tools/Invoke-PlatformDevLoop.ps1`](tools/Invoke-PlatformDevLoop.ps1) over re-implementing the loop. Create the asset and account directly without a pre-check (the platform is new). Trigger with extended logging enabled. Requires `full-loop` mode.
7. **Analyze the task log.** Hand off to [`task-log-analysis`](.agents/skills/task-log-analysis/SKILL.md).
8. **Enter the iterative debug loop** (below) until green or the loop budget triggers escalation.

## Workflow: enhance platform

Use this workflow when the operator wants to change a platform that is already deployed on the appliance.

1. **Gather requirements.** What operation is changing, what new behavior is expected, what existing behavior must not regress. Ask only what is missing.
2. **Source the current JSON via export.** Run `Export-SafeguardCustomPlatformScript` against the appliance (via [`safeguard-ps-operations`](.agents/skills/safeguard-ps-operations/SKILL.md)). **The deployed copy is authoritative for the diff.** On-disk samples in `samples/` are starting points — drift between the deployed JSON and any sample is expected and benign.
3. **Diff-aware authoring.** Hand off to [`script-authoring`](.agents/skills/script-authoring/SKILL.md) with the exported JSON as the base. Limit the change set to what the requirement demands. The fast inner loop (local schema validation) still runs before any appliance round-trip.
4. **Validate, import, and trigger only operations affected by the change.** A `ChangePassword` edit does not require re-testing `DiscoverAccounts`.
5. **Analyze the task log** for each affected operation via [`task-log-analysis`](.agents/skills/task-log-analysis/SKILL.md).
6. **Enter the iterative debug loop** (below) until green or the loop budget triggers escalation.

## Iterative debug loop

Both workflows enter this loop after the first trigger. The loop is the same in both cases.

1. **Try manually first** (when probe-only or full-loop is available). Reproduce the operation against the target with the service-account credential before changing the JSON. If the manual attempt fails, the JSON is not the right thing to fix yet — re-probe.
2. **Draft or revise the JSON** via [`script-authoring`](.agents/skills/script-authoring/SKILL.md).
3. **Fast inner loop:** local schema validation (`Invoke-PlatformDevLoop.ps1 -SchemaOnly`). Sub-second; no appliance contact. Iterate here until clean before paying for a round-trip.
4. **`Test-SafeguardCustomPlatformScript`** against the appliance via [`safeguard-ps-operations`](.agents/skills/safeguard-ps-operations/SKILL.md). This catches things local schema validation cannot.
5. **Import** the script.
6. **Trigger** the affected operation with extended logging enabled.
7. **Analyze the task log** via [`task-log-analysis`](.agents/skills/task-log-analysis/SKILL.md). Decide: green, revise, or escalate.

### Loop budget (best-effort)

Stop and escalate to the operator when **either** of these is true:

- **3 failures share the same error signature.** Repeated identical failures mean the current hypothesis is wrong, not that one more tweak will work. The classification produced by [`task-log-analysis`](.agents/skills/task-log-analysis/SKILL.md) is what defines "same signature."
- **10 total iterations** have run, whichever comes first.

Two reinforcing rules:

- **Each iteration must produce a changed draft.** If the agent cannot articulate what changed since the prior iteration in one sentence, escalate early — looping with no real change is the most expensive failure mode.
- **On operator correction, stop the current tactic.** Before responding or retrying, restate the active skill and the specific rule the correction invoked (e.g., "script-authoring — fast inner loop runs before any appliance round-trip"). Then resume. Arguing the correction or pivoting to a new tactic without re-grounding is how a single misread compounds into three wasted iterations.
- **The counter is not persisted.** Context compaction or shell restart resets it. The desktop operator is the backstop: if the operator notices the loop has restarted twice on the same problem, that is the signal to escalate regardless of the in-memory counter.

## Routing table

The five capability skills. Each `SKILL.md` opens with a pre-flight pointer back to this file; that is convention, not enforcement.

| Skill | When to load | Modes | File |
| --- | --- | --- | --- |
| `target-probing` | The agent must learn how a live target actually behaves before authoring or revising — banner grab, auth-scheme detection, prompt shape, sudo behavior, login-form/API discovery. Produces the structured evidence artifact consumed by `strategy-selection` and `script-authoring`. | `probe-only`, `full-loop` | [`.agents/skills/target-probing/SKILL.md`](.agents/skills/target-probing/SKILL.md) |
| `strategy-selection` | A pattern decision is needed: `ssh-interactive` vs `ssh-batch`; `http-form-fill` vs `http-api`; within `http-api`, the auth shape (HttpAuth-managed Basic/Digest vs script-managed-header Bearer/custom-scheme/custom-header) and one-step vs two-step token fetch; password vs SSH key vs API key vs bearer token; self-managed vs service-account. Accepts probe evidence, fetched URLs, and pasted vendor-doc excerpts. | `author-only`, `probe-only`, `full-loop` | [`.agents/skills/strategy-selection/SKILL.md`](.agents/skills/strategy-selection/SKILL.md) |
| `script-authoring` | Drafting or revising the platform JSON. Four pattern recipes (`ssh-interactive`, `ssh-batch`, `http-api`, `http-form-fill`). The `http-api` recipe covers any auth shape the API documents — Basic/Digest via `HttpAuth`, or Bearer / custom `Authorization` scheme / custom-header API key via script-built `Headers`. Mandates the fast inner loop (local schema validation) before any appliance round-trip. | `author-only`, `probe-only`, `full-loop` | [`.agents/skills/script-authoring/SKILL.md`](.agents/skills/script-authoring/SKILL.md) |
| `safeguard-ps-operations` | Driving a live SPP appliance through `safeguard-ps`: `Connect-Safeguard -DeviceCode` (or `-Browser`), `Test-` / `Import-` / `Export-SafeguardCustomPlatformScript`, asset/account create-or-update, triggering operations with extended logging, fetching task-log JSON. Wraps [`tools/Invoke-PlatformDevLoop.ps1`](tools/Invoke-PlatformDevLoop.ps1). All cmdlet syntax must come from `Get-Help <Cmdlet> -Full`. | `full-loop` (most operations); `author-only` for `Test-` and `Export-` against a local file | [`.agents/skills/safeguard-ps-operations/SKILL.md`](.agents/skills/safeguard-ps-operations/SKILL.md) |
| `task-log-analysis` | An operation has run and produced an extended task log that must be classified (`connect` / `auth` / `parse` / `operation` / `unknown`) and turned into a next step. Backed by [`docs/agent-reference/failure-patterns.md`](docs/agent-reference/failure-patterns.md), which ships empty and grows only from real runs. | `full-loop` (live log); `author-only` (saved JSON file) | [`.agents/skills/task-log-analysis/SKILL.md`](.agents/skills/task-log-analysis/SKILL.md) |

## Keeping this file current

When skills, workflows, modes, the loop budget, or `docs/agent-reference/` paths change, update this file in the same change. Do not let the routing table drift from the skills it points at.
