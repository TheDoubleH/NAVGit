function Sync-NAVGitObjectFolder {
    <#
    .SYNOPSIS
        Mirrors exported object files into the repository: each file goes to the Objects or Tests folder
        (Get-NAVGitObjectTargetFolder). New and changed files are copied byte for byte, a copy left in the other
        folder is removed (the object moved), and - with -RemoveMissing - object files that were not exported are
        deleted. -KeepMissingTests keeps those in the Tests folder (returned as Kept): when the test objects were never
        imported, their absence from the database means nothing. Only files named like object files (TAB18.TXT) are
        touched.
        Returns [pscustomobject]@{ Added; Changed; Moved; Removed; Kept; Unchanged; Tests } (lists of file names).
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

        [switch] $RemoveMissing,

        [switch] $KeepMissingTests
    )

    $result = [ordered]@{ Added = @(); Changed = @(); Moved = @(); Removed = @(); Kept = @(); Unchanged = @(); Tests = @() }
    $folders = @{ Objects = $ObjectsPath; Tests = $TestsPath }
    foreach ($folder in $folders.Values) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }
    }

    $exported = @{}
    foreach ($file in (Get-NAVGitObjectFiles -Folder $SourceFolder)) {
        $name = $file.Name.ToUpperInvariant()
        $exported[$name] = $true

        $header = Read-NavObjectHeader -Path $file.FullName
        $target = Get-NAVGitObjectTargetFolder -Header $header -TestObjects $TestObjects
        $other = 'Tests'
        if ($target -eq 'Tests') { $other = 'Objects'; $result.Tests += $name }

        $destination = Join-Path $folders[$target] $file.Name
        $otherCopy = Join-Path $folders[$other] $file.Name
        $movedFromOther = Test-Path -LiteralPath $otherCopy -PathType Leaf

        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            if (Test-NAVGitFileEqual -Path $file.FullName -OtherPath $destination) {
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
        foreach ($target in @('Objects', 'Tests')) {
            foreach ($file in (Get-NAVGitObjectFiles -Folder $folders[$target])) {
                $name = $file.Name.ToUpperInvariant()
                if ($exported.ContainsKey($name)) { continue }
                if ($target -eq 'Tests' -and $KeepMissingTests) {
                    $result.Kept += $name
                    continue
                }
                Remove-Item -LiteralPath $file.FullName -Force
                $result.Removed += $name
            }
        }
    }

    return [pscustomobject]$result
}

function Test-NAVGitFileEqual {
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
