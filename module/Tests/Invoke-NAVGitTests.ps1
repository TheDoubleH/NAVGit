<#
.SYNOPSIS
    Runs the NAVGit Pester tests. Requires Pester 5.5 or later.
.EXAMPLE
    .\module\Tests\Invoke-NAVGitTests.ps1
.EXAMPLE
    .\module\Tests\Invoke-NAVGitTests.ps1 -CI    # exit code = number of failed tests, writes TestResults.xml
#>
[CmdletBinding()]
param(
    [string] $Path = $PSScriptRoot,
    [switch] $CI
)

$pester = Get-Module -Name Pester -ListAvailable |
    Where-Object { $_.Version -ge [version]'5.5.0' } |
    Sort-Object -Property Version -Descending |
    Select-Object -First 1
if (-not $pester) {
    throw 'Pester 5.5 or later is required: Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck'
}
Import-Module $pester -Force

$configuration = New-PesterConfiguration
$configuration.Run.Path = $Path
$configuration.Output.Verbosity = 'Detailed'
if ($CI) {
    $configuration.Run.Exit = $true
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputPath = Join-Path $PSScriptRoot 'TestResults.xml'
}

Invoke-Pester -Configuration $configuration
