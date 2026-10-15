function ConvertTo-NavGitObjectDate {
    <#
    .SYNOPSIS
        Parses the Date of a C/AL text object. Returns [pscustomobject]@{ Valid; Value } where Value is a [datetime]
        or $null for a blank date. The format follows the locale of the exporting machine; without -Format it is
        derived from the separator: '.' -> dd.MM.yy, '-' -> dd-MM-yy, '/' -> MM/dd/yy.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $Text,

        [string] $Format
    )

    $Text = "$Text".Trim()
    if (-not $Text) {
        return [pscustomobject]@{ Valid = $true; Value = $null }
    }

    if ($Format) {
        $formats = @($Format)
    }
    elseif ($Text.Contains('.')) {
        $formats = @('dd.MM.yy', 'd.M.yy', 'dd.MM.yyyy', 'd.M.yyyy')
    }
    elseif ($Text.Contains('-')) {
        $formats = @('dd-MM-yy', 'd-M-yy', 'dd-MM-yyyy', 'yyyy-MM-dd')
    }
    else {
        $formats = @('MM/dd/yy', 'M/d/yy', 'MM/dd/yyyy', 'M/d/yyyy')
    }

    $value = [datetime]::MinValue
    if ([datetime]::TryParseExact($Text, [string[]]$formats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$value)) {
        return [pscustomobject]@{ Valid = $true; Value = $value.Date }
    }
    return [pscustomobject]@{ Valid = $false; Value = $null }
}

function ConvertTo-NavGitObjectTime {
    <#
    .SYNOPSIS
        Parses the Time of a C/AL text object (12:00:00, 9:00:00, 1:00:00 PM, 12:00:00.567). Returns
        [pscustomobject]@{ Valid; Value } where Value is a [timespan] truncated to seconds, or $null when blank.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $Text
    )

    $Text = "$Text".Trim()
    if (-not $Text) {
        return [pscustomobject]@{ Valid = $true; Value = $null }
    }

    $formats = [string[]]@('H:mm:ss', 'HH:mm:ss', 'H:mm:ss.FFF', 'HH:mm:ss.FFF', 'h:mm:ss tt', 'hh:mm:ss tt', 'h:mm:ss.FFF tt', 'hh:mm:ss.FFF tt')
    $value = [datetime]::MinValue
    if ([datetime]::TryParseExact($Text, $formats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$value)) {
        return [pscustomobject]@{ Valid = $true; Value = New-TimeSpan -Hours $value.Hour -Minutes $value.Minute -Seconds $value.Second }
    }
    return [pscustomobject]@{ Valid = $false; Value = $null }
}

function ConvertFrom-NavGitSqlDateTime {
    <#
    .SYNOPSIS
        Converts the 'yyyy-MM-dd HH:mm:ss' text of [Object].[Date] or [Object].[Time] (CONVERT style 120).
        Year 1753 is NAV's blank value -> $null.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Text,

        [Parameter(Mandatory)]
        [ValidateSet('Date', 'Time')]
        [string] $Part
    )

    if (-not $Text -or $Text.StartsWith('1753')) {
        return $null
    }
    $value = [datetime]::ParseExact($Text, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
    if ($Part -eq 'Date') {
        return $value.Date
    }
    return New-TimeSpan -Hours $value.Hour -Minutes $value.Minute -Seconds $value.Second
}
