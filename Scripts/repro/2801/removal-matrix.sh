#!/bin/bash
# Removal matrix for Scripts/census-compiled-out-validation.py, per
# okf/policies/prove-the-test-fails.md: remove each rule in turn and confirm the self-test loses at
# least one case. A rule no case notices is decorative, and three of this script's were, on the
# first run: the fixtures for comment stripping, the preprocessor skip and the inherited-live
# classification restated the logic instead of driving it, and were rewritten to call file_sites and
# derive_inherited directly.
#
# Restores from a copy rather than from git, so it is safe on an uncommitted script and cannot touch
# anything else in the worktree.
#
#   bash Scripts/repro/2801/removal-matrix.sh
#
# Result, 2026-09-29, against the version this landed with: baseline 28 cases, and every one of the
# ten removals below drops at least one.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
script="$repo/Scripts/census-compiled-out-validation.py"
backup="$(mktemp -t census-2801)"
cp "$script" "$backup"
trap 'cp "$backup" "$script"; rm -f "$backup"' EXIT

baseline=$(python3 "$script" --self-test 2>&1 | grep -c '^\[PASS\]')
echo "baseline PASS count: $baseline"

try_one () {
  local label="$1"
  shift
  cp "$backup" "$script"
  python3 - "$script" "$@" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
assert old in text, "pattern not found, the script has moved on: %r" % old
open(path, "w").write(text.replace(old, new, 1))
PY
  local out pass fail
  out=$(python3 "$script" --self-test 2>&1)
  pass=$(printf '%s' "$out" | grep -c '^\[PASS\]')
  fail=$(printf '%s' "$out" | grep '^\[FAIL\]' | sed 's/ -- .*//' | tr '\n' ' ')
  echo "$label: PASS $pass (was $baseline)  FAILED: ${fail:-NONE, the rule is decorative}"
  cp "$backup" "$script"
}

try_one "drop-literal-argument-exemption" \
  'if THROWING.NUMERIC_ARG_RE.match(args):
            continue' 'if False:
            continue'

try_one "drop-preprocessor-directive-skip" \
  'if DIRECTIVE_RE.match(text[line_start:match.start() + 1]):' 'if False:'

try_one "drop-comment-stripping" \
  'return THROWING.strip_noise(text)' 'return text'

try_one "drop-package-distinction" \
  'return "inert" if package in packages else "unexamined"' 'return "inert"'

try_one "drop-inherited-live-classification" \
  'if "inherited-live" in entry:
        return "live-inherited"' 'if False:
        return "live-inherited"'

try_one "drop-Status-from-the-explicit-guard" \
  '(?:IsDone|Status)' '(?:IsDone)'

try_one "drop-the-count-guard-bucket" \
  'COUNT_GUARD_RE = r"\s*(?:\.|->)\s*(?:Nb\w+|IsEmpty|Extrema)\s*\("' \
  'COUNT_GUARD_RE = r"\s*(?:\.|->)\s*(?:ZZZNeverMatches)\s*\("'

try_one "drop-the-member-body-attribution" \
  'return best[1] if best else fallback' 'return fallback'

try_one "drop-every-plausibility-assertion" \
  'problems = []' 'problems = []
    return problems'

# The rule that made 89 sites read as fabricated: a construction nested inside an earlier match's
# parentheses must still be seen. This restores the skipping that check-throwing-calls' regex does.
try_one "skip-constructions-nested-in-an-earlier-one" \
  '    sites = []
    for match in VOCABULARY_RE.finditer(body):
        open_paren = body.index("(", match.end() - 1)' \
  '    sites = []
    cursor = -1
    for match in VOCABULARY_RE.finditer(body):
        if match.start() < cursor:
            continue
        open_paren = body.index("(", match.end() - 1)
        cursor = body.find(";", open_paren)'

echo "restored; final PASS count: $(python3 "$script" --self-test 2>&1 | grep -c '^\[PASS\]')"
