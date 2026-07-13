# Changelog

All notable changes and future updates will be documented here.

## [1.3.0-beta] — 2026-07-12

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