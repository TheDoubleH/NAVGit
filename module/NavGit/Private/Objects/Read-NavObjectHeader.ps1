function Read-NavObjectHeader {
    <#
    .SYNOPSIS
        Reads the header of a C/AL text object file without NAV Model Tools:
        OBJECT <Type> <Id> <Name>, the OBJECT-PROPERTIES (Date, Time, Modified, Version List) and Subtype from PROPERTIES.
        Returns [pscustomobject]@{ Type; TypeId; Id; Name; Date; Time; Modified; VersionList; Subtype; Path }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        # C/AL files are written in the OEM code page of the exporting machine.
        [System.Text.Encoding] $Encoding = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
    )

    $header = [ordered]@{
        Type        = $null
        TypeId      = $null
        Id          = $null
        Name        = $null
        Date        = ''
        Time        = ''
        Modified    = $false
        VersionList = ''
        Subtype     = ''
        Path        = $Path
    }

    $reader = New-Object System.IO.StreamReader($Path, $Encoding, $true)
    try {
        $first = $reader.ReadLine()
        # Names with leading/trailing spaces are written in brackets: OBJECT [Table 50376 Required Sales Doc. Document ]
        $declaration = $null
        if ($first -match '^OBJECT\s+\[(?<inner>.*)\]\s*$') {
            $declaration = $Matches.inner
        }
        elseif ($first -match '^OBJECT\s+(?<inner>.*?)\s*$') {
            $declaration = $Matches.inner
        }
        if ($null -eq $declaration -or $declaration -notmatch '^(?<type>[A-Za-z]+)\s+(?<id>\d+)\s(?<name>.*)$') {
            throw "'$Path' is not a C/AL object file (first line: '$first')."
        }
        $header.Type = Get-NavGitObjectTypeName -Name $Matches.type
        $header.TypeId = Get-NavGitObjectTypeId -Type $header.Type
        $header.Id = [int]$Matches.id
        $header.Name = $Matches.name

        $section = ''
        $lineNumber = 1
        while ($null -ne ($line = $reader.ReadLine())) {
            $lineNumber++
            if ($line -match '^  (OBJECT-PROPERTIES|PROPERTIES)\s*$') {
                $section = $Matches[1]
                continue
            }
            if ($line -match '^  }\s*$') {
                if ($section -eq 'PROPERTIES') { break }
                $section = ''
                continue
            }
            # Anything after the properties (FIELDS, CONTROLS, CODE, ...) is not needed.
            if ($line -match '^  [A-Z]' -and $section -eq '') {
                break
            }
            if ($section -eq 'OBJECT-PROPERTIES' -and $line -match '^\s+(?<key>Date|Time|Modified|Version List)=(?<value>.*);\s*$') {
                $value = ConvertFrom-NavGitPropertyValue $Matches.value
                switch ($Matches.key) {
                    'Date' { $header.Date = $value }
                    'Time' { $header.Time = $value }
                    'Modified' { $header.Modified = ($value -eq 'Yes') }
                    'Version List' { $header.VersionList = $value }
                }
            }
            elseif ($section -eq 'PROPERTIES' -and $line -match '^\s+Subtype=(?<value>[^;]*);') {
                $header.Subtype = ConvertFrom-NavGitPropertyValue $Matches.value
            }
            if ($lineNumber -gt 500) { break }
        }
    }
    finally {
        $reader.Dispose()
    }

    return [pscustomobject]$header
}

function ConvertFrom-NavGitPropertyValue {
    # C/AL wraps values with special characters or leading spaces in [ ]: Time=[ 9:00:00]; Version List=[A;B];
    param([string] $Value)

    $Value = $Value.Trim()
    if ($Value.Length -ge 2 -and $Value.StartsWith('[') -and $Value.EndsWith(']')) {
        $Value = $Value.Substring(1, $Value.Length - 2)
    }
    return $Value.Trim()
}

function Get-NavGitObjectTypeId {
    <#
    .SYNOPSIS
        Object type name -> [Type] value in the [Object] table.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string] $Type
    )

    $map = @{ TableData = 0; Table = 1; Form = 2; Report = 3; Dataport = 4; Codeunit = 5; XMLport = 6; MenuSuite = 7; Page = 8; Query = 9 }
    if (-not $map.ContainsKey($Type)) {
        throw "Unknown object type '$Type'."
    }
    return $map[$Type]
}

function Get-NavGitObjectTypeName {
    <#
    .SYNOPSIS
        Normalises an object type name or [Object].[Type] number to the C/AL spelling (Table, Codeunit, XMLport, ...).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string] $Name,
        [int] $TypeId = -1
    )

    $names = @('TableData', 'Table', 'Form', 'Report', 'Dataport', 'Codeunit', 'XMLport', 'MenuSuite', 'Page', 'Query')
    if ($TypeId -ge 0) {
        return $names[$TypeId]
    }
    $match = $names | Where-Object { $_ -eq $Name } | Select-Object -First 1
    if (-not $match) {
        throw "Unknown object type '$Name'."
    }
    return $match
}
