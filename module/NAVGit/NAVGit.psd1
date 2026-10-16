@{
    RootModule           = 'NAVGit.psm1'
    ModuleVersion        = '0.2.0'
    GUID                 = '6f0f3c2e-7a4b-4d61-9a55-2f3e8c1d9b10'
    Author               = 'Henrik Helgesen'
    CompanyName          = 'Helgesen Consulting'
    Copyright            = '(c) Henrik Helgesen. All rights reserved.'
    Description          = 'Git-based development workflow for Dynamics NAV 2016-2018 / Business Central 14 (C/AL) containers, built on BcContainerHelper.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop')

    # BcContainerHelper is deliberately NOT a RequiredModule: it is imported on demand
    # (Assert-NAVGitBcContainerHelper) so lightweight commands such as starting the client stay fast.

    FunctionsToExport    = '*'
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    FileList             = @('Commands.psd1', 'Schema\navgit.schema.json')

    PrivateData          = @{
        PSData = @{
            Tags = @('NAV', 'BusinessCentral', 'CAL', 'Docker', 'BcContainerHelper', 'Git')
        }
    }
}
