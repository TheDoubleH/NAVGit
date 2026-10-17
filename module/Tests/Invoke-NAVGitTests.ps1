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
    [string] $Path,
    [switch] $CI
)

# Not as a parameter default: Windows PowerShell 5.1 leaves $PSScriptRoot empty there when run with -File.
if (-not $Path) {
    $Path = $PSScriptRoot
}

$pester = Get-Module -Name Pester -ListAvailable |
    Where-Object { $_.Version -ge [version]'5.5.0' } |
    Sort-Object -Property Version -Descending |
    Select-Object -First 1
if (-not $pester) {
    # Per-user modules are separate for Windows PowerShell and PowerShell 7, so install in the edition you run.
    throw "Pester 5.5 or later is required in PowerShell $($PSVersionTable.PSVersion): Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck"
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
