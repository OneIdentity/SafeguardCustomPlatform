# Reference

Detailed reference documentation for every aspect of custom platform scripts. Use this section when you need to look up a specific command, parameter, operation, or behavior.

## Core References

| Document | Description |
| --- | --- |
| [Script Structure](script-structure.md) | JSON layout, top-level keys, operations, `Do` blocks, and functions. |
| [Operations](operations.md) | All 19 operations with credential contexts and feature flags. |
| [Reserved Parameters](reserved-parameters.md) | Parameters SPP auto-populates (72 parameters documented). |
| [Custom Parameters](custom-parameters.md) | Defining your own parameters with types, defaults, and UI behavior. |
| [Variables](variables.md) | Variable interpolation, scope rules, and the expression engine. |
| [Status Messages](status-messages.md) | Predefined status messages available to scripts. |
| [Imports](imports.md) | Reusable SSH function libraries and the import catalog. |
| [Compatibility](compatibility.md) | Which features are available in which SPP versions. |

## Command Reference

The [Commands](commands/) section documents every command available in `Do` blocks, organized by category:

| Category | Commands | Page |
| --- | --- | --- |
| HTTP | `Request`, `NewHttpRequest`, `BaseAddress`, `Headers`, `HttpAuth`, cookies, forms, JSON, encoding | [commands/](commands/index.md) |
| SSH/Telnet | `Connect`, `Disconnect`, `Send`, `Receive`, `ExecuteCommand`, `DiscoverSshHostKey` | [commands/](commands/index.md) |
| Flow Control | `Condition`, `Switch`, `For`, `ForEach` | [commands/](commands/index.md) |
| Functions | `Function`, `Return`, `Break`, `Eval` | [commands/](commands/index.md) |
| Error Handling | `Try`, `Throw` | [commands/](commands/index.md) |
| Utilities | `SetItem`, `Declare`, `Split`, `Comment` | [commands/](commands/index.md) |
| Output | `WriteDiscoveredAccount`, `WriteDiscoveredService`, `WriteDiscoveredSshKey`, `WriteResponseObject` | [commands/](commands/index.md) |
| Logging | `Log`, `Status`, `Wait` | [commands/](commands/index.md) |
| Dependencies | `ExecuteDependentCommand` | [commands/](commands/index.md) |

See [commands/index.md](commands/index.md) for the full navigable reference.
