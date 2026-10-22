BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot '..\NAVGit\NAVGit.psd1') -Force
}

InModuleScope NAVGit {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        $defaultTestObjects = (Get-NAVGitDefaultConfig).testObjects

        function New-TestFolder([string] $Prefix = 'f') {
            $path = Join-Path $TestDrive ("$Prefix-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            return $path
        }
    }

    Describe 'Read-NavObjectHeader' {
        It 'reads type, id, name and object properties' {
            $file = New-TestObjectFile -Folder (New-TestFolder) -Type Table -Id 18 -Name 'Customer' -VersionList 'NAVW111.00,NAVNO11.00' -Modified

            $header = Read-NavObjectHeader -Path $file

            $header.Type | Should -Be 'Table'
            $header.TypeId | Should -Be 1
            $header.Id | Should -Be 18
            $header.Name | Should -Be 'Customer'
            $header.Date | Should -Be '24.11.17'
            $header.Time | Should -Be '12:00:00'
            $header.Modified | Should -BeTrue
            $header.VersionList | Should -Be 'NAVW111.00,NAVNO11.00'
            $header.Subtype | Should -Be ''
        }

        It 'treats a missing Modified line as not modified and strips [ ] around values' {
            $file = New-TestObjectFile -Folder (New-TestFolder) -Time '[ 9:05:00]' -VersionList '[CUST1.00;X]'

            $header = Read-NavObjectHeader -Path $file

            $header.Modified | Should -BeFalse
            $header.Time | Should -Be '9:05:00'
            $header.VersionList | Should -Be 'CUST1.00;X'
        }

        It 'reads Subtype=Test of a test codeunit' {
            $file = New-TestObjectFile -Folder (New-TestFolder) -Type Codeunit -Id 50100 -Subtype Test -VersionList 'CUST1.00'
            (Read-NavObjectHeader -Path $file).Subtype | Should -Be 'Test'
        }

        It 'reads names with OEM characters' {
            # Built from char codes: Windows PowerShell reads BOM-less .ps1 files as ANSI.
            $name = "Kundeoversikt $([char]0xE6)$([char]0xF8)$([char]0xE5)"
            $cp850 = [System.Text.Encoding]::GetEncoding(850)
            $file = New-TestObjectFile -Folder (New-TestFolder) -Name $name -Encoding $cp850
            (Read-NavObjectHeader -Path $file -Encoding $cp850).Name | Should -Be $name
        }

        It 'reads the bracketed declaration used for names with trailing spaces' {
            $file = New-TestObjectFile -Folder (New-TestFolder) -Id 50376
            $lines = [System.IO.File]::ReadAllLines($file)
            $lines[0] = 'OBJECT [Table 50376 Required Sales Doc. Document ]'
            [System.IO.File]::WriteAllLines($file, $lines)

            $header = Read-NavObjectHeader -Path $file
            $header.Type | Should -Be 'Table'
            $header.Id | Should -Be 50376
            $header.Name | Should -Be 'Required Sales Doc. Document '
        }

        It 'rejects files that are not C/AL objects' {
            $file = Join-Path (New-TestFolder) 'TAB1.TXT'
            Set-Content -LiteralPath $file -Value 'hello'
            { Read-NavObjectHeader -Path $file } | Should -Throw '*not a C/AL object file*'
        }
    }

    Describe 'Object date and time parsing' {
        It 'parses date <Text>' -ForEach @(
            @{ Text = '24.11.17'; Expected = '2017-11-24' }
            @{ Text = '1.2.18'; Expected = '2018-02-01' }
            @{ Text = '11/24/17'; Expected = '2017-11-24' }
            @{ Text = '24-11-17'; Expected = '2017-11-24' }
        ) {
            $result = ConvertTo-NAVGitObjectDate -Text $Text
            $result.Valid | Should -BeTrue
            $result.Value | Should -Be ([datetime]$Expected)
        }

        It 'uses an explicit date format' {
            (ConvertTo-NAVGitObjectDate -Text '24/11/17' -Format 'dd/MM/yy').Value | Should -Be ([datetime]'2017-11-24')
            (ConvertTo-NAVGitObjectDate -Text '24/11/17').Valid | Should -BeFalse
        }

        It 'treats a blank date as valid and empty' {
            $result = ConvertTo-NAVGitObjectDate -Text ''
            $result.Valid | Should -BeTrue
            $result.Value | Should -BeNullOrEmpty
        }

        It 'parses time <Text>' -ForEach @(
            @{ Text = '12:00:00'; Expected = '12:00:00' }
            @{ Text = '9:05:00'; Expected = '09:05:00' }
            @{ Text = '1:30:00 PM'; Expected = '13:30:00' }
            @{ Text = '12:00:00.567'; Expected = '12:00:00' }
        ) {
            $result = ConvertTo-NAVGitObjectTime -Text $Text
            $result.Valid | Should -BeTrue
            $result.Value | Should -Be ([timespan]$Expected)
        }

        It 'converts SQL values and treats 1753 as blank' {
            ConvertFrom-NAVGitSqlDateTime -Text '2017-11-24 00:00:00' -Part Date | Should -Be ([datetime]'2017-11-24')
            ConvertFrom-NAVGitSqlDateTime -Text '1754-01-01 13:30:15' -Part Time | Should -Be ([timespan]'13:30:15')
            ConvertFrom-NAVGitSqlDateTime -Text '1753-01-01 00:00:00' -Part Date | Should -BeNullOrEmpty
        }
    }

    Describe 'Get-NAVGitObjectTargetFolder' {
        It 'puts Version List <VersionList> in <Expected>' -ForEach @(
            @{ VersionList = 'Test'; Expected = 'Tests' }
            @{ VersionList = 'TEST1.0'; Expected = 'Tests' }
            @{ VersionList = 'NAVW111.00,Test'; Expected = 'Tests' }
            @{ VersionList = 'CUST1.0, TestLib'; Expected = 'Tests' }
            @{ VersionList = 'NAVW111.00'; Expected = 'Objects' }
            @{ VersionList = 'NAVW111.00,LATEST'; Expected = 'Objects' }
            @{ VersionList = 'NAVW1,MyTest'; Expected = 'Objects' }
            @{ VersionList = ''; Expected = 'Objects' }
        ) {
            $header = [pscustomobject]@{ Type = 'Table'; VersionList = $VersionList; Subtype = '' }
            Get-NAVGitObjectTargetFolder -Header $header -TestObjects $defaultTestObjects | Should -Be $Expected
        }

        It 'puts codeunits with Subtype=Test in Tests unless includeTestCodeunits is off' {
            $header = [pscustomobject]@{ Type = 'Codeunit'; VersionList = 'CUST1.00'; Subtype = 'Test' }
            Get-NAVGitObjectTargetFolder -Header $header -TestObjects $defaultTestObjects | Should -Be 'Tests'
            Get-NAVGitObjectTargetFolder -Header $header -TestObjects @{ versionListPattern = 'Test'; includeTestCodeunits = $false } | Should -Be 'Objects'
        }

        It 'uses a custom pattern' {
            $header = [pscustomobject]@{ Type = 'Table'; VersionList = 'NAVW1,MyTest'; Subtype = '' }
            Get-NAVGitObjectTargetFolder -Header $header -TestObjects @{ versionListPattern = 'Test'; includeTestCodeunits = $true } | Should -Be 'Tests'
        }
    }

    Describe 'Compare-NAVGitObjects' {
        BeforeAll {
            $folder = New-TestFolder 'cmp'
            $unchanged = Read-NavObjectHeader (New-TestObjectFile -Folder $folder -Id 50000)
            $newObject = Read-NavObjectHeader (New-TestObjectFile -Folder $folder -Id 50001)
            $versionChanged = Read-NavObjectHeader (New-TestObjectFile -Folder $folder -Id 50002 -VersionList 'CUST1.01')
            $modifiedChanged = Read-NavObjectHeader (New-TestObjectFile -Folder $folder -Id 50003 -Modified)
            $timeChanged = Read-NavObjectHeader (New-TestObjectFile -Folder $folder -Id 50004 -Time '12:00:01')
            $badDate = Read-NavObjectHeader (New-TestObjectFile -Folder $folder -Id 50005 -Date 'xx')

            $db = @(
                New-TestDbObject -Id 50000
                New-TestDbObject -Id 50002
                New-TestDbObject -Id 50003
                New-TestDbObject -Id 50004
                New-TestDbObject -Id 50005
                New-TestDbObject -Id 60000 -Name 'Only in DB'
                New-TestDbObject -Type Codeunit -Id 50000 -Name 'Same id other type'
            )
            $repo = @($unchanged, $newObject, $versionChanged, $modifiedChanged, $timeChanged, $badDate)
        }

        It 'imports new and changed objects and skips unchanged ones' {
            $result = Compare-NAVGitObjects -RepoObjects $repo -DbObjects $db

            @($result.Unchanged.Id) | Should -Be @(50000)
            @($result.ToImport.Id | Sort-Object) | Should -Be @(50001, 50002, 50003, 50004, 50005)
            $result.Unparsed | Should -Be 1
        }

        It 'reports objects that are only in the database, per type' {
            $result = Compare-NAVGitObjects -RepoObjects $repo -DbObjects $db
            @($result.Missing | ForEach-Object { "$($_.Type) $($_.Id)" } | Sort-Object) | Should -Be @('Codeunit 50000', 'Table 60000')
        }

        It 'imports everything with -Force' {
            (Compare-NAVGitObjects -RepoObjects $repo -DbObjects $db -Force).ToImport.Count | Should -Be 6
        }

        It 'handles an empty database' {
            $result = Compare-NAVGitObjects -RepoObjects $repo -DbObjects @()
            $result.ToImport.Count | Should -Be 6
            $result.Missing.Count | Should -Be 0
        }
    }

    Describe 'Get-NAVGitRepoObjects' {
        It 'reads Objects and Tests and ignores other files' {
            $repo = New-TestRepository
            $config = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)
            $null = New-TestObjectFile -Folder $config.objectsPath -Id 18
            $null = New-TestObjectFile -Folder $config.testsPath -Type Codeunit -Id 50100
            Set-Content -LiteralPath (Join-Path $config.objectsPath 'README.md') -Value 'x'

            @(Get-NAVGitRepoObjects -Config $config | ForEach-Object { "$($_.Type) $($_.Id)" } | Sort-Object) | Should -Be @('Codeunit 50100', 'Table 18')
        }

        It 'throws when an object exists in both folders' {
            $repo = New-TestRepository
            $config = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)
            $null = New-TestObjectFile -Folder $config.objectsPath -Id 18
            $null = New-TestObjectFile -Folder $config.testsPath -Id 18
            { Get-NAVGitRepoObjects -Config $config } | Should -Throw '*Table 18 exists twice*'
        }
    }

    Describe 'Join-NAVGitObjectFiles' {
        It 'concatenates bytes and adds a line break when a file does not end with one' {
            $folder = New-TestFolder 'join'
            [System.IO.File]::WriteAllBytes((Join-Path $folder 'a.txt'), [byte[]](65, 13, 10))
            [System.IO.File]::WriteAllBytes((Join-Path $folder 'b.txt'), [byte[]](0xE6, 66))
            [System.IO.File]::WriteAllBytes((Join-Path $folder 'c.txt'), [byte[]](67))

            Join-NAVGitObjectFiles -Path @((Join-Path $folder 'a.txt'), (Join-Path $folder 'b.txt'), (Join-Path $folder 'c.txt')) -Destination (Join-Path $folder 'all.txt')

            [System.IO.File]::ReadAllBytes((Join-Path $folder 'all.txt')) | Should -Be ([byte[]](65, 13, 10, 0xE6, 66, 13, 10, 67, 13, 10))
        }
    }

    Describe 'Sync-NAVGitObjectFolder' {
        BeforeEach {
            $source = New-TestFolder 'export'
            $objects = New-TestFolder 'Objects'
            $tests = New-TestFolder 'Tests'
        }

        It 'routes test objects to Tests and others to Objects' {
            $null = New-TestObjectFile -Folder $source -Id 18 -VersionList 'NAVW111.00'
            $null = New-TestObjectFile -Folder $source -Id 50100 -VersionList 'Test'
            $null = New-TestObjectFile -Folder $source -Type Codeunit -Id 50101 -Subtype Test

            $result = Sync-NAVGitObjectFolder -SourceFolder $source -ObjectsPath $objects -TestsPath $tests -TestObjects $defaultTestObjects -RemoveMissing

            Join-Path $objects 'TAB18.TXT' | Should -Exist
            Join-Path $tests 'TAB50100.TXT' | Should -Exist
            Join-Path $tests 'COD50101.TXT' | Should -Exist
            @($result.Added | Sort-Object) | Should -Be @('COD50101.TXT', 'TAB18.TXT', 'TAB50100.TXT')
            @($result.Tests | Sort-Object) | Should -Be @('COD50101.TXT', 'TAB50100.TXT')
        }

        It 'moves an object that became a test object' {
            $null = New-TestObjectFile -Folder $objects -Id 50100 -VersionList 'CUST1.00'
            $null = New-TestObjectFile -Folder $source -Id 50100 -VersionList 'CUST1.00,Test'

            $result = Sync-NAVGitObjectFolder -SourceFolder $source -ObjectsPath $objects -TestsPath $tests -TestObjects $defaultTestObjects -RemoveMissing

            Join-Path $objects 'TAB50100.TXT' | Should -Not -Exist
            Join-Path $tests 'TAB50100.TXT' | Should -Exist
            $result.Moved | Should -Be @('TAB50100.TXT')
        }

        It 'detects changed and unchanged files byte for byte' {
            $null = New-TestObjectFile -Folder $objects -Id 18
            $null = New-TestObjectFile -Folder $objects -Id 27 -VersionList 'OLD'
            $null = New-TestObjectFile -Folder $source -Id 18
            $null = New-TestObjectFile -Folder $source -Id 27 -VersionList 'NEW'

            $result = Sync-NAVGitObjectFolder -SourceFolder $source -ObjectsPath $objects -TestsPath $tests -TestObjects $defaultTestObjects -RemoveMissing

            $result.Unchanged | Should -Be @('TAB18.TXT')
            $result.Changed | Should -Be @('TAB27.TXT')
            (Read-NavObjectHeader (Join-Path $objects 'TAB27.TXT')).VersionList | Should -Be 'NEW'
        }

        It 'removes object files that were not exported but keeps other files' {
            $null = New-TestObjectFile -Folder $objects -Id 99
            $null = New-TestObjectFile -Folder $tests -Id 98
            Set-Content -LiteralPath (Join-Path $objects 'README.md') -Value 'keep'
            $null = New-TestObjectFile -Folder $source -Id 18

            $result = Sync-NAVGitObjectFolder -SourceFolder $source -ObjectsPath $objects -TestsPath $tests -TestObjects $defaultTestObjects -RemoveMissing

            @($result.Removed | Sort-Object) | Should -Be @('TAB98.TXT', 'TAB99.TXT')
            Join-Path $objects 'README.md' | Should -Exist
        }

        It 'keeps missing files in Tests with -KeepMissingTests but still removes them from Objects' {
            $null = New-TestObjectFile -Folder $objects -Id 99
            $null = New-TestObjectFile -Folder $tests -Id 98 -VersionList 'Test'
            $null = New-TestObjectFile -Folder $source -Id 18

            $result = Sync-NAVGitObjectFolder -SourceFolder $source -ObjectsPath $objects -TestsPath $tests -TestObjects $defaultTestObjects -RemoveMissing -KeepMissingTests

            $result.Removed | Should -Be @('TAB99.TXT')
            $result.Kept | Should -Be @('TAB98.TXT')
            Join-Path $tests 'TAB98.TXT' | Should -Exist
            Join-Path $objects 'TAB99.TXT' | Should -Not -Exist
        }

        It 'still moves an exported object out of Tests with -KeepMissingTests' {
            $null = New-TestObjectFile -Folder $tests -Id 50100 -VersionList 'CUST1.00,Test'
            $null = New-TestObjectFile -Folder $source -Id 50100 -VersionList 'CUST1.00'

            $result = Sync-NAVGitObjectFolder -SourceFolder $source -ObjectsPath $objects -TestsPath $tests -TestObjects $defaultTestObjects -RemoveMissing -KeepMissingTests

            $result.Moved | Should -Be @('TAB50100.TXT')
            $result.Kept.Count | Should -Be 0
            Join-Path $tests 'TAB50100.TXT' | Should -Not -Exist
        }

        It 'keeps files that were not exported without -RemoveMissing' {
            $null = New-TestObjectFile -Folder $objects -Id 99
            $null = New-TestObjectFile -Folder $source -Id 18

            $result = Sync-NAVGitObjectFolder -SourceFolder $source -ObjectsPath $objects -TestsPath $tests -TestObjects $defaultTestObjects

            $result.Removed.Count | Should -Be 0
            Join-Path $objects 'TAB99.TXT' | Should -Exist
        }
    }

    Describe 'Import-NAVGitObjects' {
        BeforeEach {
            $repo = New-TestRepository
            $config = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)
            $null = New-TestObjectFile -Folder $config.objectsPath -Id 18
            $null = New-TestObjectFile -Folder $config.objectsPath -Id 27 -VersionList 'CUST1.01'
            $null = New-TestObjectFile -Folder $config.testsPath -Type Codeunit -Id 50100 -VersionList 'Test'
            $staging = New-TestFolder 'staging'
            $script:importedFile = $null

            Mock Initialize-NAVGitContainerCommand {
                [pscustomobject]@{ Config = $config; ContainerName = 'cust'; Credential = New-TestCredential; SqlCredential = New-TestCredential 'sa' }
            }
            Mock Get-NAVGitDbObjects { @((New-TestDbObject -Id 18), (New-TestDbObject -Id 27), (New-TestDbObject -Id 99 -Name 'Old')) }
            Mock Get-NAVGitStagingFolder { $staging }
            Mock Import-ObjectsToNavContainer { $script:importedFile = [System.IO.File]::ReadAllText($objectsFile) }
            Mock Invoke-NAVGitContainerCompile { @() }
            Mock Invoke-NAVGitForceSync { }
            Mock Set-NAVGitObjectsDeleted { }
            Mock Get-NAVGitContainerState { $null }
            Mock Set-NAVGitContainerStateValue { }
            Mock Write-Host { }
        }

        It 'imports only changed and new objects, including the Tests folder with includeTestToolkit, then compiles and syncs' {
            $config.includeTestToolkit = $true
            $result = Import-NAVGitObjects -Path $repo -WarningAction SilentlyContinue

            $result.Imported | Should -Be 2
            $result.Unchanged | Should -Be 1
            $result.Missing | Should -Be 1
            $script:importedFile | Should -Match 'OBJECT Table 27'
            $script:importedFile | Should -Match 'OBJECT Codeunit 50100'
            $script:importedFile | Should -Not -Match 'OBJECT Table 18 '
            Should -Invoke Import-ObjectsToNavContainer -Times 1 -Exactly -ParameterFilter { $containerName -eq 'cust' -and $SynchronizeSchemaChanges -eq 'Force' -and $sqlCredential.UserName -eq 'sa' }
            Should -Invoke Invoke-NAVGitContainerCompile -Times 1 -Exactly
            Should -Invoke Invoke-NAVGitForceSync -Times 1 -Exactly
            Should -Invoke Set-NAVGitObjectsDeleted -Times 0 -Exactly
            $staging | Should -Not -Exist
        }

        It 'does not import test objects when includeTestToolkit is off' {
            $result = Import-NAVGitObjects -Path $repo -WarningVariable warnings -WarningAction SilentlyContinue

            $result.Imported | Should -Be 1
            $result.SkippedTests | Should -Be 1
            $script:importedFile | Should -Match 'OBJECT Table 27'
            $script:importedFile | Should -Not -Match 'OBJECT Codeunit 50100'
            ($warnings -join ' ') | Should -Match '1 changed test object\(s\) in Tests are not imported because includeTestToolkit is off'
        }

        It 'imports test objects with -IncludeTests' {
            $result = Import-NAVGitObjects -Path $repo -IncludeTests -WarningAction SilentlyContinue

            $result.Imported | Should -Be 2
            $result.SkippedTests | Should -Be 0
            $script:importedFile | Should -Match 'OBJECT Codeunit 50100'
        }

        It 'records that the test objects are imported when they are included (<Case>)' -ForEach @(
            @{ Case = 'includeTestToolkit'; Toolkit = $true; Switch = $false }
            @{ Case = '-IncludeTests'; Toolkit = $false; Switch = $true }
        ) {
            $config.includeTestToolkit = $Toolkit
            $null = Import-NAVGitObjects -Path $repo -IncludeTests:$Switch -WarningAction SilentlyContinue
            Should -Invoke Set-NAVGitContainerStateValue -Times 1 -Exactly -ParameterFilter { $ContainerName -eq 'cust' -and $Name -eq 'testsImported' -and $Value -eq $true }
        }

        It 'does not record anything when the test objects are skipped' {
            $null = Import-NAVGitObjects -Path $repo -WarningAction SilentlyContinue
            Should -Invoke Set-NAVGitContainerStateValue -Times 0 -Exactly
        }

        It 'does not record anything when the import fails' {
            $config.includeTestToolkit = $true
            Mock Import-ObjectsToNavContainer { throw 'finsql failed' }
            { Import-NAVGitObjects -Path $repo -WarningAction SilentlyContinue } | Should -Throw '*finsql failed*'
            Should -Invoke Set-NAVGitContainerStateValue -Times 0 -Exactly
        }

        It 'keeps importing test objects once they are in the container' {
            Mock Get-NAVGitContainerState { @{ testsImported = $true } }

            $result = Import-NAVGitObjects -Path $repo -WarningAction SilentlyContinue

            $result.SkippedTests | Should -Be 0
            $script:importedFile | Should -Match 'OBJECT Codeunit 50100'
        }

        It 'does not import anything when only test objects changed and includeTestToolkit is off' {
            Mock Get-NAVGitDbObjects { @((New-TestDbObject -Id 18), (New-TestDbObject -Id 27 -VersionList 'CUST1.01')) }

            $result = Import-NAVGitObjects -Path $repo -WarningAction SilentlyContinue

            $result.Imported | Should -Be 0
            $result.SkippedTests | Should -Be 1
            Should -Invoke Import-ObjectsToNavContainer -Times 0 -Exactly
            Should -Invoke Invoke-NAVGitContainerCompile -Times 0 -Exactly
        }

        It 'never treats skipped test objects in the database as missing' {
            $config.import.deleteMissing = 'mark'
            # The test codeunit is in the database (older version) and changed in Git, but tests are not imported.
            Mock Get-NAVGitDbObjects { @((New-TestDbObject -Id 18), (New-TestDbObject -Id 27 -VersionList 'CUST1.01'), (New-TestDbObject -Type Codeunit -Id 50100 -VersionList 'Test,OLD')) }

            $result = Import-NAVGitObjects -Path $repo -WarningAction SilentlyContinue

            $result.SkippedTests | Should -Be 1
            $result.Missing | Should -Be 0
            Should -Invoke Set-NAVGitObjectsDeleted -Times 0 -Exactly
        }

        It 'does not list objects missing in Git with deleteMissing = skip (default)' {
            $config.import.deleteMissing | Should -Be 'skip'
            $null = Import-NAVGitObjects -Path $repo -WarningVariable warnings -WarningAction SilentlyContinue -Verbose 4>&1 |
                Tee-Object -Variable verbose | Out-Null
            ($warnings -join ' ') | Should -Not -Match 'not in Git'
            ($verbose -join ' ') | Should -Match "1 object\(s\) are in the database but not in Git \(set import.deleteMissing to 'warn'"
            Should -Invoke Set-NAVGitObjectsDeleted -Times 0 -Exactly
        }

        It 'lists objects missing in Git with deleteMissing = warn' {
            $config.import.deleteMissing = 'warn'
            $null = Import-NAVGitObjects -Path $repo -WarningVariable warnings -WarningAction SilentlyContinue
            ($warnings -join ' ') | Should -Match '1 object\(s\) are in the database but not in Git:'
            ($warnings -join ' ') | Should -Match 'Table 99 Old'
        }

        It 'always lists objects it marks with deleteMissing = mark' {
            $config.import.deleteMissing = 'mark'
            $null = Import-NAVGitObjects -Path $repo -WarningVariable warnings -WarningAction SilentlyContinue
            ($warnings -join ' ') | Should -Match "marked with Version List '#DELETE'"
        }

        It 'marks missing objects with deleteMissing = mark' {
            $config.import.deleteMissing = 'mark'
            $null = Import-NAVGitObjects -Path $repo -WarningAction SilentlyContinue
            Should -Invoke Set-NAVGitObjectsDeleted -Times 1 -Exactly -ParameterFilter { @($Objects).Count -eq 1 -and $Objects[0].Id -eq 99 }
        }

        It 'does nothing in the container when everything is unchanged' {
            Mock Get-NAVGitDbObjects { @((New-TestDbObject -Id 18), (New-TestDbObject -Id 27 -VersionList 'CUST1.01'), (New-TestDbObject -Type Codeunit -Id 50100 -VersionList 'Test')) }

            $result = Import-NAVGitObjects -Path $repo

            $result.Imported | Should -Be 0
            Should -Invoke Import-ObjectsToNavContainer -Times 0 -Exactly
            Should -Invoke Invoke-NAVGitContainerCompile -Times 0 -Exactly
        }
    }

    Describe 'Export-NAVGitObjects' {
        BeforeEach {
            $repo = New-TestRepository
            $config = Get-NAVGitConfig -Path $repo -UserSettings (New-TestUserSettings)
            $null = New-TestObjectFile -Folder $config.objectsPath -Id 50100 -VersionList 'CUST1.00'
            $null = New-TestObjectFile -Folder $config.objectsPath -Id 77
            $staging = New-TestFolder 'staging'

            Mock Initialize-NAVGitContainerCommand {
                [pscustomobject]@{ Config = $config; ContainerName = 'cust'; Credential = New-TestCredential; SqlCredential = $null }
            }
            Mock Get-NAVGitStagingFolder { $staging }
            Mock Export-NavContainerObjects {
                $null = New-TestObjectFile -Folder $objectsFolder -Id 18 -VersionList 'NAVW111.00'
                $null = New-TestObjectFile -Folder $objectsFolder -Id 50100 -VersionList 'CUST1.00,Test'
            }
            Mock Get-NAVGitContainerState { @{ testsImported = $true } }
            Mock Write-Host { }
        }

        It 'exports, routes test objects to Tests and removes deleted objects' {
            $result = Export-NAVGitObjects -Path $repo

            Join-Path $config.objectsPath 'TAB18.TXT' | Should -Exist
            Join-Path $config.testsPath 'TAB50100.TXT' | Should -Exist
            Join-Path $config.objectsPath 'TAB50100.TXT' | Should -Not -Exist
            Join-Path $config.objectsPath 'TAB77.TXT' | Should -Not -Exist
            $result.Moved | Should -Be @('TAB50100.TXT')
            $result.Removed | Should -Be @('TAB77.TXT')
            Should -Invoke Export-NavContainerObjects -Times 1 -Exactly -ParameterFilter { $filter -eq '' -and $exportTo -eq 'txt folder' }
            $staging | Should -Not -Exist
        }

        It 'keeps the Tests folder when the test objects were never imported' {
            Mock Get-NAVGitContainerState { @{ testsImported = $false } }
            $null = New-TestObjectFile -Folder $config.testsPath -Type Codeunit -Id 50200 -VersionList 'Test'

            $result = Export-NAVGitObjects -Path $repo

            Join-Path $config.testsPath 'COD50200.TXT' | Should -Exist
            $result.Kept | Should -Be @('COD50200.TXT')
            $result.Removed | Should -Be @('TAB77.TXT')
            Join-Path $config.testsPath 'TAB50100.TXT' | Should -Exist
        }

        It 'removes missing test files once the test objects are imported' {
            $null = New-TestObjectFile -Folder $config.testsPath -Type Codeunit -Id 50200 -VersionList 'Test'

            $result = Export-NAVGitObjects -Path $repo

            Join-Path $config.testsPath 'COD50200.TXT' | Should -Not -Exist
            @($result.Removed | Sort-Object) | Should -Be @('COD50200.TXT', 'TAB77.TXT')
            $result.Kept.Count | Should -Be 0
        }

        It 'goes by includeTestToolkit (<Toolkit>) when the state does not say' -ForEach @(
            @{ Toolkit = $true; Removed = $true }
            @{ Toolkit = $false; Removed = $false }
        ) {
            Mock Get-NAVGitContainerState { $null }
            $config.includeTestToolkit = $Toolkit
            $null = New-TestObjectFile -Folder $config.testsPath -Type Codeunit -Id 50200 -VersionList 'Test'

            $null = Export-NAVGitObjects -Path $repo

            (Test-Path -LiteralPath (Join-Path $config.testsPath 'COD50200.TXT')) | Should -Be (-not $Removed)
        }

        It 'keeps files that were not exported when a partial filter is used' {
            $config.export.filter = 'Type=Table;Id=18'
            $result = Export-NAVGitObjects -Path $repo -WarningAction SilentlyContinue

            $result.Removed.Count | Should -Be 0
            Join-Path $config.objectsPath 'TAB77.TXT' | Should -Exist
        }
    }

    Describe 'Update-NAVGitContainer' {
        BeforeEach {
            $repo = New-TestRepository
            Mock Assert-NAVGitAdministrator { }
            Mock Assert-NAVGitBcContainerHelper { }
            Mock New-NAVGitContainer { }
            Mock Import-NAVGitObjects { }
            $env:NAVGIT_SETTINGS_PATH = Join-Path $TestDrive 'no-settings.json'
        }
        AfterAll {
            Remove-Item Env:\NAVGIT_SETTINGS_PATH -ErrorAction SilentlyContinue
        }

        It 'builds the container and imports the objects' {
            Mock Test-BcContainer { $false }
            Update-NAVGitContainer -Path $repo
            Should -Invoke New-NAVGitContainer -Times 1 -Exactly -ParameterFilter { $Force }
            Should -Invoke Import-NAVGitObjects -Times 1 -Exactly
        }

        It 'only shows the command with -WhatIf' {
            Update-NAVGitContainer -Path $repo -WhatIf
            Should -Invoke New-NAVGitContainer -Times 1 -Exactly -ParameterFilter { $WhatIf }
            Should -Invoke Import-NAVGitObjects -Times 0 -Exactly
        }
    }
}
