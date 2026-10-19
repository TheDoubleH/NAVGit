function Get-NAVGitDefaultConfig {
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
        auth                 = Get-NAVGitDefaultAuth -UserSettings $UserSettings
        isolation            = $isolation
        memoryLimit          = ''
        dns                  = ''
        updateHosts          = $true
        enableSymbolLoading  = $false
        includeTestToolkit   = $false
        testToolkit          = @{ country = ''; librariesOnly = $false }
        myScripts            = @()
        additionalParameters = @()
        paths                = @{ objects = 'Objects'; tests = 'Tests'; addIns = 'Add-Ins' }
        testObjects          = @{ versionListPattern = '(^|,)\s*Test'; includeTestCodeunits = $true }
        import               = @{ deleteMissing = 'skip'; syncSchema = 'Force'; compileFilter = 'Compiled=0'; dateFormat = '' }
        export               = @{ filter = ''; format = 'txt folder' }
        client               = @{ defaultProfile = '' }
        showBcContainerCommand = ($UserSettings.showBcContainerCommand -eq $true)
    }
}

function Get-NAVGitDefaultAuth {
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

function Get-NAVGitEffectiveAuth {
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
        Write-NAVGitLog "Windows authentication does not work with Azure AD accounts in a container; using NavUserPassword. Set 'auth' to NavUserPassword in navgit.json to silence this warning." -Level Warning
        return 'NavUserPassword'
    }
    return $Auth
}
