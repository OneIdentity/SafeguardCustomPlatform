# Guides

Task-focused how-to documentation for building and maintaining custom platforms. Each guide covers a specific topic in depth.

## Development

| Guide | Description |
| --- | --- |
| [Development Workflow](development-workflow.md) | End-to-end workflow from authoring through upload, testing, and iteration. |
| [Testing and Debugging](testing-and-debugging.md) | Test tools, task logs, `ExtendedLogging`, and diagnostic techniques. |
| [Error Handling](error-handling.md) | Try/Catch patterns for reliable error recovery in scripts. |
| [Regex Patterns](regex-patterns.md) | Practical .NET regex patterns for prompts, parsing, and error detection. |
| [Troubleshooting](troubleshooting.md) | Common errors, diagnostics, and recommended fixes. |

## SSH Platforms

| Guide | Description |
| --- | --- |
| [SSH Platforms](ssh-platforms.md) | SSH design patterns: interactive vs. batch, login flows, prompt detection. |
| [SSH Key Management](ssh-key-management.md) | Checking, changing, and discovering SSH authorized keys. |

## HTTP Platforms

| Guide | Description |
| --- | --- |
| [HTTP Platforms](http-platforms.md) | REST, OAuth2, Bearer tokens, forms, and cookie-based workflows. |
| [API Key Management](api-key-management.md) | API key validation and rotation patterns. |

## Advanced Features

| Guide | Description |
| --- | --- |
| [Account Discovery](account-discovery.md) | Implementing `DiscoverAccounts` and `DiscoverServices` operations. |
| [File Management](file-management.md) | Working with file-based credentials (`CheckFile`/`ChangeFile`). |
| [JIT Elevation](jit-elevation.md) | Implementing just-in-time privilege elevation and demotion. |
| [Dependent Systems](dependent-systems.md) | Updating dependent systems as part of credential rotation workflows. |
