function Export-NavGitObjects {
    <#
    .SYNOPSIS
        Export NAV objects to GIT: exports objects from the container and places them in the Objects or Tests folder.
    .DESCRIPTION
        All objects (or those matching export.filter) are exported, one file per object (e.g. TAB18.TXT). Test objects -
        Version List matching testObjects.versionListPattern, or codeunits with Subtype=Test - go to the Tests folder,
        all others to the Objects folder. An object that changed category is moved. With a full export (no
        export.filter), object files of objects that no longer exist in the database are deleted.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath
    )

    $context = Initialize-NavGitContainerCommand -Path $Path -Operation 'Exporting objects'
    $config = $context.Config
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Only a full export can tell which objects were deleted.
    $fullExport = -not $config.export.filter
    $description = 'all objects'
    if (-not $fullExport) {
        $description = $config.export.filter
        Write-NavGitLog "export.filter '$($config.export.filter)' selects part of the objects; object files that were not exported are kept." -Level Warning
    }

    $staging = Get-NavGitStagingFolder -ContainerName $context.ContainerName
    try {
        Write-NavGitLog "Exporting $description from '$($context.ContainerName)'" -Level Step
        Export-NavContainerObjects -containerName $context.ContainerName -objectsFolder $staging -filter $config.export.filter `
            -exportTo $config.export.format -sqlCredential $context.SqlCredential

        Write-NavGitLog 'Updating the Objects and Tests folders' -Level Step
        $result = Sync-NavGitObjectFolder -SourceFolder $staging -ObjectsPath $config.objectsPath -TestsPath $config.testsPath `
            -TestObjects $config.testObjects -RemoveMissing:$fullExport
    }
    finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-NavGitLog ("Export finished ({0:mm\:ss}): {1} added, {2} changed, {3} moved, {4} removed, {5} unchanged; {6} test object(s) in {7}" -f
        $stopwatch.Elapsed, $result.Added.Count, $result.Changed.Count, $result.Moved.Count, $result.Removed.Count,
        $result.Unchanged.Count, $result.Tests.Count, $config.paths.tests) -Level Success
    return $result
}
