#!/usr/bin/env zsh
AUTOCORRECT_DIR="${AUTOCORRECT_DIR:-${HOME}/.config/lk-autocorrect}"
AUTOCORRECT_STORE="${AUTOCORRECT_DIR}/commands.txt"
AUTOCORRECT_THRESHOLD="${AUTOCORRECT_THRESHOLD:-2}"
AUTOCORRECT_AUTO="${AUTOCORRECT_AUTO:-false}"
AUTOCORRECT_COLOR="${AUTOCORRECT_COLOR:-true}"

# Colors
_ac_yellow() { $AUTOCORRECT_COLOR && printf '\033[33m%s\033[0m' "$*" || printf '%s' "$*"; }
_ac_bold()   { $AUTOCORRECT_COLOR && printf '\033[1m%s\033[0m'  "$*" || printf '%s' "$*"; }
_ac_green()  { $AUTOCORRECT_COLOR && printf '\033[32m%s\033[0m' "$*" || printf '%s' "$*"; }
_ac_red()    { $AUTOCORRECT_COLOR && printf '\033[31m%s\033[0m' "$*" || printf '%s' "$*"; }

# Python matcher script path
_AC_MATCHER="${AUTOCORRECT_DIR}/matcher.py"

# Write matcher.py and command store on first run
_ac_setup() {
  mkdir -p "${AUTOCORRECT_DIR}"

  # Write the Python matcher
  cat > "${_AC_MATCHER}" << 'PYEOF'
import sys
import os
import re

if len(sys.argv) != 4:
    sys.exit(1)

typo      = sys.argv[1][:50].strip()
store     = sys.argv[2]
try:
    threshold = min(abs(int(sys.argv[3])), 5)
except ValueError:
    sys.exit(1)

if not typo:
    sys.exit(0)

if re.search(r'[;&|`$(){}<>\\\'"!]', typo):
    sys.exit(0)

expected_dir = os.path.abspath(os.path.expanduser("~/.config/lk-autocorrect"))
if not os.path.abspath(store).startswith(expected_dir):
    sys.exit(1)

if not os.path.isfile(store) or os.path.islink(store):
    sys.exit(1)

if os.path.getsize(store) > 1_000_000:
    sys.exit(1)

def levenshtein(s, t):
    m, n = len(s), len(t)
    if s == t: return 0
    if not s: return n
    if not t: return m
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1): dp[i][0] = i
    for j in range(n + 1): dp[0][j] = j
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            cost = 0 if s[i-1] == t[j-1] else 1
            dp[i][j] = min(
                dp[i-1][j] + 1,
                dp[i][j-1] + 1,
                dp[i-1][j-1] + cost
            )
            if i > 1 and j > 1 and s[i-1] == t[j-2] and s[i-2] == t[j-1]:
                dp[i][j] = min(dp[i][j], dp[i-2][j-2] + cost)
    return dp[m][n]

best_cmd  = ""
best_dist = 9999

