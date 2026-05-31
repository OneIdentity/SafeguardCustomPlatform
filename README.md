# Safeguard Custom Platform Scripts

Build custom platform scripts for [Safeguard for Privileged Passwords (SPP)](https://www.oneidentity.com/products/safeguard-for-privileged-passwords/) when built-in platforms don't cover your target system.

Custom platform scripts are JSON definitions that teach SPP how to connect to any target — Linux hosts, network appliances, REST APIs, web portals, cloud services — and manage credentials (passwords, SSH keys, API keys) through SSH, HTTP, or Telnet.

## Where Do I Start?

| I want to... | Go here |
| --- | --- |
| **Get something working in 5 minutes** | [Quick Start](docs/quick-start/) |
| **Understand how custom platforms work** | [Concepts](docs/concepts/) |
| **Learn step by step with a tutorial** | [Tutorials](docs/tutorials/) |
| **Look up a specific command or parameter** | [Reference](docs/reference/) |
| **Deploy a tested sample script** | [Samples](samples/) |
| **Start a new script from a template** | [Templates](templates/) |
| **Solve a specific problem** | [Guides](docs/guides/) |

## Repository Layout

```
docs/
  quick-start/     5-minute guides to get a working platform fast
  concepts/        Architecture, execution model, feature flags
  tutorials/       Step-by-step walkthroughs for building scripts
  guides/          Task-focused how-to content (SSH patterns, HTTP patterns, etc.)
  reference/       Commands, operations, parameters, variables
samples/           Production-tested scripts with companion documentation
  ssh/             Linux, Unix, appliance samples
  http/            REST API, OAuth2, form-based samples
  telnet/          Cisco IOS, IBM RACF TN3270 samples
templates/         Pattern templates and minimal starters (not tested against live targets)
schema/            JSON Schema for IDE autocomplete
tools/             TestTool.ps1 for local validation
```

## Quick Start

```powershell
# Clone the repo
git clone https://github.com/OneIdentity/SafeguardCustomPlatform.git
cd SafeguardCustomPlatform

# Pick a template and customize it
code templates/TemplateSshMinimal.json

# Upload to SPP
Import-SafeguardCustomPlatformScript -FilePath .\MyPlatform.json

# Test
Test-SafeguardAssetAccountPassword -AssetToUse "MyHost" -AccountToUse "admin" -ExtendedLogging
```

For detailed quick-start paths, see [docs/quick-start/](docs/quick-start/).

## Tools

- [`tools/TestTool.ps1`](tools/TestTool.ps1) — Validate script JSON locally before uploading to SPP
- [`schema/custom-platform-script.schema.json`](schema/custom-platform-script.schema.json) — JSON Schema for IDE autocomplete (VS Code configured automatically)

## Contributing

Contributions are welcome — new sample scripts, documentation improvements, and bug fixes. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Support

One Identity open source projects are supported through [GitHub issues](https://github.com/OneIdentity/SafeguardCustomPlatform/issues) and the [One Identity Community](https://www.oneidentity.com/community/). This includes all scripts, plugins, SDKs, modules, code snippets, and other solutions. For assistance with this project, please open a new issue in this repository or ask a question in the One Identity Community. Requests for assistance made through official One Identity Support will be referred back to GitHub and the One Identity Community forums where those requests can benefit all users.

## License

See [LICENSE](LICENSE).
