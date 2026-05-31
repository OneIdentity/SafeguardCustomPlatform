# HTTP Samples

Tested custom platform scripts for managing systems over HTTP/REST APIs. These samples cover REST APIs with various authentication methods, browser-form login workflows, and cloud service integrations.

| Sample | Complexity | Target System |
| --- | --- | --- |
| [facebook](facebook/) | ⭐⭐⭐ | Browser-form credential management (Facebook-style) |
| [twitter](twitter/) | ⭐⭐⭐ | Browser-form login with challenge handling (Twitter-style) |
| [forgerock-openam](forgerock-openam/) | ⭐⭐ | ForgeRock AM 7.5 REST API |
| [okta-discovery](okta-discovery/) | ⭐⭐⭐ | Okta with account discovery and group membership |
| [onelogin-jit](onelogin-jit/) | ⭐⭐⭐ | OneLogin JIT elevation and account activation |
| [wordpress](wordpress/) | ⭐⭐ | WordPress REST API with Basic Auth |

## Choosing a Sample

- **Simple REST API with Basic Auth?** Start with [wordpress](wordpress/).
- **Token-based (OAuth2/Bearer)?** Look at [forgerock-openam](forgerock-openam/).
- **Need account discovery?** See [okta-discovery](okta-discovery/).
- **JIT elevation workflow?** Try [onelogin-jit](onelogin-jit/).
- **Browser-form login (not a REST API)?** See [facebook](facebook/) or [twitter](twitter/).

## Related Docs

- [HTTP Platforms Guide](../../docs/guides/http-platforms.md) — patterns and best practices for HTTP platforms
- [Commands: Request](../../docs/reference/commands/request.md) — HTTP request command reference
- [Commands: HTTP Auth](../../docs/reference/commands/http-auth.md) — authentication methods
- [Commands: Forms](../../docs/reference/commands/forms.md) — HTML form extraction and submission
- [Commands: JSON](../../docs/reference/commands/json.md) — JSON response parsing
