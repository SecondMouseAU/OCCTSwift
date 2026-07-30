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

Usage (from the repo root):

    python3 Scripts/check-bridge-index.py          # report stale entries
    python3 Scripts/check-bridge-index.py --quiet  # exit status only

Exit status is 1 when any entry is stale, so this can gate a commit.
"""
import os
import re
import sys

HEADER = 'Sources/OCCTBridge/include/OCCTBridge.h'
SRC_DIR = 'Sources/OCCTBridge/src'
SYMBOL = re.compile(r'\bOCCT[A-Za-z0-9_]+')
ENTRY = re.compile(r'^//\s+(\w+)\s+→\s+(.+?)\s*$')


def index_entries(lines):
    """(line number, OCCT class, bridge symbol) for every symbol named in the index."""
    out = []
    for i, line in enumerate(lines):
        m = ENTRY.match(line)
        if not m:
            continue
        cls, syms = m.group(1), re.sub(r'\(v[\d.]+\)', '', m.group(2))
        for sym in re.split(r'[,/]', syms):
            sym = sym.strip()
            if re.fullmatch(r'OCCT\w+\*?', sym):
                out.append((i + 1, cls, sym))
    return out


def real_symbols(lines):
    """Every bridge symbol that actually exists.

    The index lives in header comments, so comment lines are stripped first —
    otherwise every entry trivially finds itself.
    """
    code = '\n'.join(l for l in lines if not l.lstrip().startswith('//'))
    found = set(SYMBOL.findall(code))
    for root, _dirs, files in os.walk(SRC_DIR):
        for name in files:
            if name.endswith(('.mm', '.h')):
                with open(os.path.join(root, name), errors='replace') as f:
                    found.update(SYMBOL.findall(f.read()))
    return found


def main():
    quiet = '--quiet' in sys.argv
    if not os.path.exists(HEADER):
        print(f'{HEADER} not found — run from the repo root', file=sys.stderr)
        return 2

    with open(HEADER, errors='replace') as f:
        lines = f.read().split('\n')
    entries = index_entries(lines)
    known = real_symbols(lines)

    stale = []
    for ln, cls, sym in entries:
        if sym.endswith('*'):
            if not any(k.startswith(sym[:-1]) for k in known):
                stale.append((ln, cls, sym, 'no symbol starts with this prefix'))
        elif sym not in known:
            near = sorted(k for k in known if sym in k or k in sym)
            hint = 'did you mean: ' + ', '.join(near[:3]) if near else 'no similar symbol'
            stale.append((ln, cls, sym, hint))

    if not quiet:
        classes = len({c for _, c, _ in entries})
        print(f'{len(entries)} index symbols across {classes} OCCT classes')
        for ln, cls, sym, hint in stale:
            print(f'  STALE {HEADER}:{ln}  {cls} → {sym}  ({hint})')
        print(f'{len(stale)} stale')
    return 1 if stale else 0


if __name__ == '__main__':
    sys.exit(main())
