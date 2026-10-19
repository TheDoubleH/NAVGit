function ConvertFrom-AdvaniaGitSetup {
    <#
    .SYNOPSIS
        Creates navgit.json from an AdvaniaGIT setup.json (merged with AdvaniaGIT's GITSettings.Json defaults,
        setup.json wins as in AdvaniaGIT).
    .DESCRIPTION
        Mapping:
          projectName -> projectName            dockerFriendlyName -> containerName
          artifact (URL or storageAccount/type/version/country/select) or navVersion -> artifact
          dockerRestoreBackup -> database (search the backup folder for projectName, baseBranch, navSolution);
                                 not set -> database.useDemo
          licenseFile (%1 -> {major}) -> licenseFile
          dockerAuthentication -> auth          dockerIsolation -> isolation      dockerMemoryLimit -> memoryLimit
          dockerTestToolkit / dockerTestLibraries / testToolkitCountry -> includeTestToolkit, testToolkit
          dockerEnableSymbolLoading -> enableSymbolLoading                         dockerMyScripts -> myScripts
          objectsPath / testObjectsPath -> paths
        Settings without an equivalent are reported.
    .PARAMETER Path
        Repository folder containing setup.json. Default: current location.
    .PARAMETER GitSettingsPath
        AdvaniaGIT GITSettings.Json with the defaults. Default: C:\AdvaniaGIT\Data\GITSettings.Json (skipped if missing).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [string] $SetupFile = 'setup.json',

        [string] $GitSettingsPath = 'C:\AdvaniaGIT\Data\GITSettings.Json',

        [switch] $Force
    )

    $Path = (Resolve-Path -LiteralPath $Path).ProviderPath
    $setupPath = Join-Path $Path $SetupFile
    if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
        throw "'$setupPath' not found."
    }
    $target = Join-Path $Path 'navgit.json'
    if ((Test-Path -LiteralPath $target) -and -not $Force) {
        throw "'$target' already exists. Use -Force to overwrite it."
    }

    $setup = ConvertTo-NAVGitHashtable (Get-Content -LiteralPath $setupPath -Raw | ConvertFrom-Json)
    $settings = @{}
    if ($GitSettingsPath -and (Test-Path -LiteralPath $GitSettingsPath -PathType Leaf)) {
        $settings = ConvertTo-NAVGitHashtable (Get-Content -LiteralPath $GitSettingsPath -Raw | ConvertFrom-Json)
    }
    # AdvaniaGIT's Combine-Settings: setup.json wins over GITSettings.
    $merged = Merge-NAVGitHashtable -Base $settings -Override $setup

    $result = ConvertFrom-AdvaniaGitSettings -Settings $merged
    foreach ($note in $result.Notes) {
        Write-NAVGitLog $note -Level Warning
    }

    $testsFolder = 'Tests'
    if ($result.Config.Contains('paths') -and $result.Config.paths.Contains('tests')) { $testsFolder = $result.Config.paths.tests }
    if (-not $result.Config.Contains('includeTestToolkit') -and (Get-NAVGitObjectFiles -Folder (Join-Path $Path $testsFolder)).Count -gt 0) {
        Write-NAVGitLog "The $testsFolder folder has test objects. Set `"includeTestToolkit`": true so Build and Update imports the test toolkit before your objects (or run Import Test Toolkit afterwards)." -Level Warning
    }

    # AdvaniaGIT kept backups and licenses under its root folder; point out the NAVGit user settings for them.
    $userSettings = Get-NAVGitUserSettings
    $advaniaRoot = Split-Path -Path (Split-Path -Path $GitSettingsPath -Parent) -Parent
    foreach ($pair in @(@{ Setting = 'backupFolder'; Folder = 'Backup' }, @{ Setting = 'licenseFolder'; Folder = 'License' })) {
        $folder = Join-Path $advaniaRoot $pair.Folder
        if (-not $userSettings[$pair.Setting] -and (Test-Path -LiteralPath $folder -PathType Container)) {
            Write-NAVGitLog "AdvaniaGIT used '$folder'. Add `"$($pair.Setting)`": `"$($folder.Replace('\', '\\'))`" to $($userSettings.settingsPath) to keep using it." -Level Warning
        }
    }
    Write-NAVGitConfigFile -Config $result.Config -Path $target -WhatIf:$WhatIfPreference
}

