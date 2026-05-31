[← Tutorials](README.md)

# Your First Form-Based Script

By the end of this tutorial, you will have a working custom platform script that logs in to a generic web portal by submitting HTML forms, verifies managed account credentials with `CheckPassword`, and updates the password with `ChangePassword`.

## What You'll Build

You will build a small custom platform script for a generic web portal that exposes only browser-style forms:

- `CheckPassword` — fetches the login page, fills the username and password fields, submits the form, and confirms the account can sign in.
- `ChangePassword` — signs in, opens the password settings page, fills the password-change form, and submits the new password.

This is the right pattern when the target has no REST API and the supported workflow is the same one a browser uses.

## Prerequisites

Before you start, make sure you have:

- A target web application with an HTML login form and a password-change page.
- An SPP appliance and the `safeguard-ps` PowerShell module. If you have not used that workflow before, read [Development Workflow](development-workflow.md).
- Browser developer tools so you can inspect field names and submit URLs.
- Basic familiarity with JSON, HTML forms, and HTTP redirects.

## When to Use Form-Based vs. REST API

| Use form submission when... | Use the REST API pattern when... |
| --- | --- |
| The application only exposes browser login pages. | The application provides documented API endpoints. |
| You must submit HTML form fields such as hidden CSRF tokens. | You can authenticate with HTTP headers or API tokens. |
| Success is visible through redirects or returned HTML. | Success is visible through status codes and JSON responses. |

If the target has a stable API, start with [Your First HTTP Script](your-first-http-script.md). If it only offers browser forms, use this tutorial.

## Step 1: Create the Script Skeleton

Create a new file named `MyFirstFormPlatform.json` and start with this minimal structure:

```json
{
  "Id": "MyFirstFormPlatform",
  "BackEnd": "Scriptable",
  "CheckPassword": {
    "Parameters": [],
    "Do": []
  },
  "ChangePassword": {
    "Parameters": [],
    "Do": []
  },
  "Functions": [
    {
      "Name": "Login",
      "Parameters": [],
      "Do": []
    }
  ]
}
```

This tutorial builds the reusable `Login` function first, then calls it from `CheckPassword` and `ChangePassword`.

## Step 2: Set Up the Base Address

Replace the `Login` function with this version. It defines the function inputs and sets `BaseAddress` before any requests run:

```json
{
  "Name": "Login",
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "UserName": { "Type": "String", "Required": true } },
    { "Password": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "Condition": {
        "If": "UseSsl",
        "Then": { "Do": [ { "BaseAddress": { "Address": "https://%Address%" } } ] },
        "Else": { "Do": [ { "BaseAddress": { "Address": "http://%Address%" } } ] }
    } }
  ]
}
```

This is a single element in the `Functions` array.

## Step 3: Fetch the Login Page

Next, create a request object and send a `GET` to the login page so you can capture the HTML form:

```json
{
  "Name": "Login",
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "UserName": { "Type": "String", "Required": true } },
    { "Password": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "Condition": { "If": "UseSsl", "Then": { "Do": [ { "BaseAddress": { "Address": "https://%Address%" } } ] }, "Else": { "Do": [ { "BaseAddress": { "Address": "http://%Address%" } } ] } } },
    { "NewHttpRequest": { "ObjectName": "LoginPageRequest" } },
    { "Request": { "Verb": "Get", "Url": "/login", "RequestObjectName": "LoginPageRequest", "ResponseObjectName": "Global:LoginResponse", "AllowRedirect": true } }
  ]
}
```

At this stage you are not logging in yet. You are only retrieving the HTML page that contains the form.

## Step 4: Extract the Form

`ExtractFormData` parses the HTML and collects the form fields into a form object, including hidden inputs such as CSRF tokens and session identifiers. Add a null check so failures are clear.

```json
{
  "Name": "Login",
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "UserName": { "Type": "String", "Required": true } },
    { "Password": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "Condition": { "If": "UseSsl", "Then": { "Do": [ { "BaseAddress": { "Address": "https://%Address%" } } ] }, "Else": { "Do": [ { "BaseAddress": { "Address": "http://%Address%" } } ] } } },
    { "NewHttpRequest": { "ObjectName": "LoginPageRequest" } },
    { "Request": { "Verb": "Get", "Url": "/login", "RequestObjectName": "LoginPageRequest", "ResponseObjectName": "Global:LoginResponse", "AllowRedirect": true } },
    { "ExtractFormData": { "ResponseObjectName": "LoginResponse", "FormObjectName": "LoginForm" } },
    { "Condition": { "If": "LoginForm == null", "Then": { "Do": [ { "Throw": { "Value": "Login form not found" } } ] } } }
  ]
}
```

