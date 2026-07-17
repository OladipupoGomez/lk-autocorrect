# lk-autocorrect

> Fuzzy autocorrect for mistyped shell commands. Works in zsh and bash on Linux and macOS, and PowerShell on Windows.

When you mistype a command, instead of a dead error you get a suggestion:

```
$ gti status
[lk-autocorrect] Did you mean: git status?
[lk-autocorrect] Run it? [y/N] y
```

```
$ dockr ps
[lk-autocorrect] Did you mean: docker ps?
[lk-autocorrect] Run it? [y/N] y
```

```
$ terrafrom plan
[lk-autocorrect] Did you mean: terraform plan?
[lk-autocorrect] Run it? [y/N] y
```

---

## Requirements

- **macOS** or **Linux** (zsh or bash) — check with `echo $SHELL`
- **Python 3.11+** — check with `python3 --version`
- **Windows** — PowerShell 5 or PowerShell 7 

---

## Install

### macOS / Linux

**Step 1 — Install lk-autocorrect**

```bash
pip install lk-autocorrect
```

> **macOS users:** if you see an `externally-managed-environment` error, use:
> ```bash
> pip install lk-autocorrect --user --break-system-packages
> ```

**Step 2 — Add lk-autocorrect to PATH (if needed)**

If `lk-autocorrect` is not found after installing, run the command to add it to PATH:

```bash
export PATH="$HOME/Library/Python/3.13/bin:$PATH"
```

Add that line to your `~/.zshrc` or `~/.bashrc` to make it permanent, then restart your shell.

**Step 3 — Run the installer**

```bash
lk-autocorrect install
```

This automatically adds the source line to your `~/.zshrc` or `~/.bashrc`.

**Step 4 — Reload your shell**

```bash
source ~/.zshrc   # zsh
source ~/.bashrc  # bash
```

**Step 5 — Test it**

```bash
gti status        # → Did you mean: git status?
dockr ps          # → Did you mean: docker ps?
kubctl get pods   # → Did you mean: kubectl get pods?
```

---

### Windows (PowerShell)

**Step 1 — Install lk-autocorrect**

```powershell
pip install lk-autocorrect
```

**Step 2 — Add lk-autocorrect to PATH**

After installing, if PowerShell cannot find `lk-autocorrect` run the following commands.
This will find where pip installed it and add it to your PATH permanently:

```powershell
# find where pip installed lk-autocorrect
pip show lk-autocorrect

# add Scripts folder to PATH permanently
$scriptsPath = (pip show lk-autocorrect | Select-String "Location").Line.Split(" ")[1] + "\..\..\Scripts"
$env:PATH += ";$scriptsPath"
```

> This adds the Python Scripts folder to your PATH so `lk-autocorrect` can be found.
> Open a new PowerShell window or restart Powershell after running this.

**Step 3 — Run the installer**

```powershell
lk-autocorrect install
```

This automatically adds the source line to your PowerShell profile (`$PROFILE`).
After install you will see the PATH commands printed — run them if `lk-autocorrect` is not found.

**Step 4 — Reload your profile**

```powershell
. $PROFILE
```

**Step 5 — Test it**

```powershell
gti status        # → Did you mean: git status?
dockr ps          # → Did you mean: docker ps?
kubctl get pods   # → Did you mean: kubectl get pods?
```

> **Note:** if you see a script execution error on first run:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

---

## Shell compatibility

| Shell | Platform | Support | Notes |
|---|---|---|---|
| zsh | macOS / Linux | Full | Automatic — fires on any mistyped command |
| bash 4+ | macOS / Linux | Full | Automatic — fires on any mistyped command |
| bash 3.2 | macOS | Partial | Use `lk <command>` as fallback |
| PowerShell 5 | Windows | Full | Automatic via `CommandNotFoundAction` |
| PowerShell 7 | Windows | Full | Automatic via `CommandNotFoundAction` |
| Git Bash | Windows | Full | Treated as bash — works automatically |
| WSL | Windows | Full | Treated as Linux — works automatically |
| CMD | Windows | ❌ | No hook mechanism available |

