# dnet-artisan

**Artisan-style commands for .NET, right in your PowerShell terminal.**

Create controllers, classes, DTOs, and service/interface pairs without leaving
your editor. Run, build, test, and manage EF Core migrations using short commands.
Works with Zed, VS Code, or any terminal that runs PowerShell.

```powershell
dnet make:controller Product --resource
dnet make:class Helpers/DateHelper
dnet make:service Payment --interface
dnet serve
```

[Bahasa Indonesia](docs/README.id.md) | [Command reference](docs/commands.md) |
[Contributing](CONTRIBUTING.md)

## Status and requirements

Version **0.1.0** is a PowerShell helper, not a .NET global tool or an editor
extension. Windows PowerShell 5.1 and PowerShell 7 are supported. PowerShell 7
is required on Linux and macOS. Install a .NET SDK appropriate to your project.
The generated code targets current SDK-style C# projects; the compilation smoke
test uses .NET 10. EF commands also require `dotnet-ef` and the
`Microsoft.EntityFrameworkCore.Design` package in the target project.

## Install from this checkout

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

The command is available in PowerShell sessions. This release does not install a
`cmd.exe`, Bash, or Zsh command, and it is not installed through `dotnet tool`.

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

The first suite compiles generated C# and exercises project selection, path
handling, collisions, CLI forwarding, and command completion. The installer
suite uses temporary profiles and a temporary installation directory. Neither
suite runs migrations against an application database. GitHub Actions runs
the suites on Windows, Linux, and macOS, plus Windows PowerShell 5.1.

## License

[MIT](LICENSE). This project is not affiliated with Laravel, Microsoft, or Zed.

Underlying CLI references: [.NET CLI](https://learn.microsoft.com/en-us/dotnet/core/tools/),
[EF Core CLI](https://learn.microsoft.com/en-us/ef/core/cli/dotnet).