This is the key shift from an API workflow. You start from the real form the portal returned instead of building the POST body by hand.

## Step 5: Fill In the Form Fields

Use `SetFormValue` to update the extracted form object. `InputName` must match the HTML `name` attribute exactly. Mark password values with `IsSecret: true`.

```json
{
  "Name": "Login",
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "UserName": { "Type": "String", "Required": true } },
    { "Password": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "Condition": { "If": "UseSsl", "Then": { "Do": [ { "BaseAddress": { "Address": "https://%Address%" } } ] }, "Else": { "Do": [ { "BaseAddress": { "Address": "http://%Address%" } } ] } } },
    { "NewHttpRequest": { "ObjectName": "LoginPageRequest" } },
    { "Request": { "Verb": "Get", "Url": "/login", "RequestObjectName": "LoginPageRequest", "ResponseObjectName": "Global:LoginResponse", "AllowRedirect": true } },
    { "ExtractFormData": { "ResponseObjectName": "LoginResponse", "FormObjectName": "LoginForm" } },
    { "Condition": { "If": "LoginForm == null", "Then": { "Do": [ { "Throw": { "Value": "Login form not found" } } ] } } },
    { "SetFormValue": { "FormObjectName": "LoginForm", "CreateForm": "DoNotCreate", "InputName": "username", "Value": "%UserName%" } },
    { "SetFormValue": { "FormObjectName": "LoginForm", "CreateForm": "DoNotCreate", "InputName": "password", "Value": "%Password%", "IsSecret": true } }
  ]
}
```

In a real portal, those fields might be `email`, `login`, `session[password]`, or something else. Use the actual HTML field names, not the visible labels on the page.

## Step 6: Submit the Form

Create a second request object and submit the form with `application/x-www-form-urlencoded`. The POST body comes from the form object you already extracted and updated.

```json
{
  "Name": "Login",
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "UserName": { "Type": "String", "Required": true } },
    { "Password": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "Condition": { "If": "UseSsl", "Then": { "Do": [ { "BaseAddress": { "Address": "https://%Address%" } } ] }, "Else": { "Do": [ { "BaseAddress": { "Address": "http://%Address%" } } ] } } },
    { "NewHttpRequest": { "ObjectName": "LoginPageRequest" } },
    { "Request": { "Verb": "Get", "Url": "/login", "RequestObjectName": "LoginPageRequest", "ResponseObjectName": "Global:LoginResponse", "AllowRedirect": true } },
    { "ExtractFormData": { "ResponseObjectName": "LoginResponse", "FormObjectName": "LoginForm" } },
    { "Condition": { "If": "LoginForm == null", "Then": { "Do": [ { "Throw": { "Value": "Login form not found" } } ] } } },
    { "SetFormValue": { "FormObjectName": "LoginForm", "CreateForm": "DoNotCreate", "InputName": "username", "Value": "%UserName%" } },
    { "SetFormValue": { "FormObjectName": "LoginForm", "CreateForm": "DoNotCreate", "InputName": "password", "Value": "%Password%", "IsSecret": true } },
    { "NewHttpRequest": { "ObjectName": "LoginPostRequest" } },
    { "Request": { "Verb": "Post", "Url": "/login/submit", "RequestObjectName": "LoginPostRequest", "ResponseObjectName": "Global:LoginPostResponse", "AllowRedirect": false, "Content": { "ContentObjectName": "LoginForm", "ContentType": "application/x-www-form-urlencoded" } } }
  ]
}
```

The hidden fields captured in `LoginForm` stay with the object, so the POST includes them automatically.

## Step 7: Check the Response

Many portals redirect after a successful login and stay on the login page when authentication fails. Add a redirect-based check and return `true` or `false` from the `Login` function.

