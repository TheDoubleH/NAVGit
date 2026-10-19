function Get-NAVGitObjectFiles {
    <#
    .SYNOPSIS
        C/AL object files in a folder, named like Split-NAVApplicationObjectFile does (TAB18.TXT, COD50000.TXT).
        Other files are ignored and never touched.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Folder
    )

    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $Folder -File | Where-Object { $_.Name -match '^[A-Za-z]{3}\d+\.txt$' })
}

function Get-NAVGitRepoObjects {
    <#
    .SYNOPSIS
        Reads the headers of all object files in the repository's Objects and Tests folders.
        Throws when the same object exists in both folders or twice.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config
    )

    $objects = @{}
    foreach ($folder in @($Config.objectsPath, $Config.testsPath)) {
        foreach ($file in (Get-NAVGitObjectFiles -Folder $folder)) {
            $header = Read-NavObjectHeader -Path $file.FullName
            $key = "$($header.Type):$($header.Id)"
            if ($objects.ContainsKey($key)) {
                throw "$($header.Type) $($header.Id) exists twice: '$($objects[$key].Path)' and '$($file.FullName)'. Remove one of them."
            }
            $objects[$key] = $header
        }
    }
    return @($objects.Values)
}
