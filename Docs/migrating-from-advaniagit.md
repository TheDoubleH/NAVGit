# Migrating from AdvaniaGIT

`ConvertFrom-AdvaniaGitSetup` (or *NAVGit: Create navgit.json* in VS Code) reads the repository's `setup.json`
together with AdvaniaGIT's defaults in `C:\AdvaniaGIT\Data\GITSettings.Json` (setup.json wins, as in AdvaniaGIT) and
writes `navgit.json`.

```powershell
cd C:\Repos\Customer
ConvertFrom-AdvaniaGitSetup -WhatIf   # show the result and the notes
ConvertFrom-AdvaniaGitSetup
```

## Setting mapping

| AdvaniaGIT (`setup.json` / `GITSettings.Json`) | navgit.json | Notes |
| --- | --- | --- |
| `projectName` | `projectName` | required |
| `dockerFriendlyName` | `containerName` | |
| `artifact` (URL) | `artifact.url` | |
| `artifact` (`storageAccount/type/version/country/select`) | `artifact.version`, `artifact.country`, `artifact.select` | only the public `bcartifacts` storage and `OnPrem` type are supported; others produce a note |
| `navVersion` (no `artifact`) | `artifact.version` | country set to `w1` (check it); a four-part version gets `select: Closest` |
| neither `artifact` nor `navVersion` | `artifact: { nav: "2018", country: "w1" }` | placeholder, with a note |
| `dockerImage` | (none) | images are no longer published; use an artifact |
| `dockerRestoreBackup: true` | `database.searchNames` from `baseBranch` and `navSolution` | backup searched in the user `backupFolder` |
| `dockerRestoreBackup` not set / false | `database.useDemo: true` | |
| `licenseFile` (`%1` = version) | `licenseFile` (`{major}`) | |
| `dockerAuthentication` | `auth` | only `Windows` / `NavUserPassword` |
| `dockerIsolation` | `isolation` | only `hyperv` / `process` |
| `dockerMemoryLimit` | `memoryLimit` | AdvaniaGIT ignored it; NAVGit applies it |
| `dockerTestToolkit`, `dockerTestLibraries` | `includeTestToolkit`, `testToolkit.librariesOnly` | |
| `testToolkitCountry` | `testToolkit.country` | |
| `dockerEnableSymbolLoading` | `enableSymbolLoading` | |
| `dockerMyScripts` | `myScripts` | |
| `mapAddInFolder: false` | `paths.addIns: ""` | `true` is NAVGit's default (`Add-Ins`) |
| `objectsPath`, `testObjectsPath` | `paths.objects`, `paths.tests` | written only when not the default |
| `datetimeCulture` | `import.dateFormat` | the culture's short date pattern with a two-digit year, e.g. `nb-NO` → `dd.MM.yy` |
| `storeAllObjects: false` | (none) | deltas are not supported; a note is written |

The command also warns when:

- the tests folder contains objects but `includeTestToolkit` is not set;
- `C:\AdvaniaGIT\Backup` or `C:\AdvaniaGIT\License` exists and the matching user setting (`backupFolder`,
  `licenseFolder`) is not set.

## Behaviour differences

- **Backups go to `-bakFile`.** The image is built without the Cronus database, and a missing backup is an error
  rather than a silent fallback to Cronus.
- **Raw docker arguments are checked.** Entries in `additionalParameters` that duplicate a native setting are
  rejected ([list](configuration.md#additionalparameters)).
- **Tests are exported to `Tests`.** Objects with `Test` in the Version List and test codeunits go to the tests folder.
- **The `Tests` folder is imported** when `includeTestToolkit` is set, so the first import adds your test objects.
  AdvaniaGIT never imported it. Without the toolkit, changed test objects are skipped with a warning.
- **Unlicensed objects are left alone.** Objects your license cannot export are in the database but not in Git. By
  default (`import.deleteMissing: skip`) only a count goes to the verbose output; AdvaniaGIT marked them `#DELETE`
  (use `mark` for that).
- **Existing containers** are unknown to the client commands until you run `Update-NAVGitContainerState` once
  (elevated) in the repository.
- **Not ported:** deltas (`storeAllObjects: false`), FTP backups, PasswordState, CI/AL build pipelines.
