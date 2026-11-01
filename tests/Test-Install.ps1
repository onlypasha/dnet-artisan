param([switch]$KeepArtifacts)
$ErrorActionPreference='Stop'
$repository=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('dnet-artisan-install-tests-'+[guid]::NewGuid().ToString('N'))
$destination=Join-Path $fixture "install with ' quote"
$existingProfile=Join-Path $fixture 'profiles/existing.ps1'
$newProfile=Join-Path $fixture 'profiles/new.ps1'
$unicode=[char]0x00e9
$original="# Existing caf${unicode} profile`nfunction ExistingFunction { 'preserved' }`n"
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($existingProfile))
[IO.File]::WriteAllText($existingProfile,$original,(New-Object Text.UTF8Encoding($true)))
function Assert($Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
try {
    & (Join-Path $repository 'install.ps1') -InstallDirectory $destination -ProfilePath @($existingProfile,$newProfile)
    Assert (Test-Path -LiteralPath (Join-Path $destination 'Dnet.ps1')) 'Source was not installed.'
    Assert ([IO.File]::ReadAllText($existingProfile).StartsWith($original)) 'Existing profile text changed.'
    . $existingProfile
    $expectedVersion=([IO.File]::ReadAllText((Join-Path $repository 'VERSION'))).Trim()
    Assert ((dnet version) -eq "dnet-artisan $expectedVersion") 'Profile loader did not load the helper.'
    Assert ((ExistingFunction) -eq 'preserved') 'Existing function was lost.'
    & (Join-Path $repository 'install.ps1') -InstallDirectory $destination -ProfilePath @($existingProfile,$newProfile)
    Assert (([regex]::Matches([IO.File]::ReadAllText($existingProfile),'# BEGIN DNET-ARTISAN')).Count -eq 1) 'Reinstall duplicated its loader.'
    $userAddition="`n# User change after installation`n"
    [IO.File]::AppendAllText($existingProfile,$userAddition)
    & (Join-Path $repository 'uninstall.ps1') -InstallDirectory $destination
    Assert ([IO.File]::ReadAllText($existingProfile) -ceq ($original+$userAddition)) 'Uninstall changed user profile content.'
    Assert (-not (Test-Path -LiteralPath $newProfile)) 'A new empty managed profile was not removed.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $destination 'Dnet.ps1'))) 'Installed helper was not removed.'
    Assert ((@(Get-ChildItem -LiteralPath (Join-Path $destination 'backups') -Directory)).Count -ge 1) 'Profile backups were not retained.'
    & (Join-Path $repository 'uninstall.ps1') -InstallDirectory $destination

    $sourceOnly=Join-Path $fixture 'source-only'
    & (Join-Path $repository 'install.ps1') -InstallDirectory $sourceOnly -NoProfile
    $installedSource=Join-Path $sourceOnly 'Dnet.ps1'
    [IO.File]::AppendAllText($installedSource,"`n# Local source edit`n")
    $caught=$false
    try { & (Join-Path $repository 'uninstall.ps1') -InstallDirectory $sourceOnly } catch { $caught=$_.Exception.Message -match 'modified' }
    Assert $caught 'Uninstall removed modified source.'
    Assert (Test-Path -LiteralPath $installedSource) 'Modified source was removed.'

    $conflictInstall=Join-Path $fixture 'conflict'
    $conflictProfile=Join-Path $fixture 'profiles/conflict.ps1'
    [IO.File]::WriteAllText($conflictProfile,'function dnet { "other tool" }')
    $caught=$false
    try { & (Join-Path $repository 'install.ps1') -InstallDirectory $conflictInstall -ProfilePath $conflictProfile } catch { $caught=$_.Exception.Message -match 'already defines' }
    Assert $caught 'An existing dnet function was overwritten.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $conflictInstall 'Dnet.ps1'))) 'Conflict installed files before preflight finished.'

    $rollbackInstall=Join-Path $fixture 'rollback'
    $rollbackProfile=Join-Path $fixture 'profiles/rollback.ps1'
    [IO.File]::WriteAllText($rollbackProfile,$original,(New-Object Text.UTF8Encoding($true)))
    $blockedParent=Join-Path $fixture 'not-a-directory'
    [IO.File]::WriteAllText($blockedParent,'block directory creation')
    $caught=$false
    try { & (Join-Path $repository 'install.ps1') -InstallDirectory $rollbackInstall -ProfilePath @($rollbackProfile,(Join-Path $blockedParent 'profile.ps1')) } catch { $caught=$true }
    Assert $caught 'Expected a failing profile write.'
    Assert ([IO.File]::ReadAllText($rollbackProfile) -ceq $original) 'Failed installation did not roll back the first profile.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $rollbackInstall 'Dnet.ps1'))) 'Failed installation left a partial helper.'
    Write-Output 'PASS: install/uninstall, quoted paths, Unicode/user edits, idempotence, backups, conflicts, and failed-install rollback.'
} finally {
    if ($KeepArtifacts) { Write-Host "Artifacts retained: $fixture" }
    elseif (Test-Path -LiteralPath $fixture) {
        $absoluteFixture=[IO.Path]::GetFullPath($fixture)
        $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
        if (-not $absoluteFixture.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($absoluteFixture) -notmatch '^dnet-artisan-install-tests-[a-f0-9]{32}$') { throw 'Unsafe test cleanup path.' }
        Remove-Item -LiteralPath $absoluteFixture -Recurse -Force
    }
}
