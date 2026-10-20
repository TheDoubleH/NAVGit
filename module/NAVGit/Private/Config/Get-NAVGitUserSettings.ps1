function Get-NAVGitUserSettingsPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($env:NAVGIT_SETTINGS_PATH) {
        return $env:NAVGIT_SETTINGS_PATH
    }
    return Join-Path $env:APPDATA 'NAVGit\settings.json'
}

function Get-NAVGitUserSettings {
    <#
    .SYNOPSIS
        Reads the per-user settings file (%APPDATA%\NAVGit\settings.json, override with $env:NAVGIT_SETTINGS_PATH).
        A missing file is not an error; defaults are returned.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $Path = (Get-NAVGitUserSettingsPath)
    )

    $settings = @{
        backupFolder             = ''
        licenseFolder            = ''
        defaultAuth              = ''
        defaultIsolation         = ''
        bcContainerHelperVersion = ''
        # Personal default; navgit.json wins when it sets showBcContainerCommand.
        showBcContainerCommand   = $false
        # Personal override; wins over import.deleteMissing in navgit.json when set.
        deleteMissing            = ''
        # Personal override; wins over containerName in navgit.json when set. A name or an object (see navgit.json).
        containerName            = ''
    }
    $booleanKeys = @('showBcContainerCommand')

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        try {
            $fileSettings = ConvertTo-NAVGitHashtable (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
        }
        catch {
            throw "NAVGit user settings '$Path' is not valid JSON: $($_.Exception.Message)"
        }
        if ($fileSettings -isnot [hashtable]) {
            throw "NAVGit user settings '$Path' must contain a JSON object."
        }

        foreach ($key in $fileSettings.Keys) {
            if (-not $settings.ContainsKey($key)) {
                Write-Warning "NAVGit user settings '$Path': unknown setting '$key' is ignored."
                continue
            }
            if ($booleanKeys -contains $key) {
                if ($fileSettings[$key] -isnot [bool]) {
                    throw "NAVGit user settings '$Path': $key must be true or false (was '$($fileSettings[$key])')."
                }
                $settings[$key] = $fileSettings[$key]
                continue
            }
            if ($key -eq 'containerName' -and $fileSettings[$key] -is [hashtable]) {
                # Validated when the configuration is loaded (Resolve-NAVGitContainerName).
                foreach ($subKey in $fileSettings[$key].Keys) {
                    if ($subKey -notin @('fixed', 'branch')) {
                        Write-Warning "NAVGit user settings '$Path': unknown setting 'containerName.$subKey' is ignored."
                    }
                }
                $settings[$key] = $fileSettings[$key]
                continue
            }
            $settings[$key] = [string]$fileSettings[$key]
        }

        if ($settings.defaultAuth -and $settings.defaultAuth -notin @('Windows', 'NavUserPassword')) {
            throw "NAVGit user settings '$Path': defaultAuth must be 'Windows' or 'NavUserPassword' (was '$($settings.defaultAuth)')."
        }
        if ($settings.defaultIsolation -and $settings.defaultIsolation -notin @('hyperv', 'process')) {
            throw "NAVGit user settings '$Path': defaultIsolation must be 'hyperv', 'process' or empty (was '$($settings.defaultIsolation)')."
        }
        if ($settings.deleteMissing -and $settings.deleteMissing -notin @('skip', 'warn', 'mark')) {
            throw "NAVGit user settings '$Path': deleteMissing must be 'skip', 'warn', 'mark' or empty (was '$($settings.deleteMissing)')."
        }
    }

    $settings.settingsPath = $Path
    return $settings
}
