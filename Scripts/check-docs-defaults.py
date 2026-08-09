#!/usr/bin/env python3
"""Verify that every default value a `docs/reference/` page restates matches its declaration.

Each page under `docs/reference/` documents an API by *restating* its signature in a fenced
```swift block:

    ### `Surface.approxWithDetails(tolerance:uContinuity:vContinuity:maxDegree:maxSegments:)`

    ```swift
    public func approxWithDetails(tolerance: Double, uContinuity: ParametricContinuity = .c2,
                                  vContinuity: ParametricContinuity = .c2,
                                  maxDegree: Int = 8, maxSegments: Int = 100) -> ApproxSurfaceResult
    ```

That restatement is a copy, and a copy drifts. #491 flipped both continuity defaults from `.c1`
to `.c2` and updated `docs/reference/Surface.md`; `docs/reference/Shape-HLR-Geom.md` documents the
same method and kept saying `.c1` (#626). A caller who omits the argument then believes they get a
C1 fit and gets a C2 one, which per #572 is not cosmetic: continuity is one of the inputs deciding
how far the fitted surface moves.

This script re-runs that comparison for every restated default in the tree. It parses each page's
fenced-swift declarations, finds the matching declaration in `Sources/OCCTSwift`, and compares the
default of each parameter the two have in common.

## The three shapes a default can drift in

All three are reported and all three fail the run, because a gate that reports a defect while
exiting 0 is not a gate:

  - `changed`      — both sides state a default and the literals differ (the #626 shape);
  - `docs-only`    — docs state a default the source does not have, so a caller believes an
    argument is optional when it is required;
  - `source-only`  — the source states a default the docs omit, so a caller believes an argument
    is required when it is optional. This is also how a *source-side* addition hides: the source
    gains `= 8` and the unchanged page keeps reading `maxDegree: Int`.

That last shape is why the comparison covers restatements stating **no** defaults at all, not only
the ones that state some. Skipping a default-free restatement before looking up its declaration
would mean a page reading `zzNoDef(a: Double, tol: Double)` never notices the source acquiring
`tol: Double = 5e-9`; on this tree that would leave roughly 2500 restatements uncovered against
876 covered. A restatement is skipped only once its declaration is known to be default-free too.

`--lenient` drops `source-only` to a warning, for a tree that has not finished paying that down.
Layout is not drift: `SIMD3(0, 0, 1)` and `SIMD3(0,0,1)` compare equal, whitespace inside a string
literal excepted.

## Picking the right declaration to compare against

Several declarations can share one name and parameter-label list — `writeOBJ(to:deflection:)` is
both `Document.writeOBJ` (deflection 1.0) and `Shape.writeOBJ` (0.1), and `approximated` exists on
`Curve3D`, `Curve2D` and `Surface`. Comparing against the wrong one is how the first version of
this script let a page state `Shape.writeOBJ`'s default for `Document.writeOBJ` and still exit 0 —
the #626 defect shape passing through the gate built to catch it.

So the owning type is resolved most specific first:

  1. the nearest heading's qualifier — ``### `Surface.approxWithDetails(...)` ``;
  2. then outward through the enclosing section headings — `CurveAdaptors.md` holds
     `## WireCurve` and `## EdgeCurve`, each with an identically titled `### points(count:)`,
     which the nearest heading alone cannot tell apart;
  3. then the page filename — `Document-Persistence-IO.md` -> `Document`;
  4. failing all of that, every candidate.

Each hint narrows only when it selects a non-empty set, because a page documents types other than
its title: `Shape-HLR-Geom.md` carries `Surface.approxWithDetails`.

Narrowing to a type is not the end of it. A type can hold two overloads, and deprecating a method
by keeping its old signature verbatim — defaults included — is the ordinary way to deprecate, so a
stale page goes on matching the retained twin. Wherever a pool still holds candidates that
*disagree* about a default, the restatement is reported as `unverified` and fails, instead of being
decided by whichever candidate happened to match cleanly. A twin that merely *lacks* a default is
not a disagreement: the doc's own defaults still pick the overload that has one, so the ordinary
deprecation shape stays quiet.

A doc declaration matching no source declaration is listed under `unmatched`. That bucket is
pinned rather than ignored: a restatement stops being compared the moment its labels stop matching
any declaration, so a renamed or reordered parameter would otherwise slip into it silently. Growth
fails the run.

Usage (from the repo root):

    python3 Scripts/check-docs-defaults.py                  # report drifted defaults
    python3 Scripts/check-docs-defaults.py --self-test      # run the built-in drift battery
    python3 Scripts/check-docs-defaults.py --list-unmatched # show uncomparable restatements
    python3 Scripts/check-docs-defaults.py --lenient        # source-only warns instead of failing
    python3 Scripts/check-docs-defaults.py --quiet          # exit status only

Exit status is 1 when a default disagrees, when a restatement cannot be adjudicated, or when the
`unmatched` bucket grows — so this can gate a commit. CI runs it, and its `--self-test`, in
`ci.yml`'s `gate-scripts` job (#625).
"""
import argparse
import glob
import os
import re
import sys

