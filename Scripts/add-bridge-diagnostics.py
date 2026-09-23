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
was instrumented with this script when the channel shipped, and #2077 swept the other 73 a domain at
a time, each pass reviewed as "this script's output plus clang-format" rather than by hand.

THE SWEEP IS DONE, so this script's remaining job is a NEW bridge file or a new bridge function:
run it, run Scripts/format-bridge.sh, and Scripts/check-bridge-diagnostics.py will confirm. That
gate is also what will tell you this script was needed in the first place.

WHAT "FUNCTION LEVEL" MEANS, and why it is the whole safety argument: under this tree's
clang-format config the bridge is indented two spaces per level with the brace on its own line, so a
catch block at indent 2 is the one that fails the entire call, which is exactly what the channel is
for. A deeper one sits inside a loop or an inner try and may be ordinary recover-and-continue
control flow; recording one of those would report a failure for a call that went on to succeed.
Those are reported, never edited, and each needs a human verdict. Of the 54 deeper blocks in the
bridge, #2077 instrumented 21 by hand (the ones that swallow the exception and convert it into a
refusal no outer handler will see) and left 33 out with a comment at each saying why.

That comment is load-bearing and not only documentation: the idempotence check below treats a block
whose first lines mention occtRecordCaughtException as already handled, so the comment is what stops
the next run of this script reinserting the call. #2077 measured both halves of that in OCCTBridge.mm
on one pass: occtDiagnosticsLog's clause already carried such a comment and was left alone, while
occtRecordCaughtException's own classification ladder did not, and the call this script inserted
there would have rethrown the same exception into the same clause and recursed until the stack ran
out. Both now carry one, and both are on check-bridge-diagnostics.py's exemption list.

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
