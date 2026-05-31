[← Home](../README.md)

# Sample Scripts

Production-tested custom platform scripts you can deploy to SPP or study as reference implementations. Each sample includes a companion README explaining what it does, how to set it up, and how to deploy it.

## Samples by Protocol

| Protocol | Samples | Description |
| --- | --- | --- |
| [SSH](ssh/) | 8 samples | Linux, Unix, and appliance management over interactive or batch SSH. |
| [HTTP](http/) | 6 samples | REST APIs, OAuth2, browser-form workflows, and cloud services. |
| [Telnet](telnet/) | 2 samples | Network devices (Cisco IOS) and mainframes (IBM RACF TN3270). |

## How to Use a Sample

1. **Browse** the protocol directory that matches your target system.
2. **Read the README** in the sample's folder to understand prerequisites and setup.
3. **Download** the JSON file (or clone this repository).
4. **Upload** to SPP:
   ```powershell
   Import-SafeguardCustomPlatformScript -FilePath .\SampleScript.json
   ```
5. **Create an asset** using the custom platform and configure accounts.
6. **Test** with `ExtendedLogging` before production use.

## Samples vs. Templates

| | Samples (`samples/`) | Templates (`templates/`) |
| --- | --- | --- |
| **Tested** | ✅ Tested against real target systems | ❌ Not tested against live targets |
| **Purpose** | Deploy to production (with customization) | Learn patterns and start new scripts |
| **Completeness** | Full implementations with error handling | Illustrative — may omit edge cases |

If you want a starting point for a new platform rather than a deployable sample, see [Templates](../templates/).

## Quick Reference: Which Sample Do I Need?

| I need to... | Start here |
| --- | --- |
| Manage Linux local accounts (SSH) | [generic-linux](ssh/generic-linux/) |
| Add account discovery to Linux | [generic-linux-with-discovery](ssh/generic-linux-with-discovery/) |
| Manage SSH keys on Linux | [generic-linux-ssh-keys](ssh/generic-linux-ssh-keys/) |
| Use SSH batch mode (no interactive shell) | [linux-ssh-batch-mode](ssh/linux-ssh-batch-mode/) |
| Manage a REST API with Basic Auth | [wordpress](http/wordpress/) |
| Manage a REST API with tokens (OAuth2) | [forgerock-openam](http/forgerock-openam/) |
| Discover accounts via REST API | [okta-discovery](http/okta-discovery/) |
| Implement JIT privilege elevation | [onelogin-jit](http/onelogin-jit/) |
| Handle browser-form login flows | [facebook](http/facebook/) or [twitter](http/twitter/) |
| Manage a Cisco IOS device (Telnet) | [cisco-ios](telnet/cisco-ios/) |
| Manage an IBM mainframe (TN3270) | [racf-tn3270](telnet/racf-tn3270/) |
