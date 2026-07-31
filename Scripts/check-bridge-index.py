#!/usr/bin/env python3
"""Verify OCCTBridge.h's OCCT-class → bridge-symbol cross-reference index.

The index at the top of `Sources/OCCTBridge/include/OCCTBridge.h` maps each wrapped
OCCT class to the bridge symbols that wrap it. It is hand-maintained, so a rename
leaves it pointing at a symbol that no longer exists — and since the index is the
map people use to find every call site of an OCCT class, a stale entry hides real
work. That is exactly how #484's unpatched fourth `ShapeFix_Face` call site was
missed: the index named `OCCTShapeFixFace`, which exists nowhere, so a re-audit of
`ShapeFix_Face` call sites by symbol name found nothing.

A trailing `*` in an index entry means "family prefix": at least one real symbol
must start with it.

Every `OCCT`-prefixed name anywhere in an entry is checked, including inside a
parenthetical aside. The first version of this script split the entry on commas
and slashes and required each piece to be a bare symbol, which meant an annotated
name (`OCCTShapeFill* (Shape.fill)`), a wrapped continuation line, and a heading
naming several classes at once (`RWObj_CafReader/Writer`) were all dropped without
a word — that is how two fabricated entries survived until #510 went looking for
them, and how #508's `OCCTGCE2dMakeLine*` survived #510's own first pass. A
validator that skips what it cannot parse reports zero for two different reasons.

Usage (from the repo root):

    python3 Scripts/check-bridge-index.py             # report stale entries
    python3 Scripts/check-bridge-index.py --quiet     # exit status only
    python3 Scripts/check-bridge-index.py --self-test # prove each failure mode is caught

Exit status is 1 when any entry is stale, so this can gate a commit.
"""
import os
import re
import sys

HEADER = 'Sources/OCCTBridge/include/OCCTBridge.h'
SRC_DIR = 'Sources/OCCTBridge/src'
SYMBOL = re.compile(r'\bOCCT[A-Za-z0-9_]+')
ENTRY = re.compile(r'^//\s+([\w/]+)\s+→\s*(.*?)\s*$')
CONTINUATION = re.compile(r'^//\s{20,}(\S.*?)\s*$')
NAMED = re.compile(r'\bOCCT[A-Za-z0-9_]+\*?')


def index_entries(lines):
    """(line number, OCCT class, bridge symbol) for every symbol named in the index."""
    out, i = [], 0
    while i < len(lines):
        m = ENTRY.match(lines[i])
        if not m:
            i += 1
            continue
        ln, cls, syms = i + 1, m.group(1), m.group(2)
        i += 1
        while i < len(lines) and '→' not in lines[i]:
            cont = CONTINUATION.match(lines[i])
            if not cont:
                break
            syms += ' ' + cont.group(1)
            i += 1
        for sym in NAMED.findall(syms):
            out.append((ln, cls, sym))
    return out


def code_only(lines):
    """The lines that declare or define something, with `//` comment lines dropped."""
    return '\n'.join(l for l in lines if not l.lstrip().startswith('//'))


def real_symbols(lines):
    """Every bridge symbol that actually exists.

    Comment lines are stripped from the header (otherwise every index entry
    trivially finds itself) and from the sources too. The sources were read whole
    until #549, which meant a *removed* function still counted as existing as long
    as its tombstone comment named it, and the tombstone idiom (#500, #506) puts
    that name in a comment on purpose. Three entries in the GCPnts_AbscissaPoint
    line were stale that way, all three of them removed arc-length spellings.
    """
    found = set(SYMBOL.findall(code_only(lines)))
    for root, _dirs, files in os.walk(SRC_DIR):
        for name in files:
            if name.endswith(('.mm', '.h')):
                with open(os.path.join(root, name), errors='replace') as f:
                    found.update(SYMBOL.findall(code_only(f.read().split('\n'))))
    return found


def stale_entries(entries, known):
    """(line, class, symbol, hint) for every index symbol that names nothing real."""
    out = []
    for ln, cls, sym in entries:
        if sym.endswith('*'):
            if not any(k.startswith(sym[:-1]) for k in known):
                out.append((ln, cls, sym, 'no symbol starts with this prefix'))
        elif sym not in known:
            near = sorted(k for k in known if sym in k or k in sym)
            hint = 'did you mean: ' + ', '.join(near[:3]) if near else 'no similar symbol'
            out.append((ln, cls, sym, hint))
    return out


# Each case is a real index entry with one fabricated name injected. The parser this
# script replaced reported every one of them as clean, because it dropped the shape
# they are written in rather than checking it (#510).
SELF_TEST = [
    ('plain entry', [
        '// BRepFill_Draft                      → OCCTBRepFillDraftNope']),
    ('continuation line', [
        '// ShapeFix_Shape                      → OCCTShapeFixDetailed, OCCTShapeHeal*,',
        '//                                       OCCTImportSTLRobustNope']),
    ('heading naming several classes', [
        '// RWObj_CafReader/Writer              → OCCTDocumentLoadOBJNope*']),
    ('name inside a parenthetical aside', [
        '// GeomAPI_ProjectPointOnCurve         → OCCTCurve3DNearestParameter',
        '//                                       (NOT OCCTCurve3DProjectPointNope; see below)']),
    ('annotated family prefix', [
        '// BRepOffsetAPI_MakeFilling           → OCCTShapeFillNope* (Shape.fill)']),
    # Not a fabricated name: OCCTCurve2DLength was a real function until #549 removed it, and
    # its tombstone comment still names it in both the header and OCCTBridge_Geom2d.mm. This
    # case fails the moment real_symbols() reads a source comment as a definition again.
    ('symbol surviving only in a tombstone comment', [
        '// GCPnts_AbscissaPoint                → OCCTCurve2DLength'], 'OCCTCurve2DLength'),
]


def self_test(known):
    """Prove each failure mode this script covers is actually caught."""
    failed = 0
    for name, lines, *expected in SELF_TEST:
        marker = expected[0] if expected else 'Nope'
        found = stale_entries(index_entries(lines), known)
        flagged = [s for _, _, s, _ in found if marker in s]
        status = 'ok  ' if flagged else 'MISS'
        if not flagged:
            failed += 1
        print(f'  {status} {name}: {", ".join(flagged) or "injected name not reported"}')
    print(f'{len(SELF_TEST) - failed}/{len(SELF_TEST)} failure modes caught')
    return 1 if failed else 0


def main():
    quiet = '--quiet' in sys.argv
    if not os.path.exists(HEADER):
        print(f'{HEADER} not found — run from the repo root', file=sys.stderr)
        return 2

    with open(HEADER, errors='replace') as f:
        lines = f.read().split('\n')
    entries = index_entries(lines)
    known = real_symbols(lines)

    if '--self-test' in sys.argv:
        return self_test(known)

    stale = stale_entries(entries, known)

    if not quiet:
        classes = len({c for _, c, _ in entries})
        print(f'{len(entries)} index symbols across {classes} OCCT classes')
        for ln, cls, sym, hint in stale:
            print(f'  STALE {HEADER}:{ln}  {cls} → {sym}  ({hint})')
        print(f'{len(stale)} stale')
    return 1 if stale else 0


if __name__ == '__main__':
    sys.exit(main())