```json
{
  "Name": "Login",
  "Parameters": [
    { "Address": { "Type": "String", "Required": true } },
    { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
    { "UserName": { "Type": "String", "Required": true } },
    { "Password": { "Type": "Secret", "Required": true } }
  ],
  "Do": [
    { "Condition": { "If": "UseSsl", "Then": { "Do": [ { "BaseAddress": { "Address": "https://%Address%" } } ] }, "Else": { "Do": [ { "BaseAddress": { "Address": "http://%Address%" } } ] } } },
    { "NewHttpRequest": { "ObjectName": "LoginPageRequest" } },
    { "Request": { "Verb": "Get", "Url": "/login", "RequestObjectName": "LoginPageRequest", "ResponseObjectName": "Global:LoginResponse", "AllowRedirect": true } },
    { "ExtractFormData": { "ResponseObjectName": "LoginResponse", "FormObjectName": "LoginForm" } },
    { "Condition": { "If": "LoginForm == null", "Then": { "Do": [ { "Throw": { "Value": "Login form not found" } } ] } } },
    { "SetFormValue": { "FormObjectName": "LoginForm", "CreateForm": "DoNotCreate", "InputName": "username", "Value": "%UserName%" } },
    { "SetFormValue": { "FormObjectName": "LoginForm", "CreateForm": "DoNotCreate", "InputName": "password", "Value": "%Password%", "IsSecret": true } },
    { "NewHttpRequest": { "ObjectName": "LoginPostRequest" } },
    { "Request": { "Verb": "Post", "Url": "/login/submit", "RequestObjectName": "LoginPostRequest", "ResponseObjectName": "Global:LoginPostResponse", "AllowRedirect": false, "Content": { "ContentObjectName": "LoginForm", "ContentType": "application/x-www-form-urlencoded" } } },
    { "Condition": {
        "If": "LoginPostResponse.StatusCode.ToString().Equals(\"Redirect\") && LoginPostResponse.Headers.ContainsKey(\"Location\")",
        "Then": { "Do": [ { "Return": { "Value": true } } ] },
        "Else": { "Do": [ { "Log": { "Text": "Login did not produce the expected redirect" } }, { "Return": { "Value": false } } ] }
    } }
  ]
}
```

This is a good first success check because it matches how many production portals behave. Later you can tighten it by validating the destination in the `Location` header.

## Step 8: Build CheckPassword

Now call the `Login` function from `CheckPassword`. The operation passes the managed account credentials and turns the boolean result into a clear success or failure.

```json
{
  "CheckPassword": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AccountPassword": { "Type": "Secret", "Required": true } },
      { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
    ],
    "Do": [
      { "Function": { "Name": "Login", "Parameters": [ "%Address%", "%UseSsl%", "%AccountUserName%", "%AccountPassword%" ], "ResultVariable": "LoginResult" } },
      { "Condition": { "If": "LoginResult", "Then": { "Do": [ { "Return": { "Value": true } } ] }, "Else": { "Do": [ { "Throw": { "Value": "CheckPassword failed: portal login was rejected" } } ] } } }
    ]
  }
}
```

At this point, you can validate account credentials against a portal that only exposes a login form.

## Why There Is No CheckSystem

You may notice this script has no `CheckSystem` operation. That is intentional.

`CheckSystem` is SPP's "Test Connection" operation. When SPP runs it, it passes the asset's **service account** credentials (`FuncUserName`/`FuncPassword`) — not the managed account's credentials. The purpose is to verify that SPP can reach the target system using a privileged account that manages other accounts.

Form-based platforms that use a self-service password change model have no separate service account. There is no admin API and no privileged user that resets other users' passwords — each account logs in and changes its own password. Because there are no service account credentials to test, `CheckSystem` has nothing meaningful to do and should be omitted.

This matches the pattern used by existing form-based samples (CustomFacebook, CustomTwitter) which implement only `CheckPassword` and `ChangePassword`.

> **Tip:** If your form-based platform *does* have an admin account that can verify system health (e.g., an admin status page), you can add `CheckSystem` with `FuncUserName`/`FuncPassword` parameters. But for the common self-service pattern, leave it out.

## Step 9: Add ChangePassword

Because there is no admin API, form-based platforms almost always change a password by logging in as the account itself and filling the portal's "change your password" page. The account changes its own password through the same self-service flow a human would use.

This means:

- SPP must know the account's **current** password to log in and perform the change.
- There is typically no separate privileged service account that resets other users' passwords.
- In SPP configuration, set the platform to use the **managed account's own credentials** for the password change operation rather than a shared service account.

