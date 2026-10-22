@{
    RootModule           = 'NAVGit.psm1'
    # Keep in step with vscode/package.json "version" (the release workflow checks both against the tag).
    ModuleVersion        = '1.3.1'
    GUID                 = '6f0f3c2e-7a4b-4d61-9a55-2f3e8c1d9b10'
    Author               = 'Henrik Helgesen'
    CompanyName          = 'Helgesen Consulting, Inc.'
    Copyright            = '(c) Henrik Helgesen. All rights reserved.'
    Description          = 'Git-based development workflow for Dynamics NAV 2016-2018 / Business Central 14 (C/AL) containers, built on BcContainerHelper (install it separately: Install-Module BcContainerHelper).'
    PowerShellVersion    = '5.1'
    # Tested on Windows PowerShell 5.1 and PowerShell 7 (Windows only: Docker Windows containers, NAV client).
    CompatiblePSEditions = @('Desktop', 'Core')

    # BcContainerHelper is deliberately NOT a RequiredModule: it is imported on demand
    # (Assert-NAVGitBcContainerHelper) so lightweight commands such as starting the client stay fast.

    # Listed explicitly so the PowerShell Gallery and Find-Command can see the commands without loading the module.
    # Must match the files in Public\ (enforced by Module.Tests.ps1).
    FunctionsToExport    = @(
        'ConvertFrom-AdvaniaGitSetup'
        'Export-NAVGitObjects'
        'Get-NAVGitProfile'
        'Import-NAVGitObjects'
        'Import-NAVGitTestToolkit'
        'Invoke-NAVGitCommand'
        'Invoke-NAVGitCompile'
        'New-NAVGitConfig'
        'New-NAVGitContainer'
        'Remove-NAVGitContainer'
        'Show-NAVGitContainerCommand'
        'Start-NAVGitClient'
        'Start-NAVGitDevelopmentEnvironment'
        'Update-NAVGitAddIns'
        'Update-NAVGitContainer'
        'Update-NAVGitContainerState'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    FileList             = @('Commands.psd1', 'Schema\navgit.schema.json')

    PrivateData          = @{
        PSData = @{
            Tags         = @('NAV', 'BusinessCentral', 'CAL', 'Docker', 'BcContainerHelper', 'Git', 'Windows', 'PSEdition_Desktop', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/TheDoubleH/NAVGit'
            LicenseUri   = 'https://github.com/TheDoubleH/NAVGit/blob/main/LICENSE'
            IconUri      = 'https://raw.githubusercontent.com/TheDoubleH/NAVGit/main/assets/logo.png'
            ReleaseNotes = 'https://github.com/TheDoubleH/NAVGit/releases'
        }
    }
}
