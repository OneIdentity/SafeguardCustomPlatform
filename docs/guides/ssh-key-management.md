[← Documentation](../README.md)

# SSH Key Management Guide

Safeguard SSH key management keeps the public key installed on a target account in sync with the key material stored in SPP. For custom platforms, that usually means reading and rewriting one or more `authorized_keys`-style files over SSH.

## Table of Contents

- [What SSH key management means in Safeguard](#what-ssh-key-management-means-in-safeguard)
- [Operations involved](#operations-involved)
- [Key parameters you will use](#key-parameters-you-will-use)
- [Feature flags derived automatically](#feature-flags-derived-automatically)
- [Recommended implementation pattern](#recommended-implementation-pattern)
- [Using system import libraries](#using-system-import-libraries)
- [OpenSSH vs legacy formats](#openssh-vs-legacy-formats)
- [Reporting discovered keys](#reporting-discovered-keys)
- [Supporting restricted authorized keys](#supporting-restricted-authorized-keys)
- [Error handling guidance](#error-handling-guidance)
- [Related references](#related-references)

## What SSH key management means in Safeguard

In Safeguard, SSH key management is about four related tasks for a managed account:

- confirm that the managed public key is actually installed on the target
- deploy a newly generated public key to the target account
- discover all keys already present for that account
- remove a specific key from the account's authorized-key store

SPP stores the managed account's key material and calls your custom platform operations to synchronize the target system. On Unix-like platforms, the target-side implementation is usually one of these patterns:

- read and update `~/.ssh/authorized_keys`
- read and update multiple candidate files such as `authorized_keys` and `authorized_keys2`
- use a shared system import library that already implements the common file handling

This guide assumes the common case: a service account connects over SSH, escalates as needed, and manipulates the managed account's key file on disk.

## Operations involved

See the full definitions in [Operations Reference](../reference/operations.md). For SSH key workflows, the important operations are:

| Operation | Purpose | Typical result |
| --- | --- | --- |
| `CheckSshKey` | Verify that a specific public key is installed on the target account. | Return `true` when found, `false` when missing. |
| `ChangeSshKey` | Install a new public key and, in most implementations, optionally remove the old public key. | Return `true` after the new key is deployed and verified. |
| `DiscoverAuthorizedKeys` | Enumerate keys already configured for the account. | Emit one `WriteDiscoveredSshKey` record per key. |
| `RemoveAuthorizedKey` | Remove one specific key from `authorized_keys`. | Return `true` after the file is rewritten successfully. |

A practical pairing is:

- `CheckSshKey` + `ChangeSshKey` for managed-key rotation
- `DiscoverAuthorizedKeys` + `RemoveAuthorizedKey` for cleanup of unmanaged keys

Operation-specific guidance:

- **`CheckSshKey`** should be read-only. It should not normalize, rewrite, or repair the file; it only answers whether the expected public key is present.
- **`ChangeSshKey`** should add first, verify second, and remove the old key last. That ordering reduces lockout risk.
- **`DiscoverAuthorizedKeys`** should report every valid key line it can parse, including unmanaged or restricted keys.
- **`RemoveAuthorizedKey`** should remove only the targeted key line and leave all other keys untouched.

## Key parameters you will use

See [Reserved Parameters](../reference/reserved-parameters.md) for the broader reference. For SSH key work, you will usually consume these values.

> In older samples and some existing docs, you will also see shorter names such as `NewSshKey`, `OldSshKey`, and `AccountSshKey`. The table below uses the clearer conceptual names and notes the common sample equivalents.

| Parameter | Meaning in the workflow | Common sample name |
| --- | --- | --- |
| `NewPublicSshKey` | New public key to deploy during `ChangeSshKey`. | `NewSshKey` |
| `NewSshKeyType` | Key algorithm for the new key, such as RSA or ED25519. | `NewSshKeyType` |
| `NewSshKeyComment` | Comment to append when writing the new public key line. | `NewSshKeyComment` |
| `OldPublicSshKey` | Existing public key to verify or remove. | `OldSshKey` |
| `OldPrivateSshKey` | Previous private key, if your workflow needs validation or rollback logic. | `OldPrivateSshKey` |
| `PrivateSshKey` | Current managed private key from SPP. Useful when testing login with the installed key. | `PrivateSshKey` |
| `PublicSshKey` | Current managed public key already associated with the account. | `AccountSshKey` |
| `PublicSshKeyComment` | Comment associated with the current managed public key. | `AccountSshKeyComment` |

You will usually combine those with standard SSH connection parameters such as `Address`, `Port`, `Timeout`, `FuncUserName`, `FuncPassword`, `UserKey`, `CheckHostKey`, `HostKey`, and `AccountUserName`.

## Feature flags derived automatically

SPP derives the relevant feature flags from the operations present in your script:

| Flag | Derived from |
| --- | --- |
| `SshKeyFl` | `CheckSshKey` operation present |
| `DiscoverSshKeyFl` | `DiscoverAuthorizedKeys` operation present |

Important consequences:

- `ChangeSshKey` is normally paired with `CheckSshKey`, but `SshKeyFl` is derived from `CheckSshKey`.
- `RemoveAuthorizedKey` belongs with key discovery workflows, but `DiscoverSshKeyFl` is derived from `DiscoverAuthorizedKeys`.
- You do not hand-edit these flags in the JSON; they are inferred from the script content. See [Feature Flags](feature-flags.md).

## Recommended implementation pattern

For most Unix and Linux targets, the safest pattern is to treat `authorized_keys` as text that must be read, parsed, and rewritten carefully.

### 1. Resolve the target file or files

Do not assume only one path exists. A practical Unix pattern is to check multiple templates, for example:

- `%h/.ssh/authorized_keys`
- `%h/.ssh/authorized_keys2`

[`GenericLinuxWithSSHKeySupport.json`](../../SampleScripts/SSH/GenericLinuxWithSSHKeySupport.json) follows exactly that pattern and resolves the final paths before check, change, or discovery.

### 2. Check for a key with exact matching

A minimal `CheckSshKey` implementation normally reads or greps the target file and returns `true` only when the exact public key is present.

```json
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "%DelegationPrefix::$% grep -F -- '%OldPublicSshKey%' '%AuthorizedKeysPath%'",
    "BufferName": "Stdout",
    "StderrBufferName": "Stderr",
    "ExitStatusBufferName": "rc"
  }
}
```

Notes:

- Use `grep -F` for literal matching.
- Match the key body, not just the comment.
- Return `false` for "not found", but throw for permission or parsing failures.

### 3. Change the key with backup, append, verify, then cleanup

A robust `ChangeSshKey` flow looks like this:

1. resolve the target file path
2. create the `.ssh` directory if needed
3. back up the current file
4. append the new key line
5. restore file ownership and mode
6. optionally test login with `PrivateSshKey` or the newly generated private key
7. remove the old key line
8. roll back from backup if anything fails

A simplified append step looks like this:

```json
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "echo '%NewPublicSshKey% %NewSshKeyComment::$%' | %DelegationPrefix::$% tee -a '%AuthorizedKeysPath%'",
    "BufferName": "Stdout",
    "StderrBufferName": "Stderr",
    "ExitStatusBufferName": "rc"
  }
}
```

The sample [`GenericLinuxWithSSHKeySupport.json`](../../SampleScripts/SSH/GenericLinuxWithSSHKeySupport.json) uses the same overall approach, including backup and rollback.

### 4. Remove the old key by rewriting the file

A common pattern is to write every line except the target key into a replacement file, then move it into place.

```json
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "%DelegationPrefix::$% cat '%AuthorizedKeysPath%' | grep -F -v -- '%OldPublicSshKey%' | %DelegationPrefix::$% tee '%AuthorizedKeysPath%_Updated'",
    "BufferName": "Stdout",
    "StderrBufferName": "Stderr",
    "ExitStatusBufferName": "rc"
  }
}
```

After that, move the updated file into place and restore ownership and permissions.

### 5. Preserve the expected Unix permissions

When your script creates or rewrites files, restore the normal permissions immediately:

- `.ssh` directory: typically `700`
- `authorized_keys`: typically `600`
- owner: the managed account user, not the service account

If your service account reaches the file through `sudo`, make sure you finish by `chown`/`chmod` back to the managed account.

## Using system import libraries

When the target follows standard Unix shell behavior, prefer shared import libraries over re-implementing the whole flow.

```json
{
  "Imports": [
    "ChangeSshKeyCommon",
    "UnixShellAuthorizedKeys",
    "UnixShellChangeSshKey",
    "UnixShellAuthorizedKeysOpenSsh",
    "UnixShellChangeSshKeyOpenSsh"
  ]
}
```

These are the import libraries you will most often see for SSH key work:

| Import | Typical use |
| --- | --- |
| `ChangeSshKeyCommon` | Shared orchestration, validation, and common change-key behavior. |
| `UnixShellAuthorizedKeys` | Generic helper logic for locating, reading, and parsing authorized-key files. |
| `UnixShellChangeSshKey` | Generic helper logic for add/remove flows on Unix shells. |
| `UnixShellAuthorizedKeysOpenSsh` | OpenSSH-specific parsing and file conventions. |
| `UnixShellChangeSshKeyOpenSsh` | OpenSSH-specific change-key helpers. |

Use imports when:

- the target behaves like a normal Unix shell
- the server stores keys in OpenSSH-style files
- you want appliance-maintained helpers instead of custom text parsing

Use custom logic when:

- the appliance has a nonstandard key store
- the CLI wraps all changes in a vendor command
- you must preserve options or metadata that the shared helper does not manage

For the exact import names and function signatures available in your build, see [Imports](../reference/imports.md).

## OpenSSH vs legacy formats

Most custom-platform implementations should treat OpenSSH format as the primary target format:

```text
command="/usr/local/bin/wrapper",from="10.0.0.0/8" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... my-comment
```

Key points:

- OpenSSH stores one key per line in `authorized_keys`.
- The line may begin with options such as `command=` or `from=`.
- The key type and base64 payload are the most reliable anchors for parsing.

Legacy considerations:

- some Unix targets still look at `authorized_keys2`
- imported or released keys may exist in SSH2 or PuTTY form elsewhere in SPP workflows
- for management on Unix, normalize to the server's actual accepted format before writing

SPP guidance is also important here:

- access requests can expose keys in multiple client formats
- target-side management is most commonly done with OpenSSH-style files
- imported keys with authorized-key options are a special case: SPP does not automatically preserve those options during rotation

So if your target relies on options or legacy storage conventions, your custom platform must preserve them deliberately.

## Reporting discovered keys

`DiscoverAuthorizedKeys` should emit every discovered key with `WriteDiscoveredSshKey`.

A minimal pattern is:

```json
{
  "WriteDiscoveredSshKey": {
    "KeyType": "%{ ParsedKey.KeyType }%",
    "SshKey": "%{ ParsedKey.KeyValue }%",
    "Comment": "%{ ParsedKey.KeyComment }%",
    "Options": "%{ ParsedKey.Options }%"
  }
}
```

Implementation advice:

- read every candidate authorized-key file
- split the content into lines
- ignore blank lines and invalid lines
- parse each valid key line into `Options`, `KeyType`, `KeyValue`, and `Comment`
- emit one discovered record per key

If your parser does not currently capture options, at least emit `KeyType`, `SshKey`, and `Comment`. But for restricted keys, capturing `Options` is strongly recommended.

## Supporting restricted authorized keys

Restricted keys are keys with option prefixes such as:

- `command="/path/to/command"`
- `from="10.1.2.0/24"`
- `no-port-forwarding`
- `restrict`

The repository's [`RestrictedAuthorizedKeyExample.json`](../../SampleScripts/SSH/RestrictedAuthorizedKeyExample.json) shows the broader pattern of using a restricted key for service-account authentication. For target-account key management, the important lesson is the same: do not assume a key line starts with `ssh-rsa` or `ssh-ed25519`.

A good parser anchors on the key type but allows an optional prefix before it:

```json
{
  "SetItem": {
    "Name": "KeyMatch",
    "Value": "%{ Regex.Match(KeyString, \"^(?<options>.*\\s)?(?<type>ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp521|ecdsa-sha2-nistp384|ecdsa-sha2-nistp256)\\s+(?<key>\\S+)\\s*(?<comment>.*)$\") }%"
  }
}
```

Recommendations for restricted keys:

- preserve the entire options prefix when discovering keys
- when rotating a restricted key, rebuild the full line as `Options + space + NewPublicSshKey + optional comment`
- do not blindly append `%NewPublicSshKey% %NewSshKeyComment%` if the old key had restrictions you must keep
- if restrictions are business-critical, store them separately in a custom parameter or derive them from discovery before rewrite

This matters because SPP does not automatically preserve authorized-key options on imported keys. Your script must own that behavior.

## Error handling guidance

SSH key workflows fail in a few predictable ways. Handle them deliberately.

### Key format mismatches

Validate before writing:

- the line contains a recognized key type
- the base64 payload is well formed
- the discovered key type matches the expected `NewSshKeyType` when your platform requires strict validation

Throw a clear error when the format is invalid instead of writing a malformed line into `authorized_keys`.

### Permission denied on `authorized_keys`

Treat permission failures as hard errors, not as "key missing" results. Typical cases include:

- `Permission denied`
- `Sorry, try again`
- `is not in the sudoers file`
- file ownership or mode preventing write access

A good pattern is:

- `false` for check operations when the key is simply not present
- `Throw` for file access failures, sudo failures, or parse failures

### Safe rollback

For `ChangeSshKey` and `RemoveAuthorizedKey`, treat the `authorized_keys` file atomically — never leave the account in a state where no valid key is installed.

**Pattern:**

1. **Backup first** — copy the current `authorized_keys` to a timestamped backup (e.g., `.authorized_keys.bak`).
2. **Write changes** — append the new key or rewrite the file without the removed key.
3. **Verify** — if possible, attempt a test login with the new private key (or at minimum confirm the file is syntactically valid and non-empty).
4. **On success** — delete the backup.
5. **On failure** — restore the backup over the modified file and `Throw` with a descriptive error.

```json
{
  "Command": "ExecuteCommand",
  "CommandLine": "cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak",
  "ExitStatusBufferName": "rc"
}
```

After the key change commands, verify and conditionally restore:

```json
{
  "Command": "Condition",
  "Expression": "%rc% != 0",
  "Do": [
    {
      "Command": "ExecuteCommand",
      "CommandLine": "cp ~/.ssh/authorized_keys.bak ~/.ssh/authorized_keys",
      "ExitStatusBufferName": "restoreRc"
    },
    {
      "Command": "Throw",
      "Expression": "Key deployment failed — rolled back to previous authorized_keys"
    }
  ]
}
```

**Why this matters:** If a key change is partially applied and the script fails midway, the account could become inaccessible via SSH. The backup/restore pattern ensures Safeguard can retry the operation on the next cycle without manual intervention on the target.

### Keep discovery tolerant but not silent

During `DiscoverAuthorizedKeys`, it is fine to skip blank or malformed lines. But do not silently swallow whole-file access problems. Log the invalid line, skip it, and fail the operation if the file itself cannot be read.

## Related references

- [Operations Reference](../reference/operations.md)
- [Reserved Parameters](../reference/reserved-parameters.md)
- [SSH Platforms Guide](ssh-platforms.md)
- [Imports](../reference/imports.md)
- [Your First SSH Script](../getting-started/your-first-ssh-script.md)
- [Account Discovery](account-discovery.md)
- [Output Commands](../reference/commands/output.md)
