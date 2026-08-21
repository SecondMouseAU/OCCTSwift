#!/usr/bin/env python3
"""Recall of `shapetype_census.py`, which is the number its false-positive rate does not give (#1001).

The census scores 0 false positives over a twenty-row hand-adjudicated sample. That is easy to
misread as a clean bill of health, and it is not one: the census's documented defect runs in the
OTHER direction. Its first version accepted any `IsNull()` anywhere in a body as a guard on the
caller's shape, which is why #1026 was filed at fifteen sites when the real figure was 46. A
detector that under-reports will naturally show a low false-positive rate, so the two numbers
measure different things and only one of them was measured by the sample.

This measures the other one, against a ground truth the census had no part in building: the set of
bridge functions a human actually added a null-shape guard to when fixing #1026. Recall against a
hand-built validation set is the criterion #928 settled on for the same reason, that it is the one
measurement not drawn from the detector's own output.

GROUND TRUTH
------------
The two #1026 fix commits, `76ef6ec9` (42 sites) and `7bb20ac5` (the four TopoDS_Builder sites). A
function is in the ground truth when its body gained `occtShapeIsPresent(` or `occtShapeIsType(`
between the commit's parent and the commit itself. That is a record of human judgement about where
a guard was needed, made by probing rather than by running this census.

WHAT A MISS MEANS, AND WHAT IT DOES NOT
---------------------------------------
The census is deliberately narrower than the whole #1026 class. Its own docstring says the GATE for
this class is `check-null-handle-guards.py`, which resolves guarding helpers by analysis and covers
the eight flag accessors as well; the census knows two helpers by name and matches `ShapeType()`
ONLY. Some of #1026's sites are ones "the gate cannot see" at all, where the kernel dereferences the
shape inside a constructor or inside `TopoDS_Builder::Add`. So a miss here is not automatically a
defect: it is either a blind spot inside the stated subject or a site outside it, and the report
separates the two rather than pooling them, because the raw recall figure hides which is which.

    python3 Scripts/repro/1001-detector-fp-rates/measure_shapetype_recall.py
"""

import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
CENSUS = os.path.join(ROOT, "Scripts", "repro", "1008-topods-cast-guard", "shapetype_census.py")

FIX_COMMITS = ["76ef6ec9", "7bb20ac5"]
PRE_FIX_TREE = "90917a70"
GUARDS = ("occtShapeIsPresent(", "occtShapeIsType(")

# Deliberately independent of the census's own parser: a definition opens at column 0 with a name
# containing OCCT, and runs to its matching brace.
DEF = re.compile(r'^[A-Za-z_][^\n;=]*?\b(OCCT[A-Za-z0-9_]+)\s*\([^;{]*?\)\s*\{', re.M | re.S)


def show(ref, path):
    proc = subprocess.run(["git", "show", f"{ref}:{path}"], cwd=ROOT,
                          capture_output=True, text=True)
    return proc.stdout if proc.returncode == 0 else None


def functions_with_guard(text):
    """Names of OCCT-prefixed definitions in `text` whose body calls a named guard helper."""
    found = set()
    if not text:
        return found
    for m in DEF.finditer(text):
        open_at = text.index("{", m.end() - 1)
        depth, close_at = 0, len(text) - 1
        for j in range(open_at, len(text)):
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
                if depth == 0:
                    close_at = j
                    break
        body = text[open_at:close_at + 1]
        if any(g in body for g in GUARDS):
            found.add(m.group(1))
    return found


def body_at(ref, filename, funcname):
    """The body of one OCCT-prefixed definition at a given commit, or None."""
    text = show(ref, f"Sources/OCCTBridge/src/{filename}")
    if not text:
        return None
    for m in DEF.finditer(text):
        if m.group(1) != funcname:
            continue
        open_at = text.index("{", m.end() - 1)
        depth, close_at = 0, len(text) - 1
        for j in range(open_at, len(text)):
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
                if depth == 0:
                    close_at = j
                    break
        return text[open_at:close_at + 1]
    return None


