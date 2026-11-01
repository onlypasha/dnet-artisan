#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('Install','Uninstall')][string]$Action='Install',[string]$Prefix)
$ErrorActionPreference='Stop'
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { throw 'Use install.ps1 or uninstall.ps1 on Windows.' }
. (Join-Path $PSScriptRoot 'Installation.Common.ps1')
if ($Prefix) {
    $prefixDirectory=[IO.Path]::GetFullPath($Prefix)
    $destination=Join-Path $prefixDirectory 'share/dnet-artisan/cli'
    $commandDirectory=Join-Path $prefixDirectory 'bin'
} else {
    $destination=Join-Path (Get-DnetInstallDirectory) 'cli'
    $commandDirectory=Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/bin'
}
$manifestPath=Join-Path $destination 'unix-installation.json'
$launcherPath=Join-Path $commandDirectory 'dnet'
$sourcePath=Join-Path $destination 'Dnet.ps1'
$entryPath=Join-Path $destination 'Invoke-Dnet.ps1'
$expectedPaths=@($sourcePath,$entryPath,$launcherPath)
$oldManifest=$null
if (Test-Path -LiteralPath $manifestPath) {
    $oldManifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($oldManifest.CommandDirectory -cne $commandDirectory -or @($oldManifest.Files).Count -ne 3) { throw 'Installation manifest does not match this prefix.' }
    foreach ($file in $oldManifest.Files) {
        if ($file.Path -cnotin $expectedPaths) { throw 'Unexpected file in installation manifest.' }
        if (Test-Path -LiteralPath $file.Path) {
            $item=Get-Item -LiteralPath $file.Path -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint -or $item.PSIsContainer) { throw "Refusing to modify linked or non-file output: $($file.Path)" }
            if ((Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -ne $file.Sha256) { throw "Installed file was modified: $($file.Path). Back it up or restore it before continuing." }
        }
    }
}
if ($Action -eq 'Uninstall') {
    if (-not $oldManifest) { Write-Host "No managed Unix installation found at $destination"; return }
    foreach ($file in $oldManifest.Files) { if (Test-Path -LiteralPath $file.Path) { [IO.File]::Delete($file.Path) } }
    [IO.File]::Delete($manifestPath)
    Write-Host 'Uninstalled the dnet shell command. Shell profiles and generated C# files were preserved.'
    return
}
if (-not (Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue)) { throw '.NET SDK is required. Install it before installing dnet-artisan.' }
foreach ($path in $expectedPaths) {
    if ((Test-Path -LiteralPath $path) -and -not $oldManifest) { throw "Unmanaged file already exists: $path" }
    $parent=[IO.Path]::GetDirectoryName($path)
    while ($parent) {
        if (Test-Path -LiteralPath $parent) {
            if ((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked installation directories are not supported: $parent" }
        }
        $parent=[IO.Path]::GetDirectoryName($parent)
    }
}
$repository=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceText=[IO.File]::ReadAllText((Join-Path $repository 'src/Dnet.ps1'))
$entryText=[IO.File]::ReadAllText((Join-Path $repository 'src/Invoke-Dnet.ps1'))
Assert-DnetPowerShellSyntax $sourceText 'Dnet.ps1'
Assert-DnetPowerShellSyntax $entryText 'Invoke-Dnet.ps1'
$quoteReplacement="'"+'"'+"'"+'"'+"'"
$quotedEntry="'"+$entryPath.Replace("'",$quoteReplacement)+"'"
$launcher="#!/bin/sh`nset -eu`nexec pwsh -NoLogo -NoProfile -File $quotedEntry " + '"$@"' + "`n"
$plans=@(@{Path=$sourcePath;Content=$sourceText},@{Path=$entryPath;Content=$entryText},@{Path=$launcherPath;Content=$launcher})
$snapshots=@{}
foreach ($path in @($expectedPaths)+@($manifestPath)) { if (Test-Path -LiteralPath $path) { $snapshots[$path]=[IO.File]::ReadAllBytes($path) } }
$touched=@()
try {
    foreach ($plan in $plans) {
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($plan.Path))
        $touched+=$plan.Path
        [IO.File]::WriteAllText($plan.Path,$plan.Content,(New-Object Text.UTF8Encoding($false)))
    }
    & chmod 755 -- $launcherPath
    if ($LASTEXITCODE -ne 0) { throw 'Could not make the dnet launcher executable.' }
    $manifest=[ordered]@{
        Version=([IO.File]::ReadAllText((Join-Path $repository 'VERSION'))).Trim()
        CommandDirectory=$commandDirectory
        Files=@($expectedPaths | ForEach-Object { @{Path=$_;Sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash} })
    }
    $touched+=$manifestPath
    [IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
} catch {
    foreach ($path in $touched) {
        if ($snapshots.ContainsKey($path)) { [IO.File]::WriteAllBytes($path,$snapshots[$path]) }
        elseif (Test-Path -LiteralPath $path -PathType Leaf) { [IO.File]::Delete($path) }
    }
    throw
}
Write-Host "Installed dnet-artisan $($manifest.Version) for Bash/Zsh: $launcherPath"
if ($commandDirectory -cnotin ($env:PATH -split [IO.Path]::PathSeparator)) {
    $quotedBin="'"+$commandDirectory.Replace("'",$quoteReplacement)+"'"
    Write-Host ('Add it to your current shell: export PATH='+$quotedBin+':"$PATH"')
}
Write-Host 'Run dnet --version or dnet list from your shell.'
