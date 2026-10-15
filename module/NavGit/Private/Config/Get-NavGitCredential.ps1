function Get-NavGitCredential {
    <#
    .SYNOPSIS
        Returns the container credential. It is stored DPAPI-encrypted (Export-Clixml, current user only) in
        %LOCALAPPDATA%\NavGit\credentials\<containerName>.xml, falling back to default.xml. Prompts once when missing.
        For Windows authentication the user name must be the current Windows user.
    #>
    [CmdletBinding()]
    [OutputType([pscredential])]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName,

        [Parameter(Mandatory)]
        [ValidateSet('Windows', 'NavUserPassword')]
        [string] $Auth,

        # Ignore stored credentials and prompt again.
        [switch] $Reset,

        # Fail instead of prompting (for background callers).
        [switch] $NoPrompt
    )

    $folder = Get-NavGitDataPath -Name 'credentials'
    $containerFile = Join-Path $folder "$ContainerName.xml"
    $defaultFile = Join-Path $folder 'default.xml'

    if (-not $Reset) {
        foreach ($file in @($containerFile, $defaultFile)) {
            if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
                continue
            }
            try {
                $credential = Import-Clixml -LiteralPath $file
            }
            catch {
                Write-NavGitLog "Stored credential '$file' could not be read and is ignored: $($_.Exception.Message)" -Level Warning
                continue
            }
            if ($Auth -eq 'Windows' -and (Get-NavGitUserNameOnly $credential.UserName) -ne $env:USERNAME) {
                Write-NavGitLog "Stored credential '$file' is for '$($credential.UserName)', but Windows authentication needs '$env:USERNAME'." -Level Detail
                continue
            }
            return $credential
        }
    }

    if ($NoPrompt) {
        throw "No stored credential for container '$ContainerName'. Run a container command in a terminal once to enter it."
    }

    if ($Auth -eq 'Windows') {
        $message = "Enter your Windows password for the NAV container '$ContainerName' (Windows authentication)"
        $defaultUser = $env:USERNAME
    }
    else {
        $message = "Enter the NAV user name and password for the container '$ContainerName' (NavUserPassword; also used as SQL 'sa' password)"
        $defaultUser = 'admin'
    }

    $credential = Get-Credential -UserName $defaultUser -Message $message
    if (-not $credential) {
        throw 'No credential entered.'
    }
    if ($Auth -eq 'Windows' -and (Get-NavGitUserNameOnly $credential.UserName) -ne $env:USERNAME) {
        throw "Windows authentication requires the current Windows user '$env:USERNAME' (got '$($credential.UserName)')."
    }

    $credential | Export-Clixml -LiteralPath $defaultFile -Force
    Write-NavGitLog "Credential saved (encrypted for $env:USERNAME) to $defaultFile" -Level Detail
    return $credential
}

function Get-NavGitUserNameOnly {
    param([string] $UserName)
    # DOMAIN\user -> user, user@domain -> user
    return (($UserName -split '\\')[-1] -split '@')[0]
}
