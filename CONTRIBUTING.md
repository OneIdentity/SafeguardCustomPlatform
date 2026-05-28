# Contributing to SafeguardCustomPlatform

Thank you for helping improve SafeguardCustomPlatform. We welcome new sample scripts, documentation improvements, bug fixes, and feature requests.

## Getting Started

1. Fork this repository on GitHub.
2. Clone your fork locally.
3. Create a feature branch for one logical change.
4. Make and test your changes.
5. Submit a pull request.

```powershell
git clone https://github.com/<your-account>/SafeguardCustomPlatform.git
cd SafeguardCustomPlatform
git checkout -b my-change
```

## Contributing Sample Scripts

- Add new scripts under `SampleScripts/` in the correct protocol folder:
  - `SampleScripts/SSH/`
  - `SampleScripts/HTTP/`
  - `SampleScripts/Telnet/`
- Follow the JSON structure in [docs/reference/script-structure.md](docs/reference/script-structure.md).
- Include the standard operations your target supports whenever possible. At minimum, include `CheckSystem` (the operation behind **Test Connection**) and `CheckPassword`, unless accounts change their own passwords on that platform (in which case `CheckSystem` may not apply).
- Use meaningful parameter names and sensible defaults.
- Use the `Comment` command to explain non-obvious logic.
- Test against a real SPP instance before submitting.
- During development, validate locally with `Test-SafeguardCustomPlatformScript` and use `Import-SafeguardCustomPlatformScript` when you need to upload a revised script to SPP. See [docs/getting-started/testing-and-debugging.md](docs/getting-started/testing-and-debugging.md).

## Script Conventions

- JSON must be valid: no trailing commas, proper escaping, and correct data types.
- Use descriptive function names such as `ConnectSsh` and `ChangePasswordSsh`, not placeholder names like `func1`.
- Use the `Global:` prefix for connection or response objects that must be shared across functions.
- Always include `Disconnect` in cleanup paths for SSH or Telnet sessions.
- Handle error conditions explicitly: check command results, validate responses, and fail with a clear reason when needed.
- Include `Timeout` parameters with reasonable defaults.
- Mask sensitive values with `ContainsSecret: true` or `OutputContainsSecret: true` where appropriate.
- Prefer readable, maintainable logic over clever shortcuts.

## Documentation Contributions

- Documentation lives in `docs/`.
- Follow the existing markdown style and heading structure used in the repo.
- Cross-link to related reference pages when you add or update documentation.
- Never use internal codenames in customer-facing documentation.
- If you update script behavior or conventions, update the related reference or guide page in the same pull request when possible.

## Pull Request Process

- Describe what changed and why.
- Reference any related GitHub issues.
- Keep pull requests focused; one logical change per PR is preferred.
- Make sure JSON is valid before opening the PR. CI will check this, but please validate locally first.
- If your change affects script authoring guidance, include the related documentation update.

## Reporting Issues

Please use [GitHub Issues](https://github.com/OneIdentity/SafeguardCustomPlatform/issues) for bugs and feature requests.

When reporting a problem, include:

- SPP version
- A sanitized script excerpt
- The error message
- Expected behavior
- Actual behavior

If possible, also include the operation you ran and any relevant `Get-SafeguardTaskLog` output with secrets removed.

## Code of Conduct

Please be respectful, constructive, and patient in all discussions and reviews. We want this repository to be welcoming to everyone who is trying to learn, contribute, or help others.
