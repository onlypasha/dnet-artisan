#requires -Version 5.1
function Get-DnetInstallDirectory {
    param([string]$Directory)
    if ($Directory) { return [IO.Path]::GetFullPath($Directory) }
    $userDirectory = [Environment]::GetFolderPath('UserProfile')
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $baseDirectory = [Environment]::GetFolderPath('LocalApplicationData')
    } elseif ($env:XDG_DATA_HOME) { $baseDirectory = $env:XDG_DATA_HOME }
    else { $baseDirectory = Join-Path $userDirectory '.local/share' }
    return Join-Path $baseDirectory 'dnet-artisan'
}

function Get-DnetProfilePaths {
    param([string[]]$Paths, [switch]$CurrentShellOnly)
    if ($Paths.Count) { return @($Paths | ForEach-Object { [IO.Path]::GetFullPath($_) } | Select-Object -Unique) }
    if (-not $CurrentShellOnly -and [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $documents = [Environment]::GetFolderPath('MyDocuments')
        return @((Join-Path $documents 'WindowsPowerShell/profile.ps1'), (Join-Path $documents 'PowerShell/profile.ps1'))
    }
    return @($PROFILE.CurrentUserAllHosts)
}

function Get-DnetLoaderPattern { return '(?ms)^# BEGIN DNET-ARTISAN\r?\n.*?^# END DNET-ARTISAN(?:\r?\n)?' }

function Assert-DnetPowerShellSyntax {
    param([string]$Text,[string]$Label)
    $tokens=$null; $parseErrors=$null
    [Management.Automation.Language.Parser]::ParseInput($Text,[ref]$tokens,[ref]$parseErrors) | Out-Null
    if ($parseErrors) { throw "PowerShell syntax error in ${Label}: $($parseErrors[0].Message)" }
}

function Write-DnetUtf8File {
    param([string]$Path,[string]$Text)
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    # A BOM preserves existing non-ASCII profile text in Windows PowerShell 5.1.
    [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($true)))
}
