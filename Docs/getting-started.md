# Getting started

## Requirements

- Windows with Docker running Windows containers.
- Windows PowerShell 5.1 or PowerShell 7.
- BcContainerHelper: `Install-Module BcContainerHelper -Scope AllUsers`.
- Administrator rights for the container and object commands. Starting the client and C/SIDE does not need them.

Supported versions: Dynamics NAV 2016 (9.0), NAV 2017 (10.0), NAV 2018 (11.0), Business Central 13 and 14 (C/AL).

## Install

PowerShell module, from the [PowerShell Gallery](https://www.powershellgallery.com/packages/NAVGit):

```powershell
Install-Module NAVGit -Scope CurrentUser
Install-Module BcContainerHelper -Scope CurrentUser    # if you don't have it yet
```

Update later with `Update-Module NAVGit`. Windows PowerShell 5.1 and PowerShell 7 keep per-user modules in separate
folders, so install in the edition you use (or in both). `-Scope AllUsers` installs for every user but needs an
elevated session.

You can also run *NAVGit: Install PowerShell Module* in VS Code, which does the same for the PowerShell set in
`navgit.powershellPath`.

To work on NAVGit itself, import the module from a clone instead:
`Import-Module C:\Repos\NAVGit\module\NAVGit\NAVGit.psd1`.

VS Code extension: install **NAVGit** from the
[Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=TheDoubleH.navgit)
(`code --install-extension TheDoubleH.navgit`). It bundles the module, so you don't need to import it separately to
use the extension. See [vscode-extension.md](vscode-extension.md#installation).

## First repository

1. **Create `navgit.json`** in the repository root:
   - from an AdvaniaGIT repository: `ConvertFrom-AdvaniaGitSetup -WhatIf`, then without `-WhatIf`;
   - from scratch: `New-NAVGitConfig -Nav 2018 -Cu cu30 -Country no -BakFile C:\Backups\Customer.bak`;
   - or in VS Code: *NAVGit: Create navgit.json*.

   See [configuration.md](configuration.md) for every setting.

2. **Optionally create the user settings** in `%APPDATA%\NAVGit\settings.json`, for example to keep using
   AdvaniaGIT's backup and license folders. See [user-settings.md](user-settings.md).

   ```json
   {
     "backupFolder": "C:\\AdvaniaGIT\\Backup",
     "licenseFolder": "C:\\AdvaniaGIT\\License"
   }
   ```

3. **Check the plan** (no elevation needed):

   ```powershell
   Show-NAVGitContainerCommand
   ```

   It shows the artifact, database, license, isolation, memory and authentication, followed by the
   `New-BcContainer` command.

4. **Build the container and import the objects** (elevated):

   ```powershell
   Update-NAVGitContainer
   ```

   The first time, NAVGit asks for the container credential and stores it encrypted.

5. **Work**: start C/SIDE (`Start-NAVGitDevelopmentEnvironment`), change objects, export them to Git
   (`Export-NAVGitObjects`), commit. After pulling changes from others, `Import-NAVGitObjects` imports only what
   changed.

## Repository layout

```text
<repository>\
  navgit.json        configuration (committed)
  Objects\           application objects, one file per object (TAB18.TXT, COD50000.TXT, ...)
  Tests\             test objects
  Add-Ins\           optional .NET add-ins
```

The folder names can be changed with [`paths`](configuration.md#folders).
