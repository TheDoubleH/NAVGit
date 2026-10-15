function Resolve-NavGitArtifactUrl {
    <#
    .SYNOPSIS
        Resolves the configured artifact to a concrete artifact URL and returns
        [pscustomobject]@{ Url; Version; Country; NavRelease }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config
    )

    $artifact = $Config.artifact
    $country = 'w1'
    if ($artifact.country) {
        $country = $artifact.country.ToLowerInvariant()
    }

    if ($artifact.url) {
        $url = $artifact.url
        $description = $url
    }
    elseif ($artifact.nav) {
        Assert-NavGitBcContainerHelper -UserSettings $Config.userSettings
        $params = @{ nav = $artifact.nav; country = $country; select = 'Latest' }
        if ($artifact.cu) {
            $params.cu = $artifact.cu.ToLowerInvariant()
        }
        $description = "NAV $($artifact.nav) $(if ($artifact.cu) { $artifact.cu } else { 'latest CU' }) ($country)"
        Write-NavGitLog "Resolving artifact for $description" -Level Detail
        $url = Get-NavArtifactUrl @params
    }
    else {
        Assert-NavGitBcContainerHelper -UserSettings $Config.userSettings
        $select = 'Latest'
        if ($artifact.select) {
            $select = $artifact.select
        }
        $params = @{ type = 'OnPrem'; version = $artifact.version; country = $country; select = $select }
        $description = "OnPrem $($artifact.version) ($country, $select)"
        Write-NavGitLog "Resolving artifact for $description" -Level Detail
        $url = Get-BcArtifactUrl @params
    }

    $url = @($url | Where-Object { $_ }) | Select-Object -First 1
    if (-not $url) {
        throw "No artifact found for $description. Check 'artifact' in $($Config.configPath)."
    }

    $info = ConvertFrom-NavGitArtifactUrl -Url $url
    if ($info.Version.Major -lt 9 -or $info.Version.Major -gt 14) {
        throw "Artifact $url is version $($info.Version). NavGit supports NAV 2016 (9.0) to BC14 (14.x) only."
    }

    return [pscustomobject]@{
        Url        = $url
        Version    = $info.Version
        Country    = $info.Country
        NavRelease = Get-NavGitNavRelease -Version $info.Version -Override $Config.navRelease
    }
}

function ConvertFrom-NavGitArtifactUrl {
    <#
    .SYNOPSIS
        Extracts version and country from an artifact URL such as https://<cdn>/onprem/11.0.48560.0/no[?sas].
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Url
    )

    if ($Url -notmatch '/(?<type>onprem|sandbox)/(?<version>\d+(\.\d+){1,3})/(?<country>[A-Za-z0-9-]+)/?(\?|$)') {
        throw "'$Url' is not a recognised artifact URL (expected .../onprem/<version>/<country>)."
    }
    if ($Matches.type -ne 'onprem') {
        throw "'$Url' is a sandbox artifact. NavGit (C/AL) needs OnPrem artifacts."
    }

    return [pscustomobject]@{
        Version = [version]$Matches.version
        Country = $Matches.country.ToLowerInvariant()
    }
}

function Get-NavGitNavRelease {
    <#
    .SYNOPSIS
        Release name used in backup file names (AdvaniaGIT compatible): 9 -> 2016, 10 -> 2017, 11 -> 2018, 13 -> 2019, 14 -> BC14.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [version] $Version,

        [string] $Override
    )

    if ($Override) {
        return $Override
    }
    switch ($Version.Major) {
        9 { return '2016' }
        10 { return '2017' }
        11 { return '2018' }
        13 { return '2019' }
        14 { return 'BC14' }
        default { return "$($Version.Major).$($Version.Minor)" }
    }
}
