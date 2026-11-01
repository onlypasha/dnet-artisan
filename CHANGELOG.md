# Changelog

## 0.2.0

- Add an executable `dnet` command for Linux Bash/Zsh, powered by PowerShell 7.
- Add `install.sh` and `uninstall.sh`, user-local and XDG-aware install locations,
  and custom `--prefix` support without editing shell profiles or using sudo.
- Preserve shell argument boundaries and native .NET exit codes.
- Test shell installation, generators, compilation, quoting, exit codes, reinstall,
  modified-file protection, XDG locations, and uninstall on Linux CI.

## 0.1.0

- Add Artisan-style C# generators for controllers, classes, models, DTOs,
  services, interfaces, and enums.
- Add nested names, project selection, namespace overrides, and command completion.
- Add .NET build/run/watch/test/package and EF Core migration shortcuts.
- Refuse existing output files and unsafe generator paths.
- Add a portable profile installer and uninstall with profile preservation.
- Add generator compilation tests, installer tests, and GitHub Actions CI.
