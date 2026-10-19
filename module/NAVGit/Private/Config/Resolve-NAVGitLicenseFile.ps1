function Resolve-NAVGitLicenseFile {
    <#
    .SYNOPSIS
        Resolves licenseFile to an existing file path or URL, or $null when no license is configured
        (the container then uses the Cronus demo license from the artifact).
        '{major}' in the value is replaced with the major version (e.g. Customer{major}.flf -> Customer11.flf).
        Relative paths are tried against the repository first, then the user licenseFolder.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config,

        $ArtifactInfo
    )

    $licenseFile = $Config.licenseFile
    if (-not $licenseFile) {
        Write-NAVGitLog "No licenseFile configured; the container uses the demo license from the artifact." -Level Warning
        return $null
    }

    if ($licenseFile -like '*{major}*') {
        if (-not $ArtifactInfo) {
            throw "licenseFile '$licenseFile' uses {major}, but the artifact version is not known."
        }
        $licenseFile = $licenseFile.Replace('{major}', [string]$ArtifactInfo.Version.Major)
    }

    if ($licenseFile -match '^https?://') {
        return $licenseFile
    }

    $licenseFolder = $Config.userSettings.licenseFolder
    $candidates = @()
    if ([System.IO.Path]::IsPathRooted($licenseFile)) {
        $candidates += $licenseFile
    }
    else {
        $candidates += Join-Path $Config.repositoryPath $licenseFile
        if ($licenseFolder) {
            $candidates += Join-Path $licenseFolder $licenseFile
        }
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).ProviderPath
        }
    }
    throw "License file '$licenseFile' was not found. Looked in:$([Environment]::NewLine)$(($candidates | ForEach-Object { "  $_" }) -join [Environment]::NewLine)"
}
