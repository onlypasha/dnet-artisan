# Contributing

Use PowerShell 7 and a .NET 10 SDK for development. Keep runtime code compatible
with Windows PowerShell 5.1: avoid ternary operators, null-coalescing operators,
and other syntax introduced in PowerShell 7.

```powershell
./tests/Test-Dnet.ps1
./tests/Test-Install.ps1
```

Use `-SkipBuild` for fast generator/dispatch checks or `-KeepArtifacts` to inspect
temporary fixtures after a run. Full validation must include the compilation
smoke test. Tests must not use a real application's database or edit actual
PowerShell profiles.

For a new command, update `src/Dnet.ps1`, command completion, the command
reference, and tests covering the resulting file or native CLI arguments.
Preserve argument boundaries: do not build shell command strings or use
`Invoke-Expression`. Generated files must stay within the project, and existing
files must not be overwritten.

Keep changes focused. Describe the resulting behavior and include the tests
you ran in pull requests. Report bugs with your OS, PowerShell version, .NET SDK
version, the exact command, and a minimal project layout.
