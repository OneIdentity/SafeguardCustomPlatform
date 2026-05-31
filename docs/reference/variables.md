[← Reference](README.md)

# Variables Reference

Variables are the named values the script engine uses to pass data between parameters, commands, functions, and helper logic. Parameters arrive as variables automatically at runtime, and commands such as `SetItem`, `Receive`, `Connect`, and `Function` can create or update additional variables as the task runs.

## Quick Reference

| Concept | Syntax | Example | Notes |
| --- | --- | --- | --- |
| Simple substitution | `%Name%` | `%AccountUserName%` | Replaces the token with the current variable value |
| Inline expression | `%{ expression }%` | `%{ FuncUserName.ToUpper() }%` | Evaluates a C# expression and inserts the result |
| Local variable | `SetItem` | `{ "SetItem": { "Name": "MatchLine", "Value": "%{ Regex.Match(...) }%" } }` | Visible in the current operation/function |
| Global variable | `Global:` / `GLOBAL:` prefix | `{ "SetItem": { "Name": "GLOBAL:ConnectSsh", "Value": null } }` | Persists across functions in the same task execution |
| Secret variable | `"IsSecret": true` | `{ "SetItem": { "Name": "UserCommand", "Value": "username %AccountUserName% secret %NewPassword%", "IsSecret": true } }` | Sensitive value is masked in logs |
| Function result capture | `ResultVariable` | `{ "Function": { "Name": "RunCommand", "ResultVariable": "Result" } }` | Stores a returned value or object in a named variable |

For readability, the examples on this page use compact JSON snippets. See [Script Structure](script-structure.md) for the exact upload format and [Operations](operations.md) for where variables are typically consumed.

```json
{
  "Parameters": [
    {"Name": "Address", "Type": "String"},
    {"Name": "FuncUserName", "Type": "String"},
    {"Name": "FuncPassword", "Type": "Secret"},
    {"Name": "AccountUserName", "Type": "String"}
  ]
}
```

---

## Variable Interpolation

### `%Name%` simple substitution

Use `%VariableName%` when you want to insert the current value of a parameter or variable directly into another command.

```json
{
  "Status": {
    "Type": "Changing",
    "Percent": 50,
    "Message": {
      "Name": "ChangingPassword",
      "Parameters": [ "%AccountUserName%" ]
    }
  }
}
```

This is the most common pattern for:

- status-message parameters
- function arguments
- command buffers
- URLs, usernames, and other string inputs

Parameters declared on an operation or function are automatically available by name, so values such as `%Address%`, `%FuncUserName%`, `%AccountUserName%`, and `%NewPassword%` can be used immediately.

### `%{ expression }%` inline expressions

Use `%{ ... }%` when simple substitution is not enough and you need to compute a value.

```json
{
  "SetItem": {
    "Name": "FuncUserName",
    "Value": "%{ FuncUserName.ToUpper() }%"
  }
}
```

```json
{
  "SetItem": {
    "Name": "MatchLine",
    "Value": "%{ Regex.Match(Result.Stdout, $\"^{AccountUserName}:([^:]+)\", RegexOptions.MultiLine) }%"
  }
}
```

Inside an expression, refer to variables directly as `FuncUserName`, `Result.Stdout`, or `MatchLine.Groups[1].Value`.

> Use `%Name%` for straight substitution and `%{ expression }%` for parsing, normalization, condition building, and object-property access.

---

## Creating Variables with `SetItem`

`SetItem` creates a variable or overwrites an existing one.

### Full form

```json
{ "SetItem": { "Name": "VarName", "Value": "some value" } }
```

The `Value` can be a string, expression result, boolean, integer, array, object, or `null`.

```json
{ "SetItem": { "Name": "TempVar", "Value": "%{ Regex.Replace(LoginPostResponse.Headers[\"Location\"][0], \"(.*challenge_type=)\", \"\") }%" } }
{ "SetItem": { "Name": "GLOBAL:LoginChallenge", "Value": false } }
{ "SetItem": { "Name": "RetrySeconds", "Value": 5 } }
{ "SetItem": { "Name": "CommandResult", "Value": { "rc": 0, "Stdout": "ok", "Stderr": "" } } }
```

### Secret values

If the value itself is sensitive, mark it as secret.

```json
{
  "SetItem": {
    "Name": "UserCommand",
    "Value": "username %AccountUserName% %PasswordType% %NewPassword%",
    "IsSecret": true
  }
}
```

That pattern appears in the Cisco Telnet sample when the script builds a command string that embeds the new password.

### Short form

Older samples also show a shorthand form:

```json
{ "SetItem": "PasswordType" }
```

Use the full object form when possible because it is clearer and lets you show the source value explicitly. The shorthand is useful when the current command context already exposes a same-named value and you just want to materialize it as a variable.

> `SetItem` is the main way to make intermediate parsing results readable. Instead of repeating the same long regex or string transform several times, compute it once and reuse the variable.

---

## Scope

By default, variables are local to the current operation or function.

| Scope | Example | Lifetime |
| --- | --- | --- |
| Local variable | `MatchLine`, `Entry`, `PwdChangeResult` | Current operation or function execution |
| Function parameter | `UserName`, `Password`, `VerifyAccountOnly` | Current function call |
| Global variable | `GLOBAL:ConnectSsh`, `Global:LoginResponse`, `Global:RequestTerminal` | Shared across functions for the current task execution |

Function parameters are explicitly documented as local to the function in [Script Structure](script-structure.md).

