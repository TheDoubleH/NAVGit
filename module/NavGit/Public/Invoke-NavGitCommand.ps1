function Invoke-NavGitCommand {
    <#
    .SYNOPSIS
        Runs a NavGit command by its registry name (Commands.psd1). Entry point for the VS Code extension.
    .DESCRIPTION
        Checks elevation and imports BcContainerHelper when the command needs them, runs the function, and reports
        errors. $LASTEXITCODE is set to 0 on success and 1 on failure, so callers can run
        powershell -Command "Import-Module NavGit; Invoke-NavGitCommand ...; exit $LASTEXITCODE".
    .PARAMETER Name
        Command name, e.g. BuildContainer, ImportObjects, ExportObjects, StartClient, GetProfiles.
    .PARAMETER Repository
        Repository folder (or any folder/file inside it). Default: current location.
    .PARAMETER Force
        Passed to commands that support it (e.g. replace an existing container without asking).
    .PARAMETER ProfileId
        Passed to commands that support it (Start NAV Client).
    .PARAMETER AsJson
        Write the command's result as JSON to the output and suppress progress messages (for background callers).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Name,

        [string] $Repository = (Get-Location).ProviderPath,

        [switch] $Force,

        [string] $ProfileId,

        [switch] $AsJson
    )

    $global:LASTEXITCODE = 0
    try {
        $definition = Get-NavGitCommandDefinition -Name $Name

        $command = Get-Command -Name $definition.Function -Module NavGit -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $command) {
            throw "The command '$($definition.Description)' ($($definition.Function)) is not available in this version of NavGit."
        }
        if ($definition.RequiresElevation) {
            Assert-NavGitAdministrator -Operation $definition.Description
        }
        if ($definition.RequiresContainerHelper) {
            Assert-NavGitBcContainerHelper -UserSettings (Get-NavGitUserSettings)
        }

        $params = @{ Path = $Repository }
        if ($Force -and $command.Parameters.ContainsKey('Force')) { $params.Force = $true }
        if ($ProfileId -and $command.Parameters.ContainsKey('ProfileId')) { $params.ProfileId = $ProfileId }

        if ($AsJson) {
            # Progress (Write-Host = information stream) and warnings would end up in stdout; drop them.
            $result = & $definition.Function @params 3>$null 6>$null
        }
        else {
            Write-NavGitLog "NavGit: $($definition.Description) ($Repository)" -Level Step
            $null = & $definition.Function @params
        }

        if ($AsJson) {
            # Always an array, so callers can parse it the same way for 0, 1 or n results.
            ConvertTo-Json -InputObject @($result) -Depth 5 -Compress
        }
    }
    catch {
        $global:LASTEXITCODE = 1
        if ($AsJson) {
            # Keep stdout parseable; the error text goes to stderr.
            [Console]::Error.WriteLine("NavGit: $($_.Exception.Message)")
        }
        else {
            Write-Host ''
            Write-Host "NavGit: $($_.Exception.Message)" -ForegroundColor Red
            Write-Verbose ($_.ScriptStackTrace)
        }
    }
}
