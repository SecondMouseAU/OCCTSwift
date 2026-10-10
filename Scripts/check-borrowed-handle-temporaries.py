#!/usr/bin/env python3
"""GATE: no `.handle` read straight off a collection element or a call result (#3130).

`Edge`, `Wire`, `Face`, `Shape` and the other owning wrappers expose their native pointer as
`handle`. The compiler does not tie that pointer to the wrapper that owns it, so in an optimised
build the wrapper is free to be released as soon as the `.handle` load is its last use, which is
BEFORE the C call that receives the pointer runs. Measured on macOS `-c release`
(`Scripts/repro/3130-borrowed-handle/`, 8 runs each under `MallocScribble`):

  * `OCCTEdgeSetSameParameter(edges[0].handle, false)`       wrote through a freed OCCTEdge
  * `OCCTEdgeGetLength(edges[0].handle)`                      segfault or 0.0
  * `OCCTEdgeGetLength(b.edges().first!.handle)`              segfault or 0.0
  * `OCCTShapeIsValid(Shape.box(...)!.handle)`                false, or a bus error

and every one of them correct through `owner.withHandle { ... }`. An owner bound to its own `let`
or `for` variable survived every variant measured (the optimiser keeps a named variable's lexical
lifetime across a call it cannot see through), so a named local is not in this gate's scope.
The two shapes that lose their owner are the ones this gate fires on:

  1. a SUBSCRIPT result:   `edges[0].handle`, `faces[i]!.handle`, `edges[0]?.handle`
  2. a CALL result:        `shape.edges().first!.handle`, `makeShape()!.handle`, `list.first?.handle`
     (matched as `)` or `].first/.last` followed by `.handle`), including a chain split so
     that `.handle` opens the next line.

The fix is never to rescue the expression, it is to hold the owner for the call:
`edges[0].withHandle { OCCTEdgeSetSameParameter($0, false) }`. `withHandle` is on every
`NativeHandleOwner` (`Sources/OCCTSwift/NativeHandleView.swift`); a method call keeps its receiver
alive for the whole call, which is the entire mechanism.

POPULATION: every `*.swift` under `Sources/` and `Tests/`. The tree holds zero matches today (the
one instance, `BRepLibExtendedTests`, is fixed with this gate), so there is no baseline to carry.

EXEMPTION: a comment `handle-temporary-exempt: <reason>` on the offending line or in the run of
comment lines directly above it. The reason is required; a bare marker is itself reported.

THE ARRAY SHAPE (#3266)
-----------------------
A third shape loses its owners the same way: `let hs = profiles.map { $0.handle }` followed by a C
call taking `hs`. Once the function is inlined into a caller whose `profiles` is a local with no
later use, nothing keeps the wrappers, and the optimiser (Swift 6.2.4, `-c release`) may release
them before the C call runs: #3261, the `threadedHole` crash in `BRepOffsetAPI_ThruSections`. A
parameter is not safe either, because inlining turns it into the caller's local. The gate cannot
tell a parameter from a local, so it fires on every pure extraction (a `map`/`compactMap` whose
closure is just `$0.handle`, `$0.x.handle`, optionally `as T`) unless the receiver is held, which
is a `withExtendedLifetime(<receiver>)` on the same line or on one of the next three lines:

    let handles = profiles.map { $0.handle }
    defer { withExtendedLifetime(profiles) {} }

A map whose closure calls the bridge itself (`bodies.map { f($0.handle) }`) consumes the pointer
while `$0` is live and is not matched.

WHAT IT CANNOT SEE
------------------
  * A named local whose last use is the `.handle` load. Measured safe on macOS release in six
    variants, but by an optimiser behaviour and not a language guarantee.
  * A pointer copied out first (`let h = list[0].handle`) is caught, because the `[0].handle` part
    is what matches; a pointer obtained through some other property name (`.ref`) is not matched.
  * Property chains through a collection element (`pairs[0].edge.handle`): the owner there is
    `.edge`, a stored property of an element, and is not distinguished from a stored property of
    `self`.
  * Anything outside `Sources/` and `Tests/`.

Usage:
  Scripts/check-borrowed-handle-temporaries.py
  Scripts/check-borrowed-handle-temporaries.py --self-test
"""
import argparse
import glob
import os
import re
import sys

ROOTS = ('Sources', 'Tests')
EXEMPT_RE = re.compile(r'handle-temporary-exempt:\s*(\S.*)?')

# `]` or `)` (a subscript or a call just returned), an optional force/optional marker, optional
# whitespace including a line break, then `.handle`. `.first`/`.last` after a named collection is
# the same shape without either bracket: `edges.first!.handle`.
TEMP_RE = re.compile(
    r'(?:[\]\)]|\.(?:first|last)\b)[!?]?\s*\.handle\b')

