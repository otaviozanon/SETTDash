# tests

Automated checks for SETTDash. Run them after **any** code change, before committing and before
publishing a new `.exe`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-All.ps1
```

Exit code `0` = all good, `1` = at least one suite failed (do not publish). Individual suites can be
run on their own; each one prints `[ok]` / `[FAIL]` lines and exits with the same convention.

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-All.ps1 -SkipSmoke
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-All.ps1 -Elevated
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-StrictMode.ps1
```

`-Elevated` relaunches the whole suite as administrator (one UAC prompt) so the paths that only
exist for an admin are exercised too. Accept the prompt and leave the elevated window open until it
prints its summary.

## Suites

| Suite | File | What it proves | Time |
|---|---|---|---|
| Build | `Test-Build.ps1` | `Build.ps1` produces a script that parses, contains the WOW64/logging contracts, defines no function twice, and carries no debug/autorun leftovers. Deletes the generated `SETTDash.ps1` afterwards. | ~5 s |
| StaticGuards | `Test-StaticGuards.ps1` | Source-level rules that encode the v3.2.31/v3.2.32 regressions: no unwrapped collection result read with `.Count`, `.CimClass` only via `Get-SafeProp`, no `@( ... \| ConvertFrom-Json)`, no `$Script:TempDir` under `%TEMP%`, no `FirstChanceException` hook. | ~5 s |
| StrictMode | `Test-StrictMode.ps1` | Loads the scan/selection layer under `Set-StrictMode -Version Latest` and feeds it the crashing inputs: empty selections, `$null` paths, corrupt/malformed `disabled-startups.json`, plus read-only scans against the real machine. | ~10 s |
| Actions | `Test-Actions.ps1` | Runs the **real** action code in a sandbox (see below): sweeps every mutating function, proves a clean folder really gets deleted while everything outside the sandbox survives, compares each apply against its revert, and fails if any mutating command in the tree is not intercepted. | ~75 s |
| Smoke | `Test-Smoke.ps1` | Builds and compiles a **real x64 exe** (unelevated, no UAC), walks all 27 sidebar pages, clicks every read-only `Scan` button, and asserts the process exits 0, the driver reports `failures=0`, and no error report was written. | ~60–120 s |

All suites write their artifacts to `tests\.tools\` (git-ignored): the injected script, the compiled
exe, the marker/stdout/stderr logs, the sandbox stubs and the sandbox filesystem.
`Run-All.ps1` keeps them so a failure in CI can be downloaded as an artifact; delete the folder
whenever you want the space back.

## The sandbox (how destructive actions get tested)

`tests\Sandbox.ps1` loads 96 of the app's 102 source files in `Build.ps1` order (the six that need a
real WPF window are skipped, and their public entry points are stubbed) and then replaces every
mutating cmdlet with a shadow that records **what would have been done** into a journal and does
nothing else:

* registry, files, services, scheduled tasks, processes, archive extraction, NIC properties, DNS
  cache, memory compression, system restore, downloads — journaled, never executed;
* native tools (`netsh`, `powercfg`, `reg`, `winget`, `sc`, `schtasks`, `dism`, ...) resolve to
  `.cmd` stubs earlier on `PATH` that append their arguments to the same journal;
* `%TEMP%` points inside the sandbox for the duration, so code that calls `[System.IO.File]`
  directly cannot write to the real temp;
* the GUI layer (`Write-GuiLog`, `Set-GuiProgress`, `$Window`) is stubbed, so an action's own error
  reporting can be asserted without touching `%LOCALAPPDATA%`.

The **only** real filesystem effect allowed is deletion under `tests\.tools\sandbox-fs\`: the
cleanup tests create fake files there and prove they are really removed, while a probe file outside
that tree is proven to survive.

The guard that keeps this honest is AST-based, not a doc note: every command in the sources is
classified by its verb, and anything mutating that is not an app function, a reviewed safe command
or a shadow in `Sandbox.ps1` fails the suite. Direct `[System.IO.File]::` / registry writes are
pinned in a reviewed allow-list for the same reason.

## Order of operations before a release

1. `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-All.ps1`
2. Fix whatever failed (the failing assertion prints the file/line it cares about).
3. Run it again until green.
4. Optionally repeat with `-Elevated` for the admin-only paths.
5. Commit, then push / publish.

On GitHub, `release.yml` runs this same suite as a `test` job and the `release` job declares
`needs: test`, so a red suite blocks the version bump, the tag and the publish. CI runners are
already administrators, so the elevated paths run there without any prompt.

## Why compile in the smoke test

Two of the reported crashes only reproduced in the ps2exe host, not in `powershell.exe SETTDash.ps1`:

* a first-chance exception handler that re-entered PowerShell for every failed assembly probe
  (stack overflow on *Your PC > Disks* without elevation);
* nested `Where-Object` pipelines over scheduled-task triggers that do not expose `CimClass`
  (stack overflow on *Clean > Startup Manager*).

Both kill the process with `Process is terminated due to StackOverflowException.` and no managed
handler can run, so nothing is logged. A non-compiled test would have called the same code and
passed. That is the whole reason this suite compiles.

## Known limits

* The sandbox proves the **intent** is correct and the code does not crash, not that Windows accepts
  the change. A registry write is journaled; whether `HKLM\...` really takes the value under your
  policy/ACL is only proven by a real elevated run.
* Actions that depend on real hardware or third-party binaries (GPU-vendor keys, `winget install`,
  playbook scripts, downloadable utilities) report their natural "not available here" error inside
  the sandbox, and the suite only requires that they do not throw.
* The smoke exe is **not elevated** (UAC cannot be accepted unattended in the default run). Use
  `Run-All.ps1 -Elevated` locally for the admin paths; CI runners are already administrators.
* Visual output, animations and anything that needs a human to look at the window are not asserted.
* A native crash inside a third-party DLL and a stack overflow cannot be logged, by design.

## Gotchas worth remembering

* `%TEMP%` is wiped by *Full Cleanup*: never put build tools or runtime files there. The app keeps
  its runtime under `%LOCALAPPDATA%\SETTDash\runtime`.
* An empty array is unrolled to `$null` by PowerShell, so `@($x).Count` is the safe form. The
  `StaticGuards` suite enforces it instead of relying on review.
* `ConvertFrom-Json` returns a top-level JSON array as a **single** object in PowerShell 5.1: assign
  it to a variable first, then wrap with `@()`. `@(Get-Content -Raw | ConvertFrom-Json)` silently
  produces an array of one array.
