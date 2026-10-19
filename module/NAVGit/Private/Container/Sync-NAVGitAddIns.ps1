function Sync-NAVGitAddIns {
    <#
    .SYNOPSIS
        Copies the repository's add-ins into the Add-ins folders of the service tier and the RoleTailored Client inside
        the container, and into the Windows client folder on the host that Start Client and Start FinSql use.
        The files go through a folder shared with the container, so this also works when c:\run\Add-ins is not mapped.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ContainerName,

        [Parameter(Mandatory)]
        [string] $AddInsFolder,

        [string] $ClientFolder
    )

    Write-NAVGitLog "Copying add-ins from $AddInsFolder" -Level Step
    $staging = Get-NAVGitStagingFolder -ContainerName $ContainerName
    try {
        Copy-Item -Path (Join-Path $AddInsFolder '*') -Destination $staging -Recurse -Force
        $containerStaging = Get-BcContainerPath -containerName $ContainerName -path $staging -throw

        Invoke-ScriptInBcContainer -containerName $ContainerName -argumentList $containerStaging -scriptblock {
            param($Source)
            $targets = @(
                (Get-Item 'C:\Program Files\Microsoft Dynamics NAV\*\Service\Add-ins' -ErrorAction SilentlyContinue)
                (Get-Item 'C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client\Add-ins' -ErrorAction SilentlyContinue)
            ) | Where-Object { $_ }
            foreach ($target in $targets) {
                Copy-Item -Path (Join-Path $Source '*') -Destination $target.FullName -Recurse -Force
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($ClientFolder) {
        $hostTarget = Join-Path $ClientFolder 'Add-ins'
        if (-not (Test-Path -LiteralPath $hostTarget -PathType Container)) {
            New-Item -ItemType Directory -Path $hostTarget -Force | Out-Null
        }
        Copy-Item -Path (Join-Path $AddInsFolder '*') -Destination $hostTarget -Recurse -Force
    }
}
