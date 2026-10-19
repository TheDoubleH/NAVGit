BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1') -Force
}

InModuleScope NAVGit {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        Mock Write-Host { }
    }

    Describe 'Get-NAVGitCompileFilter' {
        It 'maps <Scope> to "<Filter>"' -ForEach @(
            @{ Scope = 'Uncompiled'; Filter = 'Compiled=No' }
            @{ Scope = 'Modified'; Filter = 'Modified=Yes' }
            @{ Scope = 'All'; Filter = '' }
        ) {
            Get-NAVGitCompileFilter -Scope $Scope | Should -Be $Filter
        }
    }

    Describe 'Invoke-NAVGitCompile' {
        BeforeEach {
            $repo = New-TestRepository
            $config = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)
            Mock Initialize-NAVGitContainerCommand {
                [pscustomobject]@{ Config = $config; ContainerName = 'cust'; Credential = New-TestCredential; SqlCredential = New-TestCredential 'sa' }
            }
            Mock Compile-ObjectsInNavContainer { }
            Mock Get-NAVGitUncompiledObjects { @() }
        }

        It 'compiles in the container with filter "<Filter>" for scope <Scope>' -ForEach @(
            @{ Scope = 'Uncompiled'; Filter = 'Compiled=No' }
            @{ Scope = 'Modified'; Filter = 'Modified=Yes' }
            @{ Scope = 'All'; Filter = '' }
        ) {
            $result = Invoke-NAVGitCompile -Path $repo -Scope $Scope

            $result.Filter | Should -Be $Filter
            $result.Uncompiled | Should -Be 0
            Should -Invoke Compile-ObjectsInNavContainer -Times 1 -Exactly -ParameterFilter {
                $containerName -eq 'cust' -and $filter -eq $Filter -and $sqlCredential.UserName -eq 'sa' -and $SynchronizeSchemaChanges -eq 'Force'
            }
        }

        It 'compiles only uncompiled objects by default' {
            $null = Invoke-NAVGitCompile -Path $repo
            Should -Invoke Compile-ObjectsInNavContainer -Times 1 -Exactly -ParameterFilter { $filter -eq 'Compiled=No' }
        }

        It 'accepts a custom filter' {
            $null = Invoke-NAVGitCompile -Path $repo -Filter 'Type=Codeunit;Id=50000..50099'
            Should -Invoke Compile-ObjectsInNavContainer -Times 1 -Exactly -ParameterFilter { $filter -eq 'Type=Codeunit;Id=50000..50099' }
        }

        It 'uses import.syncSchema' {
            $config.import.syncSchema = 'Yes'
            $null = Invoke-NAVGitCompile -Path $repo -Scope Modified
            Should -Invoke Compile-ObjectsInNavContainer -Times 1 -Exactly -ParameterFilter { $SynchronizeSchemaChanges -eq 'Yes' }
        }

        It 'reports objects that are still uncompiled' {
            Mock Get-NAVGitUncompiledObjects { @((New-TestDbObject -Id 50000 -Compiled $false), (New-TestDbObject -Type Codeunit -Id 50001 -Compiled $false)) }
            $result = Invoke-NAVGitCompile -Path $repo -Scope All -WarningVariable warnings -WarningAction SilentlyContinue
            $result.Uncompiled | Should -Be 2
            ($warnings -join ' ') | Should -Match '2 object\(s\) are not compiled'
        }
    }

    Describe 'Invoke-NAVGitCommand with fixed registry parameters' {
        BeforeEach {
            $repo = New-TestRepository
            Mock Assert-NAVGitAdministrator { }
            Mock Assert-NAVGitBcContainerHelper { }
            Mock Get-NAVGitUserSettings { New-TestUserSettings }
            Mock Write-NAVGitLog { }
            Mock Invoke-NAVGitCompile { }
        }

        It '<Name> calls Invoke-NAVGitCompile -Scope <Scope>' -ForEach @(
            @{ Name = 'CompileUncompiled'; Scope = 'Uncompiled' }
            @{ Name = 'CompileModified'; Scope = 'Modified' }
            @{ Name = 'CompileAll'; Scope = 'All' }
        ) {
            Invoke-NAVGitCommand -Name $Name -Repository $repo
            $LASTEXITCODE | Should -Be 0
            Should -Invoke Invoke-NAVGitCompile -Times 1 -Exactly -ParameterFilter { $Scope -eq $Scope -and $Path -eq $repo }
            Should -Invoke Assert-NAVGitAdministrator -Times 1 -Exactly
        }
    }
}
