#!/usr/bin/env python3
"""
lk-autocorrect — fuzzy CLI command correction
https://github.com/OladipupoGomez/lk-autocorrect
"""

import os
import sys
import shutil
from pathlib import Path

# Constants
VERSION     = "1.2.0"
INSTALL_DIR = Path.home() / ".lk-autocorrect"
CONFIG_DIR  = Path.home() / ".config" / "lk-autocorrect"
MARKER      = "# lk-autocorrect"
SOURCE_LINE = f'source "{INSTALL_DIR}/autocorrect.sh"'
PACKAGE_DIR = Path(__file__).parent

# Colors
def yellow(s): return f"\033[33m{s}\033[0m"
def green(s):  return f"\033[32m{s}\033[0m"
def red(s):    return f"\033[31m{s}\033[0m"
def bold(s):   return f"\033[1m{s}\033[0m"

TAG = yellow("[lk-autocorrect]")
OK  = green("[lk-autocorrect]")
ERR = red("[lk-autocorrect]")

# OS guard
if sys.platform == "win32":
    print(f"{ERR} Windows is not supported. Use WSL or Git Bash.")
    sys.exit(1)

# Python version warning
# EOL versions: 3.8 (2024-10), 3.9 (2025-10)
_PY = sys.version_info
if _PY < (3, 10):
    print(
        f"{yellow('[lk-autocorrect]')} Python {_PY.major}.{_PY.minor} is end-of-life "
        f"or approaching it. lk-autocorrect works fine but consider upgrading."
    )

# Shell detection
def detect_shell():
    shell = os.environ.get("SHELL", "")
    home  = Path.home()
    if "zsh" in shell:
        return "zsh", home / ".zshrc"
    elif "bash" in shell:
        rc = home / ".bashrc"
        return "bash", rc if rc.exists() else home / ".bash_profile"
    return "unknown", home / ".profile"

# RC file helpers
def is_injected(rc: Path) -> bool:
    if not rc.exists():
        return False
    return MARKER in rc.read_text()

def inject_rc(rc: Path):
    # validate rc file is in home directory — block path traversal
    try:
        rc.resolve().relative_to(Path.home())
    except ValueError:
        print(f"{ERR} Refusing to write to {rc} — outside home directory")
        sys.exit(1)
    # validate it's actually a shell rc file
    valid_names = {".bashrc", ".bash_profile", ".zshrc", ".profile"}
    if rc.name not in valid_names:
        print(f"{ERR} Refusing to write to {rc} — not a known shell RC file")
        sys.exit(1)
    with rc.open("a") as f:
        f.write(f"\n{MARKER}\n{SOURCE_LINE}\n")

def remove_from_rc(rc: Path):
    if not rc.exists():
        return
    lines = rc.read_text().splitlines()
    cleaned = [
        line for line in lines
        if line.strip() != MARKER and line.strip() != SOURCE_LINE
    ]
    rc.write_text("\n".join(cleaned) + "\n")

# Install
def install():
    # verify source files exist before copying
    for f in ["autocorrect.sh", "matcher.py"]:
        if not (PACKAGE_DIR / f).exists():
            print(f"{ERR} Missing package file: {f}")
            sys.exit(1)
    shell_name, rc = detect_shell()

    print(f"\n{bold('lk-autocorrect')} v{VERSION}\n")
    print(f"{TAG} Shell:       {bold(shell_name)}")
    print(f"{TAG} RC file:     {bold(str(rc))}")
    print(f"{TAG} Install dir: {bold(str(INSTALL_DIR))}\n")

    # create install dir and copy files
    INSTALL_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy(PACKAGE_DIR / "autocorrect.sh", INSTALL_DIR / "autocorrect.sh")
    shutil.copy(PACKAGE_DIR / "matcher.py",     INSTALL_DIR / "matcher.py")
    (INSTALL_DIR / "autocorrect.sh").chmod(0o755)
    (INSTALL_DIR / "matcher.py").chmod(0o600)
    write_checksums()

    # inject source line
    if is_injected(rc):
        print(f"{TAG} Already in {rc} — skipping")
    else:
        inject_rc(rc)
        print(f"{OK} Added to {rc}")

    print(f"\n{OK} {bold('Done!')} Reload your shell:\n")
    print(f"    {bold(f'source {rc}')}\n")
    print(f"  Then try: {bold('gti status')}\n")

# Checksum helpers
def sha256_file(path: Path) -> str:
    import hashlib
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()

def write_checksums():
    """Write checksums of installed files for integrity verification."""
    checksums = {
        "matcher.py":     sha256_file(INSTALL_DIR / "matcher.py"),
        "autocorrect.sh": sha256_file(INSTALL_DIR / "autocorrect.sh"),
    }
    checksum_file = INSTALL_DIR / ".checksums"
    checksum_file.write_text(
        "\n".join(f"{v}  {k}" for k, v in checksums.items())
    )
    checksum_file.chmod(0o600)

