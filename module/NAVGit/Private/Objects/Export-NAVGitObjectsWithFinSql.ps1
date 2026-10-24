function Export-NAVGitObjectsWithFinSql {
    <#
    .SYNOPSIS
        Exports objects with the finsql.exe on the host (the client folder copied by -includeCSide) and splits them,
        inside the container, into one file per object in -ObjectsFolder (a staging folder shared with the container).
        finsql writes the name of an Automation from the type library registered on the machine it runs on. Server
        Core containers lack most type libraries (TAPI, Office, ...) and would write
        'Unknown Automation Server.Unknown Class'; the host has them, as on the developer's own machine.
        The split is done the way Export-NavContainerObjects does it, so the files are byte for byte the same.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Context,

        [Parameter(Mandatory)]
        [hashtable] $State,

        [Parameter(Mandatory)]
        [string] $ObjectsFolder,

        [string] $Filter
    )

    $finsqlFolder = Join-Path $ObjectsFolder 'finsql'
    New-Item -ItemType Directory -Path $finsqlFolder -Force | Out-Null
    $objectsFile = Join-Path $finsqlFolder 'objects.txt'

    $exportFilter = Get-NAVGitExportFilter -Filter $Filter -NavVersion $State.navVersion
    Invoke-NAVGitFinSqlCommand -State $State -SqlCredential $Context.SqlCredential -WorkFolder $finsqlFolder -Command ExportObjects -Parameters ([ordered]@{
            file                    = $objectsFile
            filter                  = $exportFilter
            exporttxtskipunlicensed = '1'
        })

    if ((Test-Path -LiteralPath $objectsFile -PathType Leaf) -and (Get-Item -LiteralPath $objectsFile).Length -gt 0) {
        $containerFolder = Get-BcContainerPath -containerName $Context.ContainerName -path $ObjectsFolder -throw
        Invoke-ScriptInBcContainer -containerName $Context.ContainerName -scriptblock {
            param($folder)

            $objectsFile = Join-Path $folder 'finsql\objects.txt'
            # Same as Export-NavContainerObjects: the split reads the system code page, finsql writes OEM.
            $utf8 = [System.Text.Encoding]::Default.BodyName -eq 'utf-8'
            if ($utf8) {
                $encoding = [System.Text.Encoding]::GetEncoding((Get-Culture).TextInfo.OEMCodePage)
                [System.IO.File]::WriteAllText($objectsFile, [System.IO.File]::ReadAllText($objectsFile, $encoding), [System.Text.Encoding]::UTF8)
            }
            Split-NAVApplicationObjectFile -Source $objectsFile -Destination $folder | Out-Null
            if ($utf8) {
                Get-ChildItem -Path (Join-Path $folder '*.txt') | ForEach-Object {
                    [System.IO.File]::WriteAllText($_.FullName, [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8), $encoding)
                }
            }
        } -argumentList $containerFolder
    }
    Remove-Item -LiteralPath $finsqlFolder -Recurse -Force -ErrorAction SilentlyContinue
}

function Get-NAVGitExportFilter {
    <#
    .SYNOPSIS
        The finsql export filter. From NAV version 14 the system objects are left out unless the filter selects IDs,
        as Export-NavContainerObjects does.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string] $Filter,

        [string] $NavVersion
    )

    $major = 0
    if ($NavVersion) { $major = ([version]$NavVersion).Major }
    if ($major -lt 14) {
        return $Filter
    }
    if (-not $Filter) {
        return 'Id=1..1999999999'
    }
    if ($Filter.StartsWith('Id=', [System.StringComparison]::OrdinalIgnoreCase) -or $Filter.ToLowerInvariant().Contains(';id=')) {
        return $Filter
    }
    return "$Filter;Id=1..1999999999"
}

function Get-NAVGitFinSqlCommandArguments {
    <#
    .SYNOPSIS
        finsql.exe command line for a command= run against the container database: database connection, a log file
        and an own .zup in -WorkFolder (so the developer's C/SIDE settings are not touched), then -Parameters.
        Empty parameter values are left out.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State,

        [Parameter(Mandatory)]
        [string] $Command,

        [Parameter(Mandatory)]
        [string] $WorkFolder,

        [System.Collections.IDictionary] $Parameters = @{},

        [pscredential] $SqlCredential
    )

    $arguments = [ordered]@{
        command    = $Command
        servername = $State.hostDatabaseServer
        database   = $State.databaseName
    }
    if ($State.auth -eq 'Windows' -or -not $SqlCredential) {
        $arguments.ntauthentication = '1'
    }
    else {
        $password = $SqlCredential.GetNetworkCredential().Password
        if ($password.Contains('"')) {
            throw 'The container password contains a double quote ("), which finsql.exe cannot be given on its command line. Use another password (New-NAVGitContainer -ResetCredential).'
        }
        $arguments.ntauthentication = '0'
        $arguments.username = $SqlCredential.UserName
        $arguments.password = $password
    }
    foreach ($key in $Parameters.Keys) {
        $arguments[$key] = $Parameters[$key]
    }
    $arguments.logfile = Join-Path $WorkFolder 'finsql.log'
    $arguments.id = Join-Path $WorkFolder 'navgit.zup'

    $parts = foreach ($key in $arguments.Keys) {
        $value = "$($arguments[$key])"
        if ($value -eq '') { continue }
        if ($value -match '^\d+$' -or $key -eq 'command') {
            "$key=$value"
        }
        else {
            "$key=`"$value`""
        }
    }
    return ($parts -join ',')
}

function Invoke-NAVGitFinSqlCommand {
    <#
    .SYNOPSIS
        Runs finsql.exe from the container's client folder on the host with command=<Command> and waits for it.
        Throws when finsql did not finish or wrote errors to its log.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State,

        [Parameter(Mandatory)]
        [string] $Command,

        [Parameter(Mandatory)]
        [string] $WorkFolder,

        [System.Collections.IDictionary] $Parameters = @{},

        [pscredential] $SqlCredential
    )

    $finsql = Join-Path $State.clientFolder 'finsql.exe'
    $arguments = Get-NAVGitFinSqlCommandArguments -State $State -Command $Command -WorkFolder $WorkFolder -Parameters $Parameters -SqlCredential $SqlCredential
    $logFile = Join-Path $WorkFolder 'finsql.log'
    $resultFile = Join-Path $WorkFolder 'navcommandresult.txt'
    Remove-Item -LiteralPath $logFile, $resultFile -Force -ErrorAction SilentlyContinue

    Write-NAVGitLog "`"$finsql`" $($arguments -replace 'password="[^"]*"', 'password="***"')" -Level Detail
    $process = Start-Process -FilePath $finsql -ArgumentList $arguments -WorkingDirectory $State.clientFolder -WindowStyle Hidden -Wait -PassThru

    # finsql writes navcommandresult.txt next to the log file when the command ran, and the log only on errors.
    $log = ''
    if (Test-Path -LiteralPath $logFile -PathType Leaf) {
        $log = (Get-Content -LiteralPath $logFile -Raw).Trim()
    }
    if ($log) {
        throw "finsql.exe $Command failed:$([Environment]::NewLine)$log"
    }
    if (-not (Test-Path -LiteralPath $resultFile -PathType Leaf)) {
        throw "finsql.exe $Command did not finish (exit code $($process.ExitCode)). Is the container running?"
    }
}
