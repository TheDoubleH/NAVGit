function Get-NAVGitContainerStatePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName
    )

    return Join-Path (Get-NAVGitDataPath -Name 'containers') "$ContainerName.json"
}

function Get-NAVGitContainerState {
    <#
    .SYNOPSIS
        Reads the saved state of a container (%LOCALAPPDATA%\NAVGit\containers\<name>.json), or $null when there is none.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName
    )

    $path = Get-NAVGitContainerStatePath -ContainerName $ContainerName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $null
    }
    return ConvertTo-NAVGitHashtable (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Save-NAVGitContainerState {
    <#
    .SYNOPSIS
        Reads the container's server configuration (requires elevation and BcContainerHelper) and saves everything the
        client commands need, so those can later run without elevation or docker access.
        testsImported is only written when -TestsImported is given; see Test-NAVGitTestsImported.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config,

        [string] $ArtifactUrl,

        [string] $BackupPath,

        [bool] $TestsImported
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
        hostDatabaseServer     = Get-NAVGitHostDatabaseServer -ContainerName $containerName -DatabaseServer $server.DatabaseServer -DatabaseInstance $server.DatabaseInstance
        clientServicesPort     = [int]$server.ClientServicesPort
        managementServicesPort = [int]$server.ManagementServicesPort
        enableSymbolLoading    = ($server.EnableSymbolLoadingAtServerStartup -eq 'True')
        clientFolder           = Get-NAVGitClientFolder -ContainerName $containerName
        savedAt                = (Get-Date).ToString('o')
    }
    if ($PSBoundParameters.ContainsKey('TestsImported')) {
        $state.testsImported = $TestsImported
    }

    $path = Get-NAVGitContainerStatePath -ContainerName $containerName
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-NAVGitLog "Container state saved to $path" -Level Detail

    return Get-NAVGitContainerState -ContainerName $containerName
}

function Set-NAVGitContainerStateValue {
    <#
    .SYNOPSIS
        Sets one value in the saved state of a container. Does nothing when there is no saved state: a partial state
        file would make the client commands fail with a misleading message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName,

        [Parameter(Mandatory)]
        [string] $Name,

        $Value
    )

    $path = Get-NAVGitContainerStatePath -ContainerName $ContainerName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-NAVGitLog "No saved state for '$ContainerName', so $Name was not saved. Run Update-NAVGitContainerState to create it." -Level Detail
        return
    }

    # Kept as PSCustomObject so the property order of the file stays the same.
    $state = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $current = $state.PSObject.Properties[$Name]
    if ($current -and $current.Value -eq $Value) {
        return
    }
    $state | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding UTF8
}

function Test-NAVGitTestsImported {
    <#
    .SYNOPSIS
        True when the objects in the Tests folder have been imported into the container (testsImported in the saved
        state, set by Import-NAVGitObjects and Import-NAVGitTestToolkit). Without the value - a state saved by an
        older NAVGit, or no state at all - includeTestToolkit decides, as that is what earlier imports went by.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName,

        [Parameter(Mandatory)]
        [hashtable] $Config
    )

    $state = Get-NAVGitContainerState -ContainerName $ContainerName
    if ($state -and $state.ContainsKey('testsImported')) {
        return [bool]$state.testsImported
    }
    return [bool]$Config.includeTestToolkit
}

function Remove-NAVGitContainerState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName
    )

    $path = Get-NAVGitContainerStatePath -ContainerName $ContainerName
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Remove-Item -LiteralPath $path -Force
    }
}

function Get-NAVGitHostDatabaseServer {
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

function Get-NAVGitClientFolder {
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
