#!/usr/bin/env python3
"""
lk-autocorrect — fuzzy CLI command correction
https://github.com/OladipupoGomez/lk-autocorrect
"""

import os
import sys
import shutil
from pathlib import Path

# Fix Windows console encoding
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

# Constants
VERSION      = "1.3.0b1"
PACKAGE_DIR  = Path(__file__).parent

# Platform detection
def is_wsl():
    """Detect Windows Subsystem for Linux."""
    try:
        with open("/proc/version") as f:
            return "microsoft" in f.read().lower()
    except Exception:
        return False

def is_windows():
    return sys.platform == "win32"

def get_platform():
    if is_windows():
        return "windows"
    if is_wsl():
        return "wsl"
    return "unix"

PLATFORM = get_platform()

# Paths
if is_windows():
    INSTALL_DIR = Path.home() / ".lk-autocorrect"
    CONFIG_DIR  = Path(os.environ.get("USERPROFILE", Path.home())) / ".config" / "lk-autocorrect"
else:
    INSTALL_DIR = Path.home() / ".lk-autocorrect"
    CONFIG_DIR  = Path.home() / ".config" / "lk-autocorrect"

SCRIPT_SH   = INSTALL_DIR / "autocorrect.sh"
SCRIPT_PS1  = INSTALL_DIR / "autocorrect.ps1"
MARKER      = "# lk-autocorrect"

# Colors
def yellow(s): return f"\033[33m{s}\033[0m"
def green(s):  return f"\033[32m{s}\033[0m"
def red(s):    return f"\033[31m{s}\033[0m"
def bold(s):   return f"\033[1m{s}\033[0m"

TAG = yellow("[lk-autocorrect]")
OK  = green("[lk-autocorrect]")
ERR = red("[lk-autocorrect]")

# Shell detection
def detect_shell():
    home = Path.home()

    if is_windows():
        # PowerShell profile paths
        ps_profile = Path(os.environ.get("USERPROFILE", home)) / "Documents" / "PowerShell" / "Microsoft.PowerShell_profile.ps1"
        ps5_profile = Path(os.environ.get("USERPROFILE", home)) / "Documents" / "WindowsPowerShell" / "Microsoft.PowerShell_profile.ps1"
        return "powershell", ps_profile, ps5_profile

    shell = os.environ.get("SHELL", "")
    if "zsh" in shell:
        return "zsh", home / ".zshrc", None
    elif "bash" in shell:
        rc = home / ".bashrc"
        return "bash", rc if rc.exists() else home / ".bash_profile", None
    return "unknown", home / ".profile", None

# RC file helpers
def is_injected(rc: Path) -> bool:
    if not rc or not rc.exists():
        return False
    return MARKER in rc.read_text(encoding="utf-8", errors="ignore")

def inject_rc(rc: Path, source_line: str):
    rc.parent.mkdir(parents=True, exist_ok=True)
    with rc.open("a", encoding="utf-8") as f:
        f.write(f"\n{MARKER}\n{source_line}\n")

def remove_from_rc(rc: Path):
    if not rc or not rc.exists():
        return
    lines = rc.read_text(encoding="utf-8", errors="ignore").splitlines()
    cleaned = [l for l in lines if l.strip() != MARKER and "lk-autocorrect" not in l]
    rc.write_text("\n".join(cleaned) + "\n", encoding="utf-8")

# Install
def install():
    print(f"\n{bold('lk-autocorrect')} v{VERSION}\n")
    print(f"{TAG} Platform: {bold(PLATFORM)}")

    # verify source files exist before copying
    for f in ["autocorrect.sh", "autocorrect.ps1", "matcher.py"]:
        if not (PACKAGE_DIR / f).exists():
            print(f"{ERR} Missing package file: {f}")
            sys.exit(1)

    INSTALL_DIR.mkdir(parents=True, exist_ok=True)

    if is_windows():
        _install_windows()
    else:
        _install_unix()

