[← Samples](../README.md)

# SSH Samples

Tested custom platform scripts for managing systems over SSH. These samples cover interactive expect-style patterns and batch-mode execution.

| Sample | Complexity | Target System |
| --- | --- | --- |
| [generic-linux](generic-linux/) | ⭐⭐ | Standard Linux (local accounts, interactive SSH) |
| [generic-linux-with-ad](generic-linux-with-ad/) | ⭐⭐ | Linux with AD domain-qualified service account |
| [generic-linux-with-discovery](generic-linux-with-discovery/) | ⭐⭐⭐ | Linux with local account discovery |
| [generic-linux-ssh-keys](generic-linux-ssh-keys/) | ⭐⭐⭐ | Linux with SSH authorized key lifecycle |
| [linux-app-text-config](linux-app-text-config/) | ⭐⭐⭐ | Application passwords in text config files |
| [linux-ssh-batch-mode](linux-ssh-batch-mode/) | ⭐⭐ | Linux using batch-mode SSH (no interactive shell) |
| [restricted-authorized-key](restricted-authorized-key/) | ⭐⭐⭐ | Linux with restricted key + passwordless sudo |
| [vcenter-appliance](vcenter-appliance/) | ⭐⭐⭐ | VMware vCenter Server Appliance |

## Choosing a Sample

- **New to SSH platforms?** Start with [generic-linux](generic-linux/) — it's the baseline.
- **Need account discovery?** Look at [generic-linux-with-discovery](generic-linux-with-discovery/).
- **Managing SSH keys?** See [generic-linux-ssh-keys](generic-linux-ssh-keys/).
- **Prefer batch commands over interactive shells?** Try [linux-ssh-batch-mode](linux-ssh-batch-mode/).

## Related Docs

- [SSH Platforms Guide](../../docs/guides/ssh-platforms.md) — patterns and best practices for SSH platforms
- [Commands: Connect/Disconnect](../../docs/reference/commands/connect.md) — connection management reference
- [Commands: Send/Receive](../../docs/reference/commands/send-receive.md) — interactive terminal commands
- [Commands: ExecuteCommand](../../docs/reference/commands/execute-command.md) — batch-mode command execution
