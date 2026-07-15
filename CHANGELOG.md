# Changelog

All notable changes and future updates will be documented here.

## [1.4.0] — 2026-07-15

This release makes autocorrect much smarter, and Windows now works just as well as Mac and Linux.

### What's new
- Autocorrect now fixes typos in subcommands too, not just the main command. For example, `git psuh` becomes `git push`, and `trafform fmt` becomes `terraform fmt`. This works for git, terraform, kubectl, docker, aws, az, and helm
- If you typo both the command AND the subcommand at once (like `gti statsu`), it fixes both together and only asks you once instead of twice
- Windows now has all the same features as Mac and Linux, including the new subcommand fixing
- New `ac-off` and `ac-on` commands — turn autocorrect off temporarily without uninstalling it, then turn it back on whenever you want
- Longer command names now get a little more leeway when matching typos, since a few wrong letters matter less in a long word than a short one
- If lk-autocorrect isn't found after installing, you'll now get clear instructions to fix it, on both Windows and Mac/Linux
- Added a lot more commands to the default list so more typos get caught out of the box
- Uninstalling now reminds you to open a new terminal window so everything is fully removed

### Fixed (PowerShell, found during beta testing)
- Subcommand wrapper's temporary file was being created via system `mktemp` (typically `/tmp`), which `matcher.py`'s path validation silently rejected since it only allows reads from inside `~/.config/lk-autocorrect/`. Fixed by creating the temp file inside `AUTOCORRECT_DIR` instead — this was the root cause of subcommand correction silently doing nothing
- `CommandScriptBlock` execution bug — calling a corrected command by bare name (e.g. `git`) could resolve to lk-autocorrect's own subcommand-wrapper function instead of the real executable, silently dropping arguments. Fixed by resolving the actual `.exe` path via `Get-Command -CommandType Application` before executing
- Phantom "Did you mean" prompts firing during normal PowerShell startup — caused by PowerShell's own internal command resolution (e.g. trying `get-aws`, `get-helm` as verb-noun guesses when an application isn't installed) also triggering our `CommandNotFoundAction` handler. Fixed by checking `$eventArgs.CommandOrigin -eq "Runspace"`, so only commands the user actually typed are ever processed
- `matcher.py` and the command store are now refreshed automatically on every source — previously an existing install would keep an old, incomplete store forever since files were only written if missing. The store now merges in any new default commands on top of existing installs, preserving anything added via `ac-add` or removed via `ac-remove`
- Output ordering bug in `lk-autocorrect upgrade` — buffered `print()` output could appear after a spawned subprocess's output, making the old version banner appear to print after the new version had already run. Fixed with explicit `sys.stdout.flush()` calls before each subprocess invocation

### Security
- Updated a build tool (`setuptools`) to patch a known security issue

---

## [1.4.0-beta2] — 2026-07-14

### Added
- Subcommand typo correction — `git`, `terraform`, `kubectl`, `docker`, `aws`, `az`, and `helm` now correct typos in their subcommands, not just the base command (e.g. `git psuh` → `git push`, `trafform fmt` → `terraform fmt`)
- Windows/PowerShell parity — `autocorrect.ps1` now has the same subcommand correction, `ac-off`/`ac-on` toggle, length-aware matching, and combined single-prompt correction as `autocorrect.sh`. PowerShell subcommand wrapping uses `function:global:` to shadow each wrapped command, resolving the real `.exe` path once via `Get-Command -CommandType Application` to avoid recursive calls
- Combined single-prompt correction — when both the base command and the subcommand are mistyped at once (e.g. `gti statsu`), both are corrected together and the user is only asked once, instead of seeing two separate confirmation prompts
- Significantly expanded the default command store — git, docker, kubectl/helm, terraform, aws, and az now each ship with 10–18 subcommands instead of 3–4, making subcommand correction useful out of the box
- `ac-off` / `ac-on` — disable or re-enable autocorrect for the current shell session without uninstalling; `ac-help` now shows live enabled/disabled status
- `AUTOCORRECT_ENABLED` environment variable — set to `false` in your shell rc file to disable autocorrect permanently without removing it
- Length-aware fuzzy matching — words of 8+ characters get one extra edit of tolerance (`threshold + 1`), since a 3-edit difference is proportionally much smaller on a long word than a short one
- macOS/Linux PATH guidance — `lk-autocorrect install` now detects if the CLI isn't resolvable on PATH and prints the exact `export PATH=...` command to fix it, computed via Python's `sysconfig`, matching the guidance Windows already had