# `recv.map { $0.handle }`, `recv.compactMap { $0.a.handle as T }`: the closure only extracts.
# The receiver is a dotted identifier path; anything fancier is not matched (see the docstring).
ARRAY_RE = re.compile(
    r'([A-Za-z_][A-Za-z0-9_.]*)\s*\.(?:map|compactMap)\s*\{\s*\$0(?:\.[A-Za-z_]\w*)*\.handle'
    r'(?:\s+as\s+[A-Za-z0-9_?.]+)?\s*\}')
HELD_WINDOW = 3


def strip_code(text):
    """Blank comments and string literals, keeping line numbers and the exemption comments."""
    out = []
    i, n = 0, len(text)
    comments = {}
    line = 1
    while i < n:
        c = text[i]
        if text.startswith('//', i):
            j = text.find('\n', i)
            j = n if j < 0 else j
            comments[line] = text[i:j]
            out.append(' ' * (j - i))
            i = j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            seg = text[i:j]
            for k, ln in enumerate(seg.split('\n')):
                comments[line + k] = ln
            out.append(re.sub(r'[^\n]', ' ', seg))
            line += seg.count('\n')
            i = j
        elif c == '"':
            triple = text.startswith('"""', i)
            end = '"""' if triple else '"'
            j = i + len(end)
            while j < n and not text.startswith(end, j):
                j += 2 if text[j] == '\\' else 1
            j = min(j + len(end), n)
            seg = text[i:j]
            out.append(re.sub(r'[^\n]', ' ', seg))
            line += seg.count('\n')
            i = j
        else:
            if c == '\n':
                line += 1
            out.append(c)
            i += 1
    return ''.join(out), comments


def find_in_text(text):
    """Return [(line, snippet, problem)] for one file's text. problem is None for a violation."""
    code, comments = strip_code(text)
    findings = []
    for m in TEMP_RE.finditer(code):
        line = code.count('\n', 0, m.end()) + 1
        # The exemption sits on the offending line or in the comment run directly above it.
        exempt, k = None, line
        while k >= 1 and (k == line or k in comments and code.split('\n')[k - 1].strip() == ''):
            em = EXEMPT_RE.search(comments.get(k, ''))
            if em:
                exempt = em
                break
            k -= 1
        if exempt is not None:
            if not (exempt.group(1) or '').strip():
                findings.append((line, m.group(0).strip(), 'exemption-without-reason'))
            continue
        findings.append((line, ' '.join(m.group(0).split()), 'borrowed-handle-temporary'))

    lines = code.split('\n')
    for m in ARRAY_RE.finditer(code):
        line = code.count('\n', 0, m.start()) + 1
        held_re = re.compile(r'withExtendedLifetime\(\s*' + re.escape(m.group(1)) + r'\s*[,)]')
        if any(held_re.search(lines[k]) for k in range(line - 1, min(line + HELD_WINDOW, len(lines)))):
            continue
        exempt, k = None, line
        while k >= 1 and (k == line or k in comments and lines[k - 1].strip() == ''):
            em = EXEMPT_RE.search(comments.get(k, ''))
            if em:
                exempt = em
                break
            k -= 1
        if exempt is not None:
            if not (exempt.group(1) or '').strip():
                findings.append((line, ' '.join(m.group(0).split()), 'exemption-without-reason'))
            continue
        findings.append((line, ' '.join(m.group(0).split()), 'unheld-handle-array'))
    return findings


def scan(roots=ROOTS):
    files = []
    for root in roots:
        files += glob.glob(os.path.join(root, '**', '*.swift'), recursive=True)
    findings = []
    for f in sorted(files):
        with open(f, encoding='utf-8') as fh:
            for line, snippet, kind in find_in_text(fh.read()):
                findings.append((f, line, snippet, kind))
    return files, findings


