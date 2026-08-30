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
    python3 Scripts/derive-swift-file-split.py --file Sources/OCCTSwift/Curve2D.swift
    python3 Scripts/derive-swift-file-split.py --file Sources/OCCTSwift/Curve2D.swift --list foreign

`--file` is the "extending it to any file would be the honest first step" #687 asked for: the same
`scan()` this script always used, aimed at a path instead of the two hardcoded ones. `--list foreign`
with `--file` prints every declaration NOT extending the file's own presumed type (guessed from the
filename, stripping a trailing `+Suffix`), which is the #393/#394 axis ("foreign material is the
trigger, not size") applied to an arbitrary file rather than just Document/Shape.

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


def presumed_owner(path):
    """`Curve2D.swift` -> `Curve2D`, `Shape+Modeling.swift` -> `Shape`. A guess from the filename,
    used only by `--list foreign`; never trusted for anything that decides pass/fail."""
    stem = os.path.splitext(os.path.basename(path))[0]
    return stem.split("+")[0]


def report(path, show_list):
    extended = collections.Counter()
    standalone = collections.Counter()
    free_funcs = collections.Counter()
    foreign_lines = []
    owner = presumed_owner(path)
    for kind, name, size in scan(path):
        if kind == "extension":
            extended[name] += size
        elif kind == "func":
            free_funcs[name] += size
        else:
            standalone[name] += size
        if kind != "func" and name == owner:
            pass  # the file's own type, declared or extended: not foreign
        else:
            foreign_lines.append((kind, name, size))
        if show_list == "all":
            kind_label = {"extension": "extension", "func": "free func"}.get(kind, "type")
            print(f"{size:6d}\t{kind_label}\t{name}")
    if show_list == "foreign":
        total_foreign = sum(size for _, _, size in foreign_lines)
        file_lines = sum(1 for _ in open(path, errors="ignore"))
        print(f"### {os.path.basename(path)}: {file_lines} lines, presumed owner `{owner}` "
              f"(guessed from the filename); {total_foreign} lines ({100 * total_foreign // max(file_lines, 1)}%) "
              f"do not extend it")
        for kind, name, size in sorted(foreign_lines, key=lambda t: -t[2]):
            kind_label = {"extension": "extension", "func": "free func"}.get(kind, "type")
            print(f"  {size:6d}\t{kind_label}\t{name}")
        return
    if show_list == "all":
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

    # `--file`/`--list foreign` (#687's arbitrary-file extension): a fixture named after one of its
    # own declarations must report that one declaration as NOT foreign and every other one as
    # foreign. Needs a filename this script can actually guess an owner from, which
    # NamedTemporaryFile's random suffix can't give, hence the explicit dir + name.
    import shutil

    tmp_dir = tempfile.mkdtemp()
    try:
        fixture_path = os.path.join(tmp_dir, "AValue.swift")
        with open(fixture_path, "w") as fh:
            fh.write(SELF_TEST_FIXTURE)
        owner = presumed_owner(fixture_path)
        if owner != "AValue":
            print(f"  FILE-MODE FAILURE: presumed_owner guessed {owner!r}, expected 'AValue'",
                  file=sys.stderr)
            ok_file = False
        else:
            foreign_names = set()
            own_names = set()
            for kind, name, _ in scan(fixture_path):
                is_own = kind != "func" and name == owner
                (own_names if is_own else foreign_names).add((kind, name))
            expected_foreign = SELF_TEST_EXPECTED - {("struct", "AValue")}
            missing_foreign = expected_foreign - foreign_names
            wrongly_foreign = {("struct", "AValue")} & foreign_names
            ok_file = not missing_foreign and not wrongly_foreign
            if missing_foreign:
                print(f"  FILE-MODE FAILURE: not flagged foreign: {missing_foreign}", file=sys.stderr)
            if wrongly_foreign:
                print(f"  FILE-MODE FAILURE: AValue's own struct wrongly flagged foreign", file=sys.stderr)
    finally:
        shutil.rmtree(tmp_dir)
    print(f"self-test (--file --list foreign): {'OK' if ok_file else 'FAILED'}")

    return 0 if (not missing and not extra and ok_file) else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", metavar="WHICH", help="Document|Shape for full detail, or "
                    "'foreign' with --file for that file's non-owner declarations only")
    ap.add_argument("--file", metavar="PATH", help="measure an arbitrary Sources/OCCTSwift/*.swift "
                     "file instead of the hardcoded Document/Shape pair (#687)")
    ap.add_argument("--self-test", action="store_true", help="prove the detector catches each shape")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if args.file:
        if args.list and args.list not in ("all", "foreign"):
            print("error: --list with --file takes 'all' or 'foreign', not a hardcoded file label",
                  file=sys.stderr)
            return 2
        if not os.path.isfile(args.file):
            print(f"error: {args.file} not found (run from the repo root?)", file=sys.stderr)
            return 2
        report(args.file, args.list or None)
        return 0

    if args.list and args.list not in FILES:
        print(f"error: --list without --file takes one of {sorted(FILES)}", file=sys.stderr)
        return 2

    for path in FILES.values():
        if not os.path.isfile(path):
            print(f"error: run from the repo root (expected {path})", file=sys.stderr)
            return 2

    for label, path in FILES.items():
        if args.list and args.list != label:
            continue
        report(path, "all" if args.list else None)
    return 0


if __name__ == "__main__":
    sys.exit(main())
