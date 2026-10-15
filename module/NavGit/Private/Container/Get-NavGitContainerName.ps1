function Get-NavGitContainerName {
    <#
    .SYNOPSIS
        Derives the default container name from the project name: '_' and other invalid characters become '-',
        truncated to 15 characters (NetBIOS host name limit), no leading/trailing '-'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $ProjectName
    )

    $name = $ProjectName -replace '[^A-Za-z0-9-]', '-'
    $name = $name.Trim('-')
    if ($name.Length -gt 15) {
        $name = $name.Substring(0, 15).TrimEnd('-')
    }
    return $name
}
