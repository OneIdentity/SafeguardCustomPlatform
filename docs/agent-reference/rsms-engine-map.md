[← Agent reference](README.md)

# Rsms engine map

The custom-platform JSON authored in this repo is **not** executed here. It is
parsed, validated, and run by the **Rsms** scriptable engine that ships inside
the appliance, whose source lives in a *different* repository:
[`Kevin-Andrew/PangaeaAppliance`](https://github.com/Kevin-Andrew/PangaeaAppliance).

This file maps each construct an author writes (operations, `Do`-block verbs,
parameter types, reserved variables, task-log/status contracts) to the
**authoritative Rsms source location** that defines it. It exists so an agent
fixing a compatibility bug between the two repos can answer "what does the
engine *actually* accept?" with a one-hop lookup instead of guessing from this
repo's `schema/` — which is a convenience mirror that can drift.

## How to read this file

- **All `path\to\file.cs:line` citations are repo-root-relative paths inside
  `PangaeaAppliance`, not this repo.** Windows separators, matching that repo.
- **The engine is authoritative; `schema/custom-platform-script.schema.json` is
  not.** When the local JSON Schema and the engine disagree, the engine wins.
  A `SchemaOnly` green is necessary but not sufficient (see `AGENTS.md`,
  "`SchemaOnly` is not a correctness signal"). The fix for a disagreement is
  almost always to correct this repo's schema/sample, not the script under test.
- **Verify before trusting.** These citations are a snapshot. Re-confirm against
  the current PangaeaAppliance tree before acting on a high-stakes change — file
  moves happen (see "Path-drift warning"). The quick index at the bottom is the
  minimal set of files to re-check.

## Provenance

Source-cited by a cross-repo analysis of the PangaeaAppliance tree (see commit
ref in the quick index). Every claim below carries a `file:line` citation into
that repo. When a path here stops resolving, treat it as drift and re-locate the
symbol by name — do not assume the contract changed.

## Path-drift warning (read this first)

The PangaeaAppliance **`Hercules\Source\Rsms.*` and `Hercules.DevKit` paths that
older citations in this repo use no longer exist.** The Hercules subtree was
dissolved and relocated into PangaeaAppliance's standard `src\` layout. The C#
**namespaces are still `Hercules.*` / `Rsms.Public.*`**, but the files now live
under `src\Service\Rsms`, `src\Platform\Platform.Rsms*`, and
`src\Common\Common.Rsms`. Concretely:

| Older (stale) path cited in this repo | Current path in PangaeaAppliance |
| --- | --- |
| `Hercules\Source\Rsms.Public\Constants\Logging.cs` | `src\Common\Common.Rsms\Rsms.Public\Constants\Logging.cs` |
| `Hercules\Source\Hercules.DevKit\Constants\ParameterConstants.cs` | `src\Platform\Platform.Rsms\Constants\ParameterConstants.cs` |
| `src\Data\Transfer\V2\PlatformTasks\TaskLog.cs` / `TaskStatus.cs` | unchanged — still correct |

This drift is itself the canonical example of why this file exists: a contract
moved in the engine repo and the citations here went stale without any
functional change. The stale references are corrected in
[`tools/README.md`](../../tools/README.md) and
[`.agents/skills/task-log-analysis/SKILL.md`](../../.agents/skills/task-log-analysis/SKILL.md).

## 1. Engine entry point

The Scriptable backend is the **`Service.Rsms`** service (assembly `Rsms`,
`src\Service\Rsms\Rsms.csproj`, TFM `net10.0-windows`). The interpreter lives
under `src\Service\Rsms\Modules\Modules\Scriptable\`.

| Role | Class | Source |
| --- | --- | --- |
| Backend / operation host | `ScriptableModule` | `src\Service\Rsms\Modules\Modules\Scriptable\ScriptableModule.cs:32` (registered `[ModuleBackendDefinition(BackendNames.ScriptableBackendName, …)]` at `:31`) |
| Interpreter / `Do`-loop | `Runner` | `Runner.cs:17` — `ExecuteOperationBlock` walks the `Do` list `:181-197`; `ExecuteOperation` runs each verb `:204-213`; function call + scoping `:89-161` |
| Verb registry / resolver | `ComponentManager` | `ComponentManager.cs:13` — auto-registers every `IModuleComponent` keyed by `[ComponentName]` `:45-66`; resolves by name `:33-36`. Components must be stateless `:56-57` |
| JSON → object-model parser | `ModelOperationBlockConverter` | `Abstractions\ModelOperationBlockConverter.cs` — each `Do` step is a single-property object `{ "Verb": {…} }`; `CreateOperation` `:245-260`; verb→type lookup `GetComponentTypeMatchingComponentName` `:317-328` (throws `No component found matching name …` on unknown verb `:324`) |
| Platform-definition model | `ScriptablePlatformDefinition` | `Model\ScriptablePlatformDefinition.cs:16` — binds top-level keys `Imports` `:19`, `Meta` `:22`, `Functions` `:25`; `GetFunctionBlock(OperationType)` `:37-45` |

Caller chain from the appliance Core API into the engine:
`PlatformLogic.ValidatePlatformScriptAsync` →
`HerculesClient.ValidateScriptAsync`
(`src\Platform\Platform.Rsms.Client\HerculesClient.cs:273`) → Rsms
`PlatformsController` (`src\Service\Rsms\Controllers\v1\PlatformsController.cs`).

## 2. `Do`-block verbs (case-sensitive)

Verb names are string constants in `Hercules.Common.Constants.ComponentNames`
(`src\Platform\Platform.Rsms\Constants\ComponentNames.cs`). The parser matches a
`Do` step's single property name **exactly, ordinal/case-sensitive**, against
`ComponentNameAttribute.Name` (`ModelOperationBlockConverter.cs:320-321`). One
component may register several names (`Attributes\ComponentNameAttribute.cs:5-6`).

All component files are under
`src\Service\Rsms\Modules\Modules\Scriptable\Components\`.

| Verb | Dispatched at (under `…\Components\`) |
| --- | --- |
| `Connect` | `Connect\ConnectComponent.cs:22` |
| `Disconnect` | `Disconnect\DisconnectComponent.cs:12` |
| `Send` | `Send\SendComponent.cs:15` |
| `Receive` | `Receive\ReceiveComponent.cs:18` |
| `ExecuteCommand` | `ExecuteCommand\ExecuteCommandComponent.cs:22` |
| `ExecuteDependentCommand` | `ExecuteDependentCommand\ExecuteDependentCommandComponent.cs:21` |
| `Request` | `Request\RequestComponent.cs:26` |
| `NewHttpRequest` | `NewRequest\NewHttpRequestComponent.cs:9` |
| `BaseAddress` | `BaseAddress\BaseAddressComponent.cs:9` |
| `Headers` | `Headers\HeaderComponent.cs:12` |
| `HttpAuth` | `HttpAuth\HttpAuthComponent.cs:17` |
| `ExtractJsonObject` | `ExtractJsonObject\ExtractJsonObjectComponent.cs:14` |
| `ExtractFormData` | `ExtractFormData\ExtractFormDataComponent.cs:12` |
| `GetFormValue` / `GetFormData` | `GetFormValue\GetFormValueComponent.cs:10-11` |
| `SetFormValue` / `SetFormData` | `SetFormValue\SetFormValueComponent.cs:11-12` |
| `WriteResponseObject` | `WriteResponseObject\WriteResponseObjectComponent.cs:12` |
| `GetCookie` | `GetCookie\GetCookieComponent.cs:12` |
| `SetCookie` | `SetCookie\SetCookieComponent.cs:11` |
| `ClearCookie` | `ClearCookie\ClearCookieComponent.cs:13` |
| `Split` | `Split\SplitComponent.cs:10` |
| `Eval` | `Eval\EvalComponent.cs:9` |
| `Log` | `Log\LogComponent.cs:9` |
| `Status` | `Status\StatusComponent.cs:38` |
| `Wait` | `Wait\WaitComponent.cs:10` |
| `Comment` | `Comment\CommentComponent.cs:8` |
| `SmaAccountName` | `SmaAccountName\SmaAccountNameComponent.cs:10` |
| `DiscoverSshHostKey` | `DiscoverSshHostKey\DiscoverSshHostKeyComponent.cs:21` |
| `WriteDiscoveredAccount` | `WriteDiscoveredAccount\WriteDiscoveredAccountComponent.cs:19` |
| `WriteDiscoveredService` | `WriteDiscoveredService\WriteDiscoveredServiceComponent.cs:18` |
| `WriteDiscoveredSshKey` | `WriteDiscoveredSshKey\WriteDiscoveredSshKeyComponent.cs:14` |
| `WriteDiscoveredAsset` | `WriteDiscoveredAsset\WriteDiscoveredAssetComponent.cs:19` |
| `Condition` | `Condition\ConditionComponent.cs:10` |
| `Switch` | `Switch\SwitchComponent.cs:14` |
| `For` | `For\ForComponent.cs:10` |
| `ForEach` | `ForEach\ForEachComponent.cs:12` |
| `Try` | `Try\TryComponent.cs:13` |
| `Throw` | `Throw\ThrowComponent.cs:9` |
| `Function` (call) | `Function\FunctionComponent.cs:11` |
| `Return` / `Break` | `Return\ReturnComponent.cs:12-13` |
| `SetItem` / `Declare` | `SetItem\SetItemComponent.cs:8-9` |

**Lesser-known verbs the engine supports** (rarely in samples, easy to miss):
`AwsFunction` (`AwsFunction\AwsComponent.cs:13`); `VmwareSdkConnect` /
`VmwareSdkDisconnect` / `VmwareSdkDiscoverAssets`
(`VmwareSdkFunction\VmwareSdkComponent.cs:21-23`); `ComparePasswordHash` /
`CompareShadowHash` / `CompareMacOsPasswordHash` / `CompareUnixPasswordHash`
(one component, `ComparePasswordHash\ComparePasswordHashComponent.cs:12-15`; for
`CompareShadowHash` it delegates to the `IPasswordHash` helper
`src\Service\Rsms\Common\Crypt\PasswordHash.cs:96` `CheckPasswordAgainstShadowEntry`,
which splits the `/etc/shadow` line on `:` itself at `:98` — pass the whole line,
do not pre-split);
`CryptMd5` (`Encrypt\EncryptComponent.cs:11`); `UrlEncode` / `UrlDecode`
(`EncodeDecode\EncodeDecodeComponent.cs:11-12`). Useful aliases:
`Declare`==`SetItem`, `Break`==`Return`, `GetFormData`==`GetFormValue`,
`SetFormData`==`SetFormValue`.

**Not executable `Do` verbs** even though they appear in `ComponentNames.cs`:
`Import`, `Functions`, `Meta` are **top-level definition keys**, and `Define` /
`NewObject` are structural — none register a component. Emitting them as a `Do`
step throws `No component found matching name …`
(`ModelOperationBlockConverter.cs:324`).

## 3. Operations

Public operation names are the `Rsms.Public.Definitions.OperationType` enum —
`src\Common\Common.Rsms\Rsms.Public\Definitions\OperationType.cs:3-30`. Full set
(enum order):

`Unknown, CheckSystem, CheckPassword, ChangePassword, ChangeSshKey,
UpdateDependentSystem, DiscoverAccounts, DiscoverServices, DiscoverSshHostKey,
EnableAccount, DisableAccount, DiscoverAuthorizedKeys, CheckSshKey, CheckHostKey,
DiscoverAssets, RemoveAuthorizedKey, RetrieveSshHostKey, CheckApiKey,
ChangeApiKey, DiscoverApiKeys, ElevateAccount, DemoteAccount,
CheckFile, ChangeFile`

A script "supports" an operation iff its `Functions` contains a function whose
`Name` matches the `OperationType` name (case-insensitive:
`ScriptablePlatformDefinition.GetFunctionBlock` `Model\ScriptablePlatformDefinition.cs:42-45`;
gating `ScriptableOperationAttribute.IsSupportedForPlatformDefinition`
`Attributes\ScriptableOperationAttribute.cs:14-37`). There are **no runtime
feature flags** toggling operations — support is per-platform-definition.

Operations the engine actually **implements** (`[ScriptableOperation]` methods in
`ScriptableModule.cs`): `CheckSystem:112`, `CheckPassword:181`,
`ChangePassword:227`, `ChangeSshKey:303`,
`CheckApiKey:326`, `ChangeApiKey:349`, `UpdateDependentSystem:372`,
`DiscoverAccounts:520`, `DiscoverServices:558`, `DiscoverSshHostKey:602`,
`EnableAccount:634`, `DisableAccount:672`, `DemoteAccount:710`,
`ElevateAccount:737`, `DiscoverAuthorizedKeys:764`, `CheckSshKey:810`,
`DiscoverAssets:861`, `RemoveAuthorizedKey:924`, `CheckFile:971`,
`ChangeFile:1022`, `RetrieveSshHostKey:1080`.

> **Compatibility gap:** `OperationType` defines `DiscoverApiKeys` and
> `CheckHostKey`, but neither has a `[ScriptableOperation]` method in
> `ScriptableModule.cs` on the analyzed tree — they are valid enum values that
> are **not executable** on this engine version. A script that defines a
> `DiscoverApiKeys` function will not be driven by the engine. Re-verify against
> the target appliance build before relying on either.

## 4. Parameter types & reserved variables

Two type enums exist — **do not conflate them**:

| Enum | Values | Source | Used for |
| --- | --- | --- | --- |
| `Rsms.Public.Definitions.DataType` | `Null, Boolean, Integer, Float, String, Array, Object, Secret, Email` | `src\Common\Common.Rsms\Rsms.Public\Definitions\DataType.cs:3-14` | engine-internal typing; function-parameter and reserved-variable types |
| `CustomScriptParameterType` (`Pangaea.Data.Transfer.V2.PlatformTasks`) | `String=0, Integer=1, Boolean=2, Secret=3, Array=4, Object=5, Float=6` | `src\Data\Transfer\V2\PlatformTasks\CustomScriptParameterType.cs:6-42` | the `Type` an author sets on a custom platform parameter |

`CustomScriptParameterType` has **no `Email`/`Null`**; map between the two by
name, not by numeric value.

**Reserved/built-in variables** the engine injects are the
`Rsms.Public.Definitions.ReservedParameterName` enum (105 names) —
`src\Common\Common.Rsms\Rsms.Public\Definitions\ReservedParameterDefinitions.cs:7-106`;
canonical `DataType`s in `ReservedParameterDefinitionObjects` `:126-225`. Matching
is **case-insensitive** (`IsReservedParameterName` uses `Enum.TryParse(…, true, …)`
`:230-231`). A custom platform **cannot redefine a reserved name with a different
type** — enforced in
`src\Platform\Platform.Rsms\Extensions\PlatformExtensions.cs:85-87`.

High-use reserved variables:

| Variable | Type | Notes |
| --- | --- | --- |
| `Address` | String | `ReservedParameterDefinitions.cs:133` |
| `Port` / `SshPort` | Integer | `:172` / `:202` |
| `AssetName` | String | `:139`; defaults to `"Custom Asset"` when absent (`ScriptableModule.cs:38, 83-87`) |
| `AccountUserName` / `AccountId` / `AccountDn` / `AccountNamespace` | String | `:131` / `:129` / `:128` / `:132` |
| `AccountPassword` | **Secret** | `:130` |
| `NewPassword` | **Secret** | `:164` |
| `UseSsl` / `SkipServerCertValidation` | Boolean | — |
| `Timeout` / `Interval` | Integer | — |
| `DependentUsername` / `DependentPassword`(Secret) / `DependentCommand` / `CommandArguments` / `StdinArguments`(Array) | mixed | dependent-system flow |
| `HttpProxyUri` / `HttpProxyPort` / `HttpProxyUserName` / `HttpProxyPassword`(Secret) | mixed | HTTP proxy flow |

## 5. Task-log & status contracts

These back [`task-log-analysis`](../../.agents/skills/task-log-analysis/SKILL.md)
and the `phases[2]/phases[3]` payloads documented in
[`tools/README.md`](../../tools/README.md).

- **`TaskLog`** — `src\Data\Transfer\V2\PlatformTasks\TaskLog.cs:7`. Fields (all
  `[ReadOnly(true)]`): `DateTimeOffset Timestamp` `:13`, `TaskStatus Status`
  `:25`, `string Message` `:31`.
- **`TaskStatus`** enum (25 values, 0–24) —
  `src\Data\Transfer\V2\PlatformTasks\TaskStatus.cs:3`:
  `Unknown=0, Success=1, Failure=2, Connecting=3, Checking=4, Changing=5,
  PasswordMismatch=6, SshHostKeyMismatch=7, ServiceChangePasswordSuccess=8,
  ServiceChangePasswordFailure=9, ServiceRestartSuccess=10,
  ServiceRestartFailure=11, TaskChangePasswordSuccess=12,
  TaskChangePasswordFailure=13, Running=14, Queued=15, Finalizing=16, Saving=17,
  SshKeyMismatch=18, Discovering=19, Submitted=20, Cancelled=21,
  ApiKeyMismatch=22, Skipped=23, FileMismatch=24`.
- **Log-name constants** — `Hercules.Common.Constants.Logging`,
  `src\Common\Common.Rsms\Rsms.Public\Constants\Logging.cs` (the **single
  canonical definition** — other `Logging.cs` / `class Logging` files in
  PangaeaAppliance, e.g. `src\Service\Rsts\HttpService\Logging.cs`, are unrelated
  and do not define these members): `Operation =
  "Operation"` `:14`, `SshCommunication = "SshCommunication"` `:15` (plus derived
  `Operation.log` `:21`, `SshCommunication.log` `:23`, `PlatformTasks` `:32`,
  `Failure.log` `:34`, default log path `:12`; Tn3270/Telnet/Odbc/Open3270 names
  `:16-19`). These two names are the sections `Get-SafeguardTaskLog` emits.
- **Secret redaction sentinel** —
  `Hercules.Common.Constants.ParameterConstants.Secret = "**secret**"`,
  `src\Platform\Platform.Rsms\Constants\ParameterConstants.cs:5`. SPP replaces
  known secret parameter values with this literal before returning a log. Do not
  attempt to recover real values from it. Authors introducing new secret
  parameters should declare them `Type: "Secret"` so the same redaction applies.

## 6. Script validation (where rejection happens)

The appliance Core API surface this repo hits:
`src\Service\Core\Controllers\V3\Partitions\PlatformsController.cs`
— `POST .../ValidateScript` (base64 body) `:235-264` and
`POST .../ValidateScript/Raw` (octet-stream/file body) `:271-294`. Both require
`AssetAdmin`, are primary-only, and return a `V3.Partitions.Platform`. They call
`PlatformLogic.ValidatePlatformScriptAsync`
(`src\Data\Middleware\Core\V2\System\PlatformLogic.cs:823, 895`) →
`HerculesClient.ValidateScriptAsync`
(`src\Platform\Platform.Rsms.Client\HerculesClient.cs:273`).

Engine-side validation (real rejection):
`PlatformsController.CreateOrUpdateCustomPlatformDefinition(validateOnly:true)`
(`src\Service\Rsms\Controllers\v1\PlatformsController.cs:230-265`) →
`PlatformDefinitionFileSource.ValidateCustomPlatformDefinition`
(`src\Service\Rsms\Modules\Modules\Registry\PlatformDefinitionFileSource.cs:312`)
→ `ScriptableModuleCustomPlatformDefinitionValidator`
(`…\Scriptable\Validation\ScriptableModuleCustomPlatformDefinitionValidator.cs:11`)
and the static analyzer `ScriptableModuleStaticAnalyzer.Analyze`
(`…\Scriptable\Validation\ScriptableModuleStaticAnalyzer.cs:16`).

**Hard rejections (errors) the local JSON Schema does not mirror:**

| Engine rejects | Where | Schema mirrors it? |
| --- | --- | --- |
| Malformed JSON / wrong content → `E10017_PlatformRequestBadContent` | `Controllers\v1\PlatformsController.cs:245,252` | partial |
| **Duplicate function names** (across file + imports) → `DuplicateFunctionException` | `ScriptableModuleCustomPlatformDefinitionValidator.cs:24-30` | no |
| **Unknown `Do` verb** → `No component found matching name {name}` | `ModelOperationBlockConverter.cs:324` | no (schema is permissive on verb set) |
| **Reserved-parameter type/shape violations** | `ScriptableModuleStaticAnalyzer.cs:27-30` (+ `PlatformExtensions.cs:85-87`) | no |
| **Assignment to an undefined key** → `Key "{x}" was not found, the following keys exist: […]` | `ControlFlowExtensions.cs:141` | no |

**Warnings (do NOT reject):** uncalled functions
(`ScriptableModuleStaticAnalyzer.cs:37-42`); `GLOBAL` prefix usage
(`ControlFlowExtensions.cs:152`); use of an unpassed global-scope variable
(`:200-201`); possible infinite function recursion (`:345-346`); top-level
`Return` not returning a boolean (`:611`).

> **This section is the highest-yield place to look for "schema accepts / engine
> rejects" compatibility bugs.** The engine enforces unique function names,
> exact-case verb names, single-property-per-`Do`-step shape, and reserved-name
> typing — none of which a permissive JSON Schema necessarily catches. When a
> script passes `-SchemaOnly` but fails `Test-SafeguardCustomPlatformScript`,
> classify the appliance error against this table first.

## 7. Versioning & compatibility signals

- **No engine semantic version or changelog.** `Rsms.csproj` sets only
  `TargetFrameworks=net10.0-windows` (`src\Service\Rsms\Rsms.csproj:3`), no
  `<Version>`. You cannot read a feature-introduction version off the assembly.
- The engine's HTTP API is **v1 only**
  (`src\Service\Rsms\Controllers\v1\…`).
- **The practical compatibility oracle is the appliance build version**, not an
  engine version. Rsms ships and versions with the appliance ISO (the
  `version.json` written at bundle time). To decide "does build *X* support
  construct *Y*," map *Y* to the presence of (a) a `ComponentNames` constant +
  a registered `[ComponentName]` component (verbs), or (b) a `[ScriptableOperation]`
  method (operations) in the PangaeaAppliance tree at that build's ref.

## Quick contract index

Re-check these files first when verifying a compatibility claim. Paths are
PangaeaAppliance-relative.

| Contract | File |
| --- | --- |
| Verb name strings | `src\Platform\Platform.Rsms\Constants\ComponentNames.cs` |
| Verb → impl dispatch | `[ComponentName]` on each `…\Scriptable\Components\*\*Component.cs` |
| Verb resolution rule (exact-case) | `…\Scriptable\Abstractions\ModelOperationBlockConverter.cs:317-328` |
| Operation names | `src\Common\Common.Rsms\Rsms.Public\Definitions\OperationType.cs` |
| Operation impls | `src\Service\Rsms\Modules\Modules\Scriptable\ScriptableModule.cs` |
| Engine type system | `src\Common\Common.Rsms\Rsms.Public\Definitions\DataType.cs` |
| Author param types | `src\Data\Transfer\V2\PlatformTasks\CustomScriptParameterType.cs` |
| Reserved variables | `src\Common\Common.Rsms\Rsms.Public\Definitions\ReservedParameterDefinitions.cs` |
| TaskLog / TaskStatus | `src\Data\Transfer\V2\PlatformTasks\TaskLog.cs`, `TaskStatus.cs` |
| Log names / secret sentinel | `src\Common\Common.Rsms\Rsms.Public\Constants\Logging.cs`, `src\Platform\Platform.Rsms\Constants\ParameterConstants.cs` |
| Validation entry | `…\Scriptable\Validation\ScriptableModuleStaticAnalyzer.cs`, `ScriptableModuleCustomPlatformDefinitionValidator.cs` |
| Public validate endpoints | `src\Service\Core\Controllers\V3\Partitions\PlatformsController.cs:235,271` |

> **Snapshot ref:** analyzed against PangaeaAppliance commit
> `fb5ae4e0fe1bc438c8035dbe9b7086b77b40115b` (branch
> `features/f_696160_ISO_InitialSetupWebsite`; tip dated 2026-06-22). The last
> commit touching the Scriptable engine dir
> (`src\Service\Rsms\Modules\Modules\Scriptable`) specifically was `9be615a13d`
> ("TFS 709205 … net10 upgrade"). Confirm the current ref before relying on
> line numbers; symbol names are more stable than lines.
