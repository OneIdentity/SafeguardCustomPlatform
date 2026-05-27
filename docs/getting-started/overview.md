# Architecture Overview

Safeguard custom platform scripts let you teach Safeguard for Privileged Passwords (SPP) how to work with systems that do not fit a built-in platform.

## 1. What Are Custom Platform Scripts?

Custom platform scripts are JSON-based definitions that instruct Safeguard how to communicate with a target system and perform credential management operations such as password verification, password changes, SSH key rotation, account discovery, and related tasks.

They support both SSH- and HTTP-based integrations, which makes them useful for operating systems, network devices, appliances, web applications, cloud services, and proprietary systems.

## 2. How Scripts Are Executed (Architecture)

From an administrator's point of view, the flow looks like this:

1. You write a JSON script that defines one or more operations, such as `CheckPassword` or `ChangePassword`.
2. You upload the script to SPP by using the web UI or API.
3. SPP validates the script by checking its JSON structure, parameter types, and references to functions or commands.
4. If the script references built-in function libraries through `Imports`, SPP merges those reusable script functions into your script automatically.
5. SPP reads the validated script and derives the platform's capabilities from the operations and parameters you defined.
6. The platform is saved with computed feature flags, so you never configure capabilities manually.
7. When a task runs, such as a scheduled password change, SPP passes the relevant parameters to the script engine.
8. The script engine executes the selected operation's `Do` block against the target system.

**Key concept:** feature flags are automatic. Your script content is the platform definition. If you add `ChangePassword`, SPP knows the platform can change passwords. If you add `DiscoverAccounts`, SPP enables account discovery. There is no separate capability switch to configure.

## 3. Do You Need a Custom Platform?

Use a custom platform when:

- Your target system uses SSH or HTTP but is not covered by a built-in platform.
- You need to manage credentials on a proprietary appliance, homegrown application, or cloud API.
- You need custom logic such as multi-step authentication, pagination, or conditional flows.
- You need to integrate with a system that exposes a REST API for credential management.

Consider alternatives when:

- A built-in platform already supports your target system.
- Your target is supported by a Starling Connect connector.
- You only need session recording without credential management, where SPS alone may be enough.

## 4. Supported Operations (Overview)

The following operation categories are available for custom platforms. Detailed behavior belongs in the reference documentation.

| Category | Operations |
| --- | --- |
| Connection | `CheckSystem` |
| Password | `CheckPassword`, `ChangePassword` |
| SSH Keys | `CheckSshKey`, `ChangeSshKey`, `DiscoverSshHostKey`, `RetrieveSshHostKey`, `DiscoverAuthorizedKeys`, `RemoveAuthorizedKey` |
| Discovery | `DiscoverAccounts`, `DiscoverServices` |
| JIT Access | `ElevateAccount`, `DemoteAccount`, `EnableAccount`, `DisableAccount` |
| Dependencies | `UpdateDependentSystem` |
| API Keys | `CheckApiKey`, `ChangeApiKey` |
| Files | `CheckFile`, `ChangeFile` |

All operations listed above are fully supported for custom platforms.

## 5. Key Concepts

| Concept | Meaning |
| --- | --- |
| Operations | Named entry points in your script, such as `CheckPassword` or `ChangePassword`. |
| Do blocks | The sequence of commands that runs for an operation. |
| Reserved parameters | Parameters with special names that SPP fills automatically, such as `AccountPassword` or `AssetAddress`. |
| Custom parameters | Parameters you define for asset-specific or platform-specific configuration. |
| Commands | Individual instructions inside a `Do` block, such as `Connect`, `Send`, or `Request`. |
| Imports | Built-in function libraries you can reference to reuse common scripting logic across platforms. |
| Feature flags | Platform capabilities that SPP derives from your script content. You never set them manually. |

## 6. Next Steps

- [Your First SSH Script](your-first-ssh-script.md)
- [Your First HTTP Script](your-first-http-script.md)
- [Development Workflow](development-workflow.md)
- [Script Structure Reference](../reference/script-structure.md)
