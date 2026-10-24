# PowerShell command reference

Install the module once (see [Getting started](getting-started.md#install)):

```powershell
Install-Module NAVGit -Scope CurrentUser
```

PowerShell loads it automatically when you run one of its commands; `Import-Module NAVGit` loads it explicitly.

Every command takes `-Path`: the repository folder, or any folder or file inside it. The default is the current
folder. `Get-Help <command> -Full` shows the built-in help.

**Elevated** means the command must run in a PowerShell session started with *Run as administrator*
(BcContainerHelper needs it for Docker, the hosts file and shared folders).

## Overview

| Command | Elevated | Purpose |
| --- | --- | --- |
| [`New-NAVGitConfig`](#new-navgitconfig) | no | Create `navgit.json` |
| [`ConvertFrom-AdvaniaGitSetup`](#convertfrom-advaniagitsetup) | no | Create `navgit.json` from AdvaniaGIT's `setup.json` |
| [`Show-NAVGitContainerCommand`](#show-navgitcontainercommand) | no | Dry run: show the `New-BcContainer` command |
| [`New-NAVGitContainer`](#new-navgitcontainer) | yes | Build Container |
| [`Update-NAVGitContainer`](#update-navgitcontainer) | yes | Build and Update Container |
| [`Remove-NAVGitContainer`](#remove-navgitcontainer) | yes | Remove Container |
| [`Update-NAVGitContainerState`](#update-navgitcontainerstate) | yes | Register an existing container for the client commands |
| [`Import-NAVGitObjects`](#import-navgitobjects) | yes | Import All GIT Objects to NAV |
| [`Export-NAVGitObjects`](#export-navgitobjects) | yes | Export NAV objects to GIT |
| [`Invoke-NAVGitCompile`](#invoke-navgitcompile) | yes | Compile objects |
| [`Import-NAVGitTestToolkit`](#import-navgittesttoolkit) | yes | Import Test Toolkit |
| [`Update-NAVGitAddIns`](#update-navgitaddins) | yes | Update Add-ins |
| [`Start-NAVGitClient`](#start-navgitclient) | no | Start the Windows client |
| [`Start-NAVGitDevelopmentEnvironment`](#start-navgitdevelopmentenvironment) | no | Start C/SIDE (finsql.exe) |
| [`Get-NAVGitProfile`](#get-navgitprofile) | no | List profiles (role centers) |
| [`Invoke-NAVGitCommand`](#invoke-navgitcommand) | depends | Run a command by its registry name |

## Configuration

### New-NAVGitConfig

Creates `navgit.json` in a folder and validates it.

| Parameter | Values | Default |
| --- | --- | --- |
| `-Path` | folder | current folder |
| `-ProjectName` | string | the folder name |
| `-Nav` | `2016`, `2017`, `2018` | `2018` |
| `-Cu` | `rtm`, `cuNN` | (latest) |
| `-Version` | version prefix, e.g. `14.0` (instead of `-Nav`) | |
| `-ArtifactUrl` | artifact URL (instead of `-Nav` / `-Version`) | |
| `-Country` | localization code | `w1` |
| `-BakFile` | backup path or URL | |
| `-UseDemo` | switch: use the Cronus database | |
| `-LicenseFile` | license path or URL | |
| `-Auth` | `Windows`, `NavUserPassword` | |
| `-Isolation` | `""`, `hyperv`, `process` | |
| `-Force` | switch: overwrite an existing `navgit.json` | |

`-Nav`/`-Cu`, `-Version` and `-ArtifactUrl` are mutually exclusive. `-WhatIf` prints the JSON instead of writing it.

```powershell
New-NAVGitConfig -ProjectName Customer -Nav 2018 -Cu cu30 -Country no -BakFile C:\Backups\Customer.bak
New-NAVGitConfig -Version 14.0 -Country w1 -UseDemo
```

The file is written as UTF-8 without BOM. If the new configuration does not validate (for example because no backup
is configured and there is no `backupFolder`), the file is still written and a warning explains what needs
attention.

### ConvertFrom-AdvaniaGitSetup

Creates `navgit.json` from an AdvaniaGIT `setup.json`. See [Migrating from AdvaniaGIT](migrating-from-advaniagit.md).

| Parameter | Default |
| --- | --- |
| `-Path` | current folder (must contain the setup file) |
| `-SetupFile` | `setup.json` |
| `-GitSettingsPath` | `C:\AdvaniaGIT\Data\GITSettings.Json` (skipped if missing) |
| `-Force` | overwrite an existing `navgit.json` |

Run it with `-WhatIf` first to see the result and the migration notes.

### Show-NAVGitContainerCommand

Resolves the artifact, backup and license and prints the plan and the `New-BcContainer` command NAVGit would run,
with the password hidden. Creates nothing and needs no elevation, but needs BcContainerHelper installed to resolve
`nav` / `version` artifacts.

`-PassThru` also returns the plan object (`Artifact`, `Backup`, `LicenseFile`, `AddInsFolder`, `Parameters`).

## Containers

### New-NAVGitContainer

*Build Container.* Builds the container with `New-BcContainer`, saves the container state for the client commands,
and copies add-ins when the add-ins folder exists.

| Parameter | Meaning |
| --- | --- |
| `-Force` | Replace an existing container without asking. |
| `-ResetCredential` | Ask for the container credential again instead of using the stored one. |
| `-WhatIf` | Show the plan and command; build nothing (with the elevation checks). |

### Update-NAVGitContainer

*Build and Update Container.* `New-NAVGitContainer -Force` followed by `Import-NAVGitObjects`. If the container
exists it asks once up front (unless `-Force`), so declining stops the whole command. `-WhatIf` behaves like
`New-NAVGitContainer -WhatIf`.

### Remove-NAVGitContainer

*Remove Container.* Runs `Remove-BcContainer` and deletes the saved container state. Asks for confirmation unless
`-Force` is given. If the container does not exist it only warns and cleans up the state.

### Update-NAVGitContainerState

Reads the configuration of an existing container and saves the state file the client commands need. Use it for
containers not built by NAVGit (for example existing AdvaniaGIT containers) or recreated by hand.

## Objects

### Import-NAVGitObjects

*Import All GIT Objects to NAV.*

1. Reads the headers of all object files in `paths.objects` and `paths.tests`.
2. Reads the object table of the container database.
3. Imports objects that are new or whose Version List, Modified flag, Date or Time differ, in one finsql run
   (`ImportAction Overwrite`, `SynchronizeSchemaChanges` = `import.syncSchema`).
4. Handles objects in the database but not in Git according to `import.deleteMissing`.
5. Compiles with `import.compileFilter`, lists still-uncompiled objects, and runs `Sync-NAVTenant -Mode ForceSync`.

| Parameter | Meaning |
| --- | --- |
| `-Force` | Import every object file, also unchanged ones. |
| `-IncludeTests` | Import the tests folder even when `includeTestToolkit` is `false`. |

Once the tests folder has been imported into a container (with `includeTestToolkit`, `-IncludeTests` or
[Import Test Toolkit](#import-navgittesttoolkit)), the container state records it and later imports include the
tests folder automatically.

Returns `Imported`, `Unchanged`, `SkippedTests`, `Missing`, `Uncompiled` counts.

### Export-NAVGitObjects

*Export NAV objects to GIT.* Exports objects (all, or `export.filter`) one file per object and routes each to
`paths.tests` or `paths.objects` according to [`testObjects`](configuration.md#test-object-detection). Files are
compared byte for byte, so unchanged objects do not show up as Git changes. An object that changed category is
moved. A full export also deletes files of objects that no longer exist. Files in `paths.tests` are only deleted
once the test objects have been imported into the container; before that they are kept (and listed as `Kept`),
because they are simply not in the database.

The export runs `finsql.exe` on the host, so Automation variables are named from the host's type libraries
([why](how-it-works.md#exporting-objects)). Without a saved container state or `finsql.exe` on the host it exports
inside the container instead, with a warning.

Returns lists of file names: `Added`, `Changed`, `Moved`, `Removed`, `Kept`, `Unchanged`, `Tests`.

### Invoke-NAVGitCompile

Compiles objects inside the container (`Compile-ObjectsInNavContainer`, so it works for NavUserPassword containers
too), with `SynchronizeSchemaChanges` = `import.syncSchema`, then lists objects still uncompiled.

| Parameter | Values | Default |
| --- | --- | --- |
| `-Scope` | `Uncompiled` (`Compiled=No`), `Modified` (`Modified=Yes`), `All` (every object) | `Uncompiled` |
| `-Filter` | any C/SIDE filter, e.g. `Type=Codeunit;Id=50000..50099` (instead of `-Scope`) | |

### Import-NAVGitTestToolkit

*Import Test Toolkit.* Runs `Import-TestToolkitToBcContainer` (imports `C:\TestToolKit\*.fob` from the container),
honouring `testToolkit.country` and `testToolkit.librariesOnly`. Then it imports the new and changed objects in
`paths.tests`, compiles uncompiled objects, and records in the container state that the test objects are imported,
so later imports keep them current and exports may delete test files whose objects were deleted.

Returns `ImportedTests` and `Uncompiled` counts.

`-LibrariesOnly` imports only the test libraries, regardless of `testToolkit.librariesOnly`.

### Update-NAVGitAddIns

*Update Add-ins.* Copies the contents of `paths.addIns` into the service tier and RoleTailored client `Add-ins`
folders in the container and into the Windows client folder on the host, without rebuilding. Restart the Windows
client afterwards; the service tier may need a restart for assemblies it has already loaded. Fails if the add-ins
folder does not exist.

## Clients

These commands need no elevation and no Docker access. They use the state saved when the container was built
(see [How it works](how-it-works.md#container-state)) and the client files BcContainerHelper copied to the host.

### Start-NAVGitClient

Starts `Microsoft.Dynamics.Nav.Client.exe` with the `ClientUserSettings.config` BcContainerHelper prepared.

| Parameter | Meaning |
| --- | --- |
| (none) | Opens `client.defaultProfile`, or the default role center when that is empty. |
| `-ProfileId <id>` | Opens the given profile, e.g. `'ORDER PROCESSOR'`. |
| `-SelectProfile` | Shows a numbered list of profiles in the console; Enter opens the default role center. |

### Start-NAVGitDevelopmentEnvironment

Starts C/SIDE (`finsql.exe`) connected to the container's database and NAV server (so table changes can be
synchronized when saved). With `enableSymbolLoading` on NAV 2018/BC14 it adds `generatesymbolreference=1`.

### Get-NAVGitProfile

Lists the profiles in the container database: `Id`, `Description`, `RoleCenterId`, `IsDefault`. Connects to SQL from
the host by container name, with Windows authentication or as `sa` with the stored container password.

## Invoke-NAVGitCommand

Runs a command by its name in the command registry (`module/NAVGit/Commands.psd1`). This is what the VS Code
extension calls. It checks elevation and imports BcContainerHelper when the command needs them, and sets
`$LASTEXITCODE` to 0 or 1.

| Parameter | Meaning |
| --- | --- |
| `-Name` | Registry name (see below). |
| `-Repository` | Repository folder; default the current folder. |
| `-Force` | Passed on to commands that have `-Force`. |
| `-ProfileId` | Passed on to commands that have `-ProfileId`. |
| `-AsJson` | Write the result as a JSON array and suppress progress output; errors go to stderr. |

| Name | Function | Elevated |
| --- | --- | --- |
| `BuildContainer` | `New-NAVGitContainer` | yes |
| `BuildAndUpdate` | `Update-NAVGitContainer` | yes |
| `RemoveContainer` | `Remove-NAVGitContainer` | yes |
| `ImportTestToolkit` | `Import-NAVGitTestToolkit` | yes |
| `ImportObjects` | `Import-NAVGitObjects` | yes |
| `ExportObjects` | `Export-NAVGitObjects` | yes |
| `CompileUncompiled` | `Invoke-NAVGitCompile -Scope Uncompiled` | yes |
| `CompileModified` | `Invoke-NAVGitCompile -Scope Modified` | yes |
| `CompileAll` | `Invoke-NAVGitCompile -Scope All` | yes |
| `UpdateAddIns` | `Update-NAVGitAddIns` | yes |
| `StartDevEnv` | `Start-NAVGitDevelopmentEnvironment` | no |
| `StartClient` | `Start-NAVGitClient` | no |
| `GetProfiles` | `Get-NAVGitProfile` | no |

```powershell
powershell -Command "Import-Module NAVGit; Invoke-NAVGitCommand ImportObjects -Repository C:\Repos\Customer; exit $LASTEXITCODE"
```
