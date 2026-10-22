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

    # Every setting except the folders, the BcContainerHelper pin and uidOffset overrides navgit.json when it is set.
    $settings = @{
        backupFolder             = ''
        licenseFolder            = ''
        bcContainerHelperVersion = ''
        auth                     = ''
        isolation                = ''
        # $null = not set; navgit.json (or the default) is used.
        showBcContainerCommand   = $null
        deleteMissing            = ''
        # A name or an object (see navgit.json).
        containerName            = ''
        # @{ url = '<artifact url>' } or $null.
        artifact                 = $null
        # C/SIDE Uid Offset written to the database after a build; '' = leave the backup's value.
        uidOffset                = ''
    }
    # Earlier names, from when these settings were only defaults.
    $renamedKeys = @{ defaultAuth = 'auth'; defaultIsolation = 'isolation' }
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

        foreach ($fileKey in $fileSettings.Keys) {
            $key = $fileKey
            if ($renamedKeys.ContainsKey($fileKey)) {
                $key = $renamedKeys[$fileKey]
                if ($fileSettings.ContainsKey($key)) {
                    Write-Warning "NAVGit user settings '$Path': '$fileKey' is ignored because '$key' is set."
                    continue
                }
                Write-Warning "NAVGit user settings '$Path': '$fileKey' is now called '$key'; rename it."
            }
            if (-not $settings.ContainsKey($key)) {
                Write-Warning "NAVGit user settings '$Path': unknown setting '$key' is ignored."
                continue
            }
            if ($booleanKeys -contains $key) {
                if ($fileSettings[$fileKey] -isnot [bool]) {
                    throw "NAVGit user settings '$Path': $key must be true or false (was '$($fileSettings[$fileKey])')."
                }
                $settings[$key] = $fileSettings[$fileKey]
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
            if ($key -eq 'artifact') {
                $artifact = $fileSettings[$key]
                if ($artifact -isnot [hashtable] -or -not ($artifact.url -is [string] -and $artifact.url -match '^https://')) {
                    throw "NAVGit user settings '$Path': artifact must be { `"url`": `"https://...`" }."
                }
                foreach ($subKey in $artifact.Keys) {
                    if ($subKey -ne 'url') {
                        Write-Warning "NAVGit user settings '$Path': unknown setting 'artifact.$subKey' is ignored."
                    }
                }
                $settings[$key] = @{ url = $artifact.url }
                continue
            }
            $settings[$key] = [string]$fileSettings[$fileKey]
        }

        if ($settings.auth -and $settings.auth -notin @('Windows', 'NavUserPassword')) {
            throw "NAVGit user settings '$Path': auth must be 'Windows' or 'NavUserPassword' (was '$($settings.auth)')."
        }
        if ($settings.isolation -and $settings.isolation -notin @('hyperv', 'process')) {
            throw "NAVGit user settings '$Path': isolation must be 'hyperv', 'process' or empty (was '$($settings.isolation)')."
        }
        if ($settings.deleteMissing -and $settings.deleteMissing -notin @('skip', 'warn', 'mark')) {
            throw "NAVGit user settings '$Path': deleteMissing must be 'skip', 'warn', 'mark' or empty (was '$($settings.deleteMissing)')."
        }
        $uidOffset = 0
        if ($settings.uidOffset -and -not ($settings.uidOffset -match '^\d+$' -and [int]::TryParse($settings.uidOffset, [ref]$uidOffset))) {
            throw "NAVGit user settings '$Path': uidOffset must be a whole number from 0 to 2147483647 or empty (was '$($settings.uidOffset)')."
        }
    }

    $settings.settingsPath = $Path
    return $settings
}
