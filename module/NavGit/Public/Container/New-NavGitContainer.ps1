function New-NavGitContainer {
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
        New-NavGitContainer -WhatIf
        Shows the New-BcContainer command that would run.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [switch] $Force,

        [switch] $ResetCredential
    )

    $config = Get-NavGitConfig -Path $Path
    Assert-NavGitAdministrator -Operation 'Building a container'
    Assert-NavGitBcContainerHelper -UserSettings $config.userSettings

    $config.auth = Get-NavGitEffectiveAuth -Auth $config.auth
    $credential = Get-NavGitCredential -ContainerName $config.containerName -Auth $config.auth -Reset:$ResetCredential

    Write-NavGitLog "Preparing container '$($config.containerName)'" -Level Step
    $plan = Get-NavGitContainerPlan -Config $config -Credential $credential
    Write-NavGitContainerPlan -Plan $plan

    if (-not $PSCmdlet.ShouldProcess($config.containerName, 'Create NAV container')) {
        Write-Host (Format-NavGitContainerCommand -Parameters $plan.Parameters)
        return
    }

    if (-not $Force -and (Test-BcContainer -containerName $config.containerName)) {
        if (-not $PSCmdlet.ShouldContinue("Container '$($config.containerName)' already exists. Remove it and build a new one?", 'Rebuild container')) {
            Write-NavGitLog 'Cancelled.' -Level Warning
            return
        }
    }

    Write-NavGitLog "Creating container '$($config.containerName)'" -Level Step
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $parameters = $plan.Parameters
    New-BcContainer @parameters

    $state = Save-NavGitContainerState -Config $config -ArtifactUrl $plan.Artifact.Url -BackupPath $plan.Backup.Path
    if (-not $state.clientFolder) {
        Write-NavGitLog "The Windows client was not found on the host; Start Client and Start FinSql will not work for '$($config.containerName)'." -Level Warning
    }
    if ($plan.AddInsFolder) {
        Sync-NavGitAddIns -ContainerName $config.containerName -AddInsFolder $plan.AddInsFolder -ClientFolder $state.clientFolder
    }

    Write-NavGitLog ("Container '{0}' is ready ({1:mm\:ss})" -f $config.containerName, $stopwatch.Elapsed) -Level Success
}
