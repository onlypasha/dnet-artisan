#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$InstallDirectory,
    [string[]]$ProfilePath,
    [switch]$CurrentShellOnly,
    [switch]$NoProfile
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'scripts/Installation.Common.ps1')
$destination = Get-DnetInstallDirectory $InstallDirectory
$installedFile = Join-Path $destination 'Dnet.ps1'
$manifestPath = Join-Path $destination 'installation.json'
$sourceFile = Join-Path $PSScriptRoot 'src/Dnet.ps1'
$sourceText = [IO.File]::ReadAllText($sourceFile)
Assert-DnetPowerShellSyntax $sourceText 'Dnet.ps1'
$version = ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'VERSION'))).Trim()
$oldManifest = $null
if (Test-Path -LiteralPath $manifestPath) { $oldManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json }
if ((Test-Path -LiteralPath $installedFile) -and -not $oldManifest) {
    throw "Destination contains an unmanaged Dnet.ps1: $installedFile. Choose another -InstallDirectory."
}
$profiles=@()
if (-not $NoProfile) { $profiles = @(Get-DnetProfilePaths $ProfilePath -CurrentShellOnly:$CurrentShellOnly) }
$escapedSource = $installedFile.Replace("'","''")
$loader = "# BEGIN DNET-ARTISAN`n. '$escapedSource'`n# END DNET-ARTISAN`n"
$profilePlans=@()
foreach ($path in $profiles) {
    $before=''
    $existed=Test-Path -LiteralPath $path
    if ($existed) { $before=[IO.File]::ReadAllText($path) }
    $beginCount=([regex]::Matches($before,'(?m)^# BEGIN DNET-ARTISAN\r?$')).Count
    $endCount=([regex]::Matches($before,'(?m)^# END DNET-ARTISAN\r?$')).Count
    if ($beginCount -ne $endCount -or $beginCount -gt 1) { throw "Malformed dnet-artisan loader in $path" }
    if ($beginCount) {
        $after=[regex]::Replace($before,(Get-DnetLoaderPattern),[Text.RegularExpressions.MatchEvaluator]{param($m) $loader})
    } else {
        if ($before -match '(?im)^\s*(function\s+(global:)?dnet\b|Set-Alias\s+(-Name\s+)?dnet\b)') {
            throw "Profile already defines dnet: $path. Remove or rename that command first."
        }
        $separator=''
        if ($before -and -not $before.EndsWith("`n")) { $separator="`n" }
        $after=$before+$separator+$loader
    }
    Assert-DnetPowerShellSyntax $after $path
    $createdProfile=-not $existed
    if ($oldManifest) {
        $oldProfile=@($oldManifest.Profiles | Where-Object { $_.Path -eq $path })
        if ($oldProfile.Count) { $createdProfile=[bool]$oldProfile[0].CreatedProfile }
    }
    $beforeBytes=$null
    if ($existed) { $beforeBytes=[IO.File]::ReadAllBytes($path) }
    $profilePlans += [pscustomobject]@{Path=$path;Before=$before;BeforeBytes=$beforeBytes;After=$after;Existed=$existed;CreatedProfile=$createdProfile}
}
$backupDirectory=Join-Path $destination ('backups/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmss')+'-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($backupDirectory)
if (Test-Path -LiteralPath $installedFile) { Copy-Item -LiteralPath $installedFile -Destination (Join-Path $backupDirectory 'Dnet.ps1') }
$backupIndex=0
foreach ($plan in $profilePlans) {
    if ($plan.Existed) { Write-DnetUtf8File (Join-Path $backupDirectory ("profile-$backupIndex.ps1")) $plan.Before }
    $backupIndex++
}
$manifestProfiles=@($profilePlans | Select-Object Path,CreatedProfile)
if ($oldManifest) {
    foreach ($previousProfile in $oldManifest.Profiles) {
        if ($previousProfile.Path -notin $manifestProfiles.Path) { $manifestProfiles += $previousProfile }
    }
}
$oldSourceBytes=$null; $oldManifestBytes=$null
if (Test-Path -LiteralPath $installedFile) { $oldSourceBytes=[IO.File]::ReadAllBytes($installedFile) }
if (Test-Path -LiteralPath $manifestPath) { $oldManifestBytes=[IO.File]::ReadAllBytes($manifestPath) }
$touchedProfiles=@()
try {
    Write-DnetUtf8File $installedFile $sourceText
    foreach ($plan in $profilePlans) { $touchedProfiles += $plan; Write-DnetUtf8File $plan.Path $plan.After }
    $manifest=[ordered]@{
        Version=$version
        InstalledFile=$installedFile
        SourceSha256=(Get-FileHash -LiteralPath $installedFile -Algorithm SHA256).Hash
        Profiles=$manifestProfiles
        LastBackupDirectory=$backupDirectory
    }
    Write-DnetUtf8File $manifestPath ($manifest | ConvertTo-Json -Depth 10)
} catch {
    $installError=$_
    foreach ($plan in $touchedProfiles) {
        if ($plan.Existed) { [IO.File]::WriteAllBytes($plan.Path,$plan.BeforeBytes) }
        elseif (Test-Path -LiteralPath $plan.Path -PathType Leaf) { [IO.File]::Delete($plan.Path) }
    }
    if ($null -ne $oldSourceBytes) { [IO.File]::WriteAllBytes($installedFile,$oldSourceBytes) }
    elseif (Test-Path -LiteralPath $installedFile -PathType Leaf) { [IO.File]::Delete($installedFile) }
    if ($null -ne $oldManifestBytes) { [IO.File]::WriteAllBytes($manifestPath,$oldManifestBytes) }
    elseif (Test-Path -LiteralPath $manifestPath -PathType Leaf) { [IO.File]::Delete($manifestPath) }
    throw $installError
}
Write-Host "Installed dnet-artisan $version to $destination"
if ($profiles.Count) { Write-Host 'Open a new PowerShell terminal, then run: dnet list' }
else { Write-Host "To load it now: . '$escapedSource'" }
