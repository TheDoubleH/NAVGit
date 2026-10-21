# User settings (settings.json)

The user settings hold what differs per developer machine, not per repository: where backups and licenses are kept,
personal overrides, and a BcContainerHelper version pin. They are never committed to Git.

**A user setting that is set always wins over `navgit.json`.** `navgit.json` is still validated as written, so it
stays valid for colleagues who do not have your settings. An empty (or missing) user setting leaves the repository's
value alone. With `-Verbose` NAVGit reports each value it overrides.

Overrides apply to every repository on the machine. A personal `artifact` or `auth` therefore affects all your
NAVGit repositories, not just the one you were working in.

## Location

`%APPDATA%\NAVGit\settings.json`, for example `C:\Users\you\AppData\Roaming\NAVGit\settings.json`.

Set the environment variable `NAVGIT_SETTINGS_PATH` to use another file (the test suite does this).

The file is optional. When it does not exist, every setting has its default.

## Example

```json
{
  "backupFolder": "C:\\NAVGIT\\Backup",
  "licenseFolder": "C:\\NAVGIT\\License",
  "auth": "NavUserPassword",
  "isolation": "hyperv",
  "bcContainerHelperVersion": "",
  "showBcContainerCommand": false,
  "deleteMissing": "",
  "containerName": {
    "branch": {
      "prefix": "MIS",
      "length": 8
    }
  },
  "artifact": {
    "url": "https://bcartifacts.blob.core.windows.net/onprem/9.0.50357.0/na"
  }
}
```

## Settings

| Setting | Type | Default | Accepted values | Effect |
| --- | --- | --- | --- | --- |
| `backupFolder` | string | `""` | a folder path | Searched for backups; base for relative `database.bakFile` |
| `licenseFolder` | string | `""` | a folder path | Base for relative `licenseFile` |
| `bcContainerHelperVersion` | string | `""` | `""` or an installed version, e.g. `6.0.30` | Pins the BcContainerHelper version |
| `auth` | string | `""` | `""`, `Windows`, `NavUserPassword` | **Overrides** `auth` |
| `isolation` | string | `""` | `""`, `hyperv`, `process` | **Overrides** `isolation` |
| `showBcContainerCommand` | boolean | not set | `true`, `false` | **Overrides** `showBcContainerCommand` |
| `deleteMissing` | string | `""` | `""`, `skip`, `warn`, `mark` | **Overrides** `import.deleteMissing` |
| `containerName` | string or object | `""` | `""` or any [`containerName`](configuration.md#containername) form | **Overrides** `containerName` |
| `artifact` | object | not set | `{ "url": "https://..." }` | **Overrides** `artifact` |

`backupFolder`, `licenseFolder` and `bcContainerHelperVersion` have no counterpart in `navgit.json`; they only tell
NAVGit where things are on this machine.

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

### `bcContainerHelperVersion`

When set, NAVGit imports exactly this version of BcContainerHelper (`Import-Module -RequiredVersion`). The version
must be installed:

```powershell
Install-Module BcContainerHelper -RequiredVersion 6.0.30 -Scope AllUsers
```

Empty (default) imports the newest installed version. If BcContainerHelper is already loaded in the session, NAVGit
uses the loaded one.

### `auth`

Personal override for [`auth`](configuration.md#auth). Empty (default) uses the repository's `auth`, or, when it has
none, `NavUserPassword` on Azure AD joined machines and `Windows` elsewhere.

Set it to `NavUserPassword` on an Azure AD joined machine when a repository says `"auth": "Windows"`: Windows
authentication does not work for Azure AD accounts inside a container.

This setting used to be called `defaultAuth`. The old name is still read, with a warning asking you to rename it.

### `isolation`

Personal override for [`isolation`](configuration.md#isolation). Empty (default) uses the repository's value. An
empty user setting cannot force "let BcContainerHelper decide" over a repository that names a mode.

This setting used to be called `defaultIsolation`. The old name is still read, with a warning asking you to rename
it.

### `showBcContainerCommand`

Personal override for [`showBcContainerCommand`](configuration.md#showbccontainercommand). Must be a JSON boolean.
Both `true` and `false` win over the repository; leave the setting out to use the repository's value.

### `deleteMissing`

Personal override for [`import.deleteMissing`](configuration.md#importdeletemissing). Empty (default) uses the
repository's setting.

### `containerName`

Personal override for [`containerName`](configuration.md#containername), in any of its forms: a name,

```json
{ "branch": {
    "fixed": "Contoso" }
}
```

or

```json
{ "branch": {
    "prefix": "MIS", 
    "length": 8 }
}
```

A `branch` rule here applies only on ticket branches (`MIS-1234-…`, or only those of `prefix` when set). On other branches the repository's
`containerName` is used, or the name derived from `projectName` when it has none. This lets you work with one
container per ticket while colleagues keep the repository's fixed name. Empty (default) uses the repository's
setting.

### `artifact`

Personal override for [`artifact`](configuration.md#artifact-required). Only the URL form is accepted:

```json
"artifact": {
  "url": "https://bcartifacts.blob.core.windows.net/onprem/9.0.50357.0/na"
}
```

When set, it replaces the repository's `artifact` completely, whatever form that uses (`nav`/`cu`, `version`, or
`url`). The URL must start with `https://` and point to an OnPrem artifact of version 9 (NAV 2016) to 14 (BC14),
as described under [Form 1](configuration.md#artifact-required). The `nav` and `version` forms are not accepted here.

Because it applies to every repository, use it for a temporary pin (for example a specific build while you test
something) and remove it afterwards. A repository for another NAV version would otherwise be built from this
artifact too.

## Validation

- The file must be valid JSON containing one object, or every command stops with an error.
- Unknown keys produce a warning (`unknown setting '…' is ignored`).
- Values are read as strings except `showBcContainerCommand`, which must be `true` or `false`, `containerName`,
  which may also be an object (checked when a repository's configuration is loaded), and `artifact`, which must be
  `{ "url": "https://..." }`.
- `auth`, `isolation` and `deleteMissing` are checked against their allowed values; an invalid value is an error,
  not a warning.
- The old names `defaultAuth` and `defaultIsolation` are read as `auth` and `isolation`, with a warning. When both
  the old and the new name are present, the new one is used.

## Other per-user data

NAVGit keeps credentials and container state under `%LOCALAPPDATA%\NAVGit`; see
[How it works](how-it-works.md#where-navgit-keeps-things). Set `NAVGIT_DATA_PATH` to use another root folder.
