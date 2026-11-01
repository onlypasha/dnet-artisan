#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
case "${1-}" in
    --help|-h)
        printf '%s\n' 'Usage: sh install.sh [--prefix DIRECTORY]' 'Requires PowerShell 7 (pwsh) and a .NET SDK. Does not use sudo or modify shell profiles.'
        exit 0 ;;
    --prefix)
        if [ "$#" -ne 2 ] || [ -z "$2" ]; then printf '%s\n' '--prefix requires one directory.' >&2; exit 2; fi ;;
    '') ;;
    *) printf '%s\n' 'Usage: sh install.sh [--prefix DIRECTORY]' >&2; exit 2 ;;
esac
if ! command -v pwsh >/dev/null 2>&1; then
    printf '%s\n' 'PowerShell 7 (pwsh) is required. Install it first:' 'https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux' >&2
    exit 127
fi
if [ "$#" -eq 2 ]; then
    exec pwsh -NoLogo -NoProfile -File "$script_dir/scripts/Install-Unix.ps1" -Action Install -Prefix "$2"
fi
exec pwsh -NoLogo -NoProfile -File "$script_dir/scripts/Install-Unix.ps1" -Action Install
