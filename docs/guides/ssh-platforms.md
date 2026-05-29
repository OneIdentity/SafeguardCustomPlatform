[← Documentation](../README.md)

# SSH Platforms Guide

This guide covers the SSH patterns you will use most often when building Safeguard custom platforms. It assumes you already understand SSH itself and want to understand how SPP expects an SSH-based script to behave.

## Table of Contents

- [Choosing an SSH pattern](#choosing-an-ssh-pattern)
- [Connection and login patterns](#connection-and-login-patterns)
- [Using `Connect`, `Disconnect`, `Send`, `Receive`, and `ExecuteCommand`](#using-connect-disconnect-send-receive-and-executecommand)
- [Common login flows](#common-login-flows)
- [Shell prompt detection and `Receive` regex patterns](#shell-prompt-detection-and-receive-regex-patterns)
- [SPS session recording integration](#sps-session-recording-integration)
- [SSH error handling patterns](#ssh-error-handling-patterns)
- [Using system import libraries](#using-system-import-libraries)
- [Practical tips](#practical-tips)
- [Sample scripts to study](#sample-scripts-to-study)
- [Related references](#related-references)

## Choosing an SSH pattern

Most SSH custom platforms fall into one of these two patterns:

| Pattern | Best for | Core commands | Key setting |
| --- | --- | --- | --- |
| Interactive expect-style | Password changes, shell-driven workflows, `sudo` prompts, menu systems, appliances with conversational CLIs | `Connect` + `Send` + `Receive` + `Disconnect` | `RequestTerminal: true` |
| Direct command execution | Simple Linux or Unix commands, `id`, `grep`, `cat`, `passwd` with stdin, batch-friendly sudo flows | `Connect` + `ExecuteCommand` + `Disconnect` | `RequestTerminal: false` |

As a rule:

- Use **interactive SSH** when you must react to prompts one step at a time.
- Use **batch mode** when the remote system can do the whole job with normal command execution.
- Prefer **sample-first development**. Start from a close match in [`SampleScripts/SSH`](../../SampleScripts/SSH/) instead of building from scratch.

## Connection and login patterns

### Interactive expect-style pattern

This is the classic Linux pattern used in [`GenericLinux.json`](../../SampleScripts/SSH/GenericLinux.json): connect, flush the banner, set up the shell, send a command, receive output, and react to prompts.

```json
{
  "Connect": {
    "ConnectionObjectName": "Global:ConnectSsh",
    "Type": "Ssh",
    "NetworkAddress": "%Address%",
    "Port": "%Port%",
    "Login": "%FuncUserName%",
    "Password": "%FuncPassword::$%",
    "RequestTerminal": true,
    "CheckHostKey": "%CheckHostKey%",
    "HostKey": "%HostKey::$%",
    "Timeout": "%Timeout%"
  }
}
{ "Receive": { "ConnectionObjectName": "ConnectSsh", "BufferName": "LoginBanner" } }
{ "Send": { "ConnectionObjectName": "ConnectSsh", "Buffer": "unset TERM; stty -echo; LANG=C; LC_ALL=C; echo \"INIT_CHECK=$?\"" } }
{
  "Receive": {
    "ConnectionObjectName": "ConnectSsh",
    "BufferName": "InitBuffer",
    "ExpectRegex": "INIT_CHECK=0",
    "ExpectTimeout": 5000
  }
}
```

Use this pattern when:

- the platform displays a shell prompt or banner after login
- `sudo`, `su`, or `passwd` prompts appear mid-flow
- you need to inspect text before deciding what to send next

### Direct command execution pattern

From SPP 7.4 onward, SSH scripts can skip interactive prompt walking and execute remote commands directly.

```json
{
  "Connect": {
    "ConnectionObjectName": "Global:ConnectSsh",
    "Type": "Ssh",
    "NetworkAddress": "%Address%",
    "Port": "%Port%",
    "Login": "%FuncUserName%",
    "Password": "%FuncPassword::$%",
    "UserKey": "%UserKey::$%",
    "RequestTerminal": false,
    "CheckHostKey": "%CheckHostKey%",
    "HostKey": "%HostKey::$%",
    "Timeout": "%Timeout%"
  }
}
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "/usr/bin/id %FuncUserName%",
    "BufferName": "Stdout",
    "StderrBufferName": "Stderr",
    "ExitStatusBufferName": "rc"
  }
}
{ "Disconnect": { "ConnectionObjectName": "ConnectSsh" } }
```

Use this pattern when:

- the target behaves like a normal SSH command runner
- you do not need a PTY
- you want cleaner stdout, stderr, and exit-code handling
- you are working from samples such as [`LinuxSshBatchModeExample.json`](../../SampleScripts/SSH/LinuxSshBatchModeExample.json) or [`RestrictedAuthorizedKeyExample.json`](../../SampleScripts/SSH/RestrictedAuthorizedKeyExample.json)

## Using `Connect`, `Disconnect`, `Send`, `Receive`, and `ExecuteCommand`

### `Connect` and `Disconnect`

Use [`Connect`](../reference/commands/connect.md) to open the session and [`Disconnect`](../reference/commands/connect.md) to close it.

Important SSH-specific settings:

- `Type: "Ssh"`
- `Login`, plus either `Password` or `UserKey`
- `RequestTerminal: true` for interactive `Send` / `Receive`
- `RequestTerminal: false` for `ExecuteCommand`
- `CheckHostKey` and `HostKey` for trust validation
- `SoftwareVersionVariableName` when you want the SSH server banner

### `Send` and `Receive`

Use [`Send`](../reference/commands/send-receive.md) and [`Receive`](../reference/commands/send-receive.md) together when the remote side behaves like a terminal.

A reliable pattern is:

1. `Connect`
2. initial `Receive` to consume banners or MOTD text
3. `Send` a command that emits a unique marker such as `CHECKUSER=$?`
4. `Receive` until the marker or next prompt appears
5. branch with `Condition` or `Switch`

### `ExecuteCommand`

Use [`ExecuteCommand`](../reference/commands/execute-command.md) when SSH can be treated as a remote process runner.

It works best when you:

- set `RequestTerminal: false` on `Connect`
- always capture `BufferName`
- also capture `StderrBufferName` and `ExitStatusBufferName` for troubleshooting
- wrap it in a helper function that returns `{ rc, Stdout, Stderr }`

## Common login flows

### Password authentication

Password auth is the simplest case. Pass `%FuncPassword::$%` or `%AccountPassword::$%` into `Connect`.

```json
{
  "Connect": {
    "ConnectionObjectName": "Global:ConnectSsh",
    "Type": "Ssh",
    "NetworkAddress": "%Address%",
    "Port": "%Port%",
    "Login": "%FuncUserName%",
    "Password": "%FuncPassword::$%",
    "RequestTerminal": true,
    "CheckHostKey": "%CheckHostKey%",
    "HostKey": "%HostKey::$%",
    "Timeout": "%Timeout%"
  }
}
```

This is the right starting point for `CheckSystem`, and it is often enough for a minimal `CheckPassword` implementation too.

### Key authentication

For SSH-key-based service accounts, pass the private key with `UserKey`.

```json
{
  "Connect": {
    "ConnectionObjectName": "Global:ConnectSsh",
    "Type": "Ssh",
    "NetworkAddress": "%Address%",
    "Port": "%Port%",
    "Login": "%FuncUserName%",
    "UserKey": "%UserKey::$%",
    "RequestTerminal": false,
    "CheckHostKey": "%CheckHostKey%",
    "HostKey": "%HostKey::$%",
    "Timeout": "%Timeout%"
  }
}
```

This is common for automation-friendly service accounts, restricted authorized keys, and batch-mode Linux platforms.

### Prompted privilege escalation

Many Linux scripts log in as the service account, then elevate with `sudo`.

```json
{ "Send": { "ConnectionObjectName": "ConnectSsh", "Buffer": "%DelegationPrefix% grep '^%AccountUserName%:' /etc/shadow" } }
{ "Receive": { "ConnectionObjectName": "ConnectSsh", "BufferName": "AccountEntry" } }
{
  "Condition": {
    "If": "Regex.IsMatch(AccountEntry, @\"SUDO password for\")",
    "Then": {
      "Do": [
        { "Send": { "ConnectionObjectName": "ConnectSsh", "Buffer": "%FuncPassword%", "ContainsSecret": true } },
        { "Receive": { "ConnectionObjectName": "ConnectSsh", "BufferName": "AccountEntry", "ContainsSecret": true } }
      ]
    }
  }
}
```

This is safer than assuming password-less sudo.

### `su`-style escalation

Some appliances require `su` or a vendor-specific privilege shell. The pattern is the same:

1. `Send` the elevation command
2. `Receive` until a password prompt or the elevated prompt appears
3. `Send` the secret only if the password prompt is present
4. `Receive` again and confirm the new prompt

Typical regexes are `(?i)password:` for the prompt and a root shell prompt such as `(?m)^.*#\s?$` for success.

### MFA or secondary prompts

SSH custom platforms can handle **post-login interactive prompts** with `Receive` and `Send`, for example OTP prompts, approval banners, or appliance-specific acknowledgment text.

However, be careful:

- If the SSH server requires an authentication method that cannot be satisfied by the `Connect` parameters alone, the script may fail before a shell is available.
- If the extra step appears **after** login in the terminal stream, treat it like any other prompt-driven flow.
- Always prefer service-account authentication paths that are stable and non-human-driven.

A practical pattern is to branch on several expected prompts:

```json
{
  "Receive": {
    "ConnectionObjectName": "ConnectSsh",
    "BufferName": "LoginFlow",
    "ExpectRegex": "(?i)(verification code:|password:|[#$>]\\s?$)",
    "ExpectTimeout": 10000
  }
}
```

## Shell prompt detection and `Receive` regex patterns

`Receive` is most reliable when you wait for **something specific**.

### Prefer markers over generic prompts

A unique marker is better than guessing the shell prompt:

```json
{ "Send": { "ConnectionObjectName": "ConnectSsh", "Buffer": "grep -q '^%AccountUserName%:' /etc/passwd; echo \"CHECKUSER=$?\"" } }
{
  "Receive": {
    "ConnectionObjectName": "ConnectSsh",
    "BufferName": "ReturnStatus",
    "ExpectRegex": "CHECKUSER=[0-9]+",
    "ExpectTimeout": 5000
  }
}
```

This avoids false matches caused by banners, color prompts, or multiline shells.

### Useful prompt regexes

| Purpose | Regex |
| --- | --- |
| Generic shell prompt | `(?m)^.*[#$>]\s?$` |
| Root shell prompt | `(?m)^.*#\s?$` |
| Password prompt | `(?i)password:` |
| Sudo prompt | `(?i)sudo password for .*:` |
| `passwd` current/new password prompt | `([cC]urrent.*[Pp]assword)|([Nn]ew.*[Pp]assword:)` |
| Marker plus sudo error handling | `(%Expect%)|(%ErrorRegex%)` |

Tips for `Receive` regexes:

- Use `ExpectTimeout` so a slow system becomes a controlled timeout instead of a hung operation.
- Use `ExpectOptions` or `RegexOptions.Multiline` when the prompt may not be on the first line.
- Keep the regex narrow enough to avoid matching MOTD text.
- For password changes, expect the **next prompt**, not the final command output only.

## SPS session recording integration

SSH custom platforms are often used in environments where SPP and SPS work together.

Key points:

- When you add or edit the custom platform in SPP, enable **Allow Session Requests** if the platform should support SSH session access requests.
- This setting is typically enabled for SSH platforms.
- SPP brokers privileged access requests. When SPP is integrated with SPS, SSH sessions are proxied through SPS so the session can be monitored, recorded, and played back.
- From the requester's perspective, they launch an SSH session through the SPP request workflow. They do not connect directly to the target resource.
- Your custom platform script still defines how SPP manages credentials and host connectivity for operations such as `CheckSystem`, `CheckPassword`, `ChangePassword`, and `DiscoverSshHostKey`.

Think of the split this way:

- **Custom platform script**: credential operations and platform logic
- **SPP access request workflow**: approval and launch path
- **SPS**: SSH proxying, monitoring, and recording

## SSH error handling patterns

Use `Try` / `Catch` around network-sensitive commands and turn low-level failures into clear status messages.

### Connection refused

Usually means the host is reachable but nothing is listening on the SSH port, or a firewall rejected the connection.

Pattern:

```json
{
  "Try": {
    "Do": [
      {
        "Connect": {
          "ConnectionObjectName": "Global:ConnectSsh",
          "Type": "Ssh",
          "NetworkAddress": "%Address%",
          "Port": "%Port%",
          "Login": "%FuncUserName%",
          "Password": "%FuncPassword::$%",
          "RequestTerminal": true,
          "CheckHostKey": "%CheckHostKey%",
          "HostKey": "%HostKey::$%",
          "Timeout": "%Timeout%"
        }
      }
    ],
    "Catch": [
      {
        "Status": {
          "Type": "Connecting",
          "Percent": 95,
          "Message": {
            "Name": "AssetConnectFailedWithReasonAndAddress",
            "Parameters": [ "%AssetName%", "%Address%", "%Exception%" ]
          }
        }
      },
      { "Throw": { "Value": "%Exception%" } }
    ]
  }
}
```

### Authentication failed

Treat authentication failures as either:

- a `Connect` failure in direct-login flows, or
- a prompt/output match in interactive flows, for example `Permission denied`, `Sorry, try again`, or repeated sudo prompts.

A good interactive pattern is to centralize common error text:

```json
{ "SetItem": { "Name": "ErrorRegex", "Value": "(Permission denied)|(Sorry, try again)|(incorrect password attempts)|(is not in the sudoers file)" } }
```

### Timeout

Timeouts are common with slow banners, heavy MOTD output, or slow `sudo` policy plugins.

Recommended pattern:

```json
{
  "Receive": {
    "ConnectionObjectName": "ConnectSsh",
    "BufferName": "CmdResponse",
    "ExpectRegex": "%ExpectRegex::$%",
    "ExpectTimeout": 10000,
    "TimeoutResultVariableName": "Global:CmdTimedOut"
  }
}
```

Then branch explicitly on `CmdTimedOut` so you can log a useful error.

### Host-key problems

For SSH platforms, host-key errors are part of normal trust handling, not an edge case.

- Implement `DiscoverSshHostKey` so SPP can capture the trusted host key.
- Use [`DiscoverSshHostKey`](../reference/commands/ssh-host-key.md) when the platform supports SSH.
- Keep `CheckHostKey` enabled in production.
- Temporarily disabling host-key checks may help initial debugging, but it should not be your steady-state design.

## Using system import libraries

If your SPP build exposes system import libraries, use them when they match your platform instead of copying the same SSH helper functions into every script.

The `Imports` block looks like this:

```json
"Imports": [
  "LinuxSshLogin",
  "LinuxSshFunctions",
  "DiscoverSshHostKey"
]
```

Common SSH-oriented library names you may see include:

- `LinuxSshLogin` - shared SSH login, logout, and connection helpers
- `LinuxSshFunctions` - reusable Linux-oriented helper functions such as environment setup or common command wrappers
- `DiscoverSshHostKey` - host-key discovery helpers for SSH platforms
- `TestLoginSsh` - shared login-test logic for simple validation flows
- `ReturnOperationResultSsh` - shared return/result helpers so operations report success or failure consistently

Use imports when:

- your platform is a close variation of a built-in Linux SSH pattern
- you want appliance-maintained helper logic instead of duplicating boilerplate
- multiple operations share the same connection or result-handling flow

Avoid imports when:

- the target CLI is highly unusual and the shared helper would fight your prompt flow
- you need to understand every branch during first-time troubleshooting

For the exact library names and function signatures available in your build, see [Imports](../reference/imports.md).

## Practical tips

### Handle slow prompts with `Wait`

Some appliances need a short pause after login or privilege changes. The vCenter sample uses a one-second wait after login.

```json
{ "Wait": { "Seconds": 1 } }
```

Use `Wait` sparingly. Prefer `Receive` with a specific regex when possible.

### Flush banners and MOTD text early

Many SSH targets print legal banners, last-login text, or MOTD content before the shell is ready.

A safe pattern is:

1. `Connect`
2. immediate `Receive` into a throwaway buffer
3. `Send` an initialization command that prints a marker
4. `Receive` until the marker appears

### Normalize the shell before doing real work

The Linux samples set environment variables so prompts are more predictable and localized output does not break regex matching.

```json
{ "Send": { "ConnectionObjectName": "ConnectSsh", "Buffer": "unset TERM; stty -echo; LANG=C; LC_ALL=C; SUDO_PROMPT='SUDO password for %p:'; export LANG LC_ALL SUDO_PROMPT; echo \"INIT_CHECK=$?\"" } }
```

### Prefer command markers to raw prompt guessing

`echo "CHECKSYS=$?"`, `echo "CHECKUSER=$?"`, and similar markers make parsing much more reliable than waiting for a generic shell prompt.

### Design `sudo` and `su` flows deliberately

- For interactive shells, detect a `sudo` or `su` password prompt with `Receive`.
- For batch mode, use `ExecuteCommand` and inspect `stderr` and `rc`.
- If `sudo` requires a password, decide whether to support that path explicitly or require password-less sudo for the service account.
- If your script uses a restricted authorized key, follow the batch-mode patterns from [`RestrictedAuthorizedKeyExample.json`](../../SampleScripts/SSH/RestrictedAuthorizedKeyExample.json).

## Sample scripts to study

Start with the closest example in this repository:

- [`GenericLinux.json`](../../SampleScripts/SSH/GenericLinux.json) - interactive Linux password workflows
- [`GenericLinuxWithSSHKeySupport.json`](../../SampleScripts/SSH/GenericLinuxWithSSHKeySupport.json) - interactive Linux plus SSH key management
- [`GenericLinuxWithDiscovery.json`](../../SampleScripts/SSH/GenericLinuxWithDiscovery.json) - interactive Linux plus discovery helpers
- [`LinuxSshBatchModeExample.json`](../../SampleScripts/SSH/LinuxSshBatchModeExample.json) - non-interactive `ExecuteCommand` pattern
- [`RestrictedAuthorizedKeyExample.json`](../../SampleScripts/SSH/RestrictedAuthorizedKeyExample.json) - restricted-key SSH authentication with batch-mode command execution
- [`vCenterServerAppliance.json`](../../SampleScripts/SSH/vCenterServerAppliance.json) - appliance-specific interactive flow with timing considerations

## Related references

- [Your First SSH Script](../getting-started/your-first-ssh-script.md)
- [Connect and Disconnect](../reference/commands/connect.md)
- [Send and Receive](../reference/commands/send-receive.md)
- [ExecuteCommand](../reference/commands/execute-command.md)
- [DiscoverSshHostKey](../reference/commands/ssh-host-key.md)
- [Imports](../reference/imports.md)
- [Operations Reference](../reference/operations.md)
- [Troubleshooting](troubleshooting.md)
