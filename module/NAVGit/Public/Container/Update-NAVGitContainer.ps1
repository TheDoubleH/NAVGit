function Update-NAVGitContainer {
    <#
    .SYNOPSIS
        Build and Update Container: builds the container (New-NAVGitContainer) and imports all Git objects
        (Import-NAVGitObjects).
    .DESCRIPTION
        Objects in the Tests folder are only imported when includeTestToolkit is set in navgit.json; the toolkit is then
        imported while the container is created, before the objects.
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
        New-NAVGitContainer -Path $Path -WhatIf
        return
    }

    $config = Get-NAVGitConfig -Path $Path
    Assert-NAVGitAdministrator -Operation 'Building a container'
    Assert-NAVGitBcContainerHelper -UserSettings $config.userSettings

    # Ask here, so declining stops the whole command instead of importing into the old container.
    if (-not $Force -and (Test-BcContainer -containerName $config.containerName)) {
        if (-not $PSCmdlet.ShouldContinue("Container '$($config.containerName)' already exists. Remove it, build a new one and import all objects?", 'Build and update container')) {
            Write-NAVGitLog 'Cancelled.' -Level Warning
            return
        }
    }

    New-NAVGitContainer -Path $Path -Force

    Import-NAVGitObjects -Path $Path
}
