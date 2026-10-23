# How it works

## Building a container

`New-NAVGitContainer` (and *Build and Update Container*) does this:

1. Load and validate `navgit.json` merged with the defaults and the [user settings](user-settings.md).
2. Check elevation and import BcContainerHelper (the pinned version, if `bcContainerHelperVersion` is set).
3. Get the [credential](#credentials).
4. Resolve the **artifact** to a URL (`Get-NavArtifactUrl` for `nav`, `Get-BcArtifactUrl -type OnPrem` for
   `version`, or the given `url`) and check it is OnPrem, version 9–14.
5. Resolve the **backup** (`database.bakFile`, the `backupFolder` search, or Cronus with `useDemo`).
6. Resolve the **license** (`licenseFile` with `{major}` replaced).
7. Build the `New-BcContainer` parameters and run it.
8. Save the [container state](#container-state) and copy the add-ins.

### The New-BcContainer call

Every setting with a native `New-BcContainer` parameter is passed as that parameter, never as a raw docker
argument. This is the main difference from AdvaniaGIT: with `-bakFile` BcContainerHelper knows a backup is used and
builds the image without the Cronus database.

| New-BcContainer parameter | Value |
| --- | --- |
| `-accept_eula`, `-accept_outdated` | always |
| `-containerName` | `containerName` |
| `-artifactUrl` | resolved `artifact` |
| `-imageName` | `imageName` |
| `-bakFile` | resolved backup (omitted with `useDemo`) |
| `-licenseFile` | resolved `licenseFile` (omitted when empty) |
| `-auth` | `auth` (after the Azure AD check) |
| `-Credential` | stored credential |
| `-isolation` | `isolation` (omitted when empty) |
| `-memoryLimit` | `memoryLimit` (omitted when empty) |
| `-dns` | `dns` (omitted when empty) |
| `-includeCSide` | always (copies the Windows client and finsql.exe to the host) |
| `-doNotExportObjectsToText` | always (NAVGit exports objects itself) |
| `-enableSymbolLoading` | when `enableSymbolLoading` |
| `-includeTestToolkit` | when `includeTestToolkit` |
| `-includeTestLibrariesOnly` | when `includeTestToolkit` and `testToolkit.librariesOnly` |
| `-updateHosts` | `updateHosts` |
| `-shortcuts` | `shortcuts` (default `None`) |
| `-restart` | always `unless-stopped` |
| `-myScripts` | `myScripts` (when not empty) |
| `-additionalParameters` | `additionalParameters`, plus the add-ins volume |

Use `Show-NAVGitContainerCommand` (or `showBcContainerCommand: true`) to see the exact command.

## Importing objects

Each object file's header (Type, ID, Name, Date, Time, Modified, Version List) is compared with the `Object` table
of the container database. An object is imported when it is new, or when its Version List (case-sensitive),
Modified flag, Date or Time differ. A Date or Time that cannot be parsed counts as different. Only changed objects
are joined into one file and imported in one finsql run, so an import after a small change is quick.

Objects in `paths.tests` are read every time, so they never count as "missing", but changed ones are imported only
when `includeTestToolkit` is `true`, `-IncludeTests` is given, or they were imported into the container before
(see [Container state](#container-state)). *Import Test Toolkit* imports them too.

After importing, objects matching `import.compileFilter` are compiled inside the container, the uncompiled ones are
listed (first 25), and the tenant is force-synchronized.

## Exporting objects

Objects are exported to a temporary folder shared with the container, split into one file per object
(`TAB18.TXT`), and mirrored into the repository:

- Each file goes to `paths.tests` if its Version List matches `testObjects.versionListPattern` or it is a test
  codeunit (`includeTestCodeunits`), else to `paths.objects`.
- A file is only written when its bytes differ from the file in Git.
- A copy in the other folder is removed (the object moved category).
- With a full export (no `export.filter`), files for objects that were not exported are deleted. Files in
  `paths.tests` are kept until the test objects have been imported into the container: until then, a test object
  missing from the database was never imported, not deleted.

## Credentials

The container credential is asked for once and stored encrypted with Windows DPAPI (`Export-Clixml`), so only your
Windows account on this machine can read it.

- Stored as `%LOCALAPPDATA%\NAVGit\credentials\default.xml` and shared by all containers. A
  `<containerName>.xml` in the same folder is used first if present, for a container that needs a different
  credential.
- For `Windows` authentication the user name must be your current Windows user (`DOMAIN\user` and `user@domain`
  are both accepted); a stored credential for someone else is skipped.
- For `NavUserPassword` the default user name offered is `admin`. BcContainerHelper sets the SQL `sa` password to the
  same password; NAVGit uses `sa` for imports, exports and the profile list.
- `New-NAVGitContainer -ResetCredential` asks again and overwrites `default.xml`.

## Container state

After a build NAVGit reads the container's server configuration and saves it to
`%LOCALAPPDATA%\NAVGit\containers\<containerName>.json`: artifact URL, version, backup, authentication, server
instance, database server and name, client and management ports, symbol loading, and the host folder with the
Windows client. The client commands use only this file, which is why they need neither elevation nor Docker.

The file also records `testsImported`: whether the objects in `paths.tests` have been imported into this container.
A new container starts at `false`; importing with tests or *Import Test Toolkit* sets it to `true`, and
`Update-NAVGitContainerState` keeps it. Export only deletes files in `paths.tests` when it is `true`. Without the
value (a file from an older NAVGit) `includeTestToolkit` decides.

Containers built another way have no state file; run `Update-NAVGitContainerState` once (elevated).
`Remove-NAVGitContainer` deletes the file.

## Where NAVGit keeps things

| What | Where |
| --- | --- |
| Repository configuration | `<repository>\navgit.json` |
| User settings | `%APPDATA%\NAVGit\settings.json` (or `NAVGIT_SETTINGS_PATH`) |
| Credentials (DPAPI encrypted) | `%LOCALAPPDATA%\NAVGit\credentials\default.xml`, `<container>.xml` |
| Container state | `%LOCALAPPDATA%\NAVGit\containers\<container>.json` |
| Windows client and finsql.exe | `C:\ProgramData\BcContainerHelper\Extensions\<container>\Program Files\<version>\RoleTailored Client` |
| Temporary import/export files | `C:\ProgramData\BcContainerHelper\Extensions\<container>\navgit\<guid>` (removed afterwards) |

`%LOCALAPPDATA%\NAVGit` can be moved with the environment variable `NAVGIT_DATA_PATH`. The
`C:\ProgramData\BcContainerHelper` folder follows BcContainerHelper's `hostHelperFolder` setting.

## Environment variables

| Variable | Effect |
| --- | --- |
| `NAVGIT_SETTINGS_PATH` | Path of the user settings file instead of `%APPDATA%\NAVGit\settings.json`. |
| `NAVGIT_DATA_PATH` | Root folder for credentials and container state instead of `%LOCALAPPDATA%\NAVGit`. |
