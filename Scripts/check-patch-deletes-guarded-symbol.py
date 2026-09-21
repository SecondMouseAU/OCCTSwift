#!/usr/bin/env python3
"""Gate: no carried OCCT patch deletes a line whose symbol a test comment says it depends on (#2058).

#2056 is the incident. Carried patch `0035` removed one line from `STEPControl_Writer::Transfer`,
the `InitializeMissingParameters()` call that re-sets `DirectFaces` when the shared actor's
`OperationsFlags` are empty, and that call is the whole of what protects consumers from #280 now
that the bridge-side workaround is gone. The regression test for #280 caught it, 1h5m later, in
`kernel-integration.yml`. Nothing caught it at patch-authoring time, and the test's own doc comment
still described the retired bridge workaround, so reading the test while assessing the patch argued
for the patch.

`census-comment-staleness.py` could not have caught it: it scans comments in `Sources/` only, and
the stale sentence named no symbol that had stopped resolving. So this is a different check with a
different subject. It reads the patches, not the kernel tree, and asks one question of each removed
line: does some test comment name the symbol on it?

That makes it a pure-text check over `Tests/**/*.swift` and `Scripts/patches/*.patch`, with no
OCCT, no `Libraries/occt-src` and no network, so it runs in `ci.yml`'s `gate-scripts` job next to
its siblings rather than an hour into `kernel-integration.yml`.

WHAT COUNTS AS A GUARDED SYMBOL. Only whole-line `//` and `///` comments in `Tests/**/*.swift`, the
form the convention in #2058 asks for. Two spellings are indexed:

  * a qualified `Class_Something::Method`, e.g. `STEPControl_Writer::Transfer`. The class name must
    contain an underscore, which is OCCT's own convention and keeps Swift's own `::`-free prose out.
  * a backticked symbol, e.g. ``InitializeMissingParameters()`` or ``SetShapeProcessFlags``. This is
    the channel that catches `0035`: the deleted line spells the call unqualified, and so does the
    comment.

WHAT COUNTS AS A DEFECT. A line removed by a hunk, where either

  1. the line contains a qualified `Class::Method` spelling some test comment names, anywhere; or
  2. the removed line's file is that class's own source (`STEPControl_Writer.cxx` for
     `STEPControl_Writer`), and the line names a symbol the SAME test file's comments name.

Rule 2's file scoping is what makes the check usable. Measured over the 27 patches on disk, the
unscoped version of rule 2 (any test-named symbol on any removed line) reports 12 sites across 3
patches and every one is a false positive: OCCT method names are `Add`, `Initialize`, `Set`,
`IsDone`, so a patch rewriting any file that mentions one of those would fail the gate. Requiring
the removed line to sit in the source of a class that same test file names takes that to zero, while
`0035` still fails: `STEPWriterCAFCorruptionTests.swift` names both `STEPControl_Writer::Transfer` and
``InitializeMissingParameters()``, and the deleted line sits in `STEPControl_Writer.cxx`.

A symbol that a patch removes on one line and re-adds on another, in the same file, is a rewrite
rather than a removal and is not reported. Without that, 14 sites across four of the patches on disk
fail, all of them for moving a call rather than dropping it (`0030` alone contributes eight, one per
`TopoDS_TShape` flag accessor it rewrites).

WHAT TO DO WITH A FINDING. The gate is not a veto on deleting kernel lines. It says a test asserts
something about this line, so the patch has to answer that test: either the removal is wrong (that
was `0035`), or the test's comment is describing a mechanism that has moved and must be rewritten in
the same change. Both were true of #2056 at different times.

Usage:
  Scripts/check-patch-deletes-guarded-symbol.py
  Scripts/check-patch-deletes-guarded-symbol.py --list-symbols   # the index, and its size
  Scripts/check-patch-deletes-guarded-symbol.py --self-test
"""
import argparse
import glob
import os
import re
import sys

TEST_GLOB = 'Tests/**/*.swift'
PATCH_GLOB = 'Scripts/patches/*.patch'

# A whole-line comment, `//` or `///`. Trailing comments are deliberately not read: the convention
# #2058 proposes is a doc comment on the test, and taking everything after the first `//` on any
# line would index the contents of string literals too.
COMMENT_LINE_RE = re.compile(r'^\s*(?:///|//)(?!/)(.*)$')

