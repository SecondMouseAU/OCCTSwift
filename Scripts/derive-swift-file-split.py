#!/usr/bin/env python3
"""Measure what is actually inside Document.swift and Shape.swift, for #393 and #394.

Both issues were written on the premise that these files are already organised as thematic
`extension` blocks, so the split is a mechanical move of each `// MARK:` section. Measurement says
otherwise, and that premise is why the two issues need rewriting before anyone starts:

  - The MARK sections are RELEASE BATCHES, not domains. 240 of Document.swift's 277 top-level marks
    carry a version tag like "(v0.109.0)", and a batch contains whatever landed in that release
    across every domain. Splitting on MARK boundaries would produce Document+v0.109.swift.
  - Document.swift is not a Document file. It has more `extension Shape` than `extension Document`,
    and 40% of it is standalone types that extend nothing.

So the split axis is the TYPE each declaration belongs to, which is what this reports.

    python3 Scripts/derive-swift-file-split.py                 # summary for both files
    python3 Scripts/derive-swift-file-split.py --list Document # every declaration and its owner

Exits 2 if run from anywhere but the repo root, matching the other gate scripts (#625).
"""

import argparse
import collections
import os
import re
import sys

FILES = {
    "Document": "Sources/OCCTSwift/Document.swift",
    "Shape": "Sources/OCCTSwift/Shape.swift",
}

DECL = re.compile(
    r"^(?:public |internal |private |package |)?(?:final )?"
    r"(extension|class|struct|enum|protocol|actor)\s+([A-Za-z_]\w*)"
)


def scan(path):
    """Yield (kind, name, line_count) for every top-level declaration, by brace depth."""
    lines = open(path, errors="ignore").read().split("\n")
    i, n = 0, len(lines)
    while i < n:
        m = DECL.match(lines[i])
        if not m:
            i += 1
            continue
        kind, name, start = m.group(1), m.group(2), i
        depth, opened = 0, False
        while i < n:
            depth += lines[i].count("{") - lines[i].count("}")
            opened = opened or "{" in lines[i]
            i += 1
            if opened and depth <= 0:
                break
        yield kind, name, i - start


def report(label, path, show_list):
    extended = collections.Counter()
    standalone = collections.Counter()
    for kind, name, size in scan(path):
        (extended if kind == "extension" else standalone)[name] += size
        if show_list:
            print(f"{size:6d}\t{'extension' if kind == 'extension' else 'type'}\t{name}")
    if show_list:
        return

    total = sum(extended.values()) + sum(standalone.values())
    file_lines = sum(1 for _ in open(path, errors="ignore"))
    print(f"### {os.path.basename(path)}: {file_lines} lines, {total} inside top-level declarations")
    print("    extensions, by the type they extend:")
    for name, size in extended.most_common():
        print(f"      {size:6d}  extension {name}")
    print(f"    standalone types declared here: {len(standalone)} types, {sum(standalone.values())} lines")
    for name, size in standalone.most_common(8):
        print(f"      {size:6d}  {name}")
    if len(standalone) > 8:
        print(f"      ... and {len(standalone) - 8} more")
    print()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", metavar="WHICH", choices=sorted(FILES), help="print every declaration")
    args = ap.parse_args()

    for path in FILES.values():
        if not os.path.isfile(path):
            print(f"error: run from the repo root (expected {path})", file=sys.stderr)
            return 2

    for label, path in FILES.items():
        if args.list and args.list != label:
            continue
        report(label, path, bool(args.list))
    return 0


if __name__ == "__main__":
    sys.exit(main())
