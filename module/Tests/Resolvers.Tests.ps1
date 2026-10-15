BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NavGit\NavGit.psd1') -Force
}

InModuleScope NavGit {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

        function Get-TestConfig {
            param([hashtable] $Override = @{}, [hashtable] $UserSettings = (New-TestUserSettings))
            $repo = New-TestRepository -Config $Override
            return Get-NavGitConfig -Path $repo -UserSettings $UserSettings
        }

        $nav2018Url = 'https://bcartifacts.azureedge.net/onprem/11.0.48560.0/no'
        $artifact2018 = [pscustomobject]@{ Url = $nav2018Url; Version = [version]'11.0.48560.0'; Country = 'no'; NavRelease = '2018' }
    }

    Describe 'ConvertFrom-NavGitArtifactUrl' {
        It 'parses <Url>' -ForEach @(
            @{ Url = 'https://bcartifacts.azureedge.net/onprem/11.0.48560.0/no'; Version = '11.0.48560.0'; Country = 'no' }
            @{ Url = 'https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/onprem/14.0.29537.0/W1/'; Version = '14.0.29537.0'; Country = 'w1' }
            @{ Url = 'https://x.blob.core.windows.net/onprem/9.0.53060.0/dk?sv=2020&sig=abc'; Version = '9.0.53060.0'; Country = 'dk' }
        ) {
            $info = ConvertFrom-NavGitArtifactUrl -Url $Url
            $info.Version | Should -Be ([version]$Version)
            $info.Country | Should -Be $Country
        }

        It 'rejects sandbox and unknown URLs' {
            { ConvertFrom-NavGitArtifactUrl -Url 'https://x/sandbox/14.0.1.0/w1' } | Should -Throw '*sandbox*'
            { ConvertFrom-NavGitArtifactUrl -Url 'https://x/something/else' } | Should -Throw '*not a recognised artifact URL*'
        }
    }

    Describe 'Get-NavGitNavRelease' {
        It 'maps <Version> to <Release>' -ForEach @(
            @{ Version = '9.0.1.0'; Release = '2016' }
            @{ Version = '10.0.1.0'; Release = '2017' }
            @{ Version = '11.0.1.0'; Release = '2018' }
            @{ Version = '13.0.1.0'; Release = '2019' }
            @{ Version = '14.0.1.0'; Release = 'BC14' }
        ) {
            Get-NavGitNavRelease -Version $Version | Should -Be $Release
        }

        It 'uses the navRelease override' {
            Get-NavGitNavRelease -Version '14.0.1.0' -Override '2019R2' | Should -Be '2019R2'
        }
    }

    Describe 'Resolve-NavGitArtifactUrl' {
        It 'uses an explicit url without calling BcContainerHelper' {
            Mock Get-NavArtifactUrl { throw 'should not be called' }
            Mock Get-BcArtifactUrl { throw 'should not be called' }
            $config = Get-TestConfig @{ artifact = @{ url = $nav2018Url } }

            $result = Resolve-NavGitArtifactUrl -Config $config

            $result.Url | Should -Be $nav2018Url
            $result.Version | Should -Be ([version]'11.0.48560.0')
            $result.Country | Should -Be 'no'
            $result.NavRelease | Should -Be '2018'
        }

        It 'resolves the nav form with Get-NavArtifactUrl' {
            Mock Get-NavArtifactUrl { $nav2018Url }
            $config = Get-TestConfig @{ artifact = @{ nav = '2018'; cu = 'CU30'; country = 'NO' } }

            (Resolve-NavGitArtifactUrl -Config $config).Url | Should -Be $nav2018Url

            Should -Invoke Get-NavArtifactUrl -Times 1 -Exactly -ParameterFilter {
                $nav -eq '2018' -and $cu -eq 'cu30' -and $country -eq 'no' -and $select -eq 'Latest'
            }
        }

        It 'resolves the version form with Get-BcArtifactUrl -type OnPrem and defaults country to w1' {
            Mock Get-BcArtifactUrl { 'https://bcartifacts.azureedge.net/onprem/14.0.29537.0/w1' }
            $config = Get-TestConfig @{ artifact = @{ version = '14.0' } }

            $result = Resolve-NavGitArtifactUrl -Config $config

            $result.NavRelease | Should -Be 'BC14'
            Should -Invoke Get-BcArtifactUrl -Times 1 -Exactly -ParameterFilter {
                $type -eq 'OnPrem' -and $version -eq '14.0' -and $country -eq 'w1' -and $select -eq 'Latest'
            }
        }

        It 'throws when no artifact is found' {
            Mock Get-NavArtifactUrl { $null }
            $config = Get-TestConfig @{ artifact = @{ nav = '2016'; cu = 'cu99' } }

            { Resolve-NavGitArtifactUrl -Config $config } | Should -Throw '*No artifact found for NAV 2016 cu99*'
        }

        It 'rejects an explicit url outside the supported versions' {
            $config = Get-TestConfig @{ artifact = @{ url = 'https://bcartifacts.azureedge.net/onprem/8.0.48067.0/w1' } }
            { Resolve-NavGitArtifactUrl -Config $config } | Should -Throw '*supports NAV 2016 (9.0) to BC14*'
        }
    }

    Describe 'Resolve-NavGitBackupFile' {
        It 'returns Demo when useDemo is set' {
            $config = Get-TestConfig @{ database = @{ useDemo = $true } }
            $result = Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018
            $result.Source | Should -Be 'Demo'
            $result.Path | Should -BeNullOrEmpty
        }

        It 'passes a URL through' {
            $config = Get-TestConfig @{ database = @{ bakFile = 'https://storage/backups/cust.bak' } }
            $result = Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018
            $result.Source | Should -Be 'Url'
            $result.Path | Should -Be 'https://storage/backups/cust.bak'
        }

        It 'finds an absolute bakFile' {
            $bak = Join-Path $TestDrive 'abs.bak'
            Set-Content -LiteralPath $bak -Value 'x'
            $config = Get-TestConfig @{ database = @{ bakFile = $bak } }

            $result = Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018
            $result.Source | Should -Be 'Config'
            $result.Path | Should -Be $bak
        }

        It 'finds a relative bakFile in the repository before the backupFolder' {
            $backupFolder = Join-Path $TestDrive 'bf-rel'
            New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $backupFolder 'db.bak') -Value 'folder'
            $config = Get-TestConfig @{ database = @{ bakFile = 'db.bak' } } (New-TestUserSettings @{ backupFolder = $backupFolder })

            (Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018).Path | Should -Be (Join-Path $backupFolder 'db.bak')

            Set-Content -LiteralPath (Join-Path $config.repositoryPath 'db.bak') -Value 'repo'
            (Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018).Path | Should -Be (Join-Path $config.repositoryPath 'db.bak')
        }

        It 'throws when the configured bakFile does not exist' {
            $config = Get-TestConfig @{ database = @{ bakFile = 'missing.bak' } }
            { Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018 } | Should -Throw "*'missing.bak' from database.bakFile was not found*"
        }

        Context 'backupFolder search' {
            BeforeEach {
                $backupFolder = Join-Path $TestDrive ("bf-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
                New-Item -ItemType Directory -Path (Join-Path $backupFolder '2018\11.0.48560.0') -Force | Out-Null
                $settings = New-TestUserSettings @{ backupFolder = $backupFolder }
            }

            It 'prefers {release}-{projectName}.bak' {
                Set-Content -LiteralPath (Join-Path $backupFolder '2018-Customer_NAV2018.bak') -Value 'x'
                Set-Content -LiteralPath (Join-Path $backupFolder '2018\Customer_NAV2018.bak') -Value 'x'
                $config = Get-TestConfig -UserSettings $settings

                $result = Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018
                $result.Source | Should -Be 'Search'
                $result.Path | Should -Be (Join-Path $backupFolder '2018-Customer_NAV2018.bak')
            }

            It 'then tries {release}\{version}\{projectName}.bak before {release}\{projectName}.bak' {
                Set-Content -LiteralPath (Join-Path $backupFolder '2018\11.0.48560.0\Customer_NAV2018.bak') -Value 'x'
                Set-Content -LiteralPath (Join-Path $backupFolder '2018\Customer_NAV2018.bak') -Value 'x'
                $config = Get-TestConfig -UserSettings $settings

                (Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018).Path |
                    Should -Be (Join-Path $backupFolder '2018\11.0.48560.0\Customer_NAV2018.bak')
            }

            It 'falls back to database.searchNames' {
                Set-Content -LiteralPath (Join-Path $backupFolder '2018\BaseSolution.bak') -Value 'x'
                $config = Get-TestConfig @{ database = @{ searchNames = @('BaseSolution') } } $settings

                (Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018).Path | Should -Be (Join-Path $backupFolder '2018\BaseSolution.bak')
            }

            It 'throws and lists what it tried when nothing matches' {
                $config = Get-TestConfig -UserSettings $settings
                { Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018 } | Should -Throw '*No backup found*2018-Customer_NAV2018.bak*database.useDemo*'
            }
        }

        It 'throws when neither bakFile nor backupFolder is configured (never silently uses Cronus)' {
            $config = Get-TestConfig
            { Resolve-NavGitBackupFile -Config $config -ArtifactInfo $artifact2018 } | Should -Throw '*no backupFolder in the user settings*'
        }
    }

    Describe 'Resolve-NavGitLicenseFile' {
        It 'returns null with a warning when no license is configured' {
            $config = Get-TestConfig
            $result = Resolve-NavGitLicenseFile -Config $config -ArtifactInfo $artifact2018 -WarningVariable warnings -WarningAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $warnings | Should -Match 'demo license'
        }

        It 'replaces {major} and finds the file in the licenseFolder' {
            $licenseFolder = Join-Path $TestDrive 'licenses'
            New-Item -ItemType Directory -Path $licenseFolder -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $licenseFolder 'Customer11.flf') -Value 'x'
            $config = Get-TestConfig @{ licenseFile = 'Customer{major}.flf' } (New-TestUserSettings @{ licenseFolder = $licenseFolder })

            Resolve-NavGitLicenseFile -Config $config -ArtifactInfo $artifact2018 | Should -Be (Join-Path $licenseFolder 'Customer11.flf')
        }

        It 'passes a URL through' {
            $config = Get-TestConfig @{ licenseFile = 'https://storage/license.flf' }
            Resolve-NavGitLicenseFile -Config $config -ArtifactInfo $artifact2018 | Should -Be 'https://storage/license.flf'
        }

        It 'throws when the license file does not exist' {
            $config = Get-TestConfig @{ licenseFile = 'nope.flf' }
            { Resolve-NavGitLicenseFile -Config $config -ArtifactInfo $artifact2018 } | Should -Throw "*License file 'nope.flf' was not found*"
        }
    }
}
