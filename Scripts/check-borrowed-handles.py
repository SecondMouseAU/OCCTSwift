#!/usr/bin/env python3
"""Fail on a Swift value type that STORES a native OCCT handle (#965).

A `*Ref` handle is owned by exactly one reference type, whose `deinit` calls the matching
`Release`. A struct has no `deinit`, so a struct that stores an `OCCT*Ref` cannot own the
handle it holds: it is borrowing one whose lifetime it does not control. The moment such a
value outlives the object it borrowed from, reading it is a use-after-free.

That is #965, and it was not one accessor: 19 `*Properties` views across Curve2D.swift (7),
Curve3D.swift (5) and Surface.swift (7) stored `fileprivate let handle: OCCT*Ref`, so
`edge.curve3D?.circleProperties.radius` - the spelling `Edge.curve3D`'s own doc comment
recommends - ended the process with SIGSEGV, and an escaped view that happened not to crash
read a later allocation's radius instead (measured: 1001.0 where 7.0 was expected).

The fix conforms each view to `NativeHandleView`, which stores the OWNER and reads the handle
through it. Nineteen hand-written retains can silently become eighteen; this gate is what stops
that. It says nothing about whether a conformance exists, only that no struct or enum in
Sources/OCCTSwift stores a raw handle, which is the property that actually matters and the one
a twentieth view would violate.

Reference types are exempt because they can release what they hold, and this gate does not
check that they do. Enums are treated like structs: no `deinit` there either.

Usage:
  Scripts/check-borrowed-handles.py
  Scripts/check-borrowed-handles.py --self-test
"""
import argparse
import glob
import os
import re
import sys

SOURCE_GLOB = 'Sources/OCCTSwift/*.swift'

# Value types permitted to store a raw handle, keyed (file, type, property). Empty, and it should
# stay that way: an entry here is a value whose handle nothing keeps alive, so it needs the same
# measurement #965 got before it is written down. Match check-null-handle-guards.py's ALLOWED in
# spirit - a measured reason per line, not a silencer.
ALLOWED = {
    # ('Sources/OCCTSwift/Example.swift', 'Thing', 'handle'): 'why this one cannot dangle',
}

VALUE_KINDS = ('struct', 'enum')
TYPE_KINDS = ('struct', 'class', 'enum', 'actor', 'extension', 'protocol')

TYPE_DECL_RE = re.compile(
    r'\b(struct|class|enum|actor|extension|protocol)\s+([A-Za-z_]\w*)')

# A stored-property declaration: optional attributes and modifiers, then let/var, a name, and an
# explicit type annotation. `static`/`class` are matched so a static stored handle is caught too.
PROPERTY_RE = re.compile(
    r'^(?:@\w+(?:\([^)]*\))?\s+)*'
    r'(?:(?:public|internal|fileprivate|private|open)(?:\(set\))?\s+)*'
    r'(?:static\s+|class\s+)?'
    r'(?:weak\s+|unowned\s+)?'
    r'(let|var)\s+([A-Za-z_]\w*)\s*:\s*([^=\n]+?)\s*(\{|=|$)')

HANDLE_TYPE_RE = re.compile(r'^OCCT\w*Ref[!?]?$')

LINE_COMMENT_RE = re.compile(r'//.*$')


def strip_comments(lines):
    """Blank out line comments and block-comment interiors.

    A `Ref` named inside a comment is not a stored property, and a block comment containing
    braces would otherwise desynchronise the scope stack. The block handling is deliberately
    line-based rather than a full lexer: it clears from `/*` to the matching `*/`, including a
    closing `*/` that shares its line with real code, which is the hole #680 found in a sibling
    script's equivalent guard.
    """
    out = []
    in_block = False
    for line in lines:
        if in_block:
            end = line.find('*/')
            if end == -1:
                out.append('')
                continue
            line = ' ' * (end + 2) + line[end + 2:]
            in_block = False
        # Repeatedly clear any /* ... */ that opens on this line.
        while True:
            start = line.find('/*')
            if start == -1:
                break
            end = line.find('*/', start + 2)
            if end == -1:
                line = line[:start]
                in_block = True
                break
            line = line[:start] + ' ' * (end + 2 - start) + line[end + 2:]
        out.append(LINE_COMMENT_RE.sub('', line))
    return out