### Fixed
- Subcommand wrapper's temporary file was being created via system `mktemp` (typically `/tmp`), which `matcher.py`'s path validation silently rejected since it only allows reads from inside `~/.config/lk-autocorrect/`. Fixed by creating the temp file inside `AUTOCORRECT_DIR` instead — this was the root cause of subcommand correction silently doing nothing
- Trailing space in the correction prompt when a corrected subcommand had no additional arguments (e.g. `git push ?` → `git push?`)

### Security
- Pinned `setuptools>=83.0.0,<85` in build requirements and CI (`PYSEC-2026-3447`), fixed in `83.0.0`. Upper bound added to avoid unexpected breakage from future setuptools releases

## [1.3.0] — 2026-07-14

Stable release consolidating all Windows support work from the beta cycle (`1.3.0-beta2` through `1.3.0-beta6`).

### Added
- Full Windows support via PowerShell 5 and PowerShell 7, using the `CommandNotFoundAction` hook
- `src/autocorrect.ps1` — dedicated PowerShell script with `ac-add`, `ac-remove`, `ac-list`, `ac-test`, `ac-help`
- WSL detection — installer correctly treats WSL as Linux rather than Windows
- `lk-autocorrect upgrade` command — detects pip vs pipx automatically, supports `--pre` for beta/alpha releases and exact version pinning (`lk-autocorrect upgrade [version]`)
- `install` now verifies the package is genuinely installed via pip/pipx before proceeding, and warns if already fully installed and configured
- PATH guidance printed automatically on install for both Windows and macOS/Linux when `lk-autocorrect` isn't resolvable on PATH
- Windows and PowerShell-specific commands added to the default store (`winget`, `choco`, `scoop`, `Get-Help`, `Get-Process`, etc.)
- CI now tests across Ubuntu, macOS, and Windows on Python 3.11–3.13

### Fixed
- PowerShell command correction rewritten using `$eventArgs.CommandScriptBlock` — the officially supported substitution mechanism — fixing verb-noun transformation issues, scope restrictions on `Invoke-Expression`, and duplicate error messages
- Argument passing to corrected commands on PowerShell (e.g. `gti status` → `git status`)
- Unicode encoding crash on Windows (CP1252) — replaced `✓`/`✗` with ASCII equivalents
- `upgrade` re-exec bug — was calling a non-existent module path, now resolves the installed console script directly so it works regardless of internal package structure
- WSL no longer blocked by the Windows platform check in the installer

### Changed
- Minimum Python version raised from 3.9 to 3.11 — 3.9/3.10 caused installation failures on Windows CI runners and are approaching end-of-life

---

## [1.3.0-beta6] — 2026-07-13

### Fixed
- `VERSION` string in `src/cli.py` was not bumped before tagging and publishing `1.3.0-beta5` — the package published to PyPI as `1.3.0b5` still reported itself as `1.3.0b4` at runtime, making the earlier re-exec fix impossible to verify. No functional code changes in this release; version string corrected and re-published so `lk-autocorrect --version` reports accurately

## [1.3.0-beta5] — 2026-07-13

### Fixed
- `upgrade` re-exec was calling `-m lk_autocorrect.cli` which does not exist — the actual package module is `src`, causing `ModuleNotFoundError: No module named 'lk_autocorrect'` on both macOS (pipx) and Windows (pip) immediately after every upgrade. Fixed by resolving the installed `lk-autocorrect` console script directly via `shutil.which()` instead of hardcoding an internal module path — this also makes the fix immune to any future package/module renaming

