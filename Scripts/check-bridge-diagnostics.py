#!/usr/bin/env python3
"""Gate: every function-level `catch (...)` in the bridge records what it caught (#2077).

#1161 shipped a diagnostics channel, `occtRecordCaughtException`, that reclassifies the exception a
`catch (...)` block already holds and hands its OCCT type name and message to Swift through
`OCCTDiagnostics`. #2077 swept it across all 74 `Sources/OCCTBridge/src/*.mm` files. This gate is
what keeps the sweep from decaying: a new bridge function written with a bare
`catch (...) { return nullptr; }` returns a `nil` that explains nothing, and nothing but this would
notice.

WHAT IT ASSERTS. For every FUNCTION-LEVEL `catch (...)` block, the first statement of the block is
`occtRecordCaughtException(__func__);`. Comments may precede it; another statement may not, because
anything that runs first can itself throw, and a `throw;` re-raised after the in-flight exception has
been replaced classifies the wrong one.

WHAT "FUNCTION LEVEL" MEANS, and why the rule stops there: under `Sources/OCCTBridge/.clang-format`
the bridge is indented two spaces per level with the brace on its own line, so a `catch (...)` at
indent 2 inside a top-level function body is the one that fails the whole call. Measured over the
tree at the time of writing, all 3,599 of them are the ONLY function-level try/catch in their own
function, so each is unambiguously "this call refused". A deeper catch sits inside a loop or an inner
try and is frequently ordinary recover-and-continue control flow, where recording would report a
failure for a call that went on to succeed; those need a per-site human verdict, carry a comment in
the source saying which way it went, and are outside this gate. `Scripts/add-bridge-diagnostics.py`
draws the same line and reports them rather than editing them.

EXEMPTIONS. A function-level site that must not record goes in EXEMPT below with a written reason.
There are exactly two, both in OCCTBridge.mm and both inside the diagnostics channel itself, where a
record would feed itself. Nothing else in the bridge qualifies: a function-level block cannot
`continue` a loop it is not inside, and no bridge function has a second function-level try for a
fallback to live in, so a function-level catch always refuses the call. An exemption for a site that
has since been deleted, renamed or instrumented is itself a finding, which is what keeps the list
from becoming an allowlist nobody rereads.

TWO BLINDNESS GUARDS, because a gate reporting clean with a broken parser looks exactly like one
reporting clean on a clean tree (okf/policies/prove-the-test-fails.md):

  * `unresolved-function`. A site whose enclosing function name cannot be read is a failure, not a
    site to skip. It is also not hypothetical: a first version of this parser walked forward from
    each column-0 `{` looking for a column-0 `}`, which walks straight past a `struct` (it closes
    with `};`) and left 103 of the tree's sites attributed to the struct above them, where no
    exemption could ever have named them.
  * `parser-blind`. If the sources contain the text `catch (...)` anywhere and the parser finds no
    function-level site at all, that is a failure rather than "0 of 0 clean". This is the guard that
    fires if the bridge ever stops being indented two spaces per level, since the indent is the
    whole of how function level is recognised. It is deliberately written against a search with no
    indent rule, so it is not the same rule compared with itself: a first version compared the
    parser's count against a second count using the SAME pattern, and the removal matrix showed it
    could never fire.

WHAT THIS GATE IS NOT. It says nothing about OS signals. `OCC_CONVERT_SIGNALS` is undefined in this
build, so `OCC_CATCH_SIGNALS` expands to nothing and a SIGSEGV/SIGBUS/SIGFPE raised inside OCCT
reaches no `catch` clause at any coverage level. See docs/reference/Diagnostics.md.

Usage:
  Scripts/check-bridge-diagnostics.py
  Scripts/check-bridge-diagnostics.py --list        # every site and its verdict
  Scripts/check-bridge-diagnostics.py --self-test
"""
import argparse
import glob
import os
import re
import sys

SRC_GLOB = 'Sources/OCCTBridge/src/*.mm'
CALL = 'occtRecordCaughtException(__func__);'
# Prefix-anchored, not end-anchored: clang-format always puts the body's brace on its own line, but
# a hand edit can write `catch (...) {`, and a site the parser cannot see is a site the gate cannot
# check.
CATCH_LINE = re.compile(r'^  catch \(\.\.\.\)')