Next, add a `ChangePassword` operation. It logs in with the current password, opens the password settings page, extracts the change form, fills the current, new, and confirmation fields, then submits the form.

```json
{
  "ChangePassword": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AccountPassword": { "Type": "Secret", "Required": true } },
      { "NewPassword": { "Type": "Secret", "Required": true } },
      { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
    ],
    "Do": [
      { "Function": { "Name": "Login", "Parameters": [ "%Address%", "%UseSsl%", "%AccountUserName%", "%AccountPassword%" ], "ResultVariable": "LoginResult" } },
      { "Condition": { "If": "!LoginResult", "Then": { "Do": [ { "Throw": { "Value": "ChangePassword failed: login was rejected" } } ] } } },
      { "Condition": { "If": "UseSsl", "Then": { "Do": [ { "BaseAddress": { "Address": "https://%Address%" } } ] }, "Else": { "Do": [ { "BaseAddress": { "Address": "http://%Address%" } } ] } } },
      { "NewHttpRequest": { "ObjectName": "ChangePageRequest" } },
      { "Request": { "Verb": "Get", "Url": "/settings/password", "RequestObjectName": "ChangePageRequest", "ResponseObjectName": "Global:ChangeResponse", "AllowRedirect": true } },
      { "ExtractFormData": { "ResponseObjectName": "ChangeResponse", "FormObjectName": "ChangeForm" } },
      { "Condition": { "If": "ChangeForm == null", "Then": { "Do": [ { "Throw": { "Value": "Password change form not found" } } ] } } },
      { "SetFormValue": { "FormObjectName": "ChangeForm", "CreateForm": "DoNotCreate", "InputName": "current_password", "Value": "%AccountPassword%", "IsSecret": true } },
      { "SetFormValue": { "FormObjectName": "ChangeForm", "CreateForm": "DoNotCreate", "InputName": "new_password", "Value": "%NewPassword%", "IsSecret": true } },
      { "SetFormValue": { "FormObjectName": "ChangeForm", "CreateForm": "DoNotCreate", "InputName": "confirm_password", "Value": "%NewPassword%", "IsSecret": true } },
      { "NewHttpRequest": { "ObjectName": "ChangePostRequest" } },
      { "Request": { "Verb": "Post", "Url": "/settings/password/save", "RequestObjectName": "ChangePostRequest", "ResponseObjectName": "Global:ChangePostResponse", "AllowRedirect": false, "Content": { "ContentObjectName": "ChangeForm", "ContentType": "application/x-www-form-urlencoded" } } },
      { "Condition": { "If": "ChangePostResponse.StatusCode.ToString().Equals(\"Redirect\") && ChangePostResponse.Headers.ContainsKey(\"Location\")", "Then": { "Do": [ { "Return": { "Value": true } } ] }, "Else": { "Do": [ { "Throw": { "Value": "ChangePassword failed: portal did not confirm the password update" } } ] } } }
    ]
  }
}
```

This example uses generic field names such as `current_password` and `confirm_password`. Replace them with the real `name` attributes from your portal.

## Step 10: Full Script

Here is the complete script in one block:

