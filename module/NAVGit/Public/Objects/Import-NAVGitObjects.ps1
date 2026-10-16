function Import-NAVGitObjects {
    <#
    .SYNOPSIS
        Import All GIT Objects to NAV: imports changed objects from the Objects and Tests folders, compiles and syncs.
    .DESCRIPTION
        Every object file in the repository (Objects and Tests) is compared with the database on Version List,
        Modified, Date and Time. New and changed objects are imported in one finsql run, then uncompiled objects are
        compiled and the schema is force-synchronized. Objects in the database that are not in Git are reported
        (import.deleteMissing = 'warn') or marked with Version List '#DELETE' ('mark').
        Test objects (the Tests folder) need the test toolkit, so they are only imported when includeTestToolkit is
        set in navgit.json, or with -IncludeTests. They are always read, so they never count as missing.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    .PARAMETER Force
        Import every object file, also unchanged ones.
    .PARAMETER IncludeTests
        Import the Tests folder even though includeTestToolkit is off (e.g. after Import-NAVGitTestToolkit).
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [switch] $Force,

        [switch] $IncludeTests
    )

    $context = Initialize-NAVGitContainerCommand -Path $Path -Operation 'Importing objects'
    $config = $context.Config
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    Write-NAVGitLog "Reading objects from $($config.objectsPath) and $($config.testsPath)" -Level Step
    $repoObjects = @(Get-NAVGitRepoObjects -Config $config)
    Write-NAVGitLog "Reading objects from container '$($context.ContainerName)'" -Level Step
    $dbObjects = @(Get-NAVGitDbObjects -ContainerName $context.ContainerName)

    $comparison = Compare-NAVGitObjects -RepoObjects $repoObjects -DbObjects $dbObjects -DateFormat $config.import.dateFormat -Force:$Force

    # Test objects need the test toolkit; without it they would only fail to compile.
    $toImport = @($comparison.ToImport)
    $skippedTests = @()
    if (-not ($config.includeTestToolkit -or $IncludeTests)) {
        $skippedTests = @($toImport | Where-Object { Test-NAVGitPathInFolder -Path $_.Path -Folder $config.testsPath })
        $toImport = @($toImport | Where-Object { -not (Test-NAVGitPathInFolder -Path $_.Path -Folder $config.testsPath) })
    }

    Write-NAVGitLog "$($repoObjects.Count) objects in Git: $($toImport.Count) to import, $($comparison.Unchanged.Count) unchanged"
    if ($skippedTests.Count -gt 0) {
        Write-NAVGitLog "$($skippedTests.Count) changed test object(s) in $($config.paths.tests) are not imported because includeTestToolkit is off. Set `"includeTestToolkit`": true in navgit.json, or import the toolkit and use -IncludeTests." -Level Warning
    }
    if ($comparison.Unparsed -gt 0) {
        Write-NAVGitLog "$($comparison.Unparsed) object(s) had a Date/Time that could not be read and are imported anyway. Set import.dateFormat (e.g. 'dd.MM.yy') if this happens for every object." -Level Warning
    }

    $uncompiled = @()
    if ($toImport.Count -gt 0) {
        $staging = Get-NAVGitStagingFolder -ContainerName $context.ContainerName
        try {
            $importFile = Join-Path $staging 'import.txt'
            Join-NAVGitObjectFiles -Path @($toImport | ForEach-Object { $_.Path }) -Destination $importFile

            Write-NAVGitLog "Importing $($toImport.Count) object(s)" -Level Step
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
            Set-NAVGitObjectsDeleted -ContainerName $context.ContainerName -Objects $missing
            Write-NAVGitLog "$($missing.Count) object(s) are not in Git and were marked with Version List '#DELETE':$([Environment]::NewLine)$list" -Level Warning
        }
        else {
            Write-NAVGitLog "$($missing.Count) object(s) are in the database but not in Git:$([Environment]::NewLine)$list" -Level Warning
        }
    }

    if ($toImport.Count -gt 0) {
        $uncompiled = @(Invoke-NAVGitContainerCompile -Context $context)
        Invoke-NAVGitForceSync -ContainerName $context.ContainerName
    }

    Write-NAVGitLog ("Import finished ({0:mm\:ss})" -f $stopwatch.Elapsed) -Level Success
    return [pscustomobject]@{
        Imported     = $toImport.Count
        Unchanged    = $comparison.Unchanged.Count
        SkippedTests = $skippedTests.Count
        Missing      = $missing.Count
        Uncompiled   = $uncompiled.Count
    }
}

function Test-NAVGitPathInFolder {
    # True when the file is directly inside the folder (object folders are flat).
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Folder
    )

    $parent = [System.IO.Path]::GetFullPath((Split-Path -Path $Path -Parent)).TrimEnd('\')
    return $parent -ieq [System.IO.Path]::GetFullPath($Folder).TrimEnd('\')
}
