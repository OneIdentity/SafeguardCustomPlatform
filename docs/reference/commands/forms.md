[← Command Reference](index.md)

# Forms

`ExtractFormData`, `GetFormValue`/`GetFormData`, and `SetFormValue`/`SetFormData` support browser-style HTML form workflows.

The usual pattern is: request the page, extract the form, inspect or modify fields, then submit the form as `application/x-www-form-urlencoded` content.

## Workflow

1. `Request` downloads the page that contains the form.
2. `ExtractFormData` parses the response body into a reusable form object.
3. `GetFormValue` or `SetFormValue` reads or edits individual fields.
4. `Request` submits the form object as the request body.

## `ExtractFormData`

### Syntax

```json
{
  "ExtractFormData": {
    "ResponseObjectName": "LoginResponse",
    "FormObjectName": "LoginForm",
    "XPath": "//form[@id='login_form']",
    "ContainsSecret": false
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `ResponseObjectName` | String | Yes | Response object that contains the HTML page. |
| `FormObjectName` | String | Yes | Variable name for the extracted form object. |
| `XPath` | String | No | XPath selector used to pick a specific `<form>` element. |
| `ContainsSecret` | Boolean | No | Masks extracted form values in logs. Default is `false`. |

## `GetFormValue` / `GetFormData`

`GetFormData` is an alias of `GetFormValue`.

### Syntax

```json
{
  "GetFormValue": {
    "FormObjectName": "LoginForm",
    "InputName": "authenticity_token",
    "VariableName": "AuthToken",
    "ContainsSecret": true
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `FormObjectName` | String | Yes | Existing form object to read from. |
| `InputName` | String | Yes | Input name to fetch. |
| `VariableName` | String | Yes | Variable that receives the input value. |
| `ContainsSecret` | Boolean | No | Marks the stored value as secret. Default is `false`. |

## `SetFormValue` / `SetFormData`

`SetFormData` is an alias of `SetFormValue`.

### Syntax

```json
{
  "SetFormValue": {
    "FormObjectName": "LoginForm",
    "CreateForm": "DoNotCreate",
    "InputName": "session[password]",
    "Value": "%LoginPassword%",
    "IsSecret": true
  }
}
```

### Parameters

| Name | Type | Required? | Description |
| --- | --- | :---: | --- |
| `FormObjectName` | String | Yes | Existing or new form object to edit. |
| `CreateForm` | String | No | Form creation behavior: `DoNotCreate`, `CreateIfNotFound`, `CreateOrFail`, or `CreateOrReplace`. Default is `CreateIfNotFound`. |
| `InputName` | String | No | Field name to add or replace. Omit it when you only want to create an empty form object. |
| `Value` | String expression | No | Value assigned to `InputName`. |
| `IsSecret` | Boolean | No | Masks the value in logs. Default is `false`. |

## Examples

### Extract the login form from a page

From `SampleScripts/HTTP/CustomTwitter.json`:

```json
{
  "ExtractFormData": {
    "ResponseObjectName": "LoginResponse",
    "FormObjectName": "LoginForm"
  }
}
{
  "Condition": {
    "If": "LoginForm == null",
    "Then": {
      "Do": [
        { "Throw": { "Value": "Error, login form not found" } }
      ]
    }
  }
}
```

### Populate fields before posting the form

From `SampleScripts/HTTP/CustomTwitter.json`:

```json
{
  "SetFormValue": {
    "FormObjectName": "LoginForm",
    "CreateForm": "DoNotCreate",
    "InputName": "session[username_or_email]",
    "Value": "%LoginUserName%"
  }
}
{
  "SetFormValue": {
    "FormObjectName": "LoginForm",
    "CreateForm": "DoNotCreate",
    "InputName": "session[password]",
    "Value": "%LoginPassword%",
    "IsSecret": true
  }
}
```

### The alias form shown in older scripts

From the built-in `System/Twitter.json` platform definition:

```json
{
  "SetFormData": {
    "FormObjectName": "LoginForm",
    "CreateForm": "DoNotCreate",
    "InputName": "session[username_or_email]",
    "Value": "%LoginUserName%"
  }
}
```

### Submit the extracted form

From `SampleScripts/HTTP/CustomTwitter.json`:

```json
{
  "Request": {
    "Verb": "Post",
    "Url": "sessions",
    "RequestObjectName": "LoginPostRequest",
    "ResponseObjectName": "Global:LoginPostResponse",
    "AllowRedirect": false,
    "Content": {
      "ContentObjectName": "LoginForm",
      "ContentType": "application/x-www-form-urlencoded"
    }
  }
}
```

## Notes

> `ExtractFormData` writes `null` when no matching form is found. The Twitter and Facebook samples immediately test for `FormObjectName == null` before continuing.

> Use `CreateForm: "DoNotCreate"` when you expect a real extracted form and want a missing form to fail loudly.

> `GetFormData` and `SetFormData` are legacy-friendly aliases. Prefer `GetFormValue` and `SetFormValue` in new documentation because they are clearer.

## Cross-References

- [Commands Index](index.md)
- [Request](request.md)
- [Cookies](cookies.md)
- [Variables](../variables.md)
