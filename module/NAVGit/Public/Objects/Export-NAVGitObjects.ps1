function Export-NAVGitObjects {
    <#
    .SYNOPSIS
        Export NAV objects to GIT: exports objects from the container and places them in the Objects or Tests folder.
    .DESCRIPTION
        All objects (or those matching export.filter) are exported, one file per object (e.g. TAB18.TXT). Test objects -
        Version List matching testObjects.versionListPattern, or codeunits with Subtype=Test - go to the Tests folder,
        all others to the Objects folder. An object that changed category is moved. With a full export (no
        export.filter), object files of objects that no longer exist in the database are deleted. Files in the Tests
        folder are only deleted once the test objects have been imported into the container (Import-NAVGitObjects
        with tests, or Import-NAVGitTestToolkit); before that they are simply not in the database.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath
    )

    $context = Initialize-NAVGitContainerCommand -Path $Path -Operation 'Exporting objects'
    $config = $context.Config
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Only a full export can tell which objects were deleted.
    $fullExport = -not $config.export.filter
    $description = 'all objects'
    if (-not $fullExport) {
        $description = $config.export.filter
        Write-NAVGitLog "export.filter '$($config.export.filter)' selects part of the objects; object files that were not exported are kept." -Level Warning
    }

    # Test objects that were never imported are missing from the database, not deleted.
    $keepMissingTests = $fullExport -and -not (Test-NAVGitTestsImported -ContainerName $context.ContainerName -Config $config)

    $staging = Get-NAVGitStagingFolder -ContainerName $context.ContainerName
    try {
        Write-NAVGitLog "Exporting $description from '$($context.ContainerName)'" -Level Step
        Export-NavContainerObjects -containerName $context.ContainerName -objectsFolder $staging -filter $config.export.filter `
            -exportTo $config.export.format -sqlCredential $context.SqlCredential

        Write-NAVGitLog 'Updating the Objects and Tests folders' -Level Step
        $result = Sync-NAVGitObjectFolder -SourceFolder $staging -ObjectsPath $config.objectsPath -TestsPath $config.testsPath `
            -TestObjects $config.testObjects -RemoveMissing:$fullExport -KeepMissingTests:$keepMissingTests
    }
    finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($result.Kept.Count -gt 0) {
        Write-NAVGitLog "$($result.Kept.Count) file(s) in $($config.paths.tests) are not in the database and were kept: the test objects were never imported into this container. Run Import Test Toolkit to import them."
    }
    Write-NAVGitLog ("Export finished ({0:mm\:ss}): {1} added, {2} changed, {3} moved, {4} removed, {5} kept, {6} unchanged; {7} test object(s) in {8}" -f
        $stopwatch.Elapsed, $result.Added.Count, $result.Changed.Count, $result.Moved.Count, $result.Removed.Count,
        $result.Kept.Count, $result.Unchanged.Count, $result.Tests.Count, $config.paths.tests) -Level Success
    return $result
}