try:
    with open(store, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if re.search(r'[;&|`$(){}<>!]', line):
                continue
            if len(line) > 100:
                continue
            first_word = line.split()[0]
            d = levenshtein(typo, first_word)
            if d < best_dist:
                best_dist = d
                best_cmd  = line
except (IOError, OSError, PermissionError):
    sys.exit(1)

if best_dist <= threshold and best_cmd:
    if not re.search(r'[;&|`$(){}<>!]', best_cmd):
        print("{}|||{}".format(best_cmd, best_dist))
PYEOF

  # Write the command store with restricted permissions
  cat > "${AUTOCORRECT_STORE}" << 'STOREEOF'
# File system
ls
ll
la
cd
pwd
cp
mv
rm
ln
stat
file
mkdir
rmdir
touch
cat
less
more
head
tail
find

# Text processing
grep
awk
sed
cut
sort
uniq
wc
tr
diff
patch
echo
printf
tee
xargs

# Network & file transfer
curl
wget
ssh
scp
rsync
ping
traceroute
netstat
ss
ip
ifconfig
nmap
dig
nslookup

# Archives & compression
tar
zip
unzip
gzip
gunzip

# Permissions & users
chmod
chown
chgrp
umask
sudo
whoami
id

# Process management
ps
top
htop
kill
pkill
killall
jobs
bg
fg
nohup

# System info
df
du
free
uname
uptime
hostname

# Shell utilities
export
source
alias
unalias
history
which
whereis
type
cron
crontab

# Editors
nano
vim
vi
emacs
code
nvim

# Build & compile
make
cmake
gcc

# Git
git
git add
git commit
git push
git pull
git clone
git status
git log
git diff
git branch
git checkout
git merge
git rebase
git stash
git fetch
git reset
git tag
git remote
git init

# Python
python
python3
pip
pip3

# Node & JavaScript
node
npm
npx
yarn
pnpm

# Package managers
apt
apt-get
dpkg
yum
dnf
rpm
brew
pacman
snap

# System services
systemctl
journalctl
service

# Docker
docker
docker-compose

# Kubernetes
kubectl
kubectl get
kubectl apply
kubectl delete
kubectl describe
kubectl logs
kubectl exec
kubectl rollout
kubectl scale
kubectl create
kubectl edit
kubectl config
kubectl cluster-info
helm
minikube

# Terraform
terraform
terraform init
terraform plan
terraform apply

# IaC & config management
ansible
vagrant

# Databases
mysql
psql
sqlite3
redis-cli
mongosh

# AWS CLI
aws
aws s3
aws s3 cp
aws s3 ls
aws s3 sync
aws ec2
aws iam
aws lambda
aws cloudformation
aws ecr
aws eks
aws rds

# Azure CLI
az
az vm
az aks
az storage
az login
az group
az acr
az webapp
az functionapp
az network
az keyvault
STOREEOF

  # restrict permissions — only owner can read/write
  chmod 600 "${AUTOCORRECT_STORE}"
  chmod 600 "${_AC_MATCHER}"
}

# Run setup if either file is missing
if [[ ! -f "${_AC_MATCHER}" || ! -f "${AUTOCORRECT_STORE}" ]]; then
  _ac_setup
fi

# Guard against double-sourcing (after setup runs)
[[ -n "$_LK_AUTOCORRECT_LOADED" ]] && return 0
_LK_AUTOCORRECT_LOADED=1