def scan_lines(lines, path):
    """Return [(path, line_no, kind, type_name, property_name, type_text)] for every stored
    handle declared directly inside a value type.

    Scope tracking is by net brace delta, with each opened scope labelled from the declaring
    line: a `struct`/`class`/... line opens a TYPE scope, anything else (a func, an initialiser,
    a computed property, a closure, an `if`) opens a non-type scope. A property counts as a
    member only when the innermost open scope is a type scope, which is what keeps a local
    `let h: OCCTShapeRef? = ...` inside a method from being reported.
    """
    findings = []
    stack = []  # (kind, name)
    lines = strip_comments(lines)

    for index, raw in enumerate(lines):
        line = raw.rstrip()
        stripped = line.strip()

        if stripped:
            enclosing = stack[-1] if stack else None
            if enclosing and enclosing[0] in VALUE_KINDS:
                match = PROPERTY_RE.match(stripped)
                if match:
                    _keyword, name, type_text, tail = match.groups()
                    computed = tail == '{' or _opens_a_body_next(lines, index)
                    type_head = type_text.split()[0].strip() if type_text.split() else ''
                    if not computed and HANDLE_TYPE_RE.match(type_head):
                        key = (path, enclosing[1], name)
                        if key not in ALLOWED:
                            findings.append(
                                (path, index + 1, enclosing[0], enclosing[1], name, type_head))

        opens = line.count('{')
        closes = line.count('}')

        for _ in range(min(closes, len(stack)) if closes >= opens else 0):
            stack.pop()

        if opens > closes:
            decl = TYPE_DECL_RE.search(line)
            kind = decl.group(1) if decl and _declares_a_type(line, decl) else None
            name = decl.group(2) if kind else ''
            stack.append((kind or 'other', name))
            for _ in range(opens - closes - 1):
                stack.append(('other', ''))
        elif closes > opens and closes < opens + len(stack) + 1:
            for _ in range(closes - opens):
                if stack:
                    stack.pop()

    return findings


def _declares_a_type(line, match):
    """True when the `struct`/`class`/... keyword really opens a type declaration here.

    Guards the two spellings that mention a type keyword without declaring one: a conformance
    list or generic constraint naming `AnyObject`-style keywords is not one of them, but
    `case struct` and a string literal are, and so is `indirect enum` (which does declare, and
    must stay matched).
    """
    prefix = line[:match.start()]
    return '"' not in prefix and not prefix.rstrip().endswith('.')


def _opens_a_body_next(lines, index):
    """True when the next non-blank line opens a body, i.e. the declaration is computed with its
    brace on the following line. Without this the `var handle: Owner.NativeHandle` shape written
    across two lines reads as stored.
    """
    for line in lines[index + 1:]:
        stripped = line.strip()
        if not stripped:
            continue
        return stripped.startswith('{')
    return False


def scan_file(path):
    with open(path, encoding='utf-8') as fh:
        return scan_lines(fh.read().splitlines(), path)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    findings = []
    for path in sorted(glob.glob(SOURCE_GLOB)):
        findings.extend(scan_file(path))

    if findings:
        print(f'FAIL: {len(findings)} value type(s) store a native OCCT handle they do not own:')
        for path, line_no, kind, type_name, name, type_text in findings:
            print(f'  {path}:{line_no}  {kind} {type_name}.{name}: {type_text}')
        print('  A struct or enum has no deinit, so it cannot release what it holds. Store the')
        print('  owning class and conform to NativeHandleView, which reads the handle through it.')
        print('  See Sources/OCCTSwift/NativeHandleView.swift and #965.')
        return 1

    print('check-borrowed-handles: clean, no value type stores a native OCCT handle')
    return 0


