function ConvertTo-NAVGitJson {
    <#
    .SYNOPSIS
        Serializes (ordered) hashtables, arrays and scalars as JSON with two-space indentation.
        Windows PowerShell's ConvertTo-Json produces hard to read indentation for files people edit.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $InputObject,

        [int] $Indent = 0
    )

    $pad = '  ' * $Indent
    $innerPad = '  ' * ($Indent + 1)

    if ($null -eq $InputObject) { return 'null' }
    if ($InputObject -is [bool]) { if ($InputObject) { return 'true' } else { return 'false' } }
    if ($InputObject -is [int] -or $InputObject -is [long] -or $InputObject -is [double] -or $InputObject -is [decimal]) {
        return ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0}', $InputObject))
    }
    if ($InputObject -is [string]) {
        $escaped = $InputObject.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n').Replace("`t", '\t')
        return '"' + $escaped + '"'
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Count -eq 0) { return '{}' }
        $items = foreach ($key in $InputObject.Keys) {
            "$innerPad$(ConvertTo-NAVGitJson -InputObject ([string]$key)): $(ConvertTo-NAVGitJson -InputObject $InputObject[$key] -Indent ($Indent + 1))"
        }
        return "{`r`n" + ($items -join ",`r`n") + "`r`n$pad}"
    }
    if ($InputObject -is [System.Collections.IEnumerable]) {
        $array = @($InputObject)
        if ($array.Count -eq 0) { return '[]' }
        $items = foreach ($item in $array) { "$innerPad$(ConvertTo-NAVGitJson -InputObject $item -Indent ($Indent + 1))" }
        return "[`r`n" + ($items -join ",`r`n") + "`r`n$pad]"
    }
    return ConvertTo-NAVGitJson -InputObject ([string]$InputObject) -Indent $Indent
}
