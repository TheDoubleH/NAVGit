function New-NAVGitConfig {
    <#
    .SYNOPSIS
        Creates a navgit.json in the repository folder.
    .EXAMPLE
        New-NAVGitConfig -ProjectName Customer -Nav 2018 -Cu cu30 -Country no -BakFile 'C:\Backups\Customer.bak'
    .EXAMPLE
        New-NAVGitConfig -Version 14.0 -Country w1 -UseDemo
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Nav')]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        # Default: the folder name.
        [string] $ProjectName,

        [Parameter(ParameterSetName = 'Nav')]
        [ValidateSet('2016', '2017', '2018')]
        [string] $Nav = '2018',

        [Parameter(ParameterSetName = 'Nav')]
        [string] $Cu,

        [Parameter(Mandatory, ParameterSetName = 'Version')]
        [string] $Version,

        [Parameter(Mandatory, ParameterSetName = 'Url')]
        [string] $ArtifactUrl,

        [string] $Country = 'w1',

        [string] $BakFile,

        [switch] $UseDemo,

        [string] $LicenseFile,

        [ValidateSet('Windows', 'NavUserPassword')]
        [string] $Auth,

        [ValidateSet('', 'hyperv', 'process')]
        [string] $Isolation,

        [switch] $Force
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Folder '$Path' does not exist."
    }
    $Path = (Resolve-Path -LiteralPath $Path).ProviderPath
    $target = Join-Path $Path 'navgit.json'
    if ((Test-Path -LiteralPath $target) -and -not $Force) {
        throw "'$target' already exists. Use -Force to overwrite it."
    }
    if (-not $ProjectName) {
        $ProjectName = Split-Path -Path $Path -Leaf
    }

    $config = [ordered]@{ projectName = $ProjectName }
    switch ($PSCmdlet.ParameterSetName) {
        'Url' { $config.artifact = [ordered]@{ url = $ArtifactUrl } }
        'Version' { $config.artifact = [ordered]@{ version = $Version; country = $Country } }
        default {
            $config.artifact = [ordered]@{ nav = $Nav }
            if ($Cu) { $config.artifact.cu = $Cu }
            $config.artifact.country = $Country
        }
    }
    if ($UseDemo) {
        $config.database = [ordered]@{ useDemo = $true }
    }
    elseif ($BakFile) {
        $config.database = [ordered]@{ bakFile = $BakFile }
    }
    if ($LicenseFile) { $config.licenseFile = $LicenseFile }
    if ($Auth) { $config.auth = $Auth }
    if ($PSBoundParameters.ContainsKey('Isolation')) { $config.isolation = $Isolation }

    Write-NAVGitConfigFile -Config $config -Path $target -WhatIf:$WhatIfPreference
}

function Write-NAVGitConfigFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Config,

        [Parameter(Mandatory)]
        [string] $Path
    )

    $json = ConvertTo-NAVGitJson -InputObject $Config
    if (-not $PSCmdlet.ShouldProcess($Path, 'Write navgit.json')) {
        Write-Host $json
        return
    }

    # UTF-8 without BOM (VS Code default).
    [System.IO.File]::WriteAllText($Path, $json + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-NAVGitLog "Created $Path" -Level Success

    try {
        $null = Get-NAVGitConfig -Path (Split-Path -Path $Path -Parent)
    }
    catch {
        Write-NAVGitLog "The new configuration needs attention: $($_.Exception.Message)" -Level Warning
    }
    return $Path
}
