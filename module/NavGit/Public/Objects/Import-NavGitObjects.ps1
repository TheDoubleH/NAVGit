function Import-NavGitObjects {
    <#
    .SYNOPSIS
        Import All GIT Objects to NAV: imports changed objects from the Objects and Tests folders, compiles and syncs.
    .DESCRIPTION
        Every object file in the repository (Objects and Tests) is compared with the database on Version List,
        Modified, Date and Time. New and changed objects are imported in one finsql run, then uncompiled objects are
        compiled and the schema is force-synchronized. Objects in the database that are not in Git are reported
        (import.deleteMissing = 'warn') or marked with Version List '#DELETE' ('mark').
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    .PARAMETER Force
        Import every object file, also unchanged ones.
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [switch] $Force
    )

    $context = Initialize-NavGitContainerCommand -Path $Path -Operation 'Importing objects'
    $config = $context.Config
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    Write-NavGitLog "Reading objects from $($config.objectsPath) and $($config.testsPath)" -Level Step
    $repoObjects = @(Get-NavGitRepoObjects -Config $config)
    Write-NavGitLog "Reading objects from container '$($context.ContainerName)'" -Level Step
    $dbObjects = @(Get-NavGitDbObjects -ContainerName $context.ContainerName)

    $comparison = Compare-NavGitObjects -RepoObjects $repoObjects -DbObjects $dbObjects -DateFormat $config.import.dateFormat -Force:$Force
    Write-NavGitLog "$($repoObjects.Count) objects in Git: $($comparison.ToImport.Count) to import, $($comparison.Unchanged.Count) unchanged"
    if ($comparison.Unparsed -gt 0) {
        Write-NavGitLog "$($comparison.Unparsed) object(s) had a Date/Time that could not be read and are imported anyway. Set import.dateFormat (e.g. 'dd.MM.yy') if this happens for every object." -Level Warning
    }

    $uncompiled = @()
    if ($comparison.ToImport.Count -gt 0) {
        $staging = Get-NavGitStagingFolder -ContainerName $context.ContainerName
        try {
            $importFile = Join-Path $staging 'import.txt'
            Join-NavGitObjectFiles -Path @($comparison.ToImport | ForEach-Object { $_.Path }) -Destination $importFile

            Write-NavGitLog "Importing $($comparison.ToImport.Count) object(s)" -Level Step
            Import-ObjectsToNavContainer -containerName $context.ContainerName -objectsFile $importFile `
                -sqlCredential $context.SqlCredential -ImportAction Overwrite -SynchronizeSchemaChanges $config.import.syncSchema
        }
        finally {
            Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $missing = @($comparison.Missing | Where-Object { $_.VersionList -ne '#DELETE' })
    if ($missing.Count -gt 0) {
        $list = ($missing | Select-Object -First 25 | ForEach-Object { "  $($_.Type) $($_.Id) $($_.Name)" }) -join [Environment]::NewLine
        if ($config.import.deleteMissing -eq 'mark') {
            Set-NavGitObjectsDeleted -ContainerName $context.ContainerName -Objects $missing
            Write-NavGitLog "$($missing.Count) object(s) are not in Git and were marked with Version List '#DELETE':$([Environment]::NewLine)$list" -Level Warning
        }
        else {
            Write-NavGitLog "$($missing.Count) object(s) are in the database but not in Git:$([Environment]::NewLine)$list" -Level Warning
        }
    }

    if ($comparison.ToImport.Count -gt 0) {
        $uncompiled = @(Invoke-NavGitCompile -Context $context)
        Invoke-NavGitForceSync -ContainerName $context.ContainerName
    }

    Write-NavGitLog ("Import finished ({0:mm\:ss})" -f $stopwatch.Elapsed) -Level Success
    return [pscustomobject]@{
        Imported   = $comparison.ToImport.Count
        Unchanged  = $comparison.Unchanged.Count
        Missing    = $missing.Count
        Uncompiled = $uncompiled.Count
    }
}
