[← Documentation](../README.md)

# File Management Guide

This guide shows how to implement file-based credential workflows in Safeguard custom platforms. Use it when the credential you manage is a file rather than a password, SSH key, or API key.

## Table of Contents

- [What file management means in Safeguard](#what-file-management-means-in-safeguard)
- [Core operations](#core-operations)
- [Reserved parameter and feature flag behavior](#reserved-parameter-and-feature-flag-behavior)
- [Common use cases](#common-use-cases)
- [Recommended custom parameters](#recommended-custom-parameters)
- [Implementing `CheckFile`](#implementing-checkfile)
- [Implementing `ChangeFile`](#implementing-changefile)
- [SSH pattern: stage, deploy, verify, clean up](#ssh-pattern-stage-deploy-verify-clean-up)
- [HTTP pattern: upload through an API](#http-pattern-upload-through-an-api)
- [How to decode base64 safely](#how-to-decode-base64-safely)
- [Verification strategies](#verification-strategies)
- [Error handling patterns](#error-handling-patterns)
- [Security considerations](#security-considerations)
- [Related references](#related-references)

## What file management means in Safeguard

In Safeguard, **file management** means managing credentials whose authoritative value is a file payload. Instead of rotating a password string, your custom platform checks or deploys the contents of a file that Safeguard stores securely.

Typical examples include:

- TLS/SSL certificates and certificate bundles
- application config files with embedded credentials
- Java keystores
- license files that expire and need rotation
- SSH private key files managed as files rather than through `CheckSshKey` / `ChangeSshKey`

Safeguard stores the file in the secure file vault, then passes the file content to your script at runtime. Your script is responsible for putting that content in the right place, validating it, and returning success or failure.

## Core operations

File workflows use two operations from the [Operations Reference](../reference/operations.md):

| Operation | Purpose | Typical success condition |
| --- | --- | --- |
| `CheckFile` | Verify that the current file on the target matches the file stored in Safeguard. | The deployed file is current, valid, and in the expected location. |
| `ChangeFile` | Deploy a new file from Safeguard to the target system. | The new file is written successfully and post-change verification succeeds. |

A common pattern is:

1. `CheckFile` compares the target's current state to the expected file.
2. `ChangeFile` stages and deploys the new file.
3. `ChangeFile` verifies the deployment before returning `true`.
4. A later `CheckFile` confirms the target stays in sync.

## Reserved parameter and feature flag behavior

The key reserved parameter is [`FileBase64String`](../reference/reserved-parameters.md#file-management).

| Parameter | Type | Source | Meaning |
| --- | --- | --- | --- |
| `FileBase64String` | `Secret` | Safeguard account secure file vault | Base64-encoded content of the file being checked or changed |

Important details:

- `FileBase64String` is **auto-populated**. Administrators do not type it into Custom Script Parameters.
- The value is a **base64-encoded string**, so your script must either decode it or pass it to a target/API that decodes it.
- Treat it as sensitive data. Use `IsSecret`, `InputContainsSecret`, `CommandContainsSecret`, and similar masking options when needed.

`FileFeatureFl` is a special case. As documented in [Operations](../reference/operations.md#checkfile), it is always `true` for custom platforms. You do **not** enable file support by declaring a parameter or setting a flag manually.

However, the operations still matter:

- `FileFeatureFl` being on does **not** create runnable behavior by itself.
- You still need to define `CheckFile` and/or `ChangeFile` in your script if you want Safeguard to perform those tasks.

## Common use cases

| Use case | What `CheckFile` usually verifies | What `ChangeFile` usually does |
| --- | --- | --- |
| TLS/SSL certificate deployment | Thumbprint, serial number, issuer, expiration, file permissions | Replace certificate/key bundle, then validate certificate metadata |
| Config file with embedded credentials | Exact content or normalized checksum, syntax validity, owner/mode | Write updated config, validate syntax, optionally restart/reload service |
| Java keystore (`.jks`, `.p12`) | Keystore exists, checksum matches, alias/certificate is present | Upload keystore, verify with `keytool`, preserve permissions |
| License file rotation | File exists, checksum matches, target reports active/non-expired license | Replace license file, call reload/import endpoint, confirm active status |
| SSH private key file | Exact bytes, owner, mode, optional fingerprint | Write key file, set restrictive permissions, verify fingerprint/access |

## Recommended custom parameters

`FileBase64String` gives you the file content, but it does not tell your script where or how to deploy it. Most file-management platforms also define custom parameters such as:

| Parameter | Why it is useful |
| --- | --- |
| `TargetPath` | Absolute path of the deployed file on the target system |
| `TargetOwner` / `TargetGroup` | Owner and group that should own the file after deployment |
| `TargetMode` | Required file mode such as `600` or `640` |
| `ReloadCommand` | Optional command or API action to reload the application after update |
| `ApiFileId` / `CertificateAlias` | Target-side identifier used by an HTTP API or keystore tool |

Keep these as normal custom parameters unless Safeguard already provides a matching reserved parameter.

## Implementing `CheckFile`

`CheckFile` should answer one question: **does the target currently have the right file?**

Good `CheckFile` implementations are read-only and explicit. They usually:

1. locate the deployed file or target-side object
2. decode or otherwise interpret `FileBase64String`
3. compare the expected content to the current target content
4. validate extra properties such as permissions, ownership, alias, or expiry
5. return `true` only when everything matches

A minimal parameter block often looks like this:

```json
"CheckFile": {
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
    { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
    { "FuncUserName": { "Type": "String", "Required": true } },
    { "FuncPassword": { "Type": "Secret", "Required": false } },
    { "AccountUserName": { "Type": "String", "Required": true } },
    { "FileBase64String": { "Type": "Secret", "Required": true } },
    { "TargetPath": { "Type": "String", "Required": true } }
  ],
  "Do": [
    { "Comment": { "Text": "Read the deployed file and compare it with FileBase64String" } }
  ]
}
```

Use exact byte-for-byte comparison when the raw file must match exactly. Use semantic validation when the target normalizes the file during import, such as certificate stores or APIs that reformat uploaded content.

## Implementing `ChangeFile`

`ChangeFile` should safely deploy a new file and prove that the deployment worked.

A reliable pattern is:

1. connect or authenticate with the service account
2. stage the new file in a protected temporary location
3. copy or import it into the real target location
4. set ownership and permissions
5. verify the deployed result
6. clean up the staging file
7. return `true`

If rollback is practical, take a backup before replacing the current file. This is especially useful for certificates, keystores, and application configs.

## SSH pattern: stage, deploy, verify, clean up

For SSH-based platforms, the safest general pattern is:

1. connect with the service account
2. write `FileBase64String` to stdin of a remote decode command
3. decode into a protected staging file
4. install or move that file to the real destination
5. verify content and permissions
6. remove the staging file in `Finally`

This keeps the base64 payload out of the command line and preserves binary content exactly.

### Example: `CheckFile` over SSH

```json
{
  "CheckFile": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "Port": { "Type": "Integer", "Required": false, "DefaultValue": 22 } },
      { "Timeout": { "Type": "Integer", "Required": false, "DefaultValue": 20 } },
      { "FuncUserName": { "Type": "String", "Required": true } },
      { "FuncPassword": { "Type": "Secret", "Required": false } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "FileBase64String": { "Type": "Secret", "Required": true } },
      { "TargetPath": { "Type": "String", "Required": true } }
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
          "Timeout": "%Timeout%"
        }
      },
      {
        "Try": {
          "Do": [
            {
              "ExecuteCommand": {
                "ConnectionObjectName": "ConnectSsh",
                "Command": "umask 077; mkdir -p /var/lib/sg-stage; base64 -d > /var/lib/sg-stage/expected.bin",
                "Stdin": [ "%FileBase64String%" ],
                "BufferName": "DecodeStdout",
                "StderrBufferName": "DecodeStderr",
                "ExitStatusBufferName": "DecodeRc",
                "InputContainsSecret": true
              }
            },
            {
              "Condition": {
                "If": "DecodeRc != 0",
                "Then": {
                  "Do": [
                    { "Throw": { "Value": "Unable to decode expected file: %{ DecodeStderr }%" } }
                  ]
                }
              }
            },
            {
              "ExecuteCommand": {
                "ConnectionObjectName": "ConnectSsh",
                "Command": "cmp -s /var/lib/sg-stage/expected.bin %TargetPath%",
                "BufferName": "CompareStdout",
                "StderrBufferName": "CompareStderr",
                "ExitStatusBufferName": "CompareRc"
              }
            },
            {
              "Condition": {
                "If": "CompareRc == 0",
                "Then": { "Do": [ { "Return": { "Value": true } } ] },
                "Else": { "Do": [ { "Throw": { "Value": "File content does not match target file" } } ] }
              }
            }
          ],
          "Finally": [
            {
              "ExecuteCommand": {
                "ConnectionObjectName": "ConnectSsh",
                "Command": "rm -f /var/lib/sg-stage/expected.bin",
                "BufferName": "CleanupStdout",
                "StderrBufferName": "CleanupStderr",
                "ExitStatusBufferName": "CleanupRc"
              }
            },
            { "Disconnect": { "ConnectionObjectName": "ConnectSsh" } }
          ]
        }
      }
    ]
  }
}
```

### Example: core deployment step for `ChangeFile` over SSH

```json
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "umask 077; mkdir -p /var/lib/sg-stage; base64 -d > /var/lib/sg-stage/newfile.bin",
    "Stdin": [ "%FileBase64String%" ],
    "BufferName": "DecodeStdout",
    "StderrBufferName": "DecodeStderr",
    "ExitStatusBufferName": "DecodeRc",
    "InputContainsSecret": true
  }
}
{
  "ExecuteCommand": {
    "ConnectionObjectName": "ConnectSsh",
    "Command": "install -m 600 /var/lib/sg-stage/newfile.bin %TargetPath%",
    "BufferName": "InstallStdout",
    "StderrBufferName": "InstallStderr",
    "ExitStatusBufferName": "InstallRc"
  }
}
```

In real platforms, add ownership changes, backup logic, privilege escalation such as `sudo`, and post-deployment verification before returning success. The general SSH building blocks are covered in the [SSH Platforms Guide](ssh-platforms.md).

## HTTP pattern: upload through an API

For HTTP platforms, the usual pattern is to send the file content to an upload endpoint with `POST` or `PUT`, then verify the target-side object through a follow-up API call.

In many cases, the simplest API contract is to keep the file base64-encoded and send it in JSON. That avoids lossy text conversions and works well for binary files.

### Example: upload base64 content with `PUT`

```json
{
  "SetItem": {
    "Name": "UploadBody",
    "Value": {
      "path": "%TargetPath%",
      "owner": "%AccountUserName%",
      "fileBase64": "%FileBase64String%"
    },
    "IsSecret": true
  }
}
{
  "NewHttpRequest": { "ObjectName": "UploadRequest" }
}
{
  "Headers": {
    "RequestObjectName": "UploadRequest",
    "AddHeaders": {
      "Authorization": "Bearer %AccessToken%",
      "Accept": "application/json"
    }
  }
}
{
  "Request": {
    "RequestObjectName": "UploadRequest",
    "ResponseObjectName": "UploadResponse",
    "Verb": "PUT",
    "Url": "/api/v1/files",
    "Content": {
      "ContentObjectName": "UploadBody",
      "ContentType": "application/json"
    }
  }
}
{
  "Condition": {
    "If": "UploadResponse.StatusCode.ToString().Equals(\"OK\")",
    "Then": { "Do": [ { "Return": { "Value": true } } ] },
    "Else": { "Do": [ { "Throw": { "Value": "Upload failed: HTTP %{ UploadResponse.StatusCode }%" } } ] }
  }
}
```

Do not treat an upload `200 OK` by itself as proof that the file is active. In a production `ChangeFile`, follow the upload with a metadata read, checksum query, certificate lookup, or other verification step, then return `true` only after that verification succeeds.

If the API imports the file into a certificate store, keystore, or licensing subsystem, `CheckFile` should query the API for the imported object's metadata rather than expecting the raw uploaded bytes to remain unchanged.

For general HTTP transport patterns, see the [HTTP Platforms Guide](http-platforms.md).

## How to decode base64 safely

There is no dedicated public `Base64Decode` command in the documented command set. In practice, file-management scripts usually use one of these approaches.

### 1. Preferred for SSH and binary files: decode on the target

Pass `%FileBase64String%` as stdin to a remote command and let the target decode it with native tools. This preserves binary data and keeps the payload off the command line.

Examples of target-side decode commands include:

- Linux or Unix: `base64 -d`
- Windows PowerShell: `[System.Convert]::FromBase64String(...)`
- Windows certutil: `certutil -decode`

### 2. Preferred for HTTP APIs: keep it base64

If the target API can accept a base64 field, do not decode it inside the script at all. Send the base64 value as JSON and let the server-side endpoint decode it.

### 3. Text-only files: decode inside the script engine with a C# expression

For text files such as config fragments, you can decode the payload inside a `SetItem` expression:

```json
{
  "SetItem": {
    "Name": "DecodedText",
    "Value": "%{ System.Text.Encoding.UTF8.GetString(System.Convert.FromBase64String(FileBase64String)) }%",
    "IsSecret": true
  }
}
```

Use this only when the target value is truly UTF-8 text. Do **not** use it for binary files such as PKCS#12 bundles, Java keystores, or opaque license blobs.

## Verification strategies

Choose a verification pattern that matches how the target system stores the file.

### Checksum comparison

Best when the deployed file should match byte-for-byte.

Common approaches:

- decode the expected payload to a staging file and compare with `cmp`
- compute a checksum for both files and compare the digest
- use API-returned digests when the target exposes them

### Certificate validation

Best for PEM, CRT, PFX, or keystore-backed certificate workflows.

Common checks:

- serial number
- thumbprint or fingerprint
- subject / issuer
- not-before and not-after dates
- expected alias in a keystore

Typical target-side tools include `openssl x509`, `openssl pkcs12`, or `keytool -list`.

### File existence, ownership, and permissions

Best when location and filesystem metadata matter as much as content.

Common checks:

- file exists and is non-empty
- expected owner and group are set
- restrictive mode such as `600` or `640` is present
- parent directory is correct and not world-readable

### Application-specific validation

Best when the target imports the file into an internal store.

Examples:

- query an API for the active certificate thumbprint
- run an application config test command
- check that the target now reports the new license as active
- call a reload endpoint and confirm the service accepted the new file

## Error handling patterns

File deployment failures are often operational rather than logical. Surface them clearly.

| Failure | Typical signal | Recommended response |
| --- | --- | --- |
| Permission denied | SSH stderr contains `Permission denied`; API returns `403` or similar | Throw a clear error that names the target path or API resource and the identity used |
| Disk full / no space left | Exit code non-zero; stderr contains `No space left on device` | Fail immediately; do not report success just because decode or upload started |
| File in use / locked | Replace or rename fails; API reports conflict | Retry only if the platform supports a safe retry window; otherwise throw |
| Verification failure | File write succeeds but checksum, cert, or metadata check fails | Throw a verification-specific error and, if possible, restore from backup |
| Cleanup failure | Temp file removal fails | Prefer `Finally` cleanup; if cleanup fails after a successful deployment, surface a warning/error that explains what remains |

A simple `Try` / `Catch` wrapper for a risky deployment step looks like this:

```json
{
  "Try": {
    "Do": [
      {
        "ExecuteCommand": {
          "ConnectionObjectName": "ConnectSsh",
          "Command": "install -m 600 /var/lib/sg-stage/newfile.bin %TargetPath%",
          "BufferName": "InstallStdout",
          "StderrBufferName": "InstallStderr",
          "ExitStatusBufferName": "InstallRc"
        }
      },
      {
        "Condition": {
          "If": "InstallRc != 0",
          "Then": {
            "Do": [
              { "Throw": { "Value": "File deployment failed: %{ InstallStderr }%" } }
            ]
          }
        }
      }
    ],
    "Catch": [
      { "Throw": { "Value": "ChangeFile failed for %TargetPath%: %Exception%" } }
    ]
  }
}
```

For exact syntax, see [error handling commands](../reference/commands/error-handling.md).

## Security considerations

File-based credentials are often long-lived, high-value secrets. Handle them like passwords or private keys.

- Use a protected staging location with restrictive permissions.
- Clean up staging files in `Finally`, not only on the success path.
- Avoid leaving decoded secrets in world-readable locations.
- Prefer stdin over command-line arguments for `%FileBase64String%` so the payload does not appear in process listings.
- Mark intermediate variables and request bodies as secret when they contain file content.
- Verify ownership and permissions after deployment, not just content.
- Do not convert binary payloads to text unless the file format is actually textual.
- If you take backups, protect them with the same permissions as the active file and clean them up according to your operational policy.

## Related references

- [Operations Reference](../reference/operations.md#checkfile)
- [ChangeFile operation](../reference/operations.md#changefile)
- [Reserved Parameters Reference](../reference/reserved-parameters.md#file-management)
- [SSH Platforms Guide](ssh-platforms.md)
- [HTTP Platforms Guide](http-platforms.md)
- [Your First SSH Script](../tutorials/your-first-ssh-script.md)
- [Variables Reference](../reference/variables.md)
- [ExecuteCommand](../reference/commands/execute-command.md)
- [Request](../reference/commands/request.md)
- [Error Handling Commands](../reference/commands/error-handling.md)
