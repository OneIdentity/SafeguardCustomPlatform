[← Repository README](../../README.md)

# Agent reference corpus

This directory holds machine-first reference material for the agent skill system. It is cited from `AGENTS.md` and from individual `SKILL.md` files under `.agents/skills/`.

Human-facing documentation lives in `docs/concepts/`, `docs/guides/`, `docs/tutorials/`, `docs/reference/`, and `docs/quick-start/` and is not duplicated here. Agent-only content stays out of human-facing locations.

## Files

| File | Purpose | How it is maintained |
| --- | --- | --- |
| [`samples-index.md`](samples-index.md) | Normalized index of every sample and template (protocol, auth-scheme, operations, OS-family, file-path, README). | **Generated** by `tools/Build-SamplesIndex.ps1`. CI runs the same script with `-CheckOnly` and fails if the committed copy is stale. |
| [`strategy-decision-tree.md`](strategy-decision-tree.md) | Decision table that backs the `strategy-selection` skill (SSH and HTTP only). | Hand-maintained from `docs/guides/`. SSH and HTTP only. |
| [`failure-patterns.md`](failure-patterns.md) | Error-signature → likely cause → fix catalog used by `task-log-analysis`. | **Initially empty.** Rows are populated from real extended task logs as failures are encountered. Invented rows are not acceptable. |
| [`script-authoring-deep-dives.md`](script-authoring-deep-dives.md) | Long-form reference for topics extracted out of the `script-authoring` skill (diagnostics rules, sample-mining loop, function-call signatures, Linux `CheckPassword` pattern, `Catch`-block logging). | Hand-maintained. |
| [`vendor-doc-search-recipes.md`](vendor-doc-search-recipes.md) | Query templates for fetching vendor docs and a normalization recipe for pasted vendor-doc excerpts. | Hand-maintained. |
| [`rsms-engine-map.md`](rsms-engine-map.md) | Cross-repo map: each authored construct (operations, `Do`-block verbs, parameter types, reserved variables, task-log/status contracts, validation entry points) → the authoritative source `file:line` in the `Kevin-Andrew/PangaeaAppliance` repo, where the Rsms engine that executes these scripts lives. Backs cross-repo compatibility-bug work. | Hand-maintained from a source-cited analysis of the PangaeaAppliance tree. Re-verify citations against the current engine ref; paths move. |

## Related contracts

- `.agents/schemas/evidence.schema.json` — JSON Schema for the probing evidence artifact produced by the `target-probing` skill and consumed by `strategy-selection` and `script-authoring`. This is an internal agent contract and is deliberately separate from `schema/custom-platform-script.schema.json`.
