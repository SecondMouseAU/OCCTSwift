#!/usr/bin/env python3
"""Mechanical sweep: every bridge site that resolves an index by walking a TopExp_Explorer.

Flags a site when an explorer construction is followed within a few lines by an index comparison --
the "walk until idx == N" idiom, which addresses topology OCCURRENCES rather than the deduplicated
TopExp::MapShapes enumeration that edges()/edge(at:)/vertices() hand out.

Reports every sub-shape type, grouped, rather than only the ones currently believed to matter: the
grouping is what makes a deliberate exclusion (FACE, and the WIRE/SHELL fallbacks) visible as a
decision rather than an oversight. See README.md for the expected output on a converged tree.
"""
import re
import pathlib
import sys

SRC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "Sources/OCCTBridge/src")

explorer = re.compile(r"TopExp_Explorer\s+(\w+)\s*\(([^,]+),\s*([A-Za-z_][\w:]*)")
compare = re.compile(r"\b(\w+)\s*==\s*(\w*[Ii]ndex\w*|\w*Idx\w*)\b|\b(\w*[Ii]ndex\w*|\w*Idx\w*)\s*==\s*(\w+)\b")

rows = []
for path in sorted(SRC.glob("*.mm")):
    lines = path.read_text().splitlines()
    for n, line in enumerate(lines):
        m = explorer.search(line)
        if not m:
            continue
        shape_type = m.group(3)
        # Look ahead a few lines for an index comparison inside the loop body.
        window = "\n".join(lines[n:n + 6])
        if not compare.search(window):
            continue
        rows.append((str(path), n + 1, shape_type, line.strip()[:95]))

by_type = {}
for path, n, t, _ in rows:
    by_type.setdefault(t, []).append((path, n))

print(f"{len(rows)} explorer-indexed sites\n")
for t in sorted(by_type):
    print(f"--- {t}  ({len(by_type[t])}) ---")
    for path, n in by_type[t]:
        print(f"    {path}:{n}")
    print()
