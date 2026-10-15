function Get-NavGitObjectTargetFolder {
    <#
    .SYNOPSIS
        Decides whether an exported object belongs in the Tests or the Objects folder. Returns 'Tests' or 'Objects'.
        Tests: the Version List matches testObjects.versionListPattern (case-insensitive), or - with
        testObjects.includeTestCodeunits - the object is a codeunit with Subtype=Test.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        $Header,

        [Parameter(Mandatory)]
        [hashtable] $TestObjects
    )

    if ($Header.VersionList -and $TestObjects.versionListPattern -and
        [regex]::IsMatch($Header.VersionList, $TestObjects.versionListPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        return 'Tests'
    }
    if ($TestObjects.includeTestCodeunits -and $Header.Type -eq 'Codeunit' -and $Header.Subtype -eq 'Test') {
        return 'Tests'
    }
    return 'Objects'
}
