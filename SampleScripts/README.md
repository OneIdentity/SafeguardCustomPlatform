To better understand the content of these sample scripts, read the <a href="../../../wiki">wiki documentation</a>.

These sample custom platform scripts are organized by the protocol used for managing
the asset.  Currently, Safeguard custom platforms support: 
<a href="SSH">SSH</a>,
<a href="Telnet">Telnet (TN3270)</a>, and
<a href="HTTP">HTTP</a>.

It may be possible to support a particular platform using more than one protocol.
Please refer to the Safeguard for Privileged Passwords (SPP) [Administration Guide](https://support.oneidentity.com/technical-documents/one-identity-safeguard/administration-guide) for more information.

## Templates (Pattern Reference)

The [Templates](Templates/) folder contains **pattern templates** — illustrative
scripts that demonstrate common integration patterns and techniques. These are
*not* tested against live targets and are not intended to be deployed as-is.
Use them as a starting point or reference when building your own platform scripts.

Files prefixed with `Pattern-` show recommended approaches for specific scenarios
(REST API auth, JIT elevation, file management, etc.). Files prefixed with
`Template` are minimal starters you can copy and fill in.

See [Templates/README.md](Templates/README.md) for a full listing.

For information on creating and adding a custom platforms, search for these topics in the SPP [Administration Guide](https://support.oneidentity.com/technical-documents/one-identity-safeguard/administration-guide):
 - Custom Platforms
 - Adding a custom platform </br>

For information on assets, search for these topics in the SPP [Administration Guide](https://support.oneidentity.com/technical-documents/one-identity-safeguard/administration-guide):
 - Assets
 - Adding an asset
 - Connection tab (add asset) 
