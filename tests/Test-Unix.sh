#!/bin/sh
set -eu
repository=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/dnet-artisan-shell.XXXXXXXX")
cleanup() {
    case "$fixture" in "${TMPDIR:-/tmp}"/dnet-artisan-shell.*) rm -rf -- "$fixture" ;; *) printf '%s\n' 'Unsafe cleanup path.' >&2 ;; esac
}
trap cleanup EXIT HUP INT TERM
prefix="$fixture/install with ' quote"
export DOTNET_CLI_HOME="$fixture/dotnet-home"
export DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=false
export DOTNET_GENERATE_ASPNET_CERTIFICATE=false
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export NUGET_PACKAGES="$fixture/nuget/packages"
export NUGET_HTTP_CACHE_PATH="$fixture/nuget/cache"
export NUGET_SCRATCH="$fixture/nuget/scratch"
sh "$repository/install.sh" --help >/dev/null
sh "$repository/install.sh" --prefix "$prefix"
export PATH="$prefix/bin:$PATH"
test -x "$prefix/bin/dnet"
expected_version=$(cat "$repository/VERSION")
test "$(dnet --version)" = "dnet-artisan $expected_version"
dnet list | grep 'make:controller' >/dev/null
project="$fixture/project with spaces"
mkdir -p "$project"
cat > "$project/ShellSmoke.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework><RootNamespace>ShellSmoke</RootNamespace></PropertyGroup>
</Project>
EOF
cat > "$project/Program.cs" <<'EOF'
System.Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(args));
return 23;
EOF
cd "$project"
dnet make:class Admin/Report
grep 'namespace ShellSmoke.Admin' Admin/Report.cs >/dev/null
before=$(sha256sum Admin/Report.cs)
if dnet make:class Admin/Report > "$fixture/collision.log" 2>&1; then printf '%s\n' 'Existing file was overwritten.' >&2; exit 1; fi
test "$(sha256sum Admin/Report.cs)" = "$before"
if dnet invalid:command > "$fixture/error.log" 2>&1; then exit 1; else code=$?; test "$code" -eq 1; fi
dnet build --ignore-failed-sources -p:NuGetAudit=false
if dnet run --no-build -- --project 'value with spaces' 'literal;not-a-command' > "$fixture/arguments.log" 2> "$fixture/run-error.log"; then
    printf '%s\n' 'Native exit code was lost.' >&2; exit 1
else
    code=$?
    test "$code" -eq 23
fi
grep -F '["--project","value with spaces","literal;not-a-command"]' "$fixture/arguments.log" >/dev/null
sh "$repository/install.sh" --prefix "$prefix"
printf '%s\n' 'keep this user file' > "$prefix/share/dnet-artisan/cli/keep.txt"
cp "$prefix/bin/dnet" "$fixture/launcher.original"
printf '\n# user edit\n' >> "$prefix/bin/dnet"
if sh "$repository/uninstall.sh" --prefix "$prefix" > "$fixture/modified.log" 2>&1; then printf '%s\n' 'Modified launcher was removed.' >&2; exit 1; fi
test -f "$prefix/share/dnet-artisan/cli/Dnet.ps1"
cp "$fixture/launcher.original" "$prefix/bin/dnet"
sh "$repository/uninstall.sh" --prefix "$prefix"
test ! -e "$prefix/bin/dnet"
test ! -e "$prefix/share/dnet-artisan/cli/Dnet.ps1"
test -f "$prefix/share/dnet-artisan/cli/keep.txt"
sh "$repository/uninstall.sh" --prefix "$prefix"

# Exercise default XDG and user-bin locations without touching the runner's profile.
mkdir -p "$fixture/isolated-home"
HOME="$fixture/isolated-home" XDG_DATA_HOME="$fixture/xdg-data" sh "$repository/install.sh"
test -x "$fixture/isolated-home/.local/bin/dnet"
test -f "$fixture/xdg-data/dnet-artisan/cli/Invoke-Dnet.ps1"
HOME="$fixture/isolated-home" XDG_DATA_HOME="$fixture/xdg-data" sh "$repository/uninstall.sh"
test ! -e "$fixture/isolated-home/.local/bin/dnet"
printf '%s\n' 'PASS: Linux shell install, quoted paths, generators, compilation, exact arguments/native exit codes, reinstall, modified files, XDG paths, and uninstall.'
