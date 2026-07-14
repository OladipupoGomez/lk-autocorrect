# Settings
if (-not $env:AUTOCORRECT_DIR)    { $env:AUTOCORRECT_DIR    = "$env:USERPROFILE\.config\lk-autocorrect" }
if (-not $env:AUTOCORRECT_STORE)  { $env:AUTOCORRECT_STORE  = "$env:AUTOCORRECT_DIR\commands.txt" }
if (-not $env:AUTOCORRECT_THRESHOLD) { $env:AUTOCORRECT_THRESHOLD = "2" }
if (-not $env:AUTOCORRECT_AUTO)   { $env:AUTOCORRECT_AUTO   = "false" }

$_AC_MATCHER = "$env:AUTOCORRECT_DIR\matcher.py"

# Colors
function _ac_yellow($msg) {
    Write-Host "[lk-autocorrect] " -ForegroundColor Yellow -NoNewline
    Write-Host $msg -ForegroundColor Yellow
}
function _ac_green($msg) {
    Write-Host "[lk-autocorrect] " -ForegroundColor Green -NoNewline
    Write-Host $msg -ForegroundColor Green
}
function _ac_red($msg) {
    Write-Host "[lk-autocorrect] " -ForegroundColor Red -NoNewline
    Write-Host $msg -ForegroundColor Red
}
# Prints the tag in yellow, then prompts on the same line and returns the answer
function _ac_yellow_prompt($msg) {
    Write-Host "[lk-autocorrect] " -ForegroundColor Yellow -NoNewline
    return Read-Host $msg
}

# Find Python
function _ac_find_python {
    foreach ($cmd in @("python", "python3", "py")) {
        try {
            $ver = & $cmd --version 2>&1
            if ($ver -match "Python 3\.") { return $cmd }
        } catch {}
    }
    return $null
}

$_AC_PYTHON = _ac_find_python

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

expected_unix = os.path.abspath(os.path.expanduser("~/.config/lk-autocorrect"))
expected_win  = os.path.abspath(os.path.join(os.environ.get("USERPROFILE", ""), ".config", "lk-autocorrect"))
store_abs = os.path.abspath(store)
if not (store_abs.startswith(expected_unix) or store_abs.startswith(expected_win)):
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
            dp[i][j] = min(dp[i-1][j]+1, dp[i][j-1]+1, dp[i-1][j-1]+cost)
            if i > 1 and j > 1 and s[i-1] == t[j-2] and s[i-2] == t[j-1]:
                dp[i][j] = min(dp[i][j], dp[i-2][j-2]+cost)
    return dp[m][n]

best_cmd  = ""
best_dist = 9999

try:
    with open(store, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'): continue
            if re.search(r'[;&|`$(){}<>!]', line): continue
            if len(line) > 100: continue
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
    _ac_red "Python 3 not found. Install from https://python.org"
    return
}

# CommandNotFoundAction hook
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param($name, $eventArgs)

    # skip empty, paths, flags
    if (-not $name) { return }
    if ($name.StartsWith("-") -or $name.StartsWith("/") -or $name.StartsWith(".")) { return }
    if ($name -match '[;&|`$(){}<>"]') { return }
    if ($name.Length -gt 50) { return }

    # get the args PowerShell was going to pass to the missing command
    $invocationLine = (Get-PSCallStack | Select-Object -First 1).InvocationInfo.Line
    if (-not $invocationLine) { $invocationLine = $name }
    $trimmedLine = $invocationLine.Trim()
    $argTokens = @()
    if ($trimmedLine.Length -gt $name.Length) {
        $rest = $trimmedLine.Substring($name.Length).Trim()
        if ($rest) { $argTokens = $rest -split '\s+' }
    }

    # run matcher
    $result = & $_AC_PYTHON $_AC_MATCHER $name $env:AUTOCORRECT_STORE $env:AUTOCORRECT_THRESHOLD 2>$null
    if (-not $result) { return }

    $parts      = $result -split "\|\|\|"
    $suggestion = $parts[0]
    $dist       = $parts[1]
    if ($dist -eq "0") { return }

    $suggestionParts = $suggestion -split " "
    $suggestedCmd    = $suggestionParts[0]
    $suggestedArgs   = @()
    if ($suggestionParts.Count -gt 1) { $suggestedArgs = $suggestionParts[1..($suggestionParts.Count-1)] }

    $finalArgs  = $suggestedArgs + $argTokens
    $displayCmd = if ($finalArgs.Count -gt 0) { "$suggestedCmd $($finalArgs -join ' ')" } else { $suggestedCmd }

    # tag in yellow, "Did you mean:" in yellow, the command itself in cyan
    Write-Host "[lk-autocorrect] " -ForegroundColor Yellow -NoNewline
    Write-Host "Did you mean: " -ForegroundColor Yellow -NoNewline
    Write-Host $displayCmd -ForegroundColor Cyan -NoNewline
    Write-Host "?"

    $run = $false
    if ($env:AUTOCORRECT_AUTO -eq "true") {
        _ac_yellow "Running..."
        $run = $true
    } else {
        $answer = _ac_yellow_prompt "Run it? [y/N]"
        if ($answer -match "^[Yy]$") { $run = $true }
    }

    if ($run) {
        # this is the officially supported mechanism — assigning a
        # script block here tells PowerShell to run THIS instead of
        # throwing CommandNotFoundException.
        $capturedCmd  = $suggestedCmd
        $capturedArgs = $finalArgs
        $eventArgs.CommandScriptBlock = {
            & $capturedCmd @capturedArgs
        }.GetNewClosure()
    } else {
        # user declined — let PowerShell show its normal error
        return
    }
}

# Public functions

function ac-add {
    param([string]$cmd)
    if (-not $cmd) { Write-Host "Usage: ac-add [command]"; return }
    if ($cmd -match '[;&|`$(){}<>"'']') {
        _ac_red "Invalid characters in command"; return
    }
    if ($cmd.Length -gt 50) {
        _ac_red "Command too long (max 50 chars)"; return
    }
    $existing = Get-Content $env:AUTOCORRECT_STORE | Where-Object { $_ -eq $cmd }
    if ($existing) {
        _ac_yellow "'$cmd' already in store"; return
    }
    Add-Content -Path $env:AUTOCORRECT_STORE -Value $cmd
    _ac_green "Added '$cmd'"
}

function ac-remove {
    param([string]$cmd)
    if (-not $cmd) { Write-Host "Usage: ac-remove [command]"; return }
    $lines = Get-Content $env:AUTOCORRECT_STORE | Where-Object { $_ -ne $cmd }
    Set-Content -Path $env:AUTOCORRECT_STORE -Value $lines
    _ac_red "Removed '$cmd'"
}

function ac-list {
    $commands = Get-Content $env:AUTOCORRECT_STORE | Where-Object { $_ -notmatch '^\s*#' -and $_ -ne "" }
    _ac_yellow "$($commands.Count) commands in store:"
    Write-Host ""
    $commands | Sort-Object | Format-Wide -AutoSize
}

function ac-test {
    param([string]$typo)
    if (-not $typo) { Write-Host "Usage: ac-test [typo]"; return }
    $result = & $_AC_PYTHON $_AC_MATCHER $typo $env:AUTOCORRECT_STORE $env:AUTOCORRECT_THRESHOLD 2>$null
    if (-not $result) {
        _ac_red "No match for '$typo' within threshold $env:AUTOCORRECT_THRESHOLD"
    } else {
        $parts = $result -split "\|\|\|"
        _ac_green "'$typo' -> '$($parts[0])' (distance: $($parts[1]))"
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
