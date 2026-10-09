#!/usr/bin/env python3
"""Fail on a bridge-side OCCT adaptor that is STORED, unless it is on the allowlist (#3065).

OCCT's geometry adaptors (`GeomAdaptor_Curve`, `BRepAdaptor_Curve`, `Adaptor3d_Surface`, ...) carry
a BSpline evaluation cache that a `const` evaluator rebuilds in place. Upstream's stated design
(Open-Cascade-SAS/OCCT#1554, @gkv311) is that **each worker owns its adaptor**, taking
`ShallowCopy()` of a shared one, which drops the cache. Sharing one adaptor between threads is
unsupported, and measured wrong every time under load: without carried patch `0031`, eight threads
on one shared adaptor read a wrong point in 97 of 97 completed runs (#3065).

So the question for the bridge is not whether it evaluates through an adaptor, it constantly does,
but **whether any adaptor outlives one call**. An adaptor built per call is private to its caller by
construction. One stored in a struct, a class, a namespace-scope variable or a function-local
`static` is reachable from every caller of that object, which is exactly the shared-adaptor shape.

Two are stored today, and both are on `ALLOWED` for the same measured reason: `OCCTEdgeCurve` holds a
`BRepAdaptor_Curve` and `OCCTCompCurve` a `BRepAdaptor_CompCurve`, built once at `init` and reused by
every accessor of the Swift `EdgeCurve` / `WireCurve`. Those two Swift classes are not `Sendable`, so
Swift 6 refuses to send one across a task boundary, and their docs tell the caller to build one per
task. This gate holds both halves of that: the allowlist, and (`SWIFT_NOT_SENDABLE`) that neither
class acquires a `Sendable` conformance, since that conformance is what would turn the allowed
persistent adaptor into a shared one.

A third stored adaptor is a decision, not an edit: add it to `ALLOWED` with the reason it cannot be
reached from two threads, or build it per call.

What this does NOT see, stated rather than assumed: an adaptor held behind a wrapper type whose own
name does not contain `Adaptor` (a hand-written `struct Thing { Handle(Foo) f; }` where `Foo`
embeds an adaptor), and OCCT classes that build an adaptor internally and keep it (`Extrema_*`,
`GeomAPI_Project*`). Those are the kernel's own storage, not ours, and are what the TSan gate's
`*_shallow_copy_per_thread` and `*_independent` modes exercise.

Usage:
  Scripts/check-bridge-adaptor-members.py
  Scripts/check-bridge-adaptor-members.py --self-test
"""
import argparse
import glob
import os
import re
import sys

BRIDGE_GLOBS = ('Sources/OCCTBridge/src/*.mm', 'Sources/OCCTBridge/include/*.h')
SWIFT_GLOB = 'Sources/OCCTSwift/*.swift'

# (enclosing struct/class, adaptor type) -> why it cannot be reached from two threads at once.
# An entry is a persistent adaptor, so it needs the reasoning below, not a silencer.
ALLOWED = {
    ('OCCTEdgeCurve', 'BRepAdaptor_Curve'):
        'behind Swift `EdgeCurve`, which is not Sendable, so it cannot cross a task boundary; its '
        'doc says one per task',
    ('OCCTCompCurve', 'BRepAdaptor_CompCurve'):
        'behind Swift `WireCurve`, which is not Sendable, so it cannot cross a task boundary; its '
        'doc says one per task',
}

# Swift classes whose bridge struct holds an allowed persistent adaptor. A Sendable conformance on
# either is what would make the adaptor shareable across tasks.
SWIFT_NOT_SENDABLE = ('EdgeCurve', 'WireCurve')

# An OCCT adaptor class: `<Package>Adaptor<...>_<Name>`, e.g. BRepAdaptor_Curve, GeomAdaptor_Surface,
# Geom2dAdaptor_Curve, Adaptor3d_Curve, Adaptor2d_Curve.
ADAPTOR_RE = re.compile(r'\b(\w*Adaptor\w*_\w+)\b')

