[← Reference](../README.md)

# Commands Reference

Commands are the building blocks inside `Do` arrays. Each command performs a specific action—making HTTP requests, connecting via SSH, controlling flow, or writing output.

Use this page as the navigation hub for the detailed command reference pages.

## Quick Reference

| Category | Command | Description | Details |
| --- | --- | --- | --- |
| HTTP | `Request` | Execute an HTTP request and capture the response object. | [request.md](request.md) |
| HTTP | `NewHttpRequest` | Create a named HTTP request object for later configuration. | [http-setup.md](http-setup.md) |
| HTTP | `BaseAddress` | Set the base URL that relative request paths resolve against. | [http-setup.md](http-setup.md) |
| HTTP | `Headers` | Add or update HTTP headers on a request object. | [http-setup.md](http-setup.md) |
| HTTP | `HttpAuth` | Apply HTTP authentication such as Basic, Bearer, or NTLM. | [http-auth.md](http-auth.md) |
| HTTP | `GetCookie` | Read a cookie value from the current HTTP session state. | [cookies.md](cookies.md) |
| HTTP | `SetCookie` | Create or overwrite a cookie value for later requests. | [cookies.md](cookies.md) |
| HTTP | `ClearCookie` | Remove a cookie from the current HTTP session state. | [cookies.md](cookies.md) |
| HTTP | `GetFormValue` | Read a field value from an extracted HTML form object. | [forms.md](forms.md) |
| HTTP | `SetFormValue` | Populate a field in a form object before submission. | [forms.md](forms.md) |
| HTTP | `ExtractFormData` | Parse HTML response content into a reusable form object. | [forms.md](forms.md) |
| HTTP | `ExtractJsonObject` | Parse JSON content into an object the script can inspect. | [json.md](json.md) |
| HTTP | `UrlEncode` | Encode text for safe use in URLs or form payloads. | [encoding.md](encoding.md) |
| HTTP | `UrlDecode` | Decode previously encoded URL text. | [encoding.md](encoding.md) |
| HTTP | `CryptMd5` | Generate an MD5 hash value from input text. | [encoding.md](encoding.md) |
| Hashing | `CompareShadowHash` | Compare a password against a salted `/etc/shadow` hash entry. | [encoding.md](encoding.md) |
| Hashing | `ComparePasswordHash` | Compare a password against a salted hash (batch-mode variant). | [encoding.md](encoding.md) |
| Hashing | `CompareMacOsPasswordHash` | Compare a password against a macOS directory-service hash. | [encoding.md](encoding.md) |
| Hashing | `CompareUnixPasswordHash` | Compare a password against a general Unix password hash. | [encoding.md](encoding.md) |
| SSH/Telnet | `Connect` | Open an SSH or Telnet session and create a connection object. | [connect.md](connect.md) |
| SSH/Telnet | `Disconnect` | Close an existing connection object and end the session. | [connect.md](connect.md) |
| SSH/Telnet | `Send` | Send interactive text or commands to a terminal session. | [send-receive.md](send-receive.md) |
| SSH/Telnet | `Receive` | Read terminal output into a buffer variable. | [send-receive.md](send-receive.md) |
| SSH/Telnet | `ExecuteCommand` | Run a remote command in batch mode and capture stdout, stderr, and exit status. | [execute-command.md](execute-command.md) |
| SSH/Telnet | `DiscoverSshHostKey` | Retrieve SSH host key data for asset trust workflows. | [ssh-host-key.md](ssh-host-key.md) |
| Flow Control | `Condition` | Branch to `Then` or `Else` based on an expression result. | [flow-control.md](flow-control.md) |
| Flow Control | `Switch` | Match a value against cases and run the matching block. | [flow-control.md](flow-control.md) |
| Flow Control | `For` | Repeat a block a fixed number of times. | [flow-control.md](flow-control.md) |
| Flow Control | `ForEach` | Iterate over each element in a collection. | [flow-control.md](flow-control.md) |
| Functions | `Function` | Call a named reusable function block. | [functions.md](functions.md) |
| Functions | `Return` | Exit a function or operation and optionally return a value. | [functions.md](functions.md) |
| Functions | `Break` | Exit a loop or function early (alias for `Return`). | [functions.md](functions.md) |
| Functions | `Eval` | Evaluate an expression for side effects or object manipulation. | [functions.md](functions.md) |
| Error Handling | `Try` | Run a block with `Catch` and optional cleanup behavior. | [error-handling.md](error-handling.md) |
| Error Handling | `Throw` | Raise an error to stop execution or trigger a catch block. | [error-handling.md](error-handling.md) |
| Utilities | `SetItem` | Create or update a variable value in script state. | [utilities.md](utilities.md) |
| Utilities | `Declare` | Alias for `SetItem` — create or update a variable. | [utilities.md](utilities.md) |
| Utilities | `Split` | Split text into an array using a delimiter or pattern. | [utilities.md](utilities.md) |
| Utilities | `Comment` | Add an in-script note with no runtime effect. | [utilities.md](utilities.md) |
| Logging and Status | `Log` | Write a message to the task log. | [logging.md](logging.md) |
| Logging and Status | `Status` | Report progress, phase, or a localized status message. | [logging.md](logging.md) |
| Logging and Status | `Wait` | Pause execution for a defined interval. | [logging.md](logging.md) |
| Output | `WriteDiscoveredAccount` | Emit a discovered account record from a discovery script. | [output.md](output.md) |
| Output | `WriteDiscoveredService` | Emit a discovered service record from a discovery script. | [output.md](output.md) |
| Output | `WriteDiscoveredSshKey` | Emit a discovered SSH key record. | [output.md](output.md) |
| Output | `WriteResponseObject` | Write structured response data back to the platform task engine. | [output.md](output.md) |
| Dependent Commands | `ExecuteDependentCommand` | Invoke a custom dependency command exposed to the script. | [execute-dependent-command.md](execute-dependent-command.md) |

