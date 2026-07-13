# Settings
$env:AUTOCORRECT_DIR    = if ($env:AUTOCORRECT_DIR) { $env:AUTOCORRECT_DIR } else { "$env:USERPROFILE\.config\lk-autocorrect" }
$env:AUTOCORRECT_STORE  = "$env:AUTOCORRECT_DIR\commands.txt"
$env:AUTOCORRECT_THRESHOLD = if ($env:AUTOCORRECT_THRESHOLD) { $env:AUTOCORRECT_THRESHOLD } else { "2" }
$env:AUTOCORRECT_AUTO   = if ($env:AUTOCORRECT_AUTO) { $env:AUTOCORRECT_AUTO } else { "false" }
$_AC_MATCHER            = "$env:AUTOCORRECT_DIR\matcher.py"

# Find Python
function _ac_find_python {
    foreach ($cmd in @("python", "python3", "py")) {
        try {
            $ver = & $cmd --version 2>&1
            if ($ver -match "Python 3\.") {
                return $cmd
            }
        } catch {}
    }
    return $null
}

$_AC_PYTHON = _ac_find_python

# Colors
function _ac_yellow($s) { Write-Host "[lk-autocorrect] " -ForegroundColor Yellow -NoNewline; $s }
function _ac_green($s)  { Write-Host "[lk-autocorrect] " -ForegroundColor Green  -NoNewline; $s }
function _ac_red($s)    { Write-Host "[lk-autocorrect] " -ForegroundColor Red    -NoNewline; $s }

# Bootstrap store and matcher
function _ac_setup {
    if (-not (Test-Path $env:AUTOCORRECT_DIR)) {
        New-Item -ItemType Directory -Path $env:AUTOCORRECT_DIR -Force | Out-Null
    }

    # write matcher.py
    if (-not (Test-Path $_AC_MATCHER)) {
        $matcherContent = @'
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
# Windows path support
win_expected = os.path.abspath(os.path.join(os.environ.get("USERPROFILE", ""), ".config", "lk-autocorrect"))
store_abs = os.path.abspath(store)
if not (store_abs.startswith(expected_dir) or store_abs.startswith(win_expected)):
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
'@
        Set-Content -Path $_AC_MATCHER -Value $matcherContent -Encoding UTF8
    }

    # write command store
    if (-not (Test-Path $env:AUTOCORRECT_STORE)) {
        $storeContent = @'
# File system
ls
dir
cd
pwd
cp
mv
rm
mkdir
rmdir
cat
more
find
stat

# Text processing
grep
findstr
sort
diff

# Network
curl
wget
ping
traceroute
nslookup
ipconfig
netstat

# Archives
tar
zip
unzip

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
winget
choco
scoop

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

# IaC
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

# PowerShell specific
Get-Help
Get-Command
Get-Process
Get-Service
Set-Location
Get-ChildItem
Remove-Item
Copy-Item
Move-Item
Invoke-WebRequest
'@
        Set-Content -Path $env:AUTOCORRECT_STORE -Value $storeContent -Encoding UTF8
    }
}

# Run setup
_ac_setup

if (-not $_AC_PYTHON) {
    Write-Host "[lk-autocorrect] " -ForegroundColor Red -NoNewline
    Write-Host "Python 3 not found. Install from https://python.org"
    return
}

