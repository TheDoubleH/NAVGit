BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NavGit\NavGit.psd1') -Force
}

Describe 'NavGit module' {
    It 'has a valid manifest' {
        { Test-ModuleManifest -Path (Join-Path $PSScriptRoot '..\NavGit\NavGit.psd1') -ErrorAction Stop } | Should -Not -Throw
    }

    It 'does not import BcContainerHelper on load' {
        Remove-Module BcContainerHelper -ErrorAction SilentlyContinue
        Import-Module (Join-Path $PSScriptRoot '..\NavGit\NavGit.psd1') -Force
        Get-Module BcContainerHelper | Should -BeNullOrEmpty
    }
}

InModuleScope NavGit {
    Describe 'navgit.schema.json' {
        BeforeAll {
            $schemaPath = Join-Path $script:NavGitModuleRoot 'Schema\navgit.schema.json'
            $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
            $known = Get-NavGitKnownConfigKeys
        }

        It 'is valid JSON with object properties' {
            $schema.type | Should -Be 'object'
            $schema.properties | Should -Not -BeNullOrEmpty
        }

        It 'declares exactly the known top-level keys' {
            $schemaKeys = @($schema.properties.PSObject.Properties.Name | Where-Object { $_ -ne '$schema' } | Sort-Object)
            $schemaKeys | Should -Be @($known.Keys | Sort-Object)
        }

        It 'declares exactly the known sub keys of <_>' -ForEach @('database', 'testToolkit', 'paths', 'testObjects', 'import', 'export', 'client') {
            $schemaKeys = @($schema.properties.$_.properties.PSObject.Properties.Name | Sort-Object)
            $schemaKeys | Should -Be @($known[$_] | Sort-Object)
        }

        It 'declares exactly the known artifact keys across its forms' {
            $schemaKeys = @($schema.properties.artifact.oneOf | ForEach-Object { $_.properties.PSObject.Properties.Name } | Sort-Object -Unique)
            $schemaKeys | Should -Be @($known['artifact'] | Sort-Object)
        }

        It 'has defaults matching Get-NavGitDefaultConfig for <_>' -ForEach @('imageName', 'memoryLimit', 'dns', 'updateHosts', 'enableSymbolLoading', 'includeTestToolkit') {
            $defaults = Get-NavGitDefaultConfig -UserSettings @{}
            $schema.properties.$_.default | Should -Be $defaults[$_]
        }

        It 'has the same default test object pattern as Get-NavGitDefaultConfig' {
            $defaults = Get-NavGitDefaultConfig -UserSettings @{}
            $schema.properties.testObjects.properties.versionListPattern.default | Should -Be $defaults.testObjects.versionListPattern
        }
    }

    Describe 'Commands.psd1 registry' {
        BeforeAll {
            $commands = @(Get-NavGitCommandDefinition)
        }

        It 'contains the planned commands' {
            $commands.Name | Should -Be @('BuildContainer', 'BuildAndUpdate', 'RemoveContainer', 'ImportTestToolkit',
                'ImportObjects', 'ExportObjects', 'StartDevEnv', 'StartClient', 'GetProfiles')
        }

        It 'has unique names and functions' {
            ($commands.Name | Sort-Object -Unique).Count | Should -Be $commands.Count
            ($commands.Function | Sort-Object -Unique).Count | Should -Be $commands.Count
        }

        It 'entry <Name> has all required fields' -ForEach (@(Get-NavGitCommandDefinition) | ForEach-Object { @{ Name = $_.Name; Entry = $_ } }) {
            $Entry.Function | Should -Match '^[A-Z][a-z]+-NavGit[A-Za-z]+$'
            $Entry.Description | Should -Not -BeNullOrEmpty
            $Entry.RequiresElevation | Should -BeOfType [bool]
            $Entry.RequiresContainerHelper | Should -BeOfType [bool]
        }

        It 'does not require elevation for client commands' {
            ($commands | Where-Object Name -in 'StartDevEnv', 'StartClient', 'GetProfiles').RequiresElevation | Should -Not -Contain $true
        }

        It 'returns a single entry by name and throws for an unknown name' {
            (Get-NavGitCommandDefinition -Name 'ExportObjects').Function | Should -Be 'Export-NavGitObjects'
            { Get-NavGitCommandDefinition -Name 'Nope' } | Should -Throw '*Unknown NavGit command*'
        }
    }
}