# Function-level catch blocks that deliberately do NOT record, keyed by (file basename, enclosing
# function name), with the reason. Each reason is also written at the site itself, which is what
# stops Scripts/add-bridge-diagnostics.py reinserting the call on its next run: that script treats a
# block whose first four lines mention occtRecordCaughtException as already handled.
EXEMPT = {
    ('OCCTBridge.mm', 'occtRecordCaughtException'):
        'this IS the classifier. A call here would `throw;` the same exception, land in this same '
        'clause and recurse until the stack ran out. #2077 measured the sweep script inserting one '
        'and reverted it.',
    ('OCCTBridge.mm', 'occtDiagnosticsLog'):
        'the tail of occtRecordCaughtException itself, reached only while a record is being sent. '
        'A diagnostic that throws must not become the failure being diagnosed.',
}


class Site:
    def __init__(self, path, function, catch_line, first_statement, has_call, call_line):
        self.path = path
        self.function = function or '(unresolved)'
        self.resolved = function is not None
        self.catch_line = catch_line
        self.first_statement = first_statement
        self.has_call = has_call
        self.call_line = call_line

    @property
    def key(self):
        return (os.path.basename(self.path), self.function)

    @property
    def instrumented(self):
        return self.first_statement == '    ' + CALL


def function_name(signature):
    """The declared name in a (possibly multi-line) C/ObjC++ signature, or None."""
    text = ' '.join(part.strip() for part in signature)
    paren = text.find('(')
    if paren < 0:
        return None
    before = text[:paren]
    names = re.findall(r'[A-Za-z_][A-Za-z0-9_]*', before)
    return names[-1] if names else None


def enclosing_signature(lines, index):
    """The signature lines of the top-level definition whose body encloses `lines[index]`.

    The nearest preceding line that is a bare `{` in column 0 opens that body. No brace matching is
    involved, deliberately: a first version walked forward from each `{` looking for a `}` in column
    0, which walks straight past a `struct` (it closes with `};`) and attributed 103 of the tree's
    catch sites to the struct above them instead of their own function. A struct's own members are
    indented, so a catch at indent 2 can only ever sit in a top-level function body.
    """
    brace = None
    for j in range(index, -1, -1):
        if lines[j] == '{':
            brace = j
            break
    if brace is None:
        return []
    signature = []
    j = brace - 1
    while j >= 0 and lines[j].strip() and not lines[j].lstrip().startswith('//'):
        signature.insert(0, lines[j])
        j -= 1
    return signature


def scan(path, text):
    """Every function-level catch (...) block in one .mm file."""
    lines = text.split('\n')
    sites = []
    for k, line in enumerate(lines):
        if not CATCH_LINE.match(line):
            continue
        name = function_name(enclosing_signature(lines, k))
        if k + 1 >= len(lines) or lines[k + 1] != '  {':
            # A catch whose body does not open with a bare brace. clang-format never writes one, and
            # the first statement of a body the parser cannot locate cannot be read, so the site is
            # recorded with no first statement rather than skipped.
            sites.append(Site(path, name, k + 1, None, False, None))
            continue
        first = None
        call_line = None
        for m in range(k + 2, len(lines)):
            if lines[m] == '  }':
                break
            stripped = lines[m].strip()
            if stripped == CALL and call_line is None:
                call_line = m + 1
            if first is None and stripped and not stripped.startswith('//'):
                first = lines[m]
        sites.append(Site(path, name, k + 1, first, call_line is not None, call_line))
    return sites


def any_catch_all(text):
    """`catch (...)` anywhere in the file, at any indent, comments included.

    Independent of the indent rule on purpose: it is what tells a tree whose bridge has stopped
    being indented two spaces per level (so scan() finds nothing) apart from a tree with no catch
    blocks left. Without it, "0 of 0 sites are instrumented" reads as clean.
    """
    return 'catch (...)' in text


def collect(glob_pattern=SRC_GLOB):
    return {path: open(path, encoding='utf-8').read() for path in sorted(glob.glob(glob_pattern))}


