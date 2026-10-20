# User settings (settings.json)

The user settings hold what differs per developer machine, not per repository: where backups and licenses are kept,
personal defaults, and a BcContainerHelper version pin. They are never committed to Git.

## Location

`%APPDATA%\NAVGit\settings.json`, for example `C:\Users\you\AppData\Roaming\NAVGit\settings.json`.

Set the environment variable `NAVGIT_SETTINGS_PATH` to use another file (the test suite does this).

The file is optional. When it does not exist, every setting has its default.

## Example

```json
{
  "backupFolder": "C:\\AdvaniaGIT\\Backup",
  "licenseFolder": "C:\\AdvaniaGIT\\License",
  "defaultAuth": "NavUserPassword",
  "defaultIsolation": "hyperv",
  "bcContainerHelperVersion": "",
  "showBcContainerCommand": false,
  "deleteMissing": "",
  "containerName": { "branch": { "prefix": "MIS", "length": 8 } }
}
```

## Settings

| Setting | Type | Default | Accepted values | Effect |
| --- | --- | --- | --- | --- |
| `backupFolder` | string | `""` | a folder path | Searched for backups; base for relative `database.bakFile` |
| `licenseFolder` | string | `""` | a folder path | Base for relative `licenseFile` |
| `defaultAuth` | string | `""` | `""`, `Windows`, `NavUserPassword` | Default for `auth` |
| `defaultIsolation` | string | `""` | `""`, `hyperv`, `process` | Default for `isolation` |
| `bcContainerHelperVersion` | string | `""` | `""` or an installed version, e.g. `6.0.30` | Pins the BcContainerHelper version |
| `showBcContainerCommand` | boolean | `false` | `true`, `false` | Default for `showBcContainerCommand` |
| `deleteMissing` | string | `""` | `""`, `skip`, `warn`, `mark` | **Overrides** `import.deleteMissing` |
| `containerName` | string or object | `""` | `""` or any [`containerName`](configuration.md#containername) form | **Overrides** `containerName` |

### `backupFolder`

The folder searched for a database backup when `navgit.json` has no `database.bakFile` and `database.useDemo` is not
`true`. The search order is described under
[`database.searchNames`](configuration.md#databasesearchnames). It is also the second place a relative
`database.bakFile` is looked up (after the repository root).

The folder must exist when a search is needed; otherwise the build fails.

Coming from AdvaniaGIT, point it at `C:\AdvaniaGIT\Backup` to keep using your existing backups and their naming.

### `licenseFolder`

The second place a relative `licenseFile` is looked up (after the repository root). Coming from AdvaniaGIT, point it
at `C:\AdvaniaGIT\License`.

### `defaultAuth`

Used when `navgit.json` has no `auth`. Empty means: `NavUserPassword` on Azure AD joined machines, `Windows`
elsewhere. See [`auth`](configuration.md#auth).

### `defaultIsolation`

Used when `navgit.json` has no `isolation` key at all. `""` lets BcContainerHelper choose. An explicit
`"isolation": ""` in `navgit.json` still wins over this setting.

### `bcContainerHelperVersion`

When set, NAVGit imports exactly this version of BcContainerHelper (`Import-Module -RequiredVersion`). The version
must be installed:

```powershell
Install-Module BcContainerHelper -RequiredVersion 6.0.30 -Scope AllUsers
```

Empty (default) imports the newest installed version. If BcContainerHelper is already loaded in the session, NAVGit
uses the loaded one.

### `showBcContainerCommand`

Personal default for [`showBcContainerCommand`](configuration.md#showbccontainercommand). Must be a JSON boolean.
A value in `navgit.json` wins.

### `deleteMissing`

Personal override for [`import.deleteMissing`](configuration.md#importdeletemissing). Unlike the other settings, this
one **wins** over the repository: when it is set, every repository uses it, whatever its `navgit.json` says. With
`-Verbose` NAVGit reports when it overrides the repository's value. Empty (default) uses the repository's setting.

### `containerName`

Personal override for [`containerName`](configuration.md#containername), in any of its forms: a name,
`{ "fixed": "Contoso" }` or `{ "branch": { "prefix": "MIS", "length": 8 } }`. Like `deleteMissing`, it **wins** over the repository.

A `branch` rule here applies only on ticket branches (`MIS-1234-…`, or only those of `prefix` when set). On other branches the repository's
`containerName` is used, or the name derived from `projectName` when it has none. This lets you work with one
container per ticket while colleagues keep the repository's fixed name. Empty (default) uses the repository's
setting.

## Validation

- The file must be valid JSON containing one object, or every command stops with an error.
- Unknown keys produce a warning (`unknown setting '…' is ignored`).
- Values are read as strings except `showBcContainerCommand`, which must be `true` or `false`, and `containerName`,
  which may also be an object (checked when a repository's configuration is loaded).
- `defaultAuth`, `defaultIsolation` and `deleteMissing` are checked against their allowed values; an invalid value is
  an error, not a warning.

## Other per-user data

NAVGit keeps credentials and container state under `%LOCALAPPDATA%\NAVGit`; see
[How it works](how-it-works.md#where-navgit-keeps-things). Set `NAVGIT_DATA_PATH` to use another root folder.
