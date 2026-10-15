function Assert-NavGitAdditionalParameters {
    <#
    .SYNOPSIS
        Rejects additionalParameters that duplicate a native New-BcContainer parameter. Passing them as raw docker
        arguments hides them from BcContainerHelper (e.g. '--env bakfile=' means the image is built with Cronus).
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [string[]] $AdditionalParameters = @()
    )

    $envReplacements = [ordered]@{
        'bakfile'                = "'database.bakFile'"
        'licensefile'            = "'licenseFile'"
        'username'               = 'the stored credential (Get-NavGitCredential)'
        'password'               = 'the stored credential (Get-NavGitCredential)'
        'securepassword'         = 'the stored credential (Get-NavGitCredential)'
        'passwordkeyfile'        = 'the stored credential (Get-NavGitCredential)'
        'auth'                   = "'auth'"
        'databaseserver'         = 'nothing: external databases are not supported, use database.bakFile'
        'databaseinstance'       = 'nothing: external databases are not supported, use database.bakFile'
        'databasename'           = 'nothing: external databases are not supported, use database.bakFile'
        'databaseusername'       = 'nothing: external databases are not supported, use database.bakFile'
        'databasepassword'       = 'nothing: external databases are not supported, use database.bakFile'
        'databasesecurepassword' = 'nothing: external databases are not supported, use database.bakFile'
        'artifacturl'            = "'artifact'"
        'enablesymbolloading'    = "'enableSymbolLoading'"
    }
    $optionReplacements = [ordered]@{
        '--name'      = "'containerName'"
        '--memory'    = "'memoryLimit'"
        '-m'          = "'memoryLimit'"
        '--isolation' = "'isolation'"
        '--dns'       = "'dns'"
        '--restart'   = 'nothing: NavGit sets the restart policy'
    }

    $problems = New-Object System.Collections.Generic.List[string]
    foreach ($parameter in $AdditionalParameters) {
        foreach ($match in [regex]::Matches($parameter, '(?:^|\s)(?:--env|-e)[\s=]+"?(?<name>[A-Za-z0-9_]+)=')) {
            $name = $match.Groups['name'].Value.ToLowerInvariant()
            if ($envReplacements.Contains($name)) {
                $problems.Add("'$parameter': use $($envReplacements[$name]) instead of --env $($match.Groups['name'].Value).")
            }
        }
        foreach ($option in $optionReplacements.Keys) {
            if ($parameter -match "(?:^|\s)$([regex]::Escape($option))(?:[\s=]|$)") {
                $problems.Add("'$parameter': use $($optionReplacements[$option]) instead of $option.")
            }
        }
    }

    if ($problems.Count -gt 0) {
        $list = ($problems | ForEach-Object { "  - $_" }) -join [Environment]::NewLine
        throw "additionalParameters contains settings that must use their own navgit.json entry:$([Environment]::NewLine)$list"
    }
}
