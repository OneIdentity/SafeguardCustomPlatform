[← Command Reference](index.md)

# Encoding and Hashing

These commands help with URL-safe string handling and password-hash operations inside the script engine.

Use `UrlEncode` and `UrlDecode` for transport-safe text, `CryptMd5` when a target system expects a crypt-style MD5 hash, and the comparison commands when you need to verify a supplied password against a stored salted hash.

## `UrlEncode` and `UrlDecode`

### Syntax

```json
{
  "UrlEncode": {
    "Source": "http://some.test.org/query?var1=value1&var2=value2 &var3=passé",
    "ResultVariable": "EncodedUrl",
    "IsSecret": false
  }
}
{
  "UrlDecode": {
    "Source": "%EncodedUrl%",
    "ResultVariable": "DecodedUrl",
    "IsSecret": false
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Source` | String expression | Yes | Text to encode or decode. |
| `ResultVariable` | String | Yes | Variable that receives the converted text. |
| `IsSecret` | Boolean | No | Masks the stored result in logs. Default is `false`. |

## `CryptMd5`

### Syntax

```json
{
  "CryptMd5": {
    "Source": "%NewPassword%",
    "ResultVariable": "NewPass"
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Source` | String expression | Yes | Plaintext value to hash. |
| `ResultVariable` | String | Yes | Variable that receives the generated hash. |

## Password-hash comparison commands

The following commands share the same interface:

- `CompareShadowHash`
- `ComparePasswordHash`
- `CompareMacOsPasswordHash`
- `CompareUnixPasswordHash`

### Shared syntax

```json
{
  "CompareShadowHash": {
    "Password": "%AccountPassword%",
    "SaltedHash": "%AccountEntry%",
    "ResultVariable": "PasswordHashMatched"
  }
}
```

### Shared parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `Password` | Secret expression | Yes | Plaintext password to test. |
| `SaltedHash` | String expression | Yes | Stored salted hash or platform-specific hash text. |
| `ResultVariable` | String | No | Variable that receives the boolean match result. |

### When to use which command

| Command | Target format |
| --- | --- |
| `CompareShadowHash` | Linux `/etc/shadow`-style entries |
| `ComparePasswordHash` | General salted-hash comparison |
| `CompareMacOsPasswordHash` | macOS directory-service shadow hash data |
| `CompareUnixPasswordHash` | General Unix password hash formats |

## Examples

### Encode and decode a URL string

Pattern based on the script-engine URL encode/decode tests:

```json
{
  "UrlEncode": {
    "Source": "http://some.test.org/query?var1=value1&var2=value2 &var3=passé",
    "ResultVariable": "EncodedUrl"
  }
}
{
  "UrlDecode": {
    "Source": "%EncodedUrl%",
    "ResultVariable": "DecodedUrl"
  }
}
```

### Generate a crypt-style MD5 password hash

From the built-in `System/Imports/CheckpointSshFunctions.json` definition:

```json
{
  "CryptMd5": {
    "Source": "%NewPassword%",
    "ResultVariable": "NewPass"
  }
}
```

### Compare against a Linux shadow entry

From `SampleScripts/SSH/GenericLinux.json`:

```json
{
  "CompareShadowHash": {
    "Password": "%AccountPassword%",
    "SaltedHash": "%AccountEntry%",
    "ResultVariable": "PasswordHashMatched"
  }
}
```

### Compare against a general salted hash

From `SampleScripts/SSH/LinuxSshBatchModeExample.json`:

```json
{
  "ComparePasswordHash": {
    "Password": "%AccountPassword%",
    "SaltedHash": "%Entry%",
    "ResultVariable": "PasswordHashMatched"
  }
}
```

### Compare against a macOS shadow hash

From the built-in `System/MacOsSsh.json` platform definition:

```json
{
  "CompareMacOsPasswordHash": {
    "Password": "%AccountPassword%",
    "SaltedHash": "%PasswordHash%",
    "ResultVariable": "PasswordHashMatched"
  }
}
```

## Notes

> `UrlEncode` and `UrlDecode` expect string input. A missing or null `Source` results in an error.

> The comparison commands write a boolean into `ResultVariable` and also return that boolean as the command result.

> `CompareUnixPasswordHash` uses the same parameter shape shown above even though this repository does not currently ship a public sample script that calls it directly.

## Cross-References

- [Commands Index](index.md)
- [Request](request.md)
- [Variables](../variables.md)
