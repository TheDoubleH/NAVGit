BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1') -Force
}

InModuleScope NAVGit {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    }

    Describe 'ConvertTo-NAVGitHashtable' {
        It 'converts nested objects and keeps arrays (including empty and single item)' {
            $json = '{ "a": { "b": 1 }, "empty": [], "one": ["x"], "many": [ { "c": true }, { "c": false } ] }' | ConvertFrom-Json
            $result = ConvertTo-NAVGitHashtable $json

            $result | Should -BeOfType [hashtable]
            $result.a | Should -BeOfType [hashtable]
            $result.a.b | Should -Be 1
            , $result.empty | Should -BeOfType [object[]]
            $result.empty.Count | Should -Be 0
            , $result.one | Should -BeOfType [object[]]
            $result.one.Count | Should -Be 1
            $result.many[1] | Should -BeOfType [hashtable]
            $result.many[1].c | Should -BeFalse
        }
    }

    Describe 'Merge-NAVGitHashtable' {
        It 'merges nested hashtables and lets the override win' {
            $merged = Merge-NAVGitHashtable -Base @{ a = 1; n = @{ x = 1; y = 2 }; list = @(1, 2) } -Override @{ n = @{ y = 3 }; list = @(9); b = 2 }
            $merged.a | Should -Be 1
            $merged.b | Should -Be 2
            $merged.n.x | Should -Be 1
            $merged.n.y | Should -Be 3
            $merged.list | Should -Be @(9)
        }
    }

    Describe 'Find-NAVGitConfigFile' {
        It 'finds navgit.json in a parent folder' {
            $repo = New-TestRepository
            $deep = Join-Path $repo 'Objects\Sub'
            New-Item -ItemType Directory -Path $deep -Force | Out-Null

            Find-NAVGitConfigFile -Path $deep | Should -Be (Join-Path $repo 'navgit.json')
        }

        It 'accepts a file path inside the repository' {
            $repo = New-TestRepository
            $file = Join-Path $repo 'TAB18.TXT'
            Set-Content -LiteralPath $file -Value 'x'

            Find-NAVGitConfigFile -Path $file | Should -Be (Join-Path $repo 'navgit.json')
        }

        It 'returns null when there is no navgit.json' {
            $folder = Join-Path $TestDrive 'nothing-here'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            Find-NAVGitConfigFile -Path $folder | Should -BeNullOrEmpty
        }
    }

    Describe 'Get-NAVGitUserSettings' {
        It 'returns defaults when the file does not exist' {
            $settings = Get-NAVGitUserSettings -Path (Join-Path $TestDrive 'missing.json')
            $settings.backupFolder | Should -Be ''
            $settings.defaultIsolation | Should -Be ''
            $settings.settingsPath | Should -Be (Join-Path $TestDrive 'missing.json')
        }

        It 'reads values from the file and warns about unknown keys' {
            $path = Join-Path $TestDrive 'settings.json'
            Set-Content -LiteralPath $path -Value '{ "backupFolder": "D:\\Backups", "defaultIsolation": "process", "typo": 1 }'

            $settings = Get-NAVGitUserSettings -Path $path -WarningVariable warnings -WarningAction SilentlyContinue
            $settings.backupFolder | Should -Be 'D:\Backups'
            $settings.defaultIsolation | Should -Be 'process'
            $warnings | Should -Match "unknown setting 'typo'"
        }

        It 'rejects an invalid defaultIsolation' {
            $path = Join-Path $TestDrive 'bad-settings.json'
            Set-Content -LiteralPath $path -Value '{ "defaultIsolation": "vm" }'
            { Get-NAVGitUserSettings -Path $path } | Should -Throw '*defaultIsolation*'
        }

        It 'uses NAVGIT_SETTINGS_PATH when set' {
            $env:NAVGIT_SETTINGS_PATH = 'X:\custom\settings.json'
            try { Get-NAVGitUserSettingsPath | Should -Be 'X:\custom\settings.json' }
            finally { Remove-Item Env:\NAVGIT_SETTINGS_PATH }
        }
    }

    Describe 'Get-NAVGitConfig' {
        It 'applies defaults and resolves context paths' {
            $repo = New-TestRepository
            $config = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)

            $config.projectName | Should -Be 'Customer_NAV2018'
            $config.containerName | Should -Be 'Customer-NAV201'
            $config.imageName | Should -Be 'navgit'
            $config.updateHosts | Should -BeTrue
            $config.paths.objects | Should -Be 'Objects'
            $config.import.deleteMissing | Should -Be 'warn'
            $config.repositoryPath | Should -Be $repo
            $config.objectsPath | Should -Be (Join-Path $repo 'Objects')
            $config.testsPath | Should -Be (Join-Path $repo 'Tests')
            $config.ContainsKey('$schema') | Should -BeFalse
        }

        It 'lets navgit.json override nested defaults without losing siblings' {
            $repo = New-TestRepository -Config @{ paths = @{ tests = 'TestObjects' } }
            $config = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)

            $config.paths.tests | Should -Be 'TestObjects'
            $config.paths.objects | Should -Be 'Objects'
        }

        It 'truncates the derived container name to 15 characters' {
            $repo = New-TestRepository -Config @{ projectName = 'A_Very_Long_Project_Name' }
            (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)).containerName | Should -Be 'A-Very-Long-Pro'
        }

        Context 'isolation precedence' {
            It 'uses navgit.json first' {
                $repo = New-TestRepository -Config @{ isolation = 'process' }
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ defaultIsolation = 'hyperv' })).isolation | Should -Be 'process'
            }

            It 'keeps an explicit empty isolation from navgit.json' {
                $repo = New-TestRepository -Config @{ isolation = '' }
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ defaultIsolation = 'hyperv' })).isolation | Should -Be ''
            }

            It 'falls back to the user defaultIsolation' {
                $repo = New-TestRepository
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ defaultIsolation = 'hyperv' })).isolation | Should -Be 'hyperv'
            }

            It 'defaults to empty (BcContainerHelper decides)' {
                $repo = New-TestRepository
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)).isolation | Should -Be ''
            }

            It 'rejects an invalid isolation' {
                $repo = New-TestRepository -Config @{ isolation = 'vm' }
                { Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings) } | Should -Throw "*'isolation' must be one of*"
            }
        }

        Context 'auth default' {
            It 'uses the user defaultAuth' {
                Get-NAVGitDefaultAuth -UserSettings (New-TestUserSettings @{ defaultAuth = 'Windows' }) -UserDomain 'AzureAD' | Should -Be 'Windows'
            }

            It 'uses NavUserPassword for Azure AD accounts' {
                Get-NAVGitDefaultAuth -UserSettings (New-TestUserSettings) -UserDomain 'AzureAD' | Should -Be 'NavUserPassword'
            }

            It 'uses Windows otherwise' {
                Get-NAVGitDefaultAuth -UserSettings (New-TestUserSettings) -UserDomain 'CONTOSO' | Should -Be 'Windows'
            }
        }

        It 'throws when no navgit.json exists' {
            $folder = Join-Path $TestDrive 'no-config'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            { Get-NAVGitConfig -Path $folder -UserSettings (New-TestUserSettings) } | Should -Throw '*No navgit.json found*'
        }

        It 'throws a clear error for invalid JSON' {
            $repo = New-TestRepository -RawJson '{ "projectName": "x", '
            { Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings) } | Should -Throw '*is not valid JSON*'
        }

        It 'warns about unknown keys' {
            $repo = New-TestRepository -Config @{ dockerImage = 'old'; paths = @{ objects = 'Objects'; test = 'x' } }
            $null = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings) -WarningVariable warnings -WarningAction SilentlyContinue
            $allWarnings = $warnings -join [Environment]::NewLine
            $allWarnings | Should -Match "unknown setting 'dockerImage'"
            $allWarnings | Should -Match "unknown setting 'paths.test'"
        }
    }

    Describe 'Assert-NAVGitConfig' {
        BeforeAll {
            function Get-ValidConfig {
                $config = Merge-NAVGitHashtable -Base (Get-NAVGitDefaultConfig -UserSettings (New-TestUserSettings)) -Override @{
                    projectName   = 'Cust'
                    containerName = 'Cust'
                    artifact      = @{ nav = '2018' }
                }
                return $config
            }
        }

        It 'accepts a valid configuration' {
            { Assert-NAVGitConfig -Config (Get-ValidConfig) } | Should -Not -Throw
        }

        It 'reports all problems at once' {
            $config = Get-ValidConfig
            $config.projectName = ''
            $config.auth = 'AAD'
            $config.updateHosts = 'yes'
            $thrown = { Assert-NAVGitConfig -Config $config } | Should -Throw -PassThru
            $thrown.Exception.Message | Should -Match "'projectName' is required"
            $thrown.Exception.Message | Should -Match "'auth' must be one of"
            $thrown.Exception.Message | Should -Match "'updateHosts' must be true or false"
        }

        It 'rejects <Case>' -ForEach @(
            @{ Case = 'no artifact form'; Artifact = @{ country = 'no' }; Message = "exactly one of 'url', 'nav' or 'version'*found: none" }
            @{ Case = 'two artifact forms'; Artifact = @{ nav = '2018'; version = '11.0' }; Message = "exactly one of*found: nav, version" }
            @{ Case = 'an http artifact url'; Artifact = @{ url = 'http://x/onprem/11.0.1.0/w1' }; Message = 'must be an https:// URL' }
            @{ Case = 'url with country'; Artifact = @{ url = 'https://x/onprem/11.0.1.0/w1'; country = 'no' }; Message = "'artifact.country' cannot be combined" }
            @{ Case = 'NAV 2015'; Artifact = @{ nav = '2015' }; Message = "'artifact.nav' must be one of" }
            @{ Case = 'an invalid cu'; Artifact = @{ nav = '2018'; cu = 'update5' }; Message = "'artifact.cu'*must be 'rtm' or 'cu<number>'" }
            @{ Case = 'version 8 (NAV 2015)'; Artifact = @{ version = '8.0' }; Message = 'must be between 9 (NAV 2016) and 14' }
            @{ Case = 'version 15 (AL only)'; Artifact = @{ version = '15' }; Message = 'must be between 9 (NAV 2016) and 14' }
            @{ Case = 'Sandbox type'; Artifact = @{ version = '14'; type = 'Sandbox' }; Message = "'artifact.type' must be one of 'OnPrem'" }
            @{ Case = 'Closest with a partial version'; Artifact = @{ version = '14.0'; select = 'Closest' }; Message = 'requires a full four-part' }
            @{ Case = 'cu with version'; Artifact = @{ version = '14.0'; cu = 'cu1' }; Message = "'artifact.cu' can only be used with 'artifact.nav'" }
        ) {
            $config = Get-ValidConfig
            $config.artifact = $Artifact
            { Assert-NAVGitConfig -Config $config } | Should -Throw "*$Message*"
        }

        It 'accepts the version form for BC14' {
            $config = Get-ValidConfig
            $config.artifact = @{ type = 'OnPrem'; version = '14.0.29537.0'; country = 'w1'; select = 'Closest' }
            { Assert-NAVGitConfig -Config $config } | Should -Not -Throw
        }

        It 'rejects bakFile together with useDemo' {
            $config = Get-ValidConfig
            $config.database = @{ bakFile = 'x.bak'; useDemo = $true }
            { Assert-NAVGitConfig -Config $config } | Should -Throw "*cannot both be set*"
        }

        It 'rejects an invalid container name' {
            $config = Get-ValidConfig
            $config.containerName = 'this-name-is-too-long'
            { Assert-NAVGitConfig -Config $config } | Should -Throw "*'containerName'*1-15 characters*"
        }

        It 'rejects an invalid memoryLimit' {
            $config = Get-ValidConfig
            $config.memoryLimit = '8GB'
            { Assert-NAVGitConfig -Config $config } | Should -Throw "*'memoryLimit'*"
        }

        It 'rejects identical or rooted object paths' {
            $config = Get-ValidConfig
            $config.paths = @{ objects = 'Objects'; tests = 'Objects\' }
            { Assert-NAVGitConfig -Config $config } | Should -Throw '*must be different folders*'

            $config.paths = @{ objects = 'C:\Objects'; tests = 'Tests' }
            { Assert-NAVGitConfig -Config $config } | Should -Throw "*'paths.objects' must be relative*"
        }

        It 'rejects an invalid versionListPattern regex' {
            $config = Get-ValidConfig
            $config.testObjects = @{ versionListPattern = '(Test'; includeTestCodeunits = $true }
            { Assert-NAVGitConfig -Config $config } | Should -Throw '*not a valid regular expression*'
        }

        It 'rejects a non-array additionalParameters' {
            $config = Get-ValidConfig
            $config.additionalParameters = '--dns 8.8.8.8'
            { Assert-NAVGitConfig -Config $config } | Should -Throw "*'additionalParameters' must be an array of strings*"
        }
    }

    Describe 'Get-NAVGitContainerName' {
        It 'turns <ProjectName> into <Expected>' -ForEach @(
            @{ ProjectName = 'Cust_NAV2018'; Expected = 'Cust-NAV2018' }
            @{ ProjectName = 'Customer_NAV2018'; Expected = 'Customer-NAV201' }
            @{ ProjectName = 'abc def.ghi'; Expected = 'abc-def-ghi' }
            @{ ProjectName = '_lead'; Expected = 'lead' }
            @{ ProjectName = 'Fourteen_chars_'; Expected = 'Fourteen-chars' }
        ) {
            Get-NAVGitContainerName -ProjectName $ProjectName | Should -Be $Expected
        }
    }
}
