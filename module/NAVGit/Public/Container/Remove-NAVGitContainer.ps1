function Remove-NAVGitContainer {
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

    $config = Get-NAVGitConfig -Path $Path
    Assert-NAVGitAdministrator -Operation 'Removing a container'
    Assert-NAVGitBcContainerHelper -UserSettings $config.userSettings

    $containerName = $config.containerName
    if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
        $ConfirmPreference = 'None'
    }

    if (Test-BcContainer -containerName $containerName) {
        if (-not $PSCmdlet.ShouldProcess($containerName, 'Remove NAV container')) {
            return
        }
        Write-NAVGitLog "Removing container '$containerName'" -Level Step
        Remove-BcContainer -containerName $containerName
    }
    else {
        Write-NAVGitLog "Container '$containerName' does not exist." -Level Warning
    }

    Remove-NAVGitContainerState -ContainerName $containerName
    Write-NAVGitLog "Container '$containerName' removed" -Level Success
}