def _install_unix():
    shell_name, rc, _ = detect_shell()
    print(f"{TAG} Shell:       {bold(shell_name)}")
    print(f"{TAG} RC file:     {bold(str(rc))}")
    print(f"{TAG} Install dir: {bold(str(INSTALL_DIR))}\n")

    shutil.copy(PACKAGE_DIR / "autocorrect.sh", SCRIPT_SH)
    shutil.copy(PACKAGE_DIR / "matcher.py", INSTALL_DIR / "matcher.py")
    SCRIPT_SH.chmod(0o755)
    (INSTALL_DIR / "matcher.py").chmod(0o644)

    source_line = f'source "{SCRIPT_SH}"'
    if is_injected(rc):
        print(f"{TAG} Already in {rc} — skipping")
    else:
        inject_rc(rc, source_line)
        print(f"{OK} Added to {rc}")

    print(f"\n{OK} {bold('Done!')} Reload your shell:\n")
    print(f"    {bold(f'source {rc}')}\n")
    print(f"  Then try: {bold('gti status')}\n")

def _install_windows():
    shell_name, ps7_profile, ps5_profile = detect_shell()
    print(f"{TAG} Shell:       {bold('PowerShell')}")
    print(f"{TAG} Install dir: {bold(str(INSTALL_DIR))}\n")

    shutil.copy(PACKAGE_DIR / "autocorrect.ps1", SCRIPT_PS1)
    shutil.copy(PACKAGE_DIR / "matcher.py", INSTALL_DIR / "matcher.py")

    source_line = f'. "{SCRIPT_PS1}"'

    # inject into both PS7 and PS5 profiles
    for profile in [ps7_profile, ps5_profile]:
        if profile and not is_injected(profile):
            inject_rc(profile, source_line)
            print(f"{OK} Added to {profile}")
        elif profile:
            print(f"{TAG} Already in {profile} — skipping")

    print(f"\n{OK} {bold('Done!')} Reload PowerShell:\n")
    print(f"    {bold('. $PROFILE')}\n")
    print(f"  Then try: {bold('gti status')}\n")
    print(f"{TAG} Note: if you see a script execution error run:\n")
    print(f"    {bold('Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser')}\n")

# Auto install (postinstall hook)
def auto_install():
    INSTALL_DIR.mkdir(parents=True, exist_ok=True)

    for f in ["autocorrect.sh", "autocorrect.ps1", "matcher.py"]:
        src = PACKAGE_DIR / f
        if src.exists():
            shutil.copy(src, INSTALL_DIR / f)

    if not is_windows():
        SCRIPT_SH.chmod(0o755)
        (INSTALL_DIR / "matcher.py").chmod(0o644)

    if is_windows():
        _, ps7_profile, ps5_profile = detect_shell()
        source_line = f'. "{SCRIPT_PS1}"'
        for profile in [ps7_profile, ps5_profile]:
            if profile and not is_injected(profile):
                inject_rc(profile, source_line)
    else:
        _, rc, _ = detect_shell()
        source_line = f'source "{SCRIPT_SH}"'
        if not is_injected(rc):
            inject_rc(rc, source_line)

    shell_name = "PowerShell" if is_windows() else detect_shell()[0]
    print(f"\n{OK} lk-autocorrect installed for {shell_name}!")

    if is_windows():
        print(f"{TAG} Run {bold('. $PROFILE')} or open a new terminal.\n")
    else:
        _, rc, _ = detect_shell()
        print(f"{TAG} Run {bold(f'source {rc}')} or open a new terminal.\n")

# Uninstall
def uninstall():
    print(f"\n{bold('lk-autocorrect')} — uninstall\n")

    if is_windows():
        _, ps7, ps5 = detect_shell()
        for profile in [ps7, ps5]:
            if profile and is_injected(profile):
                remove_from_rc(profile)
                print(f"{OK} Removed from {profile}")
    else:
        for rc in [
            Path.home() / ".bashrc",
            Path.home() / ".bash_profile",
            Path.home() / ".zshrc",
            Path.home() / ".profile",
        ]:
            if is_injected(rc):
                remove_from_rc(rc)
                print(f"{OK} Removed from {rc}")

    answer = input(f"\nKeep your command store at {CONFIG_DIR}? [Y/n] ")
    if answer.strip().lower() == "n":
        shutil.rmtree(CONFIG_DIR, ignore_errors=True)
        print(f"{TAG} Removed config directory")

    shutil.rmtree(INSTALL_DIR, ignore_errors=True)
    print(f"\n{OK} Uninstalled. Restart your shell.\n")

