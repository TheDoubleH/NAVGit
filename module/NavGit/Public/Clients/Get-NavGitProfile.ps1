function Get-NavGitProfile {
    <#
    .SYNOPSIS
        Lists the profiles (role centers) in the container database: Id, Description, RoleCenterId, IsDefault.
        Queries SQL from this machine; needs no elevation.
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    #>
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).ProviderPath
    )

    $context = Get-NavGitClientContext -Path $Path
    $state = $context.State

    $credential = $null
    if ($state.auth -ne 'Windows') {
        try {
            $credential = Get-NavGitCredential -ContainerName $state.containerName -Auth $state.auth -NoPrompt
        }
        catch {
            throw "No stored credential for '$($state.containerName)'; it is saved the first time you build the container with NavGit."
        }
    }

    $query = @'
SELECT [Profile ID] AS Id, [Description], [Role Center ID] AS RoleCenterId, [Default Role Center] AS IsDefault
FROM [dbo].[Profile]
ORDER BY [Profile ID]
'@
    $rows = Invoke-NavGitSql -State $state -Query $query -Credential $credential
    return @(foreach ($row in $rows) {
            [pscustomobject]@{
                Id           = [string]$row.Id
                Description  = [string]$row.Description
                RoleCenterId = [int]$row.RoleCenterId
                IsDefault    = ([int]$row.IsDefault -eq 1)
            }
        })
}
