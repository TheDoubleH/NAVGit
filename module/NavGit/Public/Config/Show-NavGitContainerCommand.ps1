function Show-NavGitContainerCommand {
    <#
    .SYNOPSIS
        Shows the New-BcContainer command NavGit would run for the repository, with the credential masked.
        Does not create anything and does not need elevation.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    .PARAMETER PassThru
        Return the plan (artifact, backup, license, parameters) instead of only printing it.
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [switch] $PassThru
    )

    $config = Get-NavGitConfig -Path $Path
    $config.auth = Get-NavGitEffectiveAuth -Auth $config.auth

    try {
        $credential = Get-NavGitCredential -ContainerName $config.containerName -Auth $config.auth -NoPrompt
    }
    catch {
        # Only the user name is shown, so a placeholder is fine when nothing is stored yet.
        $userName = 'admin'
        if ($config.auth -eq 'Windows') { $userName = $env:USERNAME }
        $credential = New-Object System.Management.Automation.PSCredential($userName, (New-Object System.Security.SecureString))
    }

    $plan = Get-NavGitContainerPlan -Config $config -Credential $credential
    Write-NavGitContainerPlan -Plan $plan
    Write-Host ''
    Write-Host (Format-NavGitContainerCommand -Parameters $plan.Parameters)

    if ($PassThru) {
        return $plan
    }
}
