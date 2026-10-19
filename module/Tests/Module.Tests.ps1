BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1') -Force
}

Describe 'NAVGit module' {
    It 'has a valid manifest' {
        { Test-ModuleManifest -Path (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1') -ErrorAction Stop } | Should -Not -Throw
    }

    It 'lists exactly the Public functions in FunctionsToExport' {
        $manifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1')
        $publicFunctions = @(Get-ChildItem -Path (Join-Path $PSScriptRoot '..\NAVGit\Public') -Filter '*.ps1' -Recurse | ForEach-Object { $_.BaseName } | Sort-Object)
        @($manifest.FunctionsToExport | Sort-Object) | Should -Be $publicFunctions
    }

    It 'has the same version as the VS Code extension' {
        $manifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1')
        $package = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\vscode\package.json') -Raw | ConvertFrom-Json
        $manifest.ModuleVersion | Should -Be $package.version
    }

    It 'has the PowerShell Gallery metadata' {
        $manifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1')
        $manifest.Description | Should -Not -BeNullOrEmpty
        $manifest.Author | Should -Not -BeNullOrEmpty
        $manifest.PrivateData.PSData.ProjectUri | Should -Match '^https://'
        $manifest.PrivateData.PSData.LicenseUri | Should -Match '^https://'
    }

    It 'does not import BcContainerHelper on load' {
        Remove-Module BcContainerHelper -ErrorAction SilentlyContinue
        Import-Module (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1') -Force
        Get-Module BcContainerHelper | Should -BeNullOrEmpty
    }
}

InModuleScope NAVGit {
    Describe 'navgit.schema.json' {
        BeforeAll {
            $schemaPath = Join-Path $script:NAVGitModuleRoot 'Schema\navgit.schema.json'
            $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
            $known = Get-NAVGitKnownConfigKeys
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

        It 'has defaults matching Get-NAVGitDefaultConfig for <_>' -ForEach @('imageName', 'memoryLimit', 'dns', 'updateHosts', 'enableSymbolLoading', 'includeTestToolkit') {
            $defaults = Get-NAVGitDefaultConfig -UserSettings @{}
            $schema.properties.$_.default | Should -Be $defaults[$_]
        }

        It 'has the same default test object pattern as Get-NAVGitDefaultConfig' {
            $defaults = Get-NAVGitDefaultConfig -UserSettings @{}
            $schema.properties.testObjects.properties.versionListPattern.default | Should -Be $defaults.testObjects.versionListPattern
        }
    }

    Describe 'Commands.psd1 registry' {
        BeforeAll {
            $commands = @(Get-NAVGitCommandDefinition)
        }

        It 'contains the planned commands' {
            $commands.Name | Should -Be @('BuildContainer', 'BuildAndUpdate', 'RemoveContainer', 'ImportTestToolkit',
                'ImportObjects', 'ExportObjects', 'CompileUncompiled', 'CompileModified', 'CompileAll', 'UpdateAddIns',
                'StartDevEnv', 'StartClient', 'GetProfiles')
        }

        It 'has unique names and unique function + parameter combinations' {
            ($commands.Name | Sort-Object -Unique).Count | Should -Be $commands.Count
            $combinations = $commands | ForEach-Object {
                $parameters = ''
                if ($_.ContainsKey('Parameters')) { $parameters = ($_.Parameters.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ';' }
                "$($_.Function)|$parameters"
            }
            ($combinations | Sort-Object -Unique).Count | Should -Be $commands.Count
        }

        It 'entry <Name> only uses fixed parameters the function accepts' -ForEach (@(Get-NAVGitCommandDefinition) | Where-Object { $_.ContainsKey('Parameters') } | ForEach-Object { @{ Name = $_.Name; Entry = $_ } }) {
            $command = Get-Command -Name $Entry.Function -Module NAVGit -CommandType Function
            foreach ($key in $Entry.Parameters.Keys) {
                $command.Parameters.Keys | Should -Contain $key
                $validValues = $command.Parameters[$key].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | ForEach-Object { $_.ValidValues }
                if ($validValues) { $validValues | Should -Contain $Entry.Parameters[$key] }
            }
        }

        It 'entry <Name> has all required fields' -ForEach (@(Get-NAVGitCommandDefinition) | ForEach-Object { @{ Name = $_.Name; Entry = $_ } }) {
            $Entry.Function | Should -Match '^[A-Z][a-z]+-NAVGit[A-Za-z]+$'
            $Entry.Description | Should -Not -BeNullOrEmpty
            $Entry.RequiresElevation | Should -BeOfType [bool]
            $Entry.RequiresContainerHelper | Should -BeOfType [bool]
        }

        It 'entry <Name> points to an exported function' -ForEach (@(Get-NAVGitCommandDefinition) | ForEach-Object { @{ Name = $_.Name; Function = $_.Function } }) {
            Get-Command -Name $Function -Module NAVGit -CommandType Function | Should -Not -BeNullOrEmpty
            (Get-Module NAVGit).ExportedFunctions.Keys | Should -Contain $Function
        }

        It 'does not require elevation for client commands' {
            ($commands | Where-Object Name -in 'StartDevEnv', 'StartClient', 'GetProfiles').RequiresElevation | Should -Not -Contain $true
        }

        It 'returns a single entry by name and throws for an unknown name' {
            (Get-NAVGitCommandDefinition -Name 'ExportObjects').Function | Should -Be 'Export-NAVGitObjects'
            { Get-NAVGitCommandDefinition -Name 'Nope' } | Should -Throw '*Unknown NAVGit command*'
        }
    }
}
