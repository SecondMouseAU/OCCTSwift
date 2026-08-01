#!/usr/bin/env python3
"""Verify OCCTBridge.h's OCCT-class → bridge-symbol cross-reference index.

The index at the top of `Sources/OCCTBridge/include/OCCTBridge.h` maps each wrapped
OCCT class to the bridge symbols that wrap it. It is hand-maintained, so a rename
leaves it pointing at a symbol that no longer exists — and since the index is the
map people use to find every call site of an OCCT class, a stale entry hides real
work. That is exactly how #484's unpatched fourth `ShapeFix_Face` call site was
missed: the index named `OCCTShapeFixFace`, which exists nowhere, so a re-audit of
`ShapeFix_Face` call sites by symbol name found nothing.

Two independent checks run over every entry.

**Existence** (#510) — does the named symbol exist at all?

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

**Direction** (#565) — does the named symbol wrap the class it is filed under?

An entry naming a real symbol from a neighbouring class passes the existence check
and misleads exactly the way a fabricated one does: you look up a class, get sent
to a function that has nothing to do with it, and conclude the class is wrapped
there. #501 hit this — `GCPnts_UniformAbscissa → OCCTCPntsUniformDeflection*` named
a symbol that exists and wraps `CPnts_UniformDeflection`, a different class. #565
found 15 more, including `BOPAlgo_CellsBuilder → OCCTBOPAlgoSplit` (that symbol
drives `BOPAlgo_Splitter`) and `ShapeFix_Wire → OCCTShapeFixWire*` (that prefix is
`ShapeFix_WireVertex` and `ShapeFix_Wireframe`).

The check is satisfied when at least one symbol the entry names reaches the class.
Reaching it is not always a matter of the class appearing verbatim in the function
body, so four forms of indirection are resolved before anything is reported. Each
had to be handled first: a check that cannot tell "wrong class" from "reached
indirectly" fails on correct entries and gets switched off.

1. **Wrapper-type fields** — `XCAFDoc_ShapeTool` is held as `OCCTDocument::shapeTool`,
   so 66 call sites reach it without naming the type. A function that names a bridge
   wrapper struct reaches the OCCT classes that struct holds.
2. **Helper indirection** — `TDataStd_NamedData` is reached only through two lowercase
   `static` helpers, so no `OCCT`-prefixed function body names it. A function reaches
   what its file-local helpers (and the shared `OCCTBridge_Internal.h` ones) reach.
   This is the near-miss that almost got the entry wrongly deleted in #510.
3. **Static facades** — `ShapeCustom::SweptToElementary` is how the bridge reaches
   `ShapeCustom_SweptToElementary`; the worker class is never named. A `Foo::Bar` call
   counts as naming `Foo_Bar`. (Facades with no worker class of their own, such as
   `GeomConvert::` and `BRepGProp::`, are matched by their bare name already.)
4. **Multi-class headings** — `RWObj_CafReader/Writer` covers `RWObj_CafReader` and
   `RWObj_CafWriter`, not `RWObj_Writer`: an alternative replaces a trailing run of
   CamelCase words, not everything after the `_`.

Where a class is genuinely reached only through *another OCCT class*, the entry says
so with a `(via OtherClass)` aside — `BOPAlgo_RemoveFeatures` through
`BRepAlgoAPI_Defeaturing`, `ShapeUpgrade_ConvertCurve3dToBezier` through
`ShapeUpgrade_ShapeConvertToBezier`. That aside is the exemption, and it is checked:
the named symbols must reach the class named in it. An entry naming no symbol at all
(`gp_Pnt/gp_Vec/gp_Dir → (used throughout all bridge functions)`) has nothing to
check a direction against and is skipped.

Usage (from the repo root):

    python3 Scripts/check-bridge-index.py             # report stale and misfiled entries
    python3 Scripts/check-bridge-index.py --quiet     # exit status only
    python3 Scripts/check-bridge-index.py --self-test # prove each failure mode is caught

Exit status is 1 when any entry is stale or misfiled, so this can gate a commit.
"""
import os
import re
import sys
from collections import defaultdict

