function Get-NavGitUserSettingsPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($env:NAVGIT_SETTINGS_PATH) {
        return $env:NAVGIT_SETTINGS_PATH
    }
    return Join-Path $env:APPDATA 'NavGit\settings.json'
}

function Get-NavGitUserSettings {
    <#
    .SYNOPSIS
        Reads the per-user settings file (%APPDATA%\NavGit\settings.json, override with $env:NAVGIT_SETTINGS_PATH).
        A missing file is not an error; defaults are returned.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $Path = (Get-NavGitUserSettingsPath)
    )

    $settings = @{
        backupFolder             = ''
        licenseFolder            = ''
        defaultAuth              = ''
        defaultIsolation         = ''
        bcContainerHelperVersion = ''
    }

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        try {
            $fileSettings = ConvertTo-NavGitHashtable (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
        }
        catch {
            throw "NavGit user settings '$Path' is not valid JSON: $($_.Exception.Message)"
        }
        if ($fileSettings -isnot [hashtable]) {
            throw "NavGit user settings '$Path' must contain a JSON object."
        }

        foreach ($key in $fileSettings.Keys) {
            if (-not $settings.ContainsKey($key)) {
                Write-Warning "NavGit user settings '$Path': unknown setting '$key' is ignored."
                continue
            }
            $settings[$key] = [string]$fileSettings[$key]
        }

        if ($settings.defaultAuth -and $settings.defaultAuth -notin @('Windows', 'NavUserPassword')) {
            throw "NavGit user settings '$Path': defaultAuth must be 'Windows' or 'NavUserPassword' (was '$($settings.defaultAuth)')."
        }
        if ($settings.defaultIsolation -and $settings.defaultIsolation -notin @('hyperv', 'process')) {
            throw "NavGit user settings '$Path': defaultIsolation must be 'hyperv', 'process' or empty (was '$($settings.defaultIsolation)')."
        }
    }

    $settings.settingsPath = $Path
    return $settings
}