```json
{
  "Id": "MyFirstFormPlatform",
  "BackEnd": "Scriptable",
  "CheckPassword": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AccountPassword": { "Type": "Secret", "Required": true } },
      { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
    ],
    "Do": [
      { "Function": { "Name": "Login", "Parameters": [ "%Address%", "%UseSsl%", "%AccountUserName%", "%AccountPassword%" ], "ResultVariable": "LoginResult" } },
      { "Condition": { "If": "LoginResult", "Then": { "Do": [ { "Return": { "Value": true } } ] }, "Else": { "Do": [ { "Throw": { "Value": "CheckPassword failed: portal login was rejected" } } ] } } }
    ]
  },
  "ChangePassword": {
    "Parameters": [
      { "Address": { "Type": "String", "Required": true } },
      { "AccountUserName": { "Type": "String", "Required": true } },
      { "AccountPassword": { "Type": "Secret", "Required": true } },
      { "NewPassword": { "Type": "Secret", "Required": true } },
      { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } }
    ],
    "Do": [
      { "Function": { "Name": "Login", "Parameters": [ "%Address%", "%UseSsl%", "%AccountUserName%", "%AccountPassword%" ], "ResultVariable": "LoginResult" } },
      { "Condition": { "If": "!LoginResult", "Then": { "Do": [ { "Throw": { "Value": "ChangePassword failed: login was rejected" } } ] } } },
      { "Condition": { "If": "UseSsl", "Then": { "Do": [ { "BaseAddress": { "Address": "https://%Address%" } } ] }, "Else": { "Do": [ { "BaseAddress": { "Address": "http://%Address%" } } ] } } },
      { "NewHttpRequest": { "ObjectName": "ChangePageRequest" } },
      { "Request": { "Verb": "Get", "Url": "/settings/password", "RequestObjectName": "ChangePageRequest", "ResponseObjectName": "Global:ChangeResponse", "AllowRedirect": true } },
      { "ExtractFormData": { "ResponseObjectName": "ChangeResponse", "FormObjectName": "ChangeForm" } },
      { "Condition": { "If": "ChangeForm == null", "Then": { "Do": [ { "Throw": { "Value": "Password change form not found" } } ] } } },
      { "SetFormValue": { "FormObjectName": "ChangeForm", "CreateForm": "DoNotCreate", "InputName": "current_password", "Value": "%AccountPassword%", "IsSecret": true } },
      { "SetFormValue": { "FormObjectName": "ChangeForm", "CreateForm": "DoNotCreate", "InputName": "new_password", "Value": "%NewPassword%", "IsSecret": true } },
      { "SetFormValue": { "FormObjectName": "ChangeForm", "CreateForm": "DoNotCreate", "InputName": "confirm_password", "Value": "%NewPassword%", "IsSecret": true } },
      { "NewHttpRequest": { "ObjectName": "ChangePostRequest" } },
      { "Request": { "Verb": "Post", "Url": "/settings/password/save", "RequestObjectName": "ChangePostRequest", "ResponseObjectName": "Global:ChangePostResponse", "AllowRedirect": false, "Content": { "ContentObjectName": "ChangeForm", "ContentType": "application/x-www-form-urlencoded" } } },
      { "Condition": { "If": "ChangePostResponse.StatusCode.ToString().Equals(\"Redirect\") && ChangePostResponse.Headers.ContainsKey(\"Location\")", "Then": { "Do": [ { "Return": { "Value": true } } ] }, "Else": { "Do": [ { "Throw": { "Value": "ChangePassword failed: portal did not confirm the password update" } } ] } } }
    ]
  },
  "Functions": [
    {
      "Name": "Login",
      "Parameters": [
        { "Address": { "Type": "String", "Required": true } },
        { "UseSsl": { "Type": "Boolean", "Required": false, "DefaultValue": true } },
        { "UserName": { "Type": "String", "Required": true } },
        { "Password": { "Type": "Secret", "Required": true } }
      ],
      "Do": [
        { "Condition": { "If": "UseSsl", "Then": { "Do": [ { "BaseAddress": { "Address": "https://%Address%" } } ] }, "Else": { "Do": [ { "BaseAddress": { "Address": "http://%Address%" } } ] } } },
        { "NewHttpRequest": { "ObjectName": "LoginPageRequest" } },
        { "Request": { "Verb": "Get", "Url": "/login", "RequestObjectName": "LoginPageRequest", "ResponseObjectName": "Global:LoginResponse", "AllowRedirect": true } },
        { "ExtractFormData": { "ResponseObjectName": "LoginResponse", "FormObjectName": "LoginForm" } },
        { "Condition": { "If": "LoginForm == null", "Then": { "Do": [ { "Throw": { "Value": "Login form not found" } } ] } } },
        { "SetFormValue": { "FormObjectName": "LoginForm", "CreateForm": "DoNotCreate", "InputName": "username", "Value": "%UserName%" } },
        { "SetFormValue": { "FormObjectName": "LoginForm", "CreateForm": "DoNotCreate", "InputName": "password", "Value": "%Password%", "IsSecret": true } },
        { "NewHttpRequest": { "ObjectName": "LoginPostRequest" } },
        { "Request": { "Verb": "Post", "Url": "/login/submit", "RequestObjectName": "LoginPostRequest", "ResponseObjectName": "Global:LoginPostResponse", "AllowRedirect": false, "Content": { "ContentObjectName": "LoginForm", "ContentType": "application/x-www-form-urlencoded" } } },
        { "Condition": { "If": "LoginPostResponse.StatusCode.ToString().Equals(\"Redirect\") && LoginPostResponse.Headers.ContainsKey(\"Location\")", "Then": { "Do": [ { "Return": { "Value": true } } ] }, "Else": { "Do": [ { "Log": { "Text": "Login did not produce the expected redirect" } }, { "Return": { "Value": false } } ] } } }
      ]
    }
  ]
}
```