SRC_GLOB = 'Sources/OCCTSwift/*.swift'
DOCS_GLOB = 'docs/reference/*.md'

# Restatements whose name and label list match no declaration in `Sources/OCCTSwift`. These are
# genuinely uncomparable — helper functions defined inside example snippets, and signatures whose
# labels the page spells differently from the declaration. The count is pinned because a
# restatement stops being compared the moment its labels stop matching: renaming or reordering a
# parameter on one side moves it here, and an unpinned bucket would absorb that silently. Raise it
# only after checking each new entry (`--list-unmatched`).
#
# The original three: a `requestCancel()` and a `printTree(_:indent:)` defined inside example
# snippets, and `Shape.init(handle:)`, which the page restates as `internal init` on purpose.
#
# #802 item 5 (docs-coverage bucket 2) raised this to 66: closing the coverage gap meant
# documenting `internal`/`private`/`fileprivate` implementation members too (this codebase's
# own coverage census counts those deliberately, see `check-docs-existence.py`'s docstring), and
# each restates its real signature in a fenced ```swift block for readability, exactly like a
# public entry does. `want_public=True` correctly excludes every one of them from the
# comparable-declaration index on the source side, since none carries `public`/`open` and none
# sits in a `public extension`, so all 63 land here rather than in the drift count. Verified by
# hand, one at a time, against `Sources/OCCTSwift`: every new entry is a genuine non-public
# declaration (`DXFWriter`/`PDFWriter`/`SVGWriter`'s private staging/serialization helpers,
# `MathDimension`'s internal static validators, `ThreadSpec`'s private designation parsers,
# `ThreadProfile`'s internal factory helpers, `DrawingAnnotationStore`'s internal mutators, two
# unrelated private `toOCCT()` conversions, `Mesh.toBridge()`, `Curve3D.continuityAnalysis`, and
# `ArcLengthCurveAdaptor.sampledPoints`), not a renamed or reordered parameter this bucket would
# otherwise be hiding.
EXPECTED_UNMATCHED = 66

# A declaration this script can compare. The generic-parameter group follows the name, as Swift
# writes it (`func f<T>(...)`); putting it first made every generic declaration invisible.
DECL_RE = re.compile(
    r'\b(?:public\s+|open\s+)?'
    r'(?:static\s+|class\s+|final\s+|mutating\s+|override\s+|convenience\s+|required\s+'
    r'|nonisolated\s+)*'
    r'(?P<kind>func|init|subscript)\b'
    r'\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)?'
    r'(?P<optional>[?!])?'
    r'(?P<gen>\s*<[^<>]*>)?'
    r'\s*\('
)

# Enclosing-type tracker for Sources: `extension Surface {`, `public struct Foo {`, ...
TYPE_RE = re.compile(
    r'^\s*(?P<access>public\s+|internal\s+|private\s+|fileprivate\s+|open\s+)?'
    r'(?:final\s+)?(?P<kind>extension|struct|class|enum|actor|protocol)\s+'
    r'(?P<name>[A-Za-z_][A-Za-z0-9_.]*)'
)

# An explicit access modifier on the member itself overrides what the container implies.
# Word-anchored: a substring test reads `private func openFile(...)` as public, via `open`.
EXPLICIT_ACCESS_RE = re.compile(r'(?<![A-Za-z0-9_])(private|fileprivate|internal)(?![A-Za-z0-9_])')
PUBLIC_RE = re.compile(r'(?<![A-Za-z0-9_])(public|open)(?![A-Za-z0-9_])')

# `### `Surface.approxWithDetails(a:b:)`` -> owning type hint for a doc declaration.
HEADING_RE = re.compile(r'^#{2,6}\s+(?P<text>.+?)\s*$')


def split_top_level(text, sep=','):
    """Split on `sep` at nesting depth zero (parens, brackets, angle brackets, strings)."""
    parts, depth, angle, buf, i, in_str = [], 0, 0, [], 0, False
    while i < len(text):
        c = text[i]
        if in_str:
            if c == '\\':
                buf.append(c)
                i += 1
                if i < len(text):
                    buf.append(text[i])
                    i += 1
                continue
            if c == '"':
                in_str = False
            buf.append(c)
            i += 1
            continue
        if c == '"':
            in_str = True
        elif c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
        elif c == '<':
            angle += 1
        elif c == '>' and angle > 0:
            angle -= 1
        if c == sep and depth == 0 and angle == 0:
            parts.append(''.join(buf))
            buf = []
        else:
            buf.append(c)
        i += 1
    parts.append(''.join(buf))
    return [p.strip() for p in parts if p.strip()]


