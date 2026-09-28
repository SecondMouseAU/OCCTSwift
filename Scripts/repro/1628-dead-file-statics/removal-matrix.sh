#!/bin/bash
# Removal matrix for census-dead-file-statics.py (#1628, okf/policies/prove-the-test-fails.md).
# Run from the repo root. Every line must read "load-bearing": a rule whose removal leaves the
# self-test green is a rule no fixture exercises, which is what this found on its first run for
# three of the ten (the `;` in STATIC_DECL's character class, brace_extent's prototype
# rejection, and body_digests' inclusion of live definitions).
# Break one rule at a time; the self-test must go red each time.
set -u
S=Scripts/census-dead-file-statics.py
B=$(mktemp -t census-dead-file-statics)
cp "$S" "$B"

try () {
  local label="$1"; shift
  python3 - "$@" <<'PY'
import sys, re
path = "Scripts/census-dead-file-statics.py"
old, new = sys.argv[1], sys.argv[2]
t = open(path).read()
assert t.count(old) == 1, (old, t.count(old))
open(path, "w").write(t.replace(old, new))
PY
  if python3 "$S" --self-test >/dev/null 2>&1; then
    echo "NOT LOAD-BEARING: $label  (self-test still passed)"
  else
    echo "load-bearing:     $label"
  fi
  cp "$B" "$S"
}

try "strip comments and literals" \
  'return normalise_handles(strip_comments_and_literals(text))' \
  'return normalise_handles(text)'

try "normalise Handle(Foo)" \
  'return normalise_handles(strip_comments_and_literals(text))' \
  'return strip_comments_and_literals(text)'

try "qualified-use exclusion" \
  'if before.endswith("->") or before.endswith("::") or before.endswith("."):
            continue' \
  'if False:
            continue'

try "own-body-extent exclusion (recursion)" \
  'if any(start <= offset < end for start, end in extents):
                continue  # inside one of its own bodies: recursion, not a caller' \
  'if False:
                continue  # inside one of its own bodies: recursion, not a caller'

try "declarator-name exclusion" \
  'if offset in declarators:
                continue' \
  'if False:
                continue'

try "header-name guard" \
  'if external or name in excluded:' \
  'if external:'

try "static-variable rejection in STATIC_DECL" \
  '[^;{(=]*?' \
  '[^{(=]*?'

try "prototype rejection (brace_extent returns None)" \
  'if j >= len(text) or text[j] == ";":
        return None' \
  'if j >= len(text) or text[j] == ";":
        return (j, j)'

try "divergence includes live copies" \
  'for d in result["dead"] + result["live"]:' \
  'for d in result["dead"]:'

try "divergence requires a dead copy" \
  'if not any(e["state"] == "dead" for e in entries):
            continue' \
  'if False:
            continue'

cp "$B" "$S"
python3 "$S" --self-test
