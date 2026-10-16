function Test-NAVGitAdministrator {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-NAVGitAdministrator {
    <#
    .SYNOPSIS
        Throws unless the session is elevated. BcContainerHelper needs elevation for docker, the hosts file and shared folders.
    #>
    [CmdletBinding()]
    param(
        [string] $Operation = 'This command'
    )

    if (-not (Test-NAVGitAdministrator)) {
        throw "$Operation must run in an elevated PowerShell session (Run as administrator)."
    }
}