# `Class_Something::Method`. The underscore in the class name is OCCT's convention (`BRep_Tool`,
# `STEPControl_Writer`, `gp_Trsf`) and is what keeps ordinary prose out of the index.
QUALIFIED_RE = re.compile(r'\b([A-Za-z][A-Za-z0-9]*_[A-Za-z0-9_]+)::([A-Za-z_][A-Za-z0-9_]*)')

# A backticked symbol, with or without an argument list: `InitializeMissingParameters()`,
# `SetShapeProcessFlags`, `Transfer(shape)`. Three characters minimum, and it must start with a
# CAPITAL, which is OCCT's convention for a class or method name and is what keeps the Swift side of
# a test comment out of the index: measured over Tests/, accepting a lower-case initial takes the
# index from 1,248 symbols to 2,298 and the additions are `tolerance`, `spacing`, `continue`,
# `false` and the local variables of the test itself.
BACKTICKED_RE = re.compile(r'`([A-Z][A-Za-z0-9_]{2,})(?:\([^`]*\))?`')

HUNK_RE = re.compile(r'^@@ -\d+(?:,(\d+))? \+\d+(?:,(\d+))? @@')

# Source extensions whose stem names the OCCT class that owns the file. OCCT puts `BRep_Tool` in
# BRep_Tool.hxx/.cxx/.lxx and nowhere else, which is what rule 2's scoping relies on.
CLASS_FILE_EXTS = ('.cxx', '.hxx', '.lxx', '.pxx', '.gxx', '.h', '.cpp')


class TestIndex:
    """What each test file's comments name, and the reverse map used for reporting.

    ``classes[test]``    OCCT class names that test file's comments name.
    ``symbols[test]``    symbol names (method halves and backticked names) it names.
    ``qualified[spell]`` test files naming the full `Class::Method` spelling.
    """

    def __init__(self):
        self.classes = {}
        self.symbols = {}
        self.qualified = {}

    def files(self):
        return sorted(set(self.classes) | set(self.symbols))

    def symbol_count(self):
        every = set(self.qualified)
        for names in self.symbols.values():
            every |= names
        return len(every)


def scan_test_comments(sources):
    """Build the index from a {path: text} mapping. Only paths under Tests/ are read.

    The Tests/ filter is the check's subject, not an optimisation: a mechanism described in a
    `Sources/` comment is a claim about the bridge, and nothing runs it. A test is what fails.
    """
    index = TestIndex()
    for path in sorted(sources):
        if not path.replace(os.sep, '/').startswith('Tests/'):
            continue
        classes, symbols = set(), set()
        for line in sources[path].splitlines():
            match = COMMENT_LINE_RE.match(line)
            if not match:
                continue
            comment = match.group(1)
            for qualified in QUALIFIED_RE.finditer(comment):
                classes.add(qualified.group(1))
                symbols.add(qualified.group(2))
                index.qualified.setdefault(qualified.group(0), set()).add(path)
            for backticked in BACKTICKED_RE.finditer(comment):
                symbols.add(backticked.group(1))
        if classes:
            index.classes[path] = classes
        if symbols:
            index.symbols[path] = symbols
    return index


def parse_patch(text):
    """Removed and added lines per target file, read from hunks only.

    Returns ``(removals, additions)``: a list of ``(target_path, line)`` and a dict of
    ``target_path -> [line]``. Everything outside a hunk body is skipped, which is what keeps the
    `---`/`+++` file headers and the patch's own prose preamble out. The preamble matters: patch
    `0028`'s begins with a `- Perform() clears them alongside ...` bullet, and a scanner that
    excluded only lines starting with `---` would read that bullet as a deleted line of source.
    """
    removals = []
    additions = {}
    target = None
    remaining_old = remaining_new = 0
    for line in text.splitlines():
        if remaining_old <= 0 and remaining_new <= 0:
            if line.startswith('+++ '):
                target = line[4:].split('\t')[0].strip()
                if target.startswith('b/'):
                    target = target[2:]
            elif line.startswith('@@ '):
                match = HUNK_RE.match(line)
                if match:
                    remaining_old = int(match.group(1) or 1)
                    remaining_new = int(match.group(2) or 1)
            continue
        # Inside a hunk body. A context line spends one of each count, a removal spends an old
        # line, an addition spends a new one. "\ No newline at end of file" spends neither.
        if line.startswith('-'):
            removals.append((target, line[1:]))
            remaining_old -= 1
        elif line.startswith('+'):
            additions.setdefault(target, []).append(line[1:])
            remaining_new -= 1
        elif line.startswith('\\'):
            continue
        else:
            remaining_old -= 1
            remaining_new -= 1
    return removals, additions


