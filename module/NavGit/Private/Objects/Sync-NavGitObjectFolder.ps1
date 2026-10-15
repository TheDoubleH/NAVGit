function Sync-NavGitObjectFolder {
    <#
    .SYNOPSIS
        Mirrors exported object files into the repository: each file goes to the Objects or Tests folder
        (Get-NavGitObjectTargetFolder). New and changed files are copied byte for byte, a copy left in the other
        folder is removed (the object moved), and - with -RemoveMissing - object files that were not exported are
        deleted. Only files named like object files (TAB18.TXT) are touched.
        Returns [pscustomobject]@{ Added; Changed; Moved; Removed; Unchanged; Tests } (lists of file names).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SourceFolder,

        [Parameter(Mandatory)]
        [string] $ObjectsPath,

        [Parameter(Mandatory)]
        [string] $TestsPath,

        [Parameter(Mandatory)]
        [hashtable] $TestObjects,

        [switch] $RemoveMissing
    )

    $result = [ordered]@{ Added = @(); Changed = @(); Moved = @(); Removed = @(); Unchanged = @(); Tests = @() }
    $folders = @{ Objects = $ObjectsPath; Tests = $TestsPath }
    foreach ($folder in $folders.Values) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }
    }

    $exported = @{}
    foreach ($file in (Get-NavGitObjectFiles -Folder $SourceFolder)) {
        $name = $file.Name.ToUpperInvariant()
        $exported[$name] = $true

        $header = Read-NavObjectHeader -Path $file.FullName
        $target = Get-NavGitObjectTargetFolder -Header $header -TestObjects $TestObjects
        $other = 'Tests'
        if ($target -eq 'Tests') { $other = 'Objects'; $result.Tests += $name }

        $destination = Join-Path $folders[$target] $file.Name
        $otherCopy = Join-Path $folders[$other] $file.Name
        $movedFromOther = Test-Path -LiteralPath $otherCopy -PathType Leaf

        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            if (Test-NavGitFileEqual -Path $file.FullName -OtherPath $destination) {
                $result.Unchanged += $name
            }
            else {
                Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
                $result.Changed += $name
            }
        }
        else {
            Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
            if ($movedFromOther) { $result.Moved += $name } else { $result.Added += $name }
        }

        if ($movedFromOther) {
            Remove-Item -LiteralPath $otherCopy -Force
        }
    }

    if ($RemoveMissing) {
        foreach ($folder in $folders.Values) {
            foreach ($file in (Get-NavGitObjectFiles -Folder $folder)) {
                if (-not $exported.ContainsKey($file.Name.ToUpperInvariant())) {
                    Remove-Item -LiteralPath $file.FullName -Force
                    $result.Removed += $file.Name.ToUpperInvariant()
                }
            }
        }
    }

    return [pscustomobject]$result
}

function Test-NavGitFileEqual {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $OtherPath
    )

    if ((Get-Item -LiteralPath $Path).Length -ne (Get-Item -LiteralPath $OtherPath).Length) {
        return $false
    }
    $a = [System.IO.File]::ReadAllBytes($Path)
    $b = [System.IO.File]::ReadAllBytes($OtherPath)
    for ($i = 0; $i -lt $a.Length; $i++) {
        if ($a[$i] -ne $b[$i]) { return $false }
    }
    return $true
}
