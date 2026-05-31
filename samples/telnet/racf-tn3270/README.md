# IBM RACF Password Management (TN3270)

This sample manages RACF passwords through a TN3270 session to a z/OS logon screen. It validates logon for both service and managed accounts and changes passwords by issuing a RACF `ALU ... PASSWORD(...) NOEXPIRED` command.

## Target System

IBM z/OS RACF user IDs exposed through a TN3270 / TSO logon session.

## Operations Implemented

| Operation | Description |
| --- | --- |
| `CheckSystem` | Connects to the TN3270 endpoint, signs in with the function account, and logs off to verify connectivity and administrative credentials. |
| `CheckPassword` | Uppercases the managed account username, signs in through the TSO/E logon prompt, and returns success only when the RACF logon completes. |
| `ChangePassword` | Verifies the target user exists, signs in with the function account, issues the `ALU` password-change command, and parses the response for success or policy failure. |

## Prerequisites

- SPP 6.0 or later
- Network access from SPP to the TN3270 endpoint, typically on port `23` or another site-specific port
- A RACF function account authorized for TSO logon and for the `ALU` command used to update user passwords
- Managed accounts that map to RACF user IDs; optional `WorkstationId` if your host requires a specific terminal identifier

## Deployment

1. Upload the script: `Import-SafeguardCustomPlatformScript -FilePath ./GenericRacfTn3270.json`
2. Create a custom platform using this script
3. Create an asset using the platform
4. Configure service account, managed account(s), and TN3270 connection options such as `UseSsl` and `WorkstationId`
5. Test with `Test-SafeguardAssetAccountPassword -ExtendedLogging`

## How It Works

The script uppercases RACF user IDs, connects with a TN3270 session, and sends `LOGON %UserName%`. It parses the returned screen for `INVALID USERID`, authorization failures, or the `TSO/E LOGON` prompt. For password checks it submits the managed account password and treats a normal RACF session banner such as `LAST ACCESS AT` or `LOGON IN PROGRESS` as success. For password changes it first confirms the account exists, then sends `ALU %AccountUserName% PASSWORD(%NewPassword%) NOEXPIRED`, looks for `READY` to confirm success, and logs off or disconnects as needed.

## Parameters

- `UseSsl`: Enables TLS for the TN3270 connection. Default: `true`.
- `SkipServerCertValidation`: Skips certificate validation when TLS is enabled.
- `WorkstationId`: Optional TN3270 workstation identifier.
- `Timeout`: Connection and receive timeout. Default: `30`.
- `Port`: TN3270 port. Default: `23`.

## Limitations

- The sample assumes a RACF/TSO logon flow compatible with the `TSO/E LOGON` prompt and the `ALU ... PASSWORD(...) NOEXPIRED` command syntax.
- User IDs are uppercased before use.
- If RACF rejects the new password and prompts for another one, the script disconnects instead of continuing the interactive recovery flow.

## Related

- [Connect command reference](../../../docs/reference/commands/connect.md)
- [Send/Receive command reference](../../../docs/reference/commands/send-receive.md)
- [Testing and debugging](../../../docs/guides/testing-and-debugging.md)
