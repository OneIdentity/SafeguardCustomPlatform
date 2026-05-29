To better understand these sample scripts, read the [documentation](../docs/README.md).

These sample custom platform scripts show how to extend Safeguard for Privileged Passwords (SPP) with custom platforms that manage assets through the platform scripting engine over [SSH](SSH/), [Telnet (TN3270)](Telnet/), and [HTTP](HTTP/). Some target systems can be managed through more than one protocol, so start with the sample that is closest to your target workflow.

For getting started, see the [overview](../docs/getting-started/overview.md) and
[development workflow](../docs/getting-started/development-workflow.md) guides. For
product-level details on custom platforms and asset onboarding, refer to the SPP
Administration Guide available from the [One Identity documentation site](https://docs.oneidentity.com/).

## How to Use This Catalog

- [`SSH/`](SSH/), [`HTTP/`](HTTP/), and [`Telnet/`](Telnet/) contain real tested samples.
- [`Templates/`](Templates/) contains illustrative examples that are **not** tested against live targets and are not intended to be deployed as-is.
- Files prefixed with `Pattern-` show recommended approaches for a specific integration pattern.
- Files prefixed with `Template` are minimal starters you can copy and fill in.
- Complexity ratings describe the expected customization effort:
  - ⭐ **Beginner** — minimal starter or straightforward workflow
  - ⭐⭐ **Intermediate** — multiple operations or moderate parsing/orchestration
  - ⭐⭐⭐ **Advanced** — discovery, SSH key lifecycle, JIT elevation, dependent systems, file management, or other multi-step flows

## SSH Samples (`SSH/`)

Real tested SSH samples for Unix-like systems and appliances.

| Sample | Complexity | Use case |
| --- | --- | --- |
| [`GenericLinux.json`](SSH/GenericLinux.json) | ⭐⭐ | Baseline Linux local account management over interactive SSH, including SSH host key discovery. |
| [`GenericLinuxWithAD.json`](SSH/GenericLinuxWithAD.json) | ⭐⭐ | Linux SSH account management where the functional account logs in with a domain-qualified identity. |
| [`GenericLinuxWithDiscovery.json`](SSH/GenericLinuxWithDiscovery.json) | ⭐⭐⭐ | Extends the baseline Linux SSH flow with local account discovery. |
| [`GenericLinuxWithSSHKeySupport.json`](SSH/GenericLinuxWithSSHKeySupport.json) | ⭐⭐⭐ | Adds authorized_keys discovery, validation, and rotation to Linux SSH account management. |
| [`LinuxApplicationTextConfig.json`](SSH/LinuxApplicationTextConfig.json) | ⭐⭐⭐ | Rotates an application password stored in a Linux text configuration file over SSH. |
| [`LinuxSshBatchModeExample.json`](SSH/LinuxSshBatchModeExample.json) | ⭐⭐ | Uses remote SSH commands in batch mode instead of an interactive shell for Linux password operations. |
| [`RestrictedAuthorizedKeyExample.json`](SSH/RestrictedAuthorizedKeyExample.json) | ⭐⭐⭐ | Authenticates the service account with a restricted authorized key and passwordless sudo for Linux password operations. |
| [`vCenterServerAppliance.json`](SSH/vCenterServerAppliance.json) | ⭐⭐⭐ | Manages VMware vCenter Server Appliance local root and SSO accounts, including account discovery and synchronized password handling. |

> `LinuxApplicationTextConfig.json` is primarily a change-password example for file-based application credentials.

## HTTP Samples (`HTTP/`)

Real tested HTTP samples ranging from REST APIs to browser-form workflows.

| Sample | Complexity | Use case |
| --- | --- | --- |
| [`CustomFacebook.json`](HTTP/CustomFacebook.json) | ⭐⭐⭐ | Browser-form HTTP example for Facebook-style credential validation and password change workflows. |
| [`CustomTwitter.json`](HTTP/CustomTwitter.json) | ⭐⭐⭐ | Browser-form HTTP example for Twitter-style login, challenge handling, lock detection, and password changes. |
| [`Forgerock_OpenAM.json`](HTTP/Forgerock_OpenAM.json) | ⭐⭐ | ForgeRock AM 7.5 REST sample for system validation and password rotation. |
| [`Okta_WithDiscoveryAndGroupMembershipRestore.json`](HTTP/Okta_WithDiscoveryAndGroupMembershipRestore.json) | ⭐⭐⭐ | Okta REST sample with account discovery plus group membership restore during enable and disable operations. |
| [`OneLogin_GRC_JIT_addon.json`](HTTP/OneLogin_GRC_JIT_addon.json) | ⭐⭐⭐ | OneLogin add-on for account activation and JIT role elevation in a PIAM/PIdP flow. |
| [`WordPressHttp.json`](HTTP/WordPressHttp.json) | ⭐⭐ | WordPress REST API sample using Basic Auth for system checks, credential validation, and password change. |

## Telnet Samples (`Telnet/`)

Real tested Telnet and TN3270 samples for network devices and mainframes.

| Sample | Complexity | Use case |
| --- | --- | --- |
| [`GenericCiscoIosTelnet.json`](Telnet/GenericCiscoIosTelnet.json) | ⭐⭐⭐ | Cisco IOS Telnet sample for enable-mode validation and local or enable password rotation. |
| [`GenericRacfTn3270.json`](Telnet/GenericRacfTn3270.json) | ⭐⭐⭐ | IBM RACF TN3270 sample for mainframe logon validation and password changes. |

## Templates (`Templates/`)

The [`Templates/`](Templates/) folder contains illustrative scripts that help you design your own custom platform. These files are **not** tested against live targets.

### Pattern templates (`Pattern-*.json`)

Pattern templates show recommended approaches for specific scenarios.

| Sample | Complexity | Use case |
| --- | --- | --- |
| [`Pattern-GenericHttpAccountDiscovery.json`](Templates/Pattern-GenericHttpAccountDiscovery.json) | ⭐⭐ | Illustrates paginated REST API account discovery with `WriteDiscoveredAccount`. |
| [`Pattern-GenericHttpJitElevation.json`](Templates/Pattern-GenericHttpJitElevation.json) | ⭐⭐⭐ | Illustrates idempotent JIT elevation over HTTP by adding and removing group membership. |
| [`Pattern-GenericLinuxDependentSystem.json`](Templates/Pattern-GenericLinuxDependentSystem.json) | ⭐⭐⭐ | Illustrates `UpdateDependentSystem` over SSH with a caller-provided dependency command. |
| [`Pattern-GenericLinuxFileManagement.json`](Templates/Pattern-GenericLinuxFileManagement.json) | ⭐⭐⭐ | Illustrates `CheckFile` and `ChangeFile` over SSH, including decode, deploy, and verify steps. |
| [`Pattern-GenericLinuxFull.json`](Templates/Pattern-GenericLinuxFull.json) | ⭐⭐⭐ | Illustrates a comprehensive Linux SSH platform spanning password, SSH key, discovery, and enable/disable operations. |
| [`Pattern-GenericLinuxServiceDiscovery.json`](Templates/Pattern-GenericLinuxServiceDiscovery.json) | ⭐⭐ | Illustrates Linux service discovery over SSH with `WriteDiscoveredService`. |
| [`Pattern-GenericRestApiBasicAuth.json`](Templates/Pattern-GenericRestApiBasicAuth.json) | ⭐⭐ | Illustrates REST API management using HTTP Basic auth for check, change, and discovery workflows. |
| [`Pattern-GenericRestApiBearerToken.json`](Templates/Pattern-GenericRestApiBearerToken.json) | ⭐⭐ | Illustrates REST API management using OAuth2 client credentials and bearer tokens. |
| [`Pattern-GenericRestApiKeyRotation.json`](Templates/Pattern-GenericRestApiKeyRotation.json) | ⭐⭐⭐ | Illustrates API key validation and rotation through a REST API lifecycle. |
| [`Pattern-WindowsSshBasic.json`](Templates/Pattern-WindowsSshBasic.json) | ⭐⭐ | Illustrates Windows password management over SSH with PowerShell and `net user`. |

### Minimal starters (`Template*.json`)

Minimal starters give you the smallest possible scaffold for a new platform.

| Sample | Complexity | Use case |
| --- | --- | --- |
| [`TemplateHttpMinimal.json`](Templates/TemplateHttpMinimal.json) | ⭐ | Minimal HTTP starter that calls a health endpoint with a bearer token. |
| [`TemplateSshMinimal.json`](Templates/TemplateSshMinimal.json) | ⭐ | Minimal SSH starter that validates connectivity with a single echo command. |

For a folder-focused listing, see [Templates/README.md](Templates/README.md).

## Which Sample Should I Start With?

| I need to… | Start here |
| --- | --- |
| Manage a Linux system over SSH | [`GenericLinux.json`](SSH/GenericLinux.json) — the baseline for interactive SSH workflows |
| Add account discovery to Linux | [`GenericLinuxWithDiscovery.json`](SSH/GenericLinuxWithDiscovery.json) — extends the baseline with `DiscoverAccounts` |
| Manage SSH keys on Linux | [`GenericLinuxWithSSHKeySupport.json`](SSH/GenericLinuxWithSSHKeySupport.json) — authorized_keys lifecycle |
| Use SSH in batch mode (no interactive shell) | [`LinuxSshBatchModeExample.json`](SSH/LinuxSshBatchModeExample.json) |
| Manage a REST API with Basic Auth | [`WordPressHttp.json`](HTTP/WordPressHttp.json) — simple REST check/change pattern |
| Manage a REST API with tokens | [`Forgerock_OpenAM.json`](HTTP/Forgerock_OpenAM.json) — token-based REST workflow |
| Discover accounts via REST API | [`Okta_WithDiscoveryAndGroupMembershipRestore.json`](HTTP/Okta_WithDiscoveryAndGroupMembershipRestore.json) |
| Implement JIT privilege elevation | [`OneLogin_GRC_JIT_addon.json`](HTTP/OneLogin_GRC_JIT_addon.json) |
| Handle browser-form login flows | [`CustomFacebook.json`](HTTP/CustomFacebook.json) or [`CustomTwitter.json`](HTTP/CustomTwitter.json) |
| Manage a network device over Telnet | [`GenericCiscoIosTelnet.json`](Telnet/GenericCiscoIosTelnet.json) |
| Manage a mainframe (TN3270) | [`GenericRacfTn3270.json`](Telnet/GenericRacfTn3270.json) |
| Start from scratch (SSH) | [`TemplateSshMinimal.json`](Templates/TemplateSshMinimal.json) — smallest possible scaffold |
| Start from scratch (HTTP) | [`TemplateHttpMinimal.json`](Templates/TemplateHttpMinimal.json) — smallest possible scaffold |

## Samples by Feature (Advanced)

Features that only a few samples demonstrate — useful when you need a specific capability:

| Feature | Samples |
| --- | --- |
| Account discovery (`DiscoverAccounts`) | [`GenericLinuxWithDiscovery.json`](SSH/GenericLinuxWithDiscovery.json), [`vCenterServerAppliance.json`](SSH/vCenterServerAppliance.json), [`Okta_WithDiscoveryAndGroupMembershipRestore.json`](HTTP/Okta_WithDiscoveryAndGroupMembershipRestore.json) |
| SSH key rotation (`CheckSshKey` / `ChangeSshKey`) | [`GenericLinuxWithSSHKeySupport.json`](SSH/GenericLinuxWithSSHKeySupport.json) |
| SSH key discovery (`DiscoverAuthorizedKeys`) | [`GenericLinuxWithSSHKeySupport.json`](SSH/GenericLinuxWithSSHKeySupport.json) |
| Enable / Disable account | [`Okta_WithDiscoveryAndGroupMembershipRestore.json`](HTTP/Okta_WithDiscoveryAndGroupMembershipRestore.json), [`OneLogin_GRC_JIT_addon.json`](HTTP/OneLogin_GRC_JIT_addon.json) |
| JIT elevation (`ElevateAccount` / `DemoteAccount`) | [`OneLogin_GRC_JIT_addon.json`](HTTP/OneLogin_GRC_JIT_addon.json) |
| Dependent systems (`UpdateDependentSystem`) | Pattern: [`Pattern-GenericLinuxDependentSystem.json`](Templates/Pattern-GenericLinuxDependentSystem.json) |
| File management (`CheckFile` / `ChangeFile`) | Pattern: [`Pattern-GenericLinuxFileManagement.json`](Templates/Pattern-GenericLinuxFileManagement.json) |
| Service discovery (`DiscoverServices`) | Pattern: [`Pattern-GenericLinuxServiceDiscovery.json`](Templates/Pattern-GenericLinuxServiceDiscovery.json) |
| API key rotation (`CheckApiKey` / `ChangeApiKey`) | Pattern: [`Pattern-GenericRestApiKeyRotation.json`](Templates/Pattern-GenericRestApiKeyRotation.json) |
