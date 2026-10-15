function Update-NavGitContainer {
    <#
    .SYNOPSIS
        Build and Update Container: builds the container (New-NavGitContainer) and imports all Git objects
        (Import-NavGitObjects).
    .DESCRIPTION
        Objects in the Tests folder usually need the test toolkit. Set includeTestToolkit in navgit.json to import it
        while the container is created, or run Import-NavGitTestToolkit before importing.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    .PARAMETER Force
        Replace an existing container without asking.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [switch] $Force
    )

    if ($WhatIfPreference) {
        New-NavGitContainer -Path $Path -WhatIf
        return
    }

    $config = Get-NavGitConfig -Path $Path
    Assert-NavGitAdministrator -Operation 'Building a container'
    Assert-NavGitBcContainerHelper -UserSettings $config.userSettings

    # Ask here, so declining stops the whole command instead of importing into the old container.
    if (-not $Force -and (Test-BcContainer -containerName $config.containerName)) {
        if (-not $PSCmdlet.ShouldContinue("Container '$($config.containerName)' already exists. Remove it, build a new one and import all objects?", 'Build and update container')) {
            Write-NavGitLog 'Cancelled.' -Level Warning
            return
        }
    }

    New-NavGitContainer -Path $Path -Force

    if (-not $config.includeTestToolkit -and (Get-NavGitObjectFiles -Folder $config.testsPath).Count -gt 0) {
        Write-NavGitLog "The $($config.paths.tests) folder has objects but includeTestToolkit is off; test objects may not compile without the test toolkit." -Level Warning
    }

    Import-NavGitObjects -Path $Path
}
