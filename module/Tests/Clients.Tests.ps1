BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NavGit\NavGit.psd1') -Force
}

InModuleScope NavGit {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        Mock Write-Host { }

        function New-TestState {
            param([hashtable] $Override = @{})
            $client = Join-Path $TestDrive 'client\RoleTailored Client'
            New-Item -ItemType Directory -Path $client -Force | Out-Null
            foreach ($exe in @('finsql.exe', 'Microsoft.Dynamics.Nav.Client.exe')) {
                Set-Content -LiteralPath (Join-Path $client $exe) -Value 'exe'
            }
            $state = @{
                containerName = 'Customer-NAV201'; auth = 'NavUserPassword'; navVersion = '11.0.43274.0'
                serverInstance = 'NAV'; databaseName = 'Customer Database'; hostDatabaseServer = 'Customer-NAV201'
                clientServicesPort = 7046; managementServicesPort = 7045; enableSymbolLoading = $false; clientFolder = $client
            }
            foreach ($key in $Override.Keys) { $state[$key] = $Override[$key] }
            return $state
        }
    }

    Describe 'Get-NavGitFinSqlArguments' {
        It 'connects to the container database with SQL authentication for NavUserPassword' {
            $arguments = Get-NavGitFinSqlArguments -State (New-TestState)

            $arguments | Should -Be ('servername="Customer-NAV201",database="Customer Database",ntauthentication=0,ID="Customer-NAV201",' +
                'navservername="Customer-NAV201",navserverinstance="NAV",navservermanagementport=7045')
        }

        It 'uses Windows authentication for Windows containers' {
            Get-NavGitFinSqlArguments -State (New-TestState @{ auth = 'Windows' }) | Should -Match 'ntauthentication=1'
        }

        It 'adds generatesymbolreference only with symbol loading on NAV 2018 or later' {
            Get-NavGitFinSqlArguments -State (New-TestState @{ enableSymbolLoading = $true }) | Should -Match ',generatesymbolreference=1$'
            Get-NavGitFinSqlArguments -State (New-TestState @{ enableSymbolLoading = $true; navVersion = '10.0.1.0' }) | Should -Not -Match 'generatesymbolreference'
            Get-NavGitFinSqlArguments -State (New-TestState) | Should -Not -Match 'generatesymbolreference'
        }
    }

    Describe 'Get-NavGitClientArguments' {
        It 'uses the ClientUserSettings.config in the client folder' {
            $state = New-TestState
            Get-NavGitClientArguments -State $state | Should -Be @("-settings:`"$(Join-Path $state.clientFolder 'ClientUserSettings.config')`"")
        }

        It 'adds the profile' {
            (Get-NavGitClientArguments -State (New-TestState) -ProfileId 'ORDER PROCESSOR')[1] | Should -Be '-profile:"ORDER PROCESSOR"'
        }
    }

    Describe 'Get-NavGitClientContext' {
        BeforeAll { $env:NAVGIT_SETTINGS_PATH = Join-Path $TestDrive 'none.json' }
        AfterAll { Remove-Item Env:\NAVGIT_SETTINGS_PATH -ErrorAction SilentlyContinue }

        It 'throws when the container was not built with NavGit' {
            $repo = New-TestRepository
            Mock Get-NavGitContainerState { $null }
            { Get-NavGitClientContext -Path $repo } | Should -Throw '*No container information*'
        }

        It 'throws when the client folder is missing' {
            $repo = New-TestRepository
            Mock Get-NavGitContainerState { New-TestState @{ clientFolder = 'C:\does\not\exist' } }
            { Get-NavGitClientContext -Path $repo } | Should -Throw '*Windows client*was not found*'
        }

        It 'warns when the container does not answer' {
            $repo = New-TestRepository
            Mock Get-NavGitContainerState { New-TestState }
            Mock Test-NavGitContainerReachable { $false }

            $null = Get-NavGitClientContext -Path $repo -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -Match 'does not answer'
        }
    }

    Describe 'Start-NavGitDevelopmentEnvironment' {
        It 'starts finsql.exe with the container arguments' {
            $state = New-TestState
            Mock Get-NavGitClientContext { [pscustomobject]@{ Config = @{ client = @{ defaultProfile = '' } }; State = $state } }
            Mock Start-Process { }

            Start-NavGitDevelopmentEnvironment -Path $TestDrive

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq (Join-Path $state.clientFolder 'finsql.exe') -and $ArgumentList -match 'servername="Customer-NAV201"'
            }
        }
    }

    Describe 'Start-NavGitClient' {
        BeforeEach {
            $state = New-TestState
            $config = @{ client = @{ defaultProfile = '' } }
            Mock Get-NavGitClientContext { [pscustomobject]@{ Config = $config; State = $state } }
            Mock Start-Process { }
        }

        It 'opens the default role center without a profile' {
            Start-NavGitClient -Path $TestDrive
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -like '*Microsoft.Dynamics.Nav.Client.exe' -and @($ArgumentList).Count -eq 1 -and $ArgumentList[0] -like '-settings:*'
            }
        }

        It 'uses client.defaultProfile from navgit.json' {
            $config.client.defaultProfile = 'ACCOUNTANT'
            Start-NavGitClient -Path $TestDrive
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -contains '-profile:"ACCOUNTANT"' }
        }

        It 'opens the given profile' {
            Start-NavGitClient -Path $TestDrive -ProfileId 'ORDER PROCESSOR'
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -contains '-profile:"ORDER PROCESSOR"' }
        }

        It 'lets the user pick a profile with -SelectProfile' {
            Mock Get-NavGitProfile { @([pscustomobject]@{ Id = 'A'; Description = 'a'; IsDefault = $true }, [pscustomobject]@{ Id = 'B'; Description = 'b'; IsDefault = $false }) }
            Mock Read-Host { '2' }
            Start-NavGitClient -Path $TestDrive -SelectProfile
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -contains '-profile:"B"' }
        }

        It 'opens the default role center when Enter is pressed in the menu' {
            Mock Get-NavGitProfile { @([pscustomobject]@{ Id = 'A'; Description = 'a'; IsDefault = $true }) }
            Mock Read-Host { '' }
            Start-NavGitClient -Path $TestDrive -SelectProfile
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { @($ArgumentList).Count -eq 1 }
        }
    }

    Describe 'Get-NavGitProfile' {
        BeforeEach {
            $state = New-TestState
            Mock Get-NavGitClientContext { [pscustomobject]@{ Config = @{}; State = $state } }
            Mock Invoke-NavGitSql {
                @(
                    [pscustomobject]@{ Id = 'ACCOUNTANT'; Description = 'Accountant'; RoleCenterId = 9001; IsDefault = 0 }
                    [pscustomobject]@{ Id = 'ORDER PROCESSOR'; Description = 'Sales Order Processor'; RoleCenterId = 9006; IsDefault = 1 }
                )
            }
        }

        It 'returns the profiles with the default marked, using the stored credential' {
            Mock Get-NavGitCredential { New-TestCredential }

            $profiles = @(Get-NavGitProfile -Path $TestDrive)

            $profiles.Count | Should -Be 2
            $profiles[1].Id | Should -Be 'ORDER PROCESSOR'
            $profiles[1].IsDefault | Should -BeTrue
            $profiles[0].RoleCenterId | Should -Be 9001
            Should -Invoke Get-NavGitCredential -Times 1 -Exactly -ParameterFilter { $NoPrompt }
            Should -Invoke Invoke-NavGitSql -Times 1 -Exactly -ParameterFilter { $Query -match '\[dbo\]\.\[Profile\]' -and $Credential }
        }

        It 'does not need a credential for Windows containers' {
            $state.auth = 'Windows'
            Mock Get-NavGitCredential { throw 'should not be called' }
            @(Get-NavGitProfile -Path $TestDrive).Count | Should -Be 2
        }

        It 'explains a missing credential' {
            Mock Get-NavGitCredential { throw 'No stored credential' }
            { Get-NavGitProfile -Path $TestDrive } | Should -Throw '*saved the first time you build the container*'
        }
    }

    Describe 'Invoke-NavGitCommand for client commands' {
        It 'passes ProfileId and returns clean JSON for GetProfiles' {
            $repo = New-TestRepository
            Mock Assert-NavGitAdministrator { throw 'should not need elevation' }
            Mock Assert-NavGitBcContainerHelper { throw 'should not load BcContainerHelper' }
            Mock Get-NavGitProfile { Write-Warning 'noise'; Write-Host 'noise'; [pscustomobject]@{ Id = 'A'; Description = 'a'; RoleCenterId = 1; IsDefault = $true } }
            Mock Start-NavGitClient { }

            $json = Invoke-NavGitCommand -Name GetProfiles -Repository $repo -AsJson
            $parsed = @($json | ConvertFrom-Json)
            $parsed.Count | Should -Be 1
            $parsed[0].Id | Should -Be 'A'

            Invoke-NavGitCommand -Name StartClient -Repository $repo -ProfileId 'B'
            Should -Invoke Start-NavGitClient -Times 1 -Exactly -ParameterFilter { $ProfileId -eq 'B' }
            $LASTEXITCODE | Should -Be 0
        }
    }
}
