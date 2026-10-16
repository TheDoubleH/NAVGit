function Show-NAVGitContainerCommand {
    <#
    .SYNOPSIS
        Shows the New-BcContainer command NAVGit would run for the repository, with the credential masked.
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

    $config = Get-NAVGitConfig -Path $Path
    $config.auth = Get-NAVGitEffectiveAuth -Auth $config.auth

    try {
        $credential = Get-NAVGitCredential -ContainerName $config.containerName -Auth $config.auth -NoPrompt
    }
    catch {
        # Only the user name is shown, so a placeholder is fine when nothing is stored yet.
        $userName = 'admin'
        if ($config.auth -eq 'Windows') { $userName = $env:USERNAME }
        $credential = New-Object System.Management.Automation.PSCredential($userName, (New-Object System.Security.SecureString))
    }

    $plan = Get-NAVGitContainerPlan -Config $config -Credential $credential
    Write-NAVGitContainerPlan -Plan $plan
    Write-Host ''
    Write-Host (Format-NAVGitContainerCommand -Parameters $plan.Parameters)

    if ($PassThru) {
        return $plan
    }
}
