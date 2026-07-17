#!/usr/bin/env python3
"""
lk-autocorrect matcher
Damerau-Levenshtein distance — counts transpositions as 1 edit
e.g. "gti" -> "git" = 1, not 2
"""
import sys
import os
import re

# Input validation
if len(sys.argv) != 4:
    sys.exit(1)

typo      = sys.argv[1][:50].strip()
store     = sys.argv[2]
try:
    threshold = min(abs(int(sys.argv[3])), 5)
except ValueError:
    sys.exit(1)

# block empty typos
if not typo:
    sys.exit(0)

# block shell injection characters
if re.search(r'[;&|`$(){}<>\\\'"!]', typo):
    sys.exit(0)

# validate store path is inside expected config directory
expected_dir = os.path.abspath(os.path.expanduser("~/.config/lk-autocorrect"))
store_path   = os.path.abspath(store)
if not store_path.startswith(expected_dir):
    sys.exit(1)

# validate store file exists and is not a symlink
if not os.path.isfile(store) or os.path.islink(store):
    sys.exit(1)

# cap store file size at 1MB
if os.path.getsize(store) > 1_000_000:
    sys.exit(1)

# Damerau-Levenshtein
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
            # transposition — gti->git = 1 not 2
            if i > 1 and j > 1 and s[i-1] == t[j-2] and s[i-2] == t[j-1]:
                dp[i][j] = min(dp[i][j], dp[i-2][j-2] + cost)

    return dp[m][n]

# Match against store
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

# scale the allowed distance for longer words — see autocorrect.sh
# for the full idea behind this
effective_threshold = threshold
if len(typo) >= 8:
    effective_threshold = threshold + 1

if best_dist <= effective_threshold and best_cmd:
    if not re.search(r'[;&|`$(){}<>!]', best_cmd):
        print("{}|||{}".format(best_cmd, best_dist))
