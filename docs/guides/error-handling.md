[← Documentation](../README.md)

# Error Handling Guide

Use this guide when you want Safeguard custom platform scripts to fail predictably, report useful diagnostics, and leave the target system in a clean state.

## Table of Contents

- [How errors propagate](#how-errors-propagate)
- [Using `Try`, `Throw`, and `Catch`](#using-try-throw-and-catch)
- [Choosing between `Return true`, `Return false`, and `Throw`](#choosing-between-return-true-return-false-and-throw)
- [Core error-handling patterns](#core-error-handling-patterns)
  - [Basic try/catch](#basic-trycatch)
  - [Retry pattern](#retry-pattern)
  - [Cleanup on failure](#cleanup-on-failure)
  - [Graceful degradation](#graceful-degradation)
  - [Nested try/catch](#nested-trycatch)
- [SSH-specific error handling](#ssh-specific-error-handling)
- [HTTP-specific error handling](#http-specific-error-handling)
- [Using `ExitStatusBufferName` and `Condition`](#using-exitstatusbuffername-and-condition)
- [Logging best practices](#logging-best-practices)
- [Anti-patterns](#anti-patterns)
- [See also](#see-also)

## How errors propagate

Safeguard runs the commands in an operation's `Do` block in order. Error handling is really about deciding what happens when one of those commands cannot complete.

At a high level:

1. A command succeeds, and execution continues to the next command.
2. A `Return` exits the current function or operation immediately.
3. A `Throw` command, or a command failure such as a failed `Connect` or `Request`, raises an error.
4. If that error happens inside a [`Try`](../reference/commands/error-handling.md) block, the nearest `Catch` block runs.
5. If no enclosing `Try` catches it, the operation stops and Safeguard records the error.

That means you should think about failures in two categories:

- **Expected negative results** — for example, a password is invalid, an account does not exist, or the target returned a clean “no”.
- **Exceptional failures** — for example, the network is down, authentication to the service account failed, JSON parsing failed, or the remote command crashed.

Use `false` for the first category when the operation can still answer cleanly. Use `Throw` for the second category when the operation could not complete normally.

## Using `Try`, `Throw`, and `Catch`

`Try` wraps a protected `Do` block. If a command in that block throws, the commands in `Catch` run. Inside `Catch`, the engine exposes the caught error as `%Exception%`.

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
      { "Log": { "Text": "SSH connect failed: %Exception%" } },
      { "Throw": { "Value": "Unable to connect to %Address%" } }
    ]
  }
}
```

A few important points:

- `Throw` is how you explicitly signal an error from script logic.
- `Catch` is just an array of commands, so you can `Log`, set `Status`, clean up, `Return false`, or `Throw` again with a clearer message.
- If you want the original error text to continue upward, rethrow `%Exception%`.
- `Try` also supports `Finally`, which always runs after `Do` or `Catch`. This is useful for cleanup.
- `Finally` cannot `Return` or `Break`. If `Finally` throws, that cleanup error replaces the earlier result.

For syntax details, see [Error Handling Commands](../reference/commands/error-handling.md). For real examples, compare [`GenericLinux.json`](../../samples/ssh/generic-linux/GenericLinux.json), [`CustomFacebook.json`](../../samples/http/facebook/CustomFacebook.json), and [`OneLogin_GRC_JIT_addon.json`](../../samples/http/onelogin-jit/OneLogin_GRC_JIT_addon.json).

## Choosing between `Return true`, `Return false`, and `Throw`

Safeguard cares about both the boolean result of the operation and whether an unhandled error occurred.

| Script result | When to use it | Safeguard interpretation |
| --- | --- | --- |
| `Return true` | The operation completed and the target state is what you wanted | **Task success** |
| `Return false` | The operation completed, but the answer is a clean “no” or “not successful” | **Task failure** |
| `Throw` or unhandled command exception | The operation could not complete normally because of an exceptional condition | **Task error** |

In practice:

- Use `true` when you positively verified success.
- Use `false` when the script finished its logic and determined the result was negative, such as an invalid password or a non-matching condition.
- Use `Throw` when the operation could not finish reliably, such as connection failures, parse failures, TLS problems, missing required forms, or non-retryable server errors.

This distinction matters most for check-style operations:

- `CheckSystem` usually returns `true` on success and throws on infrastructure or service-account problems.
- `CheckPassword` often returns `false` for “password is not valid”, but throws for connection, parsing, or platform-side errors.
- `ChangePassword` should usually return `true` only after verification and should usually throw on failure rather than quietly returning `false`.

For operation-specific expectations, see [Operations Reference](../reference/operations.md).

## Core error-handling patterns

### Basic try/catch

Wrap risky work, log the original error, and return `false` when you want Safeguard to treat the result as a clean failure instead of an operation error.

```json
{
  "Try": {
    "Do": [
      {
        "Function": {
          "Name": "Login",
          "Parameters": [ "%AccountUserName%", "%AccountPassword%" ],
          "ResultVariable": "LoginOk"
        }
      },
      { "Return": { "Value": "%LoginOk%" } }
    ],
    "Catch": [
      { "Log": { "Text": "CheckPassword failed with exception: %Exception%" } },
      {
        "Status": {
          "Type": "Checking",
          "Percent": 90,
          "Message": {
            "Name": "UnexpectedDataReceived",
            "Parameters": [ "%Exception%" ]
          }
        }
      },
      { "Return": { "Value": false } }
    ]
  }
}
```

Use this pattern when the operator mainly needs a failed result and diagnostics, not a hard task error.

### Retry pattern

Retries belong around **transient** failures such as timeouts, throttling, or temporary `429`/`503` responses. Do not retry bad credentials, malformed requests, or `404` account-not-found errors.

```json
[
  { "SetItem": { "Name": "RetryCount", "Value": 0 } },
  { "SetItem": { "Name": "Done", "Value": false } },
  {
    "For": {
      "Condition": "!Done && RetryCount < 3",
      "Body": {
        "Do": [
          { "SetItem": { "Name": "RequestCompleted", "Value": false } },
          {
            "Try": {
              "Do": [
                {
                  "Request": {
                    "RequestObjectName": "SystemRequest",
                    "ResponseObjectName": "SystemResponse",
                    "Verb": "GET",
                    "Url": "api/status"
                  }
                },
                { "SetItem": { "Name": "RequestCompleted", "Value": true } }
              ],
              "Catch": [
                { "Log": { "Text": "Transient request error on attempt %{RetryCount + 1}%: %Exception%" } },
                { "Wait": { "Seconds": 2 } },
                { "SetItem": { "Name": "RetryCount", "Value": "%{RetryCount + 1}%" } }
              ]
            }
          },
          {
            "Condition": {
              "If": "RequestCompleted",
              "Then": {
                "Do": [
                  {
                    "Switch": {
                      "MatchValue": "%{SystemResponse.StatusCode.ToString()}%",
                      "Cases": [
                        {
                          "CaseValue": "(OK)|(NoContent)",
                          "Do": [
                            { "SetItem": { "Name": "Done", "Value": true } },
                            { "Return": { "Value": true } }
                          ]
                        },
                        {
                          "CaseValue": "(TooManyRequests)|(ServiceUnavailable)|(BadGateway)|(GatewayTimeout)",
                          "Do": [
                            { "Log": { "Text": "Retryable HTTP status %{SystemResponse.StatusCode}% on attempt %{RetryCount + 1}%" } },
                            { "Wait": { "Seconds": 2 } },
                            { "SetItem": { "Name": "RetryCount", "Value": "%{RetryCount + 1}%" } }
                          ]
                        }
                      ],
                      "DefaultCase": {
                        "Do": [
                          { "Throw": { "Value": "Non-retryable HTTP status %{SystemResponse.StatusCode}%" } }
                        ]
                      }
                    }
                  }
                ]
              }
            }
          }
        ]
      }
    }
  },
  { "Throw": { "Value": "Request failed after retries" } }
]
```

This is the usual pattern for network timeouts, rate limits, and short-lived backend outages.

### Cleanup on failure

Always clean up connections, remote sessions, and temporary state. Use `Finally` when you want cleanup to happen whether the protected block succeeds or fails.

```json
{
  "Try": {
    "Do": [
      { "Function": { "Name": "ConnectToAsset" } },
      {
        "ExecuteCommand": {
          "ConnectionObjectName": "ConnectSsh",
          "Command": "/usr/bin/passwd %AccountUserName%",
          "Stdin": [ "%NewPassword%", "%NewPassword%" ],
          "BufferName": "CmdOut",
          "StderrBufferName": "CmdErr",
          "ExitStatusBufferName": "rc",
          "InputContainsSecret": true
        }
      },
      {
        "Condition": {
          "If": "rc == 0",
          "Then": { "Do": [ { "Return": { "Value": true } } ] },
          "Else": { "Do": [ { "Throw": { "Value": "passwd returned exit code %{rc}%" } } ] }
        }
      }
    ],
    "Catch": [
      { "Log": { "Text": "ChangePassword failed: %Exception%" } },
      { "Throw": { "Value": "ChangePassword failed: %Exception%" } }
    ],
    "Finally": [
      {
        "Condition": {
          "If": "ConnectSsh != null",
          "Then": {
            "Do": [
              { "Disconnect": { "ConnectionObjectName": "ConnectSsh" } }
            ]
          }
        }
      }
    ]
  }
}
```

If you also create remote temp files, remove them in `Finally` before disconnecting. If that cleanup can fail, either guard it with [`Condition`](../reference/commands/flow-control.md) or use command-specific exception suppression so cleanup does not hide the original error.

### Graceful degradation

Some operations can succeed partially. Discovery is the classic example: a single bad record should not necessarily fail the entire run.

```json
[
  { "SetItem": { "Name": "DiscoveredCount", "Value": 0 } },
  { "SetItem": { "Name": "SkippedCount", "Value": 0 } },
  {
    "ForEach": {
      "CollectionName": "ParsedUsers",
      "ElementName": "User",
      "Body": {
        "Do": [
          {
            "Try": {
              "Do": [
                {
                  "WriteDiscoveredAccount": {
                    "Name": "%{User.name.Value}%",
                    "UserId": "%{User.id.Value}%"
                  }
                },
                { "SetItem": { "Name": "DiscoveredCount", "Value": "%{DiscoveredCount + 1}%" } }
              ],
              "Catch": [
                { "Log": { "Text": "Skipping malformed discovery record: %Exception%" } },
                { "SetItem": { "Name": "SkippedCount", "Value": "%{SkippedCount + 1}%" } }
              ]
            }
          }
        ]
      }
    }
  },
  {
    "Condition": {
      "If": "DiscoveredCount > 0",
      "Then": {
        "Do": [
          { "Log": { "Text": "Discovery completed with %{SkippedCount}% skipped record(s)" } },
          { "Return": { "Value": true } }
        ]
      },
      "Else": {
        "Do": [
          { "Throw": { "Value": "Discovery did not produce any usable accounts" } }
        ]
      }
    }
  }
]
```

A good rule is:

- **Throw** for connection, authentication, and top-level query failures.
- **Log and continue** for one bad record inside a larger result set.
- **Return `true` with warnings** only when the remaining output is still usable.

### Nested try/catch

Use nested `Try` blocks when one layer can recover locally, but a larger failure should still abort the operation.

```json
{
  "Try": {
    "Do": [
      {
        "Try": {
          "Do": [
            {
              "Request": {
                "RequestObjectName": "UserRequest",
                "ResponseObjectName": "UserResponse",
                "Verb": "GET",
                "Url": "api/users/%AccountUserName%"
              }
            }
          ],
          "Catch": [
            { "Log": { "Text": "Primary request failed, refreshing session: %Exception%" } },
            { "Function": { "Name": "Login" } },
            {
              "Request": {
                "RequestObjectName": "UserRequest",
                "ResponseObjectName": "UserResponse",
                "Verb": "GET",
                "Url": "api/users/%AccountUserName%"
              }
            }
          ]
        }
      },
      {
        "Try": {
          "Do": [
            { "ExtractJsonObject": { "JsonObjectName": "UserResponse", "Name": "ParsedUser" } }
          ],
          "Catch": [
            { "Throw": { "Value": "API returned unexpected JSON for %AccountUserName%" } }
          ]
        }
      },
      { "Return": { "Value": true } }
    ],
    "Catch": [
      { "Status": { "Type": "Checking", "Percent": 90, "Message": { "Name": "UnexpectedDataReceived", "Parameters": [ "%Exception%" ] } } },
      { "Throw": { "Value": "CheckSystem failed: %Exception%" } }
    ]
  }
}
```

The inner `Catch` blocks handle recoverable problems. The outer `Catch` handles the fatal case and produces the final task error.

## SSH-specific error handling

SSH scripts fail at a few predictable points.

### Connection refused

A refused connection usually means the host is reachable but nothing is listening on the SSH port, or a firewall rejected the connection. Catch `Connect` errors and publish a connection-specific status message.

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

SSH authentication problems appear in two forms:

- `Connect` throws immediately in direct-login flows.
- Interactive flows succeed far enough to display text such as `Permission denied`, `Sorry, try again`, or repeated sudo prompts.

For interactive scripts, centralize common error matches and branch on them:

```json
[
  { "SetItem": { "Name": "ErrorRegex", "Value": "(Permission denied)|(Sorry, try again)|(incorrect password attempts)|(is not in the sudoers file)" } },
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
          { "Log": { "Text": "SSH authentication or sudo failure: %{CmdResponse}%" } },
          { "Return": { "Value": false } }
        ]
      }
    }
  }
]
```

Use `false` for a clean “password invalid” result. Use `Throw` when the service account or transport itself is broken.

### Command exit codes

When you use [`ExecuteCommand`](../reference/commands/execute-command.md), always capture stdout, stderr, and the exit code. Many SSH failures are visible only in `rc` and `stderr`.

### Timeout on `Receive`

A slow banner, prompt, or `sudo` policy plugin can make an interactive script look hung unless you capture timeout state explicitly.

```json
[
  {
    "Receive": {
      "ConnectionObjectName": "ConnectSsh",
      "BufferName": "CmdResponse",
      "ExpectRegex": "%ExpectRegex::$%",
      "ExpectTimeout": 10000,
      "TimeoutResultVariableName": "CmdTimedOut"
    }
  },
  {
    "Condition": {
      "If": "CmdTimedOut",
      "Then": {
        "Do": [
          { "Log": { "Text": "Timed out waiting for SSH prompt after command %LastCommand%" } },
          { "Throw": { "Value": "Timed out waiting for remote prompt" } }
        ]
      }
    }
  }
]
```

For more SSH patterns, see [SSH Platforms Guide](ssh-platforms.md) and [Send/Receive](../reference/commands/send-receive.md).

## HTTP-specific error handling

HTTP scripts should distinguish between transport errors, protocol-level status codes, and parsing errors.

### Treat status codes as part of the result

A completed HTTP request is not automatically a successful operation. Always inspect `StatusCode`.

| Status | Typical meaning | Common handling |
| --- | --- | --- |
| `401` | Authentication failed | `Return false` for invalid managed-account credentials; `Throw` for service-account or token-acquisition failures |
| `403` | Authenticated but not allowed | Set a helpful `Status`; usually `Throw` for change/discovery/system operations |
| `404` | Account, resource, or endpoint not found | Usually `Throw` with the missing account or URL in the message |
| `429` | Rate limited | Retry with backoff |
| `500` / `502` / `503` / `504` | Server or gateway issue | Retry if transient, then `Throw` |

A simple pattern looks like this:

```json
{
  "Condition": {
    "If": "SystemResponse.StatusCode == 200 || SystemResponse.StatusCode == 204",
    "Then": {
      "Do": [
        { "Return": { "Value": true } }
      ]
    },
    "Else": {
      "Do": [
        { "Throw": { "Value": "Request failed: HTTP %{SystemResponse.StatusCode}%" } }
      ]
    }
  }
}
```

### Catch request and parsing failures separately

This keeps network or TLS failures distinct from “the response shape changed.”

```json
{
  "Try": {
    "Do": [
      {
        "Request": {
          "RequestObjectName": "UserRequest",
          "ResponseObjectName": "UserResponse",
          "Verb": "GET",
          "Url": "api/users/%AccountUserName%"
        }
      },
      { "ExtractJsonObject": { "JsonObjectName": "UserResponse", "Name": "ParsedUser" } }
    ],
    "Catch": [
      { "Log": { "Text": "HTTP request or parse failure: %Exception%" } },
      { "Throw": { "Value": "Unable to read user data from HTTP response" } }
    ]
  }
}
```

### TLS and certificate errors

TLS failures usually surface as thrown request exceptions. Handle them the same way you handle other request exceptions, but include enough context to tell whether the problem is trust, hostname validation, or protocol mismatch.

Recommendations:

- Prefer fixing the certificate or trust chain over disabling validation.
- Use `SkipServerCertValidation` only for testing or controlled lab scenarios.
- Log the base URL, `UseSsl`, and whether certificate validation was skipped, but never log tokens or secrets.

For broader HTTP patterns, see [HTTP/REST API Platforms](http-platforms.md).

## Using `ExitStatusBufferName` and `Condition`

For SSH batch-mode scripts, [`ExitStatusBufferName`](../reference/commands/execute-command.md) is the standard way to capture a command's numeric exit code. Pair it with [`Condition`](../reference/commands/flow-control.md) so the script can decide whether the result means success, failure, or error. [`LinuxSshBatchModeExample.json`](../../samples/ssh/linux-ssh-batch-mode/LinuxSshBatchModeExample.json) is a good end-to-end sample of this pattern.

```json
[
  {
    "ExecuteCommand": {
      "ConnectionObjectName": "ConnectSsh",
      "Command": "/usr/bin/id %AccountUserName%",
      "BufferName": "Stdout",
      "StderrBufferName": "Stderr",
      "ExitStatusBufferName": "rc"
    }
  },
  {
    "Condition": {
      "If": "rc == 0",
      "Then": {
        "Do": [
          { "Return": { "Value": true } }
        ]
      },
      "Else": {
        "Do": [
          { "Log": { "Text": "id failed. rc=%{rc}%, stderr=%{Stderr}%" } },
          { "Throw": { "Value": "Remote command failed" } }
        ]
      }
    }
  }
]
```

Use the same branching approach for other error states:

- `rc != 0` after `ExecuteCommand`
- `CmdTimedOut == true` after `Receive`
- `SystemResponse.StatusCode == 429` after `Request`
- `ParsedForm == null` after `ExtractFormData`

A useful rule is: **capture a machine-readable error signal first, then branch on it explicitly.**

## Logging best practices

Use [`Log`](../reference/commands/logging.md) and [`Status`](../reference/commands/logging.md) deliberately during error handling.

### Use `Log` for detail

Good `Log` messages answer questions like:

- Which phase failed?
- Which target address, account, or URL was involved?
- Was this attempt 1 of 3 or the final attempt?
- What were the non-secret diagnostics such as `StatusCode`, `rc`, or a short error string?

Examples:

```json
{ "Log": { "Text": "Retry 2/3 after HTTP 429 from /api/users" } }
{ "Log": { "Text": "passwd failed. rc=%{rc}%, stderr=%{CmdErr}%" } }
```

### Use `Status` for operator-visible progress

`Status` is what the operator sees while the task is running. Update it at meaningful boundaries such as connect, authenticate, discover, retry, and cleanup.

### Log before you wrap or rethrow

If you replace the raw exception with a friendlier `Throw`, log `%Exception%` first so the original cause still appears in the task log.

### Never log secrets

Do not log:

- passwords
- tokens
- API keys
- private keys
- full request bodies that may contain secrets

### Keep the logs useful, not noisy

- Log each retry attempt, not every internal variable.
- In large loops, log summaries and skipped counts instead of one message per successful record.
- Prefer one clear message in `Catch` over several vague messages spread across the code path.

For end-to-end debugging workflow, see [Troubleshooting](troubleshooting.md).

## Anti-patterns

### Swallowing errors silently

Bad pattern:

```json
{
  "Try": {
    "Do": [
      { "Request": { "RequestObjectName": "Req", "ResponseObjectName": "Resp", "Verb": "GET", "Url": "api/status" } }
    ],
    "Catch": [
      { "Return": { "Value": false } }
    ]
  }
}
```

This loses the real cause. At minimum, log `%Exception%` before returning or rethrowing.

### Returning `true` when the operation did not really succeed

Do not treat “the command ran” as “the outcome is correct.” Check `StatusCode`, exit codes, response content, or follow-up verification first.

Bad pattern:

```json
[
  { "ExecuteCommand": { "ConnectionObjectName": "ConnectSsh", "Command": "/usr/bin/passwd %AccountUserName%", "BufferName": "Out" } },
  { "Return": { "Value": true } }
]
```

Good scripts verify the result before returning success.

### Not cleaning up resources on error paths

If you open an SSH connection, start an authenticated HTTP session, or create remote temp files, clean them up in both success and failure paths. `Finally` is usually the right place.

### Throwing from cleanup and hiding the original failure

Because a `Finally` error replaces the earlier result, be careful with cleanup code that can throw. Guard it, suppress exceptions when appropriate, and log cleanup failures separately.

## See also

- [Error Handling Commands](../reference/commands/error-handling.md)
- [Flow Control Commands](../reference/commands/flow-control.md)
- [Logging and Status Commands](../reference/commands/logging.md)
- [ExecuteCommand](../reference/commands/execute-command.md)
- [SSH Platforms Guide](ssh-platforms.md)
- [HTTP/REST API Platforms](http-platforms.md)
- [Troubleshooting](troubleshooting.md)
- [Operations Reference](../reference/operations.md)
