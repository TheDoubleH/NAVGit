function Update-NAVGitContainerState {
    <#
    .SYNOPSIS
        Re-reads the container's configuration and saves the state used by the client commands.
        Use it for containers created outside NAVGit, or after recreating a container manually.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath
    )

    $config = Get-NAVGitConfig -Path $Path
    Assert-NAVGitAdministrator -Operation 'Reading the container configuration'
    Assert-NAVGitBcContainerHelper -UserSettings $config.userSettings

    if (-not (Test-BcContainer -containerName $config.containerName)) {
        throw "Container '$($config.containerName)' does not exist. Build it with New-NAVGitContainer."
    }

    # The configuration can be read again; what was imported into the container cannot.
    $previous = Get-NAVGitContainerState -ContainerName $config.containerName
    $saveParams = @{ Config = $config; BackupPath = $null }
    if ($previous) {
        $saveParams.BackupPath = $previous.backupFile
        if ($previous.ContainsKey('testsImported')) { $saveParams.TestsImported = [bool]$previous.testsImported }
    }

    $state = Save-NAVGitContainerState @saveParams
    Write-NAVGitLog "State updated for '$($state.containerName)' (NAV $($state.navVersion), instance $($state.serverInstance), database $($state.databaseName))" -Level Success
    if (-not $state.clientFolder) {
        Write-NAVGitLog "The Windows client was not found on the host; the container was probably created without -includeCSide." -Level Warning
    }
}
