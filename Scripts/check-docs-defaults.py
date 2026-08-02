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

`--lenient` drops `source-only` to a warning, for a tree that has not finished paying that down.
Layout is not drift: `SIMD3(0, 0, 1)` and `SIMD3(0,0,1)` compare equal, whitespace inside a string
literal excepted.

## Picking the right declaration to compare against

Several declarations can share one name and parameter-label list — `writeOBJ(to:deflection:)` is
both `Document.writeOBJ` (deflection 1.0) and `Shape.writeOBJ` (0.1), and `approximated` exists on
`Curve3D`, `Curve2D` and `Surface`. Comparing against the wrong one is how the first version of
this script let a page state `Shape.writeOBJ`'s default for `Document.writeOBJ` and still exit 0 —
the #626 defect shape passing through the gate built to catch it.

So the owning type is resolved in three steps, most specific first:

  1. the heading's own qualifier — ``### `Surface.approxWithDetails(...)` ``;
  2. failing that, the page filename — `Document-Persistence-IO.md` -> `Document`;
  3. failing that, every candidate.

Steps 1 and 2 narrow only when they select a non-empty set, because a page documents types other
than its title: `Shape-HLR-Geom.md` carries `Surface.approxWithDetails`. Where nothing narrows to
a single declaration and the remaining candidates disagree about a default the doc states, the
comparison cannot be trusted either way; those are counted and listed as `unverified` and fail the
run, so the blind spot is visible instead of invisible.

A doc declaration matching no source declaration is listed under `unmatched` and never fails: the
tree documents nested types, bridge C structs and helper functions defined inside example snippets.

Usage (from the repo root):

    python3 Scripts/check-docs-defaults.py            # report drifted defaults
    python3 Scripts/check-docs-defaults.py --verbose  # also list every default checked
    python3 Scripts/check-docs-defaults.py --lenient  # source-only omissions warn instead of fail
    python3 Scripts/check-docs-defaults.py --quiet    # exit status only

