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

# `func` is in the list because top-level free functions are otherwise invisible here, and that
# blindness cost real work: #659 moved 9 of them out of Shape.swift and only found them by diffing
# every top-level line against the declaration ranges. Document.swift has 2 more waiting for #661.
# The name alternation admits operator characters as well as identifiers, so a top-level operator
# overload (`func + (lhs: V, rhs: V) -> V`) is not invisible the way plain `func` used to be. None
# exist in the tree today; the point is that the next one does not have to be found by hand.
DECL = re.compile(
    r"^(?:public |internal |private |package |fileprivate |)?(?:final )?"
    r"(extension|class|struct|enum|protocol|actor|func)\s+"
    r"([A-Za-z_]\w*|[-+*/%<>=!&|^~?]+)"
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


def report(path, show_list):
    extended = collections.Counter()
    standalone = collections.Counter()
    free_funcs = collections.Counter()
    for kind, name, size in scan(path):
        if kind == "extension":
            extended[name] += size
        elif kind == "func":
            free_funcs[name] += size
        else:
            standalone[name] += size
        if show_list:
            kind_label = {"extension": "extension", "func": "free func"}.get(kind, "type")
            print(f"{size:6d}\t{kind_label}\t{name}")
    if show_list:
        return

    total = sum(extended.values()) + sum(standalone.values()) + sum(free_funcs.values())
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
    if free_funcs:
        print(f"    top-level free functions: {len(free_funcs)}, {sum(free_funcs.values())} lines")
        for name, size in free_funcs.most_common(8):
            print(f"      {size:6d}  {name}()")
        if len(free_funcs) > 8:
            print(f"      ... and {len(free_funcs) - 8} more")
    print()


SELF_TEST_FIXTURE = """\
import Foundation

public extension Shape {
    func inAnExtension() {}
}

public final class SomeType {
    fileprivate init() {}
}

public struct AValue {}

public func aFreeFunction(x: Int) -> Int {
    return x
}

fileprivate func aFileprivateFreeFunction() {}

public func + (lhs: AValue, rhs: AValue) -> AValue {
    return lhs
}
"""

# What the fixture must classify as. The point of each entry is a failure mode this script has
# actually had: `func` was missing from DECL entirely until #659 found 9 free functions by hand,
# `fileprivate` was missing from the access alternation, and an operator name does not match an
# identifier pattern. A detector that reports "all clear" because it is blind looks exactly like
# one reporting "all clear" on a clean tree, which is why this exists.
SELF_TEST_EXPECTED = {
    ("extension", "Shape"),
    ("class", "SomeType"),
    ("struct", "AValue"),
    ("func", "aFreeFunction"),
    ("func", "aFileprivateFreeFunction"),
    ("func", "+"),
}


def self_test():
    import tempfile

    with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False) as handle:
        handle.write(SELF_TEST_FIXTURE)
        fixture = handle.name
    try:
        found = {(kind, name) for kind, name, _ in scan(fixture)}
    finally:
        os.unlink(fixture)

    missing = SELF_TEST_EXPECTED - found
    extra = found - SELF_TEST_EXPECTED
    for kind, name in sorted(missing):
        print(f"  MISSED   {kind} {name}", file=sys.stderr)
    for kind, name in sorted(extra):
        print(f"  SPURIOUS {kind} {name}", file=sys.stderr)
    ok = len(SELF_TEST_EXPECTED) - len(missing)
    print(f"self-test: {ok}/{len(SELF_TEST_EXPECTED)} cases correct" + (", 0 spurious" if not extra else ""))
    return 0 if not missing and not extra else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", metavar="WHICH", choices=sorted(FILES), help="print every declaration")
    ap.add_argument("--self-test", action="store_true", help="prove the detector catches each shape")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    for path in FILES.values():
        if not os.path.isfile(path):
            print(f"error: run from the repo root (expected {path})", file=sys.stderr)
            return 2

    for label, path in FILES.items():
        if args.list and args.list != label:
            continue
        report(path, bool(args.list))
    return 0


if __name__ == "__main__":
    sys.exit(main())
