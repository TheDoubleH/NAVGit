function Get-NAVGitKnownConfigKeys {
    <#
    .SYNOPSIS
        Returns the navgit.json keys NAVGit understands: top-level key -> $null (scalar/array) or the allowed sub keys.
        Must stay in sync with Schema\navgit.schema.json (enforced by Module.Tests.ps1).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        'projectName'          = $null
        'containerName'        = $null
        'navRelease'           = $null
        'artifact'             = @('url', 'nav', 'cu', 'country', 'type', 'version', 'select')
        'imageName'            = $null
        'database'             = @('bakFile', 'useDemo', 'searchNames')
        'licenseFile'          = $null
        'auth'                 = $null
        'isolation'            = $null
        'memoryLimit'          = $null
        'dns'                  = $null
        'updateHosts'          = $null
        'enableSymbolLoading'  = $null
        'includeTestToolkit'   = $null
        'testToolkit'          = @('country', 'librariesOnly')
        'myScripts'            = $null
        'additionalParameters' = $null
        'paths'                = @('objects', 'tests', 'addIns')
        'testObjects'          = @('versionListPattern', 'includeTestCodeunits')
        'import'               = @('deleteMissing', 'syncSchema', 'compileFilter', 'dateFormat')
        'export'               = @('filter', 'format')
        'client'               = @('defaultProfile')
    }
}