# Comments dropped, string and character literals kept (and then blanked by `blank_literals`), in one
# leftmost-match-wins alternation so a `/*` inside a `//` comment does not open a block.
COMMENT_OR_LITERAL = re.compile(
    r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', re.S)


def clean(text):
    """Comments removed and literals emptied, newlines preserved so line numbers survive."""
    def sub(m):
        s = m.group(0)
        if s.startswith('//') or s.startswith('/*'):
            return re.sub(r'[^\n]', ' ', s)
        return s[0] + s[-1]
    return COMMENT_OR_LITERAL.sub(sub, text)


TYPE_HEAD_RE = re.compile(r'^\s*(?:template\s*<[^>]*>\s*)?(struct|class|union)\s+(\w+)')
NS_HEAD_RE = re.compile(r'^\s*(?:namespace\b|extern\s+"")')

QUALIFIERS = r'(?:(?:static|mutable|const|constexpr|inline|thread_local|extern|volatile)\s+)*'
TYPE_EXPR = (r'(?:Handle\s*\(\s*[\w:]+\s*\)'
             r'|[\w:]+(?:\s*<[^;]*?>)?)')
DECL_RE = re.compile(
    r'^' + QUALIFIERS + r'(?P<type>' + TYPE_EXPR + r')\s*(?:const\s*)?[*&\s]*'
    r'(?P<name>\w+)\s*(?:\[[^\]]*\])?\s*(?:=[^;]*|\{[^;]*\})?;$')
SKIP_START = ('return', 'typedef', 'using', 'friend', 'throw', 'goto', 'case', 'else', 'delete')


def scan_text(text, path='<text>'):
    """[(path, line_no, scope_name, adaptor_type, member_name)] for every stored adaptor."""
    found = []
    lines = clean(text).split('\n')
    stack = []          # (kind, name): 'type' | 'ns' | 'other'
    prev_head = ''      # the last non-blank, non-preprocessor line, for brace-on-next-line style
    for index, raw in enumerate(lines):
        line = raw.strip()
        if not line or line.startswith('#'):
            continue

        top = stack[-1] if stack else ('file', '<file scope>')
        is_static = re.match(r'(?:\w+\s+)*?(static|thread_local)\b', line) is not None
        if (top[0] in ('file', 'ns', 'type') or is_static) and line.endswith(';') \
                and not line.startswith(SKIP_START):
            m = DECL_RE.match(line)
            if m:
                adaptor = ADAPTOR_RE.search(m.group('type'))
                if adaptor:
                    scope = top[1] if top[0] in ('file', 'ns', 'type') else '<function static>'
                    found.append((path, index + 1, scope, adaptor.group(1), m.group('name')))

        head = line if not line.startswith('{') else prev_head
        for ch_index, ch in enumerate(line):
            if ch == '{':
                if TYPE_HEAD_RE.match(head) and '(' not in head.split('{')[0].split(':')[0]:
                    stack.append(('type', TYPE_HEAD_RE.match(head).group(2)))
                elif NS_HEAD_RE.match(head):
                    stack.append(('ns', '<namespace>'))
                else:
                    stack.append(('other', ''))
                head = ''   # a second brace on the same line belongs to no named head
            elif ch == '}':
                if stack:
                    stack.pop()
        prev_head = line
    return found


def scan_swift(texts):
    """Swift classes in SWIFT_NOT_SENDABLE that claim Sendable, and the ones never declared."""
    claims, declared = [], set()
    for path, text in texts:
        text = clean(text)
        for name in SWIFT_NOT_SENDABLE:
            for m in re.finditer(r'\b(?:class|extension)\s+' + name + r'\b([^{]*)\{', text):
                if re.search(r'\bclass\s+' + name + r'\b', m.group(0)):
                    declared.add(name)
                if 'Sendable' in m.group(1):
                    claims.append((path, name))
    return claims, declared


def evaluate(hits, swift_texts):
    """(findings, stale_allowlist, swift_claims, refusals) from the scanned population."""
    findings = [h for h in hits if (h[2], h[3]) not in ALLOWED]
    seen = {(h[2], h[3]) for h in hits}
    stale = sorted(k for k in ALLOWED if k not in seen)
    claims, declared = scan_swift(swift_texts)
    refusals = []
    if not hits:
        refusals.append('no stored adaptor found anywhere in the bridge: the scan is blind or '
                        'the allowlist is obsolete, and a clean report would mean neither')
    missing = [n for n in SWIFT_NOT_SENDABLE if n not in declared]
    if swift_texts and missing:
        refusals.append('Swift class(es) not declared where expected: ' + ', '.join(missing))
    return findings, stale, claims, refusals


def read_all(patterns):
    out = []
    for pattern in patterns:
        for path in sorted(glob.glob(pattern)):
            with open(path, encoding='utf-8') as fh:
                out.append((path, fh.read()))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()
    if args.self_test:
        return self_test()

    if not os.path.isdir('Sources/OCCTBridge/src'):
        print('ERROR: run from the repo root (Sources/OCCTBridge/src not found)')
        return 2

    bridge = read_all(BRIDGE_GLOBS)
    hits = []
    for path, text in bridge:
        hits.extend(scan_text(text, path))
    findings, stale, claims, refusals = evaluate(hits, read_all([SWIFT_GLOB]))

    if refusals:
        for r in refusals:
            print('REFUSED: ' + r)
        return 2

    bad = False
    if findings:
        bad = True
        print(f'FAIL: {len(findings)} stored OCCT adaptor(s) not on the allowlist:')
        for path, line_no, scope, adaptor, name in findings:
            print(f'  {path}:{line_no}  {scope}.{name}: {adaptor}')
        print('  An adaptor that outlives one call is shared by every caller of the object that')
        print('  holds it, and a shared adaptor is unsupported by OCCT (#3065). Build it per call,')
        print('  or add it to ALLOWED with the reason two threads cannot reach it.')
    if stale:
        bad = True
        print('FAIL: allowlist entries that match no stored adaptor (the code moved, the list did not):')
        for scope, adaptor in stale:
            print(f'  {scope}: {adaptor}')
    if claims:
        bad = True
        print('FAIL: a class whose bridge struct holds a persistent adaptor claims Sendable:')
        for path, name in claims:
            print(f'  {path}: {name}')
        print('  Sendable lets one instance, and so one adaptor cache, be used from two tasks.')
    if bad:
        return 1

    distinct = sorted({(h[2], h[3]) for h in hits})
    print(f'check-bridge-adaptor-members: clean, {len(hits)} stored adaptor(s) in '
          f'{len(distinct)} allowlisted struct(s): ' + ', '.join(f'{s}.{a}' for s, a in distinct))
    return 0


def self_test():
    """Fixture battery. Each case names the mechanism it isolates (prove-the-test-fails.md)."""
    failures = []

    def expect(label, text, want):
        got = sorted((h[2], h[3]) for h in scan_text(text))
        if got != sorted(want):
            failures.append(f'{label}: want {sorted(want)}, got {got}')

    expect('the two real allowlisted members are SEEN: isolates the population, the thing a blind '
           'scan would silently lose',
           '''
           struct OCCTEdgeCurve
           {
             BRepAdaptor_Curve adaptor;
             explicit OCCTEdgeCurve(const TopoDS_Edge& e)
                 : adaptor(e)
             {
             }
           };
           struct OCCTCompCurve
           {
             BRepAdaptor_CompCurve adaptor;
           };
           ''',
           [('OCCTEdgeCurve', 'BRepAdaptor_Curve'), ('OCCTCompCurve', 'BRepAdaptor_CompCurve')])

    expect('a new struct member of a GeomAdaptor type: the defect itself',
           'struct OCCTThing\n{\n  GeomAdaptor_Curve cache;\n};\n',
           [('OCCTThing', 'GeomAdaptor_Curve')])

    expect('Handle() macro form: isolates TYPE_EXPR`s Handle alternative',
           'struct OCCTThing\n{\n  Handle(Adaptor3d_Curve) cache;\n};\n',
           [('OCCTThing', 'Adaptor3d_Curve')])

    expect('opencascade::handle<> template form: isolates the template alternative',
           'struct OCCTThing\n{\n  opencascade::handle<GeomAdaptor_Surface> s;\n};\n',
           [('OCCTThing', 'GeomAdaptor_Surface')])

    expect('pointer member: isolates the [*&] skip between type and name',
           'struct OCCTThing\n{\n  Adaptor3d_Surface* s = nullptr;\n};\n',
           [('OCCTThing', 'Adaptor3d_Surface')])

    expect('class with an access specifier: isolates the `class` head and the label line',
           'class OCCTThing\n{\npublic:\n  Geom2dAdaptor_Curve c;\n};\n',
           [('OCCTThing', 'Geom2dAdaptor_Curve')])

    expect('brace on the SAME line as the head: isolates head tracking from brace-on-next-line',
           'struct OCCTThing {\n  GeomAdaptor_Curve c;\n};\n',
           [('OCCTThing', 'GeomAdaptor_Curve')])

    expect('file-scope global: isolates the file scope, a shared adaptor with no struct at all',
           'static GeomAdaptor_Curve gShared;\n',
           [('<file scope>', 'GeomAdaptor_Curve')])

    expect('function-local static: isolates the static-anywhere rule, since a local static is '
           'process-wide',
           'void f()\n{\n  static BRepAdaptor_Curve c;\n}\n',
           [('<function static>', 'BRepAdaptor_Curve')])

    expect('per-call local inside a function: the correct pattern, and the one the bridge uses '
           'everywhere, must stay quiet',
           'double f(const TopoDS_Edge& e)\n{\n  BRepAdaptor_Curve c(e);\n  GeomAdaptor_Curve g;\n'
           '  return c.Value(0.0).X();\n}\n',
           [])

    expect('local inside a method of a struct: isolates the other-scope frame under a type frame',
           'struct OCCTThing\n{\n  double f(const TopoDS_Edge& e)\n  {\n    BRepAdaptor_Curve c(e);\n'
           '    return 0.0;\n  }\n};\n',
           [])

    expect('adaptor as a PARAMETER or return type of a method declaration: not storage',
           'struct OCCTThing\n{\n  void use(BRepAdaptor_Curve& c);\n  BRepAdaptor_Curve make();\n};\n',
           [])

    expect('adaptor named only in a line comment: isolates comment stripping',
           'struct OCCTThing\n{\n  // GeomAdaptor_Curve cache;\n  int x;\n};\n',
           [])

    expect('adaptor named only in a block comment: isolates block-comment stripping',
           'struct OCCTThing\n{\n  /* GeomAdaptor_Curve cache; */\n  int x;\n};\n',
           [])

    expect('a stray brace in a comment must not desynchronise the scope stack, so the real '
           'member below is still attributed to its struct',
           'struct OCCTThing\n{\n  // an unmatched { in prose\n  GeomAdaptor_Curve c;\n};\n',
           [('OCCTThing', 'GeomAdaptor_Curve')])

    expect('member AFTER a nested function body in the same struct: isolates brace popping',
           'struct OCCTThing\n{\n  int f()\n  {\n    return 1;\n  }\n  GeomAdaptor_Curve c;\n};\n',
           [('OCCTThing', 'GeomAdaptor_Curve')])

    expect('namespace scope: isolates the namespace frame',
           'namespace\n{\nGeomAdaptor_Curve gShared;\n}\n',
           [('<namespace>', 'GeomAdaptor_Curve')])

    expect('a non-adaptor member that merely mentions the word: BRepAdaptor alone is not a class',
           'struct OCCTThing\n{\n  int adaptorCount;\n  Handle(Geom_Curve) curve;\n};\n',
           [])

    # The allowlist and the Swift half, through evaluate().
    def run(hits_text, swift):
        hits = scan_text(hits_text)
        return evaluate(hits, swift)

    edge = 'struct OCCTEdgeCurve\n{\n  BRepAdaptor_Curve adaptor;\n};\n'
    comp = 'struct OCCTCompCurve\n{\n  BRepAdaptor_CompCurve adaptor;\n};\n'
    swift_ok = [('EdgeCurve.swift', 'public final class EdgeCurve: ArcLengthCurveAdaptor {\n}\n'),
                ('WireCurve.swift', 'public final class WireCurve: ArcLengthCurveAdaptor {\n}\n')]

    findings, stale, claims, refusals = run(edge + comp, swift_ok)
    if findings or stale or claims or refusals:
        failures.append(f'the real shape must be clean, got {findings} {stale} {claims} {refusals}')

    findings, *_ = run(edge + comp + 'struct OCCTNew\n{\n  GeomAdaptor_Curve c;\n};\n', swift_ok)
    if [f[2] for f in findings] != ['OCCTNew']:
        failures.append(f'an unlisted struct must be a finding, got {findings}')

    findings, *_ = run(edge.replace('BRepAdaptor_Curve', 'GeomAdaptor_Curve') + comp, swift_ok)
    if [f[2] for f in findings] != ['OCCTEdgeCurve']:
        failures.append('an allowlisted STRUCT holding a different adaptor TYPE must be a finding: '
                        f'the key is (struct, type), got {findings}')

    _, stale, *_ = run(comp + 'struct OCCTThing\n{\n  GeomAdaptor_Curve c;\n};\n', swift_ok)
    if stale != [('OCCTEdgeCurve', 'BRepAdaptor_Curve')]:
        failures.append(f'an allowlist entry matching nothing must be stale, got {stale}')

    *_, refusals = run('struct OCCTThing\n{\n  int x;\n};\n', swift_ok)
    if not refusals:
        failures.append('a population of zero must be a refusal, not a clean run')

    _, _, claims, _ = run(edge + comp, [
        ('EdgeCurve.swift', 'public final class EdgeCurve: ArcLengthCurveAdaptor, @unchecked Sendable {\n}\n'),
        swift_ok[1]])
    if claims != [('EdgeCurve.swift', 'EdgeCurve')]:
        failures.append(f'a Sendable class declaration must be a claim, got {claims}')

    _, _, claims, _ = run(edge + comp, swift_ok + [
        ('X.swift', 'extension WireCurve: @unchecked Sendable {\n}\n')])
    if claims != [('X.swift', 'WireCurve')]:
        failures.append(f'a Sendable extension must be a claim, got {claims}')

    _, _, claims, _ = run(edge + comp, [
        ('EdgeCurve.swift', '// public final class EdgeCurve: Sendable {\npublic final class EdgeCurve {\n}\n'),
        swift_ok[1]])
    if claims:
        failures.append(f'Sendable named only in a comment must not be a claim, got {claims}')

    *_, refusals = run(edge + comp, [swift_ok[0]])
    if not refusals:
        failures.append('a missing Swift class must be a refusal, not a pass')

    if failures:
        print('SELF-TEST FAILED:')
        for f in failures:
            print('  ' + f)
        return 1
    print('check-bridge-adaptor-members --self-test: all cases pass')
    return 0


if __name__ == '__main__':
    sys.exit(main())
