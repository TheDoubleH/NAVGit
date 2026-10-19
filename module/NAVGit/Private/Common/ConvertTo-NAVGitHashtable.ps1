function ConvertTo-NAVGitHashtable {
    <#
    .SYNOPSIS
        Recursively converts ConvertFrom-Json output (PSCustomObject) into hashtables and arrays.
        Windows PowerShell 5.1 has no ConvertFrom-Json -AsHashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-NAVGitHashtable $InputObject[$key]
        }
        return $result
    }

    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $result = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-NAVGitHashtable $property.Value
        }
        return $result
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @(foreach ($item in $InputObject) { ConvertTo-NAVGitHashtable $item })
        # Leading comma keeps the array intact (also empty and single item arrays).
        return , $items
    }

    return $InputObject
}
