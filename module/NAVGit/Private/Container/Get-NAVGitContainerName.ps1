function Get-NAVGitContainerName {
    <#
    .SYNOPSIS
        Derives the default container name from the project name: '_' and other invalid characters become '-',
        truncated to 15 characters (NetBIOS host name limit), no leading/trailing '-'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $ProjectName
    )

    $name = $ProjectName -replace '[^A-Za-z0-9-]', '-'
    $name = $name.Trim('-')
    if ($name.Length -gt 15) {
        $name = $name.Substring(0, 15).TrimEnd('-')
    }
    return $name
}

function Get-NAVGitBranchName {
    <#
    .SYNOPSIS
        Returns the current Git branch of the repository at Path, or $null (no git, not a repository, detached HEAD).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
        return $null
    }
    $branch = & git -C $Path branch --show-current 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $branch) {
        return $null
    }
    return ([string]$branch).Trim()
}

function Resolve-NAVGitContainerName {
    <#
    .SYNOPSIS
        Resolves containerName from the user settings and navgit.json. Each may be a name, { "fixed": "<name>" } or
        { "branch": { "prefix": "<key>", "length": <n> } } (prefix optional). The user setting wins. A branch rule
        applies only on a ticket branch (starting with <prefix>-<number>, or any issue key such as MIS-1234 without a
        prefix) and yields its first <n> characters; otherwise the next value is used: the user setting, then
        navgit.json, then the name derived from projectName.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        $UserValue,

        $RepoValue,

        $ProjectName,

        [Parameter(Mandatory)]
        [string] $RepositoryPath,

        [string] $SettingsPath = 'settings.json',

        [string] $ConfigPath = 'navgit.json',

        # For tests; by default the branch is read with git when a branch rule needs it.
        [AllowEmptyString()]
        [string] $BranchName
    )

    $layers = @(@(
            @{ Value = $UserValue; Source = $SettingsPath }
            @{ Value = $RepoValue; Source = $ConfigPath }
        ) | Where-Object { $null -ne $_.Value -and -not ($_.Value -is [string] -and $_.Value -eq '') })

    $branchRead = $PSBoundParameters.ContainsKey('BranchName')
    foreach ($layer in $layers) {
        $value = $layer.Value
        $source = $layer.Source

        if ($value -is [string]) {
            return (Assert-NAVGitFixedContainerName -Name $value -Source $source -Setting 'containerName')
        }
        if ($value -isnot [hashtable]) {
            throw "${source}: 'containerName' must be a name, { `"fixed`": `"<name>`" } or { `"branch`": { `"prefix`": `"<key>`", `"length`": <number> } }."
        }
        $forms = @(@('fixed', 'branch') | Where-Object { $value.ContainsKey($_) })
        if ($forms.Count -ne 1) {
            throw "${source}: 'containerName' must contain exactly one of 'fixed' or 'branch' (found: $(if ($forms.Count) { $forms -join ', ' } else { 'none' }))."
        }
        if ($forms[0] -eq 'fixed') {
            if ($value.fixed -isnot [string]) {
                throw "${source}: 'containerName.fixed' must be a string."
            }
            return (Assert-NAVGitFixedContainerName -Name $value.fixed -Source $source -Setting 'containerName.fixed')
        }

        $rule = $value.branch
        $validLength = $rule -is [hashtable] -and ($rule.length -is [int] -or $rule.length -is [long]) -and
            $rule.length -ge 1 -and $rule.length -le 15
        if (-not $validLength) {
            throw "${source}: 'containerName.branch' must be { `"length`": <1-15> }, optionally with `"prefix`": `"<key>`"."
        }
        foreach ($key in $rule.Keys) {
            if ($key -notin @('prefix', 'length')) { Write-Warning "${source}: unknown setting 'containerName.branch.$key' is ignored." }
        }
        # Ticket branches start with an issue key: project key, '-', number (MIS-1234-short-text).
        $ticketPattern = '^[A-Z][A-Z0-9]*-\d'
        $caseSensitive = $true
        if ($null -ne $rule.prefix -and -not ($rule.prefix -is [string] -and $rule.prefix -eq '')) {
            # The '-' is added here, so "MIS" and "MIS-" mean the same and "MIS" does not match MISC-....
            $issueKey = if ($rule.prefix -is [string]) { $rule.prefix.TrimEnd('-') } else { $null }
            if ($issueKey -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
                throw "${source}: 'containerName.branch.prefix' ('$($rule.prefix)') must be an issue key such as 'MIS': letters and digits, starting with a letter."
            }
            $ticketPattern = "^$issueKey-\d"
            $caseSensitive = $false
        }

        if (-not $branchRead) {
            $BranchName = Get-NAVGitBranchName -Path $RepositoryPath
            $branchRead = $true
            if (-not $BranchName) {
                Write-NAVGitLog "Could not read the Git branch of '$RepositoryPath' (no git, or a detached HEAD); containerName.branch in '$source' is not used." -Level Warning
            }
        }
        $isTicket = if ($caseSensitive) { $BranchName -cmatch $ticketPattern } else { $BranchName -match $ticketPattern }
        if ($isTicket) {
            $start = $BranchName.Substring(0, [Math]::Min([int]$rule.length, $BranchName.Length))
            $name = Get-NAVGitContainerName -ProjectName $start
            if ($name) {
                Write-NAVGitLog "Container name '$name' from branch '$BranchName' ($source)." -Level Detail
                return $name
            }
        }
        elseif ($BranchName) {
            Write-NAVGitLog "Branch '$BranchName' is not a ticket branch; containerName.branch in '$source' is not used." -Level Detail
        }
    }

    if ($ProjectName -is [string] -and $ProjectName) {
        return (Get-NAVGitContainerName -ProjectName $ProjectName)
    }
    return $null
}

function Assert-NAVGitFixedContainerName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Name,

        [string] $Source,

        [string] $Setting
    )

    if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{0,14}$') {
        throw "${Source}: '$Setting' ('$Name') must be 1-15 characters (letters, digits, -) and start with a letter or digit."
    }
    return $Name
}