HEADER = 'Sources/OCCTBridge/include/OCCTBridge.h'
SRC_DIR = 'Sources/OCCTBridge/src'
SHARED = 'OCCTBridge_Internal.h'
SYMBOL = re.compile(r'\bOCCT[A-Za-z0-9_]+')
ENTRY = re.compile(r'^//\s+([\w/]+)\s+→\s*(.*?)\s*$')
CONTINUATION = re.compile(r'^//\s{20,}(\S.*?)\s*$')
NAMED = re.compile(r'\bOCCT[A-Za-z0-9_]+\*?')
VIA = re.compile(r'\(via ([A-Za-z0-9_]+)')
IDENT = re.compile(r'\b[A-Za-z_][A-Za-z0-9_]*\b')
SCOPED = re.compile(r'\b([A-Za-z_][A-Za-z0-9_]*)::([A-Za-z_][A-Za-z0-9_]*)')
AGGREGATE = re.compile(r'\b(?:struct|class|union|namespace|enum)\s')
WORD = re.compile(r'[A-Z][a-z0-9]*|\d+')


def without_asides(text):
    """The entry's symbol list, with every parenthesised aside removed.

    An aside is commentary, not an attribution: `(OCCTWireOffset drives
    BRepOffsetAPI_MakeOffset, not this)` names a symbol precisely to say it does *not*
    wrap the class. The existence check still reads asides — a fabricated name is a
    fabrication wherever it is written, which is how #508's `OCCTGCE2dMakeLine*` was
    caught — but the direction check must not attribute one.
    """
    out, depth = [], 0
    for ch in text:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth = max(0, depth - 1)
        elif depth == 0:
            out.append(ch)
    return ''.join(out)


def index_entries(lines):
    """(line, class heading, symbols, full entry text) for every entry in the index."""
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
        out.append((ln, cls, NAMED.findall(syms), syms))
    return out


def source_files():
    out = []
    for root, _dirs, files in os.walk(SRC_DIR):
        for name in sorted(files):
            if name.endswith(('.mm', '.h')):
                out.append(os.path.join(root, name))
    return out


def real_symbols(lines):
    """Every bridge symbol that actually exists.

    Comments are stripped from the header (otherwise every index entry trivially finds
    itself) and from the sources too: a tombstone comment such as `// OCCTCurve3DLength
    lived here: ...`, left where a deleted function used to be, otherwise reads as a live
    definition and keeps a removed symbol passing this check forever (#549).
    """
    code = '\n'.join(l for l in lines if not l.lstrip().startswith('//'))
    found = set(SYMBOL.findall(code))
    for path in source_files():
        with open(path, errors='replace') as f:
            found.update(SYMBOL.findall(strip_noise(f.read())))
    return found


def stale_entries(entries, known):
    """(line, class, symbol, hint) for every index symbol that names nothing real."""
    out = []
    for ln, cls, syms, _text in entries:
        for sym in syms:
            if sym.endswith('*'):
                if not any(k.startswith(sym[:-1]) for k in known):
                    out.append((ln, cls, sym, 'no symbol starts with this prefix'))
            elif sym not in known:
                near = sorted(k for k in known if sym in k or k in sym)
                hint = 'did you mean: ' + ', '.join(near[:3]) if near else 'no similar symbol'
                out.append((ln, cls, sym, hint))
    return out


# --- what each bridge function reaches -----------------------------------


def strip_noise(text):
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    text = re.sub(r'//[^\n]*', '', text)
    # `#include <BRepOffsetAPI_MakePipe.hxx>` carries no `;`, so it would otherwise be
    # swept into the next definition's signature and credit that function with the class.
    return re.sub(r'^\s*#[^\n]*', '', text, flags=re.M)