def self_test():
    """Fixture battery over scan_lines(), no filesystem and no repo needed.

    Each case names the mechanism it isolates, because a case that agrees with its neighbour
    for an unrelated reason is not coverage (okf/policies/prove-the-test-fails.md).
    """
    cases = [
        ('struct storing a bare handle: the #965 defect itself',
         '''
         public struct CircleProperties: @unchecked Sendable {
             fileprivate let handle: OCCTCurve3DRef
             public var radius: Double { OCCTCurve3DCircleRadius(handle) }
         }
         ''',
         [('CircleProperties', 'handle')]),

        ('struct storing an OPTIONAL handle: isolates the ? suffix, which the type regex would '
         'otherwise reject outright',
         '''
         struct Thing {
             let handle: OCCTShapeRef?
         }
         ''',
         [('Thing', 'handle')]),

        ('struct with a COMPUTED handle: isolates the stored/computed split, the whole basis of '
         'the fix, since the fixed views all read `handle` this way',
         '''
         struct CircleProperties {
             let owner: Curve3D
             var handle: OCCTCurve3DRef { owner.handle }
         }
         ''',
         []),

        ('computed handle whose brace is on the NEXT line: isolates _opens_a_body_next, which is '
         'the only thing separating this from the stored case above',
         '''
         struct CircleProperties {
             let owner: Curve3D
             var handle: OCCTCurve3DRef
             {
                 owner.handle
             }
         }
         ''',
         []),

        ('CLASS storing a handle: isolates the value/reference split, since a class has a deinit '
         'to release it and every parent in the tree is one',
         '''
         public final class Curve3D {
             internal let handle: OCCTCurve3DRef
             deinit { OCCTCurve3DRelease(handle) }
         }
         ''',
         []),

        ('LOCAL handle inside a method of a struct: isolates the func-scope frame, the largest '
         'false-positive source in the real tree (Shape.swift alone has five)',
         '''
         struct Builder {
             let owner: Shape
             func build() -> Shape? {
                 let handle: OCCTShapeRef? = OCCTShapeCopy(owner.handle)
                 return handle.map(Shape.init)
             }
         }
         ''',
         []),

        ('struct storing the OWNER rather than the handle: the shape the fix produces, and the '
         'one a passing gate must not flag',
         '''
         public struct SphereProperties: Sendable, NativeHandleView {
             let owner: Surface
             public var radius: Double { OCCTSurfaceSphereRadius(handle) }
         }
         ''',
         []),

        ('struct NESTED in a class, storing a handle: isolates the nesting, which is how all 19 '
         'real sites are written and which a top-level-only scanner would miss entirely',
         '''
         public final class Surface {
             let handle: OCCTSurfaceRef
             public struct PlaneProperties: Sendable {
                 fileprivate let handle: OCCTSurfaceRef
             }
         }
         ''',
         [('PlaneProperties', 'handle')]),

        ('STATIC stored handle on a struct: isolates the static modifier, which the property '
         'regex has to skip past rather than treat as the let/var keyword',
         '''
         struct Cache {
             static var handle: OCCTShapeRef = makeIt()
         }
         ''',
         [('Cache', 'handle')]),

        ('handle named only in a comment: ISOLATES NOTHING, and is kept because saying so is more '
         'useful than deleting it. Removing either comment guard leaves this case correct, since '
         'PROPERTY_RE is ^-anchored and a line starting `//` or `/*` never matches it anyway. The '
         'three cases below are the ones that actually hold strip_comments up',
         '''
         struct Thing {
             // fileprivate let handle: OCCTShapeRef
             /* let handle: OCCTShapeRef */
             let owner: Shape
         }
         ''',
         []),

        ('unbalanced brace in a LINE comment: isolates line-comment stripping. The stray `{` opens '
         'a phantom scope, so the real member below reads as a local and is silently not reported',
         '''
         struct Thing {
             // an unmatched { in prose
             let handle: OCCTShapeRef
         }
         ''',
         [('Thing', 'handle')]),

        ('unbalanced brace in a SINGLE-LINE block comment: isolates the /* ... */ clear on one '
         'line, which is a separate code path from the multi-line tracking below',
         '''
         struct Thing {
             /* an unmatched { in prose */
             let handle: OCCTShapeRef
         }
         ''',
         [('Thing', 'handle')]),

        ('MULTI-LINE block comment containing braces: isolates the in_block tracking, the hole '
         '#680 found in a sibling script',
         '''
         struct Thing {
             /* func f() {
                let handle: OCCTShapeRef? = nil
             } */
             let handle: OCCTShapeRef
         }
         ''',
         [('Thing', 'handle')]),

        ('ENUM storing a static handle: isolates enums being treated as value types, which they '
         'are, having no deinit either',
         '''
         enum Registry {
             static let handle: OCCTShapeRef = shared()
         }
         ''',
         [('Registry', 'handle')]),

        ('non-handle stored properties only: the clean-tree control, so a detector that flags '
         'everything cannot pass this battery',
         '''
         public struct Hit {
             public let x: Double, y: Double
             public let face: Int
         }
         ''',
         []),
    ]

    failed = 0
    for name, source, expected in cases:
        lines = [line[9:] if line.startswith(' ' * 9) else line
                 for line in source.strip('\n').splitlines()]
        got = [(f[3], f[4]) for f in scan_lines(lines, 'fixture.swift')]
        ok = got == expected
        failed += not ok
        print(f'  {"ok  " if ok else "MISS"} {name}')
        if not ok:
            print(f'         expected {expected}, got {got}')

    print(f'{len(cases) - failed}/{len(cases)} cases correct')
    return 1 if failed else 0


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