To persist a value across functions, prefix the variable name with `Global:` or `GLOBAL:`.

```json
{ "SetItem": { "Name": "GLOBAL:ConnectSsh", "Value": null } }
{ "SetItem": { "Name": "Global:RequestTerminal", "Value": true } }
{ "Request": { "Verb": "Get", "Url": "login", "ResponseObjectName": "Global:LoginResponse" } }
```

The samples use both `Global:` and `GLOBAL:` forms, so treat the prefix as a global-scope marker rather than a naming-style rule.

Global variables persist only for the current platform task execution. They do not survive into a later Check, Change, or Discover request.

> Keep variables local by default. Use global scope only when later functions need the same connection object, response object, or state flag.

---

## Built-in and Common Runtime Variables

A few variable sources appear again and again in custom platform scripts.

| Variable source | Example | How it is populated |
| --- | --- | --- |
| Operation parameters | `%Address%`, `%AccountUserName%`, `%NewPassword%` | Declared in the operation's `Parameters` array |
| Function parameters | `%UserName%`, `%Password%` | Declared in the function's `Parameters` array |
| Catch context | `%Exception%` | Supplied inside `Catch` blocks |
| Receive buffers | `ReturnStatus`, `AccountEntry` | Named by `BufferName` or similar command properties |
| Result variables | `Result`, `LoginResult`, `CheckResult` | Named by `ResultVariable` on `Function`, compare, or command helpers |

### `ReturnStatus`

`ReturnStatus` is a common convention for the latest text returned by `Receive`.

```json
{ "Receive": { "ConnectionObjectName": "ConnectSsh", "BufferName": "ReturnStatus" } }
{ "Switch": { "MatchValue": "%ReturnStatus%", "Cases": [ ... ] } }
```

It is not a reserved parameter name; it is simply a useful buffer variable name that many samples reuse.

### `Result`

`Result` is a common name for a structured result captured with `ResultVariable`.

```json
{
  "Function": {
    "Name": "RunCommand",
    "Parameters": [ "/usr/bin/id %FuncUserName%", false, [], false, false, false ],
    "ResultVariable": "Result"
  }
}
```

Once captured, expressions can read properties from that object:

```json
"Output: %{ Result.Stdout }%  Error: %{ Result.Stderr }%"
```

The exact property names depend on what the command or helper function returned. In the batch-mode SSH sample, the wrapper returns an object with `rc`, `Stdout`, and `Stderr` fields.

---

## Expression Engine

Expressions inside `%{ ... }%` use C# syntax and can call common .NET APIs that appear throughout the sample scripts.

| Pattern | Example | Use |
| --- | --- | --- |
| Normalize text | `%{ AccountUserName.ToUpper() }%` | Force casing before login or lookup |
| Regex parse | `%{ Regex.Match(Result.Stdout, $"^{AccountUserName}:([^:]+)", RegexOptions.MultiLine) }%` | Capture a match object |
| Regex replace | `%{ Regex.Replace(TempVar, "&.*", "") }%` | Strip extra text from a URL or buffer |
| Regex test | `%{ Regex.IsMatch(Result.Stderr, "password updated successfully") }%` | Convert text output into a boolean |
| Property access | `%{ MatchLine.Groups[1].Value }%` | Read fields from returned objects |
| Collection helpers | `%{ StdinArgs.ToList() }%` | Convert arrays before using `Eval` |
| String helpers | `%{ string.IsNullOrEmpty(AssetName) }%` | Guard optional values |
| Interpolated strings | `%{ $"^{AccountUserName}:([^:]+)" }%` | Build expressions from other variables |

A common pattern is to split complex parsing into small steps:

```json
{ "SetItem": { "Name": "MatchLine", "Value": "%{ Regex.Match(Result.Stdout, $\"^{AccountUserName}:([^:]+)\", RegexOptions.MultiLine) }%" } }
{ "SetItem": { "Name": "Entry", "Value": "%{ MatchLine.Groups[1].Value }%" } }
```

That is easier to debug than placing the entire parse pipeline into a single expression.

> Inside `%{ ... }%`, do not wrap variable names in `%...%`. Write `Result.Stdout`, not `%Result.Stdout%`.

---

## Best Practices

- Prefer local variables first; promote to `Global:` only when another function genuinely needs the value.
- Use descriptive names such as `MatchLine`, `LoginResult`, `ServerSoftwareName`, or `PwdChangeResult` instead of one-letter placeholders.
- Mark any generated command or intermediate value as `IsSecret: true` if it contains passwords, private keys, or tokens.
- Normalize or parse once with `SetItem`, then reuse the variable instead of repeating the same expression.
- Keep expressions short and readable. If a regex or transform becomes hard to read, break it into intermediate variables.
- Treat parameter names as part of your variable contract. Reserved names come from SPP; true custom names should be documented clearly for asset admins.
- Prefer the explicit `SetItem` object form over the shorthand unless you specifically need the older compact style.

---

## Cross-References

- [Script Structure](script-structure.md) — exact JSON shape for parameters, functions, and `ResultVariable`
- [Operations](operations.md) — which operations consume which parameters and results
- [Reserved Parameters](reserved-parameters.md) — parameter names that SPP auto-populates
- [Custom Parameters](custom-parameters.md) — defining your own non-reserved names
- [Utilities Commands](commands/utilities.md) — utility-style commands such as `SetItem`, `Declare`, `Eval`, and related helpers
