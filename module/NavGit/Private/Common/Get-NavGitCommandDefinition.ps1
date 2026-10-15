function Get-NavGitCommandDefinition {
    <#
    .SYNOPSIS
        Returns the command registry entries from Commands.psd1, or the single entry matching Name.
    #>
    [CmdletBinding()]
    param(
        [string] $Name
    )

    $registry = Import-PowerShellDataFile -Path (Join-Path $script:NavGitModuleRoot 'Commands.psd1')
    $commands = @($registry.Commands)

    if (-not $Name) {
        return $commands
    }

    $command = $commands | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $command) {
        throw "Unknown NavGit command '$Name'. Known commands: $(($commands | ForEach-Object { $_.Name }) -join ', ')."
    }
    return $command
}