function ConvertFrom-AdvaniaGitSettings {
    <#
    .SYNOPSIS
        Pure mapping of merged AdvaniaGIT settings to a navgit.json structure. Returns @{ Config; Notes }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Settings
    )

    $notes = New-Object System.Collections.Generic.List[string]
    function Test-True($Value) { return ($Value -eq $true -or "$Value" -ieq 'true') }

    if (-not $Settings.projectName) {
        throw 'setup.json has no projectName.'
    }
    $config = [ordered]@{ projectName = [string]$Settings.projectName }

    if ($Settings.dockerFriendlyName) {
        $config.containerName = [string]$Settings.dockerFriendlyName
    }

    # Artifact
    $artifact = [string]$Settings.artifact
    if ($artifact -match '^https://') {
        $config.artifact = [ordered]@{ url = $artifact }
    }
    elseif ($artifact -and $artifact.Contains('/')) {
        # storageAccount/type/version/country/select
        $segments = @($artifact.Split('/')) + @('', '', '', '', '')
        $storage = $segments[0]; $type = $segments[1]; $version = $segments[2]; $country = $segments[3]; $select = $segments[4]
        if ($type -and $type -ine 'onprem') {
            $notes.Add("artifact '$artifact' is not an OnPrem artifact; set 'artifact' manually.")
        }
        if ($storage -and $storage -ine 'bcartifacts') {
            $notes.Add("artifact storage account '$storage' is not supported; using the public bcartifacts feed.")
        }
        $config.artifact = [ordered]@{ version = $version }
        if ($country) { $config.artifact.country = $country.ToLowerInvariant() }
        if ($select -in @('Latest', 'First', 'Closest')) { $config.artifact.select = $select }
    }
    elseif ($Settings.navVersion) {
        $config.artifact = [ordered]@{ version = [string]$Settings.navVersion; country = 'w1' }
        if ([string]$Settings.navVersion -match '^\d+\.\d+\.\d+\.\d+$') { $config.artifact.select = 'Closest' }
        $notes.Add("artifact derived from navVersion $($Settings.navVersion) with country 'w1'; check artifact.country.")
    }
    else {
        $config.artifact = [ordered]@{ nav = '2018'; country = 'w1' }
        $notes.Add("setup.json has no artifact or navVersion; set 'artifact' in navgit.json.")
    }
    if ($Settings.dockerImage) {
        $notes.Add("dockerImage '$($Settings.dockerImage)' is not supported (images are no longer published); the artifact is used instead.")
    }

    # Database
    if (Test-True $Settings.dockerRestoreBackup) {
        $searchNames = @(@($Settings.baseBranch, $Settings.navSolution) | Where-Object { $_ } | ForEach-Object { [string]$_ })
        $database = [ordered]@{}
        if ($searchNames.Count -gt 0) { $database.searchNames = $searchNames }
        $config.database = $database
        $notes.Add("database: the backup is searched in the 'backupFolder' of the NAVGit user settings (AdvaniaGIT used C:\AdvaniaGIT\Backup). Set database.bakFile to point at a file directly.")
    }
    else {
        $config.database = [ordered]@{ useDemo = $true }
    }

    if ($Settings.licenseFile) {
        $config.licenseFile = ([string]$Settings.licenseFile).Replace('%1', '{major}')
    }

    if ($Settings.dockerAuthentication) {
        if ($Settings.dockerAuthentication -in @('Windows', 'NavUserPassword')) {
            $config.auth = [string]$Settings.dockerAuthentication
        }
        else {
            $notes.Add("dockerAuthentication '$($Settings.dockerAuthentication)' is not supported.")
        }
    }
    if ($Settings.dockerIsolation) {
        if ($Settings.dockerIsolation -in @('hyperv', 'process')) {
            $config.isolation = ([string]$Settings.dockerIsolation).ToLowerInvariant()
        }
        else {
            $notes.Add("dockerIsolation '$($Settings.dockerIsolation)' is not supported.")
        }
    }
    if ($Settings.dockerMemoryLimit) {
        $config.memoryLimit = [string]$Settings.dockerMemoryLimit
    }
    if (Test-True $Settings.dockerEnableSymbolLoading) {
        $config.enableSymbolLoading = $true
    }

    $testToolkit = Test-True $Settings.dockerTestToolkit
    $testLibraries = Test-True $Settings.dockerTestLibraries
    if ($testToolkit -or $testLibraries) {
        $config.includeTestToolkit = $true
    }
    $toolkitSettings = [ordered]@{}
    if ($testLibraries -and -not $testToolkit) { $toolkitSettings.librariesOnly = $true }
    if ($Settings.testToolkitCountry) { $toolkitSettings.country = [string]$Settings.testToolkitCountry }
    if ($toolkitSettings.Count -gt 0) { $config.testToolkit = $toolkitSettings }

    if ($Settings.dockerMyScripts) {
        $config.myScripts = @($Settings.dockerMyScripts | ForEach-Object { [string]$_ })
    }

    $paths = [ordered]@{}
    if ($Settings.objectsPath -and $Settings.objectsPath -ne 'Objects') { $paths.objects = [string]$Settings.objectsPath }
    if ($Settings.testObjectsPath -and $Settings.testObjectsPath -ne 'Tests') { $paths.tests = [string]$Settings.testObjectsPath }
    if ($paths.Count -gt 0) { $config.paths = $paths }

    if ($Settings.datetimeCulture) {
        try {
            # C/AL object files use a two-digit year: en-US M/d/yyyy -> M/d/yy, nb-NO dd.MM.yyyy -> dd.MM.yy
            $pattern = [System.Globalization.CultureInfo]::GetCultureInfo([string]$Settings.datetimeCulture).DateTimeFormat.ShortDatePattern
            $config.import = [ordered]@{ dateFormat = $pattern.Replace('yyyy', 'yy') }
        }
        catch {
            $notes.Add("datetimeCulture '$($Settings.datetimeCulture)' is not a known culture; set import.dateFormat (e.g. 'dd.MM.yy') if objects are re-imported every time.")
        }
    }
    if ($Settings.ContainsKey('storeAllObjects') -and -not (Test-True $Settings.storeAllObjects)) {
        $notes.Add('storeAllObjects is false (deltas). NAVGit works with complete object files only.')
    }
    # mapAddInFolder=true maps <repo>\Add-Ins, which is NAVGit's default (paths.addIns); false disables it.
    if ($Settings.ContainsKey('mapAddInFolder') -and -not (Test-True $Settings.mapAddInFolder)) {
        if (-not $config.Contains('paths')) { $config.paths = [ordered]@{} }
        $config.paths.addIns = ''
    }

    return @{ Config = $config; Notes = $notes.ToArray() }
}
