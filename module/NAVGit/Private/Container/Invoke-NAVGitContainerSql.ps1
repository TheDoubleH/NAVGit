function Invoke-NAVGitContainerSql {
    <#
    .SYNOPSIS
        Runs a SQL query against the container's NAV database from inside the container (Invoke-Sqlcmd as the
        container administrator, the same way BcContainerHelper does). Rows come back as PSCustomObjects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName,

        [Parameter(Mandatory)]
        [string] $Query
    )

    $json = Invoke-ScriptInBcContainer -containerName $ContainerName -argumentList $Query -scriptblock {
        param($Query)

        $customConfigFile = Join-Path (Get-Item 'C:\Program Files\Microsoft Dynamics NAV\*\Service').FullName 'CustomSettings.config'
        [xml]$customConfig = [System.IO.File]::ReadAllText($customConfigFile)
        $databaseServer = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseServer']").Value
        $databaseInstance = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseInstance']").Value
        $databaseName = $customConfig.SelectSingleNode("//appSettings/add[@key='DatabaseName']").Value
        if ($databaseInstance) { $databaseServer += "\$databaseInstance" }

        $rows = @(Invoke-Sqlcmd -ServerInstance $databaseServer -Database $databaseName -Query $Query -QueryTimeout 600 -MaxCharLength 8000)
        $result = @(foreach ($row in $rows) {
                if ($null -eq $row -or -not $row.Table) { continue }
                $item = [ordered]@{}
                foreach ($column in $row.Table.Columns) {
                    $value = $row[$column.ColumnName]
                    if ($value -is [System.DBNull]) { $value = $null }
                    $item[$column.ColumnName] = $value
                }
                $item
            })
        ConvertTo-Json -InputObject $result -Depth 3 -Compress
    }

    if (-not $json) {
        return @()
    }
    return @(ConvertFrom-Json -InputObject ($json -join '') | ForEach-Object { $_ })
}

function Get-NAVGitDbObjects {
    <#
    .SYNOPSIS
        Objects in the container database (no TableData). System objects (>= 2000000000) are included so exported
        system tables in the repository compare as unchanged; Compare-NAVGitObjects never reports them as missing.
        Returns [pscustomobject]@{ Type; TypeId; Id; Name; Modified; VersionList; Date; Time; Compiled }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName
    )

    $query = @'
SELECT [Type], [ID], [Name], [Modified], [Version List] AS VersionList,
       CONVERT(varchar(19), [Date], 120) AS DateText, CONVERT(varchar(19), [Time], 120) AS TimeText, [Compiled]
FROM [dbo].[Object]
WHERE [Type] > 0 AND [Company Name] = ''
'@
    $rows = Invoke-NAVGitContainerSql -ContainerName $ContainerName -Query $query
    return @(foreach ($row in $rows) {
            [pscustomobject]@{
                Type        = Get-NAVGitObjectTypeName -TypeId ([int]$row.Type)
                TypeId      = [int]$row.Type
                Id          = [int]$row.ID
                Name        = $row.Name
                Modified    = ([int]$row.Modified -eq 1)
                VersionList = "$($row.VersionList)"
                Date        = ConvertFrom-NAVGitSqlDateTime -Text $row.DateText -Part Date
                Time        = ConvertFrom-NAVGitSqlDateTime -Text $row.TimeText -Part Time
                Compiled    = ([int]$row.Compiled -eq 1)
            }
        })
}

function Set-NAVGitObjectsDeleted {
    <#
    .SYNOPSIS
        Marks objects as deleted by setting their Version List to '#DELETE' (as AdvaniaGIT did); they can then be
        removed in C/SIDE with the filter Version List=#DELETE.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName,

        [Parameter(Mandatory)]
        [object[]] $Objects
    )

    $conditions = @($Objects | ForEach-Object { "([Type] = $([int]$_.TypeId) AND [ID] = $([int]$_.Id))" })
    # Keep statements reasonably small.
    for ($i = 0; $i -lt $conditions.Count; $i += 200) {
        $batch = $conditions[$i..([Math]::Min($i + 199, $conditions.Count - 1))] -join ' OR '
        $null = Invoke-NAVGitContainerSql -ContainerName $ContainerName -Query "UPDATE [dbo].[Object] SET [Version List] = '#DELETE' WHERE [Company Name] = '' AND ($batch)"
    }
}

function Get-NAVGitUncompiledObjects {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName
    )

    return @(Get-NAVGitDbObjects -ContainerName $ContainerName | Where-Object { -not $_.Compiled -and $_.Id -lt 2000000000 })
}
