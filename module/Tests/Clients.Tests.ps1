BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1') -Force
}

InModuleScope NAVGit {
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

    Describe 'Get-NAVGitFinSqlArguments' {
        It 'connects to the container database with SQL authentication for NavUserPassword' {
            $arguments = Get-NAVGitFinSqlArguments -State (New-TestState)

            $arguments | Should -Be ('servername="Customer-NAV201",database="Customer Database",ntauthentication=0,ID="Customer-NAV201",' +
                'navservername="Customer-NAV201",navserverinstance="NAV",navservermanagementport=7045')
        }

        It 'uses Windows authentication for Windows containers' {
            Get-NAVGitFinSqlArguments -State (New-TestState @{ auth = 'Windows' }) | Should -Match 'ntauthentication=1'
        }

        It 'adds generatesymbolreference only with symbol loading on NAV 2018 or later' {
            Get-NAVGitFinSqlArguments -State (New-TestState @{ enableSymbolLoading = $true }) | Should -Match ',generatesymbolreference=1$'
            Get-NAVGitFinSqlArguments -State (New-TestState @{ enableSymbolLoading = $true; navVersion = '10.0.1.0' }) | Should -Not -Match 'generatesymbolreference'
            Get-NAVGitFinSqlArguments -State (New-TestState) | Should -Not -Match 'generatesymbolreference'
        }
    }

    Describe 'Get-NAVGitClientArguments' {
        It 'uses the ClientUserSettings.config in the client folder' {
            $state = New-TestState
            Get-NAVGitClientArguments -State $state | Should -Be @("-settings:`"$(Join-Path $state.clientFolder 'ClientUserSettings.config')`"")
        }

        It 'adds the profile' {
            (Get-NAVGitClientArguments -State (New-TestState) -ProfileId 'ORDER PROCESSOR')[1] | Should -Be '-profile:"ORDER PROCESSOR"'
        }
    }

    Describe 'Get-NAVGitClientContext' {
        BeforeAll { $env:NAVGIT_SETTINGS_PATH = Join-Path $TestDrive 'none.json' }
        AfterAll { Remove-Item Env:\NAVGIT_SETTINGS_PATH -ErrorAction SilentlyContinue }

        It 'throws when the container was not built with NAVGit' {
            $repo = New-TestRepository
            Mock Get-NAVGitContainerState { $null }
            { Get-NAVGitClientContext -Path $repo } | Should -Throw '*No container information*'
        }

        It 'throws when the client folder is missing' {
            $repo = New-TestRepository
            Mock Get-NAVGitContainerState { New-TestState @{ clientFolder = 'C:\does\not\exist' } }
            { Get-NAVGitClientContext -Path $repo } | Should -Throw '*Windows client*was not found*'
        }

        It 'warns when the container does not answer' {
            $repo = New-TestRepository
            Mock Get-NAVGitContainerState { New-TestState }
            Mock Test-NAVGitContainerReachable { $false }

            $null = Get-NAVGitClientContext -Path $repo -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -Match 'does not answer'
        }
    }

    Describe 'Start-NAVGitDevelopmentEnvironment' {
        It 'starts finsql.exe with the container arguments' {
            $state = New-TestState
            Mock Get-NAVGitClientContext { [pscustomobject]@{ Config = @{ client = @{ defaultProfile = '' } }; State = $state } }
            Mock Start-Process { }

            Start-NAVGitDevelopmentEnvironment -Path $TestDrive

            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq (Join-Path $state.clientFolder 'finsql.exe') -and $ArgumentList -match 'servername="Customer-NAV201"'
            }
        }
    }

    Describe 'Start-NAVGitClient' {
        BeforeEach {
            $state = New-TestState
            $config = @{ client = @{ defaultProfile = '' } }
            Mock Get-NAVGitClientContext { [pscustomobject]@{ Config = $config; State = $state } }
            Mock Start-Process { }
        }

        It 'opens the default role center without a profile' {
            Start-NAVGitClient -Path $TestDrive
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -like '*Microsoft.Dynamics.Nav.Client.exe' -and @($ArgumentList).Count -eq 1 -and $ArgumentList[0] -like '-settings:*'
            }
        }

        It 'uses client.defaultProfile from navgit.json' {
            $config.client.defaultProfile = 'ACCOUNTANT'
            Start-NAVGitClient -Path $TestDrive
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -contains '-profile:"ACCOUNTANT"' }
        }

        It 'opens the given profile' {
            Start-NAVGitClient -Path $TestDrive -ProfileId 'ORDER PROCESSOR'
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -contains '-profile:"ORDER PROCESSOR"' }
        }

        It 'lets the user pick a profile with -SelectProfile' {
            Mock Get-NAVGitProfile { @([pscustomobject]@{ Id = 'A'; Description = 'a'; IsDefault = $true }, [pscustomobject]@{ Id = 'B'; Description = 'b'; IsDefault = $false }) }
            Mock Read-Host { '2' }
            Start-NAVGitClient -Path $TestDrive -SelectProfile
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -contains '-profile:"B"' }
        }

        It 'opens the default role center when Enter is pressed in the menu' {
            Mock Get-NAVGitProfile { @([pscustomobject]@{ Id = 'A'; Description = 'a'; IsDefault = $true }) }
            Mock Read-Host { '' }
            Start-NAVGitClient -Path $TestDrive -SelectProfile
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { @($ArgumentList).Count -eq 1 }
        }
    }

    Describe 'Get-NAVGitProfile' {
        BeforeEach {
            $state = New-TestState
            Mock Get-NAVGitClientContext { [pscustomobject]@{ Config = @{}; State = $state } }
            Mock Invoke-NAVGitSql {
                @(
                    [pscustomobject]@{ Id = 'ACCOUNTANT'; Description = 'Accountant'; RoleCenterId = 9001; IsDefault = 0 }
                    [pscustomobject]@{ Id = 'ORDER PROCESSOR'; Description = 'Sales Order Processor'; RoleCenterId = 9006; IsDefault = 1 }
                )
            }
        }

        It 'returns the profiles with the default marked, using the stored credential' {
            Mock Get-NAVGitCredential { New-TestCredential }

            $profiles = @(Get-NAVGitProfile -Path $TestDrive)

            $profiles.Count | Should -Be 2
            $profiles[1].Id | Should -Be 'ORDER PROCESSOR'
            $profiles[1].IsDefault | Should -BeTrue
            $profiles[0].RoleCenterId | Should -Be 9001
            Should -Invoke Get-NAVGitCredential -Times 1 -Exactly -ParameterFilter { $NoPrompt }
            Should -Invoke Invoke-NAVGitSql -Times 1 -Exactly -ParameterFilter { $Query -match '\[dbo\]\.\[Profile\]' -and $Credential }
        }

        It 'does not need a credential for Windows containers' {
            $state.auth = 'Windows'
            Mock Get-NAVGitCredential { throw 'should not be called' }
            @(Get-NAVGitProfile -Path $TestDrive).Count | Should -Be 2
        }

        It 'explains a missing credential' {
            Mock Get-NAVGitCredential { throw 'No stored credential' }
            { Get-NAVGitProfile -Path $TestDrive } | Should -Throw '*saved the first time you build the container*'
        }
    }

    Describe 'Invoke-NAVGitCommand for client commands' {
        It 'passes ProfileId and returns clean JSON for GetProfiles' {
            $repo = New-TestRepository
            Mock Assert-NAVGitAdministrator { throw 'should not need elevation' }
            Mock Assert-NAVGitBcContainerHelper { throw 'should not load BcContainerHelper' }
            Mock Get-NAVGitProfile { Write-Warning 'noise'; Write-Host 'noise'; [pscustomobject]@{ Id = 'A'; Description = 'a'; RoleCenterId = 1; IsDefault = $true } }
            Mock Start-NAVGitClient { }

            $json = Invoke-NAVGitCommand -Name GetProfiles -Repository $repo -AsJson
            $parsed = @($json | ConvertFrom-Json)
            $parsed.Count | Should -Be 1
            $parsed[0].Id | Should -Be 'A'

            Invoke-NAVGitCommand -Name StartClient -Repository $repo -ProfileId 'B'
            Should -Invoke Start-NAVGitClient -Times 1 -Exactly -ParameterFilter { $ProfileId -eq 'B' }
            $LASTEXITCODE | Should -Be 0
        }
    }
}
