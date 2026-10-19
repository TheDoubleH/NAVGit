# Initial Request

I need you to understand what AdvaniaGIT is doing, and how it interacts with BcContainerHelper (Was NAVContainerhelper).

I have the sourcecode for both; AdvaniaGit is located in the `C:\AdvaniaGIT` folder. It contains the powershell scripts and a VS Code extension I believe. BcContainerHelper shourcecode is located in `c:\repos\navcontainerhelper` and is a tool that downloads docker artifacts and builds docker containers.

Deep down, AdvaniaGIT bulds a commandline, that essentially executes NAV ContainerHelper. Once the buntainer is created, it then, if the right command is called, compares objects and then imports the text files into NAV and compiles them.

AdvaniaGIT has been abandoned, and my goal today is to come up with a plan to build a new version of AdvaniaGIT, but only have the features that I actually use.

**I generally use:**

- Build and Update Container
- Build Container
- Remove Container
- Import Test Toolkit
- Import All GIT Objects to NAV
- Export NAV objects to GIT

## Problems I have currently

If I have Test Objects (have `Test` in the `Version List`, they are not placed in the `Tests` folder if I use Export NAV objects to GIT. Would like to have that in the new version.

However, the biggest issue I currenly have, is that AdvaniaGIT takes a lot of parameters, and push them into a `-env` variable. This causes the Containerhelper to not quite handle them. Specificly when specifying the backup file. this means that the Artifacts downloaded include the cronus (Demo) database, despite not neeing it.

## Your task for now is

- With my description here, research and understand BCContaninerHelper and it's parameters. Understand AdvaniaGIT. I especially need you to understand how it generates the `New-Container` command and it's parameters.

With that knowledge, come up with a plan to:

- Create to generate a Powershell module that will handle the commands.
- Create a VS Code Extension that will have the commands I listed above.

Make sure to split things up, so that we can add additional commands later.
