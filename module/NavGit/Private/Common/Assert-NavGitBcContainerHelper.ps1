function Assert-NavGitBcContainerHelper {
    <#
    .SYNOPSIS
        Makes sure BcContainerHelper is imported, honouring the optional version pin in the user settings.
    #>
    [CmdletBinding()]
    param(
        [hashtable] $UserSettings
    )

    if (Get-Module -Name BcContainerHelper) {
        return
    }
    # Already available as a function (e.g. test stubs or a dot-sourced development copy).
    if (Get-Command -Name 'Get-BcArtifactUrl' -CommandType Function -ErrorAction SilentlyContinue) {
        return
    }

    $importParams = @{ Name = 'BcContainerHelper'; DisableNameChecking = $true; ErrorAction = 'Stop'; Global = $true }
    if ($UserSettings -and $UserSettings.bcContainerHelperVersion) {
        $importParams.RequiredVersion = $UserSettings.bcContainerHelperVersion
    }

    try {
        Import-Module @importParams
    }
    catch {
        $hint = 'Install-Module BcContainerHelper -Scope AllUsers'
        if ($importParams.ContainsKey('RequiredVersion')) {
            $hint = "Install-Module BcContainerHelper -RequiredVersion $($importParams.RequiredVersion)"
        }
        throw "BcContainerHelper could not be imported ($($_.Exception.Message)). Install it with: $hint"
    }
}
