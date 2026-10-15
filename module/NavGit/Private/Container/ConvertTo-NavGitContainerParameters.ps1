function ConvertTo-NavGitContainerParameters {
    <#
    .SYNOPSIS
        Builds the splat for New-BcContainer from the configuration and the resolved artifact, backup, license and
        credential. Pure function: no I/O. Everything that has a native New-BcContainer parameter is passed as one;
        additionalParameters only carries what is left (validated by Assert-NavGitAdditionalParameters).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config,

        [Parameter(Mandatory)]
        $ArtifactInfo,

        # Result of Resolve-NavGitBackupFile (Path = $null means the Cronus demo database).
        [Parameter(Mandatory)]
        $Backup,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $LicenseFile,

        [Parameter(Mandatory)]
        [pscredential] $Credential,

        [string] $UserDomain = $env:USERDOMAIN
    )

    $major = $ArtifactInfo.Version.Major
    if ($major -lt 9 -or $major -gt 14) {
        throw "Version $($ArtifactInfo.Version) is not supported. NavGit supports NAV 2016 (9.0) to BC14 (14.x)."
    }

    $auth = Get-NavGitEffectiveAuth -Auth $Config.auth -UserDomain $UserDomain

    if ($Config.enableSymbolLoading -and $major -lt 11) {
        throw "enableSymbolLoading requires NAV 2018 (11.0) or later; the artifact is $($ArtifactInfo.Version)."
    }

    $additionalParameters = @($Config.additionalParameters | Where-Object { $_ })
    Assert-NavGitAdditionalParameters -AdditionalParameters $additionalParameters

    $params = [ordered]@{
        accept_eula              = $true
        accept_outdated          = $true
        containerName            = $Config.containerName
        artifactUrl              = $ArtifactInfo.Url
        imageName                = $Config.imageName
        auth                     = $auth
        Credential               = $Credential
        includeCSide             = $true
        doNotExportObjectsToText = $true
        updateHosts              = [bool]$Config.updateHosts
        shortcuts                = 'None'
        restart                  = 'unless-stopped'
    }

    if ($Backup.Path) {
        $params.bakFile = $Backup.Path
    }
    if ($LicenseFile) {
        $params.licenseFile = $LicenseFile
    }
    if ($Config.isolation) {
        $params.isolation = $Config.isolation
    }
    if ($Config.memoryLimit) {
        $params.memoryLimit = $Config.memoryLimit
    }
    if ($Config.dns) {
        $params.dns = $Config.dns
    }
    if ($Config.enableSymbolLoading) {
        $params.enableSymbolLoading = $true
    }
    if ($Config.includeTestToolkit) {
        $params.includeTestToolkit = $true
        if ($Config.testToolkit.librariesOnly) {
            $params.includeTestLibrariesOnly = $true
        }
    }
    $myScripts = @($Config.myScripts | Where-Object { $_ })
    if ($myScripts.Count -gt 0) {
        $params.myScripts = $myScripts
    }
    if ($additionalParameters.Count -gt 0) {
        $params.additionalParameters = $additionalParameters
    }

    # Return a plain hashtable (splatting works with both, but tests and callers expect [hashtable]).
    $result = @{}
    foreach ($key in $params.Keys) { $result[$key] = $params[$key] }
    return $result
}

function Format-NavGitContainerCommand {
    <#
    .SYNOPSIS
        Renders a New-BcContainer splat as readable PowerShell, with the credential masked.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Parameters
    )

    $order = @('accept_eula', 'accept_outdated', 'containerName', 'artifactUrl', 'imageName', 'bakFile', 'licenseFile',
        'auth', 'Credential', 'isolation', 'memoryLimit', 'dns', 'includeCSide', 'doNotExportObjectsToText',
        'enableSymbolLoading', 'includeTestToolkit', 'includeTestLibrariesOnly', 'updateHosts', 'shortcuts', 'restart',
        'myScripts', 'additionalParameters')
    $keys = @($order | Where-Object { $Parameters.ContainsKey($_) }) + @($Parameters.Keys | Where-Object { $order -notcontains $_ } | Sort-Object)

    $lines = @('New-BcContainer')
    foreach ($key in $keys) {
        $value = $Parameters[$key]
        if ($value -is [bool]) {
            if ($value) { $lines += "-$key" } else { $lines += "-${key}:`$false" }
        }
        elseif ($value -is [pscredential]) {
            $lines += "-$key (credential for '$($value.UserName)', password hidden)"
        }
        elseif ($value -is [array]) {
            $lines += "-$key @($(($value | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ', '))"
        }
        else {
            $lines += "-$key '$($value -replace "'", "''")'"
        }
    }
    return ($lines -join " ``$([Environment]::NewLine)    ")
}
