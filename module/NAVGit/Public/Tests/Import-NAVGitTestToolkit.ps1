function Import-NAVGitTestToolkit {
    <#
    .SYNOPSIS
        Import Test Toolkit: imports the standard C/AL test toolkit (.fob files shipped in the container), then the
        repository's test objects, and compiles.
    .DESCRIPTION
        Uses Import-TestToolkitToBcContainer, which imports C:\TestToolKit\*.fob in the container and force-syncs.
        testToolkit.librariesOnly imports only the test libraries; testToolkit.country picks a localized toolkit.
        Then the new and changed objects in the Tests folder are imported, uncompiled objects are compiled and the
        container state records that the test objects are imported: later imports keep them current, and
        Export-NAVGitObjects may delete test files whose objects were deleted.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    .PARAMETER LibrariesOnly
        Import only the test libraries (overrides testToolkit.librariesOnly).
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [switch] $LibrariesOnly
    )

    $context = Initialize-NAVGitContainerCommand -Path $Path -Operation 'Importing the test toolkit'
    $config = $context.Config
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $params = @{
        containerName = $context.ContainerName
        sqlCredential = $context.SqlCredential
        credential    = $context.Credential
    }
    if ($LibrariesOnly -or $config.testToolkit.librariesOnly) {
        $params.includeTestLibrariesOnly = $true
    }
    if ($config.testToolkit.country) {
        $params.testToolkitCountry = $config.testToolkit.country
    }

    $what = 'test toolkit'
    if ($params.ContainsKey('includeTestLibrariesOnly')) { $what = 'test libraries' }
    Write-NAVGitLog "Importing the $what into '$($context.ContainerName)'" -Level Step
    Import-TestToolkitToBcContainer @params

    $import = Import-NAVGitChangedObjects -Context $context -TestsOnly
    Set-NAVGitContainerStateValue -ContainerName $context.ContainerName -Name 'testsImported' -Value $true

    $uncompiled = @(Invoke-NAVGitContainerCompile -Context $context)
    if ($import.Imported.Count -gt 0) {
        Invoke-NAVGitForceSync -ContainerName $context.ContainerName
    }

    Write-NAVGitLog ("Test toolkit and $($import.Imported.Count) test object(s) imported ({0:mm\:ss})" -f $stopwatch.Elapsed) -Level Success
    return [pscustomobject]@{ ImportedTests = $import.Imported.Count; Uncompiled = $uncompiled.Count }
}
