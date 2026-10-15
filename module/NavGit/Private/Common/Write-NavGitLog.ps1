function Write-NavGitLog {
    <#
    .SYNOPSIS
        Writes a timestamped, coloured status line. Warnings and errors go through the matching streams.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Message,

        [ValidateSet('Info', 'Step', 'Success', 'Warning', 'Detail')]
        [string] $Level = 'Info'
    )

    $timestamp = Get-Date -Format 'HH:mm:ss'
    switch ($Level) {
        'Warning' { Write-Warning $Message }
        'Detail' { Write-Verbose "[$timestamp] $Message" }
        'Step' { Write-Host "[$timestamp] $Message" -ForegroundColor Cyan }
        'Success' { Write-Host "[$timestamp] $Message" -ForegroundColor Green }
        default { Write-Host "[$timestamp] $Message" }
    }
}