def findings(sources):
    """(problems, sites): every verdict this gate reaches over `sources`."""
    problems = []
    sites = []
    catch_all_text = False
    for path, text in sources.items():
        catch_all_text = catch_all_text or any_catch_all(text)
        sites += scan(path, text)
    if catch_all_text and not sites:
        problems.append(('parser-blind', SRC_GLOB, '(whole tree)',
                         'the sources contain `catch (...)` and the parser found no function-level '
                         'site at all'))

    for site in sites:
        if not site.resolved:
            problems.append(('unresolved-function', site.path, '(line %d)' % site.catch_line,
                             'the enclosing function name could not be read, so no exemption '
                             'could ever name this site'))

    by_key = {}
    for site in sites:
        by_key.setdefault(site.key, []).append(site)

    for site in sites:
        reason = EXEMPT.get(site.key)
        if site.instrumented:
            if reason is not None:
                problems.append(('exempt-but-instrumented', site.path, site.function,
                                 'on the exemption list and yet records; drop the exemption'))
            continue
        if reason is not None:
            continue
        if site.has_call:
            problems.append(('not-first', site.path, site.function,
                             'records at line %d, after %r' % (site.call_line,
                                                               (site.first_statement or '').strip())))
        else:
            problems.append(('missing', site.path, site.function,
                             'no occtRecordCaughtException(__func__); as its first statement'))

    for key, reason in sorted(EXEMPT.items()):
        if key not in by_key:
            problems.append(('stale-exemption', key[0], key[1],
                             'exempted, but there is no function-level catch (...) there'))
        elif not str(reason).strip():
            problems.append(('empty-reason', key[0], key[1],
                             'exempted with no written reason'))
    return problems, sites


def run():
    sources = collect()
    if not sources:
        print('check-bridge-diagnostics: no %s, run from the repo root' % SRC_GLOB)
        return 2
    problems, sites = findings(sources)
    instrumented = sum(1 for s in sites if s.instrumented)
    if not problems:
        print('check-bridge-diagnostics: clean, %d of %d function-level catch (...) blocks in %d '
              'file(s) record what they caught, %d exempt with a written reason'
              % (instrumented, len(sites), len(sources), len(EXEMPT)))
        return 0
    print('check-bridge-diagnostics: %d problem(s) across %d function-level catch (...) blocks\n'
          % (len(problems), len(sites)))
    for kind, path, function, detail in problems:
        print('  %-24s %s :: %s' % (kind, os.path.basename(path), function))
        print('      %s' % detail)
    print('\nA function-level catch (...) is the block that fails the whole call, so it records the '
          'OCCT\nexception it caught as its first statement:\n')
    print('  catch (...)\n  {\n    %s\n    return nullptr;\n  }\n' % CALL)
    print('Scripts/add-bridge-diagnostics.py writes that line for you, then run '
          'Scripts/format-bridge.sh.\nA block that must NOT record belongs in this script\'s EXEMPT '
          'map with its reason. #2077.')
    return 1


def list_sites():
    sources = collect()
    problems, sites = findings(sources)
    for site in sites:
        verdict = 'records' if site.instrumented else (
            'EXEMPT' if site.key in EXEMPT else 'MISSING')
        print('  %-8s %s:%d %s' % (verdict, os.path.basename(site.path), site.catch_line,
                                   site.function))
    print('%d site(s), %d recording, %d exempt, %d problem(s)'
          % (len(sites), sum(1 for s in sites if s.instrumented), len(EXEMPT), len(problems)))
    return 0


# --- self-test ---------------------------------------------------------------------------------
#
# Every case holds one guard down, and each was checked by removing that guard and watching the
# case count drop (okf/policies/prove-the-test-fails.md). The three the issue asked for are
# "a removed call", "a call that is not first" and "an exemption for a site that no longer exists".

CLEAN = '''\
OCCTShapeRef OCCTShapeThing(OCCTShapeRef shape)
{
  if (!shape)
    return nullptr;
  try
  {
    return new OCCTShape(shape->shape);
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}
'''

REMOVED_CALL = '''\
OCCTShapeRef OCCTShapeThing(OCCTShapeRef shape)
{
  try
  {
    return new OCCTShape(shape->shape);
  }
  catch (...)
  {
    return nullptr;
  }
}
'''