# Status
def status():
    print(f"\n{bold('lk-autocorrect')} v{VERSION} — status\n")
    print(f"  Platform:  {bold(PLATFORM)}")

    if is_windows():
        _, ps7, _ = detect_shell()
        installed = SCRIPT_PS1.exists()
        injected  = is_injected(ps7)
        print(f"  Script:    {green('OK installed') if installed else red('NOT installed')}")
        print(f"  Profile:   {green('OK yes') if injected else red('NOT no')}")
    else:
        _, rc, _ = detect_shell()
        shell_name = detect_shell()[0]
        installed = SCRIPT_SH.exists()
        injected  = is_injected(rc)
        print(f"  Shell:     {bold(shell_name)}")
        print(f"  RC file:   {bold(str(rc))}")
        print(f"  Script:    {green('OK installed') if installed else red('NOT installed')}")
        print(f"  Sourced:   {green('OK yes') if injected else red('NOT no')}")
    print()

# Verify
def verify():
    import hashlib
    import stat

    print(f"\n{bold('lk-autocorrect')} v{VERSION} — integrity check\n")

    script = SCRIPT_PS1 if is_windows() else SCRIPT_SH
    files  = [script, INSTALL_DIR / "matcher.py"]

    all_ok = True
    for path in files:
        if not path.exists():
            print(f"  {red('!!')} {path.name} — missing")
            all_ok = False
            continue
        if path.is_symlink():
            print(f"  {red('!!')} {path.name} — symlink detected")
            all_ok = False
            continue
        mode = oct(stat.S_IMODE(path.stat().st_mode))
        sha  = hashlib.sha256(path.read_bytes()).hexdigest()
        print(f"  {green('OK')} {path.name} (perms: {mode})")
        print(f"    sha256: {sha}")

    if is_windows():
        _, ps7, _ = detect_shell()
        injected = is_injected(ps7)
    else:
        _, rc, _ = detect_shell()
        injected = is_injected(rc)

    profile_label = "$PROFILE" if is_windows() else str(detect_shell()[1])
    if injected:
        print(f"  {green('OK')} {profile_label} — source line present")
    else:
        print(f"  {red('!!')} {profile_label} — missing, run: lk-autocorrect install")
        all_ok = False

    print()
    if all_ok:
        print(f"{OK} All checks passed\n")
    else:
        print(f"{ERR} Some checks failed — run: lk-autocorrect install\n")
        sys.exit(1)

# Help
def help():
    ps_note = "  . $PROFILE                  Reload PowerShell after install\n" if is_windows() else ""
    print(f"""
{bold('lk-autocorrect')} v{VERSION}

  Fuzzy autocorrect for mistyped shell commands.

{bold('Usage:')}

  {bold('lk-autocorrect')}              Install
  {bold('lk-autocorrect install')}      Install
  {bold('lk-autocorrect uninstall')}    Remove from system
  {bold('lk-autocorrect status')}       Show installation status
  {bold('lk-autocorrect verify')}       Check file integrity
  {bold('lk-autocorrect help')}         Show this help

{bold('After install, use these in your shell:')}

  ac-add <cmd>      Add a command to the store
  ac-remove <cmd>   Remove a command from the store
  ac-list           List all commands in the store
  ac-test <typo>    Preview what a typo corrects to
  ac-help           Show in-shell help
{ps_note}
{bold('Repo:')} https://github.com/OladipupoGomez/lk-autocorrect
""")

# Entry point
def main():
    # Python version warning
    _PY = sys.version_info
    if _PY < (3, 11):
        print(f"{yellow('[lk-autocorrect]')} Python {_PY.major}.{_PY.minor} is end-of-life or approaching it. lk-autocorrect works but consider upgrading.")

    args = sys.argv[1:]
    cmd  = args[0] if args else None

    dispatch = {
        None:             install,
        "install":        install,
        "uninstall":      uninstall,
        "status":         status,
        "verify":         verify,
        "help":           help,
        "--help":         help,
        "-h":             help,
        "--version":      lambda: print(VERSION),
        "-v":             lambda: print(VERSION),
        "--auto-install": auto_install,
    }

    fn = dispatch.get(cmd)
    if fn:
        fn()
    else:
        print(f"{ERR} Unknown command: {cmd}")
        help()
        sys.exit(1)

if __name__ == "__main__":
    main()