function Import-NAVGitTestToolkit {
    <#
    .SYNOPSIS
        Import Test Toolkit: imports the standard C/AL test toolkit (.fob files shipped in the container) and compiles.
    .DESCRIPTION
        Uses Import-TestToolkitToBcContainer, which imports C:\TestToolKit\*.fob in the container and force-syncs.
        testToolkit.librariesOnly imports only the test libraries; testToolkit.country picks a localized toolkit.
        Afterwards uncompiled objects are compiled, so objects in the Tests folder that needed the toolkit compile too.
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

    $uncompiled = @(Invoke-NAVGitContainerCompile -Context $context)

    Write-NAVGitLog ("Test toolkit imported ({0:mm\:ss})" -f $stopwatch.Elapsed) -Level Success
    return [pscustomobject]@{ Uncompiled = $uncompiled.Count }
}