### Added
- `install` now warns when lk-autocorrect is already installed and configured (shell script exists AND RC/profile is already injected), pointing the user to `lk-autocorrect upgrade` or `lk-autocorrect uninstall` instead of silently re-running with no clear signal that nothing changed

## [1.3.0-beta4] — 2026-07-13

### Added
- `lk-autocorrect upgrade` command — single cross-platform command to upgrade the package
- Automatically detects whether the package was installed via `pip` or `pipx` and runs the correct upgrade command
- `--pre` flag on `upgrade` — pulls the latest beta/alpha pre-release
- Version pinning on `upgrade` — e.g. `lk-autocorrect upgrade 1.3.0b4` installs an exact version
- Re-exec mechanism — after upgrading, `upgrade` automatically restarts itself as a fresh process so it always installs the newly upgraded code rather than the stale version already loaded in memory
- Pip package verification — `install` now confirms lk-autocorrect is genuinely installed via pip/pipx (via `pip show`) before proceeding, and warns if the reported version does not match the running code

### Fixed
- `install` no longer silently reports success when running from a stray or partially broken package

### CI
- `ci.yml` now includes `windows-latest` in the test matrix — PRs catch Windows regressions before they reach `publish.yml`
- Test threshold in CI aligned to `2` to match the actual default (`AUTOCORRECT_THRESHOLD`), previously tested against `3`
- Added dedicated Windows steps for matcher smoke test and injection blocking test (`shell: pwsh`)
- Added `lk-autocorrect status` and `lk-autocorrect help` as explicit CLI smoke tests in CI

## [1.3.0-beta3] — 2026-07-13

### Fixed
- PowerShell `CommandNotFoundAction` handler completely rewritten — original implementation had three separate bugs:
  - PowerShell's verb-noun transformation (e.g. `gti` → `get-gti`) interfered with command lookup
  - `Invoke-Expression` could not execute external commands from within the event handler's restricted scope
  - Corrected commands ran successfully but PowerShell still displayed its own "not recognized" error afterward
- Fixed by using `$eventArgs.CommandScriptBlock` — the officially supported PowerShell mechanism for substituting a command, which replaces the exception entirely instead of running alongside it
- Argument passing fixed — typo args (e.g. `status` in `gti status`) are now correctly parsed from the call stack and appended to the suggested command
- Restored PowerShell-specific commands to the store (`Get-Help`, `Get-Command`, `Get-Process`, `Get-Service`, `Set-Location`, `Get-ChildItem`, `Remove-Item`, `Copy-Item`, `Move-Item`, `Invoke-WebRequest`) — dropped during an earlier rewrite
- Restored and wired up `_ac_yellow`, `_ac_green`, `_ac_red` color helper functions — now used consistently throughout `autocorrect.ps1` instead of duplicated inline `Write-Host` calls, matching the pattern in `autocorrect.sh`
- Fixed `ac-help` PowerShell syntax error — `<cmd>` and `<typo>` inside unquoted strings were being parsed as redirection operators; changed to `[cmd]` and `[typo]`
- Fixed broken string terminator in `ac-help` config example output

## [1.3.0-beta2] — 2026-07-12

### Added
- Windows support — PowerShell 5 and PowerShell 7 via `CommandNotFoundAction` hook
- `src/autocorrect.ps1` — dedicated PowerShell script with full `ac-add`, `ac-remove`, `ac-list`, `ac-test`, `ac-help` support
- WSL detection — installer correctly identifies WSL and uses the Linux/bash path instead of Windows
- Windows package manager commands added to store — `winget`, `choco`, `scoop`
- PowerShell-specific commands added to store — `Get-Help`, `Get-Command`, `Get-Process`, `Get-Service` and more
- `matcher.py` updated to validate store paths on both Windows and Unix
- `cli.py` updated to detect platform (Windows / WSL / Unix) and install the correct script
- PowerShell profile injection — adds source line to both PS7 and PS5 profiles automatically
- Execution policy guidance shown on Windows install
- GitHub Actions now tests on `windows-latest` across Python 3.11, 3.13
- Removed `os = ["linux", "darwin"]` restriction from `pyproject.toml` — package now installs on all platforms

