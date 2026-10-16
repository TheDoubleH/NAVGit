BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1') -Force
}

InModuleScope NAVGit {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

        function Get-TestConfig {
            param([hashtable] $Override = @{}, [hashtable] $UserSettings = (New-TestUserSettings))
            $repo = New-TestRepository -Config $Override
            return Get-NAVGitConfig -Path $repo -UserSettings $UserSettings
        }

        function New-ArtifactInfo([string] $Version = '11.0.43274.0') {
            [pscustomobject]@{
                Url        = "https://bcartifacts.azureedge.net/onprem/$Version/no"
                Version    = [version]$Version
                Country    = 'no'
                NavRelease = Get-NAVGitNavRelease -Version $Version
            }
        }

        $backup = [pscustomobject]@{ Path = 'C:\Backups\2018-Customer.bak'; Source = 'Search' }
        $demo = [pscustomobject]@{ Path = $null; Source = 'Demo' }
        $credential = New-TestCredential
    }

    Describe 'ConvertTo-NAVGitContainerParameters' {
        BeforeAll {
            function Invoke-Build {
                param([hashtable] $Override = @{}, $Backup = $backup, [string] $Version = '11.0.43274.0', [string] $License, [string] $UserDomain = 'CONTOSO')
                $config = Get-TestConfig $Override
                ConvertTo-NAVGitContainerParameters -Config $config -ArtifactInfo (New-ArtifactInfo $Version) -Backup $Backup `
                    -LicenseFile $License -Credential $credential -UserDomain $UserDomain
            }
        }

        It 'passes the backup as the native -bakFile parameter, never as --env bakfile' {
            $params = Invoke-Build

            $params.bakFile | Should -Be 'C:\Backups\2018-Customer.bak'
            $params.imageName | Should -Be 'navgit'
            $params.ContainsKey('additionalParameters') | Should -BeFalse
        }

        It 'omits bakFile for the Cronus demo database' {
            (Invoke-Build -Backup $demo).ContainsKey('bakFile') | Should -BeFalse
        }

        It 'always sets the C/AL container defaults' {
            $params = Invoke-Build

            $params.accept_eula | Should -BeTrue
            $params.accept_outdated | Should -BeTrue
            $params.includeCSide | Should -BeTrue
            $params.doNotExportObjectsToText | Should -BeTrue
            $params.shortcuts | Should -Be 'None'
            $params.restart | Should -Be 'unless-stopped'
            $params.updateHosts | Should -BeTrue
            $params.containerName | Should -Be 'Customer-NAV201'
            $params.artifactUrl | Should -Be 'https://bcartifacts.azureedge.net/onprem/11.0.43274.0/no'
            $params.Credential | Should -Be $credential
        }

        It 'leaves out isolation when it is empty' {
            (Invoke-Build @{ isolation = '' }).ContainsKey('isolation') | Should -BeFalse
        }

        It 'passes isolation and memoryLimit' {
            $params = Invoke-Build @{ isolation = 'hyperv'; memoryLimit = '12G' }
            $params.isolation | Should -Be 'hyperv'
            $params.memoryLimit | Should -Be '12G'
        }

        It 'passes the license file when set' {
            (Invoke-Build -License 'C:\Licenses\Customer.flf').licenseFile | Should -Be 'C:\Licenses\Customer.flf'
            (Invoke-Build).ContainsKey('licenseFile') | Should -BeFalse
        }

        It 'switches Windows auth to NavUserPassword for Azure AD accounts' {
            $params = Invoke-Build @{ auth = 'Windows' } -UserDomain 'AzureAD' -WarningAction SilentlyContinue
            $params.auth | Should -Be 'NavUserPassword'
        }

        It 'keeps Windows auth for domain accounts' {
            (Invoke-Build @{ auth = 'Windows' }).auth | Should -Be 'Windows'
        }

        It 'allows enableSymbolLoading on NAV 2018 and later' {
            (Invoke-Build @{ enableSymbolLoading = $true }).enableSymbolLoading | Should -BeTrue
            (Invoke-Build @{ enableSymbolLoading = $true } -Version '14.53.50097.0').enableSymbolLoading | Should -BeTrue
        }

        It 'rejects enableSymbolLoading before NAV 2018' {
            { Invoke-Build @{ enableSymbolLoading = $true } -Version '10.0.30000.0' } | Should -Throw '*requires NAV 2018 (11.0)*'
        }

        It 'rejects versions outside 9-14' {
            { Invoke-Build -Version '8.0.48067.0' } | Should -Throw '*not supported*'
        }

        It 'passes the test toolkit switches' {
            $params = Invoke-Build @{ includeTestToolkit = $true; testToolkit = @{ librariesOnly = $true } }
            $params.includeTestToolkit | Should -BeTrue
            $params.includeTestLibrariesOnly | Should -BeTrue
            (Invoke-Build).ContainsKey('includeTestToolkit') | Should -BeFalse
        }

        It 'passes myScripts and allowed additionalParameters' {
            $params = Invoke-Build @{ myScripts = @('https://example/SetupCertificate.ps1'); additionalParameters = @('--env SqlTimeout=1200') }
            $params.myScripts | Should -Be @('https://example/SetupCertificate.ps1')
            $params.additionalParameters | Should -Be @('--env SqlTimeout=1200')
        }

        It 'rejects --env bakfile in additionalParameters' {
            { Invoke-Build @{ additionalParameters = @('--env bakfile="C:\Host\Log\x\NAVBackup.bak"') } } | Should -Throw "*use 'database.bakFile'*"
        }
    }

    Describe 'Assert-NAVGitAdditionalParameters' {
        It 'rejects <Parameter>' -ForEach @(
            @{ Parameter = '--env bakfile="C:\Host\Log\x\NAVBackup.bak"'; Hint = 'database.bakFile' }
            @{ Parameter = '-e licensefile=C:\x.flf'; Hint = 'licenseFile' }
            @{ Parameter = '--env username=admin'; Hint = 'stored credential' }
            @{ Parameter = '--env databaseServer=sql01'; Hint = 'external databases are not supported' }
            @{ Parameter = '--env artifactUrl=https://x'; Hint = 'artifact' }
            @{ Parameter = '--dns 8.8.8.8'; Hint = "'dns'" }
            @{ Parameter = '--restart always'; Hint = 'restart policy' }
            @{ Parameter = '--memory 8G'; Hint = 'memoryLimit' }
            @{ Parameter = '--isolation=process'; Hint = "'isolation'" }
        ) {
            { Assert-NAVGitAdditionalParameters -AdditionalParameters @($Parameter) } | Should -Throw "*$Hint*"
        }

        It 'accepts <_>' -ForEach @(
            '--volume "C:\Repos\Customer:C:\GIT"'
            '--env SqlTimeout=1200'
            '--env customNavSettings=EnableTaskScheduler=false'
            '--label owner=henrik'
        ) {
            { Assert-NAVGitAdditionalParameters -AdditionalParameters @($_) } | Should -Not -Throw
        }

        It 'reports every problem' {
            $thrown = { Assert-NAVGitAdditionalParameters -AdditionalParameters @('--env bakfile=x', '--dns 8.8.8.8') } | Should -Throw -PassThru
            $thrown.Exception.Message | Should -Match 'bakFile'
            $thrown.Exception.Message | Should -Match "'dns'"
        }

        It 'accepts an empty list' {
            { Assert-NAVGitAdditionalParameters -AdditionalParameters @() } | Should -Not -Throw
        }
    }

    Describe 'Format-NAVGitContainerCommand' {
        It 'shows parameters and hides the password' {
            $text = Format-NAVGitContainerCommand -Parameters @{
                accept_eula = $true; containerName = 'cust'; bakFile = 'C:\b.bak'; Credential = $credential; myScripts = @('a.ps1')
            }
            $text | Should -Match '^New-BcContainer'
            $text | Should -Match "-bakFile 'C:\\b.bak'"
            $text | Should -Match "-Credential \(credential for 'admin', password hidden\)"
            $text | Should -Match "-myScripts @\('a.ps1'\)"
            $text | Should -Not -Match 'P@ssw0rd'
        }
    }

    Describe 'Get-NAVGitHostDatabaseServer' {
        It 'maps <Server>\<Instance> to <Expected>' -ForEach @(
            @{ Server = 'localhost'; Instance = 'SQLEXPRESS'; Expected = 'cust' }
            @{ Server = 'localhost'; Instance = ''; Expected = 'cust' }
            @{ Server = 'localhost'; Instance = 'NAVDEMO'; Expected = 'cust\NAVDEMO' }
            @{ Server = 'host.containerhelper.internal'; Instance = 'SQL2019'; Expected = 'localhost\SQL2019' }
            @{ Server = 'sql01'; Instance = ''; Expected = 'sql01' }
        ) {
            Get-NAVGitHostDatabaseServer -ContainerName 'cust' -DatabaseServer $Server -DatabaseInstance $Instance | Should -Be $Expected
        }
    }

    Describe 'Get-NAVGitClientFolder' {
        It 'finds the RoleTailored Client copied by -includeCSide' {
            $helper = Join-Path $TestDrive 'BcContainerHelper'
            $client = Join-Path $helper 'Extensions\cust\Program Files\110\RoleTailored Client'
            New-Item -ItemType Directory -Path $client -Force | Out-Null

            Get-NAVGitClientFolder -ContainerName 'cust' -HostHelperFolder $helper | Should -Be $client
            Get-NAVGitClientFolder -ContainerName 'other' -HostHelperFolder $helper | Should -BeNullOrEmpty
        }
    }

    Describe 'Get-NAVGitCredential' {
        BeforeEach {
            $env:NAVGIT_DATA_PATH = Join-Path $TestDrive ('data-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
        }
        AfterAll {
            Remove-Item Env:\NAVGIT_DATA_PATH -ErrorAction SilentlyContinue
        }

        It 'prompts once and stores the credential encrypted' {
            Mock Get-Credential { New-TestCredential 'admin' 'secret' }

            $first = Get-NAVGitCredential -ContainerName 'cust' -Auth NavUserPassword
            $second = Get-NAVGitCredential -ContainerName 'other' -Auth NavUserPassword

            $first.UserName | Should -Be 'admin'
            $second.GetNetworkCredential().Password | Should -Be 'secret'
            Should -Invoke Get-Credential -Times 1 -Exactly
            Join-Path $env:NAVGIT_DATA_PATH 'credentials\default.xml' | Should -Exist
            Get-Content (Join-Path $env:NAVGIT_DATA_PATH 'credentials\default.xml') -Raw | Should -Not -Match 'secret'
        }

        It 'prefers a container specific credential' {
            Mock Get-Credential { throw 'should not prompt' }
            $folder = Get-NAVGitDataPath -Name credentials
            New-TestCredential 'default' 'a' | Export-Clixml (Join-Path $folder 'default.xml')
            New-TestCredential 'special' 'b' | Export-Clixml (Join-Path $folder 'cust.xml')

            (Get-NAVGitCredential -ContainerName 'cust' -Auth NavUserPassword).UserName | Should -Be 'special'
            (Get-NAVGitCredential -ContainerName 'other' -Auth NavUserPassword).UserName | Should -Be 'default'
        }

        It 'ignores a stored credential for another user with Windows auth' {
            $folder = Get-NAVGitDataPath -Name credentials
            New-TestCredential 'someoneelse' 'a' | Export-Clixml (Join-Path $folder 'default.xml')
            Mock Get-Credential { New-TestCredential "DOMAIN\$env:USERNAME" 'b' }

            (Get-NAVGitCredential -ContainerName 'cust' -Auth Windows).UserName | Should -Be "DOMAIN\$env:USERNAME"
            Should -Invoke Get-Credential -Times 1 -Exactly
        }

        It 'rejects another user for Windows auth' {
            Mock Get-Credential { New-TestCredential 'someoneelse' 'b' }
            { Get-NAVGitCredential -ContainerName 'cust' -Auth Windows } | Should -Throw '*requires the current Windows user*'
        }

        It 'throws instead of prompting with -NoPrompt' {
            Mock Get-Credential { throw 'should not prompt' }
            { Get-NAVGitCredential -ContainerName 'cust' -Auth NavUserPassword -NoPrompt } | Should -Throw '*No stored credential*'
        }
    }

    Describe 'Container state' {
        BeforeAll {
            $env:NAVGIT_DATA_PATH = Join-Path $TestDrive 'state-data'
            Mock Get-BcContainerServerConfiguration {
                [pscustomobject]@{
                    ContainerName = 'Customer-NAV201'; ServerInstance = 'NAV'; DatabaseServer = 'localhost'; DatabaseInstance = 'SQLEXPRESS'
                    DatabaseName = 'CRONUS'; ClientServicesPort = '7046'; ManagementServicesPort = '7045'
                    ClientServicesCredentialType = 'NavUserPassword'; EnableSymbolLoadingAtServerStartup = 'False'
                }
            }
            Mock Get-BcContainerNavVersion { '11.0.43274.0-no' }
            Mock Get-BcContainerArtifactUrl { 'https://bcartifacts.azureedge.net/onprem/11.0.43274.0/no' }
            Mock Get-NAVGitClientFolder { 'C:\ProgramData\BcContainerHelper\Extensions\Customer-NAV201\Program Files\110\RoleTailored Client' }
        }
        AfterAll {
            Remove-Item Env:\NAVGIT_DATA_PATH -ErrorAction SilentlyContinue
        }

        It 'saves, reads and removes the state' {
            $config = Get-TestConfig
            $state = Save-NAVGitContainerState -Config $config -BackupPath 'C:\b.bak'

            $state.containerName | Should -Be 'Customer-NAV201'
            $state.navVersion | Should -Be '11.0.43274.0'
            $state.artifactUrl | Should -Be 'https://bcartifacts.azureedge.net/onprem/11.0.43274.0/no'
            $state.hostDatabaseServer | Should -Be 'Customer-NAV201'
            $state.serverInstance | Should -Be 'NAV'
            $state.clientServicesPort | Should -Be 7046
            $state.managementServicesPort | Should -Be 7045
            $state.auth | Should -Be 'NavUserPassword'
            $state.enableSymbolLoading | Should -BeFalse
            $state.backupFile | Should -Be 'C:\b.bak'
            $state.repositoryPath | Should -Be $config.repositoryPath
            $state.clientFolder | Should -Match 'RoleTailored Client$'

            (Get-NAVGitContainerState -ContainerName 'Customer-NAV201').databaseName | Should -Be 'CRONUS'
            Remove-NAVGitContainerState -ContainerName 'Customer-NAV201'
            Get-NAVGitContainerState -ContainerName 'Customer-NAV201' | Should -BeNullOrEmpty
        }
    }

    Describe 'New-NAVGitContainer' {
        BeforeAll {
            Mock Assert-NAVGitAdministrator { }
            Mock Assert-NAVGitBcContainerHelper { }
            Mock Get-NAVGitCredential { $credential }
            Mock Resolve-NAVGitArtifactUrl { New-ArtifactInfo }
            Mock Save-NAVGitContainerState { @{ clientFolder = 'C:\x\RoleTailored Client' } }
            Mock Write-Host { }
        }
        BeforeEach {
            Mock New-BcContainer { }
            Mock Test-BcContainer { $false }
            $bak = Join-Path $TestDrive 'customer.bak'
            Set-Content -LiteralPath $bak -Value 'x'
            $repo = New-TestRepository -Config @{ database = @{ bakFile = $bak }; isolation = 'process' }
            $env:NAVGIT_SETTINGS_PATH = Join-Path $TestDrive 'no-settings.json'
        }
        AfterAll {
            Remove-Item Env:\NAVGIT_SETTINGS_PATH -ErrorAction SilentlyContinue
        }

        It 'calls New-BcContainer with the native bakFile and saves the state' {
            New-NAVGitContainer -Path $repo

            Should -Invoke New-BcContainer -Times 1 -Exactly -ParameterFilter {
                $bakFile -eq $bak -and $imageName -eq 'navgit' -and $isolation -eq 'process' -and $includeCSide -and
                $containerName -eq 'Customer-NAV201' -and -not $additionalParameters
            }
            Should -Invoke Save-NAVGitContainerState -Times 1 -Exactly -ParameterFilter { $BackupPath -eq $bak }
        }

        It 'does not create anything with -WhatIf' {
            New-NAVGitContainer -Path $repo -WhatIf

            Should -Invoke New-BcContainer -Times 0 -Exactly
            Should -Invoke Save-NAVGitContainerState -Times 0 -Exactly -Scope It
        }

        It 'replaces an existing container with -Force' {
            Mock Test-BcContainer { $true }
            New-NAVGitContainer -Path $repo -Force
            Should -Invoke New-BcContainer -Times 1 -Exactly
        }

        It 'requires elevation' {
            Mock Assert-NAVGitAdministrator { throw 'must run in an elevated PowerShell session' }
            { New-NAVGitContainer -Path $repo } | Should -Throw '*elevated*'
            Should -Invoke New-BcContainer -Times 0 -Exactly
        }
    }

    Describe 'Remove-NAVGitContainer' {
        BeforeAll {
            Mock Assert-NAVGitAdministrator { }
            Mock Assert-NAVGitBcContainerHelper { }
            Mock Remove-NAVGitContainerState { }
            $env:NAVGIT_SETTINGS_PATH = Join-Path $TestDrive 'no-settings.json'
        }
        AfterAll {
            Remove-Item Env:\NAVGIT_SETTINGS_PATH -ErrorAction SilentlyContinue
        }

        It 'removes the container and its state with -Force' {
            Mock Test-BcContainer { $true }
            Mock Remove-BcContainer { }
            $repo = New-TestRepository

            Remove-NAVGitContainer -Path $repo -Force

            Should -Invoke Remove-BcContainer -Times 1 -Exactly -ParameterFilter { $containerName -eq 'Customer-NAV201' }
            Should -Invoke Remove-NAVGitContainerState -Times 1 -Exactly -Scope It
        }

        It 'still clears the state when the container is already gone' {
            Mock Test-BcContainer { $false }
            Mock Remove-BcContainer { }
            $repo = New-TestRepository

            Remove-NAVGitContainer -Path $repo -Force -WarningAction SilentlyContinue

            Should -Invoke Remove-BcContainer -Times 0 -Exactly -Scope It
            Should -Invoke Remove-NAVGitContainerState -Times 1 -Exactly -Scope It
        }
    }
}
