[← Guides](README.md)

# Account Discovery Guide

Use this guide when you need a custom platform to enumerate accounts on a target and report them back to Safeguard for Privileged Passwords (SPP).

## Table of Contents

- [What account discovery does](#what-account-discovery-does)
- [How the feature flag is enabled](#how-the-feature-flag-is-enabled)
- [Anatomy of a `DiscoverAccounts` operation](#anatomy-of-a-discoveraccounts-operation)
- [Reporting results with `WriteDiscoveredAccount`](#reporting-results-with-writediscoveredaccount)
- [SSH-based discovery patterns](#ssh-based-discovery-patterns)
- [HTTP-based discovery patterns](#http-based-discovery-patterns)
- [Related discovery operations](#related-discovery-operations)
- [Best practices](#best-practices)
- [Error handling](#error-handling)
- [About `DiscoverAssets`](#about-discoverassets)
- [See also](#see-also)

## What account discovery does

When you run an Account Discovery job in SPP, Safeguard invokes the script's `DiscoverAccounts` operation for each asset in scope.

Your script is responsible for:

1. Connecting to the target system.
2. Enumerating accounts on that target.
3. Parsing the returned data into account records.
4. Calling `WriteDiscoveredAccount` once for each account you want Safeguard to consider.
5. Returning success or failure for the overall discovery run.

In product terms, account discovery finds accounts on the managed system and feeds them into Safeguard's discovered-items pipeline. Discovery rules control which accounts are matched, and discovered accounts are not automatically managed unless the discovery job is configured to do that.

## How the feature flag is enabled

You do not set an account-discovery capability manually.

If your script defines a `DiscoverAccounts` operation, Safeguard automatically derives the `AccountDiscoveryFl` feature flag when the script is uploaded. There is no separate checkbox or capability switch to enable.

That same pattern applies to related discovery operations:

- `DiscoverAccounts` -> `AccountDiscoveryFl`
- `DiscoverServices` -> `ServiceDiscoveryFl`
- `DiscoverAuthorizedKeys` -> `DiscoverSshKeyFl`

For the full mapping, see [Operations Reference](../reference/operations.md) and [Feature Flags](feature-flags.md).

## Anatomy of a `DiscoverAccounts` operation

At minimum, `DiscoverAccounts` usually declares the target address and service-account credentials used to enumerate accounts:

- `Address`
- `FuncUserName`
- `FuncPassword`
- `DiscoveryQuery`

Most real scripts also include transport-specific parameters such as:

- SSH: `Port`, `Timeout`, `CheckHostKey`, `HostKey`, `UserKey`, `DelegationPrefix`
- HTTP: `UseSsl`, `SkipServerCertValidation`, custom paging or search parameters

A typical `Do` block follows this pattern:

1. Authenticate or connect.
2. Run one or more commands or requests to list accounts.
3. Parse the response into one account at a time.
4. Emit each match with `WriteDiscoveredAccount`.
5. Clean up the session.
6. `Return` `true` when discovery completed successfully.

### Typical SSH pattern

This example uses SSH batch mode with `ExecuteCommand`, parses `getent passwd`, filters out low-UID system accounts, and emits one discovered account at a time.

```json
{
  "DiscoverAccounts": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
      { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": false } },
      { "CheckHostKey": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
      { "HostKey": { "Type": "String", "Required": false } },
      { "DiscoveryQuery": { "Type": "Object", "Required": true } }
    ],
    "Do": [
      {
        "Connect": {
          "ConnectionObjectName": "Global:ConnectSsh",
          "Type": "Ssh",
          "NetworkAddress": "%Address%",
          "Port": "%Port%",
          "Login": "%FuncUserName%",
          "Password": "%FuncPassword::$%",
          "RequestTerminal": false,
          "CheckHostKey": "%CheckHostKey%",
          "HostKey": "%HostKey::$%",
          "Timeout": "%Timeout%"
        }
      },
      {
        "ExecuteCommand": {
          "ConnectionObjectName": "ConnectSsh",
          "Command": "getent passwd",
          "BufferName": "PasswdStdout",
          "StderrBufferName": "PasswdStderr",
          "ExitStatusBufferName": "PasswdRc"
        }
      },
      { "Disconnect": { "ConnectionObjectName": "ConnectSsh" } },
      {
        "Condition": {
          "If": "PasswdRc != 0",
          "Then": {
            "Do": [
              { "Throw": { "Value": "getent passwd failed: %{PasswdStderr}%" } }
            ]
          }
        }
      },
      {
        "SetItem": {
          "Name": "match",
          "Value": "%{Regex.Match(PasswdStdout, @\"^(?<name>[^:]+):[^:]*:(?<uid>\\d+):(?<gid>\\d+):[^\\r\\n]*$\", RegexOptions.Multiline)}%"
        }
      },
      {
        "For": {
          "Condition": "match.Success",
          "Body": {
            "Do": [
              {
                "Condition": {
                  "If": "int.Parse(match.Groups[\"uid\"].Value) >= 1000",
                  "Then": {
                    "Do": [
                      {
                        "WriteDiscoveredAccount": {
                          "Name": "%{match.Groups[\"name\"].Value}%",
                          "UserId": "%{match.Groups[\"uid\"].Value}%",
                          "GroupId": "%{match.Groups[\"gid\"].Value}%"
                        }
                      }
                    ]
                  }
                }
              },
              { "SetItem": { "Name": "match", "Value": "%{match.NextMatch()}%" } }
            ]
          }
        }
      },
      { "Return": { "Value": true } }
    ]
  }
}
```

## Reporting results with `WriteDiscoveredAccount`

`WriteDiscoveredAccount` is the command that sends one discovered-account record back to Safeguard.

Use it once per account. The most important fields are:

- `Name` - required account name
- `UserId` - optional platform-specific identifier
- `Sid` - optional Windows-style SID
- `GroupId` - optional primary group identifier
- `Groups` - optional array of `DiscoveredGroup` objects
- `Roles` - optional role collection
- `Permissions` - optional permission collection
- `FilterQuery` - optional override for the active discovery filter

If you omit `FilterQuery`, the engine uses the current operation's `DiscoveryQuery`. That is the usual pattern.

### Example with groups

```json
{
  "SetItem": {
    "Name": "GroupList",
    "Value": "%{ new List<DiscoveredGroup>() }%"
  }
}
{
  "Eval": {
    "Expression": "%{ GroupList.Add(new DiscoveredGroup(GroupName, GroupId)) }%"
  }
}
{
  "WriteDiscoveredAccount": {
    "Name": "%{ AccountName }%",
    "UserId": "%{ AccountUid }%",
    "GroupId": "%{ AccountGid }%",
    "Groups": "%{ GroupList }%"
  }
}
```

Include as much identity data as your target exposes. Stable identifiers such as UID, SID, group IDs, role IDs, or API object IDs make discovery results more useful and more durable.

## SSH-based discovery patterns

SSH discovery is usually the best fit when the target is a Unix-like operating system, network appliance, or any host where the service account can run shell commands.

### `/etc/passwd`

Use `/etc/passwd` when you only need local accounts and you know the target keeps the source of truth there.

Common pattern:

- `grep '^[^:#]' /etc/passwd`
- parse `name:password:uid:gid:comment:home:shell`
- filter on UID range, shell, or naming rules

### `getent passwd`

Prefer `getent passwd` when the system may resolve users through NSS, SSSD, LDAP, or another directory-backed source.

This is often better than reading `/etc/passwd` directly because it includes accounts from the system's configured identity providers.

### LDAP queries

If your SSH target fronts a directory service, you may get better results from an LDAP-aware command or CLI tool than from shell account files.

Examples include:

- `ldapsearch` against a directory service
- vendor CLI tools that return user objects
- platform-specific directory commands

This pattern is especially useful when you need more than a simple login name, such as group membership, directory GUIDs, or role-like attributes.

### Windows command-line discovery over SSH or CLI

For Windows-oriented custom platforms that expose a shell or remote command interface, common starting points include:

- `net user` for local accounts
- `net user /domain` for domain contexts where that is supported
- service- or vendor-specific user-list commands

These outputs are usually more text-oriented than Unix account files, so plan to normalize whitespace, headings, and locale-specific strings before parsing.

### Practical SSH advice

- Prefer `ExecuteCommand` for discovery jobs when possible. It is simpler than prompt-by-prompt `Send`/`Receive` flows.
- Set `RequestTerminal` to `false` when using `ExecuteCommand`.
- Force a stable locale when parsing text output if the target supports it.
- Filter obvious system accounts early to reduce work and noise.
- Be careful with commands that require interactive `sudo`. Non-interactive discovery is easier to support and easier to troubleshoot.

## HTTP-based discovery patterns

HTTP discovery is a good fit when the target already exposes a user or account listing API.

The usual flow is:

1. Set the base address.
2. Authenticate and configure headers or tokens.
3. Call a list-users endpoint.
4. Parse the JSON response.
5. Emit one `WriteDiscoveredAccount` per returned object.
6. Follow pagination until there are no more pages.

### Typical paginated API pattern

```json
{
  "DiscoverAccounts": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": true } },
      { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
      { "SkipServerCertValidation": { "Type": "Boolean", "Required": false, "DefaultValue": false } },
      { "DiscoveryQuery": { "Type": "Object", "Required": true } },
      { "ResultsPageLimit": { "Type": "Integer", "Required": false, "DefaultValue": 100 } }
    ],
    "Do": [
      { "BaseAddress": { "Address": "https://%Address%" } },
      { "SetItem": { "Name": "NextUrl", "Value": "/api/users?limit=%ResultsPageLimit%" } },
      {
        "For": {
          "Condition": "!string.IsNullOrEmpty(NextUrl)",
          "Body": {
            "Do": [
              { "NewHttpRequest": { "ObjectName": "ListReq" } },
              {
                "Headers": {
                  "RequestObjectName": "ListReq",
                  "AddHeaders": {
                    "Authorization": "Bearer %FuncPassword%"
                  }
                }
              },
              {
                "Request": {
                  "RequestObjectName": "ListReq",
                  "ResponseObjectName": "ListResp",
                  "Verb": "GET",
                  "Url": "%{ NextUrl }%",
                  "SubstitutionInUrl": true,
                  "IgnoreServerCertAuthentication": "%SkipServerCertValidation%",
                  "Content": {}
                }
              },
              {
                "Condition": {
                  "If": "ListResp.StatusCode != 200",
                  "Then": {
                    "Do": [
                      { "Throw": { "Value": "List users failed: %{ListResp.StatusCode}%" } }
                    ]
                  }
                }
              },
              { "ExtractJsonObject": { "JsonObjectName": "ListResp", "Name": "ListJson" } },
              {
                "ForEach": {
                  "CollectionName": "ListJson.items",
                  "ElementName": "user",
                  "Body": {
                    "Do": [
                      {
                        "WriteDiscoveredAccount": {
                          "Name": "%{ user.userName.ToString() }%",
                          "UserId": "%{ user.id.ToString() }%"
                        }
                      }
                    ]
                  }
                }
              },
              {
                "SetItem": {
                  "Name": "NextUrl",
                  "Value": "%{ ListJson.nextPage == null ? \"\" : ListJson.nextPage.ToString() }%"
                }
              }
            ]
          }
        }
      },
      { "Return": { "Value": true } }
    ]
  }
}
```

### HTTP discovery tips

- Prefer server-side filtering whenever the API supports it.
- Keep page sizes large enough to be efficient but small enough to avoid timeouts.
- Expect throttling, rate limits, and continuation tokens.
- Use stable API IDs when available, not just display names.
- Normalize disabled, deleted, or external users before reporting them.

## Related discovery operations

Account discovery is often implemented alongside other discovery operations.

### `DiscoverServices`

`DiscoverServices` is the related operation for service discovery. It is commonly used for Windows services, scheduled tasks, IIS application pools, DCOM, or COM+ applications that run under managed credentials.

The reporting command is `WriteDiscoveredService`, typically once per service:

```json
{
  "WriteDiscoveredService": {
    "ServiceName": "%{ ServiceName }%",
    "DisplayName": "%{ DisplayName }%",
    "Account": "%{ RunAs }%",
    "ServiceType": "WinService",
    "Enabled": "%{ Enabled }%"
  }
}
```

If you need Safeguard to apply service-discovery rules, use the operation's `ServiceDiscoveryQuery` parameter or override it with `FilterQuery` on the command.

### `DiscoverAuthorizedKeys`

`DiscoverAuthorizedKeys` is the related operation for SSH key discovery on a specific managed account. Instead of returning accounts, it returns the keys found in that account's authorized-keys store.

The reporting command is `WriteDiscoveredSshKey`:

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

Use `DiscoverAuthorizedKeys` when you want Safeguard to inspect existing authorized keys for a managed account, not when you want to enumerate user accounts on the host.

## Best practices

### Filter system and noise accounts deliberately

Do not return every principal blindly.

Common filters include:

- low-UID Unix accounts such as `root`, `daemon`, `bin`, and `nobody`
- accounts with shells like `/usr/sbin/nologin` or `/bin/false`
- disabled or deleted HTTP identities
- vendor-owned service principals that should never be managed by Safeguard

Apply the cheapest filters first so you spend less time parsing or enriching accounts you will discard anyway.

### Prefer server-side filtering and pagination

For large environments, do not fetch everything in one call unless the target is known to be small.

- use paginated API endpoints
- use search parameters if the API supports them
- break shell enumeration into manageable commands when possible
- update status as progress changes so long-running discovery jobs do not look hung

### Include stable identifiers

Names are helpful, but IDs are better.

Where available, populate values such as:

- `UserId`
- `Sid`
- `GroupId`
- group or role IDs

That makes downstream matching more reliable, especially when display names can change.

### Keep parsing rules deterministic

Discovery code is easier to maintain when it depends on structured data or predictable text output.

- prefer JSON APIs over screen scraping
- prefer `getent passwd` over hand-parsing multiple files when NSS matters
- force machine-friendly output formats where the target supports them
- avoid locale-sensitive parsing if you can

### Decide how much enrichment you really need

You can report only `Name`, but sometimes enrichment is worth the extra requests.

Add group, role, or permission data when:

- your discovery rules depend on it
- customers need that context to decide what to manage
- the extra calls are not too expensive for the size of the environment

## Error handling

Discovery jobs often touch many accounts, so make failures easy to understand.

### Fail fast on connection and authentication problems

If the script cannot connect or authenticate, throw an error immediately. That is usually more useful than returning an empty discovery result.

```json
{
  "Try": {
    "Do": [
      { "Function": { "Name": "LoginSsh", "ResultVariable": "LoginResult" } },
      {
        "Condition": {
          "If": "!LoginResult",
          "Then": {
            "Do": [
              { "Throw": { "Value": "Unable to authenticate for discovery" } }
            ]
          }
        }
      }
    ],
    "Catch": [
      { "Throw": { "Value": "Account discovery failed: %Exception%" } }
    ]
  }
}
```

### Continue past bad records when appropriate

A single malformed account entry should not always kill the whole job.

Common pattern:

- throw for transport, authentication, or top-level query failures
- log and continue for one-off parsing problems on a single account
- return `false` or throw if the final result is incomplete and operators should treat it as a failed discovery run

### Report progress for long-running jobs

For large targets, use `Status` messages while discovering. This is especially helpful when:

- enumerating thousands of accounts
- following many API pages
- enriching each account with extra group or role lookups

### Always clean up connections

If you open SSH or HTTP session state, clean it up in success and failure paths. Discovery jobs are often retried, so leaked state makes troubleshooting harder.

## About `DiscoverAssets`

A `DiscoverAssets` concept exists in the broader platform model, but it is not currently usable for custom platforms.

Today, custom platforms cannot light up local asset discovery because the `LocalAssetDiscoveryFl` feature depends on an internal `IsSystemOwned` condition that custom platform scripts cannot set. In practice, that means documenting the operation is fine, but customers should not expect it to become available without a product code change.

If that restriction changes in the future, the related pattern would be similar to account discovery: define the operation, accept the appropriate discovery-query object, and emit discovered items with the matching output command.

## See also

- [Operations Reference](../reference/operations.md)
- [Output Commands](../reference/commands/output.md)
- [Command Index](../reference/commands/index.md)
- [Your First SSH Script](../tutorials/your-first-ssh-script.md)
- [Your First HTTP Script](../tutorials/your-first-http-script.md)
- [SSH Platforms Guide](ssh-platforms.md)
- [HTTP Platforms Guide](http-platforms.md)
