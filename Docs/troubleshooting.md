# Troubleshooting

Add `-Verbose` to any command for detail messages (resolved artifact, overrides, saved files).

| Message | Cause and fix |
| --- | --- |
| `No navgit.json found in '…' or any parent folder.` | Run from inside the repository, pass `-Path`, or create the file with `New-NAVGitConfig` / `ConvertFrom-AdvaniaGitSetup`. |
| `'…navgit.json' is not valid JSON` | Fix the syntax. Remove comments and trailing commas; escape backslashes (`C:\\Backups`). |
| `Invalid NAVGit configuration in '…'` | One line per problem follows. See [Validation](configuration.md#validation). |
| `unknown setting '…' is ignored` (warning) | A misspelt or unsupported key. Check the name against [configuration.md](configuration.md#settings-at-a-glance). |
| `… must run in an elevated PowerShell session` | Start PowerShell or VS Code with *Run as administrator*, or set `navgit.runMode` to `auto` / `elevatedWindow`. |
| `BcContainerHelper could not be imported` | `Install-Module BcContainerHelper -Scope AllUsers`, or install the version pinned in `bcContainerHelperVersion`. |
| `No artifact found for …` | The `nav`/`cu`/`version`/`country` combination does not exist. Try another CU or `select`, or use an explicit `url`. |
| `… is a sandbox artifact` / `NAVGit supports NAV 2016 (9.0) to BC14 (14.x) only` | Use an OnPrem artifact with major version 9–14. |
| `No backup found for '…'. Tried: …` | Put the backup at one of the listed paths, add a name to `database.searchNames`, set `database.bakFile`, or set `database.useDemo`. |
| `No database.bakFile … and no backupFolder in the user settings` | Set one of them, or `database.useDemo: true`. |
| `Backup file '…' from database.bakFile was not found` / `License file '…' was not found` | The listed paths were tried (repository first, then `backupFolder` / `licenseFolder`). Fix the path. |
| `No licenseFile configured; the container uses the demo license` (warning) | Set `licenseFile` if you need your own license range. |
| `additionalParameters contains settings that must use their own navgit.json entry` | Move the listed arguments to their own setting ([table](configuration.md#additionalparameters)). |
| `enableSymbolLoading requires NAV 2018 (11.0) or later` | Turn it off for NAV 2016/2017. |
| `Windows authentication does not work with Azure AD accounts …` (warning) | Set `"auth": "NavUserPassword"`. |
| `Container '…' does not exist. Build it first` | Build with `New-NAVGitContainer`; check `containerName`. |
| `No container information for '…'` | The container was not built by NAVGit; run `Update-NAVGitContainerState` (elevated). |
| `The Windows client for '…' was not found on this machine` | The container was built without `-includeCSide`; rebuild it with NAVGit. |
| `Container '…' does not answer on port …` (warning) | The container is stopped (`docker start <name>`) or not in the hosts file (`updateHosts`). |
| `… changed test object(s) in Tests are not imported because includeTestToolkit is off` | Set `includeTestToolkit: true`, or run *Import Test Toolkit* and then `Import-NAVGitObjects -IncludeTests`. |
| `… object(s) had a Date/Time that could not be read and are imported anyway` | If it happens for all objects, set `import.dateFormat`. |
| Every object is re-imported on each run | Usually a date format mismatch: set `import.dateFormat`. |
| `… exists twice: '…' and '…'` | The same object is in both `Objects` and `Tests` (or twice in one). Delete one copy. |
| `… object(s) are not compiled` (warning) | Fix the objects in C/SIDE, or check that the test toolkit is imported for test objects. |
| `No stored credential for '…'` | Run a container command in a terminal once to enter the credential. |
| VS Code: `The NAVGit module was not found at …` | Fix or clear `navgit.modulePath`. |
| VS Code: `the elevated PowerShell window for '…' was not started` | The UAC prompt was declined. |