def verify_checksums() -> bool:
    """Return True if installed files match their recorded checksums."""
    checksum_file = INSTALL_DIR / ".checksums"
    if not checksum_file.exists():
        return True  # first run, no checksums yet
    for line in checksum_file.read_text().splitlines():
        if not line.strip():
            continue
        expected_hash, filename = line.split("  ", 1)
        filepath = INSTALL_DIR / filename
        if not filepath.exists():
            return False
        if sha256_file(filepath) != expected_hash:
            return False
    return True

# Auto install (called by pip post-install)
def auto_install():
    INSTALL_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy(PACKAGE_DIR / "autocorrect.sh", INSTALL_DIR / "autocorrect.sh")
    shutil.copy(PACKAGE_DIR / "matcher.py",     INSTALL_DIR / "matcher.py")
    (INSTALL_DIR / "autocorrect.sh").chmod(0o755)
    (INSTALL_DIR / "matcher.py").chmod(0o600)

    # write checksums for tamper detection
    write_checksums()

    _, rc = detect_shell()
    if not is_injected(rc):
        inject_rc(rc)

    shell_name, rc = detect_shell()
    print(f"\n{OK} lk-autocorrect installed for {shell_name}!")
    print(f"{TAG} Run {bold(f'source {rc}')} or open a new terminal.\n")

# Uninstall
def uninstall():
    print(f"\n{bold('lk-autocorrect')} — uninstall\n")

    rc_files = [
        Path.home() / ".bashrc",
        Path.home() / ".bash_profile",
        Path.home() / ".zshrc",
        Path.home() / ".profile",
    ]
    for rc in rc_files:
        if is_injected(rc):
            remove_from_rc(rc)
            print(f"{OK} Removed from {rc}")

    answer = input(f"\nKeep your command store at ~/.config/lk-autocorrect? [Y/n] ")
    if answer.strip().lower() == "n":
        shutil.rmtree(CONFIG_DIR, ignore_errors=True)
        print(f"{TAG} Removed config directory")

    shutil.rmtree(INSTALL_DIR, ignore_errors=True)
    print(f"\n{OK} Uninstalled. Restart your shell.\n")

# Status
def status():
    shell_name, rc = detect_shell()
    installed = (INSTALL_DIR / "autocorrect.sh").exists()
    injected  = is_injected(rc)
    intact    = verify_checksums()

    print(f"\n{bold('lk-autocorrect')} v{VERSION} — status\n")
    print(f"  Shell:     {bold(shell_name)}")
    print(f"  RC file:   {bold(str(rc))}")
    print(f"  Script:    {green('✓ installed') if installed else red('✗ not installed')}")
    print(f"  Sourced:   {green('✓ yes') if injected else red('✗ no')}")
    print(f"  Integrity: {green('✓ ok') if intact else red('✗ files modified — run: lk-autocorrect install')}")
    print()

# Help
def help():
    print(f"""
{bold('lk-autocorrect')} v{VERSION}

  Fuzzy autocorrect for mistyped shell commands.

{bold('Usage:')}

  {bold('lk-autocorrect')}              Install
  {bold('lk-autocorrect install')}      Install
  {bold('lk-autocorrect uninstall')}    Remove from system
  {bold('lk-autocorrect status')}       Show installation status
  {bold('lk-autocorrect help')}         Show this help

{bold('After install, use these in your shell:')}

  ac-add <cmd>      Add a command to the store
  ac-remove <cmd>   Remove a command from the store
  ac-list           List all commands in the store
  ac-test <typo>    Preview what a typo corrects to
  ac-help           Show in-shell help

{bold('Repo:')} https://github.com/OladipupoGomez/lk-autocorrect
""")

# Verify install integrity 
def verify():
    import hashlib

    print(f"\n{bold('lk-autocorrect')} v{VERSION} — integrity check\n")

    files_to_check = {
        INSTALL_DIR / "autocorrect.sh": "rwxr-xr-x",
        INSTALL_DIR / "matcher.py":     "rw-r--r--",
    }

    all_ok = True
    for path, expected_perms in files_to_check.items():
        if not path.exists():
            print(f"  {red('✗')} {path.name} — missing")
            all_ok = False
            continue

        # check it's a real file not a symlink
        if path.is_symlink():
            print(f"  {red('✗')} {path.name} — symlink detected (possible tampering)")
            all_ok = False
            continue

        # check permissions
        import stat
        mode = oct(stat.S_IMODE(path.stat().st_mode))
        print(f"  {green('✓')} {path.name} — exists (perms: {mode})")

        # print sha256 so user can verify against GitHub release
        sha = hashlib.sha256(path.read_bytes()).hexdigest()
        print(f"    sha256: {sha}")

    _, rc = detect_shell()
    if is_injected(rc):
        print(f"  {green('✓')} {rc.name} — source line present")
    else:
        print(f"  {red('✗')} {rc.name} — source line missing, run: lk-autocorrect install")
        all_ok = False

    print()
    if all_ok:
        print(f"{OK} All checks passed\n")
    else:
        print(f"{ERR} Some checks failed — run: lk-autocorrect install\n")
        sys.exit(1)

# Entry point
def main():
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