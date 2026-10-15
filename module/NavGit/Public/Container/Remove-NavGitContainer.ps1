function Remove-NavGitContainer {
    <#
    .SYNOPSIS
        Remove Container: removes the repository's NAV container (Remove-BcContainer) and its saved state.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    .PARAMETER Force
        Remove without asking for confirmation.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [switch] $Force
    )

    $config = Get-NavGitConfig -Path $Path
    Assert-NavGitAdministrator -Operation 'Removing a container'
    Assert-NavGitBcContainerHelper -UserSettings $config.userSettings

    $containerName = $config.containerName
    if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
        $ConfirmPreference = 'None'
    }

    if (Test-BcContainer -containerName $containerName) {
        if (-not $PSCmdlet.ShouldProcess($containerName, 'Remove NAV container')) {
            return
        }
        Write-NavGitLog "Removing container '$containerName'" -Level Step
        Remove-BcContainer -containerName $containerName
    }
    else {
        Write-NavGitLog "Container '$containerName' does not exist." -Level Warning
    }

    Remove-NavGitContainerState -ContainerName $containerName
    Write-NavGitLog "Container '$containerName' removed" -Level Success
}
