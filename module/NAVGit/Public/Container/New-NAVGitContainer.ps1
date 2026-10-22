function New-NAVGitContainer {
    <#
    .SYNOPSIS
        Build Container: creates the NAV container for the repository with BcContainerHelper.
    .DESCRIPTION
        Resolves the artifact, backup and license from navgit.json and calls New-BcContainer with native parameters
        (the backup goes to -bakFile, so the image is built without the Cronus database). Afterwards the container
        state is saved for the client commands.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    .PARAMETER Force
        Replace an existing container without asking.
    .PARAMETER ResetCredential
        Ask for the container credential again instead of using the stored one.
    .EXAMPLE
        New-NAVGitContainer -WhatIf
        Shows the New-BcContainer command that would run.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [switch] $Force,

        [switch] $ResetCredential
    )

    $config = Get-NAVGitConfig -Path $Path
    Assert-NAVGitAdministrator -Operation 'Building a container'
    Assert-NAVGitBcContainerHelper -UserSettings $config.userSettings

    $config.auth = Get-NAVGitEffectiveAuth -Auth $config.auth
    $credential = Get-NAVGitCredential -ContainerName $config.containerName -Auth $config.auth -Reset:$ResetCredential

    Write-NAVGitLog "Preparing container '$($config.containerName)'" -Level Step
    $plan = Get-NAVGitContainerPlan -Config $config -Credential $credential
    Write-NAVGitContainerPlan -Plan $plan

    if (-not $PSCmdlet.ShouldProcess($config.containerName, 'Create NAV container')) {
        Write-Host (Format-NAVGitContainerCommand -Parameters $plan.Parameters)
        return
    }

    if (-not $Force -and (Test-BcContainer -containerName $config.containerName)) {
        if (-not $PSCmdlet.ShouldContinue("Container '$($config.containerName)' already exists. Remove it and build a new one?", 'Rebuild container')) {
            Write-NAVGitLog 'Cancelled.' -Level Warning
            return
        }
    }

    if ($config.showBcContainerCommand) {
        Write-Host (Format-NAVGitContainerCommand -Parameters $plan.Parameters)
    }

    Write-NAVGitLog "Creating container '$($config.containerName)'" -Level Step
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $parameters = $plan.Parameters
    New-BcContainer @parameters

    # A new database: nothing from the Tests folder is in it until Import-NAVGitObjects or Import-NAVGitTestToolkit.
    $state = Save-NAVGitContainerState -Config $config -ArtifactUrl $plan.Artifact.Url -BackupPath $plan.Backup.Path -TestsImported $false
    if (-not $state.clientFolder) {
        Write-NAVGitLog "The Windows client was not found on the host; Start Client and Start FinSql will not work for '$($config.containerName)'." -Level Warning
    }
    if ($config.userSettings.uidOffset) {
        Write-NAVGitLog "Setting the Uid Offset to $($config.userSettings.uidOffset)" -Level Detail
        Set-NAVGitUidOffset -ContainerName $config.containerName -UidOffset ([int]$config.userSettings.uidOffset)
    }
    if ($plan.AddInsFolder) {
        Sync-NAVGitAddIns -ContainerName $config.containerName -AddInsFolder $plan.AddInsFolder -ClientFolder $state.clientFolder
    }

    Write-NAVGitLog ("Container '{0}' is ready ({1:mm\:ss})" -f $config.containerName, $stopwatch.Elapsed) -Level Success
}