def self_test():
    failures = []

    def expect(name, text, kinds):
        got = sorted(k for _, _, k in find_in_text(text))
        if got != sorted(kinds):
            failures.append('%s: expected %r, got %r' % (name, sorted(kinds), got))

    bad = 'borrowed-handle-temporary'
    expect('subscript', 'f(edges[0].handle, false)\n', [bad])
    expect('subscript optional', 'f(edges[0]?.handle)\n', [bad])
    expect('subscript force', 'f(edges[i]!.handle)\n', [bad])
    expect('first force', 'f(edges.first!.handle)\n', [bad])
    expect('last optional', 'f(edges.last?.handle)\n', [bad])
    expect('call result', 'f(b.edges().first!.handle)\n', [bad])
    expect('call result direct', 'f(Shape.box(1, 2, 3)!.handle)\n', [bad])
    expect('split chain', 'f(b.edges()\n    .handle)\n', [bad])
    expect('copied out', 'let h = faces[0].handle\n', [bad])
    expect('two on a line', 'g(a[0].handle, b[1].handle)\n', [bad, bad])
    # Must stay quiet.
    expect('named local', 'let e = edges[0]\nf(e.handle)\n', [])
    expect('parameter optional chain', 'f(face?.handle)\n', [])
    expect('closure consuming the pointer', 'let n = bodies.map { f($0.handle) }\n', [])
    # The array shape (#3266).
    arr = 'unheld-handle-array'
    expect('array plain', 'let hs = shapes.map { $0.handle }\n', [arr])
    expect('array cast', 'let hs = shapes.map { $0.handle as OCCTShapeRef? }\n', [arr])
    expect('array nested owner', 'var hs = curves.map { $0.wire.handle as OCCTWireRef? }\n', [arr])
    expect('array compactMap', 'let hs = xs.compactMap { $0.handle }\n', [arr])
    expect('array typed', 'let hs: [OCCTWireRef?] = profiles.map { $0.handle }\n', [arr])
    expect('array held', 'let hs = shapes.map { $0.handle }\ndefer { withExtendedLifetime(shapes) {} }\n', [])
    expect('array held two lines on', 'let hs = a.map { $0.handle }\nlet z = 1\n'
           'defer { withExtendedLifetime(a) {} }\n', [])
    expect('array held for the wrong array',
           'let hs = a.map { $0.handle }\ndefer { withExtendedLifetime(b) {} }\n', [arr])
    expect('array held too far on',
           'let hs = a.map { $0.handle }\nlet z = 1\nlet y = 2\nlet x = 3\n'
           'defer { withExtendedLifetime(a) {} }\n', [arr])
    expect('array held by a prefix name only',
           'let hs = a.map { $0.handle }\ndefer { withExtendedLifetime(ab) {} }\n', [arr])
    expect('array exempt', 'let hs = a.map { $0.handle } // handle-temporary-exempt: a is a literal\n', [])
    expect('member', 'f(self.handle, other.handle)\n', [])
    expect('comment', '// f(edges[0].handle)\n/* g(a[1].handle) */\n', [])
    expect('string', 'let s = "edges[0].handle"\n', [])
    expect('multiline string', 'let s = """\nedges[0].handle\n"""\n', [])
    expect('withHandle', 'edges[0].withHandle { f($0) }\n', [])
    expect('exempt same line', 'f(edges[0].handle) // handle-temporary-exempt: owner pinned above\n', [])
    expect('exempt line above', '// handle-temporary-exempt: owner pinned above\nf(edges[0].handle)\n', [])
    expect('exempt without reason', 'f(edges[0].handle) // handle-temporary-exempt:\n',
           ['exemption-without-reason'])
    expect('exemption does not leak', '// handle-temporary-exempt: x\nlet a = 1\nf(edges[0].handle)\n', [bad])
    # Line numbers are real, including after a block comment and a multiline string.
    got = find_in_text('/* a\nb */\nlet s = """\nx\n"""\nf(e[0].handle)\n')
    if [g[0] for g in got] != [6]:
        failures.append('line numbers: expected [6], got %r' % [g[0] for g in got])
    # The pre-fix source of #3125 is caught.
    expect('#2929 original', '        OCCTEdgeSetSameParameter(edges[0].handle, false)\n', [bad])

    # Canary: the scanner must see the tree. A glob that matched nothing would report all clear.
    files, findings = scan()
    if len(files) < 500:
        failures.append('population canary: only %d Swift files under Sources/ and Tests/' % len(files))
    if not any(f.startswith('Sources/OCCTSwift/NativeHandleView.swift') for f in files):
        failures.append('population canary: NativeHandleView.swift not scanned')
    if findings:
        failures.append('the tree is expected to be clean, found %d' % len(findings))

    if failures:
        print('SELF-TEST FAILED')
        for f in failures:
            print('  ' + f)
        return 1
    print('self-test ok: %d files scanned' % len(files))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()
    if not os.path.isdir('Sources') or not os.path.isdir('Tests'):
        print('run from the repository root', file=sys.stderr)
        return 2
    if args.self_test:
        return self_test()
    files, findings = scan()
    for f, line, snippet, kind in findings:
        if kind == 'exemption-without-reason':
            print('%s:%d: handle-temporary-exempt needs a reason' % (f, line))
        elif kind == 'unheld-handle-array':
            print('%s:%d: `%s` extracts raw pointers and nothing holds the owners; add '
                  '`defer { withExtendedLifetime(<array>) {} }` after it (#3266)' % (f, line, snippet))
        else:
            print('%s:%d: `%s` reads a borrowed pointer off a temporary owner; use '
                  '`owner.withHandle { ... }` (#3130)' % (f, line, snippet))
    if findings:
        print('%d finding(s) in %d files' % (len(findings), len(files)))
        return 1
    print('ok: %d Swift files, no borrowed handle read off a temporary' % len(files))
    return 0


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
