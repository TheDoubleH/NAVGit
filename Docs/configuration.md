# navgit.json reference

`navgit.json` is the per-repository configuration file. It lives in the repository root and is committed to Git, so
everyone working on the repository builds the same container.

- [navgit.json reference](#navgitjson-reference)
  - [How the file is found and read](#how-the-file-is-found-and-read)
  - [Examples](#examples)
  - [Settings at a glance](#settings-at-a-glance)
  - [Setting details](#setting-details)
    - [Identity](#identity)
      - [`projectName` (required)](#projectname-required)
      - [`containerName`](#containername)
      - [`navRelease`](#navrelease)
    - [Artifact](#artifact)
      - [`artifact` (required)](#artifact-required)
        - [Form 1: explicit URL](#form-1-explicit-url)
        - [Form 2: NAV release (resolved with `Get-NavArtifactUrl`)](#form-2-nav-release-resolved-with-get-navartifacturl)
    - [Image](#image)
      - [`imageName`](#imagename)
    - [Database](#database)
      - [`database.bakFile`](#databasebakfile)
      - [`database.useDemo`](#databaseusedemo)
      - [`database.searchNames`](#databasesearchnames)
    - [License](#license)
      - [`licenseFile`](#licensefile)
    - [Container options](#container-options)
      - [`auth`](#auth)
      - [`isolation`](#isolation)
      - [`memoryLimit`](#memorylimit)
      - [`dns`](#dns)
      - [`updateHosts`](#updatehosts)
      - [`enableSymbolLoading`](#enablesymbolloading)
      - [`myScripts`](#myscripts)
      - [`additionalParameters`](#additionalparameters)
    - [Test toolkit](#test-toolkit)
      - [`includeTestToolkit`](#includetesttoolkit)
      - [`testToolkit.country`](#testtoolkitcountry)
      - [`testToolkit.librariesOnly`](#testtoolkitlibrariesonly)
    - [Folders](#folders)
      - [`paths.objects`](#pathsobjects)
      - [`paths.tests`](#pathstests)
      - [`paths.addIns`](#pathsaddins)
    - [Test object detection](#test-object-detection)
      - [`testObjects.versionListPattern`](#testobjectsversionlistpattern)
      - [`testObjects.includeTestCodeunits`](#testobjectsincludetestcodeunits)
    - [Import](#import)
      - [`import.deleteMissing`](#importdeletemissing)
      - [`import.syncSchema`](#importsyncschema)
      - [`import.compileFilter`](#importcompilefilter)
      - [`import.dateFormat`](#importdateformat)
    - [Export](#export)
      - [`export.filter`](#exportfilter)
      - [`export.format`](#exportformat)
    - [Client](#client)
      - [`client.defaultProfile`](#clientdefaultprofile)
    - [Output](#output)
      - [`showBcContainerCommand`](#showbccontainercommand)
  - [Validation](#validation)
    - [Letter case](#letter-case)

For the per-user file (`%APPDATA%\NAVGit\settings.json`) see [user-settings.md](user-settings.md).

## How the file is found and read

1. Every command takes `-Path` (default: the current folder). NAVGit walks **up** from that folder (or from the
   folder of a file) and uses the first `navgit.json` it finds. That folder is the *repository root*; all relative
   paths in the file are relative to it.
2. The file must be plain JSON containing one object. Write it without comments: Windows PowerShell 5.1 cannot
   parse JSON with comments.
3. The file is **deep-merged over the defaults**: nested objects are merged key by key, so
   `"import": { "deleteMissing": "warn" }` keeps the defaults for the other `import` settings. Arrays are
   *replaced*, not merged.
4. The [user settings](user-settings.md) override `navgit.json`: `auth`, `isolation`, `showBcContainerCommand`,
   `import.deleteMissing` (user `deleteMissing`), `containerName` and `artifact` (user `artifact.url`). A user
   setting that is set always wins; an empty one leaves the repository's value alone. The overrides are applied
   after `navgit.json` has been validated, so the file must be valid on its own.
5. The merged result is validated. All problems are collected and reported together in one error. Unknown keys
   (usually typos) are **not** errors: they produce a warning such as
   `navgit.json: unknown setting 'isolaton' is ignored.`
6. The key `$schema` is allowed and ignored by the module.

VS Code validates the file while you type, using the schema bundled with the extension
(`module/NAVGit/Schema/navgit.schema.json`). The schema and the module's own validation agree on every setting; the
schema is slightly stricter about letter case (see [Letter case](#letter-case)).

## Examples

Minimal: the backup is found in the user's `backupFolder` by project name, the license is the demo license.

```json
{
  "projectName": "Customer",
  "artifact": { "nav": "2018", "cu": "cu30", "country": "no" }
}
```

A typical repository:

```json
{
  "projectName": "Customer",
  "artifact": { "nav": "2018", "cu": "cu30", "country": "no" },
  "database": { "bakFile": "C:\\Backups\\Customer.bak" },
  "licenseFile": "Customer{major}.flf",
  "auth": "NavUserPassword",
  "isolation": "hyperv",
  "memoryLimit": "8G",
  "includeTestToolkit": true
}
```

Every setting, with its default value (except where noted):

```json
{
  "projectName": "Customer",
  "containerName": "Customer",
  "navRelease": "2018",
  "artifact": { "version": "14.0", "country": "w1", "select": "Latest", "type": "OnPrem" },
  "imageName": "navgit",
  "database": { "bakFile": "", "useDemo": false, "searchNames": [] },
  "licenseFile": "",
  "auth": "Windows",
  "isolation": "",
  "memoryLimit": "",
  "dns": "",
  "updateHosts": true,
  "enableSymbolLoading": false,
  "includeTestToolkit": false,
  "testToolkit": { "country": "", "librariesOnly": false },
  "myScripts": [],
  "additionalParameters": [],
  "paths": { "objects": "Objects", "tests": "Tests", "addIns": "Add-Ins" },
  "testObjects": { "versionListPattern": "(^|,)\\s*Test", "includeTestCodeunits": true },
  "import": { "deleteMissing": "skip", "syncSchema": "Force", "compileFilter": "Compiled=0", "dateFormat": "" },
  "export": { "filter": "", "format": "txt folder" },
  "client": { "defaultProfile": "" },
  "showBcContainerCommand": false
}
```

(`containerName`, `navRelease` and `auth` above show *derived* values, not literal defaults; `artifact` and
`projectName` have no default.)

## Settings at a glance

| Setting | Type | Required | Default | Accepted values |
| --- | --- | --- | --- | --- |
| `projectName` | string | **yes** | | any non-empty string |
| `containerName` | string or object | | derived from `projectName` | 1–15 chars, `A-Z a-z 0-9 -`, starts with a letter or digit; or `{ "fixed": … }` / `{ "branch": { "prefix": "MIS", "length": 1–15 } }` (`prefix` optional) |
| `navRelease` | string | | derived from the version | any string |
| `artifact` | object | **yes** | | exactly one of the three [forms](#artifact) |
| `artifact.url` | string | | | `https://…/onprem/<version>/<country>` |
| `artifact.nav` | string | | | `"2016"`, `"2017"`, `"2018"` |
| `artifact.cu` | string | | latest | `rtm` or `cu<number>` (e.g. `cu30`); only with `nav` |
| `artifact.version` | string | | | version prefix with major 9–14: `14`, `14.0`, `11.0.48560.0` |
| `artifact.select` | string | | `Latest` | `Latest`, `First`, `Closest`; only with `version` |
| `artifact.type` | string | | `OnPrem` | `OnPrem`; only with `version` |
| `artifact.country` | string | | `w1` | any localization code (`w1`, `no`, `dk`, `gb`, …); not with `url` |
| `imageName` | string | | `navgit` | lowercase letters, digits, `.`, `_`, `-`; starts with a letter or digit |
| `database.bakFile` | string | | | absolute path, relative path, or `http(s)://` URL |
| `database.useDemo` | boolean | | `false` | `true`, `false` |
| `database.searchNames` | string[] | | `[]` | any strings |
| `licenseFile` | string | | `""` (demo license) | absolute path, relative path, or `http(s)://` URL; `{major}` placeholder |
| `auth` | string | | see [auth](#auth) | `Windows`, `NavUserPassword` |
| `isolation` | string | | `""` | `""`, `hyperv`, `process` |
| `memoryLimit` | string | | `""` | `""` or number + `M`/`G`: `8G`, `4096M`, `7.5G` |
| `dns` | string | | `""` | an IP address, `hostDNS`, or `""` |
| `updateHosts` | boolean | | `true` | `true`, `false` |
| `enableSymbolLoading` | boolean | | `false` | `true` (NAV 2018 / BC14 only), `false` |
| `includeTestToolkit` | boolean | | `false` | `true`, `false` |
| `testToolkit.country` | string | | `""` | localization code or `""` |
| `testToolkit.librariesOnly` | boolean | | `false` | `true`, `false` |
| `myScripts` | string[] | | `[]` | paths or URLs |
| `additionalParameters` | string[] | | `[]` | docker run arguments, [with exceptions](#additionalparameters) |
| `paths.objects` | string | | `Objects` | non-empty relative folder |
| `paths.tests` | string | | `Tests` | non-empty relative folder, different from `paths.objects` |
| `paths.addIns` | string | | `Add-Ins` | relative folder, or `""` to disable |
| `testObjects.versionListPattern` | string | | `(^\|,)\s*Test` | non-empty, valid .NET regular expression |
| `testObjects.includeTestCodeunits` | boolean | | `true` | `true`, `false` |
| `import.deleteMissing` | string | | `skip` | `skip`, `warn`, `mark` |
| `import.syncSchema` | string | | `Force` | `Force`, `Yes`, `No` |
| `import.compileFilter` | string | | `Compiled=0` | non-empty C/SIDE filter |
| `import.dateFormat` | string | | `""` | `""` or a .NET date format such as `dd.MM.yy`, `M/d/yy` |
| `export.filter` | string | | `""` (all objects) | C/SIDE filter |
| `export.format` | string | | `txt folder` | `txt folder` |
| `client.defaultProfile` | string | | `""` | a Profile ID, or `""` |
| `showBcContainerCommand` | boolean | | `false` | `true`, `false` |

Booleans must be JSON `true` / `false`; the strings `"true"` / `"false"` are rejected. Version numbers
(`artifact.nav`, `artifact.version`) must be **strings**: `"2018"`, not `2018`.

## Setting details

### Identity

#### `projectName` (required)

The project's name. Used for:

- the default `containerName`;
- the backup search in the user's `backupFolder` (see [`database`](#database)).

#### `containerName`

The Docker container name, which is also the host name the container gets in the hosts file.

- Allowed: 1–15 characters, letters, digits and `-`, starting with a letter or digit
  (regular expression `^[A-Za-z0-9][A-Za-z0-9-]{0,14}$`). The 15-character limit is the NetBIOS host name limit.
- Default: derived from `projectName`. Every character that is not a letter, digit or `-` (for example `_`, space
  or `.`) becomes `-`, leading and trailing `-` are removed, and the result is cut to 15 characters (and any
  trailing `-` removed again). `Customer_Main_Branch_2018` becomes `Customer-Main-B`.

Two repositories with the same `containerName` share one container: building one replaces the other.

`containerName` takes one of three forms:

```json
"containerName": "Contoso"
"containerName": { "fixed": "Contoso" }
"containerName": { "branch": { "length": 8 } }
"containerName": { "branch": { "prefix": "MIS", "length": 8 } }
```

The first two are the same: always this name. The `branch` form gives every ticket branch its own container, so
several can run side by side. It uses the first `length` characters of the current Git branch: with
`"length": 8` the branch `MIS-1234-fix-posting` gets the container `MIS-1234`. Characters that are not allowed
become `-`, as for the derived name.

- Only *ticket branches* count. With `prefix`, that is a branch starting with the prefix, `-` and a digit:
  `"prefix": "MIS"` matches `MIS-1234-fix-posting` and `mis-1234-…`, but not `MISC-1234`, `MIS-cleanup` or
  `OPS-77`. The `-` is added for you (`"MIS-"` means the same as `"MIS"`). Without `prefix`, any upper case issue key
  counts: upper case letters and digits, `-` and a number (`MIS-1234`, `AB2-7`). On any other branch (`main`, `feature/x`), on a detached HEAD, or when `git` is not
  installed, the rule is skipped and the next name is used: the `navgit.json` value when the rule came from the
  user settings, else the name derived from `projectName`. So `main` keeps its one shared container.
- The branch is read when a command loads the configuration, so switching branch switches container. Build the
  container once per ticket (`New-NAVGitContainer`); remove it with `Remove-NAVGitContainer` while that branch is
  checked out.
- `containerName` in the [user settings](user-settings.md#containername) **wins** over this one.

#### `navRelease`

The release name used in backup file names when searching the `backupFolder`. Normally derived from the artifact
version:

| Major version | Product | `navRelease` |
| --- | --- | --- |
| 9 | NAV 2016 | `2016` |
| 10 | NAV 2017 | `2017` |
| 11 | NAV 2018 | `2018` |
| 13 | Business Central 13 (fall 2018) | `2019` |
| 14 | Business Central 14 (spring 2019) | `BC14` |
| other | | `<major>.<minor>`, e.g. `12.0` |

Set it only when your backup folder uses a different naming scheme. Any string is accepted.

### Artifact

#### `artifact` (required)

Which BcContainerHelper artifact (NAV/BC build and localization) the container is built from. Use **exactly one**
of three forms; NAVGit decides the form from which of `url`, `nav` or `version` is present.

##### Form 1: explicit URL

```json
"artifact": { "url": "https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/onprem/9.0.50357.0/na" }
```

| Key | Rules |
| --- | --- |
| `url` | Must start with `https://`. Must be an **OnPrem** artifact URL of the shape `…/onprem/<version>/<country>` (an optional `?sas` query string is fine). Sandbox URLs are rejected: C/AL needs OnPrem. |

`cu`, `country`, `type` and `select` cannot be combined with `url`; the URL already identifies the artifact.

##### Form 2: NAV release (resolved with `Get-NavArtifactUrl`)

```json
"artifact": { "nav": "2016", "cu": "cu32", "country": "na" }
```

| Key | Accepted values | Default |
| --- | --- | --- |
| `nav` | `"2016"`, `"2017"`, `"2018"` (strings) | (required in this form) |
| `cu` | `rtm` or `cu` followed by a number: `cu1`, `cu30`, … | the latest cumulative update |
| `country` | localization code (`w1`, `no`, `dk`, `de`, `gb`, `na`, …); stored lower-case | `w1` |

`type` and `select` cannot be used in this form (NAVGit always asks for the latest build of the given CU).
Business Central 13/14 are not available in this form; use form 3.

**Form 3: version prefix (resolved with `Get-BcArtifactUrl -type OnPrem`)**

```json
"artifact": { "version": "14.0", "country": "w1", "select": "Latest" }
```

| Key | Accepted values | Default |
| --- | --- | --- |
| `version` | 1–4 dot-separated numbers whose first number (major) is between **9 and 14**: `14`, `14.0`, `11.0.48560`, `14.0.29537.0` | (required in this form) |
| `select` | `Latest`, `First`, `Closest`. `Closest` requires a full four-part version. | `Latest` |
| `type` | `OnPrem` | `OnPrem` |
| `country` | localization code; stored lower-case | `w1` |

`cu` cannot be used in this form.

Whatever the form, the resolved artifact must be version 9 (NAV 2016) to 14 (BC14); anything else stops the build.
There are no artifacts before NAV 2016, and C/AL ends with BC14.

An `artifact.url` in the [user settings](user-settings.md#artifact) **wins** over this setting and replaces it
completely. The `artifact` here must still be valid.

### Image

#### `imageName`

The local Docker image name passed to `New-BcContainer -imageName`. BcContainerHelper caches the built image under
this name and reuses it for later builds of the same artifact.

- Allowed: lowercase letters, digits, `.`, `_` and `-`, starting with a letter or digit
  (`^[a-z0-9][a-z0-9._-]*$`). Must not be empty.
- Default: `navgit`.

When a backup is used, BcContainerHelper builds the cached image **without** the Cronus demo database (`-nodb`),
which is smaller and faster to start.

### Database

Which database the container starts with. NAVGit never silently falls back to Cronus: if no backup is configured or
found and `useDemo` is not set, the build fails with a list of the places it looked.

#### `database.bakFile`

The SQL backup (`.bak`) to restore, passed to `New-BcContainer -bakFile`.

Accepted values and how they are resolved:

| Value | Resolution |
| --- | --- |
| `http://…` or `https://…` | Passed on as is; BcContainerHelper downloads it. |
| Absolute path (`C:\Backups\Customer.bak`) | Must exist. |
| Relative path (`Backups\Customer.bak`) | Tried relative to the repository root first, then relative to the user `backupFolder`. The first existing file is used. |

A configured `bakFile` that cannot be found is an error (NAVGit does not continue with a search).

#### `database.useDemo`

`true` uses the Cronus demo database that ships with the artifact. Default `false`.

`useDemo: true` and a non-empty `bakFile` cannot both be set.

#### `database.searchNames`

Extra names to try when searching the user `backupFolder`. Used only when `bakFile` is empty and `useDemo` is not
`true`.

The search tries `projectName` first and then each entry of `searchNames`. For each name it tries, in this order
(AdvaniaGIT-compatible):

1. `<backupFolder>\<navRelease>-<name>.bak`
2. `<backupFolder>\<navRelease>\<version>\<name>.bak`
3. `<backupFolder>\<navRelease>\<name>.bak`

Example: `projectName` `Customer`, NAV 2018 CU30 (11.0.43274.0), `searchNames` `["master"]`:

```text
C:\Backups\2018-Customer.bak
C:\Backups\2018\11.0.43274.0\Customer.bak
C:\Backups\2018\Customer.bak
C:\Backups\2018-master.bak
C:\Backups\2018\11.0.43274.0\master.bak
C:\Backups\2018\master.bak
```

Without a `backupFolder` in the user settings the search fails with an error asking you to set `bakFile`,
`backupFolder` or `useDemo`.

### License

#### `licenseFile`

The license file (`.flf`) imported into the container, passed to `New-BcContainer -licenseFile`.

- `{major}` anywhere in the value is replaced with the artifact's major version:
  `Customer{major}.flf` becomes `Customer11.flf` for NAV 2018 and `Customer14.flf` for BC14.
- `http://…` or `https://…`: passed on as is.
- Absolute path: must exist.
- Relative path: tried relative to the repository root first, then relative to the user `licenseFolder`.
- Empty (default): no license is imported; the container uses the demo license from the artifact, and a warning
  says so.

A configured license that cannot be found is an error.

### Container options

#### `auth`

How users log in to the NAV service tier.

| Value | Meaning |
| --- | --- |
| `Windows` | Windows authentication with your current Windows account. |
| `NavUserPassword` | User name and password. The password is also the SQL `sa` password inside the container, which NAVGit uses for imports, exports and the profile list. |

Default: `NavUserPassword` when you are signed in with an Azure AD (Entra ID) account (`%USERDOMAIN%` is
`AzureAD`); otherwise `Windows`. An `auth` in the [user settings](user-settings.md#auth) **wins** over this one.

Windows authentication does not work inside a container for Azure AD accounts. If `auth` is `Windows` on such a
machine, NAVGit uses `NavUserPassword` anyway and warns; set `auth` to `NavUserPassword` here or in your user
settings to silence the warning.

The credential is asked for once and stored encrypted; see [How it works](how-it-works.md#credentials).

#### `isolation`

Docker isolation mode, passed to `New-BcContainer -isolation`.

| Value | Meaning |
| --- | --- |
| `""` | Let BcContainerHelper decide (it picks `process` when the host and image OS versions match, else `hyperv`). |
| `hyperv` | Hyper-V isolation. |
| `process` | Process isolation (host and image Windows versions must match). |

Default: `""`. An `isolation` in the [user settings](user-settings.md#isolation) **wins** over this one.

#### `memoryLimit`

Container memory limit, passed to `New-BcContainer -memoryLimit`.

- Allowed: empty, or a number (decimals allowed) followed by `M` or `G` in either case: `8G`, `16g`, `4096M`,
  `7.5G`. Units such as `GB`, `MB` or a bare number are rejected.
- Default `""`: BcContainerHelper's default, which is 8G for Hyper-V isolation.

#### `dns`

DNS server for the container, passed to `New-BcContainer -dns`. An IP address such as `8.8.8.8`, or `hostDNS` to use
the host's DNS servers. Default `""` (Docker default). Not validated beyond being a string.

#### `updateHosts`

`true` (default) adds the container to the Windows hosts file so it can be reached by its name. The client
commands (Start NAV Client, Start FinSql, the profile list) connect by container name, so keep this on unless you
handle name resolution another way.

#### `enableSymbolLoading`

`true` enables symbol loading on the service tier (`New-BcContainer -enableSymbolLoading`) and makes
Start Development Environment open C/SIDE with `generatesymbolreference=1`.

Only for NAV 2018 and BC14 (versions 11–14). With an older artifact the build stops with an error. Default `false`.

#### `myScripts`

An array of scripts passed to `New-BcContainer -myScripts`: URLs or file paths, as BcContainerHelper accepts them.
They are copied into the container's `c:\run\my` folder and can override the container's startup scripts.
Default `[]`.

#### `additionalParameters`

An array of extra `docker run` arguments, passed to `New-BcContainer -additionalParameters`. Each entry is a string
such as `"--cpu-count 4"` or `"--env customNavSettings=EnableTaskScheduler=False"`. Default `[]`.

Arguments that duplicate a setting NAVGit (or BcContainerHelper) handles natively are **rejected**, because passing
them as raw docker arguments hides them from BcContainerHelper (the classic example: `--env bakfile=` makes
BcContainerHelper build the image *with* the Cronus database).

Rejected `--env` / `-e` variables (case-insensitive):

| Variable | Use instead |
| --- | --- |
| `bakfile` | `database.bakFile` |
| `licensefile` | `licenseFile` |
| `username`, `password`, `securepassword`, `passwordkeyfile` | the stored credential |
| `auth` | `auth` |
| `artifacturl` | `artifact` |
| `enablesymbolloading` | `enableSymbolLoading` |
| `databaseserver`, `databaseinstance`, `databasename`, `databaseusername`, `databasepassword`, `databasesecurepassword` | nothing: external databases are not supported; use `database.bakFile` |

Rejected docker options:

| Option | Use instead |
| --- | --- |
| `--name` | `containerName` |
| `--memory`, `-m` | `memoryLimit` |
| `--isolation` | `isolation` |
| `--dns` | `dns` |
| `--restart` | nothing: NAVGit always uses `unless-stopped` |

NAVGit adds one argument itself: when the add-ins folder exists, `--volume "<repo>\Add-Ins:c:\run\Add-ins"`.

### Test toolkit

#### `includeTestToolkit`

`true` imports the C/AL test toolkit while the container is built (`New-BcContainer -includeTestToolkit`).
Default `false`.

This also controls whether the [`paths.tests`](#pathstests) folder is imported: objects in it usually depend on the
toolkit and would not compile without it. With `includeTestToolkit: false`, changed test objects are skipped with a
warning, unless you run `Import-NAVGitObjects -IncludeTests` (for example after *Import Test Toolkit*).

#### `testToolkit.country`

Localized test toolkit, passed as `-testToolkitCountry` to `Import-TestToolkitToBcContainer` by
*Import Test Toolkit*. A localization code such as `no`, or `""` (default) for the toolkit shipped in the container.

#### `testToolkit.librariesOnly`

`true` imports only the test libraries, not the standard test codeunits. Applies to the build (only when
`includeTestToolkit` is `true`) and to *Import Test Toolkit*. Default `false`.

### Folders

All three must be **relative** to the repository root; absolute paths are rejected. The folders are flat: NAVGit does
not look in subfolders.

Only files named like C/AL object files are read or touched: three letters, a number and `.txt`, in any case
(`TAB18.TXT`, `COD50000.TXT`, `pag21.txt`). Other files in the folders (READMEs, `.gitkeep`) are left alone.

#### `paths.objects`

Folder for application objects. Default `Objects`. Must not be empty.

#### `paths.tests`

Folder for test objects (see [`testObjects`](#test-object-detection)). Default `Tests`. Must not be empty and must be
a different folder from `paths.objects`.

An object may exist in only one of the two folders; if the same object is found twice, the import stops with an
error naming both files.

#### `paths.addIns`

Folder with .NET add-ins (control add-ins and DLLs). Default `Add-Ins`. `""` disables add-in handling.

When the folder exists:

- it is mapped into the container as `c:\run\Add-ins` while building;
- after the build, and with *Update Add-ins*, its contents are copied to the service tier's and the RoleTailored
  client's `Add-ins` folders in the container, and to the Windows client on the host.

When it does not exist, nothing happens (except that *Update Add-ins* reports an error).

### Test object detection

Used by *Export NAV objects to GIT* to decide whether an object goes to `paths.tests` or `paths.objects`.

#### `testObjects.versionListPattern`

A .NET regular expression matched **case-insensitively** against the object's Version List. A match makes it a test
object. Must be a non-empty, valid regular expression.

Default `(^|,)\s*Test`: an entry in the comma-separated Version List that starts with `Test`.

| Version List | Default pattern |
| --- | --- |
| `Test` | test |
| `NAVW111.00,TEST1.0` | test |
| `NAVW111.00, Tests` | test |
| `NAVW111.00,MYTEST` | not a test (entry does not *start* with Test) |
| `NAVW111.00` | not a test |

Remember to escape backslashes in JSON: `"(^|,)\\s*Test"`.

#### `testObjects.includeTestCodeunits`

`true` (default) also treats codeunits with `Subtype=Test` as test objects, whatever their Version List.

### Import

Used by *Import All GIT Objects to NAV* and *Build and Update Container*, and (`syncSchema`) by the compile commands.

#### `import.deleteMissing`

What to do with objects that are in the database but not in Git. Usually these are objects outside your license
range that C/SIDE could not export.

| Value | Behaviour |
| --- | --- |
| `skip` (default) | Leave them alone; only a count goes to the verbose output. |
| `warn` | Leave them alone and list them (first 25) as a warning. |
| `mark` | Set their Version List to `#DELETE` (as AdvaniaGIT did) and list them. You can then delete them in C/SIDE with the filter `Version List=#DELETE`. |

System objects (ID 2000000000 and above) and objects already marked `#DELETE` are never counted.

A `deleteMissing` in the [user settings](user-settings.md#deletemissing) **overrides** this value.

#### `import.syncSchema`

`SynchronizeSchemaChanges` used when importing and compiling.

| Value | Meaning |
| --- | --- |
| `Force` (default) | Apply schema changes even if data is lost. |
| `Yes` | Apply schema changes; fail if data would be lost. |
| `No` | Do not synchronize. |

After an import NAVGit also runs `Sync-NAVTenant -Mode ForceSync`.

#### `import.compileFilter`

C/SIDE filter for the objects compiled after an import. Default `Compiled=0` (uncompiled objects). Must not be empty.
Any C/SIDE object filter works, e.g. `Compiled=0;Type=Table|Codeunit`.

#### `import.dateFormat`

How to read the `Date` property in the object files. NAVGit compares Version List, Modified, Date and Time with the
database to decide what to import; the date format depends on the regional settings of the machine that exported
the objects.

- `""` (default): derived from the separator in the date:
  - `.` → `dd.MM.yy` (also `d.M.yy`, `dd.MM.yyyy`, `d.M.yyyy`)
  - `-` → `dd-MM-yy` (also `d-M-yy`, `dd-MM-yyyy`, `yyyy-MM-dd`)
  - otherwise `/` → `MM/dd/yy` (also `M/d/yy`, `MM/dd/yyyy`, `M/d/yyyy`)
- Otherwise a .NET custom date format, e.g. `dd.MM.yy`, `d/M/yy`, `M/d/yy`. Only this one format is tried.

A date that cannot be read is not an error: the object is simply imported. If *every* object is re-imported on each
run, the format is wrong; set it explicitly (for example `dd/MM/yy` for British exports).

### Export

Used by *Export NAV objects to GIT*.

#### `export.filter`

C/SIDE filter for the objects to export, e.g. `Type=Table;Id=50000..50099` or `Version List=*CUST*`.
Default `""`: export all objects.

Only a **full** export (empty filter) can tell which objects were deleted, so only then are object files of objects
that no longer exist removed from `paths.objects` and `paths.tests`. With a filter, files that were not exported are
kept, and a warning reminds you of that.

#### `export.format`

Export format. The only accepted value is `txt folder` (one text file per object), which is the default.

### Client

#### `client.defaultProfile`

The Profile ID that *Start NAV Client (default)* opens, e.g. `ORDER PROCESSOR`. Default `""`: the default role
center. *Start NAV Client…* (picker) and `Start-NAVGitClient -ProfileId` ignore this setting.

### Output

#### `showBcContainerCommand`

`true` writes the full `New-BcContainer` command (credential masked) to the output before the container is built.
Useful for checking what is passed to BcContainerHelper or for reproducing a build by hand.

Default: `false`. A `showBcContainerCommand` in the [user settings](user-settings.md#showbccontainercommand)
**wins** over this one, whether it is `true` or `false`.

`Show-NAVGitContainerCommand` shows the same command at any time without building.

## Validation

Validation runs whenever a command loads the configuration (all commands do). All problems are reported together:

```text
Invalid NAVGit configuration in 'C:\Repos\Customer\navgit.json':
  - 'artifact' must contain exactly one of 'url', 'nav' or 'version' (found: nav, version).
  - 'memoryLimit' ('8GB') must look like '8G' or '4096M'.
```

Rules that go beyond "right type, allowed value":

| Rule | Error |
| --- | --- |
| `artifact` has none or more than one of `url` / `nav` / `version` | `'artifact' must contain exactly one of 'url', 'nav' or 'version'` |
| `cu`, `country`, `type` or `select` together with `url` | `cannot be combined with 'artifact.url'` |
| `type` or `select` together with `nav` | `can only be used with 'artifact.version'` |
| `cu` together with `version` | `can only be used with 'artifact.nav'` |
| `version` major below 9 or above 14 | `must be between 9 (NAV 2016) and 14 (BC14)` |
| `select: "Closest"` with fewer than four version parts | `requires a full four-part 'artifact.version'` |
| `database.useDemo: true` with a `database.bakFile` | `cannot both be set` |
| an absolute path in `paths.*` | `must be relative to the repository` |
| `paths.objects` equals `paths.tests` | `must be different folders` |
| `testObjects.versionListPattern` does not compile | `is not a valid regular expression` |
| `projectName`, `containerName`, `imageName`, `paths.objects`, `paths.tests`, `testObjects.versionListPattern`, `import.compileFilter` empty | `is required` |

Checks that need the artifact run when a container is built (or `Show-NAVGitContainerCommand` runs):

- the artifact URL can be resolved and is an OnPrem URL for version 9–14;
- `enableSymbolLoading` requires version 11 or later;
- the backup and license files exist;
- `additionalParameters` contains no [rejected](#additionalparameters) arguments.

### Letter case

The VS Code schema checks enum values with exact case (`hyperv`, `NavUserPassword`, `Latest`, `skip`, `Force`).
The module compares them case-insensitively, so `HyperV` works from PowerShell but is underlined in VS Code. Use
the spelling shown in this document.
