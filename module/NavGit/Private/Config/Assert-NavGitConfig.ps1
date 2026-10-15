function Assert-NavGitConfig {
    <#
    .SYNOPSIS
        Validates a merged navgit.json configuration. All problems are collected and thrown as one error.
        Unknown keys in the repository file (RepoConfig) produce warnings, not errors.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config,

        [hashtable] $RepoConfig = @{},

        [string] $ConfigPath = 'navgit.json'
    )

    $errors = New-Object System.Collections.Generic.List[string]

    function Test-String([string] $Name, $Value, [switch] $Required, [string] $Pattern, [string] $PatternHint) {
        if ($null -eq $Value -or ($Value -is [string] -and $Value -eq '')) {
            if ($Required) { $errors.Add("'$Name' is required.") }
            return
        }
        if ($Value -isnot [string]) {
            $errors.Add("'$Name' must be a string.")
            return
        }
        if ($Pattern -and $Value -notmatch $Pattern) {
            $errors.Add("'$Name' ('$Value') $PatternHint")
        }
    }

    function Test-Enum([string] $Name, $Value, [string[]] $Allowed) {
        if ($null -eq $Value) { return }
        if ($Value -isnot [string] -or $Value -notin $Allowed) {
            $shown = ($Allowed | ForEach-Object { "'$_'" }) -join ', '
            $errors.Add("'$Name' must be one of $shown (was '$Value').")
        }
    }

    function Test-Bool([string] $Name, $Value) {
        if ($null -ne $Value -and $Value -isnot [bool]) {
            $errors.Add("'$Name' must be true or false (was '$Value').")
        }
    }

    function Test-StringArray([string] $Name, $Value) {
        if ($null -eq $Value) { return }
        if ($Value -is [string] -or $Value -isnot [System.Collections.IEnumerable] -or $Value -is [hashtable]) {
            $errors.Add("'$Name' must be an array of strings.")
            return
        }
        foreach ($item in $Value) {
            if ($item -isnot [string]) {
                $errors.Add("'$Name' must only contain strings.")
                return
            }
        }
    }

    function Test-Object([string] $Name, $Value) {
        if ($null -ne $Value -and $Value -isnot [hashtable]) {
            $errors.Add("'$Name' must be an object.")
            return $false
        }
        return ($null -ne $Value)
    }

    # Unknown keys (typos) -> warnings
    $knownKeys = Get-NavGitKnownConfigKeys
    foreach ($key in $RepoConfig.Keys) {
        if ($key -eq '$schema') { continue }
        if (-not $knownKeys.ContainsKey($key)) {
            Write-Warning "${ConfigPath}: unknown setting '$key' is ignored."
            continue
        }
        $subKeys = $knownKeys[$key]
        if ($subKeys -and $RepoConfig[$key] -is [hashtable]) {
            foreach ($subKey in $RepoConfig[$key].Keys) {
                if ($subKeys -notcontains $subKey) {
                    Write-Warning "${ConfigPath}: unknown setting '$key.$subKey' is ignored."
                }
            }
        }
    }

    # Identity
    Test-String 'projectName' $Config.projectName -Required
    Test-String 'containerName' $Config.containerName -Required -Pattern '^[A-Za-z0-9][A-Za-z0-9-]{0,14}$' `
        -PatternHint 'must be 1-15 characters (letters, digits, -) and start with a letter or digit.'
    Test-String 'navRelease' $Config.navRelease

    # Artifact
    if ($null -eq $Config.artifact) {
        $errors.Add("'artifact' is required: use { `"url`": ... }, { `"nav`": `"2018`", `"cu`": ... } or { `"version`": `"14.0`" }.")
    }
    elseif (Test-Object 'artifact' $Config.artifact) {
        $artifact = $Config.artifact
        $forms = @(@('url', 'nav', 'version') | Where-Object { $artifact.ContainsKey($_) })
        if ($forms.Count -ne 1) {
            $errors.Add("'artifact' must contain exactly one of 'url', 'nav' or 'version' (found: $(if ($forms.Count) { $forms -join ', ' } else { 'none' })).")
        }
        elseif ($forms[0] -eq 'url') {
            Test-String 'artifact.url' $artifact.url -Required -Pattern '^https://' -PatternHint 'must be an https:// URL.'
            foreach ($extra in @('cu', 'country', 'type', 'select')) {
                if ($artifact.ContainsKey($extra)) { $errors.Add("'artifact.$extra' cannot be combined with 'artifact.url' (the URL already identifies the artifact).") }
            }
        }
        elseif ($forms[0] -eq 'nav') {
            Test-Enum 'artifact.nav' $artifact.nav @('2016', '2017', '2018')
            Test-String 'artifact.cu' $artifact.cu -Pattern '^(rtm|cu\d+)$' -PatternHint "must be 'rtm' or 'cu<number>', e.g. 'cu30'."
            Test-String 'artifact.country' $artifact.country
            foreach ($extra in @('type', 'select')) {
                if ($artifact.ContainsKey($extra)) { $errors.Add("'artifact.$extra' can only be used with 'artifact.version'.") }
            }
        }
        else {
            Test-String 'artifact.version' $artifact.version -Required -Pattern '^\d+(\.\d+){0,3}$' -PatternHint 'must be a version prefix such as 14, 14.0 or 14.0.29537.0.'
            if ($artifact.version -is [string] -and $artifact.version -match '^(\d+)') {
                $major = [int]$Matches[1]
                if ($major -lt 9 -or $major -gt 14) {
                    $errors.Add("'artifact.version' ('$($artifact.version)') must be between 9 (NAV 2016) and 14 (BC14). There are no artifacts before NAV 2016, and C/AL ends with BC14.")
                }
            }
            Test-Enum 'artifact.type' $artifact.type @('OnPrem')
            Test-Enum 'artifact.select' $artifact.select @('Latest', 'First', 'Closest')
            if ($artifact.select -eq 'Closest' -and ($artifact.version -isnot [string] -or $artifact.version -notmatch '^\d+\.\d+\.\d+\.\d+$')) {
                $errors.Add("'artifact.select' = 'Closest' requires a full four-part 'artifact.version'.")
            }
            Test-String 'artifact.country' $artifact.country
            if ($artifact.ContainsKey('cu')) { $errors.Add("'artifact.cu' can only be used with 'artifact.nav'.") }
        }
    }

    Test-String 'imageName' $Config.imageName -Required -Pattern '^[a-z0-9][a-z0-9._-]*$' -PatternHint 'must be lowercase letters, digits, ., _ or -.'

    # Database / license
    if (Test-Object 'database' $Config.database) {
        Test-String 'database.bakFile' $Config.database.bakFile
        Test-Bool 'database.useDemo' $Config.database.useDemo
        Test-StringArray 'database.searchNames' $Config.database.searchNames
        if ($Config.database.useDemo -eq $true -and $Config.database.bakFile) {
            $errors.Add("'database.bakFile' and 'database.useDemo' cannot both be set.")
        }
    }
    Test-String 'licenseFile' $Config.licenseFile

    # Container options
    Test-Enum 'auth' $Config.auth @('Windows', 'NavUserPassword')
    Test-Enum 'isolation' $Config.isolation @('', 'hyperv', 'process')
    Test-String 'memoryLimit' $Config.memoryLimit -Pattern '^\d+(\.\d+)?[MmGg]$' -PatternHint "must look like '8G' or '4096M'."
    Test-String 'dns' $Config.dns
    Test-Bool 'updateHosts' $Config.updateHosts
    Test-Bool 'enableSymbolLoading' $Config.enableSymbolLoading
    Test-Bool 'includeTestToolkit' $Config.includeTestToolkit
    if (Test-Object 'testToolkit' $Config.testToolkit) {
        Test-String 'testToolkit.country' $Config.testToolkit.country
        Test-Bool 'testToolkit.librariesOnly' $Config.testToolkit.librariesOnly
    }
    Test-StringArray 'myScripts' $Config.myScripts
    Test-StringArray 'additionalParameters' $Config.additionalParameters

    # Objects
    if (Test-Object 'paths' $Config.paths) {
        Test-String 'paths.objects' $Config.paths.objects -Required
        Test-String 'paths.tests' $Config.paths.tests -Required
        foreach ($name in @('objects', 'tests')) {
            $value = $Config.paths[$name]
            if ($value -is [string] -and $value -and [System.IO.Path]::IsPathRooted($value)) {
                $errors.Add("'paths.$name' must be relative to the repository (was '$value').")
            }
        }
        if ($Config.paths.objects -is [string] -and $Config.paths.tests -is [string] -and
            $Config.paths.objects.Trim('\', '/') -eq $Config.paths.tests.Trim('\', '/')) {
            $errors.Add("'paths.objects' and 'paths.tests' must be different folders.")
        }
    }
    if (Test-Object 'testObjects' $Config.testObjects) {
        Test-String 'testObjects.versionListPattern' $Config.testObjects.versionListPattern -Required
        if ($Config.testObjects.versionListPattern -is [string] -and $Config.testObjects.versionListPattern) {
            try { [void][regex]::new($Config.testObjects.versionListPattern) }
            catch { $errors.Add("'testObjects.versionListPattern' is not a valid regular expression: $($_.Exception.InnerException.Message)") }
        }
        Test-Bool 'testObjects.includeTestCodeunits' $Config.testObjects.includeTestCodeunits
    }
    if (Test-Object 'import' $Config.import) {
        Test-Enum 'import.deleteMissing' $Config.import.deleteMissing @('warn', 'mark')
        Test-Enum 'import.syncSchema' $Config.import.syncSchema @('Force', 'Yes', 'No')
        Test-String 'import.compileFilter' $Config.import.compileFilter -Required
    }
    if (Test-Object 'export' $Config.export) {
        Test-String 'export.filter' $Config.export.filter -Required
        Test-Enum 'export.format' $Config.export.format @('txt folder')
    }
    if (Test-Object 'client' $Config.client) {
        Test-String 'client.defaultProfile' $Config.client.defaultProfile
    }

    if ($errors.Count -gt 0) {
        $list = ($errors | ForEach-Object { "  - $_" }) -join [Environment]::NewLine
        throw "Invalid NavGit configuration in '$ConfigPath':$([Environment]::NewLine)$list"
    }
}
