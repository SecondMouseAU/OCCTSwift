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
# An @available(..., unavailable, ...) attribute: the declaration below it is a retired spelling
# kept only so an old call site fails to build with an explanation, so it is not an entry point.
# A `deprecated` one still is — it can still be called. Only the attribute's opening line is
# matched, which is where `unavailable` sits; a multi-line `message:` body below it matches none
# of the declaration patterns above (#520).
UNAVAILABLE = re.compile(r'^\s*@available\s*\([^)]*\bunavailable\b')
# reference docs use both ### and #### for entry points
DOC_HEADING = re.compile(r'^#{3,4} `([^`]+)`')

# A type/extension declaration whose body encloses the entry points below it. Captures the
# type name so a counted op carries a `Type.name` identity, not just `name` (issue #294).
TYPE_DECL = re.compile(
    r'^\s*(?:(?:public|internal|private|fileprivate|final|open|package)\s+)*'
    r'(?:struct|class|enum|actor|extension|protocol)\s+([A-Za-z_][A-Za-z0-9_.]*)')
# A public member as it appears inside a ```swift code block in the reference docs.
DOC_MEMBER = re.compile(
    r'^\s*(?:@\w+\s+)*public\s+(?:static\s+|class\s+|convenience\s+|final\s+)*'
    r'(?:func\s+([A-Za-z_]\w*)|var\s+([A-Za-z_]\w*))')
# A backtick span that names a type (possibly nested, `Outer.Inner`) rather than a member call.
TYPEISH = re.compile(r'^[A-Z][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$')


def _enclosing_type(stack):
    """Innermost type name on the brace stack, or None at file scope."""
    return stack[-1][0].split('.')[-1] if stack else None


def count_entry_points():
    """Returns (total, breakdown, ops) where ops maps (type, name) -> (file, line).

    `type` is the innermost enclosing struct/class/enum/actor/extension name (last
    component of a nested/qualified name), or None at file scope. Overloads and same-named
    members on different types collapse to one row per (type, name), which is all the audit
    needs — the derived Total still comes from `breakdown`, which counts every declaration.
    """
    breakdown = {"func": 0, "init": 0, "computed var": 0, "subscript": 0}
    ops = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "Sources/OCCTSwift/*.swift"))):
        rel = os.path.relpath(f, ROOT)
        stack = []      # [(type_name, brace_depth_at_open)]
        depth = 0
        unavailable = False   # an @available(*, unavailable) seen; it applies to the next decl
        for i, line in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
            code = re.sub(r'//.*', '', line)   # crude line-comment strip for brace counting
            enc = _enclosing_type(stack)
            if UNAVAILABLE.match(line):
                unavailable = True
            m = FUNC.match(line)
            if m:
                if not unavailable:
                    breakdown["func"] += 1
                    ops.setdefault((enc, m.group(1)), (rel, i))
                unavailable = False
            elif INIT.match(line):
                if not unavailable:
                    breakdown["init"] += 1
                unavailable = False
            else:
                m = CVAR.match(line)
                if m:
                    if not unavailable:
                        breakdown["computed var"] += 1
                        ops.setdefault((enc, m.group(1)), (rel, i))
                    unavailable = False
                elif SUBS.match(line):
                    if not unavailable:
                        breakdown["subscript"] += 1
                    unavailable = False

            # maintain the enclosing-type stack
            td = TYPE_DECL.match(line)
            opens, closes = code.count('{'), code.count('}')
            depth += opens - closes
            if td is not None and opens > closes:
                # body opens and stays open below this line; a one-liner like
                # `enum Toggle { case a, b }` (opens == closes) encloses nothing.
                stack.append((td.group(1), depth))
            else:
                while stack and depth < stack[-1][1]:
                    stack.pop()
    return sum(breakdown.values()), breakdown, ops


