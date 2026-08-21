#!/usr/bin/env python3
"""Bridge functions that declare a named parameter and never read it.

A dead parameter means the caller's input cannot affect the answer. #999 and #1000 are this
detector's output; both are closed, and the tree it was written against now reports zero.

A SCREENING PROBE, NOT A GATE. Its measured false-positive rate is in
`Scripts/repro/1001-detector-fp-rates/`, over a hand-adjudicated census of everything it reports.

THREE BLIND SPOTS, CLOSED HERE (#1001)
--------------------------------------
1. **Every parameter whose name ends in `Ref` was exempt**, which is the whole handle family. The
   exemption existed to drop the twenty-three UNNAMED parameters in `OCCTBridge_BRepGraph.mm`'s
   deliberate ABI no-op stubs, where the "name" the extractor sees is really the type
   (`OCCTShapeRef` with nothing after it). It did that, and it also silently exempted ordinary
   named parameters. **Counted rather than estimated**, with this file's own extractor: the old
   rule skipped **58 declared parameters across 17 distinct spellings**, the same figure at both
   trees. The spellings are `curveRef`, `curve2dRef`, `curve3dRef`, `docRef`, `edgeRef`, `faceRef`,
   `guideCurveRef`, `pathCurveRef`, `profileWireRef`, `sectionCurveRef`, `shape1Ref`, `shape2Ref`,
   `shapeRef`, `spineFaceRef`, `surfRef`, `surfaceRef` and `wireRef`, which is wider than the
   handle family alone. Replaced with the rule the exemption was reaching for: a parameter is
   unnamed when, after qualifiers are removed, it is a SINGLE token. `OCCTShapeRef` is unnamed;
   `OCCTCurve3DRef curveRef` is not. The `startswith("OCCT")` half of the old exemption goes for
   the same reason, and is counted in the 58.

2. **`extern "C"` on the definition line hid the whole function**, guarded or not, because `"` is
   outside the return-type character class. Fixed by blanking string literals before the signature
   is matched, the same fix `shapetype_census.py` carries for the same reason (#1026).

3. **A parameter appearing only inside a string literal read as used.** Blanking string literals in
   the body fixes that too, and it is the reason the fix is one change rather than two.

**All three fixes cost zero findings on this tree, measured rather than assumed.** Against
`Sources/OCCTBridge/src` at #1001's branch point the count is 0 before and 0 after, because Pass 4a
fixed every site the old spelling could see. Against Pass 4a's own branch point (`90917a70`), where
the population is non-empty, both versions report **the same 13**, name for name. The `Ref`
exemption really did cover 58 declared parameters, and every one of them is read, which is what a
handle parameter almost always is; `extern "C"` appears in `Sources/OCCTBridge/src/*.mm` only
inside comments; and no
parameter is mentioned solely in a string literal. So the corrections are proved by the fixture
battery below and by nothing in the tree, which is the useful thing to know about them.

Usage:
    detect-dead-parameters.py [<dir>]     # default Sources/OCCTBridge/src
    detect-dead-parameters.py --self-test
"""

import os
import re
import sys

DEFAULT_DIR = "Sources/OCCTBridge/src"

# Return type, OCCT-prefixed name, parameter list, brace body. `[^)]*` spans newlines, so a
# parameter list clang-format wrapped is still one match.
SIG = re.compile(r'^[A-Za-z_][\w \*\_\(\)]*?\b(OCCT[A-Za-z0-9_]+)\s*\(([^)]*)\)\s*\n?\{', re.M)

# Dropped from a parameter before its tokens are counted. Whatever is left is type and name.
QUALIFIERS = {"const", "volatile", "struct", "_Nonnull", "_Nullable", "_Null_unspecified",
              "unsigned", "signed", "static", "inline", "extern", "long", "short"}


def strip_noise(text):
    """Blank comments and string literals, preserving every newline so line numbers still line up."""
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


def parameter_name(param):
    """The declared name of one parameter, or None when the parameter is unnamed.

    Unnamed is decided by token count, not by how the token is spelled. A parameter that reduces to
    a single token after qualifiers, pointers, references and array brackets are removed IS a bare
    type: `OCCTShapeRef`, `int32_t`, `double`. Two or more tokens and the last one is the name.
    """
    cleaned = re.sub(r'\[\s*\]', ' ', param)
    cleaned = re.sub(r'[\*&]', ' ', cleaned)
    tokens = [t for t in re.findall(r'[A-Za-z_]\w*', cleaned) if t not in QUALIFIERS]
    if len(tokens) < 2:
        return None
    return tokens[-1]


