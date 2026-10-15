function Get-NavGitDataPath {
    <#
    .SYNOPSIS
        Returns (and creates) a per-user NavGit data folder under %LOCALAPPDATA%\NavGit,
        e.g. 'containers' or 'credentials'. Override the root with $env:NAVGIT_DATA_PATH (used by tests).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('containers', 'credentials')]
        [string] $Name
    )

    $root = $env:NAVGIT_DATA_PATH
    if (-not $root) {
        $root = Join-Path $env:LOCALAPPDATA 'NavGit'
    }
    $path = Join-Path $root $Name
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}
