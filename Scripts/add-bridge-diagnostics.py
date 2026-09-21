#!/usr/bin/env python3
"""Add the #1161 caught-exception diagnostics call to a bridge .mm file's catch blocks.

    python3 Scripts/add-bridge-diagnostics.py --dry-run Sources/OCCTBridge/src/OCCTBridge_Mesh.mm
    python3 Scripts/add-bridge-diagnostics.py Sources/OCCTBridge/src/OCCTBridge_Mesh.mm
    Scripts/format-bridge.sh Sources/OCCTBridge/src/OCCTBridge_Mesh.mm

Inserts `occtRecordCaughtException(__func__);` as the first statement of every FUNCTION-LEVEL
`catch (...)` block, and reports every other catch block it found instead of touching it. Idempotent:
a block that already has the call is left alone, so re-running after a merge is safe.

Why a script and not a hand pass: #1161 measured 3,652 `catch (...)` blocks in
Sources/OCCTBridge/src, 3,597 of them at function level. One file (OCCTBridge_Modeling_Boolean.mm)
was instrumented with this script when the channel shipped; the rest is a mechanical sweep that
should be done a domain at a time, reviewed as "this script's output plus clang-format", never by
hand.

WHAT "FUNCTION LEVEL" MEANS, and why it is the whole safety argument: under this tree's
clang-format config the bridge is indented two spaces per level with the brace on its own line, so a
catch block at indent 2 is the one that fails the entire call, which is exactly what the channel is
for. A deeper one sits inside a loop or an inner try and may be ordinary recover-and-continue
control flow; recording one of those would report a failure for a call that went on to succeed.
Those are reported, never edited, and each needs a human verdict. In the first file, one of 103
blocks was such a case (occtSampleWirePoints, which skips an edge carrying no 3D curve) and is
deliberately left out with a comment saying so.

Run Scripts/format-bridge.sh on any file this touches: the inserted line is written at a fixed
indent and clang-format is the authority on what the file should look like.
"""
import re
import sys

CATCH = re.compile(r"^(\s*)catch \(\.\.\.\)\s*$")


def instrument(path, dry_run=False):
    lines = open(path).read().split("\n")
    out = []
    inserted = 0
    skipped = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = CATCH.match(line)
        out.append(line)
        if not m:
            i += 1
            continue
        indent = len(m.group(1))
        # The opening brace of the catch body is the next line.
        if i + 1 >= len(lines) or lines[i + 1].strip() != "{":
            skipped.append((i + 1, "catch body does not open with a bare brace"))
            i += 1
            continue
        if indent != 2:
            skipped.append((i + 1, f"nested catch (indent {indent}), needs a human"))
            i += 1
            continue
        if "occtRecordCaughtException" in "\n".join(lines[i : i + 4]):
            skipped.append((i + 1, "already instrumented"))
            i += 1
            continue
        out.append(lines[i + 1])  # the "{"
        out.append("    occtRecordCaughtException(__func__);")
        inserted += 1
        i += 2
    if not dry_run:
        open(path, "w").write("\n".join(out))
    return inserted, skipped


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    total = 0
    for path in args:
        n, skipped = instrument(path, dry_run=dry)
        total += n
        print(f"{path}: inserted {n}")
        for line, why in skipped:
            print(f"    skipped line {line}: {why}")
    print(f"total inserted: {total}")