## HTTP Commands

HTTP commands handle request construction, authentication, stateful web sessions, and response parsing. They are commonly used together in sequence: configure a request, authenticate if needed, execute it, then inspect cookies, forms, or JSON content.

- [Request](request.md)
- [HTTP setup](http-setup.md): `NewHttpRequest`, `BaseAddress`, `Headers`
- [HTTP authentication](http-auth.md): `HttpAuth`
- [Cookies](cookies.md): `GetCookie`, `SetCookie`, `ClearCookie`
- [Forms](forms.md): `GetFormValue`, `SetFormValue`, `ExtractFormData`
- [JSON](json.md): `ExtractJsonObject`
- [Encoding and hashing](encoding.md): `UrlEncode`, `UrlDecode`, `CryptMd5`, `CompareShadowHash`, `ComparePasswordHash`, `CompareMacOsPasswordHash`, `CompareUnixPasswordHash`

## SSH/Telnet Commands

SSH and Telnet commands manage remote connections and terminal interaction. Use `Connect` and `Disconnect` for session lifecycle, `Send` and `Receive` for interactive prompts, and `ExecuteCommand` when batch-style command execution is a better fit.

- [Connection management](connect.md): `Connect`, `Disconnect`
- [Interactive send/receive](send-receive.md): `Send`, `Receive`
- [Execute command](execute-command.md): `ExecuteCommand`
- [SSH host key](ssh-host-key.md): `DiscoverSshHostKey`

## Flow Control

Flow control commands decide which commands run next and how many times they run. They provide the branching and loop structure inside `Do` arrays.

- [Flow control](flow-control.md): `Condition`, `Switch`, `For`, `ForEach`

## Functions

Function-related commands package reusable logic and return results to the caller. They are the main building blocks for keeping larger scripts organized.

- [Functions](functions.md): `Function`, `Return`, `Break`, `Eval`

## Error Handling

Error handling commands let a script recover from expected failures or stop immediately when continuing would be unsafe. Use them to make task behavior explicit and readable.

- [Error handling](error-handling.md): `Try`, `Throw`

## Utilities

Utility commands support everyday script work such as variable assignment, string processing, and inline documentation.

- [Utilities](utilities.md): `SetItem`, `Declare`, `Split`, `Comment`

## Logging and Status

Logging and status commands communicate progress and diagnostics while a task is running. They are especially useful for long-running password changes, discovery tasks, and remote command workflows.

- [Logging and status](logging.md): `Log`, `Status`, `Wait`

## Output

Output commands emit discovered objects or structured results that the platform consumes after the script finishes. Discovery-oriented scripts often end by calling one or more of these commands.

- [Output](output.md): `WriteDiscoveredAccount`, `WriteDiscoveredService`, `WriteDiscoveredSshKey`, `WriteResponseObject`

## Dependent Commands

Dependent commands provide a way to call custom dependency behavior from within the script engine when the integration exposes it.

- [Execute dependent command](execute-dependent-command.md): `ExecuteDependentCommand`

## Cross-References

- [Variables](../variables.md) for substitution syntax, secrets, and variable scope
- [Operations](../operations.md) for the task entry points that contain `Do` arrays
- [Script Structure](../script-structure.md) for the full JSON layout of a custom platform script
