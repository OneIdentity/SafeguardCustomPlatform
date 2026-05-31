[← Repository README](../README.md)

# Templates

The files in `templates/` are **illustrative patterns and starter scaffolds**, not production-ready scripts. They are intentionally lightweight and are **not** presented as tested integrations for live targets. Use them to understand structure, common Safeguard operations, and recommended implementation approaches before you build your own platform.

## What is in this folder?

- **Pattern templates** (`Pattern-*.json`) show recommended approaches for specific scenarios such as REST account discovery, JIT elevation, Linux file management, dependent systems, and API key rotation.
- **Minimal starters** (`Template*.json`) provide the smallest scaffold to begin from when you want a clean base and plan to add operations yourself.

## How to use these templates

1. **Choose the closest starting point.** Pick a minimal starter for a blank scaffold, or a pattern template when one already matches your target workflow.
2. **Copy it to a new script.** Keep the original template unchanged and work in your own file.
3. **Customize it for your target.** Replace commands, endpoints, authentication, parsing, prompts, regex, parameters, and error handling.
4. **Validate and test it.** Review [script structure](../docs/reference/script-structure.md), [operations](../docs/reference/operations.md), and the [development workflow](../docs/guides/development-workflow.md). Then validate locally and test only against safe non-production assets with [testing and debugging guidance](../docs/guides/testing-and-debugging.md).
5. **Deploy after verification.** Import the finished script into SPP only after it behaves consistently in your environment.

## Recommended documentation

- [Documentation hub](../docs/README.md)
- [Script structure](../docs/reference/script-structure.md)
- [Operations reference](../docs/reference/operations.md)
- [Development workflow](../docs/guides/development-workflow.md)
- [Testing and debugging](../docs/guides/testing-and-debugging.md)
- [SSH platforms](../docs/guides/ssh-platforms.md)
- [HTTP platforms](../docs/guides/http-platforms.md)

## Template catalog

| File | Type | Description | Key operations | Related docs |
| --- | --- | --- | --- | --- |
| `Pattern-GenericHttpAccountDiscovery.json` | Pattern | Paginated REST account discovery using `WriteDiscoveredAccount`. Adapt authentication, endpoint shape, and response parsing to your target API. | `CheckSystem`, `DiscoverAccounts` | [HTTP platforms](../docs/guides/http-platforms.md), [Account discovery](../docs/guides/account-discovery.md) |
| `Pattern-GenericHttpJitElevation.json` | Pattern | Idempotent JIT elevation and demotion over REST, modeled as add/remove group membership or equivalent privilege assignment. | `CheckSystem`, `ElevateAccount`, `DemoteAccount` | [HTTP platforms](../docs/guides/http-platforms.md), [JIT elevation](../docs/guides/jit-elevation.md) |
| `Pattern-GenericLinuxDependentSystem.json` | Pattern | SSH pattern for updating a dependent system after a primary credential change, using a caller-provided dependency command. | `CheckSystem`, `UpdateDependentSystem` | [SSH platforms](../docs/guides/ssh-platforms.md), [Dependent systems](../docs/guides/dependent-systems.md) |
| `Pattern-GenericLinuxFileManagement.json` | Pattern | SSH file-management pattern that checks, deploys, and verifies file content, including base64 decode and validation steps. | `CheckSystem`, `CheckFile`, `ChangeFile` | [SSH platforms](../docs/guides/ssh-platforms.md), [File management](../docs/guides/file-management.md) |
| `Pattern-GenericLinuxFull.json` | Pattern | Broad Linux SSH starting point that combines password management, SSH key management, account discovery, host key discovery, and enable/disable flows in one script. | `CheckSystem`, `CheckPassword`, `ChangePassword`, `CheckSshKey`, `ChangeSshKey`, `DiscoverAccounts`, `DiscoverSshHostKey`, `EnableAccount`, `DisableAccount` | [SSH platforms](../docs/guides/ssh-platforms.md), [SSH key management](../docs/guides/ssh-key-management.md), [Account discovery](../docs/guides/account-discovery.md) |
| `Pattern-GenericLinuxServiceDiscovery.json` | Pattern | SSH service-discovery pattern that queries `systemd` and emits results with `WriteDiscoveredService`. | `CheckSystem`, `DiscoverServices` | [SSH platforms](../docs/guides/ssh-platforms.md), [Operations reference](../docs/reference/operations.md) |
| `Pattern-GenericRestApiBasicAuth.json` | Pattern | REST API management with HTTP Basic authentication for connectivity, password validation, password change, and account discovery. | `CheckSystem`, `CheckPassword`, `ChangePassword`, `DiscoverAccounts` | [HTTP platforms](../docs/guides/http-platforms.md), [Account discovery](../docs/guides/account-discovery.md) |
| `Pattern-GenericRestApiBearerToken.json` | Pattern | REST API management with OAuth2 client credentials and bearer tokens for connectivity and password operations. | `CheckSystem`, `CheckPassword`, `ChangePassword` | [HTTP platforms](../docs/guides/http-platforms.md), [Your first HTTP script](../docs/tutorials/your-first-http-script.md) |
| `Pattern-GenericRestApiKeyRotation.json` | Pattern | REST API key validation and rotation workflow that you can adapt to your target system's key lifecycle and rollback needs. | `CheckSystem`, `CheckApiKey`, `ChangeApiKey` | [HTTP platforms](../docs/guides/http-platforms.md), [API key management](../docs/guides/api-key-management.md) |
| `Pattern-WindowsSshBasic.json` | Pattern | Windows password management over OpenSSH using PowerShell and `net user`, for environments that use SSH instead of WinRM. | `CheckSystem`, `CheckPassword`, `ChangePassword` | [SSH platforms](../docs/guides/ssh-platforms.md), [Operations reference](../docs/reference/operations.md) |
| `TemplateHttpMinimal.json` | Minimal starter | Smallest HTTP scaffold: a `CheckSystem` example that calls a health endpoint with a bearer token. Use it when you want to design your own HTTP workflow from scratch. | `CheckSystem` | [Your first HTTP script](../docs/tutorials/your-first-http-script.md), [Script structure](../docs/reference/script-structure.md) |
| `TemplateSshMinimal.json` | Minimal starter | Smallest SSH scaffold: connect, run a simple echo-style command, and disconnect in `CheckSystem`. Use it as a clean base for SSH-driven platforms. | `CheckSystem` | [Your first SSH script](../docs/tutorials/your-first-ssh-script.md), [Script structure](../docs/reference/script-structure.md) |

## Need working examples instead?

If you want fuller examples to study after you understand the patterns here, see:

- [`samples/ssh/`](../samples/ssh/)
- [`samples/http/`](../samples/http/)
- [`samples/telnet/`](../samples/telnet/)
