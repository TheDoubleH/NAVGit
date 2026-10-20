function Get-NAVGitConfig {
    <#
    .SYNOPSIS
        Loads navgit.json for the repository containing Path, merges it with defaults and user settings,
        validates it and adds resolved context (repositoryPath, configPath, objectsPath, testsPath, userSettings).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [hashtable] $UserSettings
    )

    $configPath = Find-NAVGitConfigFile -Path $Path
    if (-not $configPath) {
        throw "No navgit.json found in '$Path' or any parent folder. Create one with New-NAVGitConfig, or convert an AdvaniaGIT setup.json with ConvertFrom-AdvaniaGitSetup."
    }
    $repositoryPath = Split-Path -Path $configPath -Parent

    try {
        $json = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "'$configPath' is not valid JSON: $($_.Exception.Message)"
    }
    $repoConfig = ConvertTo-NAVGitHashtable $json
    if ($repoConfig -isnot [hashtable]) {
        throw "'$configPath' must contain a JSON object."
    }

    if (-not $UserSettings) {
        $UserSettings = Get-NAVGitUserSettings
    }

    $config = Merge-NAVGitHashtable -Base (Get-NAVGitDefaultConfig -UserSettings $UserSettings) -Override $repoConfig
    $config.Remove('$schema')

    # A personal containerName wins over the repository's; a branch rule gives one container per ticket branch.
    $config.containerName = Resolve-NAVGitContainerName -UserValue $UserSettings.containerName -RepoValue $repoConfig.containerName `
        -ProjectName $config.projectName -RepositoryPath $repositoryPath -SettingsPath $UserSettings.settingsPath -ConfigPath $configPath

    Assert-NAVGitConfig -Config $config -RepoConfig $repoConfig -ConfigPath $configPath

    # A personal deleteMissing wins over the repository's (the other user settings are only defaults).
    if ($UserSettings.deleteMissing -and $UserSettings.deleteMissing -ne $config.import.deleteMissing) {
        Write-NAVGitLog "import.deleteMissing '$($config.import.deleteMissing)' is overridden by the user setting '$($UserSettings.deleteMissing)'." -Level Detail
        $config.import.deleteMissing = $UserSettings.deleteMissing
    }

    $config.repositoryPath = $repositoryPath
    $config.configPath = $configPath
    $config.objectsPath = Join-Path $repositoryPath $config.paths.objects
    $config.testsPath = Join-Path $repositoryPath $config.paths.tests
    $config.addInsPath = $null
    if ($config.paths.addIns) {
        $config.addInsPath = Join-Path $repositoryPath $config.paths.addIns
    }
    $config.userSettings = $UserSettings

    return $config
}
