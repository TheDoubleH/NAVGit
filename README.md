# NavGit

A slim replacement for AdvaniaGIT: a PowerShell module and a VS Code extension for working with Dynamics NAV 2016,
NAV 2017, NAV 2018 and Business Central 14 (C/AL) in Docker containers built with
[BcContainerHelper](https://github.com/microsoft/navcontainerhelper).

What NavGit does differently from AdvaniaGIT:

- **The database backup is passed to `New-BcContainer -bakFile`** instead of as a raw `--env bakfile=` docker argument.
  BcContainerHelper then knows a backup is used and builds the image without the Cronus demo database (`-nodb`).
  Raw docker arguments that duplicate a native parameter (`--env bakfile`, `--env licensefile`, credentials,
  `--dns`, `--restart`, `--memory`, `--isolation`, ...) are rejected with a pointer to the right setting.
- **Export routes test objects to `Tests`**: objects whose Version List matches the test pattern (default: an entry
  starting with `Test`) and codeunits with `Subtype=Test` go to `Tests`, everything else to `Objects`. Objects that
  change category are moved.
- **Import reads `Objects` and `Tests`**, compares every object with the database (Version List, Modified, Date,
  Time) and imports only what changed, then compiles and force-syncs.
- **The client and C/SIDE start without elevation** and without copying the client out of the container.

## Requirements

- Windows with Docker (Windows containers)
- Windows PowerShell 5.1
- BcContainerHelper: `Install-Module BcContainerHelper -Scope AllUsers`
- Container and object commands need an elevated (administrator) session; the client commands do not.

## Installation

PowerShell module (from this repository):

```powershell
Import-Module C:\Repos\NAVGit\module\NavGit\NavGit.psd1
```

To have it available everywhere, copy `module\NavGit` to a folder in `$env:PSModulePath`
(e.g. `C:\Program Files\WindowsPowerShell\Modules\NavGit`).

VS Code extension (bundles the module):

```powershell
cd C:\Repos\NAVGit\vscode
npm install
npm run package
code --install-extension navgit-0.1.0.vsix
```

## Quick start

1. Create a `navgit.json` in the repository root:
   - from an AdvaniaGIT repository: `ConvertFrom-AdvaniaGitSetup` (or *NavGit: Create navgit.json* in VS Code), or
   - from scratch: `New-NavGitConfig -Nav 2018 -Cu cu30 -Country no -BakFile C:\Backups\Customer.bak`
2. Optionally create the user settings (see below), e.g. to keep using `C:\AdvaniaGIT\Backup` and `C:\AdvaniaGIT\License`.
3. Check what would be created: `Show-NavGitContainerCommand`
4. Build the container and import the objects (elevated): `Update-NavGitContainer`

## Commands

| VS Code (category *NavGit*) | PowerShell | Elevated |
| --- | --- | --- |
| Build and Update Container | `Update-NavGitContainer` | yes |
| Build Container | `New-NavGitContainer` | yes |
| Remove Container | `Remove-NavGitContainer` | yes |
| Import Test Toolkit | `Import-NavGitTestToolkit` | yes |
| Import All GIT Objects to NAV | `Import-NavGitObjects` | yes |
| Export NAV objects to GIT | `Export-NavGitObjects` | yes |
| Update Add-ins | `Update-NavGitAddIns` | yes |
| Start Development Environment (FinSql) | `Start-NavGitDevelopmentEnvironment` | no |
| Start NAV Client (default) | `Start-NavGitClient` | no |
| Start NAV Client... | `Start-NavGitClient -ProfileId <id>` (console: `-SelectProfile`) | no |
| Create navgit.json | `New-NavGitConfig`, `ConvertFrom-AdvaniaGitSetup` | no |

More PowerShell commands:

- `Show-NavGitContainerCommand`: shows the `New-BcContainer` command for the repository (dry run, no elevation).
- `New-NavGitContainer -WhatIf`: the same, with the elevation and container checks.
- `Update-NavGitContainerState`: re-reads a container's configuration for the client commands. Use it for containers
  that were not built by NavGit, e.g. existing AdvaniaGIT containers.
- `Get-NavGitProfile`: lists the profiles (role centers) of the container database.
- `Invoke-NavGitCommand -Name <name>`: runs a command by its registry name (used by the VS Code extension).

All commands take `-Path` (default: the current folder); any folder or file inside the repository works.

Useful switches:

- `New-NavGitContainer -Force` / `Update-NavGitContainer -Force`: replace an existing container without asking.
- `New-NavGitContainer -ResetCredential`: ask for the container credential again.
- `Import-NavGitObjects -Force`: import every object file, also unchanged ones.
- `Import-NavGitTestToolkit -LibrariesOnly`: only the test libraries.

## navgit.json

Plain JSON (no comments) in the repository root. VS Code validates it with the bundled schema
(`module\NavGit\Schema\navgit.schema.json`). Only `projectName` and `artifact` are required.

```json
{
  "projectName": "Customer",
  "artifact": { "nav": "2018", "cu": "cu30", "country": "no" },
  "database": { "bakFile": "C:\\Backups\\Customer.bak" },
  "licenseFile": "Customer{major}.flf",
  "auth": "NavUserPassword",
  "isolation": "hyperv",
  "includeTestToolkit": true
}
```

| Setting | Default | Description |
| --- | --- | --- |
| `projectName` | (required) | Project name; default container name and backup search name. |
| `containerName` | from `projectName` | 1-15 characters, letters, digits and `-`. Default: `projectName` with `_` → `-`, cut to 15 characters. |
| `artifact` | (required) | Exactly one form: `{ "url": "https://.../onprem/11.0.43274.0/no" }`; `{ "nav": "2018", "cu": "cu30", "country": "no" }` (Get-NavArtifactUrl; nav 2016, 2017 or 2018, cu `rtm` or `cuNN`); or `{ "version": "14.0", "country": "w1", "select": "Latest" }` (Get-BcArtifactUrl, OnPrem; select Latest, First or Closest). Versions 9 (NAV 2016) to 14 (BC14); country defaults to `w1`. |
| `navRelease` | from version | Release name in backup file names: 2016, 2017, 2018, 2019 (BC13), BC14. |
| `imageName` | `navgit` | Local image name. With a backup the cached image is built without the Cronus database. |
| `database.bakFile` | | Backup file: absolute path, path relative to the repository or the user `backupFolder`, or an http(s) URL. |
| `database.searchNames` | `[]` | Extra names to try after `projectName` when searching the `backupFolder`. |
| `database.useDemo` | `false` | Use the Cronus demo database. Without `bakFile`, a found backup or `useDemo`, building fails instead of silently using Cronus. |
| `licenseFile` | | License file: absolute, relative to the repository or the user `licenseFolder`, or a URL. `{major}` is replaced by the major version. Empty: the demo license from the artifact. |
| `auth` | user `defaultAuth`, else `NavUserPassword` on Azure AD joined machines, `Windows` elsewhere | `Windows` or `NavUserPassword`. |
| `isolation` | user `defaultIsolation`, else `""` | `hyperv`, `process` or `""` (BcContainerHelper decides). |
| `memoryLimit` | `""` | E.g. `8G`. BcContainerHelper uses 8G for Hyper-V isolation when empty. |
| `dns` | `""` | DNS server, or `hostDNS`. |
| `updateHosts` | `true` | Add the container to the hosts file (needed by the client commands). |
| `enableSymbolLoading` | `false` | Symbol loading (NAV 2018 / BC14 only). |
| `includeTestToolkit` | `false` | Import the test toolkit while building the container (so Build and Update can compile test objects). |
| `testToolkit.country` | `""` | Localized test toolkit. |
| `testToolkit.librariesOnly` | `false` | Only the test libraries. |
| `myScripts` | `[]` | Scripts for `New-BcContainer -myScripts` (URLs or paths). |
| `additionalParameters` | `[]` | Extra docker arguments; settings with their own entry are rejected. |
| `paths.objects` | `Objects` | Folder for application objects. |
| `paths.tests` | `Tests` | Folder for test objects. |
| `paths.addIns` | `Add-Ins` | .NET add-ins. When the folder exists it is mapped to `c:\run\Add-ins` and copied to the service tier and Windows client. `""` disables it. |
| `testObjects.versionListPattern` | `(^\|,)\s*Test` | Case-insensitive regular expression on the Version List that marks test objects. |
| `testObjects.includeTestCodeunits` | `true` | Also treat codeunits with `Subtype=Test` as test objects. |
| `import.deleteMissing` | `warn` | Objects in the database but not in Git: `warn`, or `mark` (Version List `#DELETE`, as AdvaniaGIT did). |
| `import.syncSchema` | `Force` | `SynchronizeSchemaChanges` for import and compile: `Force`, `Yes`, `No`. |
| `import.compileFilter` | `Compiled=0` | Objects compiled after an import. |
| `import.dateFormat` | `""` | Date format in the object files, e.g. `M/d/yy` or `dd.MM.yy`. Empty: from the separator (`.` dd.MM.yy, `-` dd-MM-yy, `/` MM/dd/yy). An unreadable date only means that object is re-imported. |
| `export.filter` | `""` | C/SIDE filter for the export; empty exports all objects. Only a full export removes files of deleted objects. |
| `export.format` | `txt folder` | Export format. |
| `client.defaultProfile` | `""` | Profile opened by *Start NAV Client (default)*; empty opens the default role center. |

## User settings

`%APPDATA%\NavGit\settings.json` (optional, per user, not in Git):

```json
{
  "backupFolder": "C:\\AdvaniaGIT\\Backup",
  "licenseFolder": "C:\\AdvaniaGIT\\License",
  "defaultAuth": "NavUserPassword",
  "defaultIsolation": "hyperv",
  "bcContainerHelperVersion": ""
}
```

- `backupFolder`: searched when `database.bakFile` is not set, in AdvaniaGIT's order:
  `<release>-<name>.bak`, `<release>\<version>\<name>.bak`, `<release>\<name>.bak` for `projectName`, then each of
  `database.searchNames`.
- `licenseFolder`: used for relative `licenseFile` values.
- `defaultAuth` / `defaultIsolation`: used when `navgit.json` has no `auth` / `isolation`.
- `bcContainerHelperVersion`: pin a BcContainerHelper version.

## Where NavGit keeps things

| What | Where |
| --- | --- |
| Container credential (DPAPI encrypted, current user only) | `%LOCALAPPDATA%\NavGit\credentials\default.xml` (or `<container>.xml`) |
| Container state for the client commands | `%LOCALAPPDATA%\NavGit\containers\<container>.json` |
| Windows client and finsql.exe (copied by BcContainerHelper) | `C:\ProgramData\BcContainerHelper\Extensions\<container>\Program Files\<version>\RoleTailored Client` |
| Temporary import/export files | `C:\ProgramData\BcContainerHelper\Extensions\<container>\navgit\<guid>` (removed afterwards) |

For NavUserPassword containers the SQL `sa` password is the container password; NavGit uses it for imports, exports
and the profile list.

## Moving from AdvaniaGIT

`ConvertFrom-AdvaniaGitSetup` reads `setup.json` together with `C:\AdvaniaGIT\Data\GITSettings.Json` (setup.json wins,
as in AdvaniaGIT) and writes `navgit.json`. Run it with `-WhatIf` first to see the result and the notes.

| AdvaniaGIT | navgit.json |
| --- | --- |
| `projectName` | `projectName` |
| `dockerFriendlyName` | `containerName` |
| `artifact` (URL) | `artifact.url` |
| `artifact` (`storageAccount/type/version/country/select`) | `artifact.version`, `artifact.country`, `artifact.select` |
| `navVersion` (no `artifact`) | `artifact.version` (country `w1`, check it) |
| `dockerImage` | not supported (no more images); use an artifact |
| `dockerRestoreBackup: true` | backup search in `backupFolder`, with `baseBranch` and `navSolution` as `database.searchNames` |
| `dockerRestoreBackup` not set | `database.useDemo: true` |
| `licenseFile` (`%1` = version) | `licenseFile` (`{major}`) |
| `dockerAuthentication` | `auth` |
| `dockerIsolation` | `isolation` |
| `dockerMemoryLimit` (ignored by AdvaniaGIT) | `memoryLimit` (applied) |
| `dockerTestToolkit`, `dockerTestLibraries`, `testToolkitCountry` | `includeTestToolkit`, `testToolkit.librariesOnly`, `testToolkit.country` |
| `dockerEnableSymbolLoading` | `enableSymbolLoading` |
| `dockerMyScripts` | `myScripts` |
| `mapAddInFolder` | `paths.addIns` (`Add-Ins` by default, `""` when it was `false`) |
| `objectsPath`, `testObjectsPath` | `paths.objects`, `paths.tests` |
| `datetimeCulture` | `import.dateFormat` (short date pattern with a two-digit year) |

Behaviour differences worth knowing:

- AdvaniaGIT never imported the `Tests` folder; NavGit does, so the first import adds your test objects.
- Objects your license cannot export (`ExportTxtSkipUnlicensed`) are in the database but not in Git; the import lists
  them as "not in Git" and leaves them alone (`import.deleteMissing: warn`).
- AdvaniaGIT containers are not known to the client commands until you run `Update-NavGitContainerState` once
  (elevated) in the repository.
- Not ported: deltas (`storeAllObjects: false`), FTP backups, PasswordState, CI/AL build pipelines.

## Development

```text
module/NavGit/        PowerShell module
  Commands.psd1       command registry (used by Invoke-NavGitCommand and the extension)
  Public/             exported commands, one file per command
  Private/            helpers (Config, Container, Objects, Clients, State, Common)
  Schema/             navgit.json schema
module/Tests/         Pester tests
vscode/               VS Code extension (TypeScript)
```

Tests:

```powershell
.\module\Tests\Invoke-NavGitTests.ps1          # Pester 5.5+ (Install-Module Pester -Scope CurrentUser -SkipPublisherCheck)
cd vscode; npm test                            # extension unit tests
```

In VS Code, F5 builds the extension and starts an Extension Development Host. Set `navgit.modulePath` to
`C:\Repos\NAVGit\module\NavGit` to use the module from the repository instead of the bundled copy.

Adding a command:

1. Write the function in `module\NavGit\Public\<Area>\Verb-NavGitThing.ps1` (one function per file; the file name
   is the exported function name).
2. Add an entry to `module\NavGit\Commands.psd1` (name, function, elevation, BcContainerHelper).
3. Add an entry to `vscode\src\commands\registry.ts` and to `contributes.commands` in `vscode\package.json`.
4. The tests check that the three lists match.
