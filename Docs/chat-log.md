# NavGit: development log

How NavGit came about: what was asked, what was found, the decisions made and what was built. Date: 2026-10-15.
Repository `C:\Repos\NAVGit`, branch `Development`.

## 1. The request

The original request is also saved in [initialrequest.md](initialrequest.md). In short:

- AdvaniaGIT (`C:\AdvaniaGIT`) is abandoned. Build a new version that only has the commands that are actually used:
  - Build and Update Container
  - Build Container
  - Remove Container
  - Import Test Toolkit
  - Import All GIT Objects to NAV
  - Export NAV objects to GIT
- Problem 1: test objects (`Test` in the Version List) do not end up in the `Tests` folder on export.
- Problem 2 (the biggest): AdvaniaGIT pushes settings into docker `--env` arguments, so BcContainerHelper does not
  handle them properly. Because of the backup file in particular, the image includes the Cronus demo database.
- Task: understand BcContainerHelper (`c:\repos\navcontainerhelper`) and AdvaniaGIT (especially how it builds the
  `New-NavContainer` command), then plan a PowerShell module plus a VS Code extension. Keep things split up so more
  commands can be added later.

## 2. Research findings

### How AdvaniaGIT builds the container

- Chain: `Start-CustomAction.ps1` → `Build-NavEnvironment.ps1` → `Start-DockerContainer.ps1` → `New-NavContainer`.
- `Start-DockerContainer.ps1` passes the backup only as `--env bakfile="C:\Host\Log\<guid>\NAVBackup.bak"` inside
  `-additionalParameters`, and sets `imageName = "custombuild"` together with `artifactUrl`.
- Other quirks:
  - `-restart no` together with `--restart always`;
  - `doNotCheckHealth` passed twice;
  - `dockerMemoryLimit` ignored;
  - a hard-coded `--dns 8.8.8.8`;
  - `$env:USERNAME` used instead of the configured user;
  - the whole AdvaniaGIT folder mounted as `C:\Host`.

### Why Cronus ends up in the image

- BcContainerHelper only sets `$skipDatabase` when the native `-bakFile` parameter is used
  (`New-NavContainer.ps1` L492-496).
