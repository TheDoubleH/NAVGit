function Update-NAVGitAddIns {
    <#
    .SYNOPSIS
        Update Add-ins: copies the repository's add-ins (paths.addIns, default Add-Ins) into the container's service
        tier and Windows client, and into the Windows client on the host, without rebuilding the container.
        Restart the Windows client afterwards; a service tier restart may be needed for already loaded assemblies.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath
    )

    $context = Initialize-NAVGitContainerCommand -Path $Path -Operation 'Updating add-ins'
    $config = $context.Config

    if (-not $config.addInsPath -or -not (Test-Path -LiteralPath $config.addInsPath -PathType Container)) {
        throw "No add-ins folder: '$($config.paths.addIns)' does not exist in $($config.repositoryPath) (paths.addIns)."
    }

    $clientFolder = $null
    $state = Get-NAVGitContainerState -ContainerName $context.ContainerName
    if ($state) { $clientFolder = $state.clientFolder }
    if (-not $clientFolder) { $clientFolder = Get-NAVGitClientFolder -ContainerName $context.ContainerName }

    Sync-NAVGitAddIns -ContainerName $context.ContainerName -AddInsFolder (Resolve-Path -LiteralPath $config.addInsPath).ProviderPath -ClientFolder $clientFolder
    Write-NAVGitLog "Add-ins updated in '$($context.ContainerName)'" -Level Success
}
