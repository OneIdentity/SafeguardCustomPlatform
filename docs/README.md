# Safeguard Custom Platform Documentation

This documentation hub helps you learn, build, and maintain Safeguard Custom Platform scripts. Start here for onboarding material, detailed references, and task-focused guides.

## Suggested Reading Order

1. [Overview](getting-started/overview.md) — Learn the architecture, execution model, and when a custom platform is the right fit.
2. [First Tutorial](getting-started/your-first-ssh-script.md) — Build your first SSH-based script step by step.
3. [Script Structure](reference/script-structure.md) — Understand the JSON layout, operations, and `Do` blocks used by every script.
4. [Operations Reference](reference/operations.md) — Review the supported operations available when implementing a platform.

## Getting Started

| Document | Description |
| --- | --- |
| [getting-started/overview.md](getting-started/overview.md) | Architecture, script execution flow, and guidance on whether you need a custom platform. |
| [getting-started/your-first-ssh-script.md](getting-started/your-first-ssh-script.md) | Step-by-step tutorial for creating your first SSH custom platform script. |
| [getting-started/your-first-http-script.md](getting-started/your-first-http-script.md) | Step-by-step tutorial for creating your first HTTP custom platform script (REST API). |
| [getting-started/your-first-form-script.md](getting-started/your-first-form-script.md) | Step-by-step tutorial for managing passwords on web portals with HTML form submission. |
| [getting-started/development-workflow.md](getting-started/development-workflow.md) | End-to-end workflow from upload through testing and iteration. |
| [getting-started/testing-and-debugging.md](getting-started/testing-and-debugging.md) | Test tools, logs, and `extendedLogging` techniques for troubleshooting. |

## Reference

| Document | Description |
| --- | --- |
| [reference/script-structure.md](reference/script-structure.md) | JSON structure, top-level keys, operations, and `Do` blocks. |
| [reference/operations.md](reference/operations.md) | Reference for all supported operations. |
| [reference/reserved-parameters.md](reference/reserved-parameters.md) | Complete reference for reserved platform parameters. |
| [reference/custom-parameters.md](reference/custom-parameters.md) | How to define and use your own custom parameters. |
| [reference/variables.md](reference/variables.md) | Variable system reference for reading, setting, and reusing values. |
| [reference/commands/](reference/commands/) | Command reference organized by category. |
| [reference/imports.md](reference/imports.md) | Reusable SSH function libraries and import patterns. |
| [reference/status-messages.md](reference/status-messages.md) | Predefined status messages available to scripts. |

## Guides

| Document | Description |
| --- | --- |
| [guides/ssh-platforms.md](guides/ssh-platforms.md) | SSH design patterns and session integration guidance. |
| [guides/http-platforms.md](guides/http-platforms.md) | REST, OAuth2, and Bearer token implementation patterns. |
| [guides/account-discovery.md](guides/account-discovery.md) | Guidance for discovering accounts through custom platforms. |
| [guides/ssh-key-management.md](guides/ssh-key-management.md) | Patterns for checking, changing, and discovering SSH keys. |
| [guides/api-key-management.md](guides/api-key-management.md) | Approaches for API key rotation workflows. |
| [guides/file-management.md](guides/file-management.md) | Working with file-based credentials and related operations. |
| [guides/jit-elevation.md](guides/jit-elevation.md) | Implementing JIT elevation and demotion scenarios. |
| [guides/dependent-systems.md](guides/dependent-systems.md) | Updating dependent systems as part of platform workflows. |
| [guides/error-handling.md](guides/error-handling.md) | Try/Catch patterns for reliable error handling. |
| [guides/regex-patterns.md](guides/regex-patterns.md) | Practical .NET regex patterns for prompts, parsing, and error detection. |
| [guides/feature-flags.md](guides/feature-flags.md) | How script content enables and shapes platform capabilities. |
| [guides/troubleshooting.md](guides/troubleshooting.md) | Common errors, diagnostics, and recommended fixes. |

## Additional Resources

| Resource | Description |
| --- | --- |
| [SampleScripts](../SampleScripts/) | Working examples you can use as references when building scripts. |
| [TestTool.ps1](../tools/TestTool.ps1) | Local test tool for validating and iterating on platform scripts. |
| [One Identity Support](https://support.oneidentity.com/) | General Safeguard product documentation, downloads, and support resources. |