def definitions(path):
    """(kind, name, names-it-reaches) for every brace-balanced definition at file scope."""
    with open(path, errors='replace') as f:
        text = strip_noise(f.read())
    out, depth, start, sig_start, i = [], 0, None, 0, 0
    while i < len(text):
        c = text[i]
        if c == '{':
            if depth == 0:
                start = i
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0 and start is not None:
                sig, body = text[sig_start:start], text[start:i + 1]
                names = set(IDENT.findall(sig)) | set(IDENT.findall(body))
                # a `Foo::Bar` call is how the bridge reaches worker class `Foo_Bar`
                names |= {f'{a}_{b}' for a, b in SCOPED.findall(body)}
                if AGGREGATE.search(sig):
                    m = re.search(r'\b(?:struct|class|union)\s+(\w+)', sig)
                    if m:
                        out.append(('type', m.group(1), names))
                else:
                    m = list(re.finditer(r'\b([A-Za-z_][A-Za-z0-9_]*)\s*\(', sig))
                    if m:
                        out.append(('fn', m[-1].group(1), names))
                start, sig_start = None, i + 1
        elif c == ';' and depth == 0:
            sig_start = i + 1
        i += 1
    return out


def reachable():
    """bridge function → every name it reaches, following the bridge's own indirections."""
    per_file, types = {}, defaultdict(set)
    for path in source_files():
        fns = {}
        for kind, name, names in definitions(path):
            if kind == 'type':
                types[name] |= names
            else:
                fns.setdefault(name, set()).update(names)
        per_file[os.path.basename(path)] = fns

    # a function that names a bridge wrapper type reaches the OCCT classes that type holds
    for fns in per_file.values():
        for names in fns.values():
            for t in list(names):
                base = t[:-3] if t.endswith('Ref') else t
                if base in types:
                    names |= types[base]

    # a function reaches what its file-local helpers (and the shared header's) reach
    shared = per_file.get(SHARED, {})
    for fns in per_file.values():
        for _ in range(4):
            grew = False
            for name, names in fns.items():
                for t in list(names):
                    if t == name:
                        continue
                    src = fns.get(t) or shared.get(t)
                    if src and not src <= names:
                        names |= src
                        grew = True
            if not grew:
                break

    merged = defaultdict(set)
    for fns in per_file.values():
        for name, names in fns.items():
            merged[name] |= names
    return merged


def expand_heading(heading):
    """`RWObj_CafReader/Writer` covers RWObj_CafReader and RWObj_CafWriter, not RWObj_Writer."""
    parts = heading.split('/')
    out = [parts[0]]
    head, _sep, tail = parts[0].partition('_')
    words = WORD.findall(tail) or [tail]
    for alt in parts[1:]:
        if '_' in alt:
            out.append(alt)
            continue
        # the alternative replaces a trailing run of CamelCase words; try every split,
        # since only the code can say which one is the class that is actually reached
        for k in range(len(words), 0, -1):
            out.append(f'{head}_{"".join(words[:k - 1])}{alt}')
    return out


def misfiled_entries(entries, reach):
    """(line, class, symbol, hint) for every listed symbol that never reaches its class.

    Per symbol, not per entry. An entry-level rule — "at least one of these reaches the
    class" — lets one wrong symbol hide behind its correct neighbours, which is the whole
    shape of the defect: `GCPnts_UniformAbscissa → OCCTCPntsUniformDeflection*` was only
    caught in #501 because it happened to be the entry's sole symbol.

    A family prefix is satisfied by any one member: `OCCTFaceFixer*` legitimately spans a
    family whose members share the class, and not every member need touch it directly.
    """
    out = []
    for ln, cls, _syms, text in entries:
        listed = NAMED.findall(without_asides(text))
        if not listed:
            continue  # names no symbol; nothing to check a direction against
        wanted = set(expand_heading(cls)) | set(VIA.findall(text))
        for sym in listed:
            if sym.endswith('*'):
                bodies = {k for k in reach if k.startswith(sym[:-1])}
            else:
                bodies = {sym} if sym in reach else set()
            if any(w in reach[b] for b in bodies for w in wanted):
                continue
            elsewhere = sorted(k for k in reach
                               if k.startswith('OCCT') and wanted & reach[k])
            hint = ('really wrapped by: ' + ', '.join(elsewhere[:3]) if elsewhere
                    else 'no bridge function reaches this class')
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
]

