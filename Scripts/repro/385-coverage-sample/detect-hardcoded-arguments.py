#!/usr/bin/env python3
"""Bare numeric literals passed as arguments to an OCCT constructor or method inside the bridge.

Distinct from #726, which looks at what a bridge function RETURNS; this looks at what it PASSES.
The signal #1020 describes is a literal argument sitting where the caller's own input should be:
a hardcoded tolerance beside a `tolerance` parameter, a hardcoded bound on a domain the caller can
place anywhere.

A SCREENING PROBE, NOT A GATE. Its measured false-positive rate is in
`Scripts/repro/1001-detector-fp-rates/`, over a hand-adjudicated census of everything it reports.

TWO BLIND SPOTS, BOTH FOUND BY REVIEW RATHER THAN BY THE TOOL, BOTH CLOSED HERE (#1001)
---------------------------------------------------------------------------------------
The first version scanned line by line and matched arguments with `\\(([^();]{4,200})\\)`, so:

  * a call `clang-format` wrapped at ColumnLimit 100 was invisible, because no single line held
    both the callee and its arguments;
  * an argument that is itself a call was invisible, because the character class forbids the
    nested parens: `Extrema_ExtPS ext(gp_Pnt(px, py, pz), *as, 1e-6, 1e-6)` never matched.

Measured against `Sources/OCCTBridge/src` at the tip of #1001's branch point, the two together hid
**10 of 23** call sites, 43% of the population. One of the ten, `IntRes2d_Domain`'s hardcoded
+-100 parameter range in `OCCTBisectorInterPointPoint`, was a defect measured to drop a real
intersection: see `Scripts/repro/1001-detector-fp-rates/occt_1001_bisector_domain.mm`. It was filed
as #1050 and is fixed; each domain now comes from its own bisector's parameter range, and
`Scripts/repro/1050-bisector-domain/` carries that investigation. The sentence is left here in the
past tense rather than deleted, because it is what this detector's one true positive bought.

The criterion itself (which literals count as a tuning knob, and 2+ of them in one call) is
unchanged, so the finding sets before and after differ only by what the parser could reach.

Usage:
    detect-hardcoded-arguments.py [<dir>]   # default Sources/OCCTBridge/src
    detect-hardcoded-arguments.py --self-test
"""

import os
import re
import sys
from collections import Counter

DEFAULT_DIR = "Sources/OCCTBridge/src"

# A literal that is plausibly a tuning knob rather than an index, a flag or an identity element.
KNOB = re.compile(r'^-?(?:[2-9]\d*|\d+\.\d+|1\d+|0\.\d+|1e-?\d+)$')

# Indices, dimensions and ordinals: too noisy to carry on their own.
SKIP_ARG = {"0", "1", "-1", "2", "3"}

# `Class(` or `Class name(`, where the class looks like an OCCT one.
HEAD = re.compile(r'\b([A-Z][A-Za-z0-9_]*(?:_[A-Za-z0-9_]+)?)\s*(?:\w+\s*)?\(')

OCCT_PREFIXES = ("gp", "Geom", "BRep", "Shape", "Approx", "Adaptor")

MIN_ARGS_LEN = 4
MAX_ARGS_LEN = 400


def strip_noise(text):
    """Blank comments and string literals, preserving every newline so line numbers still line up.

    String literals matter here and not only comments: `"tolerance 1e-6, 1e-6"` in a message would
    otherwise parse as two tuning literals the moment the scanner stopped working line by line.
    """
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith('//', i):
            j = text.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(''.join(c if c == '\n' else ' ' for c in text[i:j]))
            i = j
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                if text[j] == '\\':
                    j += 1
                j += 1
            out.append(' ' * (min(j, n - 1) + 1 - i))
            i = j + 1
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


def matching_paren(text, open_at):
    """Index of the `)` closing the `(` at `open_at`, or -1. Spans newlines on purpose."""
    depth = 0
    for j in range(open_at, len(text)):
        if text[j] == '(':
            depth += 1
        elif text[j] == ')':
            depth -= 1
            if depth == 0:
                return j
    return -1


def split_top_level(args):
    """Split an argument list on its top-level commas only, so a nested call stays one argument."""
    parts, depth, cur = [], 0, []
    for ch in args:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            parts.append(''.join(cur))
            cur = []
        else:
            cur.append(ch)
    parts.append(''.join(cur))
    return [p.strip() for p in parts]