## Validate, Upload, and Test

### Create the platform

Validate the script locally, then create the custom platform:

```powershell
Test-SafeguardCustomPlatformScript ".\MyFirstFormPlatform.json"
New-SafeguardCustomPlatform -Name "My First Form Platform" -ScriptFile ".\MyFirstFormPlatform.json"
```

### Configure password change to use the account's own credentials

Form-based platforms typically require the managed account to log in and change its own password. SPP needs to know to pass the account's current password to the `ChangePassword` operation. This is controlled by a **password change schedule** with the `-RequireCurrentPassword` flag:

```powershell
New-SafeguardPasswordChangeSchedule "Form Self-Service Change" `
    -RequireCurrentPassword `
    -Description "Account logs in and changes its own password via form submission"
```

Then assign this change schedule to the password profile used by the asset (or the partition's default profile):

```powershell
Edit-SafeguardPasswordProfile "Default Profile" -ChangeScheduleToSet "Form Self-Service Change"
```

When `-RequireCurrentPassword` is enabled, SPP supplies the account's current password as `AccountPassword` in the `ChangePassword` operation — which is exactly what the script uses to log in and fill the change form.

### Create the asset and account

```powershell
New-SafeguardCustomPlatformAsset "My First Form Platform" "portal.example.com"
New-SafeguardAssetAccount "portal.example.com" "testuser"
Set-SafeguardAssetAccountPassword "portal.example.com" "testuser"
```

Because this platform has no separate service account, you do not need to configure service account credentials on the asset. The account manages itself.

### Test

```powershell
Test-SafeguardAssetAccountPassword "portal.example.com" "testuser" -ExtendedLogging
```

`Test-SafeguardAssetAccountPassword` runs `CheckPassword` — it logs in as the account and confirms the stored credentials are correct. There is no Test Connection (CheckSystem) for this platform because there is no service account.

For the complete development loop and log review, see [Development Workflow](development-workflow.md).

## Key Differences from REST API Scripts

| Form-based scripts | REST API scripts |
| --- | --- |
| Start by fetching HTML pages. | Start by calling API endpoints directly. |
| Use `ExtractFormData` to capture hidden fields and tokens. | Build JSON payloads and headers explicitly. |
| Use `SetFormValue` to update HTML input fields by name. | Set request bodies, query parameters, or auth headers. |
| Post forms with `application/x-www-form-urlencoded`. | Commonly post JSON or other API-specific payloads. |
| Often detect success from redirects or returned HTML. | Usually detect success from HTTP status codes and JSON content. |

## Tips for Form-Based Scripts

- Use browser developer tools to inspect the real `name` attributes on each input field.
- Let `ExtractFormData` capture hidden inputs first instead of rebuilding CSRF or anti-forgery values yourself.
- For login flows, start with redirect-based success detection because many portals return a redirect on success and re-render the login page on failure.
- Some portals use multi-step authentication flows. If the login form changes after the first submit, repeat the extract, set, and post pattern for each step.
- Use the `Global:` prefix when you need response objects or state to remain available across functions.
- If a portal requires headers such as `Referer` or `User-Agent`, add them with `Headers` before you submit the form.
- During development, run tests with `-ExtendedLogging` so you can see whether the failure happened during page fetch, form extraction, or form submission.
- Remember that form-based platforms typically have no admin-level password reset. Configure SPP so the managed account uses its own credentials for the change operation.

## Next Steps

- [Your First HTTP Script](your-first-http-script.md) — learn the API-first pattern for targets that expose REST endpoints.
- [HTTP Platforms Guide](../guides/http-platforms.md) — broader HTTP scripting patterns and troubleshooting guidance.
- [`CustomFacebook.json`](../../samples/http/facebook/CustomFacebook.json) — production sample showing login and password-change form submission.
- [`CustomTwitter.json`](../../samples/http/twitter/CustomTwitter.json) — another form-based sample with different field names and redirects.
