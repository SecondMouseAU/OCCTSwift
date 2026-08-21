#!/usr/bin/env python3
"""
count-operations.py: derive OCCTSwift's canonical operation count and keep the three
headline figures from drifting apart.

CANONICAL COUNTING RULE (decided on issue #289):

    One row per distinct public Swift entry point; overloads counted separately.

Concretely, an "operation" is any of these in the `OCCTSwift` module:

    public func / public static func / public class func
    public init
    public var  : computed only (has a `{` accessor block)
    public subscript

Overloads count separately: `cylinder(radius:height:)` and
`cylinder(at:direction:radius:height:)` are two operations, because they are two distinct
entry points a caller can reach.

NOT operations (they are data, not entry points):
    public let                       : stored constants
    public var x: T = ...            : stored properties (no accessor block)
    enum cases, typealiases, types   : documented, but not called

Why derive rather than hand-maintain: README and docs/API_REFERENCE.md desynced by 882
across 11 releases, and API_REFERENCE's own Total sat 111 above the sum of its rows,
both written in the same commit, so at most one was ever right (#289).

Usage:
    ./Scripts/count-operations.py           # report; exit 1 if the docs disagree
    ./Scripts/count-operations.py --fix     # rewrite README + API_REFERENCE Total + docs/index.md
    ./Scripts/count-operations.py --audit   # list counted entry points with no reference doc

Exit status is 1 when README's headline, API_REFERENCE's Total or
docs/index.md's headline disagrees with the derived count, so this can gate a commit:
it always could; it was the one gate script whose docstring never said so, which is
why it read as a release-time reporting tool. Exit status is 2 for an
unrecognised option: this script has no `--self-test`, its three sibling gates do, and CI pairs
each of theirs with its real run, so `count-operations.py --self-test` is the natural thing to
write when extending that list: it used to be accepted silently and run the ordinary report,
passing forever. CI runs this bare in `ci.yml`'s `gate-scripts` job (#625).
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
# Bare (no explicit `public`) forms of the same four, used only when the innermost enclosing
# scope is a `public extension` body: Swift raises a member's default access level to match an
# extension's own stated modifier, so `public extension Foo { func bar() {} }` makes `bar()`
# genuinely public with no `public` keyword on its own line, invisible to FUNC/INIT/CVAR/SUBS
# above, which all anchor on a literal `public`. 64 such members across 22 blocks in 6 files were
# undercounted this way before this fix (#914 review, finding 8, corrected from an earlier draft
# of this comment, which said 86: the derived count only moved 4275 -> 4339, i.e. +64, and a
# second round of review caught the arithmetic didn't match the comment; #899/#902's own count
# moving 4267 -> 4275 on a pure `public extension` -> `extension` + per-member `public` reformat in
# `Shape+Analysis.swift` was this exact defect, caught by accident rather than by the scanner).
FUNC_BARE = re.compile(r'^\s*(?:static\s+|class\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)')
INIT_BARE = re.compile(r'^\s*(?:convenience\s+)?init[?!]?\s*\(')
CVAR_BARE = re.compile(r'^\s*(?:static\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)\b[^=]*\{')
SUBS_BARE = re.compile(r'^\s*(?:static\s+)?subscript\s*\(')
# A member explicitly narrowing below the extension's default: not implicitly public even inside
# a `public extension` body.
NARROWER_ACCESS = re.compile(r'^\s*(?:private|fileprivate|internal)\b')
PUBLIC_EXTENSION_DECL = re.compile(r'^\s*public\s+extension\s+[A-Za-z_]')
# An @available(..., unavailable, ...) attribute: the declaration below it is a retired spelling
# kept only so an old call site fails to build with an explanation, so it is not an entry point.
# A `deprecated` one still is: it can still be called. Scans the whole attribute, not just its
# opening line (#520 introduced the single-line-only version; #899/#902 found swift-format's own
# strict-mode wrapping of a long `message: """..."""` argument breaks it, silently un-retiring
# the declaration below). AVAILABLE_OPEN below finds where the attribute starts; the caller in
# count_entry_points() walks forward from there, treating the attribute's own message string as
# opaque once it opens (never handing a string-body line to the declaration matchers) and only
# searching for `unavailable` in the argument-list text before a `message:`/`renamed:` label,
# never inside the string value itself.
AVAILABLE_OPEN = re.compile(r'^\s*@available\s*\(')
UNAVAILABLE_WORD = re.compile(r'\bunavailable\b')
AVAIL_LABEL_ARG = re.compile(r'\b(?:message|renamed)\s*:')
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


def _strip_trailing_comment(line):
    '''Strip a `//...` line comment, but only a `//` that starts outside any double-quoted
    string literal on this line -- a `//` inside a string (a URL in an @available message is
    the obvious case) is string content, not a comment marker.

    The blind regex this replaces truncated a message containing a URL at the first `//`,
    losing the string's own closing quote and the attribute's closing paren -- which then pins
    the @available scanner's paren depth above zero and silently stops counting the rest of the
    *file* (#914 review, third pass -- the same "gate that cannot fail" failure mode finding 7
    fixed, reached through a different door finding 7's fix didn't close). Naive about a
    triple-quoted string opening mid-line (three double-quote characters in a row toggle
    in_string an odd number of times, ending up "in a string" rather than genuinely closed) --
    harmless here: the only caller that reads text past where a triple-quote begins on this same
    line discards everything from that point on regardless of what this function decided about
    text after it.
    '''
    in_string = False
    i = 0
    n = len(line)
    while i < n - 1:
        c = line[i]
        if in_string and c == '\\':
            i += 2
            continue
        if c == '"':
            in_string = not in_string
        elif not in_string and c == '/' and line[i + 1] == '/':
            return line[:i]
        i += 1
    return line


def _enclosing_type(stack):
    """Innermost *named* type name on the brace stack, or None at file scope.

    Skips shield frames (`name is None`, pushed for a member body/closure/if/for opening
    directly inside a `public extension`, see `_in_public_extension`'s doc) rather than
    reading `stack[-1]` directly: those frames carry no type identity of their own, and a
    counted operation still wants its enclosing type's name, not the frame closest to it.
    """
    for name, _, _ in reversed(stack):
        if name is not None:
            return name.split('.')[-1]
    return None


def _in_public_extension(stack):
    """Whether the innermost enclosing scope is itself a `public extension` body.

    Per-frame, not inherited past the innermost one: a plain (non-`public`) type nested inside a
    `public extension` reverts to Swift's ordinary internal default for its own members, same as
    it would outside one. A member body (or any other non-type brace, closure, `if`, `for`...)
    opening directly inside a `public extension` gets an explicit shield frame pushed for it (see
    the main loop below) for the identical reason: a local function nested inside a public
    extension's member is not itself public just because the enclosing extension is.
    """
    return stack[-1][2] if stack else False


def count_entry_points():
    """Returns (total, breakdown, ops) where ops maps (type, name) -> (file, line).

    `type` is the innermost enclosing struct/class/enum/actor/extension name (last
    component of a nested/qualified name), or None at file scope. Overloads and same-named
    members on different types collapse to one row per (type, name), which is all the audit
    needs: the derived Total still comes from `breakdown`, which counts every declaration.
    """
    breakdown = {"func": 0, "init": 0, "computed var": 0, "subscript": 0}
    ops = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "Sources/OCCTSwift/*.swift"))):
        rel = os.path.relpath(f, ROOT)
        stack = []      # [(type_name, brace_depth_at_open, is_public_extension)]
        depth = 0
        unavailable = False   # an @available(*, unavailable) seen; it applies to the next decl
        in_avail_attr = False     # scanning an @available(...) attribute's pre-string header
        in_avail_string = False   # inside the attribute's own message string body: opaque
        avail_paren_depth = 0
        avail_pending_unavailable = False
        for i, line in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
            code = _strip_trailing_comment(line)   # string-aware line-comment strip
            enc = _enclosing_type(stack)

            if in_avail_string:
                # A line inside the attribute's own `"""..."""` message: not attribute syntax,
                # not a declaration, just prose. Never handed to the matchers below, however
                # declaration-shaped it looks, until its own closing `"""` is seen.
                if '"""' in line:
                    in_avail_string = False
            elif in_avail_attr or AVAILABLE_OPEN.match(line):
                # Only look at text before any `"""`: the availability keyword (unavailable /
                # deprecated / a platform spec) always precedes a `message:` string argument in
                # this codebase's usage, never appears inside one, so stopping there keeps
                # parens *inside* the message prose (e.g. "continuityClass.satisfies(_:)") from
                # ever being counted as attribute-argument-list parens. Comment-stripped (`code`,
                # not `line`) for the same reason brace-counting below is.
                header = code.split('"""', 1)[0]
                # Search only the part before a `message:`/`renamed:` label, not the whole
                # header: past that label is the argument's own string *value*, where the bare
                # word "unavailable" can appear in ordinary prose (e.g. a deprecation message
                # that happens to say a feature "is currently unavailable on tvOS") without it
                # being the attribute's own unavailable/deprecated flag.
                spec = AVAIL_LABEL_ARG.split(header, 1)[0]
                if UNAVAILABLE_WORD.search(spec):
                    avail_pending_unavailable = True
                # Strip complete `"..."` string literals before counting parens: a single-line
                # `message: "... (see #123)"` has an unbalanced `(` inside the string, which is
                # prose, not attribute-argument-list syntax. Uncorrected, that leaves
                # avail_paren_depth stuck above 0 and in_avail_attr true for the rest of the
                # file, silently routing every later declaration away from the FUNC/INIT/CVAR
                # matchers (#914 review, finding 7, the mechanism was present, though no
                # `message:` string in this tree currently contains an unbalanced paren, so it
                # had not yet miscounted anything).
                header_parens = re.sub(r'"(?:[^"\\]|\\.)*"', '""', header)
                avail_paren_depth += header_parens.count('(') - header_parens.count(')')
                if '"""' in line:
                    # The message string starts here (raw `line`, not `code`: the string's own
                    # boundary is real source text, not something a comment-strip should touch).
                    rest = line.split('"""', 1)[1]
                    in_avail_attr = False
                    if avail_pending_unavailable:
                        unavailable = True
                    avail_pending_unavailable = False
                    avail_paren_depth = 0
                    if '"""' not in rest:
                        # Opens but does not also close on this same line: the body continues
                        # onto following lines, which in_avail_string now shields entirely.
                        in_avail_string = True
                elif avail_paren_depth <= 0:
                    # Attribute closed on this line with no message string at all (e.g. a bare
                    # `@available(iOS 18.0, macOS 15.0, *)`, or `unavailable`/`deprecated` with
                    # no `message:`).
                    in_avail_attr = False
                    if avail_pending_unavailable:
                        unavailable = True
                    avail_pending_unavailable = False
                    avail_paren_depth = 0
                else:
                    in_avail_attr = True
            else:
                # Inside a `public extension` body, a member with no access modifier of its own
                # is implicitly public too (see FUNC_BARE et al above), but one that explicitly
                # narrows (`private`/`fileprivate`/`internal`) is not.
                implicit_public = _in_public_extension(stack) and not NARROWER_ACCESS.match(line)
                m = FUNC.match(line) or (implicit_public and FUNC_BARE.match(line))
                if m:
                    if not unavailable:
                        breakdown["func"] += 1
                        ops.setdefault((enc, m.group(1)), (rel, i))
                    unavailable = False
                elif INIT.match(line) or (implicit_public and INIT_BARE.match(line)):
                    if not unavailable:
                        breakdown["init"] += 1
                    unavailable = False
                else:
                    m = CVAR.match(line) or (implicit_public and CVAR_BARE.match(line))
                    if m:
                        if not unavailable:
                            breakdown["computed var"] += 1
                            ops.setdefault((enc, m.group(1)), (rel, i))
                        unavailable = False
                    elif SUBS.match(line) or (implicit_public and SUBS_BARE.match(line)):
                        if not unavailable:
                            breakdown["subscript"] += 1
                        unavailable = False

            # Maintain the enclosing-type stack, skipping a line still inside the attribute's
            # message string (in_avail_string, as of the top of this iteration): prose there is
            # opaque to this too, not just to the declaration matchers above, so a code sample
            # in the message that happens to contain `{`/`}` or read as a type declaration can't
            # corrupt the stack for the file's real, subsequent declarations.
            if not in_avail_string:
                td = TYPE_DECL.match(line)
                opens, closes = code.count('{'), code.count('}')
                depth += opens - closes
                if td is not None and opens > closes:
                    # body opens and stays open below this line; a one-liner like
                    # `enum Toggle { case a, b }` (opens == closes) encloses nothing.
                    stack.append((td.group(1), depth, bool(PUBLIC_EXTENSION_DECL.match(line))))
                elif opens > closes and _in_public_extension(stack):
                    # A non-type body, a member's own `{` (whichever line it lands on: same
                    # line as `func`/`var` for the common case, or a later line for a wrapped
                    # multi-line signature), a closure, an `if`/`for`/`switch`... opening
                    # directly inside a `public extension` scope shields everything below it
                    # from the extension's implicit-public default (#914 review, second round:
                    # a local `func` nested inside a public extension's member was being counted
                    # as a public operation, since nothing reset `_in_public_extension` for the
                    # member body it's actually inside). Pushing this for every body-opener, not
                    # just member declarations, is deliberately over-broad but harmless: once one
                    # shield frame is on top, `_in_public_extension` is already False, so this
                    # branch never re-fires for a construct nested inside an already-shielded
                    # body, there is no need to special-case which shape of brace this is.
                    stack.append((None, depth, False))
                else:
                    while stack and depth < stack[-1][1]:
                        stack.pop()
    return sum(breakdown.values()), breakdown, ops


def documented_index():
    """Scan docs/reference/*.md and return (typed, bare).

    `typed` is a set of (type, name) pairs the docs associate with an owning type, parsed
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
            # sees. Read the type from the first backtick span, or, for a plain heading like
            # `## DXFError` with no backticks, from the heading text itself. Distinguish by
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
    """The three headline figures currently in the docs.

    docs/index.md is the third because it drifted while nothing was reading it: it sat at 4,339
    against a derived 4,355 until #967 noticed by hand. A figure this script does not read is a
    figure that goes stale, which is the whole argument for deriving the other two.
    """
    readme = os.path.join(ROOT, "README.md")
    apiref = os.path.join(ROOT, "docs/API_REFERENCE.md")
    index = os.path.join(ROOT, "docs/index.md")
    r = re.search(r'\*\*([\d,]+) wrapped operations\.?\*\*', open(readme, encoding="utf-8").read())
    a = re.search(r'^\|\s*\*\*Total\*\*\s*\|\s*\*\*([\d,]+)\*\*\s*\|', open(apiref, encoding="utf-8").read(), re.M)
    # The period is optional deliberately: docs/index.md writes it inside the bold and README
    # outside, and a regex that insisted on one spelling would turn a punctuation edit into a
    # crash rather than a check (found by a pre-PR review, which did exactly that edit).
    i = re.search(r'\*\*([\d,]+) wrapped operations\.?\*\*', open(index, encoding="utf-8").read())
    return (int(r.group(1).replace(',', '')) if r else None,
            int(a.group(1).replace(',', '')) if a else None,
            int(i.group(1).replace(',', '')) if i else None)


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
        sys.exit("README: could not find the 'N wrapped operations' headline: refusing to guess")
    open(readme, "w", encoding="utf-8").write(new_s)

    apiref = os.path.join(ROOT, "docs/API_REFERENCE.md")
    s = open(apiref, encoding="utf-8").read()
    new_s, n = re.subn(r'^(\|\s*\*\*Total\*\*\s*\|\s*\*\*)[\d,]+(\*\*\s*\|)',
                       rf'\g<1>{derived:,}\g<2>', s, count=1, flags=re.M)
    if n != 1:
        sys.exit("API_REFERENCE: could not find the Total row: refusing to guess")

    # The prose figure for the row sum drifts by the same mechanism as the Total did:
    # it is written by hand and nothing checks it. Derive it too, or #289 recurs here
    # the moment someone adds a category row.
    rowsum, _ = category_row_sum_text(new_s)
    pct = round(100 * rowsum / derived)
    new_s, n = re.subn(r'(covering \*\*)[\d,]+(\*\* of the entry points \(~)\d+(%)',
                       rf'\g<1>{rowsum:,}\g<2>{pct}\g<3>', new_s, count=1)
    if n != 1:
        sys.exit("API_REFERENCE: could not find the 'covering **N** of the entry points (~P%)' "
                 "note: refusing to guess")
    open(apiref, "w", encoding="utf-8").write(new_s)

    # docs/index.md carries the same headline and is checked by the same gate, so --fix has to
    # rewrite it too. It did not until #967, and the failure was silent in the worst way: --fix
    # repaired two of three files, printed a success line and exited 0, while a plain run on the
    # same tree still exited 1. A repair route that under-repairs and reports success is worse
    # than no repair route, because the release engineer it exists for stops looking.
    index = os.path.join(ROOT, "docs/index.md")
    s = open(index, encoding="utf-8").read()
    new_s, n = re.subn(r'\*\*[\d,]+( wrapped operations\.?\*\*)',
                       rf'**{derived:,}\g<1>', s, count=1)
    if n != 1:
        sys.exit("docs/index.md: could not find the 'N wrapped operations' headline: "
                 "refusing to guess")
    open(index, "w", encoding="utf-8").write(new_s)

    print(f"  rewrote README + API_REFERENCE Total + docs/index.md -> {derived:,}")
    print(f"  rewrote the categorisation note -> {rowsum:,} (~{pct}%)")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""

    # Reject an unrecognised option rather than falling through to the report. Silently ignoring
    # one made `--self-test` a trap: this script has no self-test, its three sibling gates do, and
    # CI pairs each of theirs with its real run, so the natural thing to write when adding this
    # script to that list is `count-operations.py --self-test`, which would have run the ordinary
    # report and passed forever, exactly the "a gate that cannot fail" defect #625 exists to end.
    # A prose warning was the first fix and was the wrong one: #625's whole premise is that prose
    # describing a gate is not a gate. Exit 2, matching the sibling scripts' "cannot run" status
    # (they use it for a wrong working directory), so it is distinguishable from a real failure.
    # Also stops `--fi` silently reporting when `--fix` was meant.
    if mode not in ("", "--fix", "--audit"):
        print(f"unknown option: {mode}", file=sys.stderr)
        print("usage: count-operations.py [--fix | --audit]", file=sys.stderr)
        return 2

    derived, breakdown, ops = count_entry_points()

    if mode == "--audit":
        typed_doc, bare_doc = documented_index()
        # Type-aware match: a counted (type, name) is documented if the docs associate that
        # exact (type, name), via a `Type.name` heading or a member listed in the type's
        # code block, OR if `name` appears in a type-less heading (matches any owner). This
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

    readme_n, apiref_n, index_n = read_stated()
    rowsum, rowcount = category_row_sum()
    def stated(label, n):
        # A reworded headline makes the regex miss, and `n` is then None. Formatting None raises
        # TypeError, which reports a crash where the script has in fact found something worth
        # saying, so say it.
        shown = "  n/a" if n is None else f"{n:>5}"
        if n is None:
            verdict = f"  ✗ (headline not found: refusing to guess, expected {derived})"
        elif n == derived:
            verdict = "  ✓"
        else:
            verdict = f"  ✗ (should be {derived})"
        print(f"  {label:<22}{shown}{verdict}")

    stated("README headline", readme_n)
    stated("API_REFERENCE Total", apiref_n)
    stated("docs/index.md headline", index_n)
    print(f"  sum of {rowcount} category rows  {rowsum:>5}   (illustrative categorisation; see the note in API_REFERENCE)")

    if mode == "--fix":
        fix(derived)
        return 0
    return 0 if (readme_n == derived and apiref_n == derived and index_n == derived) else 1


if __name__ == "__main__":
    sys.exit(main())
