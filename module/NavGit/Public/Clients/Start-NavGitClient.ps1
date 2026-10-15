function Start-NavGitClient {
    <#
    .SYNOPSIS
        Start NAV Client: opens the Windows client connected to the repository's container.
    .DESCRIPTION
        Without a profile the client opens the default role center (or client.defaultProfile from navgit.json).
        -ProfileId opens a specific profile; -SelectProfile shows the profiles and lets you pick one in the console.
        Needs no elevation; uses the client files BcContainerHelper copied to this machine.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    .PARAMETER ProfileId
        Profile ID to open, e.g. 'ORDER PROCESSOR'.
    .PARAMETER SelectProfile
        Pick the profile from a list (console).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [Parameter(ParameterSetName = 'Profile')]
        [string] $ProfileId,

        [Parameter(ParameterSetName = 'Select')]
        [switch] $SelectProfile
    )

    $context = Get-NavGitClientContext -Path $Path
    $client = Join-Path $context.State.clientFolder 'Microsoft.Dynamics.Nav.Client.exe'
    if (-not (Test-Path -LiteralPath $client -PathType Leaf)) {
        throw "Microsoft.Dynamics.Nav.Client.exe was not found in $($context.State.clientFolder)."
    }

    if ($SelectProfile) {
        $ProfileId = Select-NavGitProfile -Profiles @(Get-NavGitProfile -Path $Path)
    }
    elseif (-not $ProfileId -and $context.Config.client.defaultProfile) {
        $ProfileId = $context.Config.client.defaultProfile
    }

    $arguments = Get-NavGitClientArguments -State $context.State -ProfileId $ProfileId
    $what = 'default role center'
    if ($ProfileId) { $what = "profile '$ProfileId'" }
    Write-NavGitLog "Starting the Windows client for '$($context.State.containerName)' ($what)" -Level Step
    Start-Process -FilePath $client -ArgumentList $arguments -WorkingDirectory $context.State.clientFolder
}

function Select-NavGitProfile {
    <#
    .SYNOPSIS
        Console menu like AdvaniaGIT's: numbered profiles, Enter for the default role center. Returns the profile ID or $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Profiles
    )

    if ($Profiles.Count -eq 0) {
        Write-NavGitLog 'No profiles found; opening the default role center.' -Level Warning
        return $null
    }

    for ($i = 0; $i -lt $Profiles.Count; $i++) {
        $marker = ''
        if ($Profiles[$i].IsDefault) { $marker = ' (default)' }
        Write-Host ("{0,3}  {1,-30} {2}{3}" -f ($i + 1), $Profiles[$i].Id, $Profiles[$i].Description, $marker)
    }

    while ($true) {
        $answer = Read-Host 'Select a profile (Enter for the default role center)'
        if (-not $answer) { return $null }
        $number = 0
        if ([int]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $Profiles.Count) {
            return $Profiles[$number - 1].Id
        }
        Write-Host "Enter a number between 1 and $($Profiles.Count)."
    }
}