NOT_FIRST = '''\
OCCTShapeRef OCCTShapeThing(OCCTShapeRef shape)
{
  try
  {
    return new OCCTShape(shape->shape);
  }
  catch (...)
  {
    occtEnsureSignals();
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}
'''

COMMENT_FIRST = '''\
OCCTShapeRef OCCTShapeThing(OCCTShapeRef shape)
{
  try
  {
    return new OCCTShape(shape->shape);
  }
  catch (...)
  {
    // A comment is not a statement, and this is the shape a site that needs a note takes.
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}
'''

UNINSTRUMENTED_DEEPER = '''\
static std::vector<gp_Pnt> occtSampleThings(const TopoDS_Wire& wire)
{
  std::vector<gp_Pnt> pts;
  try
  {
    for (BRepTools_WireExplorer it(wire); it.More(); it.Next())
    {
      try
      {
        pts.push_back(gp_Pnt());
      }
      catch (...)
      {
        continue;
      }
    }
  }
  catch (...)
  {
    occtRecordCaughtException(__func__);
    pts.clear();
  }
  return pts;
}
'''

# clang-format never writes this, but a hand edit can, and a body that does not open with a bare
# brace is a site whose first statement the parser cannot read. It must not pass for free.
BRACE_ON_CATCH_LINE = '''\
OCCTShapeRef OCCTShapeThing(OCCTShapeRef shape)
{
  try
  {
    return new OCCTShape(shape->shape);
  }
  catch (...) {
    // The call sits on the body's SECOND line on purpose: a parser that assumed the bare brace
    // would start reading one line late, find the call, and pass a site it never located.
    occtRecordCaughtException(__func__);
    return nullptr;
  }
}
'''

MULTILINE_SIGNATURE = '''\
OCCTShapeRef OCCTShapeThingWithAVeryLongName(OCCTShapeRef shape,
                                             double       first,
                                             double       second)
{
  try
  {
    return new OCCTShape(shape->shape);
  }
  catch (...)
  {
    return nullptr;
  }
}
'''


