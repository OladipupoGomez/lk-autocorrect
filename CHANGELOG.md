# Changelog

All notable changes and future updates will be documented here.

## [1.2.0] — 2025-05-26

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