### bash 3.2 on macOS

This version does not support the `command_not_found_handle` hook that lk-autocorrect relies on for automatic correction.

When you source the script in bash 3.2 you will see:

```
[lk-autocorrect] bash 3.2 detected — automatic correction unavailable.
[lk-autocorrect] Use: lk <command>  e.g. lk gti status
[lk-autocorrect] Or switch to zsh: chsh -s /bin/zsh
```

**Option 1 — use the `lk` fallback:**
```bash
lk gti status       # → Did you mean: git status?
lk dockr ps         # → Did you mean: docker ps?
```

**Option 2 — switch to zsh (recommended):**
```bash
chsh -s /bin/zsh
# open a new terminal — autocorrect works automatically
```

**Option 3 — upgrade bash:**
```bash
brew install bash
echo '/opt/homebrew/bin/bash' | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/bash
```

---

## Python version

lk-autocorrect requires Python 3.11+ and is supported on older versions, but upgrading to 3.13+ is recommended since older versions no longer receive security patches.

**Check your version:**
```bash
python3 --version
```

**Upgrade on macOS:**
```bash
brew install python@3.13
```

**Upgrade on Linux:**
```bash
sudo apt install python3.13
```

**Upgrade on Windows:**

Download from [python.org](https://python.org) or:
```powershell
winget install Python.Python.3.13
```

---

## Usage

Once installed, autocorrect fires automatically whenever you mistype a command:

```
$ gti commit -m "fix bug"
[lk-autocorrect] Did you mean: git commit -m "fix bug"?
[lk-autocorrect] Run it? [y/N] y
```

### Shell commands

| Command | Description |
|---|---|
| `ac-add <cmd>` | Add a command to the store |
| `ac-remove <cmd>` | Remove a command from the store |
| `ac-list` | List all commands in the store |
| `ac-test <typo>` | Preview what a typo would correct to |
| `ac-off` | Disable autocorrect for the current session |
| `ac-on` | Re-enable autocorrect |
| `ac-help` | Show in-shell help, including current on/off status |

```bash
# add your own commands
ac-add "mycli"
ac-add "my-test-command"

# preview a correction
ac-test "dockr"
# [lk-autocorrect] 'dockr' → 'docker' (distance: 1)

# list everything in the store
ac-list
```

### CLI commands

| Command | Description |
|---|---|
| `lk-autocorrect install` | Install and set up shell hook |
| `lk-autocorrect uninstall` | Remove from system |
| `lk-autocorrect upgrade` | Upgrade to the latest stable version |
| `lk-autocorrect upgrade --pre` | Upgrade to the latest beta/alpha |
| `lk-autocorrect upgrade [version]` | Upgrade to a specific version |
| `lk-autocorrect status` | Show installation status |
| `lk-autocorrect verify` | Check file integrity and print checksums |
| `lk-autocorrect help` | Show help |

---

## Configuration

### macOS / Linux

Set these in your `~/.zshrc` or `~/.bashrc` **before** the source line:

```bash
# how forgiving the matcher is (1 = strict, 5 = loose) — default: 2
# words of 8+ characters automatically get +1 extra tolerance
export AUTOCORRECT_THRESHOLD=2

# auto-run the correction without asking — default: false
export AUTOCORRECT_AUTO=true

# turn off colours — default: true
export AUTOCORRECT_COLOR=false

# turn autocorrect on or off — default: true
export AUTOCORRECT_ENABLED=true
```

To turn autocorrect off temporarily without uninstalling, just run `ac-off` in your shell (and `ac-on` to bring it back). To disable it permanently, set `AUTOCORRECT_ENABLED=false` in your rc file as shown above.

### Windows (PowerShell)

Set these in your `$PROFILE` **before** the source line:

```powershell
$env:AUTOCORRECT_THRESHOLD = "2"
$env:AUTOCORRECT_AUTO = "true"
```

---

## Command store

### macOS / Linux
The store lives at `~/.config/lk-autocorrect/commands.txt` — one command per line, `#` lines are comments.

### Windows
The store lives at `%USERPROFILE%\.config\lk-autocorrect\commands.txt`.

Ships with 150+ popular commands and subcommands across git, docker, kubectl, terraform, AWS CLI, Azure CLI and more. Your store is preserved across updates and uninstalls (you are asked before it is deleted).

```bash
# add a command
ac-add "mycli"

# remove a command
ac-remove "mycli"

# or edit directly
nano ~/.config/lk-autocorrect/commands.txt  or  vim ~/.config/lk-autocorrect/commands.txt  # macOS / Linux
notepad $env:USERPROFILE\.config\lk-autocorrect\commands.txt  # Windows
```

---

## How it works

1. The shell hook (`command_not_found_handler` in zsh, `command_not_found_handle` in bash 4+, `CommandNotFoundAction` in PowerShell) fires when a command is not found.
2. The typo is passed to `matcher.py` which compares it against every command in the store using **Damerau-Levenshtein distance** — an algorithm that counts insertions, deletions, substitutions, and transpositions. This means `gti` → `git` scores as distance 1 (one transposition) not 2.
3. If the closest match is within `AUTOCORRECT_THRESHOLD` edits, the suggestion is shown.
4. You confirm with `y` or it runs automatically if `AUTOCORRECT_AUTO=true`.

### Subcommand correction

`git`, `terraform`, `kubectl`, `docker`, `aws`, `az`, and `helm` also get their **subcommands** corrected, not just the base command:

```
$ git psuh
[lk-autocorrect] Did you mean: git push?
[lk-autocorrect] Run it? [y/N] y
```

```
$ trafform fmt
[lk-autocorrect] Did you mean: terraform fmt?
[lk-autocorrect] Run it? [y/N] y
```

This works even when **both** the base command and the subcommand are mistyped at once — both are corrected together and you only get asked once:

```
$ gti statsu
[lk-autocorrect] Did you mean: git status?
[lk-autocorrect] Run it? [y/N] y
```

### Length-aware matching

Longer words get one extra edit of tolerance. A 3-edit difference on an 8+ letter word (like `trafform` → `terraform`) is a much smaller relative change than the same 3 edits on a short word — so short words are matched more strictly to avoid false positives, while longer words allow slightly looser matching.

---

## Upgrade

`lk-autocorrect` detects whether you installed via `pip` or `pipx` and runs the correct upgrade command automatically, then refreshes your shell files in one step.

```bash
# upgrade to the latest stable release
lk-autocorrect upgrade

# upgrade to the latest beta/alpha (pre-release)
lk-autocorrect upgrade --pre

# upgrade to a specific version
lk-autocorrect upgrade [version]
# example: lk-autocorrect upgrade 1.3.0b4
```

This works the same way on macOS, Linux, and Windows.

### other upgrade commands (alternative)

Instead of using 
`lk-autocorrect upgrade`:

**macOS / Linux (pipx):**
```bash
pipx upgrade lk-autocorrect
```

**macOS / Linux (pip):**
```bash
pip install --upgrade lk-autocorrect
```

**Windows (PowerShell):**
```powershell
pip install --upgrade lk-autocorrect
```

After a manual upgrade, run `lk-autocorrect install` once to refresh your shell files with the new version.

---

## Uninstall

```bash
lk-autocorrect uninstall
pip uninstall lk-autocorrect
```

---

## Verify integrity

```bash
lk-autocorrect verify
```

Prints the SHA256 checksums of the installed files so you can verify them against the GitHub release.

---

## Contributing

Pull requests welcome.

1. Fork the repo
2. Create a branch: `git checkout -b my-feature`
3. Make changes to `src/autocorrect.sh`, `src/autocorrect.ps1` or `src/matcher.py`
4. Test in zsh, bash, and PowerShell
5. Open a PR

---

## License

MIT — see [LICENSE](LICENSE)

---