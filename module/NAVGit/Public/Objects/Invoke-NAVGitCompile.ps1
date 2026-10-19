function Invoke-NAVGitCompile {
    <#
    .SYNOPSIS
        Compiles objects in the repository's container: uncompiled objects, modified objects, or all objects.
    .DESCRIPTION
        Runs inside the container with BcContainerHelper's Compile-ObjectsInNavContainer, so it also works for
        NavUserPassword containers. Schema changes are synchronized with import.syncSchema (default Force).
        Afterwards the objects that are still uncompiled are listed.
          Uncompiled  Compiled=No
          Modified    Modified=Yes
          All         every object (can take a long time)
    .PARAMETER Path
        Repository folder (or any folder/file inside it). Default: current location.
    .PARAMETER Scope
        Uncompiled (default), Modified or All.
    .PARAMETER Filter
        A C/SIDE filter instead of a scope, e.g. 'Type=Codeunit;Id=50000..50099'.
    .EXAMPLE
        Invoke-NAVGitCompile -Scope Modified
    #>
    [CmdletBinding(DefaultParameterSetName = 'Scope')]
    param(
        [string] $Path = (Get-Location).ProviderPath,

        [Parameter(ParameterSetName = 'Scope')]
        [ValidateSet('Uncompiled', 'Modified', 'All')]
        [string] $Scope = 'Uncompiled',

        [Parameter(Mandatory, ParameterSetName = 'Filter')]
        [string] $Filter
    )

    if ($PSCmdlet.ParameterSetName -eq 'Scope') {
        $Filter = Get-NAVGitCompileFilter -Scope $Scope
    }

    $context = Initialize-NAVGitContainerCommand -Path $Path -Operation 'Compiling objects'
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $uncompiled = @(Invoke-NAVGitContainerCompile -Context $context -Filter $Filter)

    Write-NAVGitLog ("Compile finished ({0:mm\:ss})" -f $stopwatch.Elapsed) -Level Success
    return [pscustomobject]@{
        Filter     = $Filter
        Uncompiled = $uncompiled.Count
    }
}

function Get-NAVGitCompileFilter {
    <#
    .SYNOPSIS
        C/SIDE filter for a compile scope. '' means all objects.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Uncompiled', 'Modified', 'All')]
        [string] $Scope
    )

    switch ($Scope) {
        'Uncompiled' { return 'Compiled=No' }
        'Modified' { return 'Modified=Yes' }
        default { return '' }
    }
}
