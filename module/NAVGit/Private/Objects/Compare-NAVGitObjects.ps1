function Compare-NAVGitObjects {
    <#
    .SYNOPSIS
        Compares repository objects (Read-NavObjectHeader) with the database objects (Get-NAVGitDbObjects).
        An object is imported when it is new or its Version List, Modified flag, Date or Time differ. A Date/Time
        that cannot be parsed also means import (safe, only slower). Database objects (ID < 2000000000) that are
        not in the repository are returned as Missing.
        Returns [pscustomobject]@{ ToImport; Unchanged; Missing; Unparsed }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $RepoObjects,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $DbObjects,

        [string] $DateFormat,

        # Import every repository object regardless of its properties.
        [switch] $Force
    )

    $db = @{}
    foreach ($object in $DbObjects) {
        $db["$($object.Type):$($object.Id)"] = $object
    }

    $toImport = New-Object System.Collections.Generic.List[object]
    $unchanged = New-Object System.Collections.Generic.List[object]
    $unparsed = 0
    $repoKeys = @{}

    foreach ($object in $RepoObjects) {
        $key = "$($object.Type):$($object.Id)"
        $repoKeys[$key] = $true

        if ($Force -or -not $db.ContainsKey($key)) {
            $toImport.Add($object)
            continue
        }
        $dbObject = $db[$key]

        $date = ConvertTo-NAVGitObjectDate -Text $object.Date -Format $DateFormat
        $time = ConvertTo-NAVGitObjectTime -Text $object.Time
        if (-not $date.Valid -or -not $time.Valid) {
            $unparsed++
            $toImport.Add($object)
            continue
        }

        $same = ($object.VersionList -ceq $dbObject.VersionList) -and
                ([bool]$object.Modified -eq [bool]$dbObject.Modified) -and
                ($date.Value -eq $dbObject.Date) -and
                ($time.Value -eq $dbObject.Time)
        if ($same) {
            $unchanged.Add($object)
        }
        else {
            $toImport.Add($object)
        }
    }

    $missing = @($DbObjects | Where-Object { $_.Id -lt 2000000000 -and -not $repoKeys.ContainsKey("$($_.Type):$($_.Id)") })

    return [pscustomobject]@{
        ToImport  = $toImport.ToArray()
        Unchanged = $unchanged.ToArray()
        Missing   = $missing
        Unparsed  = $unparsed
    }
}
