function Get-NavGitClientContext {
    <#
    .SYNOPSIS
        Common start of the client commands: configuration and saved container state, without elevation or docker.
        Returns [pscustomobject]@{ Config; State }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $config = Get-NavGitConfig -Path $Path
    $state = Get-NavGitContainerState -ContainerName $config.containerName
    if (-not $state) {
        throw "No container information for '$($config.containerName)'. Build the container with NavGit (New-NavGitContainer), or run Update-NavGitContainerState in an elevated session if it was created another way."
    }
    if (-not $state.clientFolder -or -not (Test-Path -LiteralPath $state.clientFolder -PathType Container)) {
        throw "The Windows client for '$($config.containerName)' was not found on this machine (container built without includeCSide?). Rebuild the container or run Update-NavGitContainerState."
    }
    if (-not (Test-NavGitContainerReachable -HostName $config.containerName -Port $state.clientServicesPort)) {
        Write-NavGitLog "Container '$($config.containerName)' does not answer on port $($state.clientServicesPort). Is it running? (docker start $($config.containerName))" -Level Warning
    }

    return [pscustomobject]@{ Config = $config; State = $state }
}

function Test-NavGitContainerReachable {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $HostName,

        [Parameter(Mandatory)]
        [int] $Port,

        [int] $TimeoutMilliseconds = 2000
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $connect.AsyncWaitHandle.WaitOne($TimeoutMilliseconds)) {
            return $false
        }
        $client.EndConnect($connect)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Get-NavGitFinSqlArguments {
    <#
    .SYNOPSIS
        finsql.exe arguments for the container, following BcContainerHelper's C/SIDE shortcut, plus the NAV server
        settings so C/SIDE can synchronize table schema when a table is saved.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State
    )

    $ntAuthentication = '0'
    if ($State.auth -eq 'Windows') { $ntAuthentication = '1' }

    $arguments = @(
        "servername=`"$($State.hostDatabaseServer)`""
        "database=`"$($State.databaseName)`""
        "ntauthentication=$ntAuthentication"
        "ID=`"$($State.containerName)`""
        "navservername=`"$($State.containerName)`""
        "navserverinstance=`"$($State.serverInstance)`""
        "navservermanagementport=$($State.managementServicesPort)"
    )
    $major = 0
    if ($State.navVersion) { $major = ([version]$State.navVersion).Major }
    if ($State.enableSymbolLoading -and $major -ge 11) {
        $arguments += 'generatesymbolreference=1'
    }
    return ($arguments -join ',')
}

function Get-NavGitClientArguments {
    <#
    .SYNOPSIS
        Microsoft.Dynamics.Nav.Client.exe arguments: the ClientUserSettings.config prepared by BcContainerHelper and
        optionally a profile.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State,

        [string] $ProfileId
    )

    $arguments = @("-settings:`"$(Join-Path $State.clientFolder 'ClientUserSettings.config')`"")
    if ($ProfileId) {
        $arguments += "-profile:`"$ProfileId`""
    }
    return $arguments
}

function Invoke-NavGitSql {
    <#
    .SYNOPSIS
        Runs a query from the host against the container database (reachable by container name thanks to updateHosts).
        Uses integrated security for Windows containers and 'sa' with the container password for NavUserPassword.
        No elevation or docker access needed. Returns rows as PSCustomObjects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State,

        [Parameter(Mandatory)]
        [string] $Query,

        [pscredential] $Credential,

        [int] $TimeoutSeconds = 15
    )

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source'] = $State.hostDatabaseServer
    $builder['Initial Catalog'] = $State.databaseName
    $builder['Connect Timeout'] = $TimeoutSeconds
    if ($State.auth -eq 'Windows') {
        $builder['Integrated Security'] = $true
    }
    else {
        if (-not $Credential) {
            throw 'A credential is required for NavUserPassword containers.'
        }
        $builder['User ID'] = 'sa'
        $builder['Password'] = $Credential.GetNetworkCredential().Password
    }

    $connection = New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = $TimeoutSeconds
        $table = New-Object System.Data.DataTable
        $null = $table.Load($command.ExecuteReader())

        return @(foreach ($row in $table.Rows) {
                $item = [ordered]@{}
                foreach ($column in $table.Columns) {
                    $value = $row[$column]
                    if ($value -is [System.DBNull]) { $value = $null }
                    $item[$column.ColumnName] = $value
                }
                [pscustomobject]$item
            })
    }
    catch {
        throw "SQL query against $($State.hostDatabaseServer)/$($State.databaseName) failed: $($_.Exception.Message)"
    }
    finally {
        $connection.Dispose()
    }
}