Exit status is 1 when any default disagrees, so this can gate a commit. Nothing in this tree runs
it yet; wiring the gate scripts into CI is #625, which covers all of them together.
"""
import argparse
import glob
import os
import re
import sys

SRC_GLOB = 'Sources/OCCTSwift/*.swift'
DOCS_GLOB = 'docs/reference/*.md'

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
        default = None
        m = re.search(r'(?<![=!<>])=(?![=])', tail)
        if m:
            default = tail[m.end():].strip() or None
        params.append((label, default))
    return params


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
                implied = access in ('public', 'open') and tm.group('kind') == 'extension'
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
    heading = None
    while i < len(lines):
        hm = HEADING_RE.match(lines[i])
        if hm:
            heading = hm.group('text').strip().strip('`').strip()
        if re.match(r'^\s*```\s*swift\s*$', lines[i]):
            start = i + 1
            j = start
            while j < len(lines) and not re.match(r'^\s*```\s*$', lines[j]):
                j += 1
            blocks.append(('\n'.join(lines[start:j]), start + 1, heading))
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


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--verbose', action='store_true', help='list every default compared')
    ap.add_argument('--quiet', action='store_true', help='exit status only')
    ap.add_argument('--lenient', action='store_true',
                    help='report source-only omissions without failing the run')
    args = ap.parse_args()

    src_decls = []
    for path in sorted(glob.glob(SRC_GLOB)):
        with open(path, encoding='utf-8') as fh:
            src_decls.extend(extract_decls(fh.read(), path, want_public=True))

    by_key = {}
    for d in src_decls:
        by_key.setdefault((d['name'], d['labels']), []).append(d)

    changed, docs_only, source_only, unverified, unmatched = [], [], [], [], []
    checked = matched = 0
    resolved_by = {'unique': 0, 'heading': 0, 'filename': 0, 'unnarrowed': 0}

    for path in sorted(glob.glob(DOCS_GLOB)):
        with open(path, encoding='utf-8') as fh:
            text = fh.read()
        for block, base_line, heading in doc_swift_blocks(text):
            for d in extract_decls(block, path, want_public=False):
                if not any(p[1] for p in d['params']):
                    continue  # nothing to compare
                d['line'] = base_line + d['line'] - 1
                candidates = by_key.get((d['name'], d['labels']), [])
                if not candidates:
                    unmatched.append(d)
                    continue
                matched += 1

                pool, how = candidates, 'unnarrowed'
                if len(candidates) == 1:
                    how = 'unique'
                else:
                    ht = heading_type(heading)
                    narrowed = [c for c in candidates if type_matches(c['type'], ht)]
                    if narrowed:
                        pool, how = narrowed, 'heading'
                    else:
                        ft = filename_type(path)
                        narrowed = [c for c in candidates if type_matches(c['type'], ft)]
                        if narrowed:
                            pool, how = narrowed, 'filename'
                resolved_by[how] += 1
                checked += sum(1 for _, dv in d['params'] if dv is not None)

                def diffs(cand):
                    # Positional, not keyed by label: a signature may repeat `_` several times
                    # (`circlesTangentTo(_ c1:, _ q1:, _ c2:, ...)`), and a label-keyed lookup
                    # collapses those to one entry, inventing drift for every `_` but the last.
                    # Both sides matched on the ordered label tuple, so index i is the same
                    # parameter on both.
                    ch, only_d, only_s = [], [], []
                    for i, (lab, dv) in enumerate(d['params']):
                        sv = cand['params'][i][1]
                        if dv is not None and sv is None:
                            only_d.append((lab, dv))
                        elif dv is None and sv is not None:
                            only_s.append((lab, sv))
                        elif dv is not None and sv is not None and \
                                normalize_default(sv) != normalize_default(dv):
                            ch.append((lab, dv, sv))
                    return ch, only_d, only_s

                results = [(c,) + diffs(c) for c in pool]

                # Checked BEFORE accepting a clean match, not after. When neither the heading nor
                # the filename supplied any type evidence and the candidates disagree about a
                # default, agreeing with one of them proves nothing about the intended one — that
                # is exactly how a page stating `Shape.writeOBJ`'s 0.1 for `Document.writeOBJ`
                # passed. Deciding it on "some candidate matched" is the blind spot, so say so
                # instead. A pool narrowed to one type may still hold several overloads (a
                # deprecated twin carrying no defaults); there the doc's own defaults do pick one,
                # so that stays a verified match.
                if how == 'unnarrowed' and len(pool) > 1:
                    spread = [set() for _ in d['params']]
                    for c in pool:
                        for i in range(len(d['params'])):
                            sv = c['params'][i][1]
                            spread[i].add(normalize_default(sv) if sv else None)
                    if any(len(s) > 1 for s in spread):
                        unverified.append((path, d['line'], d['name'], pool))
                        continue

                clean = [r for r in results if not r[1] and not r[2] and not r[3]]
                if clean:
                    if args.verbose and not args.quiet:
                        print(f'  ok   {path}:{d["line"]} {d["name"]}({",".join(d["labels"])})')
                    continue

                # Deterministic pick, so a report never names an arbitrary sibling's file.
                cand, ch, only_d, only_s = min(
                    results,
                    key=lambda r: (len(r[1]) + len(r[2]) + len(r[3]), r[0]['file'], r[0]['line']))
                for lab, dv, sv in ch:
                    changed.append((path, d['line'], cand, d['name'], lab, dv, sv))
                for lab, dv in only_d:
                    docs_only.append((path, d['line'], cand, d['name'], lab, dv))
                for lab, sv in only_s:
                    source_only.append((path, d['line'], cand, d['name'], lab, sv))

    if not args.quiet:
        total = matched + len(unmatched)
        print(f'restated declarations with defaults: {total} '
              f'({matched} matched to a source declaration, '
              f'{len(unmatched)} with no counterpart)')
        print(f'  owning declaration resolved by:    '
              f'{resolved_by["unique"]} unique, {resolved_by["heading"]} heading, '
              f'{resolved_by["filename"]} filename, {resolved_by["unnarrowed"]} unnarrowed')
        print(f'individual defaults compared:        {checked}')
        print(f'drifted (default changed):           {len(changed)}')
        print(f'drifted (stated only in docs):       {len(docs_only)}')
        print(f'drifted (stated only in source):     {len(source_only)}'
              f'{"  [warning only]" if args.lenient else ""}')
        print(f'unverified (ambiguous, not checked): {len(unverified)}')

        if changed:
            print('\nCHANGED — docs and source both state a default and they differ:')
            for path, line, cand, name, lab, dv, sv in changed:
                print(f'  {path}:{line}')
                print(f'    {name}(… {lab}:) docs `{dv}` vs {cand["file"]}:{cand["line"]} `{sv}`')
        if docs_only:
            print('\nSTATED ONLY IN DOCS — the source parameter has no default, so the argument '
                  'is required:')
            for path, line, cand, name, lab, dv in docs_only:
                print(f'  {path}:{line}  {name}(… {lab}: = {dv})  '
                      f'source {cand["file"]}:{cand["line"]}')
        if source_only:
            print('\nSTATED ONLY IN SOURCE — the docs omit a default, so the argument reads as '
                  'required when it is optional:')
            for path, line, cand, name, lab, sv in source_only:
                print(f'  {path}:{line}  {name}(… {lab}:)  source has `= {sv}` at '
                      f'{cand["file"]}:{cand["line"]}')
        if unverified:
            print('\nUNVERIFIED — several declarations share this name and label list, nothing '
                  'narrowed to one, and they disagree about a default:')
            for path, line, name, pool in unverified:
                where = ', '.join(f'{c["type"]} ({c["file"]}:{c["line"]})' for c in pool)
                print(f'  {path}:{line}  {name} — candidates: {where}')
        if args.verbose and unmatched:
            print('\nUNMATCHED — no declaration in Sources/OCCTSwift (not an error):')
            for d in unmatched:
                print(f'  {d["file"]}:{d["line"]}  {d["name"]}({",".join(d["labels"])})')

    fail = bool(changed) or bool(docs_only) or bool(unverified)
    if not args.lenient:
        fail = fail or bool(source_only)
    return 1 if fail else 0


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
