# ⚡ SETTDash

**All-in-one Windows optimization & tweaking dashboard** — cache cleaner, network optimizer, system tweaks, game mode, privacy, services, GPU/CPU tools, installers and more, in a single dark WPF interface. Self-contained PowerShell script, no installation required.

[![Platform](https://img.shields.io/badge/platform-Windows-1f6feb.svg?style=flat-square)]()
[![License](https://img.shields.io/badge/license-GPL--3.0-3fb950.svg?style=flat-square)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-8b949e.svg?style=flat-square)]()

> ⚠️ **Requirement:** Administrator privileges recommended for most tweaks (registry, services, power and privacy changes).

## ✨ Features

- **🖥️ Dark dashboard** — minimalist WPF interface (GitHub-dark `#0D1117`) with custom title bar and accordion sidebar
- **🧹 Cache cleaner** — temp files, browser cache, log files, memory dumps, prefetch, shader cache, Store cache, update cache, delivery optimization and device cleanup
- **🌐 Network optimizer** — TCP/IP tuning plus a built-in DNS tool (DnsJumper)
- **⚙️ System tweaks** — browser (Chrome, Edge, Firefox, Brave), Windows 11 (classic Alt-Tab, old context menu), context menu, registry and services
- **🎮 Game Mode** — gaming-focused optimizations, GPU tweaks and power options
- **🧠 Memory** — memory cleanup and optimization (bundles SETTMemoryCleaner)
- **🔒 Privacy** — telemetry and tracking toggles
- **📦 Playbooks** — one-click download of AME Wizard, AtlasOS, ReviOS and FSOSX playbooks
- **🛠️ Embedded tools** — Autoruns, DeviceCleanup, DnsJumper, FilterKeysSetter, TimerResolution, vibranceGUI, OOAPB, sPowers, MSI util and more, extracted on first run
- **💾 Installers** — winget-powered app catalog grouped by category (CPU, GPU, Essentials, Internet, Integrations, Utilities)
- **🛡️ Restore point** — creates a system restore point before applying changes
- **🖥️ Your PC** — detailed System, Sensors, GPU, CPU, Disks and Energy pages, each exportable to a printable/PDF report
- **📊 Benchmark** — CPU, GPU, RAM and Disk stress tests with live charts, plus an Export page that combines all results (cached until the app closes) into one printable/PDF report
- **🎨 Settings** — Default/Terminal Retro theme switcher, auto-start, minimize to tray, default startup page and update check toggle

## 🚀 Quick Start

1. Download `SETTDash.exe` from the [latest release](https://github.com/otaviozanon/SETTDash/releases/latest)
2. Run as Administrator
3. Pick a category from the sidebar and apply what you need

No installation — single self-contained executable.

## 📁 Project Structure

```
SETTDash.ps1          full source — WPF XAML layout + all tweak logic + embedded tools
SETTDash.exe          compiled self-contained executable (release asset, not committed)
icon_lightning.ico    window icon
```

The entire application lives in a single `SETTDash.ps1` — the XAML dashboard, the page generators, the tweak functions and the embedded programs (gzip-compressed and stored inline, extracted to `%TEMP%\SETTDash` on first run).

## 🧬 How It Works

1. Boots a WPF window (`System.Windows.Forms` + `PresentationFramework`) with a custom, transparent title bar
2. Builds the sidebar and cards dynamically from the script data
3. Each tweak applies registry / service / power changes and logs the result to the in-app console
4. Playbooks and installers are fetched from official sources (GitHub releases, winget, Microsoft Store) at run time

## 📄 License

GPL-3.0. See [LICENSE](LICENSE).
