#!/usr/bin/env python3
"""
count-operations.py — derive OCCTSwift's canonical operation count and keep the two
headline figures from drifting apart.

CANONICAL COUNTING RULE (decided on issue #289):

    One row per distinct public Swift entry point; overloads counted separately.

Concretely, an "operation" is any of these in the `OCCTSwift` module:

    public func / public static func / public class func
    public init
    public var  — computed only (has a `{` accessor block)
    public subscript

Overloads count separately: `cylinder(radius:height:)` and
`cylinder(at:direction:radius:height:)` are two operations, because they are two distinct
entry points a caller can reach.

NOT operations (they are data, not entry points):
    public let                       — stored constants
    public var x: T = ...            — stored properties (no accessor block)
    enum cases, typealiases, types   — documented, but not called

Why derive rather than hand-maintain: README and docs/API_REFERENCE.md desynced by 882
across 11 releases, and API_REFERENCE's own Total sat 111 above the sum of its rows —
both written in the same commit, so at most one was ever right (#289).

Usage:
    ./Scripts/count-operations.py           # report; exit 1 if the docs disagree
    ./Scripts/count-operations.py --fix     # rewrite README + API_REFERENCE Total
    ./Scripts/count-operations.py --audit   # list counted entry points with no reference doc
"""
import re
import sys
import glob
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FUNC = re.compile(r'^\s*public\s+(?:static\s+|class\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)')
INIT = re.compile(r'^\s*public\s+(?:convenience\s+)?init[?!]?\s*\(')
# computed property: an accessor block `{` and no `=` before it. A stored `public let x: T`
# or `public var x = 0` has no brace and is data, not an entry point.
CVAR = re.compile(r'^\s*public\s+(?:static\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)\b[^=]*\{')
SUBS = re.compile(r'^\s*public\s+(?:static\s+)?subscript\s*\(')
# reference docs use both ### and #### for entry points
DOC_HEADING = re.compile(r'^#{3,4} `([^`]+)`')


def count_entry_points():
    """Returns (total, breakdown, {name: (file, line)})."""
    breakdown = {"func": 0, "init": 0, "computed var": 0, "subscript": 0}
    names = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "Sources/OCCTSwift/*.swift"))):
        rel = os.path.relpath(f, ROOT)
        for i, line in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
            m = FUNC.match(line)
            if m:
                breakdown["func"] += 1
                names.setdefault(m.group(1), (rel, i))
                continue
            if INIT.match(line):
                breakdown["init"] += 1
                continue
            m = CVAR.match(line)
            if m:
                breakdown["computed var"] += 1
                names.setdefault(m.group(1), (rel, i))
                continue
            if SUBS.match(line):
                breakdown["subscript"] += 1
    return sum(breakdown.values()), breakdown, names


def documented_names():
    doc = set()
    for f in glob.glob(os.path.join(ROOT, "docs/reference/*.md")):
        for line in open(f, encoding="utf-8", errors="replace"):
            m = DOC_HEADING.match(line)
            if not m:
                continue
            # `Type.name(labels:)` -> `name`
            h = m.group(1).split('(')[0].split('.')[-1].strip()
            if h:
                doc.add(h)
    return doc


def read_stated():
    """The two headline figures currently in the docs."""
    readme = os.path.join(ROOT, "README.md")
    apiref = os.path.join(ROOT, "docs/API_REFERENCE.md")
    r = re.search(r'\*\*([\d,]+) wrapped operations\*\*', open(readme, encoding="utf-8").read())
    a = re.search(r'^\|\s*\*\*Total\*\*\s*\|\s*\*\*([\d,]+)\*\*\s*\|', open(apiref, encoding="utf-8").read(), re.M)
    return (int(r.group(1).replace(',', '')) if r else None,
            int(a.group(1).replace(',', '')) if a else None)


def category_row_sum():
    apiref = os.path.join(ROOT, "docs/API_REFERENCE.md")
    total = 0
    rows = 0
    for line in open(apiref, encoding="utf-8"):
        m = re.match(r'^\|\s*\*\*(.+?)\*\*\s*\|\s*\*?\*?(\d+)\*?\*?\s*\|', line)
        if m and m.group(1).lower() != "total":
            total += int(m.group(2))
            rows += 1
    return total, rows


def fix(derived):
    readme = os.path.join(ROOT, "README.md")
    s = open(readme, encoding="utf-8").read()
    new_s, n = re.subn(r'\*\*[\d,]+ wrapped operations\*\*', f'**{derived:,} wrapped operations**', s, count=1)
    if n != 1:
        sys.exit("README: could not find the 'N wrapped operations' headline — refusing to guess")
    open(readme, "w", encoding="utf-8").write(new_s)

    apiref = os.path.join(ROOT, "docs/API_REFERENCE.md")
    s = open(apiref, encoding="utf-8").read()
    new_s, n = re.subn(r'^(\|\s*\*\*Total\*\*\s*\|\s*\*\*)[\d,]+(\*\*\s*\|)',
                       rf'\g<1>{derived:,}\g<2>', s, count=1, flags=re.M)
    if n != 1:
        sys.exit("API_REFERENCE: could not find the Total row — refusing to guess")
    open(apiref, "w", encoding="utf-8").write(new_s)
    print(f"  rewrote README + API_REFERENCE Total -> {derived:,}")


def main():
    derived, breakdown, names = count_entry_points()
    mode = sys.argv[1] if len(sys.argv) > 1 else ""

    if mode == "--audit":
        doc = documented_names()
        undoc = sorted(set(names) - doc)
        print(f"counted entry points with NO reference doc: {len(undoc)}\n")
        for n in undoc:
            f, i = names[n]
            print(f"  {n:<34} {f}:{i}")
        return 1 if undoc else 0

    print("Canonical rule (#289): one row per distinct public Swift entry point; overloads counted separately.\n")
    for k, v in sorted(breakdown.items(), key=lambda x: -x[1]):
        print(f"  {k:<15} {v:>5}")
    print(f"  {'DERIVED':<15} {derived:>5}\n")

    readme_n, apiref_n = read_stated()
    rowsum, rowcount = category_row_sum()
    print(f"  README headline        {readme_n:>5}" + ("  ✓" if readme_n == derived else f"  ✗ (should be {derived})"))
    print(f"  API_REFERENCE Total    {apiref_n:>5}" + ("  ✓" if apiref_n == derived else f"  ✗ (should be {derived})"))
    print(f"  sum of {rowcount} category rows  {rowsum:>5}   (illustrative categorisation; see the note in API_REFERENCE)")

    if mode == "--fix":
        fix(derived)
        return 0
    return 0 if (readme_n == derived and apiref_n == derived) else 1


if __name__ == "__main__":
    sys.exit(main())