# Core handler
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param($name, $eventArgs)

    # skip empty, paths, flags
    if (-not $name) { return }
    if ($name.StartsWith("-") -or $name.StartsWith("/") -or $name.StartsWith(".")) { return }

    # block injection characters
    if ($name -match '[;&|`$(){}<>"'']') { return }

    # cap length
    if ($name.Length -gt 50) { return }

    # run matcher
    $result = & $_AC_PYTHON $_AC_MATCHER $name $env:AUTOCORRECT_STORE $env:AUTOCORRECT_THRESHOLD 2>$null

    if (-not $result) {
        $eventArgs.StopSearch = $false
        return
    }

    $parts      = $result -split "\|\|\|"
    $suggestion = $parts[0]
    $dist       = $parts[1]

    # skip distance 0 — exact match means not installed
    if ($dist -eq "0") {
        $eventArgs.StopSearch = $false
        return
    }

    Write-Host "[lk-autocorrect] " -ForegroundColor Yellow -NoNewline
    Write-Host "Did you mean: " -NoNewline
    Write-Host $suggestion -ForegroundColor Cyan -NoNewline
    Write-Host "?"

    if ($env:AUTOCORRECT_AUTO -eq "true") {
        Write-Host "[lk-autocorrect] Running..." -ForegroundColor Yellow
        Invoke-Expression $suggestion
    } else {
        Write-Host "[lk-autocorrect] " -ForegroundColor Yellow -NoNewline
        $answer = Read-Host "Run it? [y/N]"
        if ($answer -match "^[Yy]$") {
            Invoke-Expression $suggestion
        }
    }

    $eventArgs.StopSearch = $true
}

# Public functions

function ac-add {
    param([string]$cmd)
    if (-not $cmd) { Write-Host "Usage: ac-add <command>"; return }
    if ($cmd -match '[;&|`$(){}<>"'']') {
        Write-Host "[lk-autocorrect] Invalid characters in command" -ForegroundColor Red
        return
    }
    if ($cmd.Length -gt 50) {
        Write-Host "[lk-autocorrect] Command too long (max 50 chars)" -ForegroundColor Red
        return
    }
    $existing = Get-Content $env:AUTOCORRECT_STORE | Where-Object { $_ -eq $cmd }
    if ($existing) {
        Write-Host "[lk-autocorrect] '$cmd' already in store" -ForegroundColor Yellow
        return
    }
    Add-Content -Path $env:AUTOCORRECT_STORE -Value $cmd
    Write-Host "[lk-autocorrect] Added '$cmd'" -ForegroundColor Green
}

function ac-remove {
    param([string]$cmd)
    if (-not $cmd) { Write-Host "Usage: ac-remove <command>"; return }
    $lines = Get-Content $env:AUTOCORRECT_STORE | Where-Object { $_ -ne $cmd }
    Set-Content -Path $env:AUTOCORRECT_STORE -Value $lines
    Write-Host "[lk-autocorrect] Removed '$cmd'" -ForegroundColor Red
}

function ac-list {
    $commands = Get-Content $env:AUTOCORRECT_STORE | Where-Object { $_ -notmatch '^\s*#' -and $_ -ne "" }
    Write-Host "[lk-autocorrect] $($commands.Count) commands in store:" -ForegroundColor Yellow
    Write-Host ""
    $commands | Sort-Object | Format-Wide -AutoSize
}

function ac-test {
    param([string]$typo)
    if (-not $typo) { Write-Host "Usage: ac-test <typo>"; return }
    $result = & $_AC_PYTHON $_AC_MATCHER $typo $env:AUTOCORRECT_STORE $env:AUTOCORRECT_THRESHOLD 2>$null
    if (-not $result) {
        Write-Host "[lk-autocorrect] No match for '$typo' within threshold $env:AUTOCORRECT_THRESHOLD" -ForegroundColor Red
    } else {
        $parts = $result -split "\|\|\|"
        Write-Host "[lk-autocorrect] '$typo' -> '$($parts[0])' (distance: $($parts[1]))" -ForegroundColor Green
    }
}

function ac-help {
    Write-Host ""
    Write-Host "  lk-autocorrect - fuzzy CLI command correction"
    Write-Host ""
    Write-Host "  Commands:"
    Write-Host "    ac-add [cmd]      Add a command to the store"
    Write-Host "    ac-remove [cmd]   Remove a command from the store"
    Write-Host "    ac-list           List all commands in the store"
    Write-Host "    ac-test [typo]    Preview what a typo would match"
    Write-Host "    ac-help           Show this help"
    Write-Host ""
    Write-Host "  Config (set in your PowerShell profile):"
    Write-Host "    " + '$env:AUTOCORRECT_THRESHOLD = "2"'
    Write-Host "    " + '$env:AUTOCORRECT_AUTO = "true"'
    Write-Host ""
}
