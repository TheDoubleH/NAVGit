function Import-NAVGitObjects {
    <#
    .SYNOPSIS
        Import All GIT Objects to NAV: imports changed objects from the Objects and Tests folders, compiles and syncs.
    .DESCRIPTION
        Every object file in the repository (Objects and Tests) is compared with the database on Version List,
        Modified, Date and Time. New and changed objects are imported in one finsql run, then uncompiled objects are
        compiled and the schema is force-synchronized. Objects in the database that are not in Git (usually objects
        outside the license range) are handled by import.deleteMissing: 'skip' (default) only writes a count to the
        verbose output, 'warn' lists them, 'mark' sets their Version List to '#DELETE' and lists them. A deleteMissing
        in the user settings overrides the repository's.
        Test objects (the Tests folder) need the test toolkit, so they are only imported when includeTestToolkit is
        set in navgit.json, with -IncludeTests, or when they were imported into this container before (by this
        command or Import-NAVGitTestToolkit). They are always read, so they never count as missing.
        Importing them is saved in the container state, so Export-NAVGitObjects knows it may delete missing test files.
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

    # Once the test objects are in the container, keep them current: an export would otherwise write the older
    # versions from the database back over the changes in Git.
    $includeTests = $IncludeTests -or $config.includeTestToolkit -or
        (Test-NAVGitTestsImported -ContainerName $context.ContainerName -Config $config)

    $import = Import-NAVGitChangedObjects -Context $context -IncludeTests:$includeTests -Force:$Force
    $toImport = @($import.Imported)
    $skippedTests = @($import.SkippedTests)
    if ($includeTests) {
        Set-NAVGitContainerStateValue -ContainerName $context.ContainerName -Name 'testsImported' -Value $true
    }

    if ($skippedTests.Count -gt 0) {
        Write-NAVGitLog "$($skippedTests.Count) changed test object(s) in $($config.paths.tests) are not imported because includeTestToolkit is off. Run Import Test Toolkit, which also imports them, or set `"includeTestToolkit`": true in navgit.json." -Level Warning
    }

    $uncompiled = @()
    $missing = @($import.Missing | Where-Object { $_.VersionList -ne '#DELETE' })
    if ($missing.Count -gt 0) {
        $list = ($missing | Select-Object -First 25 | ForEach-Object { "  $($_.Type) $($_.Id) $($_.Name)" }) -join [Environment]::NewLine
        switch ($config.import.deleteMissing) {
            'mark' {
                Set-NAVGitObjectsDeleted -ContainerName $context.ContainerName -Objects $missing
                Write-NAVGitLog "$($missing.Count) object(s) are not in Git and were marked with Version List '#DELETE':$([Environment]::NewLine)$list" -Level Warning
            }
            'warn' {
                Write-NAVGitLog "$($missing.Count) object(s) are in the database but not in Git:$([Environment]::NewLine)$list" -Level Warning
            }
            default {
                # Usually objects outside the license range that can't be exported; not worth a warning on every import.
                Write-NAVGitLog "$($missing.Count) object(s) are in the database but not in Git (set import.deleteMissing to 'warn' to list them)." -Level Detail
            }
        }
    }

    if ($toImport.Count -gt 0) {
        $uncompiled = @(Invoke-NAVGitContainerCompile -Context $context)
        Invoke-NAVGitForceSync -ContainerName $context.ContainerName
    }

    Write-NAVGitLog ("Import finished ({0:mm\:ss})" -f $stopwatch.Elapsed) -Level Success
    return [pscustomobject]@{
        Imported     = $toImport.Count
        Unchanged    = $import.Unchanged.Count
        SkippedTests = $skippedTests.Count
        Missing      = $missing.Count
        Uncompiled   = $uncompiled.Count
    }
}
