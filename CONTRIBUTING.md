# Contributing

## Setup

1. Clone the repository.
2. Install `ps2exe` (only needed to compile the executable):

   ```powershell
   Install-Module ps2exe -Scope CurrentUser
   ```

3. Enable the commit-message hook (once per clone):

   ```powershell
   git config core.hooksPath .githooks
   ```

## Build

```powershell
.\Build.ps1
```

This writes the generated `SETTDash.ps1` (ignored by git). Compile it with `ps2exe` as shown in the README, then delete the generated script. Release builds are produced by `.github/workflows/release.yml`; do not commit `SETTDash.ps1` or `SETTDash.exe`.

## Tests

Run before every commit that changes source:

```powershell
.\tests\Run-All.ps1
```

- `-SkipSmoke` skips the compiled sweep while iterating.
- `-Elevated` runs the suite as administrator when the change touches admin-only paths.
- The action sandbox (`tests/Sandbox.ps1`) intercepts every mutating cmdlet. A test that really needs to mutate state must do it inside the sandbox or in a scratch folder it removes afterwards.

Add a test when you add a scan, a mutation, a persisted preference or a new page. The existing suites are the reference: `Test-StrictMode` for the data layer, `Test-Actions` for anything that writes, `Test-Settings` for preferences, `Test-Smoke` for the compiled host.

## Commit messages

Conventional Commits, imperative mood, first line under 72 characters:

```
<type>(<optional scope>): <summary>
```

Allowed types:

| Type | Use for |
| --- | --- |
| `feat` | a user-visible feature |
| `fix` | a bug fix |
| `docs` | README, comments |
| `style` | formatting only |
| `refactor` | no behaviour change |
| `perf` | performance |
| `test` | tests only |
| `build` | build scripts, dependencies |
| `ci` | workflows |
| `chore` | maintenance |
| `revert` | reverting a previous commit |

Examples:

```
feat(startup): show the publisher of each startup entry
fix(services): persist the Microsoft signature cache between scans
docs: document the modular build
```

The `.githooks/commit-msg` hook rejects messages that do not match. GitHub auto-generates release notes from these messages, so a vague "Fixes" hurts the changelog.

## Pull requests

- Keep the diff focused. One concern per PR.
- Include the test you added or explain why none is needed.
- Do not bump the version manually: the release workflow derives it from the tag.
- `tests\Run-All.ps1` must be green.
