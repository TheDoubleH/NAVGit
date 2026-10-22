# Shared helpers for NAVGit tests. Dot-source from BeforeAll.

function New-TestRepository {
    <#
        Creates a folder in TestDrive with a navgit.json built from the given hashtable and returns its path.
    #>
    param(
        [hashtable] $Config = @{},
        [string] $Name = ([guid]::NewGuid().ToString('N').Substring(0, 8)),
        [string] $RawJson
    )

    $path = Join-Path $TestDrive $Name
    New-Item -ItemType Directory -Path $path -Force | Out-Null

    if ($RawJson) {
        $json = $RawJson
    }
    else {
        $base = @{
            projectName = 'Customer_NAV2018'
            artifact    = @{ nav = '2018'; cu = 'cu30'; country = 'no' }
        }
        foreach ($key in $Config.Keys) { $base[$key] = $Config[$key] }
        foreach ($key in @($base.Keys)) { if ($null -eq $base[$key]) { $base.Remove($key) } }
        $json = $base | ConvertTo-Json -Depth 10
    }
    Set-Content -LiteralPath (Join-Path $path 'navgit.json') -Value $json -Encoding UTF8
    return $path
}

function New-TestUserSettings {
    param([hashtable] $Settings = @{})

    $result = @{
        backupFolder             = ''
        licenseFolder            = ''
        bcContainerHelperVersion = ''
        auth                     = ''
        isolation                = ''
        showBcContainerCommand   = $null
        deleteMissing            = ''
        containerName            = ''
        artifact                 = $null
        uidOffset                = ''
        settingsPath             = 'TestDrive:\settings.json'
    }
    foreach ($key in $Settings.Keys) { $result[$key] = $Settings[$key] }
    return $result
}

function New-TestObjectFile {
    <#
        Writes a minimal C/AL object file (OEM code page) and returns its path.
    #>
    param(
        [Parameter(Mandatory)] [string] $Folder,
        [string] $Type = 'Table',
        [int] $Id = 50000,
        [string] $Name = 'Test Object',
        [string] $VersionList = 'CUST1.00',
        [string] $Date = '24.11.17',
        [string] $Time = '12:00:00',
        [switch] $Modified,
        [string] $Subtype,
        [string] $FileName,
        [System.Text.Encoding] $Encoding = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
    )

    $prefix = @{ Table = 'TAB'; Codeunit = 'COD'; Page = 'PAG'; Report = 'REP'; XMLport = 'XML'; Query = 'QUE'; MenuSuite = 'MEN' }[$Type]
    if (-not $FileName) { $FileName = "$prefix$Id.TXT" }
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    $lines = @("OBJECT $Type $Id $Name", '{', '  OBJECT-PROPERTIES', '  {', "    Date=$Date;", "    Time=$Time;")
    if ($Modified) { $lines += '    Modified=Yes;' }
    $lines += @("    Version List=$VersionList;", '  }', '  PROPERTIES', '  {')
    if ($Subtype) { $lines += "    Subtype=$Subtype;" }
    $lines += @('    OnRun=BEGIN', '          END;', '', '  }', '  CODE', '  {', '', '    BEGIN', '    END.', '  }', '}', '')

    $path = Join-Path $Folder $FileName
    [System.IO.File]::WriteAllText($path, ($lines -join "`r`n"), $Encoding)
    return $path
}

function New-TestDbObject {
    param(
        [string] $Type = 'Table', [int] $Id = 50000, [string] $Name = 'Test Object', [string] $VersionList = 'CUST1.00',
        [datetime] $Date = '2017-11-24', [timespan] $Time = '12:00:00', [bool] $Modified = $false, [bool] $Compiled = $true
    )
    $typeIds = @{ Table = 1; Report = 3; Codeunit = 5; XMLport = 6; MenuSuite = 7; Page = 8; Query = 9 }
    [pscustomobject]@{
        Type = $Type; TypeId = $typeIds[$Type]; Id = $Id; Name = $Name; Modified = $Modified; VersionList = $VersionList
        Date = $Date; Time = $Time; Compiled = $Compiled
    }
}

function New-TestCredential {
    param([string] $UserName = 'admin', [string] $Password = 'P@ssw0rd!')
    return New-Object System.Management.Automation.PSCredential($UserName, (ConvertTo-SecureString $Password -AsPlainText -Force))
}

# Stubs so BcContainerHelper does not have to be imported (or exist) to mock its commands.
# Parameter names must match BcContainerHelper so ParameterFilter and splatting work.
function global:Get-BcArtifactUrl { param($type, $country, $version, $select, $storageAccount, $sasToken, $after, $before, [switch]$accept_insiderEula, [switch]$doNotCheckPlatform) }
function global:Get-NavArtifactUrl { param($nav, $cu, $country, $select) }
function global:Test-BcContainer { param($containerName, [switch]$doNotIncludeStoppedContainers) }
function global:Remove-BcContainer { param($containerName) }
function global:Get-BcContainerServerConfiguration { param($ContainerName) }
function global:Get-BcContainerArtifactUrl { param($containerName) }
function global:Get-BcContainerNavVersion { param($containerOrImageName) }
function global:Invoke-ScriptInBcContainer { param($containerName, [scriptblock]$scriptblock, [object[]]$argumentList, $useSession, $usePwsh) }
function global:Import-ObjectsToNavContainer { param($containerName, $objectsFile, [pscredential]$sqlCredential, $ImportAction, $SynchronizeSchemaChanges, [switch]$suppressBuildSearchIndex) }
function global:Export-NavContainerObjects { param($containerName, $objectsFolder, $filter, [pscredential]$sqlCredential, $exportTo, [switch]$includeSystemObjects, [switch]$PreserveFormatting) }
function global:Get-BcContainerPath { param($containerName, $path, [switch]$throw) }
function global:Import-TestToolkitToBcContainer { param($containerName, [pscredential]$sqlCredential, [pscredential]$credential, [switch]$includeTestLibrariesOnly, $testToolkitCountry, [switch]$doNotUpdateSymbols) }
function global:Compile-ObjectsInNavContainer { param($containerName, $filter, [pscredential]$sqlCredential, $SynchronizeSchemaChanges, [switch]$generatesymbolreference) }
function global:New-BcContainer {
    param(
        [switch]$accept_eula, [switch]$accept_outdated, $containerName, $artifactUrl, $imageName, $bakFile, $licenseFile,
        [pscredential]$Credential, $auth, $isolation, $memoryLimit, $dns, [switch]$includeCSide, [switch]$doNotExportObjectsToText,
        [switch]$enableSymbolLoading, [switch]$includeTestToolkit, [switch]$includeTestLibrariesOnly, [switch]$updateHosts,
        $shortcuts, $restart, $myScripts, [string[]]$additionalParameters
    )
}
