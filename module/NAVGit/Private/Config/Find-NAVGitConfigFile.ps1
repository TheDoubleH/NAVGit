function Find-NAVGitConfigFile {
    <#
    .SYNOPSIS
        Walks up from Path (a folder or a file inside the repository) and returns the first navgit.json found, or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $current = $Path
    if (Test-Path -LiteralPath $current -PathType Leaf) {
        $current = Split-Path -Path $current -Parent
    }
    if (-not (Test-Path -LiteralPath $current -PathType Container)) {
        return $null
    }
    $current = (Resolve-Path -LiteralPath $current).ProviderPath

    while ($current) {
        $candidate = Join-Path $current 'navgit.json'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
        $parent = Split-Path -Path $current -Parent
        if (-not $parent -or $parent -eq $current) {
            break
        }
        $current = $parent
    }
    return $null
}
