function Get-NAVGitContainerPlan {
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

    $artifact = Resolve-NAVGitArtifactUrl -Config $Config
    $backup = Resolve-NAVGitBackupFile -Config $Config -ArtifactInfo $artifact
    $licenseFile = Resolve-NAVGitLicenseFile -Config $Config -ArtifactInfo $artifact

    $addInsFolder = $null
    if ($Config.addInsPath -and (Test-Path -LiteralPath $Config.addInsPath -PathType Container)) {
        $addInsFolder = (Resolve-Path -LiteralPath $Config.addInsPath).ProviderPath
    }

    $parameters = ConvertTo-NAVGitContainerParameters -Config $Config -ArtifactInfo $artifact -Backup $backup `
        -LicenseFile $licenseFile -Credential $Credential -AddInsFolder $addInsFolder

    return [pscustomobject]@{
        Artifact     = $artifact
        Backup       = $backup
        LicenseFile  = $licenseFile
        AddInsFolder = $addInsFolder
        Parameters   = $parameters
    }
}

function Write-NAVGitContainerPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Plan
    )

    $p = $Plan.Parameters
    Write-NAVGitLog "Container : $($p.containerName)"
    Write-NAVGitLog "Artifact  : $($Plan.Artifact.Url) (NAV $($Plan.Artifact.NavRelease), $($Plan.Artifact.Version))"
    switch ($Plan.Backup.Source) {
        'Demo' { Write-NAVGitLog 'Database  : Cronus demo database from the artifact (database.useDemo)' }
        default { Write-NAVGitLog "Database  : $($Plan.Backup.Path) ($($Plan.Backup.Source)); image '$($p.imageName)' is built without the Cronus database" }
    }
    if ($Plan.LicenseFile) {
        Write-NAVGitLog "License   : $($Plan.LicenseFile)"
    }
    if ($Plan.AddInsFolder) {
        Write-NAVGitLog "Add-ins   : $($Plan.AddInsFolder)"
    }
    $isolation = 'chosen by BcContainerHelper'
    if ($p.isolation) { $isolation = $p.isolation }
    Write-NAVGitLog "Isolation : $isolation"
    if ($p.isolation -eq 'hyperv' -and -not $p.memoryLimit) {
        Write-NAVGitLog 'Memory    : not set; BcContainerHelper uses 8G for Hyper-V isolation'
    }
    elseif ($p.memoryLimit) {
        Write-NAVGitLog "Memory    : $($p.memoryLimit)"
    }
    Write-NAVGitLog "Auth      : $($p.auth) ($($p.Credential.UserName))"
}
