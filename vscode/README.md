# NAVGit for VS Code

Commands for working with Dynamics NAV 2016-2018 and Business Central 14 (C/AL) in Docker containers, driven by the
NAVGit PowerShell module (bundled) and BcContainerHelper.

Open a repository with a `navgit.json` and run the commands from the Command Palette (category **NAVGit**):

| Command | What it does |
| --- | --- |
| Build and Update Container | Builds the container and imports all objects from Git |
| Build Container | Builds the container (backup restored via BcContainerHelper `-bakFile`) |
| Remove Container | Removes the container (asks first) |
| Import Test Toolkit | Imports the C/AL test toolkit and compiles |
| Import All GIT Objects to NAV | Imports changed objects from `Objects` (and `Tests` when `includeTestToolkit` is set), compiles and syncs |
| Export NAV objects to GIT | Exports objects; test objects go to `Tests`, the rest to `Objects` |
| Compile Uncompiled Objects | Compiles objects with `Compiled=No` in the container |
| Compile Modified Objects | Compiles objects with `Modified=Yes` |
| Compile All Objects | Compiles every object (asks first; can take a long time) |
| Update Add-ins | Copies the repository's `Add-Ins` into the container and the Windows client |
| Start Development Environment (FinSql) | Opens C/SIDE connected to the container |
| Start NAV Client (default) | Opens the Windows client on the default role center |
| Start NAV Client... | Lets you pick a profile, then opens the Windows client |
| Create navgit.json | Creates `navgit.json`, or converts an AdvaniaGIT `setup.json` |

Container and object commands need administrator rights. When VS Code itself does not run as administrator they open
a separate elevated PowerShell window (setting `navgit.runMode`). The client commands run without elevation.

Requirements: Windows PowerShell 5.1 or PowerShell 7 (set `navgit.powershellPath` to `pwsh.exe`), Docker, and the BcContainerHelper module (`Install-Module BcContainerHelper`).

`navgit.json` gets IntelliSense from the bundled schema.
