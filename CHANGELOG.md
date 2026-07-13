# Changelog

All notable changes and future updates will be documented here.

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