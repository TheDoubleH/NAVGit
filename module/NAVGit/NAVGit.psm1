# Version 1 catches uninitialised variables. Version 2 would also throw on reading a missing hashtable key
# ($config.optionalKey), which the configuration code relies on.
Set-StrictMode -Version 1.0

$privateFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)
$publicFiles = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)

foreach ($file in ($privateFiles + $publicFiles)) {
    try {
        . $file.FullName
    }
    catch {
        throw "NAVGit: failed to load '$($file.FullName)': $($_.Exception.Message)"
    }
}

$script:NAVGitModuleRoot = $PSScriptRoot

Export-ModuleMember -Function @($publicFiles | ForEach-Object { $_.BaseName })
