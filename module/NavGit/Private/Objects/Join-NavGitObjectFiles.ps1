function Join-NavGitObjectFiles {
    <#
    .SYNOPSIS
        Concatenates object files byte for byte (no re-encoding) into one file for a single finsql import.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $Path,

        [Parameter(Mandatory)]
        [string] $Destination
    )

    $newLine = [byte[]](13, 10)
    $output = [System.IO.File]::Create($Destination)
    try {
        foreach ($file in $Path) {
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $output.Write($bytes, 0, $bytes.Length)
            if ($bytes.Length -gt 0 -and $bytes[$bytes.Length - 1] -ne 10) {
                $output.Write($newLine, 0, $newLine.Length)
            }
        }
    }
    finally {
        $output.Dispose()
    }
}
