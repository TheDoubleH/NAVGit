# Shared helpers for NavGit tests. Dot-source from BeforeAll.

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
        defaultAuth              = ''
        defaultIsolation         = ''
        bcContainerHelperVersion = ''
        settingsPath             = 'TestDrive:\settings.json'
    }
    foreach ($key in $Settings.Keys) { $result[$key] = $Settings[$key] }
    return $result
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
function global:New-BcContainer {
    param(
        [switch]$accept_eula, [switch]$accept_outdated, $containerName, $artifactUrl, $imageName, $bakFile, $licenseFile,
        [pscredential]$Credential, $auth, $isolation, $memoryLimit, $dns, [switch]$includeCSide, [switch]$doNotExportObjectsToText,
        [switch]$enableSymbolLoading, [switch]$includeTestToolkit, [switch]$includeTestLibrariesOnly, [switch]$updateHosts,
        $shortcuts, $restart, $myScripts, [string[]]$additionalParameters
    )
}
