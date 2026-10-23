function Get-NAVGitDefaultConfig {
    <#
    .SYNOPSIS
        Default values for navgit.json. The user settings override the result (see Get-NAVGitConfig).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        imageName            = 'navgit'
        database             = @{ useDemo = $false; searchNames = @() }
        licenseFile          = ''
        auth                 = Get-NAVGitDefaultAuth
        isolation            = ''
        memoryLimit          = ''
        dns                  = ''
        updateHosts          = $true
        shortcuts            = 'None'
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
        showBcContainerCommand = $false
    }
}

function Get-NAVGitDefaultAuth {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string] $UserDomain = $env:USERDOMAIN
    )

    # Windows authentication does not work for Azure AD accounts inside the container.
    if ($UserDomain -eq 'AzureAD') {
        return 'NavUserPassword'
    }
    return 'Windows'
}

function Get-NAVGitShortcutsValues {
    <#
    .SYNOPSIS
        The values New-BcContainer -shortcuts accepts (its ValidateSet), for navgit.json and the user settings.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return @('None', 'Desktop', 'StartMenu', 'CommonStartMenu', 'CommonDesktop', 'DesktopFolder', 'CommonDesktopFolder')
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
        Write-NAVGitLog "Windows authentication does not work with Azure AD accounts in a container; using NavUserPassword. Set 'auth' to NavUserPassword in navgit.json or the user settings to silence this warning." -Level Warning
        return 'NavUserPassword'
    }
    return $Auth
}