# Each case is an entry filed under the wrong class — the four shapes #565 found. Every
# one names a symbol that exists, so the existence check above calls them all clean.
DIRECTION_TEST = [
    ('symbol drives a neighbouring class', [
        '// BOPAlgo_CellsBuilder                → OCCTBOPAlgoSplit']),
    ('family prefix belongs to another class', [
        '// ShapeFix_Wire                       → OCCTShapeFixWire*']),
    ('class is reimplemented, not wrapped', [
        '// LProp_AnalyticCurInf                → OCCTLPropAnalyticCurInf']),
    ('class name is one letter off', [
        '// Law_Interpol                        → OCCTLawInterpolate']),
]

# The four indirection forms, plus the two shapes carrying an explicit exemption. A
# direction check that reports any of these is reporting a correct entry, and would be
# switched off rather than fixed — so each is asserted clean, not just left untested.
INDIRECTION_TEST = [
    ('wrapper-type field', [
        '// XCAFDoc_ShapeTool                   → OCCTDocumentAddShape']),
    ('lowercase static helper', [
        '// TDataStd_NamedData                  → OCCTDocumentNamedData*']),
    ('static facade', [
        '// ShapeCustom_SweptToElementary       → OCCTShapeSweptToElementary']),
    ('multi-class heading', [
        '// RWObj_CafReader/Writer              → OCCTDocumentWriteOBJ']),
    ('reached via another OCCT class', [
        '// ShapeUpgrade_ConvertCurve3dToBezier → OCCTShapeUpgradeConvertCurves3dToBezier',
        '//                                       (via ShapeUpgrade_ShapeConvertToBezier)']),
    ('entry naming no symbol', [
        '// gp_Pnt/gp_Vec/gp_Dir               → (used throughout all bridge functions)']),
]


def self_test(known, reach):
    """Prove each failure mode this script covers is caught, and each correct shape is not."""
    failed = 0
    for name, lines in SELF_TEST:
        flagged = [s for _, _, s, _ in stale_entries(index_entries(lines), known) if 'Nope' in s]
        failed += not flagged
        print(f'  {"ok  " if flagged else "MISS"} stale, {name}: '
              f'{", ".join(flagged) or "injected name not reported"}')
    for name, lines in DIRECTION_TEST:
        flagged = misfiled_entries(index_entries(lines), reach)
        failed += not flagged
        print(f'  {"ok  " if flagged else "MISS"} misfiled, {name}: '
              f'{flagged[0][1] if flagged else "mis-attribution not reported"}')
    for name, lines in INDIRECTION_TEST:
        flagged = misfiled_entries(index_entries(lines), reach)
        failed += bool(flagged)
        print(f'  {"ok  " if not flagged else "FALSE"} indirect, {name}: '
              f'{flagged[0][1] + " wrongly reported" if flagged else "not reported"}')
    total = len(SELF_TEST) + len(DIRECTION_TEST) + len(INDIRECTION_TEST)
    print(f'{total - failed}/{total} cases correct')
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
    reach = reachable()

    if '--self-test' in sys.argv:
        return self_test(known, reach)

    stale = stale_entries(entries, known)
    misfiled = misfiled_entries(entries, reach)

    if not quiet:
        symbols = sum(len(s) for _, _, s, _ in entries)
        print(f'{symbols} index symbols across {len(entries)} OCCT classes')
        for ln, cls, sym, hint in stale:
            print(f'  STALE    {HEADER}:{ln}  {cls} → {sym}  ({hint})')
        for ln, cls, sym, hint in misfiled:
            print(f'  MISFILED {HEADER}:{ln}  {cls} → {sym}  ({hint})')
        print(f'{len(stale)} stale, {len(misfiled)} misfiled')
    return 1 if stale or misfiled else 0


if __name__ == '__main__':
    sys.exit(main())
