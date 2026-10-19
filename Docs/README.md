# NAVGit documentation

NAVGit is a PowerShell module and VS Code extension for developing Dynamics NAV 2016–2018 and Business Central 14
(C/AL) in Docker containers built with BcContainerHelper. It replaces the parts of AdvaniaGIT that matter for
day-to-day work: building containers, importing and exporting objects, compiling, and starting the client and C/SIDE.

| Document | Contents |
| --- | --- |
| [Getting started](getting-started.md) | Requirements, installation, the first repository |
| [navgit.json reference](configuration.md) | Every repository setting: type, default, accepted values, validation |
| [User settings](user-settings.md) | `%APPDATA%\NAVGit\settings.json`: per-machine folders and defaults |
| [VS Code extension](vscode-extension.md) | Extension settings and commands |
| [PowerShell commands](commands.md) | Every command and its parameters |
| [How it works](how-it-works.md) | Container build, import/export, credentials, state, file locations |
| [Migrating from AdvaniaGIT](migrating-from-advaniagit.md) | `setup.json` mapping and behaviour differences |
| [Troubleshooting](troubleshooting.md) | Common messages and their fixes |

## The two configuration files

| File | Scope | In Git | Purpose |
| --- | --- | --- | --- |
| `navgit.json` | repository | yes | What to build: artifact, database, license, container options, folders, import/export behaviour |
| `%APPDATA%\NAVGit\settings.json` | user / machine | no | Where things are on this machine, personal defaults |

How they combine:

| Setting | navgit.json | settings.json | Winner |
| --- | --- | --- | --- |
| Authentication | `auth` | `defaultAuth` | navgit.json; settings.json is the default |
| Isolation | `isolation` | `defaultIsolation` | navgit.json; settings.json is the default |
| Show the container command | `showBcContainerCommand` | `showBcContainerCommand` | navgit.json; settings.json is the default |
| Objects missing from Git | `import.deleteMissing` | `deleteMissing` | **settings.json** when set |
| Backup location | `database.bakFile` | `backupFolder` | `bakFile`; relative paths are tried in the repository, then in `backupFolder` |
| License location | `licenseFile` | `licenseFolder` | relative paths are tried in the repository, then in `licenseFolder` |

The VS Code extension has three settings of its own (`navgit.modulePath`, `navgit.powershellPath`,
`navgit.runMode`); see [vscode-extension.md](vscode-extension.md#settings).