# Core handler
_ac_handle() {
  local typo="$1"
  shift
  local args="$*"

  # prevent re-entry loop when running corrected command
  [[ -n "$_AC_RUNNING" ]] && return 127

  [[ -z "$typo" ]] && return 1
  [[ "$typo" == /* || "$typo" == ./* || "$typo" == -* ]] && return 1

  # if the command actually exists anywhere on PATH, don't intercept it
  if command -v "$typo" &>/dev/null || type "$typo" &>/dev/null || hash "$typo" &>/dev/null; then
    return 127
  fi

  # block shell injection characters — case works in bash 3.2 and zsh
  case "$typo" in
    *[';&|`$(){}><\\"']*)  return 1 ;;
  esac

  # cap typo length to 50 chars
  if (( ${#typo} > 50 )); then
    return 1
  fi

  local result
  result=$(python3 "${_AC_MATCHER}" "${typo}" "${AUTOCORRECT_STORE}" "${AUTOCORRECT_THRESHOLD}" 2>/dev/null)
  [[ -z "$result" ]] && return 127

  local suggestion="${result%|||*}"
  local dist="${result##*|||}"

  # distance 0 = exact match but not installed — don't suggest
  [[ "$dist" == "0" ]] && return 127

  # build corrected command
  local corrected
  if [[ "$suggestion" != *" "* && -n "$args" ]]; then
    corrected="${suggestion} ${args}"
  else
    corrected="$suggestion"
  fi

  # block injection in suggestion
  case "$corrected" in
    *[';&|`$(){}><\"']*)
      return 127 ;;
  esac

  printf "%s Did you mean: %s?\n" "$(_ac_yellow "[lk-autocorrect]")" "$(_ac_bold "$corrected")"

  if [[ "$AUTOCORRECT_AUTO" == "true" ]]; then
    printf "%s Running...\n" "$(_ac_yellow "[lk-autocorrect]")"
    _AC_RUNNING=1
    eval $corrected
    local _ac_exit=$?
    unset _AC_RUNNING
    return $_ac_exit
  else
    printf "%s Run it? [y/N] " "$(_ac_yellow "[lk-autocorrect]")"
    local answer
    read -r answer </dev/tty
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      _AC_RUNNING=1
      eval $corrected
      local _ac_exit=$?
      unset _AC_RUNNING
      return $_ac_exit
    fi
    return 1
  fi
}

# ── Shell hooks ───────────────────────────────────────
if [[ -n "$ZSH_VERSION" ]]; then
  command_not_found_handler() { _ac_handle "$@"; }
elif [[ -n "$BASH_VERSION" ]]; then
  if (( BASH_VERSINFO[0] >= 4 )); then
    command_not_found_handle() { _ac_handle "$@"; }
  else
    lk() {
      local cmd="$1"; shift
      if command -v "$cmd" &>/dev/null; then
        "$cmd" "$@"
      else
        _ac_handle "$cmd" "$@"
      fi
    }
    printf "\033[33m[lk-autocorrect]\033[0m bash 3.2 detected — automatic correction unavailable.\n"
    printf "\033[33m[lk-autocorrect]\033[0m Use: \033[1mlk <command>\033[0m e.g. \033[1mlk gti status\033[0m\n"
    printf "\033[33m[lk-autocorrect]\033[0m Or switch to zsh: \033[1mchsh -s /bin/zsh\033[0m\n"
  fi
fi

# Public commands

ac-add() {
  [[ -z "$1" ]] && echo "Usage: ac-add <command>" && return 1
  case "$1" in
    *[';&|`$(){}><\"']*)
      printf "%s Invalid characters in command\n" "$(_ac_red "[lk-autocorrect]")"
      return 1 ;;
  esac
  if (( ${#1} > 50 )); then
    printf "%s Command too long (max 50 chars)\n" "$(_ac_red "[lk-autocorrect]")"
    return 1
  fi
  if grep -qxF "$1" "${AUTOCORRECT_STORE}"; then
    printf "%s '%s' already in store\n" "$(_ac_yellow "[lk-autocorrect]")" "$1"
    return 0
  fi
  echo "$1" >> "${AUTOCORRECT_STORE}"
  printf "%s Added '%s'\n" "$(_ac_green "[lk-autocorrect]")" "$1"
}

ac-remove() {
  [[ -z "$1" ]] && echo "Usage: ac-remove <command>" && return 1
  local tmp; tmp=$(mktemp)
  grep -vxF "$1" "${AUTOCORRECT_STORE}" > "$tmp" && mv "$tmp" "${AUTOCORRECT_STORE}"
  printf "%s Removed '%s'\n" "$(_ac_red "[lk-autocorrect]")" "$1"
}

ac-list() {
  local count
  count=$(grep -cvE '^\s*#|^\s*$' "${AUTOCORRECT_STORE}" 2>/dev/null || echo 0)
  printf "%s %d commands in store:\n\n" "$(_ac_yellow "[lk-autocorrect]")" "$count"
  grep -vE '^\s*#|^\s*$' "${AUTOCORRECT_STORE}" | sort | column
}

ac-test() {
  [[ -z "$1" ]] && echo "Usage: ac-test <typo>" && return 1
  local result
  result=$(python3 "${_AC_MATCHER}" "$1" "${AUTOCORRECT_STORE}" "${AUTOCORRECT_THRESHOLD}" 2>/dev/null)
  if [[ -z "$result" ]]; then
    printf "%s No match for '%s' within threshold %d\n" \
      "$(_ac_red "[lk-autocorrect]")" "$1" "$AUTOCORRECT_THRESHOLD"
  else
    local suggestion="${result%|||*}"
    local dist="${result##*|||}"
    printf "%s '%s' → '%s' (distance: %d)\n" \
      "$(_ac_green "[lk-autocorrect]")" "$1" "$suggestion" "$dist"
  fi
}

ac-help() {
  cat << 'EOF'

  lk-autocorrect — fuzzy CLI command correction

  Commands:
    ac-add <cmd>      Add a command to the store
    ac-remove <cmd>   Remove a command from the store
    ac-list           List all commands in the store
    ac-test <typo>    Preview what a typo would match
    ac-help           Show this help

  Config (set before sourcing):
    AUTOCORRECT_THRESHOLD=2    Max edit distance (default: 2)
    AUTOCORRECT_AUTO=false     Auto-run without asking (default: false)
    AUTOCORRECT_COLOR=true     Colorized output (default: true)

EOF
}