def parse_params(param_text):
    """[(label, default_or_None)] for one parameter list, in declared order."""
    params = []
    for raw in split_top_level(param_text):
        cleaned = re.sub(r'^(?:@\w+(?:\([^)]*\))?\s+|inout\s+|isolated\s+)+', '', raw).strip()
        head, _, tail = cleaned.partition(':')
        if not tail:
            continue  # not `label: Type` shaped (e.g. a lone `...`)
        names = head.split()
        if not names:
            continue
        label = names[0]
        # `_ q1: Type` — the internal name is what tells three `_` positions apart in a report.
        internal = names[1] if len(names) > 1 else names[0]
        default = None
        m = re.search(r'(?<![=!<>])=(?![=])', tail)
        if m:
            default = tail[m.end():].strip() or None
        params.append((label, default, internal))
    return params


def param_desc(decl, i):
    """`_` renders identically three times over; say which one."""
    label, _, internal = decl['params'][i]
    if label == '_':
        return f'#{i + 1} `_ {internal}`'
    return f'`{label}:`'


def normalize_default(text):
    """Compare default literals modulo layout: `SIMD3(0, 0, 1)` == `SIMD3(0,0,1)`.

    Whitespace inside a string literal is kept, so `"a b"` never equals `"ab"`.
    """
    out, i, in_str = [], 0, False
    while i < len(text):
        c = text[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < len(text):
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
        elif not c.isspace():
            out.append(c)
        i += 1
    return ''.join(out)


def strip_line_comment(line):
    """Drop a trailing `//` comment. A `//` inside a string literal is not a comment.

    `tolerance: String,  // e.g. "0.1" or "0.1 M" for MMC` has quotes *after* the `//`, so a
    regex guarded by a lookahead for a following quote keeps the comment and corrupts the next
    parameter's label. This scans instead.
    """
    i, in_str = 0, False
    while i < len(line):
        c = line[i]
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == '/' and i + 1 < len(line) and line[i + 1] == '/':
            return line[:i].rstrip()
        i += 1
    return line


def code_skeleton(line, in_block):
    """Blank out strings and comments so brace counting sees only code.

    Returns (skeleton, still_in_block_comment). A `{` inside a string literal or a doc comment is
    not a scope, and counting it desynchronises the enclosing-type stack for the rest of the file.
    """
    out, i, in_str = [], 0, False
    while i < len(line):
        c = line[i]
        if in_block:
            if c == '*' and i + 1 < len(line) and line[i + 1] == '/':
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        if c == '/' and i + 1 < len(line):
            if line[i + 1] == '/':
                break
            if line[i + 1] == '*':
                in_block = True
                i += 2
                continue
        out.append(c)
        i += 1
    return ''.join(out), in_block


def gather_decl(lines, start_idx):
    """Join lines from `start_idx` until the signature's parens balance. Returns (text, end)."""
    depth, buf, i = 0, [], start_idx
    started = False
    while i < len(lines) and i < start_idx + 40:
        line = strip_line_comment(lines[i])
        for c in line:
            if c == '(':
                depth += 1
                started = True
            elif c == ')':
                depth -= 1
        buf.append(line)
        i += 1
        if started and depth <= 0:
            break
    return ' '.join(buf), i


def extract_decls(text, source_label, want_public):
    """Yield dicts for every func/init/subscript declaration with a parameter list."""
    lines = text.split('\n')
    out = []
    type_stack = []
    brace_depth = 0
    pending_type = None
    in_block = False
    for idx, line in enumerate(lines):
        skeleton, next_block = code_skeleton(line, in_block)
        was_in_block = in_block
        in_block = next_block

        if not was_in_block:
            tm = TYPE_RE.match(skeleton)
            if tm:
                # `public extension Foo {` makes its members public without repeating the
                # keyword; `public struct Foo {` does not.
                access = (tm.group('access') or '').strip()
                # `public extension Foo { func bar() }` makes `bar` public without repeating the
                # keyword, and a protocol requirement takes the protocol's own access level.
                # `public struct Foo { func bar() }` does neither: there `bar` is internal.
                implied = (access in ('public', 'open')
                           and tm.group('kind') in ('extension', 'protocol'))
                pending_type = (tm.group('name'), implied)
            if pending_type and '{' in skeleton:
                type_stack.append((pending_type[0], brace_depth, pending_type[1]))
                pending_type = None

        brace_depth += skeleton.count('{') - skeleton.count('}')
        while type_stack and brace_depth <= type_stack[-1][1]:
            type_stack.pop()

        if was_in_block:
            continue
        m = DECL_RE.search(skeleton)
        if not m:
            continue
        # `.extrude(.init(profilePoints2D: ...))` in an example is a call, not a declaration.
        ks = m.start('kind')
        if ks > 0 and skeleton[ks - 1] == '.':
            continue
        if want_public:
            explicit_public = bool(PUBLIC_RE.search(skeleton))
            implied_public = (bool(type_stack) and type_stack[-1][2]
                              and not EXPLICIT_ACCESS_RE.search(skeleton))
            if not (explicit_public or implied_public):
                continue

        joined, _ = gather_decl(lines, idx)
        m2 = DECL_RE.search(joined)
        if not m2:
            continue
        open_paren = joined.index('(', m2.end() - 1)
        depth, j = 0, open_paren
        while j < len(joined):
            if joined[j] == '(':
                depth += 1
            elif joined[j] == ')':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if j >= len(joined):
            continue
        params = parse_params(joined[open_paren + 1:j])
        kind = m2.group('kind')
        name = m2.group('name') or kind
        if kind in ('init', 'subscript'):
            name = kind
        out.append({
            'name': name,
            'params': params,
            'labels': tuple(p[0] for p in params),
            'type': type_stack[-1][0] if type_stack else None,
            'file': source_label,
            'line': idx + 1,
        })
    return out


def doc_swift_blocks(text):
    """Yield (block_text, first_line_number, nearest_heading) for each fenced ```swift block."""
    lines = text.split('\n')
    blocks, i = [], 0
    # Heading *stack*, by level. A page section names the type its subsections belong to:
    # `CurveAdaptors.md` carries `## WireCurve` and `## EdgeCurve`, each holding an identically
    # titled `### points(count:)`. The nearest heading alone cannot tell those apart.
    stack = {}
    while i < len(lines):
        hm = HEADING_RE.match(lines[i])
        if hm:
            level = len(lines[i]) - len(lines[i].lstrip('#'))
            stack = {k: v for k, v in stack.items() if k < level}
            stack[level] = hm.group('text').strip().strip('`').strip()
        if re.match(r'^\s*```\s*swift\s*$', lines[i]):
            start = i + 1
            j = start
            while j < len(lines) and not re.match(r'^\s*```\s*$', lines[j]):
                j += 1
            chain = [stack[k] for k in sorted(stack)]
            blocks.append(('\n'.join(lines[start:j]), start + 1, chain))
            i = j + 1
            continue
        i += 1
    return blocks


def heading_type(heading):
    """`Surface.approxWithDetails(a:b:)` -> 'Surface'. None when the heading names no type."""
    if not heading:
        return None
    text = heading.split('(')[0].strip()
    words = text.split()
    if not words:
        return None
    text = words[-1]
    if '.' not in text:
        return None
    return text.rsplit('.', 1)[0]


def heading_bare_type(heading):
    """`## WireCurve` -> 'WireCurve'. A section heading that is just a type name.

    Only meaningful for an enclosing heading; a method-shaped one (`### points(count:)`) yields
    `points`, which matches no type and is harmless.
    """
    if not heading:
        return None
    text = heading.split('(')[0].strip()
    return text if re.fullmatch(r'[A-Za-z_][A-Za-z0-9_.]*', text) else None


def filename_type(path):
    """`docs/reference/Document-Persistence-IO.md` -> 'Document'.

    The page title's first hyphen-separated component is its principal type. Only a hint: a page
    documents types other than its title (`Shape-HLR-Geom.md` carries `Surface.approxWithDetails`),
    so it narrows only when it selects something.
    """
    return os.path.basename(path)[:-3].split('-')[0]


def type_matches(cand_type, hint):
    """Tolerate qualification on either side: `BRepGraph.Editor` vs `Editor`."""
    if not cand_type or not hint:
        return False
    if cand_type == hint:
        return True
    return cand_type.endswith('.' + hint) or hint.endswith('.' + cand_type)


class Report:
    """Buckets for one comparison run."""

    def __init__(self):
        self.changed = []       # docs and source both state a default, and they differ
        self.docs_only = []     # docs state one the source has not
        self.source_only = []   # source states one the docs omit
        self.unverified = []    # several candidates disagree and nothing picked one
        self.unmatched = []     # no declaration in Sources with this name and label list
        self.checked = 0
        self.matched = 0
        self.compared_decls = 0
        self.no_defaults_either_side = 0
        self.resolved_by = {'unique': 0, 'heading': 0, 'filename': 0, 'unnarrowed': 0}

    @property
    def drift_total(self):
        return len(self.changed) + len(self.docs_only) + len(self.source_only)


def source_decls_from(files):
    """files: {path: text} -> the public declarations they contain."""
    out = []
    for path in sorted(files):
        out.extend(extract_decls(files[path], path, want_public=True))
    return out


def doc_decls_from(files):
    """files: {path: markdown} -> [(decl, path, heading)] for every fenced-swift declaration."""
    out = []
    for path in sorted(files):
        for block, base_line, heading in doc_swift_blocks(files[path]):
            for d in extract_decls(block, path, want_public=False):
                d['line'] = base_line + d['line'] - 1
                out.append((d, path, heading))
    return out


def analyse(src_decls, doc_entries):
    """Compare every restated declaration against the declaration it documents."""
    by_key = {}
    for d in src_decls:
        by_key.setdefault((d['name'], d['labels']), []).append(d)

    rep = Report()
    for d, path, heading in doc_entries:
        candidates = by_key.get((d['name'], d['labels']), [])
        if not candidates:
            rep.unmatched.append((d, path))
            continue
        rep.matched += 1

        pool, how = candidates, 'unnarrowed'
        if len(candidates) == 1:
            how = 'unique'
        else:
            # Nearest heading first, then out through the enclosing sections, then the filename.
            # Each is only a hint and narrows only when it selects something, because a page
            # documents types other than its title (`Shape-HLR-Geom.md` carries
            # `Surface.approxWithDetails`).
            for hd in reversed(heading):
                for hint in (heading_type(hd), heading_bare_type(hd)):
                    narrowed = [c for c in candidates if type_matches(c['type'], hint)]
                    if narrowed:
                        pool, how = narrowed, 'heading'
                        break
                if how == 'heading':
                    break
            if how != 'heading':
                ft = filename_type(path)
                narrowed = [c for c in candidates if type_matches(c['type'], ft)]
                if narrowed:
                    pool, how = narrowed, 'filename'
        rep.resolved_by[how] += 1

        n = len(d['params'])
        doc_has = any(p[1] is not None for p in d['params'])
        pool_has = any(c['params'][i][1] is not None for c in pool for i in range(n))
        if not doc_has and not pool_has:
            # Neither side states a default anywhere: nothing this gate can compare.
            rep.no_defaults_either_side += 1
            continue
        rep.compared_decls += 1

        # Ambiguity is judged for EVERY pool holding more than one candidate, not only for a pool
        # nothing narrowed. A heading or filename picks a *type*; a type can still hold two
        # overloads, and deprecating by keeping the old signature verbatim -- defaults included --
        # is the ordinary way to deprecate. Deciding such a pool by "some candidate matched
        # cleanly" is the same unsound reasoning that let a cross-type default through.
        #
        # When a hint did narrow, a candidate that merely *lacks* a default at some position is
        # not evidence of disagreement: the doc's own defaults still pick the overload that has
        # one. So `None` is skipped there, and only two competing *values* count as ambiguous.
        if len(pool) > 1:
            ambiguous = False
            for i in range(n):
                vals = set()
                for c in pool:
                    sv = c['params'][i][1]
                    if sv is None:
                        if how == 'unnarrowed':
                            vals.add(None)
                        continue
                    vals.add(normalize_default(sv))
                if len(vals) > 1:
                    ambiguous = True
                    break
            if ambiguous:
                rep.unverified.append((d, path, pool))
                continue

        def diffs(cand):
            # Positional, not keyed by label: a signature may repeat `_` several times
            # (`circlesTangentTo(_ c1:, _ q1:, _ c2:, ...)`), and a label-keyed lookup collapses
            # those to one entry, inventing drift for every `_` but the last. Both sides matched
            # on the ordered label tuple, so index i is the same parameter on both.
            ch, only_d, only_s = [], [], []
            for i in range(n):
                dv = d['params'][i][1]
                sv = cand['params'][i][1]
                if dv is not None and sv is None:
                    only_d.append((i, dv))
                elif dv is None and sv is not None:
                    only_s.append((i, sv))
                elif dv is not None and sv is not None and \
                        normalize_default(sv) != normalize_default(dv):
                    ch.append((i, dv, sv))
            return ch, only_d, only_s

        results = [(c,) + diffs(c) for c in pool]
        clean = [r for r in results if not r[1] and not r[2] and not r[3]]
        best = min(results,
                   key=lambda r: (len(r[1]) + len(r[2]) + len(r[3]), r[0]['file'], r[0]['line']))
        ref = clean[0][0] if clean else best[0]
        rep.checked += sum(1 for i in range(n)
                           if d['params'][i][1] is not None or ref['params'][i][1] is not None)
        if clean:
            continue

        cand, ch, only_d, only_s = best
        for i, dv, sv in ch:
            rep.changed.append((d, path, cand, i, dv, sv, pool))
        for i, dv in only_d:
            rep.docs_only.append((d, path, cand, i, dv, pool))
        for i, sv in only_s:
            rep.source_only.append((d, path, cand, i, sv, pool))
    return rep


def _cands(pool):
    return ', '.join(f'{c["type"]} ({c["file"]}:{c["line"]})' for c in pool)


def print_report(rep, lenient):
    total = rep.matched + len(rep.unmatched)
    print(f'restated declarations:               {total} '
          f'({rep.matched} matched to a source declaration, '
          f'{len(rep.unmatched)} with no counterpart)')
    print(f'  owning declaration resolved by:    '
          f'{rep.resolved_by["unique"]} unique, {rep.resolved_by["heading"]} heading, '
          f'{rep.resolved_by["filename"]} filename, {rep.resolved_by["unnarrowed"]} unnarrowed')
    print(f'  carrying a default on either side: {rep.compared_decls} '
          f'({rep.no_defaults_either_side} state none on either side, nothing to compare)')
    print(f'individual defaults compared:        {rep.checked}')
    print(f'drifted (default changed):           {len(rep.changed)}')
    print(f'drifted (stated only in docs):       {len(rep.docs_only)}')
    print(f'drifted (stated only in source):     {len(rep.source_only)}'
          f'{"  [warning only]" if lenient else ""}')
    print(f'unverified (ambiguous, not checked): {len(rep.unverified)}')

    if rep.changed:
        print('\nCHANGED - docs and source both state a default and they differ:')
        for d, path, cand, i, dv, sv, pool in rep.changed:
            print(f'  {path}:{d["line"]}')
            print(f'    {d["name"]}(... {param_desc(d, i)}) docs `{dv}` vs '
                  f'{cand["file"]}:{cand["line"]} `{sv}`')
            if len(pool) > 1:
                print(f'      candidates: {_cands(pool)}')
    if rep.docs_only:
        print('\nSTATED ONLY IN DOCS - the source parameter has no default, so the argument is '
              'required:')
        for d, path, cand, i, dv, pool in rep.docs_only:
            print(f'  {path}:{d["line"]}  {d["name"]}(... {param_desc(d, i)} = {dv})  '
                  f'source {cand["file"]}:{cand["line"]}')
            if len(pool) > 1:
                print(f'      candidates: {_cands(pool)}')
    if rep.source_only:
        print('\nSTATED ONLY IN SOURCE - the docs omit a default, so the argument reads as '
              'required when it is optional:')
        for d, path, cand, i, sv, pool in rep.source_only:
            print(f'  {path}:{d["line"]}  {d["name"]}(... {param_desc(d, i)})  source has '
                  f'`= {sv}` at {cand["file"]}:{cand["line"]}')
            if len(pool) > 1:
                print(f'      candidates: {_cands(pool)}')
    if rep.unverified:
        print('\nUNVERIFIED - several declarations share this name and label list and they '
              'disagree about a default, so this restatement cannot be adjudicated:')
        for d, path, pool in rep.unverified:
            print(f'  {path}:{d["line"]}  {d["name"]} - candidates: {_cands(pool)}')


# --- self-test -------------------------------------------------------------------------------
# Committed because three gate scripts on this branch have now shipped confidently wrong. Each
# case is a drift shape that reached this script through review; none of them touch the real tree.

SELF_TEST_CASES = [
    (
        'clean pair reports nothing',
        {'Sources/OCCTSwift/A.swift': 'extension Surface {\n'
                                      '    public func fit(tol: Double = 1e-3) -> Int { 0 }\n}\n'},
        {'docs/reference/Surface.md': '### `Surface.fit(tol:)`\n\n```swift\n'
                                      'public func fit(tol: Double = 1e-3) -> Int\n```\n'},
        {},
    ),
    (
        'changed default on a uniquely-named method (the #626 shape)',
        {'Sources/OCCTSwift/A.swift': 'extension Surface {\n'
                                      '    public func fit(tol: Double = 1e-9) -> Int { 0 }\n}\n'},
        {'docs/reference/Surface.md': '### `Surface.fit(tol:)`\n\n```swift\n'
                                      'public func fit(tol: Double = 1e-3) -> Int\n```\n'},
        {'changed': 1},
    ),
    (
        'changed default across an overloaded name resolved by filename',
        {'Sources/OCCTSwift/A.swift':
            'extension Document {\n    public func writeOBJ(to url: URL, deflection: Double = 1.0)'
            ' -> Bool { true }\n}\n'
            'extension Shape {\n    public func writeOBJ(to url: URL, deflection: Double = 0.1)'
            ' -> Bool { true }\n}\n'},
        {'docs/reference/Document-Persistence-IO.md':
            '### `writeOBJ(to:deflection:)`\n\n```swift\n'
            'public func writeOBJ(to url: URL, deflection: Double = 0.1) -> Bool\n```\n'},
        {'changed': 1},
    ),
    (
        'default stated only in docs',
        {'Sources/OCCTSwift/A.swift': 'extension Surface {\n'
                                      '    public func fit(tol: Double) -> Int { 0 }\n}\n'},
        {'docs/reference/Surface.md': '### `Surface.fit(tol:)`\n\n```swift\n'
                                      'public func fit(tol: Double = 1e-3) -> Int\n```\n'},
        {'docs_only': 1},
    ),
    (
        'default stated only in source, docs restating another default',
        {'Sources/OCCTSwift/A.swift':
            'extension Surface {\n    public func fit(tol: Double = 1e-3, n: Int = 4)'
            ' -> Int { 0 }\n}\n'},
        {'docs/reference/Surface.md': '### `Surface.fit(tol:n:)`\n\n```swift\n'
                                      'public func fit(tol: Double, n: Int = 4) -> Int\n```\n'},
        {'source_only': 1},
    ),
    (
        'source-side addition where the page restates NO default at all',
        {'Sources/OCCTSwift/A.swift': 'extension Surface {\n'
                                      '    public func fit(tol: Double = 5e-9) -> Int { 0 }\n}\n'},
        {'docs/reference/Surface.md': '### `Surface.fit(tol:)`\n\n```swift\n'
                                      'public func fit(tol: Double) -> Int\n```\n'},
        {'source_only': 1},
    ),
    (
        'unnarrowable ambiguous pool is surfaced, not silently accepted',
        {'Sources/OCCTSwift/A.swift':
            'extension Document {\n    public func writeOBJ(to url: URL, deflection: Double = 1.0)'
            ' -> Bool { true }\n}\n'
            'extension Shape {\n    public func writeOBJ(to url: URL, deflection: Double = 0.1)'
            ' -> Bool { true }\n}\n'},
        {'docs/reference/Concurrency.md':
            '### `writeOBJ(to:deflection:)`\n\n```swift\n'
            'public func writeOBJ(to url: URL, deflection: Double = 1.0) -> Bool\n```\n'},
        {'unverified': 1},
    ),
    (
        'narrowed pool whose two overloads DISAGREE is unverified, not decided by a clean match',
        {'Sources/OCCTSwift/A.swift':
            'extension ZZProbe {\n'
            '    @available(*, deprecated)\n'
            '    public func zzFit(tol: Float = 1e-3) -> Int { 0 }\n'
            '    public func zzFit(tol: Double = 1e-9) -> Int { 0 }\n}\n'},
        {'docs/reference/ZZProbe.md': '### `ZZProbe.zzFit(tol:)`\n\n```swift\n'
                                      'public func zzFit(tol: Float = 1e-3) -> Int\n```\n'},
        {'unverified': 1},
    ),
    (
        'narrowed pool whose deprecated twin merely lacks a default still verifies',
        {'Sources/OCCTSwift/A.swift':
            'extension Curve3D {\n'
            '    public func continuityWith(order: ContinuityClass = .c2) -> Int { 0 }\n'
            '    @available(*, deprecated)\n'
            '    public func continuityWith(order: Int) -> Int { 0 }\n}\n'},
        {'docs/reference/Curve3D-Analysis.md':
            '### `continuityWith(order:)`\n\n```swift\n'
            'public func continuityWith(order: ContinuityClass = .c2) -> Int\n```\n'},
        {},
    ),
    (
        'each repeated `_` position is watched independently',
        {'Sources/OCCTSwift/A.swift':
            'extension Curve2D {\n    public static func tangents(_ a: Int = 1, _ b: Int = 2,'
            ' _ c: Int = 3) -> Int { 0 }\n}\n'},
        {'docs/reference/Curve2D.md':
            '### `Curve2D.tangents(_:_:_:)`\n\n```swift\n'
            'public static func tangents(_ a: Int = 1, _ b: Int = 9, _ c: Int = 3) -> Int\n```\n'},
        {'changed': 1},
    ),
    (
        'a protocol requirement takes its protocol access level',
        {'Sources/OCCTSwift/A.swift':
            'public protocol ImportProgress {\n'
            '    func progress(fraction: Double, step: String = "load")\n}\n'},
        {'docs/reference/Concurrency.md':
            '### `ImportProgress.progress(fraction:step:)`\n\n```swift\n'
            'func progress(fraction: Double, step: String = "start")\n```\n'},
        # Without the rule the requirement is not public, the restatement lands in `unmatched`,
        # and the changed default goes unreported.
        {'changed': 1},
    ),
    (
        'an enclosing section heading names the type the nearest heading omits',
        {'Sources/OCCTSwift/A.swift':
            'extension WireCurve {\n    public func points(count: Int) -> [Int] { [] }\n}\n'
            'extension Edge {\n    public func points(count: Int? = nil) -> [Int] { [] }\n}\n'},
        {'docs/reference/CurveAdaptors.md':
            '## WireCurve\n\n### `points(count:)`\n\n```swift\n'
            'public func points(count: Int = 5) -> [Int]\n```\n'},
        # Without the outward walk nothing names a type -- the filename is `CurveAdaptors` -- so
        # the pool stays at two disagreeing candidates and this reads as `unverified` instead.
        {'docs_only': 1},
    ),
    (
        'a `.init(` call site in an example is not a declaration',
        {'Sources/OCCTSwift/A.swift': 'extension Surface {\n'
                                      '    public func fit(tol: Double = 1e-3) -> Int { 0 }\n}\n'},
        {'docs/reference/Surface.md':
            '### `Surface.fit(tol:)`\n\n```swift\n'
            'public func fit(tol: Double = 1e-3) -> Int\n```\n\n'
            '- **Example:**\n  ```swift\n  let s = FeatureSpec.extrude(.init(profile: pts,'
            ' origin: .zero))\n  ```\n'},
        {},
    ),
]


def self_test():
    """Run the drift battery in memory. Returns the number of failing cases."""
    failures = 0
    for name, src_files, doc_files, expect in SELF_TEST_CASES:
        rep = analyse(source_decls_from(src_files), doc_decls_from(doc_files))
        # `unmatched` is asserted too, not just the four drift buckets. Without it a case can go
        # green for the wrong reason: the `.init(` case passed with its call-site guard removed,
        # because the stray declaration merely landed in a bucket nothing was watching.
        got = {
            'changed': len(rep.changed),
            'docs_only': len(rep.docs_only),
            'source_only': len(rep.source_only),
            'unverified': len(rep.unverified),
            'unmatched': len(rep.unmatched),
        }
        want = {k: expect.get(k, 0) for k in got}
        if got == want:
            print(f'  PASS  {name}')
        else:
            failures += 1
            print(f'  FAIL  {name}')
            print(f'          expected {want}')
            print(f'          got      {got}')
    print(f'\nself-test: {len(SELF_TEST_CASES) - failures} passed, {failures} failed')
    return failures


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--quiet', action='store_true', help='exit status only')
    ap.add_argument('--lenient', action='store_true',
                    help='report source-only omissions without failing the run')
    ap.add_argument('--self-test', action='store_true',
                    help='run the built-in drift battery instead of scanning the tree')
    ap.add_argument('--list-unmatched', action='store_true',
                    help='list restatements with no declaration in Sources')
    args = ap.parse_args()

    if args.self_test:
        return 1 if self_test() else 0

    src_files, doc_files = {}, {}
    for path in sorted(glob.glob(SRC_GLOB)):
        with open(path, encoding='utf-8') as fh:
            src_files[path] = fh.read()
    for path in sorted(glob.glob(DOCS_GLOB)):
        with open(path, encoding='utf-8') as fh:
            doc_files[path] = fh.read()

    rep = analyse(source_decls_from(src_files), doc_decls_from(doc_files))

    unmatched_grew = len(rep.unmatched) > EXPECTED_UNMATCHED
    if not args.quiet:
        print_report(rep, args.lenient)
        if unmatched_grew or args.list_unmatched:
            print(f'\nUNMATCHED — no declaration in Sources/OCCTSwift with this name and label '
                  f'list (baseline {EXPECTED_UNMATCHED}, now {len(rep.unmatched)}):')
            for d, path in rep.unmatched:
                print(f'  {path}:{d["line"]}  {d["name"]}({",".join(d["labels"])})')
        if unmatched_grew:
            print(f'\n  A restatement stops being compared the moment its labels stop matching '
                  f'any\n  declaration, so growth here is drift that would otherwise pass '
                  f'silently. Check\n  each new entry, then raise EXPECTED_UNMATCHED if it is '
                  f'genuinely uncomparable.')

    fail = bool(rep.changed) or bool(rep.docs_only) or bool(rep.unverified) or unmatched_grew
    if not args.lenient:
        fail = fail or bool(rep.source_only)
    return 1 if fail else 0


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