def self_test():
    cases = [
        ('a clean file reports nothing',
         'the whole parser: a site it cannot find cannot be checked',
         {'OCCTBridge_Fixture.mm': CLEAN}, {}, []),

        ('a removed call is reported',
         'the first-statement assertion, the issue\'s case 1',
         {'OCCTBridge_Fixture.mm': REMOVED_CALL}, {},
         [('missing', 'OCCTShapeThing')]),

        ('a call that is not first is reported',
         'the ordering half of the assertion, the issue\'s case 2: the call is present, so a '
         'presence-only check passes here',
         {'OCCTBridge_Fixture.mm': NOT_FIRST}, {},
         [('not-first', 'OCCTShapeThing')]),

        ('a comment before the call is not a statement',
         'the comment skip, without which every annotated site would be reported as not-first',
         {'OCCTBridge_Fixture.mm': COMMENT_FIRST}, {}, []),

        ('an exemption for a site that no longer exists is reported',
         'the stale-exemption sweep, the issue\'s case 3',
         {'OCCTBridge_Fixture.mm': CLEAN},
         {('OCCTBridge_Fixture.mm', 'OCCTShapeGone'): 'gone'},
         [('stale-exemption', 'OCCTShapeGone')]),

        ('an exemption with a written reason silences its site',
         'the exemption lookup itself: without it the list could never silence anything',
         {'OCCTBridge_Fixture.mm': REMOVED_CALL},
         {('OCCTBridge_Fixture.mm', 'OCCTShapeThing'): 'recovers, and here is why'},
         []),

        ('an exemption with an empty reason is reported',
         'the written-reason requirement, which is what stops the list becoming a silent allowlist',
         {'OCCTBridge_Fixture.mm': REMOVED_CALL},
         {('OCCTBridge_Fixture.mm', 'OCCTShapeThing'): '   '},
         [('empty-reason', 'OCCTShapeThing')]),

        ('an exemption for a site that records is reported',
         'the other half of staleness: the list and the source disagreeing in the opposite '
         'direction, which a stale-key sweep alone cannot see',
         {'OCCTBridge_Fixture.mm': CLEAN},
         {('OCCTBridge_Fixture.mm', 'OCCTShapeThing'): 'recovers'},
         [('exempt-but-instrumented', 'OCCTShapeThing')]),

        ('an uninstrumented DEEPER catch is not reported',
         'the indent-2 restriction: a recover-and-continue catch inside a loop is not this gate\'s '
         'subject, and reporting it would make the gate unfixable',
         {'OCCTBridge_Fixture.mm': UNINSTRUMENTED_DEEPER}, {}, []),

        ('a catch whose body opens on the catch line is reported',
         'the bare-brace requirement: the parser cannot read a first statement it cannot locate, '
         'so the site must fail rather than pass unread',
         {'OCCTBridge_Fixture.mm': BRACE_ON_CATCH_LINE}, {},
         [('missing', 'OCCTShapeThing')]),

        ('a multi-line signature still resolves to its function name',
         'function_name() over a wrapped signature, which is how the bridge writes anything with '
         'more than two parameters; a parser that lost the name here would key every exemption on '
         '(unnamed)',
         {'OCCTBridge_Fixture.mm': MULTILINE_SIGNATURE}, {},
         [('missing', 'OCCTShapeThingWithAVeryLongName')]),
    ]

    global EXEMPT
    saved = EXEMPT
    failed = 0
    print('findings cases')
    for name, isolates, sources, exempt, expected in cases:
        EXEMPT = exempt
        try:
            problems, _ = findings(sources)
        finally:
            EXEMPT = saved
        got = [(kind, function) for kind, _, function, _ in problems]
        ok = sorted(got) == sorted(expected)
        failed += not ok
        print('  %s %s' % ('ok  ' if ok else 'MISS', name))
        print('       isolates: %s' % isolates)
        if not ok:
            print('       expected %s, got %s' % (expected, got))

    # The canary cannot be reached through findings() on a well-formed fixture: the parser and the
    # line count agree by construction. Assert on the two counters directly, so the case isolates
    # the canary rather than passing for free.
    print('counting cases')
    canary_cases = [
        ('one function, one site', CLEAN, 1),
        ('a function with a deeper catch as well still has exactly one site',
         UNINSTRUMENTED_DEEPER, 1),
        ('a brace on the catch line is still located as a site', BRACE_ON_CATCH_LINE, 1),
    ]
    for name, text, expect_sites in canary_cases:
        got_sites = len(scan('fixture.mm', text))
        ok = got_sites == expect_sites
        failed += not ok
        print('  %s %s' % ('ok  ' if ok else 'MISS', name))
        if not ok:
            print('       expected %d site(s), got %d' % (expect_sites, got_sites))

    # And prove both blindness guards FIRE, which is the only state either exists for. Neither can
    # be reached from a well-formed fixture, which is exactly why they are asserted directly.
    blind_cases = [
        # Indent the function body's opening brace: the catch line still matches, so the site is
        # still found, but there is no column-0 brace above it and the name cannot be read.
        ('a body whose opening brace is indented leaves the function name unreadable',
         CLEAN.replace('\n{\n', '\n  {\n', 1), 'unresolved-function'),
        # Re-indent the whole file four spaces: `catch (...)` is still in the text and not one
        # function-level site is left, which is the state that would otherwise print "0 of 0".
        ('a tree that has stopped being indented two spaces trips the whole-tree canary',
         '\n'.join('  ' + line if line else line for line in CLEAN.split('\n')),
         'parser-blind'),
    ]
    for name, text, expected_kind in blind_cases:
        problems, _ = findings({'OCCTBridge_Fixture.mm': text})
        fired = any(kind == expected_kind for kind, _, _, _ in problems)
        failed += not fired
        print('  %s %s' % ('ok  ' if fired else 'MISS', name))
        if not fired:
            print('       expected a %s, got %s' % (expected_kind,
                                                    [k for k, _, _, _ in problems]))

    total = len(cases) + len(canary_cases) + len(blind_cases)
    print('%d/%d cases correct' % (total - failed, total))
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--self-test', action='store_true',
                        help='run the fixture battery instead of the repo')
    parser.add_argument('--list', action='store_true',
                        help='print every function-level catch site and its verdict')
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if args.list:
        return list_sites()
    return run()


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
