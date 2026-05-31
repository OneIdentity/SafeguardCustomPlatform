[← Concepts](README.md)

# Platform Lifecycle

This document covers the full lifecycle of a custom platform — from initial development through production deployment and ongoing maintenance.

## Phases

```
Author → Upload → Test → Deploy → Monitor → Update
```

## 1. Author

Write your script as a JSON file on your workstation. Use an IDE with the JSON schema for autocomplete:

- Schema: [`schema/custom-platform-script.schema.json`](../../schema/custom-platform-script.schema.json)
- VS Code setup: the `.vscode/` directory in this repo configures schema association automatically.

Start from a [template](../../templates/) or an existing [sample](../../samples/) that matches your target system.

**Best practices during authoring:**
- Start small — get `CheckSystem` working first, then add operations incrementally.
- Use the [development workflow](../guides/development-workflow.md) guide for the upload-test-iterate cycle.
- Test each operation independently before combining them.

## 2. Upload

Upload your script to SPP using either method:

**PowerShell (recommended for development):**
```powershell
Import-SafeguardCustomPlatformScript -FilePath .\MyPlatform.json
```

**Web UI:**
1. Navigate to **Asset Management > Connect and Platforms > Custom Platforms**
2. Click **Add**
3. Browse to your JSON file and upload

SPP validates the script immediately. If validation fails, you get an error message describing the issue. Fix the script and re-upload.

## 3. Test

Testing happens in two stages:

### Local Validation
Use the [TestTool](../../tools/TestTool.ps1) to validate JSON structure before uploading:
```powershell
.\tools\TestTool.ps1 -ScriptFile .\MyPlatform.json
```

### Live Testing
After upload, test against a real (non-production) target:

1. Create a test asset using your custom platform
2. Configure valid credentials
3. Run individual operations:

```powershell
# Test connectivity
Test-SafeguardAssetConnection -AssetToUse "TestHost" -ExtendedLogging

# Test password check
Test-SafeguardAssetAccountPassword -AssetToUse "TestHost" -AccountToUse "testuser" -ExtendedLogging

# Test password change (use a disposable test account!)
Invoke-SafeguardAssetAccountPasswordChange -AssetToUse "TestHost" -AccountToUse "testuser"
```

The `-ExtendedLogging` flag captures the full execution trace in the task log, which is essential for debugging.

See [Testing and Debugging](../guides/testing-and-debugging.md) for detailed guidance.

## 4. Deploy

Once testing passes:

1. Create production assets using the custom platform
2. Assign real service accounts and managed accounts
3. Configure check and change schedules
4. Set up profiles and access policies as needed

**Deployment checklist:**
- [ ] All operations tested successfully with ExtendedLogging
- [ ] Error paths tested (wrong password, unreachable host, locked account)
- [ ] Service account has appropriate privileges on the target
- [ ] Network connectivity confirmed from the SPP appliance to the target
- [ ] Schedules configured appropriately (not too aggressive)

## 5. Monitor

After deployment, monitor platform health through:

- **Task logs** — Check for failed tasks in the SPP Activity Center
- **Password check results** — Confirm scheduled checks pass consistently
- **Account discovery** — If enabled, verify discovered accounts appear correctly

## 6. Update

To update a platform script:

1. Download the current version: use the **Download** button in Custom Platforms or the API
2. Make your changes locally
3. Test the changes against a test asset
4. Upload the updated script — SPP replaces the old version

**Important:** Updating a script does NOT change parameter defaults on existing assets. If you add a new custom parameter with a default value, existing assets won't pick up that default automatically — you need to update them individually or recreate them.

## Version Management

SPP does not version custom platform scripts internally. Best practices:

- Keep your scripts in version control (like this repository)
- Use meaningful commit messages for changes
- Tag releases if you distribute scripts to multiple SPP instances
- Document breaking changes (parameter renames, operation removals) clearly

## Deprecation

To deprecate a custom platform:

1. Ensure no assets are actively using it (or migrate them to a replacement)
2. Delete the custom platform from **Asset Management > Custom Platforms**

**Warning:** Deleting a custom platform that is assigned to assets will reassign those assets to the "Other" platform type, which halts all credential management operations.

## Related

- [Architecture](architecture.md) — how custom platforms fit into SPP
- [Development Workflow](../guides/development-workflow.md) — the upload-test-iterate cycle
- [Testing and Debugging](../guides/testing-and-debugging.md) — detailed testing guidance
