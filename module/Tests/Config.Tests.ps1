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
            $settings.isolation | Should -Be ''
            $settings.showBcContainerCommand | Should -BeNullOrEmpty
            $settings.artifact | Should -BeNullOrEmpty
            $settings.settingsPath | Should -Be (Join-Path $TestDrive 'missing.json')
        }

        It 'reads values from the file and warns about unknown keys' {
            $path = Join-Path $TestDrive 'settings.json'
            Set-Content -LiteralPath $path -Value '{ "backupFolder": "D:\\Backups", "isolation": "process", "typo": 1 }'

            $settings = Get-NAVGitUserSettings -Path $path -WarningVariable warnings -WarningAction SilentlyContinue
            $settings.backupFolder | Should -Be 'D:\Backups'
            $settings.isolation | Should -Be 'process'
            $warnings | Should -Match "unknown setting 'typo'"
        }

        It 'rejects an invalid isolation' {
            $path = Join-Path $TestDrive 'bad-settings.json'
            Set-Content -LiteralPath $path -Value '{ "isolation": "vm" }'
            { Get-NAVGitUserSettings -Path $path } | Should -Throw '*isolation must be*'
        }

        It 'reads defaultAuth and defaultIsolation as auth and isolation, with a warning' {
            $path = Join-Path $TestDrive 'old-settings.json'
            Set-Content -LiteralPath $path -Value '{ "defaultAuth": "NavUserPassword", "defaultIsolation": "hyperv" }'
            $settings = Get-NAVGitUserSettings -Path $path -WarningVariable warnings -WarningAction SilentlyContinue
            $settings.auth | Should -Be 'NavUserPassword'
            $settings.isolation | Should -Be 'hyperv'
            ($warnings -join [Environment]::NewLine) | Should -Match "'defaultAuth' is now called 'auth'"
        }

        It 'prefers auth over the old defaultAuth' {
            $path = Join-Path $TestDrive 'both-settings.json'
            Set-Content -LiteralPath $path -Value '{ "defaultAuth": "Windows", "auth": "NavUserPassword" }'
            $settings = Get-NAVGitUserSettings -Path $path -WarningVariable warnings -WarningAction SilentlyContinue
            $settings.auth | Should -Be 'NavUserPassword'
            ($warnings -join [Environment]::NewLine) | Should -Match "'defaultAuth' is ignored because 'auth' is set"
        }

        It 'reads artifact.url and rejects other artifact forms' {
            $path = Join-Path $TestDrive 'artifact-settings.json'
            Set-Content -LiteralPath $path -Value '{ "artifact": { "url": "https://cdn/onprem/9.0.50357.0/na" } }'
            (Get-NAVGitUserSettings -Path $path).artifact.url | Should -Be 'https://cdn/onprem/9.0.50357.0/na'

            Set-Content -LiteralPath $path -Value '{ "artifact": { "nav": "2016" } }'
            { Get-NAVGitUserSettings -Path $path } | Should -Throw '*artifact must be*'
            Set-Content -LiteralPath $path -Value '{ "artifact": "https://cdn/onprem/9.0.50357.0/na" }'
            { Get-NAVGitUserSettings -Path $path } | Should -Throw '*artifact must be*'
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
            $config.import.deleteMissing | Should -Be 'skip'
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
            It 'lets the user setting win over navgit.json' {
                $repo = New-TestRepository -Config @{ isolation = 'process' }
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ isolation = 'hyperv' })).isolation | Should -Be 'hyperv'

                $repo = New-TestRepository -Config @{ isolation = '' }
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ isolation = 'hyperv' })).isolation | Should -Be 'hyperv'
            }

            It 'uses navgit.json when the user setting is empty' {
                $repo = New-TestRepository -Config @{ isolation = 'process' }
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)).isolation | Should -Be 'process'
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

        Context 'showBcContainerCommand' {
            It 'defaults to false' {
                (Get-NAVGitConfig -Path (New-TestRepository) -UserSettings (New-TestUserSettings)).showBcContainerCommand | Should -BeFalse
            }

            It 'uses the user setting when navgit.json has none' {
                (Get-NAVGitConfig -Path (New-TestRepository) -UserSettings (New-TestUserSettings @{ showBcContainerCommand = $true })).showBcContainerCommand | Should -BeTrue
            }

            It 'lets the user setting win over navgit.json, also when it is false' {
                $repo = New-TestRepository -Config @{ showBcContainerCommand = $false }
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ showBcContainerCommand = $true })).showBcContainerCommand | Should -BeTrue

                $repo = New-TestRepository -Config @{ showBcContainerCommand = $true }
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ showBcContainerCommand = $false })).showBcContainerCommand | Should -BeFalse
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)).showBcContainerCommand | Should -BeTrue
            }

            It 'rejects non-boolean values' {
                $repo = New-TestRepository -Config @{ showBcContainerCommand = 'yes' }
                { Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings) } | Should -Throw "*'showBcContainerCommand' must be true or false*"
            }

            It 'is read as a boolean from the user settings file' {
                $path = Join-Path $TestDrive 'flag-settings.json'
                Set-Content -LiteralPath $path -Value '{ "showBcContainerCommand": true }'
                $settings = Get-NAVGitUserSettings -Path $path
                $settings.showBcContainerCommand | Should -BeOfType [bool]
                $settings.showBcContainerCommand | Should -BeTrue

                Set-Content -LiteralPath $path -Value '{ "showBcContainerCommand": "yes" }'
                { Get-NAVGitUserSettings -Path $path } | Should -Throw '*showBcContainerCommand must be true or false*'
            }
        }

        Context 'import.deleteMissing' {
            It 'defaults to skip' {
                (Get-NAVGitConfig -Path (New-TestRepository) -UserSettings (New-TestUserSettings)).import.deleteMissing | Should -Be 'skip'
            }

            It 'uses navgit.json' {
                $repo = New-TestRepository -Config @{ import = @{ deleteMissing = 'warn' } }
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)).import.deleteMissing | Should -Be 'warn'
            }

            It 'is overridden by the user setting, also when navgit.json sets it' {
                $repo = New-TestRepository -Config @{ import = @{ deleteMissing = 'mark' } }
                $config = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ deleteMissing = 'skip' })
                $config.import.deleteMissing | Should -Be 'skip'

                $config = Get-NAVGitConfig -Path (New-TestRepository) -UserSettings (New-TestUserSettings @{ deleteMissing = 'warn' })
                $config.import.deleteMissing | Should -Be 'warn'
            }

            It 'rejects unknown values in navgit.json and in the user settings' {
                $repo = New-TestRepository -Config @{ import = @{ deleteMissing = 'delete' } }
                { Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings) } | Should -Throw "*'import.deleteMissing' must be one of 'skip', 'warn', 'mark'*"

                $path = Join-Path $TestDrive 'delete-settings.json'
                Set-Content -LiteralPath $path -Value '{ "deleteMissing": "delete" }'
                { Get-NAVGitUserSettings -Path $path } | Should -Throw '*deleteMissing must be*'
            }
        }

        Context 'auth' {
            It 'lets the user setting win over navgit.json' {
                $repo = New-TestRepository -Config @{ auth = 'Windows' }
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ auth = 'NavUserPassword' })).auth | Should -Be 'NavUserPassword'
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)).auth | Should -Be 'Windows'
            }

            It 'defaults to NavUserPassword for Azure AD accounts' {
                Get-NAVGitDefaultAuth -UserDomain 'AzureAD' | Should -Be 'NavUserPassword'
            }

            It 'defaults to Windows otherwise' {
                Get-NAVGitDefaultAuth -UserDomain 'CONTOSO' | Should -Be 'Windows'
            }
        }

        Context 'artifact' {
            It 'replaces the navgit.json artifact with the user artifact.url' {
                $url = 'https://cdn/onprem/9.0.50357.0/na'
                $config = Get-NAVGitConfig -Path (New-TestRepository) -UserSettings (New-TestUserSettings @{ artifact = @{ url = $url } })
                $config.artifact.url | Should -Be $url
                @($config.artifact.Keys) | Should -Be @('url')
            }

            It 'uses navgit.json when the user setting is not set' {
                $repo = New-TestRepository -Config @{ artifact = @{ nav = '2016'; cu = 'cu32'; country = 'na' } }
                (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)).artifact.nav | Should -Be '2016'
            }

            It 'still validates the navgit.json artifact' {
                $repo = New-TestRepository -Config @{ artifact = @{ nav = '2099' } }
                { Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ artifact = @{ url = 'https://cdn/onprem/9.0.50357.0/na' } }) } |
                    Should -Throw "*'artifact.nav'*"
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
                $config = Merge-NAVGitHashtable -Base (Get-NAVGitDefaultConfig) -Override @{
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

    Describe 'Resolve-NAVGitContainerName' {
        BeforeAll {
            $common = @{ ProjectName = 'Customer_NAV2018'; RepositoryPath = $TestDrive }
            $branchRule = @{ branch = @{ length = 8 } }
        }

        It 'derives the name from projectName when nothing is set' {
            Resolve-NAVGitContainerName @common -UserValue '' | Should -Be 'Customer-NAV201'
        }

        It 'accepts a plain name and the fixed form' {
            Resolve-NAVGitContainerName @common -RepoValue 'Contoso' | Should -Be 'Contoso'
            Resolve-NAVGitContainerName @common -RepoValue @{ fixed = 'Contoso' } | Should -Be 'Contoso'
        }

        It 'lets the user setting win over navgit.json' {
            Resolve-NAVGitContainerName @common -UserValue @{ fixed = 'Mine' } -RepoValue 'Contoso' | Should -Be 'Mine'
        }

        It 'uses the first <length> characters of a ticket branch' {
            Resolve-NAVGitContainerName @common -RepoValue $branchRule -BranchName 'MIS-1234-fix-posting' | Should -Be 'MIS-1234'
        }

        It 'uses the whole branch when it is shorter than length' {
            Resolve-NAVGitContainerName @common -RepoValue @{ branch = @{ length = 15 } } -BranchName 'MIS-1234' | Should -Be 'MIS-1234'
        }

        It 'falls back to navgit.json on a branch without a ticket key' {
            Resolve-NAVGitContainerName @common -UserValue $branchRule -RepoValue 'Contoso' -BranchName 'main' | Should -Be 'Contoso'
        }

        It 'falls back to the derived name on <BranchName>' -ForEach @(
            @{ BranchName = 'main' }
            @{ BranchName = 'feature-12-x' }
            @{ BranchName = '' }
        ) {
            Resolve-NAVGitContainerName @common -RepoValue $branchRule -BranchName $BranchName -WarningAction SilentlyContinue |
                Should -Be 'Customer-NAV201'
        }

        It 'with prefix <Prefix>, turns <BranchName> into <Expected>' -ForEach @(
            @{ Prefix = 'MIS'; BranchName = 'MIS-1234-fix-posting'; Expected = 'MIS-1234' }
            @{ Prefix = 'MIS-'; BranchName = 'MIS-1234-fix-posting'; Expected = 'MIS-1234' }
            @{ Prefix = 'MIS'; BranchName = 'mis-1234-fix-posting'; Expected = 'mis-1234' }
            @{ Prefix = 'MIS'; BranchName = 'MISC-1234-cleanup'; Expected = 'Customer-NAV201' }
            @{ Prefix = 'MIS'; BranchName = 'MIS-cleanup'; Expected = 'Customer-NAV201' }
            @{ Prefix = 'MIS'; BranchName = 'OPS-77-x'; Expected = 'Customer-NAV201' }
            @{ Prefix = ''; BranchName = 'OPS-77-x'; Expected = 'OPS-77-x' }
        ) {
            Resolve-NAVGitContainerName @common -RepoValue @{ branch = @{ prefix = $Prefix; length = 8 } } -BranchName $BranchName |
                Should -Be $Expected
        }

        It 'reads the branch with git when no branch name is given' {
            Mock Get-NAVGitBranchName { 'MIS-0042-text' }
            Resolve-NAVGitContainerName @common -RepoValue $branchRule | Should -Be 'MIS-0042'
            Should -Invoke Get-NAVGitBranchName -Times 1 -Exactly
        }

        It 'does not read the branch for a fixed name' {
            Mock Get-NAVGitBranchName { 'MIS-0042-text' }
            Resolve-NAVGitContainerName @common -RepoValue 'Contoso' | Should -Be 'Contoso'
            Should -Invoke Get-NAVGitBranchName -Times 0 -Exactly
        }

        It 'rejects <Name>' -ForEach @(
            @{ Name = 'an invalid fixed name'; Value = @{ fixed = 'this-name-is-too-long' }; Message = "*'containerName.fixed'*1-15 characters*" }
            @{ Name = 'both forms'; Value = @{ fixed = 'A'; branch = @{ length = 8 } }; Message = '*exactly one of*' }
            @{ Name = 'no form'; Value = @{}; Message = '*exactly one of*' }
            @{ Name = 'a length of 0'; Value = @{ branch = @{ length = 0 } }; Message = "*'containerName.branch' must be*" }
            @{ Name = 'a string length'; Value = @{ branch = @{ length = '8' } }; Message = "*'containerName.branch' must be*" }
            @{ Name = 'a number'; Value = 8; Message = "*'containerName' must be a name*" }
            @{ Name = 'a prefix with a dash inside'; Value = @{ branch = @{ prefix = 'MIS-X'; length = 8 } }; Message = "*'containerName.branch.prefix'*issue key*" }
            @{ Name = 'a prefix that is not a string'; Value = @{ branch = @{ prefix = 5; length = 8 } }; Message = "*'containerName.branch.prefix'*issue key*" }
        ) {
            { Resolve-NAVGitContainerName @common -RepoValue $Value -BranchName 'MIS-1234' } | Should -Throw $Message
        }
    }

    Describe 'Get-NAVGitConfig containerName' {
        It 'reads the branch rule from navgit.json and the user settings' {
            Mock Get-NAVGitBranchName { 'MIS-1234-fix-posting' }
            $repo = New-TestRepository -Config @{ containerName = @{ branch = @{ length = 8 } } }
            (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)).containerName | Should -Be 'MIS-1234'

            $repo = New-TestRepository -Config @{ containerName = 'Contoso' }
            (Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings @{ containerName = @{ branch = @{ length = 8 } } })).containerName |
                Should -Be 'MIS-1234'
        }

        It 'keeps an object containerName from the user settings file' {
            $path = Join-Path $TestDrive 'container-settings.json'
            Set-Content -LiteralPath $path -Value '{ "containerName": { "branch": { "length": 8 } } }'
            $settings = Get-NAVGitUserSettings -Path $path
            $settings.containerName | Should -BeOfType [hashtable]
            $settings.containerName.branch.length | Should -Be 8
        }
    }
}