def scan_text(text, path="<text>"):
    """Every OCCT-prefixed definition in `text` with a named parameter its body never reads."""
    src = strip_noise(text)
    found = []
    for m in SIG.finditer(src):
        name, params = m.group(1), m.group(2)
        if params.strip() in ("", "void"):
            continue
        open_at = src.index("{", m.start())
        depth, close_at = 0, len(src) - 1
        for j in range(open_at, len(src)):
            if src[j] == "{":
                depth += 1
            elif src[j] == "}":
                depth -= 1
                if depth == 0:
                    close_at = j
                    break
        body = src[open_at:close_at + 1]
        pnames = [p for p in (parameter_name(q) for q in params.split(",")) if p]
        dead = [p for p in pnames if not re.search(rf'\b{re.escape(p)}\b', body)]
        if dead:
            found.append((path, src[:m.start()].count("\n") + 1, name, dead, len(pnames)))
    return found


def scan_dir(root):
    found = []
    for fn in sorted(os.listdir(root)):
        if not (fn.endswith(".mm") or fn.endswith(".h")):
            continue
        with open(os.path.join(root, fn), errors="ignore") as fh:
            found.extend(scan_text(fh.read(), fn))
    return found


SELF_TEST = [
    ("a named parameter never read, the shape the first version already caught",
     "int OCCTFoo(double tolerance, int n)\n{\n  return n;\n}\n", ["tolerance"]),
    ("every parameter read: not reported",
     "int OCCTFoo(double tolerance, int n)\n{\n  return n * tolerance;\n}\n", []),
    ("a parameter named `curveRef` is a NAME, not a bare type (#1001 blind spot 1)",
     "int OCCTFoo(OCCTCurve3DRef curveRef, int n)\n{\n  return n;\n}\n", ["curveRef"]),
    ("an UNNAMED handle parameter is still exempt, which is what the old rule was reaching for",
     "int OCCTFoo(OCCTShapeRef, int n)\n{\n  return n;\n}\n", []),
    ('`extern "C"` on the definition line no longer hides the function (#1001 blind spot 2)',
     'extern "C" int OCCTFoo(double tolerance, int n)\n{\n  return n;\n}\n', ["tolerance"]),
    ("a parameter mentioned only inside a string literal is not read (#1001 blind spot 3)",
     'int OCCTFoo(double tolerance, int n)\n{\n  log("tolerance ignored");\n  return n;\n}\n',
     ["tolerance"]),
    ("a parameter mentioned only inside a comment is not read",
     "int OCCTFoo(double tolerance, int n)\n{\n  // tolerance ignored\n  return n;\n}\n",
     ["tolerance"]),
    ("an out-parameter written but never read still counts as reached",
     "int OCCTFoo(double* out, int n)\n{\n  *out = 1;\n  return n;\n}\n", []),
    ("a wrapped parameter list is one match, not several",
     "int OCCTFoo(double tolerance,\n            int    n)\n{\n  return n;\n}\n", ["tolerance"]),
    ("a declaration with no body is not a definition",
     "int OCCTFoo(double tolerance, int n);\n", []),
]


def self_test():
    ok = 0
    for name, src, expected in SELF_TEST:
        got = sorted(d for row in scan_text(src) for d in row[3])
        verdict = "ok  " if got == sorted(expected) else "FAIL"
        if got == sorted(expected):
            ok += 1
        print(f"  {verdict} expected {sorted(expected)}, got {got}: {name}")
    print(f"{ok}/{len(SELF_TEST)} cases correct")
    return 0 if ok == len(SELF_TEST) else 1


def main(argv):
    if "--self-test" in argv:
        return self_test()
    root = argv[1] if len(argv) > 1 else DEFAULT_DIR
    found = scan_dir(root)
    print(f"{len(found)} bridge function(s) with an unread parameter\n")
    for path, line, name, dead, total in sorted(found, key=lambda h: -len(h[3])):
        print(f"  {path}:{line}  {name}")
        print(f"      unread: {', '.join(dead)}   ({len(dead)} of {total})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
