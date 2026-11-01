# dnet-artisan

**Artisan-style commands for .NET, in PowerShell or your Linux terminal.**

Create controllers, classes, DTOs, and service/interface pairs without leaving
your editor. Run, build, test, and manage EF Core migrations using short commands.
Works with Zed, VS Code, and Linux Bash/Zsh terminals.

```powershell
dnet make:controller Product --resource
dnet make:class Helpers/DateHelper
dnet make:service Payment --interface
dnet serve
```

[Bahasa Indonesia](docs/README.id.md) | [Command reference](docs/commands.md) |
[Contributing](CONTRIBUTING.md)

## Status and requirements

Version **0.2.0** uses a PowerShell engine, not a .NET global tool or an editor
extension. Windows PowerShell 5.1 and PowerShell 7 are supported. PowerShell 7
is required on Linux and macOS. Install a .NET SDK appropriate to your project.
The generated code targets current SDK-style C# projects; the compilation smoke
test uses .NET 10. EF commands also require `dotnet-ef` and the
`Microsoft.EntityFrameworkCore.Design` package in the target project.

## Install from this checkout

### Linux (Bash/Zsh)

Install [PowerShell 7 (`pwsh`)](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)
and a .NET SDK first. Then, from your clone:

```sh
sh install.sh
export PATH="$HOME/.local/bin:$PATH"
dnet --version
dnet list
```

The `dnet` command works directly in Bash/Zsh. Its engine still requires `pwsh`
on PATH; you do not have to switch to a PowerShell shell. The installer creates
`~/.local/bin/dnet` and stores the engine in
`${XDG_DATA_HOME:-$HOME/.local/share}/dnet-artisan/cli`. Add `~/.local/bin` to your
shell's startup PATH if it is not already included. No shell profile is edited.

```sh
# Optional custom prefix; use the same prefix for uninstall.
sh install.sh --prefix "$HOME/tools"
export PATH="$HOME/tools/bin:$PATH"
```

### Windows / PowerShell sessions

Clone or download this repository, open PowerShell in its directory, then run:

```powershell
./install.ps1
```

Open a **new PowerShell terminal**, navigate to a .NET project, and run:

```powershell
dnet --version
dnet list
```

On Windows, the installer adds a small loader to the user-wide profiles for
Windows PowerShell and PowerShell 7. On other platforms it updates the current
PowerShell profile. Existing profile content is preserved and backed up.
No administrator access is required. The installer does not change execution
policy, install SDKs, add packages, or connect to a database.

The default helper location is `%LOCALAPPDATA%/dnet-artisan` on Windows,
`$XDG_DATA_HOME/dnet-artisan` when set on other platforms, or
`~/.local/share/dnet-artisan` otherwise.

```powershell
# Update only the profile for the current PowerShell edition.
./install.ps1 -CurrentShellOnly

# Install without changing any profile; load the helper yourself when needed.
./install.ps1 -InstallDirectory ./my-install -NoProfile
. ./my-install/Dnet.ps1
```

For a one-session trial without installation:

```powershell
. ./src/Dnet.ps1
dnet list
```

The PowerShell installer exposes a function in PowerShell sessions. Use
`install.sh` for a Bash/Zsh command on Linux. `cmd.exe` and `dotnet tool`
installation are not provided.

## Common commands

| Command | Result |
|---|---|
| `dnet make:controller Product` | `Controllers/ProductController.cs` |
| `dnet make:controller Admin/Report --resource` | Nested controller with five CRUD stubs |
| `dnet make:class Helpers/Clock` | `Helpers/Clock.cs` |
| `dnet make:model Product` | Model/entity class |
| `dnet make:dto CreateProduct` | `DTOs/CreateProductDto.cs` |
| `dnet make:service Payment --interface` | Service and matching interface |
| `dnet make:interface IClock` | Interface |
| `dnet make:enum OrderStatus` | Enum |
| `dnet serve` | `dotnet watch run` with hot reload |
| `dnet build` | Build the nearest solution, otherwise the project |
| `dnet test` | Run the uniquely discoverable `*.Tests.csproj` |
| `dnet package:add Package.Name` | Add a NuGet package |
| `dnet make:migration AddProducts` | Create an EF Core migration |
| `dnet migrate` | Apply EF Core migrations to the configured database |

Tab completes command names: type `dnet make:con` and press Tab.

## Project selection and conventions

Run commands from the project directory, a source subfolder, or the surrounding
solution folder. A solution folder with one web project selects that project.
Ambiguous choices require an explicit project:

```powershell
dnet make:controller Product --project ./src/Shop.Api/Shop.Api.csproj
dnet make:class Clock --namespace Company.Shop.Utilities
dnet run -- --help
```

`--project` accepts a `.csproj` file or project directory. Explicit project
selection also restricts build/format/restore/clean to that project. Native CLI
options are forwarded; arguments after `--` are kept for your application.

Namespaces follow `RootNamespace` in the project file, falling back to the
project name. Folder segments are appended to the namespace. The generator
reuses existing `Entity`/`Entities`/`Models`, `Service`/`Services`, and
`Interface`/`Interfaces` folders, with the plural names as defaults.

Generators never overwrite existing files. A service/interface pair is checked
before either file is written. Names must be ASCII C# identifiers; absolute
paths, file extensions, traversal segments, and linked output directories are
rejected.

## What scaffolding includes

`--resource` creates `Index`, `Show`, `Store`, `Update`, and `Destroy` action
stubs. These return HTTP 501 until implemented. Generated controllers do not
add authorization attributes. Models are not automatically registered as
`DbSet` properties, and services are not registered in dependency injection.

Database commands use the target application's EF Core configuration.
`dnet migrate` changes that database; `dnet migrate:rollback NAME` migrates to
the explicitly supplied target. The helper does not run database commands
during installation or tests, and does not install EF tools automatically.

## Uninstall

Linux shell installation:

```sh
sh uninstall.sh
# If you chose a custom prefix:
sh uninstall.sh --prefix "$HOME/tools"
```

This removes only managed engine files and the launcher, retains unrelated files,
and refuses to remove modified installed files. A PowerShell profile installation
is separate and uses the PowerShell uninstaller below.

From this checkout:

```powershell
./uninstall.ps1
# Use the same directory if you installed to a custom location.
./uninstall.ps1 -InstallDirectory ./my-install
```

Uninstall removes the managed loader and installed helper. Other profile text,
including edits made after installation, is preserved. Backups remain in the
installation directory. Modified helper files or loader blocks are left for
manual review. Close existing terminals to unload functions already in memory.
Generated C# files are not removed.

## Development and validation

```powershell
./tests/Test-Dnet.ps1
./tests/Test-Install.ps1
```

On Linux, also run `bash tests/Test-Unix.sh` and `sh tests/Test-Unix.sh` to test
the installed shell command end to end.

The first suite compiles generated C# and exercises project selection, path
handling, collisions, CLI forwarding, and command completion. The installer
suite uses temporary profiles and a temporary installation directory. Neither
suite runs migrations against an application database. GitHub Actions runs
the suites on Windows, Linux, and macOS, plus Windows PowerShell 5.1.

## License

[MIT](LICENSE). This project is not affiliated with Laravel, Microsoft, or Zed.

Underlying CLI references: [.NET CLI](https://learn.microsoft.com/en-us/dotnet/core/tools/),
[EF Core CLI](https://learn.microsoft.com/en-us/ef/core/cli/dotnet).