def class_of_file(path):
    """The OCCT class a source path belongs to, by stem, or None."""
    if not path:
        return None
    base = os.path.basename(path.replace('\\', '/'))
    stem, ext = os.path.splitext(base)
    if ext not in CLASS_FILE_EXTS or '_' not in stem:
        return None
    return stem


def mentions(line, name):
    return re.search(r'\b%s\b' % re.escape(name), line) is not None


def findings_for_patch(patch_name, text, index):
    """Every (patch, file, symbol, test file, line) a removed line in this patch trips."""
    removals, additions = parse_patch(text)
    found = []
    seen = set()

    def record(target, symbol, test_files, line):
        # Re-added in the same file: a rewrite, not a removal. Four of the patches on disk move a
        # guarded call between lines, 14 sites, and reporting those would make the gate unusable.
        if any(mentions(added, symbol) for added in additions.get(target, [])):
            return
        for test_file in sorted(test_files):
            key = (target, symbol, test_file)
            if key in seen:
                continue
            seen.add(key)
            found.append((patch_name, target, symbol, test_file, line.strip()))

    for target, line in removals:
        for spelling, test_files in index.qualified.items():
            if spelling in line:
                record(target, spelling, test_files, line)
        owner = class_of_file(target)
        if owner is None:
            continue
        for test_file, classes in index.classes.items():
            if owner not in classes:
                continue
            for symbol in sorted(index.symbols.get(test_file, ())):
                if mentions(line, symbol):
                    record(target, symbol, {test_file}, line)
    return found


def collect(pattern):
    out = {}
    for path in sorted(glob.glob(pattern, recursive=True)):
        with open(path, encoding='utf-8', errors='replace') as handle:
            out[path] = handle.read()
    return out


def run():
    index = scan_test_comments(collect(TEST_GLOB))
    patches = collect(PATCH_GLOB)
    found = []
    for name in sorted(patches):
        found += findings_for_patch(name, patches[name], index)

    if not found:
        print('check-patch-deletes-guarded-symbol: clean, no carried patch removes a line naming '
              'a guarded symbol (%d patches, %d OCCT symbols named by %d test files)'
              % (len(patches), index.symbol_count(), len(index.files())))
        return 0

    print('check-patch-deletes-guarded-symbol: %d removal(s) of a symbol a test comment guards\n'
          % len(found))
    for patch_name, target, symbol, test_file, line in found:
        print('  %s' % patch_name)
        print('    deletes from %s' % (target or '(unknown file)'))
        print('      %s' % line)
        print('    the symbol `%s` is named by %s' % (symbol, test_file))
        print('')
    print('A test comment says its invariant depends on this symbol, so the patch has to answer '
          'that test:\nrun it against the patched kernel, or rewrite the comment in the same '
          'change if the mechanism moved.\nPatch 0035 was the first case and #2056 is its record.')
    return 1


def list_symbols():
    index = scan_test_comments(collect(TEST_GLOB))
    print('%d test files name %d distinct OCCT symbols in whole-line comments '
          '(%d qualified Class::Method spellings)'
          % (len(index.files()), index.symbol_count(), len(index.qualified)))
    for path in index.files():
        names = sorted(index.symbols.get(path, ()))
        print('  %s' % path)
        print('    classes: %s' % ', '.join(sorted(index.classes.get(path, ()))) or '(none)')
        print('    symbols: %s' % ', '.join(names))
    return 0


# --- self-test ---------------------------------------------------------------------------------
#
# Case 1 is #2056 itself: patch 0035 verbatim (it is retired, so it lives here as a fixture rather
# than in Scripts/patches/), against the doc comment STEPWriterCAFCorruptionTests.swift carries
# today. Every other case exists to hold one guard down, and each was checked by removing that
# guard and watching the count drop.

PATCH_0035 = '''\
diff --git a/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx b/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
index c911126d..9f60d9e6 100644
--- a/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
+++ b/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
@@ -155,7 +155,6 @@ IFSelect_ReturnStatus STEPControl_Writer::Transfer(const TopoDS_Shape&
     occ::down_cast<STEPControl_ActorWrite>(WS()->NormAdaptor()->ActorWrite());
   ActWrite->SetGroupMode(
     occ::down_cast<StepData_StepModel>(thesession->Model())->InternalParameters.WriteAssembly);
-  InitializeMissingParameters();
   return thesession->TransferWriteShape(sh, compgraph, theProgress);
 }
'''

