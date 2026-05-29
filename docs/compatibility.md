# SPP Compatibility Matrix

Safeguard custom platform capabilities are derived from the operations, reserved parameter names, and engine features present in your script. Version compatibility matters because a script can be valid JSON and still depend on a capability your SPP appliance does not support yet.

This matrix is based on the current repository documentation, especially the [Operations Reference](reference/operations.md), [Platform Feature Flags](guides/feature-flags.md), [Script Structure Reference](reference/script-structure.md), and [Architecture Overview](getting-started/overview.md).

> [!IMPORTANT]
> This matrix is intentionally conservative. The repository explicitly documents custom platform development on **SPP 6.0 or later**, and it explicitly documents `ExecuteCommand` as available in **SPP 7.4 and later**. For several older capabilities, the exact introduction release is not called out in this repo, so entries marked `🆕` in the `SPP 6.0-7.3` column mean **available by the documented 6.0 baseline, but verify the exact minimum in the [One Identity documentation site](https://docs.oneidentity.com/)** before depending on the feature in older environments.

## Legend

- `🆕` Introduced in this version range, or known to be available by this baseline
- `✅` Supported in this version range
- `❌` Not supported in this version range

## Version Matrix

| Feature or capability | SPP 6.0-7.3 | SPP 7.4+ | Notes |
| --- | :---: | :---: | --- |
| Basic operations: `CheckSystem`, `CheckPassword`, `ChangePassword` | 🆕 | ✅ | Core password-management building blocks documented across the repo. |
| Account discovery: `DiscoverAccounts` | 🆕 | ✅ | Enables `AccountDiscoveryFl`. |
| SSH key validation and rotation: `CheckSshKey`, `ChangeSshKey` | 🆕 | ✅ | Enables `SshKeyFl`. |
| Authorized key discovery: `DiscoverAuthorizedKeys` | 🆕 | ✅ | Enables `DiscoverSshKeyFl`. |
| Host key discovery: `DiscoverSshHostKey` | 🆕 | ✅ | Enables `SshHostKeyFl`. |
| Account enable/disable: `EnableAccount`, `DisableAccount` | 🆕 | ✅ | Enables `SuspendRestoreAccountFl`. |
| JIT elevation/demotion: `ElevateAccount`, `DemoteAccount` | 🆕 | ✅ | Enables `ElevateDemoteAccountFl`. |
| Dependent systems: `UpdateDependentSystem` | 🆕 | ✅ | Enables `DependentSystemFl`. |
| Custom dependency commands: `DependentCommand`, `ExecuteDependentCommand` | 🆕 | ✅ | Treat `SPP 6.0-7.3` as a placeholder baseline; verify the exact minimum against release notes if you target older appliances. |
| File management: `CheckFile`, `ChangeFile` | 🆕 | ✅ | `FileFeatureFl` is always true, but the operations still determine whether useful file workflows exist. |
| Service discovery: `DiscoverServices` | 🆕 | ✅ | Enables `ServiceDiscoveryFl`. |
| API key management: `CheckApiKey`, `ChangeApiKey` | 🆕 | ✅ | Enables `ApiKeyFl`. Verify the exact minimum release if your environment is older than current 6.x/7.x guidance. |
| Import libraries: `Imports` | 🆕 | ✅ | SSH-only system libraries. Customers cannot upload their own import libraries. |
| Custom parameters | 🆕 | ✅ | Non-reserved parameter names surface in **Custom Script Parameters** on the asset. |
| Extended logging: `?extendedLogging=true`, PowerShell `-ExtendedLogging` | 🆕 | ✅ | Development and troubleshooting aid; treat the logs as sensitive. |
| SSH batch command execution: `ExecuteCommand` | ❌ | 🆕 | Explicitly documented as available in SPP 7.4 and later. |

## Notes and Limitations

> [!NOTE]
> The matrix above is about **what the SPP appliance understands**, not just what the JSON schema in this repository accepts.

- `FileFeatureFl` is always enabled for custom platforms, even if you do not implement `CheckFile` or `ChangeFile`.
- `CustomDependencyFl` is set only when `UpdateDependentSystem` declares the reserved `DependentCommand` parameter.
- `ExecuteDependentCommand` is a helper command used inside `UpdateDependentSystem`; it is not a separate top-level operation.
- `ExecuteCommand` requires SSH batch mode (`RequestTerminal: false`) and is the clearest version-specific scripting feature called out in this repo.
- Import libraries are built-in system libraries maintained as part of SPP. They are useful for SSH platforms, but there are no HTTP import libraries documented here.
- `LocalAssetDiscoveryFl` is not available to custom platforms.
- If you need an exact first-supported release for any row marked as `🆕` in `SPP 6.0-7.3`, verify it against the release notes for your appliance version on [docs.oneidentity.com](https://docs.oneidentity.com/).

## How to Check Your Version

1. In the SPP web client, go to **Appliance Management** > **Appliance** > **Appliance Information**.
2. Record the appliance version shown there.
3. If you prefer the API, query the appliance version endpoint (for example, `GET /service/appliance/v4/Version`).
4. Compare that version with the matrix above, then confirm uncertain items in the official release notes on [docs.oneidentity.com](https://docs.oneidentity.com/).

## Related References

- [Operations Reference](reference/operations.md)
- [Platform Feature Flags](guides/feature-flags.md)
- [Script Structure Reference](reference/script-structure.md)
- [System Import Libraries Reference](reference/imports.md)
- [Testing and Debugging](getting-started/testing-and-debugging.md)