### Fixed
- WSL users no longer blocked by Windows OS check in installer
- Unicode encoding error on Windows — replaced `✓`/`✗` with ASCII equivalents for CP1252 compatibility

### Changed
- Minimum Python version bumped from 3.9 to 3.11 — Python 3.9 and 3.10 caused installation failures on Windows GitHub Actions runners and are approaching end-of-life. Python 3.11+ is stable, widely available, and supported across all platforms

## [1.2.0] — 2026-05-26

### Fixed
- Fixed infinite loop — saying "y" to a suggestion, or running with `AUTOCORRECT_AUTO=true`, could re-trigger the hook recursively when the corrected command also failed to run. Fixed with an `_AC_RUNNING` re-entry guard that skips the hook entirely while a correction is executing
- Fixed false positives on installed-but-unresolvable commands (e.g. `pip4` incorrectly suggesting itself at distance 0 when `pip` existed in the store but wasn't matched correctly) — exact distance-0 matches are now silently ignored since they indicate a real command name, not a typo
- Fixed argument word-splitting — commands like `gti log --oneline -5` previously passed the entire argument string as one token to `eval`, breaking multi-flag commands; switched to unquoted `eval $corrected` so word splitting behaves correctly
- Added explicit command existence check (`command -v`, `type`, `hash`) before running the matcher — if the typed command already exists on `PATH`, autocorrect no longer intercepts it at all

### Changed
- Default `AUTOCORRECT_THRESHOLD` lowered from 3 to 2 — distance 3 was catching too many false positives on unrelated commands (e.g. `twine` incorrectly matching `file` or `ping`); distance 2 still catches all common typos (transpositions, single missing/extra/wrong letter) while ignoring unrelated words

---

## [1.0.0] — 2026-05-26

### Added
- Initial release
- Fuzzy matching using Damerau-Levenshtein distance — transpositions count as 1 edit, so `gti` → `git` scores as distance 1 not 2
- zsh support via `command_not_found_handler` hook — fires automatically on any mistyped command
- bash 4+ support via `command_not_found_handle` hook
- bash 3.2 fallback via `lk <command>` — macOS ships bash 3.2 which does not support the hook
- Python 3.9+ support with EOL warning for versions below 3.10
- Recommended safe version is Python 3.13+
- `ac-add`, `ac-remove`, `ac-list`, `ac-test`, `ac-help` shell commands
- `lk-autocorrect install`, `uninstall`, `status`, `verify`, `help` CLI commands
- Plain text command store at `~/.config/lk-autocorrect/commands.txt` — one command per line, `#` lines are comments
- 150+ popular commands across git, docker, kubectl, terraform, AWS CLI, Azure CLI and more
- Automatic shell RC injection — detects zsh or bash and adds source line to the right config file
- Store and matcher preserved across updates and uninstalls

### Security
- Default threshold set to 2 — prevents false positives on unrelated commands
- Distance 0 matches silently ignored — exact command names that aren't installed don't trigger suggestions
- `_AC_RUNNING` re-entry guard — prevents infinite loop when running corrected command
- Input sanitisation — blocks shell injection characters in typos and store entries
- Store path validation — matcher only reads from `~/.config/lk-autocorrect/`
- Symlink detection — rejects symlinked store files
- File size cap — store capped at 1MB
- Command existence check — if command is found on PATH, autocorrect does not fire
- Store and matcher files set to `600` permissions — only owner can read/write
- `lk-autocorrect verify` — checks installed files, permissions, symlinks and prints SHA256 checksums
- No external dependencies — pure Python and shell
- pip install support — `pip install lk-autocorrect`
- macOS `externally-managed-environment` handled via `--user --break-system-packages`
- Automatic checksum writing on install for integrity verification
- GitHub Actions CI/CD — runs security scan (bandit, pip-audit), tests on Python 3.9–3.13 and Ubuntu/macOS, publishes to PyPI on git tag using trusted publishing