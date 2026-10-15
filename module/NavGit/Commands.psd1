# Command registry. Invoke-NavGitCommand and the VS Code extension both dispatch through this list.
# To add a command: write the Public function, add an entry here, add an entry in vscode/src/commands/registry.ts.
#
#   Name                    Stable identifier used by the VS Code extension (-Name on Invoke-NavGitCommand)
#   Function                Public NavGit function that implements the command
#   Description             Human readable title
#   RequiresElevation       Command needs an elevated (administrator) PowerShell session
#   RequiresContainerHelper BcContainerHelper must be imported before the function runs
@{
    Commands = @(
        @{
            Name                    = 'BuildContainer'
            Function                = 'New-NavGitContainer'
            Description             = 'Build Container'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'BuildAndUpdate'
            Function                = 'Update-NavGitContainer'
            Description             = 'Build and Update Container'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'RemoveContainer'
            Function                = 'Remove-NavGitContainer'
            Description             = 'Remove Container'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'ImportTestToolkit'
            Function                = 'Import-NavGitTestToolkit'
            Description             = 'Import Test Toolkit'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'ImportObjects'
            Function                = 'Import-NavGitObjects'
            Description             = 'Import All GIT Objects to NAV'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'ExportObjects'
            Function                = 'Export-NavGitObjects'
            Description             = 'Export NAV objects to GIT'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'StartDevEnv'
            Function                = 'Start-NavGitDevelopmentEnvironment'
            Description             = 'Start Development Environment (FinSql)'
            RequiresElevation       = $false
            RequiresContainerHelper = $false
        }
        @{
            Name                    = 'StartClient'
            Function                = 'Start-NavGitClient'
            Description             = 'Start NAV Client'
            RequiresElevation       = $false
            RequiresContainerHelper = $false
        }
        @{
            Name                    = 'GetProfiles'
            Function                = 'Get-NavGitProfile'
            Description             = 'List NAV profiles'
            RequiresElevation       = $false
            RequiresContainerHelper = $false
        }
    )
}
