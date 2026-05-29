# Regex Patterns Guide

Regex is a core part of custom platform scripting. You will use it to detect prompts, wait for command completion, extract values from terminal output, and recognize failure text before the script keeps going.

The scripting engine uses .NET regular expressions (`System.Text.RegularExpressions.Regex`). That means patterns such as named capture groups (`(?<name>...)`), lookbehind, and inline options like `(?i)`, `(?m)`, and `(?s)` follow .NET behavior.

In practice, regex appears most often in these places:

- `Receive.ExpectRegex` and `Receive.ExpectOptions`
- `Condition` expressions such as `Regex.IsMatch(...)`
- `SetItem` / `Eval` expressions such as `Regex.Match(...)` or `Regex.Replace(...)`
- sample `Switch.CaseValue` patterns that use regex-style alternation

## Table of Contents

- [JSON escaping rules](#json-escaping-rules)
- [Common prompt patterns](#common-prompt-patterns)
- [Output parsing patterns](#output-parsing-patterns)
- [Error detection patterns](#error-detection-patterns)
- [Anchoring and line boundaries](#anchoring-and-line-boundaries)
- [Character classes for terminal output](#character-classes-for-terminal-output)
- [Named capture groups](#named-capture-groups)
- [Pattern cookbook](#pattern-cookbook)
- [Testing tips](#testing-tips)
- [Related references](#related-references)

## JSON escaping rules

The biggest regex gotcha in platform scripts is that the pattern lives inside JSON.

**Rule:** every backslash in the regex must be doubled in JSON.

| Meaning | Raw regex | JSON-escaped value |
| --- | --- | --- |
| Digit | `\d+` | `\\d+` |
| Whitespace | `\s+` | `\\s+` |
| Word boundary | `\buid=` | `\\buid=` |
| Optional CRLF/LF | `\r?\n` | `\\r?\\n` |
| Literal dot | `\.` | `\\.` |
| Literal backslash | `\\` | `\\\\` |
| Literal quote in JSON | `"` | `\"` |

A normal `Receive` example:

- Raw regex: `(?m)^.*[#$>]\s?$`
- JSON value: `"(?m)^.*[#$>]\\s?$"`

```json
{
  "Receive": {
    "ConnectionObjectName": "ConnectSsh",
    "BufferName": "PromptBuffer",
    "ExpectRegex": "(?m)^.*[#$>]\\s?$",
    "ExpectTimeout": 10000
  }
}
```

Inside `%{ ... }%` expressions, the regex is still inside JSON. The samples usually use a C# verbatim string to keep the expression readable:

```json
{
  "SetItem": {
    "Name": "match",
    "Value": "%{ Regex.Match(PasswdStdout, @\"^(?<name>[^:]+):[^:]*:(?<uid>\\d+):(?<gid>\\d+):[^\\r\\n]*$\", RegexOptions.Multiline) }%"
  }
}
```

That example comes from the same pattern used in the discovery docs: the C# string is verbatim (`@"..."`), but JSON still needs doubled backslashes.

## Common prompt patterns

For interactive SSH or Telnet flows, regex usually answers one question: **is the remote shell ready for the next command?**

A strong rule from the SSH samples is to prefer **command markers** over generic prompts whenever you can. `CHECKUSER=$?` or `INIT_CHECK=$?` is more reliable than guessing whether a colored shell prompt ended with `$` or `#`.

| Purpose | Raw regex | JSON-escaped value |
| --- | --- | --- |
| Generic shell prompt | `(?m)^.*[#$>]\s?$` | `(?m)^.*[#$>]\\s?$` |
| Root prompt | `(?m)^.*#\s?$` | `(?m)^.*#\\s?$` |
| Password prompt | `(?i)password:` | `(?i)password:` |
| Sudo prompt | `(?i)sudo password for .*:` | `(?i)sudo password for .*:` |
| Combined login flow | `(?i)(verification code:|password:|[#$>]\s?$)` | `(?i)(verification code:|password:|[#$>]\\s?$)` |
| Command marker | `CHECKUSER=(?<rc>\d+)` | `CHECKUSER=(?<rc>\\d+)` |

The repository's Linux SSH samples deliberately normalize the shell first:

```json
{
  "Send": {
    "ConnectionObjectName": "ConnectSsh",
    "Buffer": "unset TERM; stty -echo; LANG=C; LC_ALL=C; SUDO_PROMPT='SUDO password for %p:'; export LANG LC_ALL SUDO_PROMPT; echo \"INIT_CHECK=$?\""
  }
}
```

That reduces localization and prompt variation, which makes later regex matching much more predictable.

## Output parsing patterns

Regex is also how scripts turn free-form terminal output into structured values.

Common examples already used in the samples include:

| Use case | Raw regex | JSON-escaped value |
| --- | --- | --- |
| Extract `uid=` value | `(?m)(?<=\buid=)\d+` | `(?m)(?<=\\buid=)\\d+` |
| Extract `gid=` value | `(?m)(?<=\bgid=)\d+` | `(?m)(?<=\\bgid=)\\d+` |
| Extract `authorizedkeysfile` path | `(?m)(?<=\bauthorizedkeysfile\s+)\S.*` | `(?m)(?<=\\bauthorizedkeysfile\\s+)\\S.*` |
| Parse a passwd/getent line | `^(?<name>[^:]+):[^:]*:(?<uid>\d+):(?<gid>\d+):[^\r\n]*$` | `^(?<name>[^:]+):[^:]*:(?<uid>\\d+):(?<gid>\\d+):[^\\r\\n]*$` |
| Parse an authorized key line | `^(?<options>.*\s)?(?<type>ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp521|ecdsa-sha2-nistp384|ecdsa-sha2-nistp256)\s+(?<key>\S+)\s*(?<comment>.*)$` | `^(?<options>.*\\s)?(?<type>ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp521|ecdsa-sha2-nistp384|ecdsa-sha2-nistp256)\\s+(?<key>\\S+)\\s*(?<comment>.*)$` |
| Extract output between markers | `(?s)(?<=\bContent=).*?(?=,ALLDONE=\d+)` | `(?s)(?<=\\bContent=).*?(?=,ALLDONE=\\d+)` |

A practical example from the SSH key samples:

- Raw regex: `(?m)(?<=\bauthorizedkeysfile\s+)\S.*`
- JSON value: `"(?m)(?<=\\bauthorizedkeysfile\\s+)\\S.*"`

```json
{
  "Function": {
    "Name": "GetValueFromOutput",
    "Parameters": [
      "%DelegationPrefix::$% sshd -T -C user=%AccountUserName%,host=`hostname`,addr=`hostname -i` | grep \"^authorizedkeysfile \"",
      "(?m)(?<=\\bauthorizedkeysfile\\s+)\\S.*",
      false
    ],
    "ResultVariable": "KeyTemplateLine"
  }
}
```

## Error detection patterns

Regex is often the fastest way to stop a script when the remote side is clearly unhappy.

The SSH samples and guides repeatedly match these strings:

- `Permission denied`
- `Sorry, try again`
- `incorrect password attempts`
- `is not in the sudoers file`
- `BAD PASSWORD`
- `Have exhausted maximum number of retries`

A practical combined error regex is:

- Raw regex: `(Permission denied)|(Sorry, try again)|(incorrect password attempts)|(is not in the sudoers file)`
- JSON value: `"(Permission denied)|(Sorry, try again)|(incorrect password attempts)|(is not in the sudoers file)"`

```json
[
  {
    "SetItem": {
      "Name": "ErrorRegex",
      "Value": "(Permission denied)|(Sorry, try again)|(incorrect password attempts)|(is not in the sudoers file)"
    }
  },
  {
    "Receive": {
      "ConnectionObjectName": "ConnectSsh",
      "BufferName": "CmdResponse",
      "ExpectRegex": "(%ExpectRegex%)|(%ErrorRegex%)",
      "ExpectTimeout": 10000
    }
  },
  {
    "Condition": {
      "If": "Regex.IsMatch(CmdResponse, ErrorRegex)",
      "Then": {
        "Do": [
          { "Return": { "Value": false } }
        ]
      }
    }
  }
]
```

For prompt-driven password changes, the samples also match explicit failures such as `BAD PASSWORD` instead of only waiting for a prompt.

## Anchoring and line boundaries

Terminal output is rarely a single clean line. Banners, prompts, and command output usually arrive as a multiline buffer.

Important rules:

- `^` and `$` anchor to the start and end of the **whole string** unless you enable multiline mode.
- Use `(?m)` or `ExpectOptions: ["Multiline"]` when the prompt may appear after banners or command output.
- `.` does **not** match newlines unless you enable single-line mode with `(?s)` or `ExpectOptions: ["Singleline"]`.
- Remote output may use `\r\n` or just `\n`; `\r?\n` is usually the safest delimiter.

| Need | Raw regex | JSON-escaped value |
| --- | --- | --- |
| Prompt at end of any line | `(?m)^.*[#$>]\s?$` | `(?m)^.*[#$>]\\s?$` |
| Match across multiple lines | `(?s)BEGIN.*END` | `(?s)BEGIN.*END` |
| Match either CRLF or LF | `\r?\n` | `\\r?\\n` |

You can express options either inline or with command parameters:

```json
{
  "Receive": {
    "ConnectionObjectName": "ConnectSsh",
    "BufferName": "CmdResponse",
    "ExpectRegex": "^.*[#$>]\\s?$",
    "ExpectOptions": [ "Multiline" ],
    "ExpectTimeout": 10000
  }
}
```

## Character classes for terminal output

Prompt matching gets harder when the remote side adds ANSI color codes or other control characters.

Useful terminal-safe patterns:

| Use case | Raw regex | JSON-escaped value |
| --- | --- | --- |
| ANSI escape sequence | `\x1B\[[0-9;?]*[A-Za-z]` | `\\x1B\\[[0-9;?]*[A-Za-z]` |
| Visible shell prompt with optional ANSI prefix | `(?m)^(?:\x1B\[[0-9;?]*[A-Za-z])*.*[#$>]\s?$` | `(?m)^(?:\\x1B\\[[0-9;?]*[A-Za-z])*.*[#$>]\\s?$` |
| Control characters | `[\x00-\x1F\x7F]` | `[\\x00-\\x1F\\x7F]` |

If the target uses colored prompts, stripping ANSI codes before later matches is often simpler than trying to include every possible escape sequence in every prompt regex.

A practical expression pattern is:

```json
{
  "SetItem": {
    "Name": "CleanBuffer",
    "Value": "%{ Regex.Replace(Buffer, @\"\\x1B\\[[0-9;?]*[A-Za-z]\", \"\") }%"
  }
}
```

## Named capture groups

Named capture groups are one of the most useful .NET regex features in platform scripts.

- Syntax: `(?<name>...)`
- Access in expressions: `match.Groups["name"].Value`
- Repeated named groups can be read through `Captures`

The account-discovery samples use named groups to parse account data:

- Raw regex: `^(?<name>[^:]+):[^:]*:(?<uid>\d+):(?<gid>\d+):[^\r\n]*$`
- JSON value: `"^(?<name>[^:]+):[^:]*:(?<uid>\\d+):(?<gid>\\d+):[^\\r\\n]*$"`

```json
{
  "SetItem": {
    "Name": "match",
    "Value": "%{Regex.Match(PasswdStdout, @\"^(?<name>[^:]+):[^:]*:(?<uid>\\d+):(?<gid>\\d+):[^\\r\\n]*$\", RegexOptions.Multiline)}%"
  }
}
```

Then the script can read the structured values directly:

```json
{
  "WriteDiscoveredAccount": {
    "Name": "%{match.Groups[\"name\"].Value}%",
    "UserId": "%{match.Groups[\"uid\"].Value}%",
    "GroupId": "%{match.Groups[\"gid\"].Value}%"
  }
}
```

This is usually clearer and safer than relying on numbered groups such as `Groups[1]`, `Groups[2]`, and `Groups[3]`.

## Pattern cookbook

Use these patterns as starting points. Adjust them to the exact output your target emits.

| Purpose | Raw regex | JSON-escaped version | Notes |
| --- | --- | --- | --- |
| Generic Linux shell prompt | `(?m)^.*[#$>]\s?$` | `(?m)^.*[#$>]\\s?$` | Good fallback, but markers are better. |
| Root shell prompt | `(?m)^.*#\s?$` | `(?m)^.*#\\s?$` | Useful after `sudo` or `su`. |
| Password prompt | `(?i)password:` | `(?i)password:` | Case-insensitive basic prompt match. |
| `passwd` current/new prompt | `([cC]urrent.*[Pp]assword)|([Nn]ew.*[Pp]assword:)` | `([cC]urrent.*[Pp]assword)|([Nn]ew.*[Pp]assword:)` | Taken directly from Linux password-change flows. |
| OTP/password/prompt union | `(?i)(verification code:|password:|[#$>]\s?$)` | `(?i)(verification code:|password:|[#$>]\\s?$)` | Useful for mixed login flows. |
| Command return-code marker | `CHECKUSER=(?<rc>\d+)` | `CHECKUSER=(?<rc>\\d+)` | Reliable because you control the marker text. |
| Nonzero return-code marker | `CHECKUSER=[1-9]+.*` | `CHECKUSER=[1-9]+.*` | Used in sample `Switch` cases. |
| `uid=` extraction | `(?m)(?<=\buid=)\d+` | `(?m)(?<=\\buid=)\\d+` | Used in SSH key helper functions. |
| `authorizedkeysfile` path extraction | `(?m)(?<=\bauthorizedkeysfile\s+)\S.*` | `(?m)(?<=\\bauthorizedkeysfile\\s+)\\S.*` | Reads `sshd -T` output. |
| Unix account line with named groups | `^(?<name>[^:]+):[^:]*:(?<uid>\d+):(?<gid>\d+):[^\r\n]*$` | `^(?<name>[^:]+):[^:]*:(?<uid>\\d+):(?<gid>\\d+):[^\\r\\n]*$` | Good for `getent passwd` or `/etc/passwd` output. |
| Authorized key parser | `^(?<options>.*\s)?(?<type>ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp521|ecdsa-sha2-nistp384|ecdsa-sha2-nistp256)\s+(?<key>\S+)\s*(?<comment>.*)$` | `^(?<options>.*\\s)?(?<type>ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp521|ecdsa-sha2-nistp384|ecdsa-sha2-nistp256)\\s+(?<key>\\S+)\\s*(?<comment>.*)$` | Handles optional restricted-key prefixes. |
| Output between markers | `(?s)(?<=\bContent=).*?(?=,ALLDONE=\d+)` | `(?s)(?<=\\bContent=).*?(?=,ALLDONE=\\d+)` | Use non-greedy `.*?` when delimiters matter. |
| Common auth/sudo errors | `(Permission denied)|(Sorry, try again)|(incorrect password attempts)|(is not in the sudoers file)` | `(Permission denied)|(Sorry, try again)|(incorrect password attempts)|(is not in the sudoers file)` | Centralize this into `ErrorRegex`. |
| IPv4 address | `\b(?:\d{1,3}\.){3}\d{1,3}\b` | `\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b` | Validates IPv4 shape, not octet range. |
| SHA-256 host-key fingerprint | `\bSHA256:[A-Za-z0-9+/=]+\b` | `\\bSHA256:[A-Za-z0-9+/=]+\\b` | Useful when parsing OpenSSH-style fingerprint output. |

## Testing tips

- **Start with real output.** Copy the exact banner, prompt, or command response from your test run, including line endings.
- **Test the raw regex first.** PowerShell uses the same .NET regex engine, so `[regex]::Match(...)`, `[regex]::IsMatch(...)`, and `Select-String` are good quick checks.
- **Then convert to JSON form.** Many regexes fail only because `\d`, `\s`, or `\r?\n` were not doubled for JSON.
- **Prefer markers over prompts.** `echo \"CHECKUSER=$?\"` is more stable than trying to match every shell prompt variation.
- **Normalize remote output when possible.** The Linux samples set `LANG=C`, `LC_ALL=C`, and `SUDO_PROMPT` to reduce localization surprises.
- **Test multiline behavior explicitly.** If the prompt is not on the first line, add `(?m)` or `ExpectOptions: ["Multiline"]`.
- **Be careful with greedy `.*`.** Use `.*?` when you are matching between start and end markers.
- **Strip ANSI when needed.** Colored prompts can make a correct prompt regex look broken.
- **Keep parsing in small steps.** Capture into `match`, inspect `match.Success`, then read named groups.
- **Use the local test workflow before upload.** See [Testing and Debugging](../getting-started/testing-and-debugging.md) and the repository's `tools\TestTool.ps1`.

## Related references

- [Send and Receive](../reference/commands/send-receive.md)
- [Connect and Disconnect](../reference/commands/connect.md)
- [Utility Commands](../reference/commands/utilities.md)
- [Variables Reference](../reference/variables.md)
- [SSH Platforms Guide](ssh-platforms.md)
- [Error Handling Guide](error-handling.md)
- [Testing and Debugging](../getting-started/testing-and-debugging.md)
