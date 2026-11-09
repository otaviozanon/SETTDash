# SETTDash

**All-in-one Windows optimization & tweaking dashboard** - cache cleaner, network optimizer, system tweaks, game mode, privacy, services, startup manager, benchmarks, hardware sensors and installers, in a single dark WPF interface. Self-contained PowerShell executable, no installation required.

[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20x64-1f6feb.svg?style=flat-square)]()
[![License](https://img.shields.io/badge/license-GPL--3.0-3fb950.svg?style=flat-square)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-8b949e.svg?style=flat-square)]()

> Administrator privileges are required for registry, service, power and privacy changes. The executable requests elevation on launch.

## Features

- **Dashboard** - GitHub-dark WPF UI with a custom title bar, collapsible sidebar and a global sidebar search.
- **Clean** - System Cleaner (temp files, browser caches, logs, prefetch, Windows Update cache, memory dumps, Recycle Bin), Registry Cleaner (with `.reg` backup before every fix) and Device Cleanup.
- **Network** - TCP/IP tuning, DNS tool and network cleanup.
- **Startup** - the four places Windows starts programs from, no `msconfig` needed:
  - **Registry** - Run/RunOnce entries with the same StartupApproved state Task Manager writes.
  - **Startup Folder** - user and all-users startup folders.
  - **Services** - Win32 services, Microsoft ones hidden by default (Authenticode check, persisted cache).
  - **Scheduled Items** - third-party Task Scheduler tasks with last/next run and result. Microsoft's own tasks are never listed.
  - Every Startup row shows its publisher (or **Unsigned**) and whether it is a user/machine entry.
- **Your PC** - System, Sensors, GPU, CPU, Disks and Energy pages, each exportable to a printable report.
- **System** - Performance, Network & Privacy, System Tweaks (browser, Windows 11, context menu, registry, services) and Windows Tweaks.
- **Installers** - winget-powered catalog grouped by category.
- **Tools** - Utilities and Playbooks (AME Wizard, AtlasOS, ReviOS, FSOSX).
- **Benchmark** - CPU, GPU, RAM and Disk stress tests with live charts, plus an Export page that combines the results into one HTML/PDF report.
- **Settings** - theme switcher, auto-start, minimize to tray, default startup page and update check.
- **Restore point** - creates a System Restore checkpoint before applying changes.

## Requirements

- Windows 10 or Windows 11, x64.
- Administrator rights.
- The release `.exe` is self-contained: PowerShell 5.1 is already part of Windows, no modules or installers are needed.
- Running from source additionally needs PowerShell 5.1+ and the `ps2exe` module (only to compile).

## Download

Grab `SETTDash.exe` from the [latest release](https://github.com/otaviozanon/SETTDash/releases/latest) and run it.

## Data locations

| What | Where |
| --- | --- |
| Extracted embedded tools/font/libs | `%LOCALAPPDATA%\SETTDash\runtime` |
| Settings | `%APPDATA%\SETTDash\settings.json` |
| Registry backups | `%LOCALAPPDATA%\SETTDash\Backups\Registry` |
| Error reports | `%LOCALAPPDATA%\SETTDash\logs` |

Nothing is written under `%TEMP%`: the app cleans that folder while it is still running.

## Build from source

The repository is modular; `Build.ps1` concatenates the sources into `SETTDash.ps1` in the correct dependency order. Never edit `SETTDash.ps1` directly - it is generated and ignored by git.

```powershell
.\Build.ps1

Import-Module ps2exe
Invoke-ps2exe -inputFile SETTDash.ps1 -outputFile SETTDash.exe -iconFile SETTDash.ico `
    -noConsole -requireAdmin -x64 -title "SETTDash" `
    -description "All-in-one Windows optimization & tweaking dashboard" `
    -product "SETTDash" -company "otaviozanon"
Remove-Item SETTDash.ps1
```

`Build.ps1` injects the version into the generated script. It uses `$env:SETTDASH_VERSION` when set (the release workflow does this), otherwise the newest `v*` git tag. `Main\Window.ps1` only holds the fallback value.

## Tests

```powershell
# Everything except the compiled smoke test
.\tests\Run-All.ps1 -SkipSmoke

# Full gate: build, static guards, benchmark export, strict mode, settings,
# action sandbox and the compiled smoke sweep (needs ps2exe)
.\tests\Run-All.ps1

# Same suite elevated (one UAC prompt) for admin-only code paths
.\tests\Run-All.ps1 -Elevated
```

Every suite runs in its own PowerShell process. The action sandbox intercepts every mutating cmdlet, so the tests never touch the real registry, services or files.

## Project layout

```
Build.ps1              concatenates the sources into SETTDash.ps1
Main/                  XAML layout, window, title bar, startup sequence
Sidebar/               sidebar wiring and one file per page
Core/Helpers/          logging, theme, navigation, cards, background jobs, updater
Core/Actions/          scan/apply/revert functions (clean, tweaks, benchmarks, ...)
Core/Embed/            embedded tools, libraries and font (base64 + gzip)
Core/Gauges/           gauge and bar builders
tests/                 one test suite per concern, orchestrated by Run-All.ps1
```

## Security notes

- No kernel driver is bundled. CPU/GPU sensors use the signed PawnIO driver, installed separately through winget only if the user accepts the prompt.
- The app does not collect telemetry.
- `SETTDASH_NO_UPDATE_CHECK=1` disables the startup update check (used by the smoke test).
- The updater verifies the SHA-256 digest published by GitHub when it is available and refuses a download that does not match.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Commit messages follow Conventional Commits.

## License

GPL-3.0. See [LICENSE](LICENSE). Embedded third-party tools and libraries remain under their own licenses.
