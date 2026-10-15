function Get-NavGitContainerStatePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName
    )

    return Join-Path (Get-NavGitDataPath -Name 'containers') "$ContainerName.json"
}

function Get-NavGitContainerState {
    <#
    .SYNOPSIS
        Reads the saved state of a container (%LOCALAPPDATA%\NavGit\containers\<name>.json), or $null when there is none.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName
    )

    $path = Get-NavGitContainerStatePath -ContainerName $ContainerName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $null
    }
    return ConvertTo-NavGitHashtable (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Save-NavGitContainerState {
    <#
    .SYNOPSIS
        Reads the container's server configuration (requires elevation and BcContainerHelper) and saves everything the
        client commands need, so those can later run without elevation or docker access.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config,

        [string] $ArtifactUrl,

        [string] $BackupPath
    )

    $containerName = $Config.containerName
    $server = Get-BcContainerServerConfiguration -ContainerName $containerName
    if (-not $server -or -not $server.ServerInstance) {
        throw "Could not read the server configuration of container '$containerName'."
    }

    if (-not $ArtifactUrl) {
        $ArtifactUrl = Get-BcContainerArtifactUrl -containerName $containerName
    }
    # "11.0.43274.0-no"
    $navVersion = (Get-BcContainerNavVersion -containerOrImageName $containerName) -replace '-.*$', ''

    $state = [ordered]@{
        containerName          = $containerName
        repositoryPath         = $Config.repositoryPath
        artifactUrl            = $ArtifactUrl
        navVersion             = $navVersion
        backupFile             = $BackupPath
        auth                   = $server.ClientServicesCredentialType
        serverInstance         = $server.ServerInstance
        databaseServer         = $server.DatabaseServer
        databaseInstance       = $server.DatabaseInstance
        databaseName           = $server.DatabaseName
        hostDatabaseServer     = Get-NavGitHostDatabaseServer -ContainerName $containerName -DatabaseServer $server.DatabaseServer -DatabaseInstance $server.DatabaseInstance
        clientServicesPort     = [int]$server.ClientServicesPort
        managementServicesPort = [int]$server.ManagementServicesPort
        enableSymbolLoading    = ($server.EnableSymbolLoadingAtServerStartup -eq 'True')
        clientFolder           = Get-NavGitClientFolder -ContainerName $containerName
        savedAt                = (Get-Date).ToString('o')
    }

    $path = Get-NavGitContainerStatePath -ContainerName $containerName
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-NavGitLog "Container state saved to $path" -Level Detail

    return Get-NavGitContainerState -ContainerName $containerName
}

function Remove-NavGitContainerState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName
    )

    $path = Get-NavGitContainerStatePath -ContainerName $ContainerName
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Remove-Item -LiteralPath $path -Force
    }
}

function Get-NavGitHostDatabaseServer {
    <#
    .SYNOPSIS
        SQL server name as seen from the host, using the same rules as BcContainerHelper's C/SIDE shortcut:
        a database on localhost\SQLEXPRESS inside the container is reached as '<containerName>' from the host.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName,

        [string] $DatabaseServer,

        [string] $DatabaseInstance
    )

    if ($DatabaseServer -eq 'host.containerhelper.internal') {
        $server = 'localhost'
        if ($DatabaseInstance) { $server += "\$DatabaseInstance" }
        return $server
    }
    if (-not $DatabaseServer -or $DatabaseServer -eq 'localhost') {
        $server = $ContainerName
        if ($DatabaseInstance -and $DatabaseInstance -ne 'SQLEXPRESS') { $server += "\$DatabaseInstance" }
        return $server
    }
    $server = $DatabaseServer
    if ($DatabaseInstance) { $server += "\$DatabaseInstance" }
    return $server
}

function Get-NavGitClientFolder {
    <#
    .SYNOPSIS
        Host folder with the Windows client and finsql.exe, copied there by New-BcContainer -includeCSide:
        <hostHelperFolder>\Extensions\<container>\Program Files\<version>\RoleTailored Client. $null when missing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName,

        [string] $HostHelperFolder
    )

    if (-not $HostHelperFolder) {
        $helperConfig = Get-Variable -Name bcContainerHelperConfig -Scope Global -ValueOnly -ErrorAction SilentlyContinue
        if ($helperConfig -and $helperConfig.hostHelperFolder) {
            $HostHelperFolder = $helperConfig.hostHelperFolder
        }
        else {
            $HostHelperFolder = Join-Path $env:ProgramData 'BcContainerHelper'
        }
    }

    $programFiles = Join-Path $HostHelperFolder "Extensions\$ContainerName\Program Files"
    $folder = Get-Item -Path (Join-Path $programFiles '*\RoleTailored Client') -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($folder) {
        return $folder.FullName
    }
    return $null
}
