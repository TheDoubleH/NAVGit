# VS Code extension

The extension adds the NAVGit commands to the Command Palette and validates `navgit.json`. It bundles the
PowerShell module, so nothing else needs installing apart from Docker and BcContainerHelper.

## Installation

Install **NAVGit** from the
[Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=TheDoubleH.navgit): search for
*NAVGit* in the Extensions view (`Ctrl+Shift+X`), or run:

```powershell
code --install-extension TheDoubleH.navgit
```

To build and install it from source instead:

```powershell
cd C:\Repos\NAVGit\vscode
npm install
npm run package
code --install-extension navgit-1.0.0.vsix
```

The extension activates when the workspace contains a `navgit.json` or an AdvaniaGIT `setup.json`.

## Settings

Set them in VS Code's settings (`Ctrl+,`, search *NAVGit*) or in `settings.json`.

| Setting | Type | Default | Accepted values |
| --- | --- | --- | --- |
| `navgit.modulePath` | string | `""` | `""`, a folder containing `NAVGit.psd1`, or the path of `NAVGit.psd1` |
| `navgit.powershellPath` | string | `powershell.exe` | `powershell.exe`, `pwsh.exe`, or a full path to either |
| `navgit.runMode` | string | `auto` | `auto`, `terminal`, `elevatedWindow` |

### `navgit.modulePath`

Which NAVGit module the extension runs. Empty uses the copy bundled with the extension. Point it at the repository's
module while developing NAVGit itself:

```json
"navgit.modulePath": "C:\\Repos\\NAVGit\\module\\NAVGit"
```

A folder path gets `NAVGit.psd1` appended. If the file does not exist, commands fail with
*The NAVGit module was not found at …*.

### `navgit.powershellPath`

The PowerShell executable. `powershell.exe` (Windows PowerShell 5.1) and `pwsh.exe` (PowerShell 7) both work.

### `navgit.runMode`

Where the container and object commands (which need administrator rights) run.

| Value | Behaviour |
| --- | --- |
| `auto` | The integrated *NAVGit* terminal when VS Code runs as administrator; otherwise a separate elevated PowerShell window (UAC prompt). |
| `terminal` | Always the integrated terminal. Commands fail there if VS Code is not elevated. |
| `elevatedWindow` | Always a separate elevated PowerShell window. |

Changing any `navgit.*` setting closes the *NAVGit* terminal so the next command starts a fresh one with the new
module or PowerShell.

## Commands

All commands are in the category **NAVGit**.

| Command | PowerShell | Runs in | Notes |
| --- | --- | --- | --- |
| Build and Update Container | `Update-NAVGitContainer` | elevated terminal/window | |
| Build Container | `New-NAVGitContainer` | elevated terminal/window | |
| Remove Container | `Remove-NAVGitContainer -Force` | elevated terminal/window | asks for confirmation first |
| Import Test Toolkit | `Import-NAVGitTestToolkit` | elevated terminal/window | |
| Import All GIT Objects to NAV | `Import-NAVGitObjects` | elevated terminal/window | |
| Export NAV objects to GIT | `Export-NAVGitObjects` | elevated terminal/window | |
| Compile Uncompiled Objects | `Invoke-NAVGitCompile -Scope Uncompiled` | elevated terminal/window | |
| Compile Modified Objects | `Invoke-NAVGitCompile -Scope Modified` | elevated terminal/window | |
| Compile All Objects | `Invoke-NAVGitCompile -Scope All` | elevated terminal/window | asks for confirmation first |
| Update Add-ins | `Update-NAVGitAddIns` | elevated terminal/window | |
| Start Development Environment (FinSql) | `Start-NAVGitDevelopmentEnvironment` | hidden background process | no elevation |
| Start NAV Client (default) | `Start-NAVGitClient` | hidden background process | opens `client.defaultProfile` or the default role center |
| Start NAV Client... | `Start-NAVGitClient -ProfileId <id>` | hidden background process | shows a profile picker first |
| Create navgit.json | `New-NAVGitConfig` / `ConvertFrom-AdvaniaGitSetup` | hidden background process | see below |
| Install PowerShell Module | `Install-Module NAVGit` / `Update-Module NAVGit` | hidden background process | see below |

Background commands show progress in the status bar; their output and errors go to the *NAVGit* output channel, and
errors are also shown as a notification.

### Which repository a command uses

1. The repository (folder with `navgit.json`) containing the active editor's file, if any.
2. Otherwise every workspace folder that is, or is inside, a repository. With more than one you pick from a list.
3. With none, the extension offers to run *Create navgit.json*.

### Create navgit.json

- If the chosen workspace folder has an AdvaniaGIT `setup.json` (and no `navgit.json`), you can convert it
  (`ConvertFrom-AdvaniaGitSetup`) or start empty.
- Starting empty asks for the version (NAV 2016, 2017, 2018 or Business Central 14) and the localization, then runs
  `New-NAVGitConfig`.
- The new file opens in the editor; migration notes are shown as a warning.

### Install PowerShell Module

The extension always uses its bundled module (or `navgit.modulePath`). This command installs the module from the
PowerShell Gallery so you can also use NAVGit from your own PowerShell sessions, outside VS Code.

- Installs `NAVGit` for the current user (no elevation needed), or updates it if it was installed from the Gallery
  before.
- Uses the PowerShell set in `navgit.powershellPath`. Windows PowerShell 5.1 and PowerShell 7 keep per-user modules
  in separate folders, so switch the setting and run the command again to install for the other edition.
- On Windows PowerShell 5.1 it first enables TLS 1.2 and installs the NuGet package provider if needed.
- If BcContainerHelper is missing, it offers to install that too (current user).

Afterwards, `Import-Module NAVGit` works in any session (PowerShell also loads it automatically when you run one of
its commands).

## IntelliSense for navgit.json

The extension registers the bundled schema for every file named `navgit.json`, giving completion, hover help and
validation for all settings described in [configuration.md](configuration.md).
