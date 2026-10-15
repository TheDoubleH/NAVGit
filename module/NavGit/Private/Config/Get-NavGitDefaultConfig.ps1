function Get-NavGitDefaultConfig {
    <#
    .SYNOPSIS
        Default values for navgit.json. User settings supply the defaults for auth and isolation;
        a value present in navgit.json always wins (also an explicit empty isolation).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $UserSettings
    )

    $isolation = ''
    if ($UserSettings.defaultIsolation) {
        $isolation = $UserSettings.defaultIsolation
    }

    return @{
        imageName            = 'navgit'
        database             = @{ useDemo = $false; searchNames = @() }
        licenseFile          = ''
        auth                 = Get-NavGitDefaultAuth -UserSettings $UserSettings
        isolation            = $isolation
        memoryLimit          = ''
        dns                  = ''
        updateHosts          = $true
        enableSymbolLoading  = $false
        includeTestToolkit   = $false
        testToolkit          = @{ country = ''; librariesOnly = $false }
        myScripts            = @()
        additionalParameters = @()
        paths                = @{ objects = 'Objects'; tests = 'Tests' }
        testObjects          = @{ versionListPattern = '(^|,)\s*Test'; includeTestCodeunits = $true }
        import               = @{ deleteMissing = 'warn'; syncSchema = 'Force'; compileFilter = 'Compiled=0' }
        export               = @{ filter = 'Id=1..1999999999'; format = 'txt folder' }
        client               = @{ defaultProfile = '' }
    }
}

function Get-NavGitDefaultAuth {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $UserSettings,

        [string] $UserDomain = $env:USERDOMAIN
    )

    if ($UserSettings.defaultAuth) {
        return $UserSettings.defaultAuth
    }
    # Windows authentication does not work for Azure AD accounts inside the container.
    if ($UserDomain -eq 'AzureAD') {
        return 'NavUserPassword'
    }
    return 'Windows'
}

function Get-NavGitEffectiveAuth {
    <#
    .SYNOPSIS
        Windows authentication cannot be used with Azure AD accounts in a container; falls back to NavUserPassword with a warning.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Auth,

        [string] $UserDomain = $env:USERDOMAIN
    )

    if ($Auth -eq 'Windows' -and $UserDomain -eq 'AzureAD') {
        Write-NavGitLog "Windows authentication does not work with Azure AD accounts in a container; using NavUserPassword. Set 'auth' to NavUserPassword in navgit.json to silence this warning." -Level Warning
        return 'NavUserPassword'
    }
    return $Auth
}
