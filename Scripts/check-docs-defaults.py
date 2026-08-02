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
fenced-swift declarations, finds the matching `public` declaration in `Sources/OCCTSwift`, and
compares the default of each parameter the two have in common.

Only a *disagreement* is an error: both sides state a default for the same parameter and the two
literals differ. The two asymmetric cases are reported separately and do not fail the run, because
each has a legitimate form:

  - docs state a default the source does not have (`--strict` promotes this to an error; it is
    almost always wrong, but a doc may be describing a protocol requirement or a shim);
  - docs omit a default the source has, which is ordinary abbreviation.

A doc declaration that matches no source declaration is listed under `unmatched` and never fails:
the tree documents nested types, bridge C structs and illustrative pseudo-signatures that have no
`public` counterpart in `Sources/OCCTSwift`.

Where several source declarations share one name and parameter-label list (`approximated` exists
on `Curve3D`, `Curve2D` and `Surface`), the doc heading's `Type.` prefix picks one when it has
them; otherwise the doc is accepted if it agrees with *any* candidate, so ambiguity never
manufactures a failure.

Usage (from the repo root):

    python3 Scripts/check-docs-defaults.py           # report drifted defaults
    python3 Scripts/check-docs-defaults.py --verbose # also list every default checked
    python3 Scripts/check-docs-defaults.py --strict  # also fail on docs-only defaults
    python3 Scripts/check-docs-defaults.py --quiet   # exit status only