def documented_index():
    """Scan docs/reference/*.md and return (typed, bare).

    `typed` is a set of (type, name) pairs the docs associate with an owning type — parsed
    from `### `Type.name(...)`` headings AND from the public members listed inside a ```swift
    code block that sits under a `### `Type`` heading. `bare` is the set of names documented
    by a heading that carries NO type qualifier (e.g. `### `analyze(tolerance:)`` or a
    multi-span `### `x`, `y`, `z``), which match any owning type by name alone.
    """
    typed = set()
    bare = set()
    for f in glob.glob(os.path.join(ROOT, "docs/reference/*.md")):
        cur_type = None       # owning type for the current section's code blocks
        in_code = False
        for line in open(f, encoding="utf-8", errors="replace"):
            if line.lstrip().startswith("```"):
                in_code = not in_code
                continue
            if in_code:
                m = DOC_MEMBER.match(line)
                if m and cur_type:
                    typed.add((cur_type, m.group(1) or m.group(2)))
                continue
            if not line.lstrip().startswith("#"):
                continue
            spans = re.findall(r'`([^`]+)`', line)
            # A heading governs the ```swift block beneath it; derive that block's owning
            # (innermost) type so its members register under the same type the source side
            # sees. Read the type from the first backtick span, or — for a plain heading like
            # `## DXFError` with no backticks — from the heading text itself. Distinguish by
            # the last dotted component:
            #   `ImportResult` / `Outer.Inner`  (last is a Type)   -> owner = innermost type
            #   `Shape.faceLPropTangentU/V(...)` (last is a member) -> owner = its qualifier
            #   `analyze(tolerance:)`            (bare member)      -> owner unchanged
            ctx_src = spans[0] if spans else line.lstrip().lstrip('#').strip()
            parts = ctx_src.split('(')[0].strip().split('.')
            if TYPEISH.match(parts[-1]):
                cur_type = parts[-1]
            elif len(parts) >= 2 and spans:
                cur_type = parts[-2]
            for span in spans:
                s = span.split('(')[0].strip()
                if not s:
                    continue
                if '.' in s:
                    t, n = s.rsplit('.', 1)
                    typed.add((t.split('.')[-1], n))
                else:
                    bare.add(s)
    return typed, bare


def read_stated():
    """The two headline figures currently in the docs."""
    readme = os.path.join(ROOT, "README.md")
    apiref = os.path.join(ROOT, "docs/API_REFERENCE.md")
    r = re.search(r'\*\*([\d,]+) wrapped operations\*\*', open(readme, encoding="utf-8").read())
    a = re.search(r'^\|\s*\*\*Total\*\*\s*\|\s*\*\*([\d,]+)\*\*\s*\|', open(apiref, encoding="utf-8").read(), re.M)
    return (int(r.group(1).replace(',', '')) if r else None,
            int(a.group(1).replace(',', '')) if a else None)


def category_row_sum_text(s):
    """(sum, count) of the category rows in API_REFERENCE text, excluding the Total row."""
    total = 0
    rows = 0
    for line in s.splitlines():
        m = re.match(r'^\|\s*\*\*(.+?)\*\*\s*\|\s*\*?\*?(\d+)\*?\*?\s*\|', line)
        if m and m.group(1).lower() != "total":
            total += int(m.group(2))
            rows += 1
    return total, rows


def category_row_sum():
    apiref = os.path.join(ROOT, "docs/API_REFERENCE.md")
    return category_row_sum_text(open(apiref, encoding="utf-8").read())


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

    # The prose figure for the row sum drifts by the same mechanism as the Total did:
    # it is written by hand and nothing checks it. Derive it too, or #289 recurs here
    # the moment someone adds a category row.
    rowsum, _ = category_row_sum_text(new_s)
    pct = round(100 * rowsum / derived)
    new_s, n = re.subn(r'(covering \*\*)[\d,]+(\*\* of the entry points \(~)\d+(%)',
                       rf'\g<1>{rowsum:,}\g<2>{pct}\g<3>', new_s, count=1)
    if n != 1:
        sys.exit("API_REFERENCE: could not find the 'covering **N** of the entry points (~P%)' "
                 "note — refusing to guess")
    open(apiref, "w", encoding="utf-8").write(new_s)
    print(f"  rewrote README + API_REFERENCE Total -> {derived:,}")
    print(f"  rewrote the categorisation note -> {rowsum:,} (~{pct}%)")


def main():
    derived, breakdown, ops = count_entry_points()
    mode = sys.argv[1] if len(sys.argv) > 1 else ""

    if mode == "--audit":
        typed_doc, bare_doc = documented_index()
        # Type-aware match: a counted (type, name) is documented if the docs associate that
        # exact (type, name) — via a `Type.name` heading or a member listed in the type's
        # code block — OR if `name` appears in a type-less heading (matches any owner). This
        # eliminates the bare-name false positives the old matcher over-reported (#294).
        undoc = sorted(
            (t, n, ops[(t, n)])
            for (t, n) in ops
            if (t, n) not in typed_doc and n not in bare_doc
        )
        print(f"counted entry points with NO reference doc: {len(undoc)}\n")
        for t, n, (f, i) in undoc:
            qual = f"{t}.{n}" if t else n
            print(f"  {qual:<42} {f}:{i}")
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
