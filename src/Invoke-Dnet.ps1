#requires -Version 7.0
# Process entry point for the Bash/Zsh launcher; preserve the caller's arguments.
$ErrorActionPreference = 'Stop'
$global:LASTEXITCODE = 0
try {
    . (Join-Path $PSScriptRoot 'Dnet.ps1')
    Invoke-Dnet -Arguments @($args)
    exit $global:LASTEXITCODE
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    if (-not $global:LASTEXITCODE) { $global:LASTEXITCODE = 1 }
    exit $global:LASTEXITCODE
}
