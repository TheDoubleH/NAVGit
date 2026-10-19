BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1') -Force
}

InModuleScope NAVGit {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        Mock Write-Host { }

        function New-AddInsRepository {
            $repo = New-TestRepository
            $addIns = Join-Path $repo 'Add-Ins'
            New-Item -ItemType Directory -Path (Join-Path $addIns 'Sub') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $addIns 'Customer.AddIn.dll') -Value 'dll'
            Set-Content -LiteralPath (Join-Path $addIns 'Sub\Helper.dll') -Value 'dll'
            return $repo
        }
    }

    Describe 'paths.addIns configuration' {
        It 'defaults to the Add-Ins folder of the repository' {
            $repo = New-TestRepository
            (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)).addInsPath | Should -Be (Join-Path $repo 'Add-Ins')
        }

        It 'can be disabled with an empty value' {
            $repo = New-TestRepository -Config @{ paths = @{ addIns = '' } }
            (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)).addInsPath | Should -BeNullOrEmpty
        }
    }

    Describe 'ConvertTo-NAVGitContainerParameters with add-ins' {
        BeforeAll {
            $artifact = [pscustomobject]@{ Url = 'https://x/onprem/11.0.43274.0/no'; Version = [version]'11.0.43274.0'; Country = 'no'; NavRelease = '2018' }
            $backup = [pscustomobject]@{ Path = 'C:\b.bak'; Source = 'Config' }
        }

        It 'maps the add-ins folder to c:\run\Add-ins next to other additionalParameters' {
            $config = Get-NAVGitConfig -Path (New-TestRepository -Config @{ additionalParameters = @('--env SqlTimeout=1200') }) -UserSettings (New-TestUserSettings)
            $params = ConvertTo-NAVGitContainerParameters -Config $config -ArtifactInfo $artifact -Backup $backup -Credential (New-TestCredential) -AddInsFolder 'C:\Repos\Customer\Add-Ins'

            $params.additionalParameters | Should -Be @('--env SqlTimeout=1200', '--volume "C:\Repos\Customer\Add-Ins:c:\run\Add-ins"')
        }

        It 'adds nothing without an add-ins folder' {
            $config = Get-NAVGitConfig -Path (New-TestRepository) -UserSettings (New-TestUserSettings)
            $params = ConvertTo-NAVGitContainerParameters -Config $config -ArtifactInfo $artifact -Backup $backup -Credential (New-TestCredential)
            $params.ContainsKey('additionalParameters') | Should -BeFalse
        }
    }

    Describe 'Get-NAVGitContainerPlan with add-ins' {
        BeforeAll {
            Mock Resolve-NAVGitArtifactUrl { [pscustomobject]@{ Url = 'https://x/onprem/11.0.43274.0/no'; Version = [version]'11.0.43274.0'; Country = 'no'; NavRelease = '2018' } }
            Mock Resolve-NAVGitBackupFile { [pscustomobject]@{ Path = 'C:\b.bak'; Source = 'Config' } }
            Mock Resolve-NAVGitLicenseFile { $null }
        }

        It 'maps the folder only when it exists' {
            $withFolder = Get-NAVGitConfig -Path (New-AddInsRepository) -UserSettings (New-TestUserSettings)
            $plan = Get-NAVGitContainerPlan -Config $withFolder -Credential (New-TestCredential)
            $plan.AddInsFolder | Should -Be $withFolder.addInsPath
            $plan.Parameters.additionalParameters | Should -Match 'c:\\run\\Add-ins'

            $withoutFolder = Get-NAVGitConfig -Path (New-TestRepository) -UserSettings (New-TestUserSettings)
            (Get-NAVGitContainerPlan -Config $withoutFolder -Credential (New-TestCredential)).AddInsFolder | Should -BeNullOrEmpty
        }
    }

    Describe 'Sync-NAVGitAddIns' {
        It 'copies through a shared folder into the container and into the host client folder' {
            $repo = New-AddInsRepository
            $staging = Join-Path $TestDrive 'addins-staging'
            New-Item -ItemType Directory -Path $staging -Force | Out-Null
            $client = Join-Path $TestDrive 'client\RoleTailored Client'
            New-Item -ItemType Directory -Path $client -Force | Out-Null
            $script:stagedFiles = $null

            Mock Get-NAVGitStagingFolder { $staging }
            Mock Get-BcContainerPath { $path }
            Mock Invoke-ScriptInBcContainer { $script:stagedFiles = @(Get-ChildItem -Path $argumentList[0] -Recurse -File | ForEach-Object { $_.Name } | Sort-Object) }

            Sync-NAVGitAddIns -ContainerName 'cust' -AddInsFolder (Join-Path $repo 'Add-Ins') -ClientFolder $client

            $script:stagedFiles | Should -Be @('Customer.AddIn.dll', 'Helper.dll')
            Join-Path $client 'Add-ins\Customer.AddIn.dll' | Should -Exist
            Join-Path $client 'Add-ins\Sub\Helper.dll' | Should -Exist
            $staging | Should -Not -Exist
        }
    }

    Describe 'Update-NAVGitAddIns' {
        It 'syncs the add-ins of an existing container' {
            $repo = New-AddInsRepository
            $config = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)
            Mock Initialize-NAVGitContainerCommand { [pscustomobject]@{ Config = $config; ContainerName = 'cust'; Credential = New-TestCredential; SqlCredential = $null } }
            Mock Get-NAVGitContainerState { @{ clientFolder = 'C:\client\RoleTailored Client' } }
            Mock Sync-NAVGitAddIns { }

            Update-NAVGitAddIns -Path $repo

            Should -Invoke Sync-NAVGitAddIns -Times 1 -Exactly -ParameterFilter {
                $ContainerName -eq 'cust' -and $AddInsFolder -eq $config.addInsPath -and $ClientFolder -eq 'C:\client\RoleTailored Client'
            }
        }

        It 'throws when the repository has no add-ins folder' {
            $repo = New-TestRepository
            $config = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)
            Mock Initialize-NAVGitContainerCommand { [pscustomobject]@{ Config = $config; ContainerName = 'cust'; Credential = New-TestCredential; SqlCredential = $null } }
            { Update-NAVGitAddIns -Path $repo } | Should -Throw '*No add-ins folder*'
        }
    }

    Describe 'New-NAVGitContainer with add-ins' {
        It 'copies the add-ins after creating the container' {
            $repo = New-AddInsRepository
            $env:NAVGIT_SETTINGS_PATH = Join-Path $TestDrive 'none.json'
            Mock Assert-NAVGitAdministrator { }
            Mock Assert-NAVGitBcContainerHelper { }
            Mock Get-NAVGitCredential { New-TestCredential }
            Mock Get-NAVGitContainerPlan { [pscustomobject]@{ Artifact = [pscustomobject]@{ Url = 'u' }; Backup = [pscustomobject]@{ Path = 'C:\b.bak' }; AddInsFolder = 'C:\Repo\Add-Ins'; Parameters = @{ containerName = 'x' } } }
            Mock Write-NAVGitContainerPlan { }
            Mock Test-BcContainer { $false }
            Mock New-BcContainer { }
            Mock Save-NAVGitContainerState { @{ clientFolder = 'C:\client' } }
            Mock Sync-NAVGitAddIns { }
            try {
                New-NAVGitContainer -Path $repo
            }
            finally { Remove-Item Env:\NAVGIT_SETTINGS_PATH }

            Should -Invoke Sync-NAVGitAddIns -Times 1 -Exactly -ParameterFilter { $AddInsFolder -eq 'C:\Repo\Add-Ins' -and $ClientFolder -eq 'C:\client' }
        }
    }

    Describe 'AdvaniaGIT mapAddInFolder migration' {
        It 'keeps the default for mapAddInFolder = true and disables it for false' {
            (ConvertFrom-AdvaniaGitSettings -Settings @{ projectName = 'P'; navVersion = '9.0'; mapAddInFolder = 'true' }).Config.Contains('paths') | Should -BeFalse
            (ConvertFrom-AdvaniaGitSettings -Settings @{ projectName = 'P'; navVersion = '9.0'; mapAddInFolder = 'false' }).Config.paths.addIns | Should -Be ''
        }
    }
}
