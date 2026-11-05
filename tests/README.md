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
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-StrictMode.ps1
```

## Suites

| Suite | File | What it proves | Time |
|---|---|---|---|
| Build | `Test-Build.ps1` | `Build.ps1` produces a script that parses, contains the WOW64/logging contracts, defines no function twice, and carries no debug/autorun leftovers. Deletes the generated `SETTDash.ps1` afterwards. | ~5 s |
| StaticGuards | `Test-StaticGuards.ps1` | Source-level rules that encode the v3.2.31/v3.2.32 regressions: no unwrapped collection result read with `.Count`, `.CimClass` only via `Get-SafeProp`, no `@( ... | ConvertFrom-Json)`, no `$Script:TempDir` under `%TEMP%`, no `FirstChanceException` hook. | ~5 s |
| StrictMode | `Test-StrictMode.ps1` | Loads the scan/selection layer under `Set-StrictMode -Version Latest` and feeds it the crashing inputs: empty selections, `$null` paths, corrupt/malformed `disabled-startups.json`, plus read-only scans against the real machine. | ~10 s |
| Smoke | `Test-Smoke.ps1` | Builds and compiles a **real x64 exe** (unelevated, no UAC), walks all 27 sidebar pages, clicks every read-only `Scan` button, and asserts the process exits 0, the driver reports `failures=0`, and no error report was written. | ~60–120 s |

`Smoke` writes its artifacts to `tests\.tools\` (git-ignored): the injected script, the exe, the
marker log and the captured stdout/stderr. `Run-All.ps1` keeps them so a failure in CI can be
downloaded as an artifact; delete the folder whenever you want the space back.

## Order of operations before a release

1. `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-All.ps1`
2. Fix whatever failed (the failing assertion prints the file/line it cares about).
3. Run it again until green.
4. Commit, then push / publish.

On GitHub, `release.yml` runs this same suite as a `test` job and the `release` job declares
`needs: test`, so a red suite blocks the version bump, the tag and the publish.

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

* The smoke exe is **not elevated** (UAC cannot be accepted unattended). Pages that need admin
  degrade gracefully and are exercised in that degraded state; the elevated behaviour is not
  covered.
* Only read-only actions are automated. Buttons that change the system (Fix, Delete, Optimize,
  Install, Download, Revert, Clean) are never clicked: they are covered by `StrictMode` at the
  function level and by the user's own testing.
* A native crash inside a third-party DLL and a stack overflow cannot be logged, by design.

## Gotchas worth remembering

* `%TEMP%` is wiped by *Full Cleanup*: never put build tools or runtime files there. The app keeps
  its runtime under `%LOCALAPPDATA%\SETTDash\runtime`.
* An empty array is unrolled to `$null` by PowerShell, so `@($x).Count` is the safe form. The
  `StaticGuards` suite enforces it instead of relying on review.
* `ConvertFrom-Json` returns a top-level JSON array as a **single** object in PowerShell 5.1: assign
  it to a variable first, then wrap with `@()`. `@(Get-Content -Raw | ConvertFrom-Json)` silently
  produces an array of one array.
