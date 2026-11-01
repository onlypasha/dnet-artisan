#requires -Version 5.1
[CmdletBinding()]
param([string]$InstallDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'scripts/Installation.Common.ps1')
$destination=Get-DnetInstallDirectory $InstallDirectory
$manifestPath=Join-Path $destination 'installation.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { Write-Host "No managed installation found at $destination"; return }
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$expectedFile=[IO.Path]::GetFullPath((Join-Path $destination 'Dnet.ps1'))
if ($manifest.InstalledFile -ne $expectedFile) { throw 'Installation manifest does not match the selected install directory.' }
$plans=@()
foreach ($profile in $manifest.Profiles) {
    if (-not (Test-Path -LiteralPath $profile.Path)) { continue }
    $before=[IO.File]::ReadAllText($profile.Path)
    $pattern=Get-DnetLoaderPattern
    $blocks=[regex]::Matches($before,$pattern)
    foreach ($block in $blocks) {
        $expectedLoader=". '$($expectedFile.Replace("'","''"))'"
        if (-not $block.Value.Contains($expectedLoader)) { throw "Profile loader was modified: $($profile.Path). Review it manually." }
    }
    $after=[regex]::Replace($before,$pattern,'')
    Assert-DnetPowerShellSyntax $after $profile.Path
    $plans += [pscustomobject]@{Path=$profile.Path;Before=$before;After=$after;Remove=([bool]$profile.CreatedProfile -and $after.Length -eq 0)}
}
$sourceModified=(Test-Path -LiteralPath $expectedFile) -and (Get-FileHash -LiteralPath $expectedFile -Algorithm SHA256).Hash -ne $manifest.SourceSha256
if ($sourceModified) { throw 'Installed Dnet.ps1 was modified. Back it up or restore it before uninstalling.' }
$backupDirectory=Join-Path $destination ('backups/uninstall-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($backupDirectory)
$backupIndex=0
foreach ($plan in $plans) {
    Write-DnetUtf8File (Join-Path $backupDirectory ("profile-$backupIndex.ps1")) $plan.Before
    if ($plan.Remove) { [IO.File]::Delete($plan.Path) }
    else { Write-DnetUtf8File $plan.Path $plan.After }
    $backupIndex++
}
if (Test-Path -LiteralPath $expectedFile) { [IO.File]::Delete($expectedFile) }
[IO.File]::Delete($manifestPath)
Write-Host 'Uninstalled dnet-artisan. Existing terminal sessions retain loaded functions until closed.'
Write-Host "Profile backups were kept at $backupDirectory"