Exit status is 1 when any default disagrees, so this can gate a commit.
"""
import argparse
import glob
import os
import re
import sys

SRC_GLOB = 'Sources/OCCTSwift/*.swift'
DOCS_GLOB = 'docs/reference/*.md'

# A declaration this script can compare: it has a parameter list with defaults in it.
DECL_RE = re.compile(
    r'\b(?:public\s+|open\s+)?'
    r'(?:static\s+|class\s+|final\s+|mutating\s+|override\s+|convenience\s+)*'
    r'(?P<kind>func|init)\b'
    r'(?P<gen>\s*<[^>]*>)?'
    r'\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)?'
    r'(?P<optional>\?)?'
    r'\s*\('
)

# Enclosing-type tracker for Sources: `extension Surface {`, `public struct Foo {`, ...
TYPE_RE = re.compile(
    r'^\s*(?P<access>public\s+|internal\s+|private\s+|fileprivate\s+|open\s+)?'
    r'(?:final\s+)?(?P<kind>extension|struct|class|enum|actor|protocol)\s+'
    r'(?P<name>[A-Za-z_][A-Za-z0-9_.]*)'
)

# An explicit access modifier on the member itself overrides what the container implies.
EXPLICIT_ACCESS_RE = re.compile(r'\b(private|fileprivate|internal)\b')

# `### `Surface.approxWithDetails(tolerance:...)`` -> owning type hint for a doc declaration.
HEADING_RE = re.compile(r'^#{2,4}\s+`?(?P<text>[^`\n]+)`?\s*$')


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
            # only count as a generic bracket when it looks like one
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
        # attributes/modifiers Swift allows before the label
        cleaned = re.sub(r'^(?:@\w+(?:\([^)]*\))?\s+|inout\s+|isolated\s+)+', '', raw).strip()
        head, _, tail = cleaned.partition(':')
        if not tail:
            continue  # not `label: Type` shaped (e.g. a lone `...`)
        names = head.split()
        if not names:
            continue
        label = names[0]
        # default is everything after a top-level `=` in the type part
        default = None
        eq_parts = split_top_level(tail, '=')
        if len(eq_parts) >= 2 and '=' in tail:
            # guard against `==` or default-less generic constraints
            m = re.search(r'(?<![=!<>])=(?![=])', tail)
            if m:
                default = tail[m.end():].strip()
        params.append((label, default or None))
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
    """Yield dicts for every func/init declaration with a parameter list."""
    lines = text.split('\n')
    out = []
    type_stack = []
    brace_depth = 0
    pending_type = None
    for idx, line in enumerate(lines):
        tm = TYPE_RE.match(line)
        if tm:
            # `public extension Foo {` makes its members public without repeating the keyword;
            # `public struct Foo {` does not. Only the extension form implies public members.
            implied = bool(tm.group('access')) and \
                tm.group('access').strip() in ('public', 'open') and \
                tm.group('kind') == 'extension'
            pending_type = (tm.group('name'), implied)
        if pending_type and '{' in line:
            type_stack.append((pending_type[0], brace_depth, pending_type[1]))
            pending_type = None
        opens = line.count('{')
        closes = line.count('}')
        brace_depth += opens - closes
        while type_stack and brace_depth <= type_stack[-1][1]:
            type_stack.pop()

        m = DECL_RE.search(line)
        if not m:
            continue
        if want_public:
            explicit_public = 'public' in line or 'open' in line
            implied_public = (bool(type_stack) and type_stack[-1][2]
                              and not EXPLICIT_ACCESS_RE.search(line))
            if not (explicit_public or implied_public):
                continue
        # skip a call site that happens to contain `func` in a comment/string
        if line.lstrip().startswith(('//', '*', '///')):
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
        name = m2.group('name') or 'init'
        if m2.group('kind') == 'init':
            name = 'init'
        out.append({
            'name': name,
            'params': params,
            'labels': tuple(p[0] for p in params),
            'type': type_stack[-1][0] if type_stack else None,
            'file': source_label,
            'line': idx + 1,
            'text': ' '.join(joined.split()),
        })
    return out


def doc_swift_blocks(text):
    """Yield (block_text, first_line_number) for each fenced ```swift block."""
    lines = text.split('\n')
    blocks, i = [], 0
    heading = None
    while i < len(lines):
        hm = HEADING_RE.match(lines[i])
        if hm:
            heading = hm.group('text').strip().strip('`')
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
    if '.' in text:
        return text.rsplit('.', 1)[0].split()[-1]
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--verbose', action='store_true', help='list every default compared')
    ap.add_argument('--quiet', action='store_true', help='exit status only')
    ap.add_argument('--strict', action='store_true',
                    help='also fail when docs state a default the source does not have')
    args = ap.parse_args()

    src_decls = []
    for path in sorted(glob.glob(SRC_GLOB)):
        with open(path, encoding='utf-8') as fh:
            src_decls.extend(extract_decls(fh.read(), path, want_public=True))

    by_key = {}
    for d in src_decls:
        by_key.setdefault((d['name'], d['labels']), []).append(d)

    drifted, docs_only, unmatched, checked, compared_decls = [], [], [], 0, 0
    for path in sorted(glob.glob(DOCS_GLOB)):
        with open(path, encoding='utf-8') as fh:
            text = fh.read()
        for block, base_line, heading in doc_swift_blocks(text):
            for d in extract_decls(block, path, want_public=False):
                # only a restated *declaration* carries defaults worth checking
                if not any(p[1] for p in d['params']):
                    continue
                d['line'] = base_line + d['line'] - 1
                candidates = by_key.get((d['name'], d['labels']), [])
                if not candidates:
                    unmatched.append(d)
                    continue
                htype = heading_type(heading)
                narrowed = [c for c in candidates if htype and c['type'] == htype]
                pool = narrowed or candidates
                compared_decls += 1

                # accept if the doc agrees with any candidate in the pool
                def diffs_against(cand):
                    src_map = dict(cand['params'])
                    bad, only = [], []
                    for label, dv in d['params']:
                        if dv is None:
                            continue
                        sv = src_map.get(label)
                        if sv is None:
                            only.append((label, dv))
                        elif normalize_default(sv) != normalize_default(dv):
                            bad.append((label, dv, sv))
                    return bad, only

                results = [(c,) + diffs_against(c) for c in pool]
                clean = [r for r in results if not r[1] and not r[2]]
                if clean:
                    checked += sum(1 for p in d['params'] if p[1])
                    if args.verbose and not args.quiet:
                        print(f'  ok   {path}:{d["line"]} {d["name"]}({",".join(d["labels"])})')
                    continue
                # report against the best candidate (fewest disagreements)
                cand, bad, only = min(results, key=lambda r: (len(r[1]), len(r[2])))
                checked += sum(1 for p in d['params'] if p[1])
                for label, dv, sv in bad:
                    drifted.append((path, d['line'], cand, d['name'], label, dv, sv,
                                    len(pool) > 1))
                for label, dv in only:
                    docs_only.append((path, d['line'], cand, d['name'], label, dv))

    if not args.quiet:
        print(f'restated declarations with defaults: {compared_decls + len(unmatched)} '
              f'({compared_decls} matched to a source declaration, '
              f'{len(unmatched)} with no `public` counterpart)')
        print(f'individual defaults compared:        {checked}')
        print(f'drifted:                             {len(drifted)}')
        print(f'stated only in docs:                 {len(docs_only)}')
        if drifted:
            print('\nDRIFTED — docs and source both state a default and they differ:')
            for path, line, cand, name, label, dv, sv, ambiguous in drifted:
                note = '  (ambiguous overload set)' if ambiguous else ''
                print(f'  {path}:{line}')
                print(f'    {name}(… {label}:) docs `{dv}` vs '
                      f'{cand["file"]}:{cand["line"]} `{sv}`{note}')
        if docs_only:
            print('\nSTATED ONLY IN DOCS — the source parameter has no default:')
            for path, line, cand, name, label, dv in docs_only:
                print(f'  {path}:{line}  {name}(… {label}: = {dv})  '
                      f'source {cand["file"]}:{cand["line"]}')
        if args.verbose and unmatched:
            print('\nUNMATCHED — no `public` declaration in Sources/OCCTSwift (not an error):')
            for d in unmatched:
                print(f'  {d["file"]}:{d["line"]}  {d["name"]}({",".join(d["labels"])})')

    fail = bool(drifted) or (args.strict and bool(docs_only))
    return 1 if fail else 0


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
