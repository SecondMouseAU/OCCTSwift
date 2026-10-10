#!/usr/bin/env python3
"""Derive the bridge functions the lifted ShapeHealing test files reach (the shadow's FUNCS).

usage (repo root): python3 <this dir>/derive-funcs.py   (writes funcs.txt and funcs-<Target>.txt beside it)

A lifted file reaches a bridge function when an identifier the file uses (a method, property or
type name) is declared in Sources/OCCTSwift by a region whose body calls the function. The match is
by name only, so it over-approximates; the fixture constructors (Shape.box and friends) would
redden every test and say nothing about what a test pins, so a function reached from more than
MAXFILES lifted files is dropped as fixture plumbing and listed on stderr.
"""
import glob
import os
import re
import subprocess
import sys

MAXFILES = 3
MAXREGION = 12
MAXTOKENFILES = 2
HERE = os.path.dirname(os.path.abspath(__file__))
# files.txt (beside this script) names the PR's lifted test files; extras.txt, if present, names
# bridge functions the name match cannot see, one per line with an optional "# reason".
lifted = [l.strip() for l in open(os.path.join(HERE, "files.txt")) if l.strip() and not l.startswith("#")]

DECL = re.compile(r"^(?: {0,4}|\t)(?:@\w+(?:\([^)]*\))?[ \t]+)*(?:public |internal |private |fileprivate |static |class |final |convenience |mutating |nonmutating |override |required )*(func|var|let|init|subscript)\s*([A-Za-z_]\w*)?", re.M)
CALL = re.compile(r"\b(OCCT[A-Za-z0-9_]+)\s*\(")

regions = {}  # name -> set(bridge funcs)
for f in glob.glob("Sources/OCCTSwift/*.swift"):
    text = open(f, encoding="utf-8").read()
    ms = list(DECL.finditer(text))
    for i, m in enumerate(ms):
        end = ms[i + 1].start() if i + 1 < len(ms) else len(text)
        name = m.group(2) if m.group(1) != "init" else "init"
        if not name:
            continue
        regions.setdefault(name, set()).update(CALL.findall(text[m.start():end]))

# A token reached from many lifted files (count, x, area, box) is vocabulary, not a subject; a name
# declared by many regions in Sources is a common word. Both are dropped before any function is reached.
file_toks = {f: set(re.findall(r"\b([A-Za-z_]\w*)\b", open(f, encoding="utf-8").read())) for f in lifted}
token_files = {}
for f, ts in file_toks.items():
    for t in ts:
        token_files[t] = token_files.get(t, 0) + 1
per_func = {}
for f in lifted:
    reached = set()
    for t in file_toks[f]:
        if t in regions and t != "init" and token_files[t] <= MAXTOKENFILES and len(regions[t]) <= MAXREGION:
            reached |= regions[t]
    for fn in reached:
        per_func.setdefault(fn, set()).add(f)

# OCCTBooleanSplitMulti, OCCTMakeShell, OCCTMakeWireFromEdges and OCCTWireMakeWireFromEdgeRefs take a pointer to non-optional refs, and OCCTShapeFromWire returns a ref the
# header declares without _Nonnull although Swift imports it non-optional; the shadow generator cannot
# spell either.
UNSHADOWABLE = {"OCCTBooleanSplitMulti", "OCCTShapeFromWire", "OCCTMakeShell", "OCCTMakeWireFromEdges", "OCCTWireMakeWireFromEdgeRefs"}
# A test that names the C symbol itself sees the shadow and the import as equally visible and the
# compiler refuses with 'ambiguous use of' (injection-sweep-mechanics.md), so those are dropped.
for _f in glob.glob("Tests/**/*.swift", recursive=True):
    UNSHADOWABLE |= set(CALL.findall(open(_f, encoding="utf-8").read()))
EXTRA_FUNCS = set()
extras = os.path.join(HERE, "extras.txt")
if os.path.exists(extras):
    for l in open(extras):
        fn = l.split("#")[0].strip()
        if fn and fn not in UNSHADOWABLE:
            EXTRA_FUNCS.add(fn)
            per_func.setdefault(fn, set()).add("extra")
keep = sorted(fn for fn, fs in per_func.items() if len(fs) <= MAXFILES and fn not in UNSHADOWABLE)
drop = sorted(fn for fn, fs in per_func.items() if len(fs) > MAXFILES)
print(f"{len(lifted)} lifted files, {len(per_func)} reached, {len(keep)} kept, {len(drop)} dropped as fixture plumbing", file=sys.stderr)
print("dropped:", " ".join(drop), file=sys.stderr)
open(os.path.join(HERE, "funcs.txt"), "w").write("\n".join(keep) + "\n")
# Per-target subsets, so a slow target is only swept with the switches its own files reach.
targets = sorted({f.split("/")[1] for f in lifted})
for tgt in targets:
    sub = sorted(fn for fn in keep
                 if fn in EXTRA_FUNCS or any(("/%s/" % tgt) in f for f in per_func[fn]))
    with open(os.path.join(HERE, "funcs-%s.txt" % tgt), "w") as fh:
        fh.write("\n".join(sub) + "\n")
