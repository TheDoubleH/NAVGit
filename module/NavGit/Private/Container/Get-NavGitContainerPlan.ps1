function Get-NavGitContainerPlan {
    <#
    .SYNOPSIS
        Resolves artifact, backup and license for a configuration and builds the New-BcContainer parameters.
        Returns [pscustomobject]@{ Artifact; Backup; LicenseFile; Parameters }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config,

        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    $artifact = Resolve-NavGitArtifactUrl -Config $Config
    $backup = Resolve-NavGitBackupFile -Config $Config -ArtifactInfo $artifact
    $licenseFile = Resolve-NavGitLicenseFile -Config $Config -ArtifactInfo $artifact

    $addInsFolder = $null
    if ($Config.addInsPath -and (Test-Path -LiteralPath $Config.addInsPath -PathType Container)) {
        $addInsFolder = (Resolve-Path -LiteralPath $Config.addInsPath).ProviderPath
    }

    $parameters = ConvertTo-NavGitContainerParameters -Config $Config -ArtifactInfo $artifact -Backup $backup `
        -LicenseFile $licenseFile -Credential $Credential -AddInsFolder $addInsFolder

    return [pscustomobject]@{
        Artifact     = $artifact
        Backup       = $backup
        LicenseFile  = $licenseFile
        AddInsFolder = $addInsFolder
        Parameters   = $parameters
    }
}

function Write-NavGitContainerPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Plan
    )

    $p = $Plan.Parameters
    Write-NavGitLog "Container : $($p.containerName)"
    Write-NavGitLog "Artifact  : $($Plan.Artifact.Url) (NAV $($Plan.Artifact.NavRelease), $($Plan.Artifact.Version))"
    switch ($Plan.Backup.Source) {
        'Demo' { Write-NavGitLog 'Database  : Cronus demo database from the artifact (database.useDemo)' }
        default { Write-NavGitLog "Database  : $($Plan.Backup.Path) ($($Plan.Backup.Source)); image '$($p.imageName)' is built without the Cronus database" }
    }
    if ($Plan.LicenseFile) {
        Write-NavGitLog "License   : $($Plan.LicenseFile)"
    }
    if ($Plan.AddInsFolder) {
        Write-NavGitLog "Add-ins   : $($Plan.AddInsFolder)"
    }
    $isolation = 'chosen by BcContainerHelper'
    if ($p.isolation) { $isolation = $p.isolation }
    Write-NavGitLog "Isolation : $isolation"
    if ($p.isolation -eq 'hyperv' -and -not $p.memoryLimit) {
        Write-NavGitLog 'Memory    : not set; BcContainerHelper uses 8G for Hyper-V isolation'
    }
    elseif ($p.memoryLimit) {
        Write-NavGitLog "Memory    : $($p.memoryLimit)"
    }
    Write-NavGitLog "Auth      : $($p.auth) ($($p.Credential.UserName))"
}
