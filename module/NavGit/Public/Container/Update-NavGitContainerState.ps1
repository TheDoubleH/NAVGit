function Update-NavGitContainerState {
    <#
    .SYNOPSIS
        Re-reads the container's configuration and saves the state used by the client commands.
        Use it for containers created outside NavGit, or after recreating a container manually.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath
    )

    $config = Get-NavGitConfig -Path $Path
    Assert-NavGitAdministrator -Operation 'Reading the container configuration'
    Assert-NavGitBcContainerHelper -UserSettings $config.userSettings

    if (-not (Test-BcContainer -containerName $config.containerName)) {
        throw "Container '$($config.containerName)' does not exist. Build it with New-NavGitContainer."
    }

    $previous = Get-NavGitContainerState -ContainerName $config.containerName
    $backupPath = $null
    if ($previous) { $backupPath = $previous.backupFile }

    $state = Save-NavGitContainerState -Config $config -BackupPath $backupPath
    Write-NavGitLog "State updated for '$($state.containerName)' (NAV $($state.navVersion), instance $($state.serverInstance), database $($state.databaseName))" -Level Success
    if (-not $state.clientFolder) {
        Write-NavGitLog "The Windows client was not found on the host; the container was probably created without -includeCSide." -Level Warning
    }
}
