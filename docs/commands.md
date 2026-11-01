# Command reference

Run `dnet list` to see commands or `dnet --version` to see the installed version.
Common option: `--project PATH` selects a project or project directory.

## Generators

| Command | Options | Default output |
|---|---|---|
| `make:controller NAME` | `--resource`, `--api`, `--namespace NAME` | `Controllers/NAMEController.cs` |
| `make:class NAME` | `--namespace NAME` | `NAME.cs` |
| `make:model NAME` | `--namespace NAME` | `Models/NAME.cs` |
| `make:dto NAME` | `--namespace NAME` | `DTOs/NAMEDto.cs` |
| `make:service NAME` | `--interface`, `--namespace NAME` | `Services/NAMEService.cs` |
| `make:interface NAME` | `--namespace NAME` | `Interfaces/INAME.cs` |
| `make:enum NAME` | `--namespace NAME` | `Enums/NAME.cs` |

Existing alternative folder names are reused. Existing suffixes such as
`Controller`, `Service`, and `Dto` are not repeated. An interface name beginning
with `I` followed by an uppercase letter is kept as provided.
Use `/` or `\` to request subfolders, such as `Admin/Report`.
`--api` is accepted for controller commands; API controllers are the default.
`--resource` adds five action stubs, not database-backed CRUD behavior.

## Application commands

| Command | Underlying command |
|---|---|
| `serve [OPTIONS]` | `dotnet watch --project PROJECT run OPTIONS` |
| `run [OPTIONS]` | `dotnet run --project PROJECT OPTIONS` |
| `build [OPTIONS]` | `dotnet build TARGET OPTIONS` |
| `restore [OPTIONS]` | `dotnet restore TARGET OPTIONS` |
| `clean [OPTIONS]` | `dotnet clean TARGET OPTIONS` |
| `format [OPTIONS]` | `dotnet format TARGET OPTIONS` |
| `test [OPTIONS]` | `dotnet test TEST_PROJECT OPTIONS` |
| `package:add PACKAGE [OPTIONS]` | `dotnet add PROJECT package PACKAGE OPTIONS` |

`TARGET` is the nearest unambiguous `.sln`/`.slnx`, otherwise the selected project.
With `--project`, the explicitly selected project is used as the target.
`test` selects a unique `*.Tests.csproj` under the selected application project;
otherwise specify the test project with `--project`.

```powershell
dnet build --configuration Release
dnet run -- --application-option value
dnet test --project ./tests/Shop.Tests/Shop.Tests.csproj --no-restore
dnet format --verify-no-changes
dnet package:add Some.Package --version 1.2.3
```

## Entity Framework commands

| Command | Underlying command |
|---|---|
| `make:migration NAME [OPTIONS]` | `dotnet ef migrations add NAME OPTIONS --project PROJECT` |
| `migrate [OPTIONS]` | `dotnet ef database update OPTIONS --project PROJECT` |
| `migrate:status [OPTIONS]` | `dotnet ef migrations list OPTIONS --project PROJECT` |
| `migrate:rollback TARGET [OPTIONS]` | `dotnet ef database update TARGET OPTIONS --project PROJECT` |
| `db:context [OPTIONS]` | `dotnet ef dbcontext list OPTIONS --project PROJECT` |

EF Core CLI options such as `--context` and `--startup-project` are forwarded.
`migrate:rollback` requires an explicit target; `0` requests reverting every
migration. Database behavior, connection selection, and design-time context
creation are controlled by EF Core and the target application.

The helper does not add migrations, register services, add entity properties,
or change a database as a side effect of a source generator command.