def changed_files(commit):
    proc = subprocess.run(
        ["git", "show", "--name-only", "--pretty=format:", commit], cwd=ROOT,
        capture_output=True, text=True)
    return [f for f in proc.stdout.split("\n")
            if f.startswith("Sources/OCCTBridge/src/") and f.endswith((".mm", ".h"))]


def ground_truth():
    """Functions that GAINED a named null-shape guard in the #1026 fix commits."""
    gained = {}
    for commit in FIX_COMMITS:
        for path in changed_files(commit):
            before = functions_with_guard(show(f"{commit}~1", path))
            after = functions_with_guard(show(commit, path))
            for name in sorted(after - before):
                gained[name] = os.path.basename(path)
    return gained


def census_reported():
    """Functions the census reports at the pre-fix tree."""
    spec = importlib.util.spec_from_file_location("_census", CENSUS)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    tmp = tempfile.mkdtemp(prefix="occtswift-1001-recall-")
    try:
        tar = subprocess.run(["git", "archive", PRE_FIX_TREE, "Sources/OCCTBridge/src"],
                             cwd=ROOT, capture_output=True)
        subprocess.run(["tar", "-x", "-C", tmp], input=tar.stdout, check=True)
        src = os.path.join(tmp, "Sources", "OCCTBridge", "src")
        rows = mod.census(src) if hasattr(mod, "census") else None
        if rows is None:
            # The census exposes its report through main(); fall back to parsing its output.
            proc = subprocess.run([sys.executable, CENSUS, src], capture_output=True, text=True)
            names = set()
            for line in proc.stdout.split("\n"):
                m = re.match(r'\s*\S+\.(?:mm|h):\d+\s+(OCCT[A-Za-z0-9_]+)\(', line)
                if m:
                    names.add(m.group(1))
            return names
        return {r[2] for r in rows}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    truth = ground_truth()
    reported = census_reported()

    hit = sorted(n for n in truth if n in reported)
    miss = sorted(n for n in truth if n not in reported)

    # Classify each miss. The census matches ShapeType() only, so a missed function whose body
    # never reads ShapeType() is outside the stated subject; one that does read it is a blind spot
    # inside it. Those are very different findings.
    outside, blind = [], []
    for name in miss:
        body = body_at(PRE_FIX_TREE, truth[name], name)
        if body is None:
            outside.append((name, "definition not found at the pre-fix tree"))
        elif re.search(r'\.\s*ShapeType\s*\(', body):
            blind.append((name, "reads ShapeType() and was still missed"))
        else:
            outside.append((name, "never reads ShapeType()"))

    inside = len(truth) - len(outside)
    print(f"ground truth (functions guarded by the #1026 fix commits) : {len(truth)}")
    print(f"reported by shapetype_census.py at {PRE_FIX_TREE}            : {len(reported)}")
    print(f"of the ground truth, reported                              : {len(hit)}")
    print(f"of the ground truth, MISSED                                : {len(miss)}")
    if truth:
        print(f"raw recall                                                 : "
              f"{len(hit)}/{len(truth)} = {100 * len(hit) / len(truth):.1f}%")
    if inside:
        print(f"recall WITHIN the census's stated subject                  : "
              f"{len(hit)}/{inside} = {100 * len(hit) / inside:.1f}%")

    if outside:
        print(f"\nOUTSIDE the stated subject ({len(outside)}). The census matches ShapeType() only,")
        print("and defers the eight flag accessors to check-null-handle-guards.py:")
        for name, _why in outside:
            print(f"  {truth[name]:<32} {name}")
    if blind:
        print(f"\nBLIND SPOTS ({len(blind)}), inside the stated subject and still missed:")
        for name, why in blind:
            print(f"  {truth[name]:<32} {name}  ({why})")

    extra = sorted(n for n in reported if n not in truth)
    if extra:
        print(f"\nReported but not in the ground truth ({len(extra)}). Not false positives by")
        print("itself: the ground truth is one commit pair, and a function already carrying a")
        print("guard for another reason never appears as having GAINED one.")
        for name in extra[:12]:
            print(f"  {name}")
        if len(extra) > 12:
            print(f"  ... and {len(extra) - 12} more")
    return 0


if __name__ == "__main__":
    sys.exit(main())