def scan_text(text, path="<text>"):
    """Every call in `text` passing two or more bare tuning literals to an OCCT API."""
    src = strip_noise(text)
    found = []
    for m in HEAD.finditer(src):
        cls = m.group(1)
        if not ("_" in cls or cls.startswith(OCCT_PREFIXES)):
            continue
        open_at = src.rindex('(', m.start(), m.end())
        close_at = matching_paren(src, open_at)
        if close_at < 0:
            continue
        args = src[open_at + 1:close_at]
        if not (MIN_ARGS_LEN <= len(args) <= MAX_ARGS_LEN):
            continue
        lits = [a for a in split_top_level(args) if KNOB.match(a) and a not in SKIP_ARG]
        if len(lits) < 2:
            continue
        line = src[:m.start()].count("\n") + 1
        # The report shows the original text, comments and all, since that is what a reader opens.
        excerpt = text.split("\n")[line - 1].strip()[:88]
        found.append((path, line, cls, ", ".join(lits), excerpt))
    return found


def scan_dir(root):
    found = []
    for fn in sorted(os.listdir(root)):
        if not fn.endswith(".mm"):
            continue
        with open(os.path.join(root, fn), errors="ignore") as fh:
            found.extend(scan_text(fh.read(), fn))
    return found


SELF_TEST = [
    # (name, source, expected number of findings)
    ("plain single-line call, the shape the first version already caught",
     "void f() { Extrema_ExtCS ext(*ac, *as, 1e-6, 1e-6); }", 1),
    ("a call wrapped by clang-format, invisible to a line-by-line scan",
     "void f() {\n  IntRes2d_Domain d1(p,\n                     -100.0,\n"
     "                     1e-6,\n                     q,\n                     100.0,\n"
     "                     1e-6);\n}", 1),
    ("an argument that is itself a call, invisible to a no-nested-parens regex",
     "void f() { Extrema_ExtPS ext(gp_Pnt(px, py, pz), *as, 1e-6, 1e-6); }", 1),
    ("literals inside a string literal are not arguments",
     'void f() { Message_Msg m("Geom_Foo(1e-6, 1e-6) failed"); }', 0),
    ("literals inside a comment are not arguments",
     "void f() { /* Geom_Foo(1e-6, 1e-6) */ int x = 0; }", 0),
    ("one tuning literal is below the threshold",
     "void f() { Geom_Circle c(ax, 1e-6); }", 0),
    ("indices and identity elements do not count as tuning literals",
     "void f() { Geom_Foo c(ax, 0, 1, 2, 3, -1); }", 0),
    ("a nested call carrying the literals is reported for the nested call, once",
     "void f() { Foo_Bar(ax, Geom_Baz(1e-6, 1e-6)); }", 1),
    # This case must use an UPPERCASE callee. The first version used `snprintf`, and the removal
    # matrix scored the OCCT-class filter 9/9, i.e. decorative: HEAD requires `[A-Z]` to start a
    # callee, so a lowercase name never reaches the filter and the case was proving the wrong
    # guard. `Foo` has no underscore and no OCCT prefix, so the filter is the only thing that can
    # reject it.
    ("an uppercase but non-OCCT callee is out of scope",
     "void f() { Foo(bar, 1e-6, 1e-6); }", 0),
    ("a lowercase callee never reaches the class filter at all",
     "void f() { snprintf(buf, 1e-6, 1e-6); }", 0),
]


def self_test():
    ok = 0
    for name, src, expected in SELF_TEST:
        got = len(scan_text(src))
        verdict = "ok  " if got == expected else "FAIL"
        if got == expected:
            ok += 1
        print(f"  {verdict} expected {expected}, got {got}: {name}")
    print(f"{ok}/{len(SELF_TEST)} cases correct")
    return 0 if ok == len(SELF_TEST) else 1


def main(argv):
    if "--self-test" in argv:
        return self_test()
    root = argv[1] if len(argv) > 1 else DEFAULT_DIR
    found = scan_dir(root)
    per_file = Counter(f[0] for f in found)
    print(f"{len(found)} call site(s) passing 2+ bare tuning literals to an OCCT API\n")
    for name, n in per_file.most_common():
        print(f"  {n:3}  {name}")
    print()
    for path, line, cls, lits, excerpt in found:
        print(f"  {path}:{line}\n      {cls}  literals: {lits}\n      {excerpt}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
