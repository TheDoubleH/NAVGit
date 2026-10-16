function Resolve-NAVGitBackupFile {
    <#
    .SYNOPSIS
        Determines the database backup for the container and returns [pscustomobject]@{ Path; Source }.
        Source is 'Demo' (Path = $null, use Cronus), 'Url', 'Config' (database.bakFile) or 'Search' (backupFolder).

        Search order in the user backupFolder (AdvaniaGIT compatible), for projectName and then each database.searchNames:
          <navRelease>-<name>.bak, <navRelease>\<version>\<name>.bak, <navRelease>\<name>.bak
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config,

        [Parameter(Mandatory)]
        $ArtifactInfo
    )

    $database = $Config.database
    if ($database.useDemo -eq $true) {
        return [pscustomobject]@{ Path = $null; Source = 'Demo' }
    }

    $backupFolder = $Config.userSettings.backupFolder

    if ($database.bakFile) {
        $bakFile = $database.bakFile
        if ($bakFile -match '^https?://') {
            return [pscustomobject]@{ Path = $bakFile; Source = 'Url' }
        }

        $candidates = @()
        if ([System.IO.Path]::IsPathRooted($bakFile)) {
            $candidates += $bakFile
        }
        else {
            $candidates += Join-Path $Config.repositoryPath $bakFile
            if ($backupFolder) {
                $candidates += Join-Path $backupFolder $bakFile
            }
        }
        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return [pscustomobject]@{ Path = (Resolve-Path -LiteralPath $candidate).ProviderPath; Source = 'Config' }
            }
        }
        throw "Backup file '$bakFile' from database.bakFile was not found. Looked in:$([Environment]::NewLine)$(($candidates | ForEach-Object { "  $_" }) -join [Environment]::NewLine)"
    }

    if (-not $backupFolder) {
        throw "No database.bakFile in $($Config.configPath) and no backupFolder in the user settings ($($Config.userSettings.settingsPath)). Set one of them, or set database.useDemo to true to use the Cronus demo database."
    }
    if (-not (Test-Path -LiteralPath $backupFolder -PathType Container)) {
        throw "The backupFolder '$backupFolder' from the user settings ($($Config.userSettings.settingsPath)) does not exist."
    }

    $release = $ArtifactInfo.NavRelease
    $version = $ArtifactInfo.Version.ToString()
    $names = @($Config.projectName) + @($database.searchNames | Where-Object { $_ })

    $tried = @()
    foreach ($name in $names) {
        foreach ($relative in @("$release-$name.bak", "$release\$version\$name.bak", "$release\$name.bak")) {
            $candidate = Join-Path $backupFolder $relative
            $tried += $candidate
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return [pscustomobject]@{ Path = (Resolve-Path -LiteralPath $candidate).ProviderPath; Source = 'Search' }
            }
        }
    }

    throw "No backup found for '$($Config.projectName)'. Tried:$([Environment]::NewLine)$(($tried | ForEach-Object { "  $_" }) -join [Environment]::NewLine)$([Environment]::NewLine)Set database.bakFile, or database.useDemo to true to use the Cronus demo database."
}