- That flag goes to `New-BcImage -skipDatabase`, which builds a `-nodb` image.
- With `--env bakfile=`, BcContainerHelper doesn't know about the backup, so every custom image gets Cronus baked in.
- The artifact zip (including its `database\` folder) is always downloaded and cached; that can't be avoided.
- Confirmed on this machine: the existing AdvaniaGIT container `Cronus` runs on `custombuild:onprem-9.0.50357.0-na`.

### Why test objects stay in Objects

- "Export NAV objects to GIT" (`ImportFrom-NAVtoGIT.ps1`) exports everything into `Objects` and never looks at the
  Version List.
- Only "Export NAV *Modified* objects" routes test objects, and its check (`IndexOf(",Test") -gt 0`) misses a Version
  List that starts with `Test`.
- On import, AdvaniaGIT never read `Tests\`. With `-MarkToDelete` it could even mark test objects as `#DELETE`.

### Other findings

- AdvaniaGIT runs finsql on the host after copying the RoleTailored Client out of the container.
- The VS Code extension (`advaniagit.advaniagit` 1.1.3) only sends `Start-AdvaniaGITAction -Repository ... -ScriptName ...`
  to a terminal.

## 3. Decisions

| Question | Decision |
| --- | --- |
| Versions | NAV 2016 (9.0), NAV 2017, NAV 2018, BC14 (C/AL). No artifacts exist for NAV 2015 or older. |
| Configuration | A new `navgit.json` per repository, plus a migration from `setup.json`. |
| Where object operations run | Inside the container, through BcContainerHelper (no finsql copied to the host). |
| Backup file | An explicit `database.bakFile`; otherwise the AdvaniaGIT-style folder search. |
| Extra commands (added after the first plan) | Start FinSql, Start NAV Client (default), Start NAV Client (choose profile). |
| Isolation | Its own `isolation` setting in `navgit.json`. |
| Add-Ins | Required: `paths.addIns` (default `Add-Ins`) plus an Update Add-ins command. |
| Test toolkit | A separate Import Test Toolkit command, plus `includeTestToolkit: true` to import it while building. |
| Extension tooling | Node.js LTS installed (winget); TypeScript + esbuild, packaged as a `.vsix`. |

The approved plan is in `C:\Users\HenrikHelgesen\.claude\plans\i-need-you-to-temporal-hartmanis.md`.

## 4. What was built, phase by phase

| Phase | Commit | Contents |
| --- | --- | --- |
| 1 | `10ff47a` | Module skeleton, `Commands.psd1` registry, `navgit.json` schema, config loading and validation, artifact/backup/license resolvers, Pester tests |
| 2 | `b396c46` | `New-`, `Remove-`, `Show-NavGitContainerCommand`, `Update-NavGitContainerState`; native `-bakFile`; rejects duplicate raw docker arguments; encrypted credential and container state |
| 3 | `6064428` | `Import-NavGitObjects`, `Export-NavGitObjects` (routes test objects), `Update-NavGitContainer` (Build and Update) |
| 4 | `2ce4692` | `Import-NavGitTestToolkit`, `Invoke-NavGitCommand`, `New-NavGitConfig`, `ConvertFrom-AdvaniaGitSetup`, Add-Ins support, `Update-NavGitAddIns` |
| 5 | `9d2c9fe` | `Start-NavGitDevelopmentEnvironment`, `Start-NavGitClient`, `Get-NavGitProfile`, plus fixes from testing against the real container |
| 6 | `a6cc062` | VS Code extension (`vscode/`), installed in VS Code |
| 7 | `0b9e494` | Repository [README](../README.md): configuration reference and AdvaniaGIT migration guide |

When phase 7 was committed: 257 Pester tests and 19 extension tests passing.

### Changes from the plan, made along the way

- **BcContainerHelper is not a `RequiredModules` dependency.** It's imported only when a command needs it, so the
  client commands stay fast.
- **`navgit.json` is strict JSON.** Windows PowerShell 5.1 can't parse comments.
- **The default test-object pattern is `(^|,)\s*Test`**, meaning a Version List entry that starts with "Test".
- **The release name for BC14 is `BC14`** in backup file names; AdvaniaGIT had none. It can be overridden with
  `navRelease`.
- **"Import All" is simply the normal import.** NavGit always compares every file; `-Force` imports everything.
- **No separate compile workaround.** BcContainerHelper already generates symbols when symbol loading is enabled.
- **`import.dateFormat` was added**, because object file dates follow the container's locale.
- **`ClientUserSettings.config` is not patched.** BcContainerHelper already prepares it on the host.
- **The default export filter is empty (all objects), as in AdvaniaGIT.**

## 5. Tested against real data

Read-only checks against the running `Cronus` container (NAV 2016) and `C:\Repos\NAV2016_CCB`:

- **Artifacts:** NAV 2018 CU30 NO resolved to `11.0.43274.0/no`; BC14 to `14.53.50097.0/w1`.
- **Container command (dry run):** `-bakFile`, `-imageName 'navgit'`, isolation and the remaining settings as
  intended.
- **Migration of `NAV2016_CCB\setup.json`:** artifact URL, license, NavUserPassword, hyperv, the SetupCertificate
  script, the US test toolkit and `dateFormat` `M/d/yy` all carried over.
- **Container state, the `[Object]` query (8,974 objects in 3 s) and the profile query** worked; the finsql arguments
  came out correct.
- **Comparing the 8,809 repository files with the database:** 8,719 unchanged, 0 unreadable dates. The only objects to
  import were the 90 test objects that AdvaniaGIT had never imported.

Fixes that came out of this:

- **Bracketed object declarations** (`OBJECT [Table 50376 Name ]`, names with trailing spaces) are now parsed.
- **System tables** are now compared instead of re-imported on every run.
- **The default export filter was changed to "all objects"**, so the exported system table files are not deleted.

Known and accepted: about 293 database objects aren't in Git, probably because exports skip unlicensed objects. They
are only reported (`import.deleteMissing: warn`).

## 6. Not tested yet (to do by hand)

1. `Update-NavGitContainer` in an elevated shell; `docker images` should show a `-nodb` tag.
2. `Export-NavGitObjects`: test objects move to `Tests\` (visible in `git status`).
3. Add-ins in the container and the Windows client after a build.
4. In VS Code (after Reload Window): the commands, the elevated window and the profile list in *Start NAV Client...*.

Note: the migrated `NAV2016_CCB` config uses the container name `Cronus`, the same as the existing AdvaniaGIT
container. Set `containerName` (e.g. `Cronus-ng`) to keep the old one.

## 7. Changes made outside the repository

- **Pester 6.2.0** installed for the current user (only 3.4 was present before).
- **Node.js 24.20.0 LTS** installed with winget.
- **NavGit extension 0.1.0** installed in VS Code. The AdvaniaGIT extension is still installed; the command names
  don't clash.
- Temporary files from testing are in the session scratchpad. A temporary `Cronus` state file was removed again.

## 8. Follow-up: first real use, rename and compile commands (version 0.2.0)

Feedback after the first real try: it works, and starting the client is much faster than with AdvaniaGIT.

Changes requested and made:

- **Renamed NavGit to NAVGit.** This covers the module (`module\NAVGit\NAVGit.psd1`), all function and file names
  (`New-NAVGitContainer`, ...), the VS Code category, the output channel and the docs.
  - Unchanged, so existing setups keep working: `navgit.json`, the VS Code command IDs and settings (`navgit.*`),
    and the environment variables (`NAVGIT_*`).
  - The sections above keep the old spelling, as they were written.
- **Three compile commands**, all run inside the container with `Compile-ObjectsInNavContainer`. AdvaniaGIT's
  host-side compile does not work with NavUserPassword containers; compiling in the container does.

| VS Code (NAVGit) | PowerShell | Filter |
| --- | --- | --- |
| Compile Uncompiled Objects | `Invoke-NAVGitCompile -Scope Uncompiled` | `Compiled=No` |
| Compile Modified Objects | `Invoke-NAVGitCompile -Scope Modified` | `Modified=Yes` |
| Compile All Objects (asks first) | `Invoke-NAVGitCompile -Scope All` | none |

- **`Invoke-NAVGitCompile -Filter '...'`** compiles with any C/SIDE filter. Schema changes are synchronized with
  `import.syncSchema`.
- **`Commands.psd1` entries can carry fixed `Parameters`**, so several commands can share one function (the three
  compile commands do).
- **Test objects are only imported with the test toolkit.** Without `includeTestToolkit: true`, `Import-NAVGitObjects`
  skips changed objects in `Tests` with a warning, because they can't compile without the toolkit. `-IncludeTests`
  overrides this, for example after Import Test Toolkit. The test files are still read, so test objects in the
  database are never treated as missing or marked `#DELETE`.
- **Version 0.2.0** of the module and the extension; the extension is reinstalled in VS Code.

Tests: 283 Pester tests and 19 extension tests passing.

## 9. PowerShell 7 check

Question: does anything prevent NAVGit from working with PowerShell 7? PowerShell 7.6.7 was installed (winget) and
everything was run under both versions:

- **All 283 Pester tests pass on Windows PowerShell 5.1 and PowerShell 7.**
- **Live, read-only checks under PowerShell 7 against the `Cronus` container all worked:** BcContainerHelper 6.1.3,
  the artifact lookup, the container state, the `[Object]` query (9,012 objects), parsing an object header, the
  finsql arguments, the port check, and code page 850.
- **`System.Data.SqlClient` is included in PowerShell 7** (4.6.1.6). A deliberately wrong `sa` password got "Login
  failed for user 'sa'", so the profile list's host-side SQL connection reaches the container.
- **The extension's background command line behaves the same with `powershell.exe` and `pwsh.exe`.**

Changes:

- **`CompatiblePSEditions` in the manifest is now `Desktop` and `Core`.**
- **Docs and the `navgit.powershellPath` setting describe both versions.** Set it to `pwsh.exe` to use PowerShell 7
  from VS Code.
- **Bug fix in `Invoke-NAVGitTests.ps1`:** started with `powershell.exe -File` (as the VS Code test task does), Windows
  PowerShell 5.1 leaves `$PSScriptRoot` empty in a parameter default, so no tests were found. This was not a
  PowerShell 7 issue.

Known difference, harmless: PowerShell 7's `ConvertFrom-Json` turns the state file's `savedAt` into a date.

## 10. First real container build, and two output flags

`Invoke-NAVGitCommand -Name BuildAndUpdate` on `NAV2016_CCB` worked end to end (14.5 minutes, of which the image build
took 12.5):

- The image was built as `navgit:onprem-9.0.50357.0-na-nodb` ("Skipping restore of Cronus database"), and the
  database came from `C:\AdvaniaGIT\Backup\2016-Cryobank.bak` through `-bakFile`.
- The Add-Ins were mapped and copied, the license imported, and SetupCertificate.ps1 ran from `myScripts`.
- Import: 77 objects imported, 8,642 unchanged, 90 test objects skipped (no `includeTestToolkit`), everything
  compiled, ForceSync done.

The first attempt hung while pulling the generic image from Microsoft's registry and was stopped by hand; the second
run reused the layers already downloaded.

Requested: less noise in the output.

- **`showBcContainerCommand`** (default `false`): writes the full `New-BcContainer` command (credential hidden) to the
  output before the container is built. It works in `navgit.json` and as a personal default in the user settings;
  `navgit.json` wins.
- **The list of objects that are in the database but not in Git** (in this database, 293 objects outside the license
  range) is now controlled by **`import.deleteMissing`**. A separate `showMissingGitObjects` flag was tried first and
  replaced by this single setting:
  - `skip` (new default): only a count goes to the verbose output.
  - `warn`: lists them as a warning.
  - `mark`: sets their Version List to `#DELETE` and lists them.
- **A `deleteMissing` in the user settings overrides the repository's `import.deleteMissing`.** This is the reverse of
  the other user settings, which are only defaults.

Also found: per-user modules are separate for Windows PowerShell and PowerShell 7. Pester had only been installed
for 5.1, so it was installed for PowerShell 7 too, and the test runner's error message now names the edition.

Tests: 297 Pester tests passing on Windows PowerShell 5.1 and PowerShell 7.

Publisher: `vsce` rejected the display name `Henrik Helgesen` as `publisher`, because it must be an ID. The
extension now uses the publisher ID `TheDoubleH` and `author: Henrik Helgesen`. The old `helgesen-consulting.navgit` was
uninstalled and `TheDoubleH.navgit` installed.
