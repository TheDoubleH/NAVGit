function Merge-NAVGitHashtable {
    <#
    .SYNOPSIS
        Deep merges two hashtables. Values in Override win; nested hashtables are merged, arrays are replaced.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Base,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable] $Override
    )

    $result = @{}
    foreach ($key in $Base.Keys) {
        $result[$key] = $Base[$key]
    }

    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-NAVGitHashtable -Base $result[$key] -Override $Override[$key]
        }
        else {
            $result[$key] = $Override[$key]
        }
    }

    return $result
}
