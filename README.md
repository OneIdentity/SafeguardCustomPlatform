# Safeguard Custom Platform Scripts

Build and adapt custom platform scripts for Safeguard when built-in platforms do not fit your target system.

## What is this?

Safeguard custom platform scripts are JSON-based definitions that tell Safeguard for Privileged Passwords (SPP) how to connect to a target, navigate its interface, and perform credential operations such as password changes, key updates, and account validation.

This repository is for asset administrators and automation teams who need to manage passwords or SSH keys on operating systems, appliances, network devices, web applications, or vendor-specific workflows not covered by built-in platforms. It includes practical guidance and examples for both SSH- and HTTP-based integrations, plus historical Telnet-related content.

## Quick Start

1. **Clone the repository.** Download the repo locally so you can review the documentation, compare samples, and edit scripts safely.

   ```powershell
   git clone https://github.com/OneIdentity/SafeguardCustomPlatform.git
   cd SafeguardCustomPlatform
   ```

2. **Pick a template from `SampleScripts/Templates/`.** Start with the closest template for your target so you inherit the right protocol and operation flow, then use the other samples in `SampleScripts/` for reference as needed.

3. **Customize for your target.** Update commands, prompts, parameters, and validation behavior to match the system or application you need Safeguard to manage.

4. **Upload to SPP.** Import the finished script into Safeguard for Privileged Passwords (SPP) and associate it with the asset or platform you want to manage.

5. **Test.** Validate the script against a safe test asset first, then confirm the full credential lifecycle works as expected before rolling it into production.

## Documentation

Start with [`docs/`](docs/) to find the right level of detail for your task:

- [`docs/getting-started/`](docs/getting-started/) - Tutorials and first-script walkthroughs for new custom platform authors.
- [`docs/reference/`](docs/reference/) - Script structure, supported operations, parameters, and command behavior.
- [`docs/guides/`](docs/guides/) - SSH patterns, HTTP patterns, and advanced implementation topics.

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

See `CONTRIBUTING.md` for contribution guidelines.

## Support

One Identity open source projects are supported through [GitHub issues](https://github.com/OneIdentity/SafeguardCustomPlatform/issues) and the [One Identity Community](https://www.oneidentity.com/community/). This includes all scripts, plugins, SDKs, modules, code snippets, and other solutions. For assistance with this project, please open a new issue in this repository or ask a question in the One Identity Community. Requests for assistance made through official One Identity Support will be referred back to GitHub and the One Identity Community forums where those requests can benefit all users.

## License

See [LICENSE](LICENSE).
