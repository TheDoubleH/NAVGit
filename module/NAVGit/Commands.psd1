# Command registry. Invoke-NAVGitCommand and the VS Code extension both dispatch through this list.
# To add a command: write the Public function, add an entry here, add an entry in vscode/src/commands/registry.ts.
#
#   Name                    Stable identifier used by the VS Code extension (-Name on Invoke-NAVGitCommand)
#   Function                Public NAVGit function that implements the command
#   Parameters              Optional fixed parameters for the function (lets several commands share one function)
#   Description             Human readable title
#   RequiresElevation       Command needs an elevated (administrator) PowerShell session
#   RequiresContainerHelper BcContainerHelper must be imported before the function runs
@{
    Commands = @(
        @{
            Name                    = 'BuildContainer'
            Function                = 'New-NAVGitContainer'
            Description             = 'Build Container'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'BuildAndUpdate'
            Function                = 'Update-NAVGitContainer'
            Description             = 'Build and Update Container'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'RemoveContainer'
            Function                = 'Remove-NAVGitContainer'
            Description             = 'Remove Container'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'ImportTestToolkit'
            Function                = 'Import-NAVGitTestToolkit'
            Description             = 'Import Test Toolkit'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'ImportObjects'
            Function                = 'Import-NAVGitObjects'
            Description             = 'Import All GIT Objects to NAV'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'ExportObjects'
            Function                = 'Export-NAVGitObjects'
            Description             = 'Export NAV objects to GIT'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'CompileUncompiled'
            Function                = 'Invoke-NAVGitCompile'
            Parameters              = @{ Scope = 'Uncompiled' }
            Description             = 'Compile uncompiled objects'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'CompileModified'
            Function                = 'Invoke-NAVGitCompile'
            Parameters              = @{ Scope = 'Modified' }
            Description             = 'Compile modified objects'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'CompileAll'
            Function                = 'Invoke-NAVGitCompile'
            Parameters              = @{ Scope = 'All' }
            Description             = 'Compile all objects'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'UpdateAddIns'
            Function                = 'Update-NAVGitAddIns'
            Description             = 'Update Add-ins'
            RequiresElevation       = $true
            RequiresContainerHelper = $true
        }
        @{
            Name                    = 'StartDevEnv'
            Function                = 'Start-NAVGitDevelopmentEnvironment'
            Description             = 'Start Development Environment (FinSql)'
            RequiresElevation       = $false
            RequiresContainerHelper = $false
        }
        @{
            Name                    = 'StartClient'
            Function                = 'Start-NAVGitClient'
            Description             = 'Start NAV Client'
            RequiresElevation       = $false
            RequiresContainerHelper = $false
        }
        @{
            Name                    = 'GetProfiles'
            Function                = 'Get-NAVGitProfile'
            Description             = 'List NAV profiles'
            RequiresElevation       = $false
            RequiresContainerHelper = $false
        }
    )
}
