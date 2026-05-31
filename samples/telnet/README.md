[← Samples](../README.md)

# Telnet Samples

Tested custom platform scripts for managing systems over Telnet, including TN3270 for mainframe environments.

| Sample | Complexity | Target System |
| --- | --- | --- |
| [cisco-ios](cisco-ios/) | ⭐⭐⭐ | Cisco IOS network devices |
| [racf-tn3270](racf-tn3270/) | ⭐⭐⭐ | IBM RACF mainframes via TN3270 |

## About Telnet Platforms

Telnet platforms use the same `Connect`, `Send`, `Receive`, and `Disconnect` commands as SSH platforms but connect over Telnet instead. The scripting patterns are nearly identical to interactive SSH — the difference is the transport layer.

TN3270 is a specialized Telnet variant for IBM mainframe communication. The `GenericRacfTn3270` sample demonstrates screen-based interaction patterns specific to 3270 terminal emulation.

## Related

- [SSH Platforms Guide](../../docs/guides/ssh-platforms.md) — many patterns also apply to Telnet
- [Commands: Connect/Disconnect](../../docs/reference/commands/connect.md) — connection management
- [Commands: Send/Receive](../../docs/reference/commands/send-receive.md) — interactive terminal commands

> **Note:** Telnet pattern files (non-custom-platform) have moved to [SafeguardAutomation](https://github.com/OneIdentity/SafeguardAutomation/tree/master/Terminal%20Pattern%20Files).