GUARDING_TEST = '''\
/// Regression guard for #280.
///
/// What protects consumers today is `STEPControl_Writer::Transfer`'s call to
/// `InitializeMissingParameters()`, which re-sets `DirectFaces` when the shared actor's
/// `OperationsFlags` are empty. Anything proposing to remove that call again must make this pass.
@Test("A CAF STEP read must not corrupt later shape-level STEP writes")
func cafReadDoesNotPoisonShapeWriter() throws {
    let s = "InitializeMissingParameters"  // not a comment, and must not be indexed
}
'''


def self_test():
    test_path = 'Tests/OCCTIOTests/STEPWriterCAFCorruptionTests.swift'

    unrelated_removal = '''\
--- a/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
+++ b/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
@@ -155,7 +155,6 @@ IFSelect_ReturnStatus STEPControl_Writer::Transfer(const TopoDS_Shape&
   ActWrite->SetGroupMode(theMode);
-  myUnrelatedCounter = 0;
   return thesession->TransferWriteShape(sh, compgraph, theProgress);
'''

    additions_only = '''\
--- a/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
+++ b/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
@@ -155,6 +155,7 @@ IFSelect_ReturnStatus STEPControl_Writer::Transfer(const TopoDS_Shape&
   ActWrite->SetGroupMode(theMode);
+  InitializeMissingParameters();
   return thesession->TransferWriteShape(sh, compgraph, theProgress);
'''

    rewrite = '''\
--- a/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
+++ b/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
@@ -155,7 +155,7 @@ IFSelect_ReturnStatus STEPControl_Writer::Transfer(const TopoDS_Shape&
   ActWrite->SetGroupMode(theMode);
-  InitializeMissingParameters();
+  InitializeMissingParameters(theProgress);
   return thesession->TransferWriteShape(sh, compgraph, theProgress);
'''

    prose_preamble = '''\
Drop the per-Transfer initialisation, per upstream OCCT#1259. Notes:

- InitializeMissingParameters() is nearly inert, because both of its guards read
  through the shared actor the constructor has already populated.

diff --git a/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx b/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
--- a/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
+++ b/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
@@ -155,6 +155,7 @@ IFSelect_ReturnStatus STEPControl_Writer::Transfer(const TopoDS_Shape&
   ActWrite->SetGroupMode(theMode);
+  SetShapeFixParameters(theParams);
   return thesession->TransferWriteShape(sh, compgraph, theProgress);
'''

    caller_removal = '''\
--- a/src/DataExchange/TKDESTEP/STEPCAFControl/STEPCAFControl_Writer.cxx
+++ b/src/DataExchange/TKDESTEP/STEPCAFControl/STEPCAFControl_Writer.cxx
@@ -300,7 +300,6 @@ Standard_Boolean STEPCAFControl_Writer::Perform()
   if (!myWriter.IsNull())
-    aStatus = STEPControl_Writer::Transfer(aShape, aMode, Standard_True);
   return Standard_True;
'''

    other_class_removal = '''\
--- a/src/ModelingData/TKGeomBase/GeomTools/GeomTools_SurfaceSet.cxx
+++ b/src/ModelingData/TKGeomBase/GeomTools/GeomTools_SurfaceSet.cxx
@@ -40,7 +40,6 @@ Standard_Integer GeomTools_SurfaceSet::Add(const Handle(Geom_Surface)& S)
   if (S.IsNull())
-    return Transfer(S);
   return myMap.Add(S);
'''

    header_only = '''\
--- a/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
+++ b/src/DataExchange/TKDESTEP/STEPControl/STEPControl_Writer.cxx
@@ -155,6 +155,7 @@ IFSelect_ReturnStatus STEPControl_Writer::Transfer(const TopoDS_Shape&
   ActWrite->SetGroupMode(theMode);
+  InitializeMissingParameters();
   return thesession->TransferWriteShape(sh, compgraph, theProgress);
'''

    # (name, what it isolates, {path: text} for the index, patch text, expected (symbol, test file)
    #  pairs)
    cases = [
        ('#2056: patch 0035 against the #280 regression test',
         'the whole pipeline, and the backticked-call channel, which is the only one that sees a '
         'line spelling the call unqualified',
         {test_path: GUARDING_TEST}, PATCH_0035,
         [('InitializeMissingParameters', test_path)]),

        ('a removal in the same file that names nothing the test guards',
         'the symbol match itself: same file, same hunk, same class, different line',
         {test_path: GUARDING_TEST}, unrelated_removal, []),

        # Labelled as adding nothing on its own, per okf/policies/prove-the-test-fails.md: the
        # rewrite suppression below backstops it, because a symbol on an added line is by
        # definition in that file's additions. Removing either guard alone leaves this case green;
        # it fails only when both go. It is kept because "a patch that only adds lines is not a
        # deletion" is the property, and a future change to either guard needs it stated.
        ('a patch that only ADDS lines',
         'nothing on its own: removal-only scanning and the rewrite suppression each hide the '
         'other here, and only removing both makes this case fail',
         {test_path: GUARDING_TEST}, additions_only, []),

        ('a guarded symbol named only in a Sources/ comment',
         'the Tests/ scoping in scan_test_comments: the same comment text, moved out of Tests/, '
         'must build no index',
         {'Sources/OCCTBridge/src/OCCTBridge_IO.mm': GUARDING_TEST}, PATCH_0035, []),

        ('a `---` file header naming the guarded file, and a prose bullet naming the symbol',
         'hunk-body-only parsing: both `- InitializeMissingParameters() is nearly inert` in the '
         'preamble and the `--- a/...STEPControl_Writer.cxx` header start with a single `-`',
         {test_path: GUARDING_TEST}, prose_preamble, []),

        ('a removal that re-adds the same symbol on the next line',
         'the rewrite suppression: four of the patches on disk move a guarded call rather than '
         'dropping it, 14 sites',
         {test_path: GUARDING_TEST}, rewrite, []),

        ('a caller in another class dropping the qualified spelling',
         'the unscoped qualified channel, rule 1, which does not need the file to be the class\'s '
         'own source',
         {test_path: GUARDING_TEST}, caller_removal,
         [('STEPControl_Writer::Transfer', test_path)]),

        ('another class\'s file dropping a line that names a guarded method',
         'rule 2\'s file scoping: `Transfer` on a removed line in GeomTools_SurfaceSet.cxx is not '
         'STEPControl_Writer::Transfer, and unscoped matching is what measured 12 false '
         'positives',
         {test_path: GUARDING_TEST}, other_class_removal, []),
    ]

    failed = 0
    print('findings cases')
    for name, isolates, sources, patch_text, expected in cases:
        index = scan_test_comments(sources)
        got = [(f[2], f[3]) for f in findings_for_patch('fixture.patch', patch_text, index)]
        ok = sorted(got) == sorted(expected)
        failed += not ok
        print('  %s %s' % ('ok  ' if ok else 'MISS', name))
        print('       isolates: %s' % isolates)
        if not ok:
            print('       expected %s, got %s' % (expected, got))

    # The `---` header cannot be proved at findings level: no OCCT method name appears inside a
    # source path, so a header line can only ever trip the parser, never the symbol match. Assert
    # on the parser instead, so the case isolates something rather than passing for free.
    print('parser cases')
    parser_cases = [
        ('the `---`/`+++` file headers are not removals',
         header_only,
         [],
         ['  InitializeMissingParameters();\n']),
        ('a `-` bullet in the patch preamble is not a removal',
         prose_preamble,
         [],
         ['  SetShapeFixParameters(theParams);\n']),
        ('a hunk body removal IS a removal',
         PATCH_0035,
         ['  InitializeMissingParameters();'],
         []),
    ]
    for name, patch_text, expected_removed, expected_added in parser_cases:
        removals, additions = parse_patch(patch_text)
        got_removed = [line for _, line in removals]
        got_added = [line for lines in additions.values() for line in lines]
        ok = (got_removed == expected_removed
              and [a.rstrip('\n') for a in got_added]
              == [a.rstrip('\n') for a in expected_added])
        failed += not ok
        print('  %s %s' % ('ok  ' if ok else 'MISS', name))
        if not ok:
            print('       expected removed %s / added %s, got removed %s / added %s'
                  % (expected_removed, expected_added, got_removed, got_added))

    total = len(cases) + len(parser_cases)
    print('%d/%d cases correct' % (total - failed, total))
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--self-test', action='store_true',
                        help='run the fixture battery instead of the repo')
    parser.add_argument('--list-symbols', action='store_true',
                        help='print the guarded-symbol index and its size')
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if args.list_symbols:
        return list_symbols()
    return run()


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
