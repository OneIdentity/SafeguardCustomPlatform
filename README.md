# Safeguard Custom Platform Scripts

Build and adapt custom platform scripts for Safeguard when built-in platforms do not fit your target system.

## What is this?

Safeguard custom platform scripts are JSON-based definitions that tell Safeguard for Privileged Passwords (SPP) how to connect to a target, navigate its interface, and perform credential operations such as password changes, key updates, and account validation.

This repository is for asset administrators and automation teams who need to manage passwords or SSH keys on operating systems, appliances, network devices, web applications, or vendor-specific workflows not covered by built-in platforms. It includes practical guidance and examples for both SSH- and HTTP-based integrations, plus historical Telnet-related content.

## Quick Start

If you want the docs and samples locally while you work, clone the repository first:

```powershell
git clone https://github.com/OneIdentity/SafeguardCustomPlatform.git
cd SafeguardCustomPlatform
```

1. **Write.** Start with the closest template in `SampleScripts/Templates/`, then customize commands, prompts, parameters, and validation flow for your target.
2. **Upload.** Use `Import-SafeguardCustomPlatformScript` from `safeguard-ps` to upload the script to SPP.
3. **Test.** Validate against a safe test asset with `Test-SafeguardAssetAccountPassword -ExtendedLogging` before rolling into production.

## Documentation

Start with [`docs/`](docs/) to find the right level of detail for your task:

- [`docs/getting-started/`](docs/getting-started/) - Tutorials and first-script walkthroughs for new custom platform authors.
- [`docs/reference/`](docs/reference/) - Script structure, supported operations, parameters, and command behavior.
- [`docs/guides/`](docs/guides/) - SSH patterns, HTTP patterns, and advanced implementation topics.
- [`docs/guides/feature-flags.md`](docs/guides/feature-flags.md) - Understand which operations and capabilities your platform advertises.
- [`docs/guides/troubleshooting.md`](docs/guides/troubleshooting.md) - Common errors, diagnostic tips, and fixes.

## Compatibility Matrix

> Approximate only — check your SPP release notes for exact availability in your build.

| SPP Version | Custom Platform Feature Added |
| --- | --- |
| 6.0 | Custom platforms introduced (SSH, Telnet) |
| 6.7 | HTTP/REST custom platforms added |
| 7.0 | `DiscoverAccounts` |
| 7.0 | `DiscoverServices` |
| 7.0 | `DiscoverSshHostKey` |
| 7.4 | `ExecuteCommand` (SSH batch mode) |
| 7.4 | `ExecuteDependentCommand` (dependent system workflows) |
| 7.5 | `ElevateAccount` / `DemoteAccount` |
| 7.5 | `EnableAccount` / `DisableAccount` |
| 7.6 | `CheckFile` / `ChangeFile` |

## Sample Scripts

Browse [`SampleScripts/`](SampleScripts/) for working examples you can study or adapt. Samples are organized by protocol so you can quickly focus on the right category:

- SSH
- HTTP
- Telnet

## Tools

Use [`tools/TestTool.ps1`](tools/TestTool.ps1) to test custom platform scripts locally before uploading them to SPP.

## Telnet / Pattern Files

Telnet pattern files have moved to [SafeguardAutomation](https://github.com/OneIdentity/SafeguardAutomation/tree/master/Terminal%20Pattern%20Files).

## Contributing

Contributions are welcome, including new sample scripts, fixes, and documentation improvements. See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines, and feel free to share community-tested samples that others can adapt.

## Support

One Identity open source projects are supported through [GitHub issues](https://github.com/OneIdentity/SafeguardCustomPlatform/issues) and the [One Identity Community](https://www.oneidentity.com/community/). This includes all scripts, plugins, SDKs, modules, code snippets, and other solutions. For assistance with this project, please open a new issue in this repository or ask a question in the One Identity Community. Requests for assistance made through official One Identity Support will be referred back to GitHub and the One Identity Community forums where those requests can benefit all users.

## License

See [LICENSE](LICENSE).
