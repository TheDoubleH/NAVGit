BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NavGit\NavGit.psd1') -Force
}

InModuleScope NavGit {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        Mock Write-Host { }
    }

    Describe 'Import-NavGitTestToolkit' {
        BeforeEach {
            $repo = New-TestRepository -Config @{ testToolkit = @{ country = 'no'; librariesOnly = $false } }
            $config = Get-NavGitConfig -Path $repo -UserSettings (New-TestUserSettings)
            Mock Initialize-NavGitContainerCommand {
                [pscustomobject]@{ Config = $config; ContainerName = 'cust'; Credential = New-TestCredential; SqlCredential = New-TestCredential 'sa' }
            }
            Mock Import-TestToolkitToBcContainer { }
            Mock Invoke-NavGitCompile { @() }
        }

        It 'imports the toolkit with the configured country and compiles' {
            $result = Import-NavGitTestToolkit -Path $repo

            Should -Invoke Import-TestToolkitToBcContainer -Times 1 -Exactly -ParameterFilter {
                $containerName -eq 'cust' -and $testToolkitCountry -eq 'no' -and -not $includeTestLibrariesOnly -and $sqlCredential.UserName -eq 'sa'
            }
            Should -Invoke Invoke-NavGitCompile -Times 1 -Exactly
            $result.Uncompiled | Should -Be 0
        }

        It 'imports only the libraries with -LibrariesOnly' {
            $null = Import-NavGitTestToolkit -Path $repo -LibrariesOnly
            Should -Invoke Import-TestToolkitToBcContainer -Times 1 -Exactly -ParameterFilter { $includeTestLibrariesOnly }
        }
    }

    Describe 'Invoke-NavGitCommand' {
        BeforeEach {
            $repo = New-TestRepository
            Mock Assert-NavGitAdministrator { }
            Mock Assert-NavGitBcContainerHelper { }
            Mock Get-NavGitUserSettings { New-TestUserSettings }
            Mock Write-NavGitLog { }
        }

        It 'runs the registered function with the repository and -Force' {
            Mock New-NavGitContainer { }
            Invoke-NavGitCommand -Name BuildContainer -Repository $repo -Force

            Should -Invoke New-NavGitContainer -Times 1 -Exactly -ParameterFilter { $Path -eq $repo -and $Force }
            Should -Invoke Assert-NavGitAdministrator -Times 1 -Exactly
            Should -Invoke Assert-NavGitBcContainerHelper -Times 1 -Exactly
            $LASTEXITCODE | Should -Be 0
        }

        It 'does not pass -Force to commands without it' {
            Mock Export-NavGitObjects { }
            Invoke-NavGitCommand -Name ExportObjects -Repository $repo -Force
            Should -Invoke Export-NavGitObjects -Times 1 -Exactly -ParameterFilter { -not $PSBoundParameters.ContainsKey('Force') }
        }

        It 'sets LASTEXITCODE to 1 and reports the error when the command fails' {
            Mock Export-NavGitObjects { throw 'export broke' }
            Invoke-NavGitCommand -Name ExportObjects -Repository $repo
            $LASTEXITCODE | Should -Be 1
            Should -Invoke Write-Host -ParameterFilter { $Object -match 'export broke' }
        }

        It 'fails for an unknown command' {
            Invoke-NavGitCommand -Name Nope -Repository $repo
            $LASTEXITCODE | Should -Be 1
        }

        It 'writes the result as a JSON array with -AsJson' {
            Mock Export-NavGitObjects { [pscustomobject]@{ Added = @('TAB18.TXT') } }
            $json = Invoke-NavGitCommand -Name ExportObjects -Repository $repo -AsJson
            $parsed = @($json | ConvertFrom-Json)
            $parsed[0].Added | Should -Be 'TAB18.TXT'
        }
    }

    Describe 'ConvertTo-NavGitJson' {
        It 'writes readable JSON that round-trips' {
            $value = [ordered]@{ name = 'a "b" \ c'; flag = $true; none = $null; count = 3; list = @('x', 'y'); empty = @(); nested = [ordered]@{ k = 'v' } }
            $json = ConvertTo-NavGitJson -InputObject $value

            $json | Should -Match '^\{\r\n  "name": "a \\"b\\" \\\\ c",'
            $parsed = $json | ConvertFrom-Json
            $parsed.name | Should -Be 'a "b" \ c'
            $parsed.flag | Should -BeTrue
            $parsed.count | Should -Be 3
            $parsed.list | Should -Be @('x', 'y')
            $parsed.nested.k | Should -Be 'v'
        }
    }

    Describe 'New-NavGitConfig' {
        It 'creates a valid navgit.json' {
            $folder = Join-Path $TestDrive 'NewRepo'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            $env:NAVGIT_SETTINGS_PATH = Join-Path $TestDrive 'none.json'
            try {
                $null = New-NavGitConfig -Path $folder -Nav 2018 -Cu cu30 -Country no -BakFile 'C:\Backups\x.bak' -Isolation process
                $config = Get-NavGitConfig -Path $folder -UserSettings (New-TestUserSettings)
            }
            finally { Remove-Item Env:\NAVGIT_SETTINGS_PATH }

            $config.projectName | Should -Be 'NewRepo'
            $config.artifact.nav | Should -Be '2018'
            $config.artifact.cu | Should -Be 'cu30'
            $config.database.bakFile | Should -Be 'C:\Backups\x.bak'
            $config.isolation | Should -Be 'process'
        }

        It 'does not overwrite an existing file without -Force' {
            $repo = New-TestRepository
            { New-NavGitConfig -Path $repo -Nav 2018 } | Should -Throw '*already exists*'
        }
    }

    Describe 'ConvertFrom-AdvaniaGitSettings' {
        It 'maps an AdvaniaGIT setup' {
            $result = ConvertFrom-AdvaniaGitSettings -Settings @{
                projectName = 'Customer'; navVersion = '11.0.43274.0'; navSolution = 'NO'; baseBranch = 'master'
                artifact = 'bcartifacts/onprem/11.0.43274.0/no/Closest'; dockerImage = 'old'
                dockerRestoreBackup = 'true'; licenseFile = 'Cryobank%1.flf'; dockerAuthentication = 'NavUserPassword'
                dockerIsolation = 'hyperv'; dockerMemoryLimit = '6G'; dockerTestLibraries = 'true'; testToolkitCountry = 'no'
                dockerEnableSymbolLoading = 'true'; dockerMyScripts = 'https://x/SetupCertificate.ps1'; objectsPath = 'Objects'; testObjectsPath = 'TestObjects'
                dockerFriendlyName = 'cust18'
            }
            $config = $result.Config

            $config.projectName | Should -Be 'Customer'
            $config.containerName | Should -Be 'cust18'
            $config.artifact.version | Should -Be '11.0.43274.0'
            $config.artifact.country | Should -Be 'no'
            $config.artifact.select | Should -Be 'Closest'
            $config.database.searchNames | Should -Be @('master', 'NO')
            $config.licenseFile | Should -Be 'Cryobank{major}.flf'
            $config.auth | Should -Be 'NavUserPassword'
            $config.isolation | Should -Be 'hyperv'
            $config.memoryLimit | Should -Be '6G'
            $config.includeTestToolkit | Should -BeTrue
            $config.testToolkit.librariesOnly | Should -BeTrue
            $config.testToolkit.country | Should -Be 'no'
            $config.enableSymbolLoading | Should -BeTrue
            $config.myScripts | Should -Be @('https://x/SetupCertificate.ps1')
            $config.paths.tests | Should -Be 'TestObjects'
            $config.paths.Contains('objects') | Should -BeFalse
            ($result.Notes -join ' ') | Should -Match 'dockerImage'
        }

        It 'derives import.dateFormat from datetimeCulture with a two-digit year' {
            (ConvertFrom-AdvaniaGitSettings -Settings @{ projectName = 'P'; navVersion = '9.0'; datetimeCulture = 'en-US' }).Config.import.dateFormat | Should -Be 'M/d/yy'
            (ConvertFrom-AdvaniaGitSettings -Settings @{ projectName = 'P'; navVersion = '9.0'; datetimeCulture = 'nb-NO' }).Config.import.dateFormat | Should -Be 'dd.MM.yy'
        }

        It 'maps an artifact URL and uses the demo database without dockerRestoreBackup' {
            $config = (ConvertFrom-AdvaniaGitSettings -Settings @{ projectName = 'P'; artifact = 'https://bcartifacts.azureedge.net/onprem/14.0.29537.0/w1' }).Config
            $config.artifact.url | Should -Be 'https://bcartifacts.azureedge.net/onprem/14.0.29537.0/w1'
            $config.database.useDemo | Should -BeTrue
        }

        It 'requires a projectName' {
            { ConvertFrom-AdvaniaGitSettings -Settings @{ navVersion = '11.0' } } | Should -Throw '*projectName*'
        }
    }

    Describe 'ConvertFrom-AdvaniaGitSetup' {
        It 'writes a navgit.json that loads, with setup.json winning over GITSettings' {
            $folder = Join-Path $TestDrive 'AdvRepo'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            '{ "projectName": "Adv", "artifact": "https://bcartifacts.azureedge.net/onprem/11.0.43274.0/no", "dockerIsolation": "process" }' |
                Set-Content -LiteralPath (Join-Path $folder 'setup.json')
            $gitSettings = Join-Path $TestDrive 'GITSettings.Json'
            '{ "dockerIsolation": "hyperv", "dockerAuthentication": "NavUserPassword", "licenseFile": "Cryobank.flf", "objectsPath": "Objects" }' |
                Set-Content -LiteralPath $gitSettings
            $env:NAVGIT_SETTINGS_PATH = Join-Path $TestDrive 'none.json'
            try {
                $null = ConvertFrom-AdvaniaGitSetup -Path $folder -GitSettingsPath $gitSettings -WarningAction SilentlyContinue
            }
            finally { Remove-Item Env:\NAVGIT_SETTINGS_PATH }

            $config = Get-NavGitConfig -Path $folder -UserSettings (New-TestUserSettings)
            $config.isolation | Should -Be 'process'
            $config.auth | Should -Be 'NavUserPassword'
            $config.licenseFile | Should -Be 'Cryobank.flf'
            $config.database.useDemo | Should -BeTrue
        }
    }
}
