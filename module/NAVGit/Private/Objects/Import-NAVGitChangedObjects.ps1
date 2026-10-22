function Import-NAVGitChangedObjects {
    <#
    .SYNOPSIS
        Compares the repository's object files with the container database and imports the new and changed ones in one
        finsql run. Does not compile or synchronize.
        Without -IncludeTests the Tests folder is left out (returned as SkippedTests); with -TestsOnly only the Tests
        folder is imported. Test objects are always read, so they never count as missing (with -TestsOnly, Missing
        holds every object outside the Tests folder and means nothing).
        Returns [pscustomobject]@{ Imported; Unchanged; SkippedTests; Missing; Unparsed } (headers, except Unparsed).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Context,

        [switch] $IncludeTests,

        [switch] $TestsOnly,

        [switch] $Force
    )

    $config = $Context.Config

    $what = 'objects'
    if ($TestsOnly) {
        $what = 'test objects'
        Write-NAVGitLog "Reading objects from $($config.testsPath)" -Level Step
    }
    else {
        Write-NAVGitLog "Reading objects from $($config.objectsPath) and $($config.testsPath)" -Level Step
    }
    $repoObjects = @(Get-NAVGitRepoObjects -Config $config)
    if ($TestsOnly) {
        $repoObjects = @($repoObjects | Where-Object { Test-NAVGitPathInFolder -Path $_.Path -Folder $config.testsPath })
    }
    Write-NAVGitLog "Reading objects from container '$($Context.ContainerName)'" -Level Step
    $dbObjects = @(Get-NAVGitDbObjects -ContainerName $Context.ContainerName)

    $comparison = Compare-NAVGitObjects -RepoObjects $repoObjects -DbObjects $dbObjects -DateFormat $config.import.dateFormat -Force:$Force

    # Test objects need the test toolkit; without it they would only fail to compile.
    $toImport = @($comparison.ToImport)
    $skippedTests = @()
    if (-not ($IncludeTests -or $TestsOnly)) {
        $skippedTests = @($toImport | Where-Object { Test-NAVGitPathInFolder -Path $_.Path -Folder $config.testsPath })
        $toImport = @($toImport | Where-Object { -not (Test-NAVGitPathInFolder -Path $_.Path -Folder $config.testsPath) })
    }

    Write-NAVGitLog "$($repoObjects.Count) $what in Git: $($toImport.Count) to import, $($comparison.Unchanged.Count) unchanged"
    if ($comparison.Unparsed -gt 0) {
        Write-NAVGitLog "$($comparison.Unparsed) object(s) had a Date/Time that could not be read and are imported anyway. Set import.dateFormat (e.g. 'dd.MM.yy') if this happens for every object." -Level Warning
    }

    if ($toImport.Count -gt 0) {
        $staging = Get-NAVGitStagingFolder -ContainerName $Context.ContainerName
        try {
            $importFile = Join-Path $staging 'import.txt'
            Join-NAVGitObjectFiles -Path @($toImport | ForEach-Object { $_.Path }) -Destination $importFile

            Write-NAVGitLog "Importing $($toImport.Count) $what" -Level Step
            Import-ObjectsToNavContainer -containerName $Context.ContainerName -objectsFile $importFile `
                -sqlCredential $Context.SqlCredential -ImportAction Overwrite -SynchronizeSchemaChanges $config.import.syncSchema
        }
        finally {
            Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    return [pscustomobject]@{
        Imported     = $toImport
        Unchanged    = @($comparison.Unchanged)
        SkippedTests = $skippedTests
        Missing      = @($comparison.Missing)
        Unparsed     = $comparison.Unparsed
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
