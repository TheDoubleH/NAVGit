function Start-NavGitDevelopmentEnvironment {
    <#
    .SYNOPSIS
        Start FinSql: opens the development environment (C/SIDE) connected to the repository's container.
        Needs no elevation; uses the client files BcContainerHelper copied to this machine.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath
    )

    $context = Get-NavGitClientContext -Path $Path
    $finsql = Join-Path $context.State.clientFolder 'finsql.exe'
    if (-not (Test-Path -LiteralPath $finsql -PathType Leaf)) {
        throw "finsql.exe was not found in $($context.State.clientFolder)."
    }

    $arguments = Get-NavGitFinSqlArguments -State $context.State
    Write-NavGitLog "Starting C/SIDE for '$($context.State.containerName)'" -Level Step
    Write-NavGitLog "`"$finsql`" $arguments" -Level Detail
    Start-Process -FilePath $finsql -ArgumentList $arguments -WorkingDirectory $context.State.clientFolder
}
