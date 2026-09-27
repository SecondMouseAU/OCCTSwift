#!/usr/bin/env python3
"""Gate: no patch leaves an OCCT source file no compiler can preprocess (#2167).

PR #2076 carried fifteen WASI patches. Three of them left a source file broken on EVERY platform,
not only WASI, and the PR's own green check said "all 14 patches apply cleanly", which was true and
measured nothing: applying cleanly and preprocessing are different properties.

  * `wasi-osd-signal.patch` inserted two `#ifndef __wasi__` immediately before `#else /* ! _WIN32 */`,
    which hijacked that `#else` from the file's `#ifdef _WIN32`, and rewrote nineteen unrelated
    `#endif`s into `#else // __wasi__`. Net: two conditional opens added, nineteen `#endif` removed,
    nineteen `#else` added, and the whole non-Windows implementation compiled nowhere.
  * `wasi-osd-file.patch` added two `#ifdef`s and three `#endif`s, dangling the `#else` that followed.
  * `wasi-incallocator.hxx.patch` and `wasi-osd-path.patch` each opened `#ifndef __wasi__` twice in a
    row, so the inner `#else` branch is unreachable dead code.

WHY IT READS THE PATCH TEXT AND NOT A SOURCE TREE. `ci.yml`'s `gate-scripts` job is pure Python over
the repo's own text: no OCCT, no `Libraries/occt-src`, no build, no network, and it must not grow
one, which is the same argument `check-patch-deletes-guarded-symbol.py` (#2058) makes for living
here rather than an hour into `kernel-integration.yml`. A unified diff carries only its hunks'
context, so whole-file balance cannot be reconstructed from it. But every defect #2076 shipped is
visible in the patch text as a DIRECTIVE DELTA: what the hunks add against what they remove.

THE THREE RULES, each with what it caught and what it deliberately does not.

  1. UNBALANCED. Per target file, `(#if|#ifdef|#ifndef)` added minus removed must equal `#endif`
     added minus removed. A patch that wraps code in a new guard adds one of each; a patch that
     widens an existing condition (`#if !defined(__EMSCRIPTEN__)` becoming
     `#if !defined(__EMSCRIPTEN__) && !defined(__wasi__)`, which is what `wasi-osd-process.patch`
     does) removes one open and adds one, so both net to zero. `wasi-osd-file.patch` is +2 opens
     against +3 `#endif`; `wasi-osd-signal.patch` is +2 opens against a net 0 `#endif`.

  2. DANGLING `#else`. A change block that removes an `#endif`, adds an `#else`, and adds NEITHER a
     conditional open NOR an `#endif` of its own: the `#else` is attaching to somebody else's
     conditional and nothing closes the one whose `#endif` went away.

     The "nor an `#endif` of its own" half is a measured tightening of the rule as #2167 states it,
     and it is what keeps the gate usable. Each of `wasi-osd-signal.patch`'s nineteen sites reads

         #ifdef __linux__
           #include <cfenv>
       -  #endif
       +  #else
       +    ...
       +  #endif

     which is, IN ISOLATION, the ordinary way to add an `#else` branch to an existing conditional:
     balanced, correct, and the shape any future WASI patch will use. What is wrong with that file
     is one level up and is rule 1's finding, not nineteen separate ones. Reporting all nineteen
     would be nineteen false positives dressed as a diagnosis, and the next author to add an
     `#else` branch correctly would meet a red required check.

  3. DOUBLED GUARD. Within one contiguous run of added lines, a conditional open whose text is
     identical to one still open around it: `#ifndef __wasi__` inside `#ifndef __wasi__` makes the
     inner `#else` branch unreachable, which is the dead spinlock member
     `wasi-incallocator.hxx.patch` shipped and the dead `return OSD_Default` in
     `wasi-osd-path.patch`. Two identical guards SIDE BY SIDE in one run, each closed before the
     next opens, are not reported: that is two independent blocks, and the self-test holds that
     down.

WHAT IT CANNOT SEE, and the answer to it. A patch can be delta-balanced and still leave a file
broken, because balance is a whole-file property and the hunks show slivers. `--tree` is the deeper
mode: given a real checkout (`Libraries/occt-src` by default) it parses each file the patches target
end to end and reports `#else` after `#else`, `#endif` with no open conditional, and a conditional
left open at end of file. That mode is for a developer and for the wasm build job. It is NOT part of
`gate-scripts`, which has no checkout, and per #2098 a mode that examined nothing must fail rather
than pass: `--require-tree` turns a missing tree from a printed note into an error, and CI's wasm
job passes it.

Usage:
  Scripts/check-preprocessor-balance.py                    # the gate: patch text only
  Scripts/check-preprocessor-balance.py --list             # per-patch directive deltas, no verdict
  Scripts/check-preprocessor-balance.py --tree             # + full-file parse of Libraries/occt-src
  Scripts/check-preprocessor-balance.py --tree DIR --require-tree
  Scripts/check-preprocessor-balance.py --self-test
"""
import argparse
import glob
import os
import re
import sys

PATCH_GLOBS = ('Scripts/patches/*.patch', 'Scripts/patches-wasi/*.patch')
DEFAULT_TREE = 'Libraries/occt-src'

HUNK_RE = re.compile(r'^@@ -\d+(?:,(\d+))? \+\d+(?:,(\d+))? @@')

# A conditional directive, and only when `#` is the first non-blank character on the line. OCCT
# indents nested directives (`  #endif`), and writes `# if` with a space often enough that the
# form has to be accepted; what the leading-blank anchor keeps out is a directive quoted inside a
# comment block, where the line starts with `*` or `//`.
DIRECTIVE_RE = re.compile(r'^[ \t]*#[ \t]*(if|ifdef|ifndef|elif|elifdef|elifndef|else|endif)\b')

OPENERS = ('if', 'ifdef', 'ifndef')
MIDDLES = ('elif', 'elifdef', 'elifndef', 'else')

SOURCE_EXTS = ('.cxx', '.hxx', '.lxx', '.pxx', '.gxx', '.h', '.hpp', '.cpp', '.c', '.cc')


def directive(line):
    """The conditional directive a line OPENS, or None.

    Anchored, deliberately: a line may only carry a directive at its start. Searching instead
    would read the `#endif` out of `// there is no #endif to add here` and report a correct patch
    as unbalanced, which the self-test holds down.
    """
    match = DIRECTIVE_RE.match(line)
    return match.group(1) if match else None


def normalise(line):
    """A directive line reduced to what identifies it, for the doubled-guard comparison.

    Whitespace is collapsed and a trailing comment dropped, so `#ifndef __wasi__` and
    `  # ifndef  __wasi__  // wasm` compare equal. The condition text itself is NOT parsed: two
    spellings of the same condition (`#ifdef X` and `#if defined(X)`) are deliberately treated as
    different, because reporting them as a doubled guard would need a macro evaluator and this
    check is meant to be certain about what it reports.
    """
    body = line.strip()
    for marker in ('//', '/*'):
        cut = body.find(marker)
        if cut >= 0:
            body = body[:cut]
    return re.sub(r'\s+', ' ', body).strip()


# --- reading the patches -------------------------------------------------------------------------


class Hunk:
    """One hunk's body: the target file, and the (sign, text, patch line number) it carries."""

    def __init__(self, target, header_line):
        self.target = target
        self.header_line = header_line
        self.entries = []

    def blocks(self):
        """Maximal runs of consecutive changed lines, context excluded.

        A unified diff writes a replacement as its removals followed by its additions with no
        context between, so one block is one edit site. Rules 2 and 3 are block-scoped for that
        reason: it is the smallest unit that still holds "this `#else` replaced that `#endif`".
        """
        out, current = [], []
        for entry in self.entries:
            if entry[0] in '-+':
                current.append(entry)
            elif current:
                out.append(current)
                current = []
        if current:
            out.append(current)
        return out


def parse_patch(text):
    """Every hunk in a patch, in order.

    Hunk bodies are consumed by the counts in the `@@` header rather than by "a line starting with
    `-` is a removal", which is what keeps the `---`/`+++` file headers and the patch's own prose
    preamble out. The preamble matters: several carried patches open with a `- ...` bullet list,
    and `Scripts/patches/0028-...` is the one that made `check-patch-deletes-guarded-symbol.py`
    read prose as deleted source.
    """
    hunks = []
    target = None
    hunk = None
    remaining_old = remaining_new = 0
    for number, line in enumerate(text.splitlines(), start=1):
        if remaining_old <= 0 and remaining_new <= 0:
            hunk = None
            if line.startswith('+++ '):
                target = line[4:].split('\t')[0].strip()
                if target.startswith('b/'):
                    target = target[2:]
            elif line.startswith('@@ '):
                match = HUNK_RE.match(line)
                if match:
                    remaining_old = int(match.group(1) or 1)
                    remaining_new = int(match.group(2) or 1)
                    hunk = Hunk(target, number)
                    hunks.append(hunk)
            continue
        if line.startswith('\\'):          # "\ No newline at end of file" spends neither count
            continue
        if line.startswith('-'):
            hunk.entries.append(('-', line[1:], number))
            remaining_old -= 1
        elif line.startswith('+'):
            hunk.entries.append(('+', line[1:], number))
            remaining_new -= 1
        else:
            hunk.entries.append((' ', line[1:] if line[:1] == ' ' else line, number))
            remaining_old -= 1
            remaining_new -= 1
    return hunks


def deltas(hunks):
    """Per target file, {'open': net, 'endif': net, 'else': net} across every hunk."""
    counts = {}
    for hunk in hunks:
        per_file = counts.setdefault(hunk.target, {'open': 0, 'endif': 0, 'else': 0})
        for sign, line, _ in hunk.entries:
            if sign == ' ':
                continue
            kind = directive(line)
            if kind is None:
                continue
            step = 1 if sign == '+' else -1
            if kind in OPENERS:
                per_file['open'] += step
            elif kind == 'endif':
                per_file['endif'] += step
            elif kind in MIDDLES:
                per_file['else'] += step
    return counts


# --- the three rules -----------------------------------------------------------------------------


def unbalanced_opens(patch_name, hunks):
    """Rule 1: per target file, the net conditional opens must equal the net `#endif`."""
    found = []
    for target, count in sorted(deltas(hunks).items(), key=lambda kv: kv[0] or ''):
        if count['open'] != count['endif']:
            found.append((
                'UNBALANCED', patch_name, target, None,
                'net conditional opens %+d, net #endif %+d (net #else/#elif %+d)'
                % (count['open'], count['endif'], count['else'])))
    return found


def dangling_else(patch_name, hunks):
    """Rule 2: a block that turns somebody else's `#endif` into an `#else` and closes nothing."""
    found = []
    for hunk in hunks:
        for block in hunk.blocks():
            removed_endif = [e for e in block if e[0] == '-' and directive(e[1]) == 'endif']
            added_else = [e for e in block if e[0] == '+' and directive(e[1]) in MIDDLES]
            added_open = [e for e in block if e[0] == '+' and directive(e[1]) in OPENERS]
            added_endif = [e for e in block if e[0] == '+' and directive(e[1]) == 'endif']
            if removed_endif and added_else and not added_open and not added_endif:
                found.append((
                    'DANGLING_ELSE', patch_name, hunk.target, added_else[0][2],
                    'adds `%s` where `%s` was removed, with no conditional opened and no #endif to '
                    'replace the one it dropped' % (added_else[0][1].strip(),
                                                    removed_endif[0][1].strip())))
    return found


def doubled_guard(patch_name, hunks):
    """Rule 3: an added conditional nested directly inside an identical added conditional."""
    found = []
    for hunk in hunks:
        for block in hunk.blocks():
            stack = []
            for sign, line, number in block:
                if sign != '+':
                    continue
                kind = directive(line)
                if kind is None:
                    continue
                if kind in OPENERS:
                    text = normalise(line)
                    for open_line, open_number in stack:
                        if open_line == text:
                            found.append((
                                'DOUBLED_GUARD', patch_name, hunk.target, number,
                                '`%s` opened again inside itself (the outer one is at patch line '
                                '%d), so the inner #else branch is unreachable'
                                % (text, open_number)))
                            break
                    stack.append((text, number))
                elif kind == 'endif' and stack:
                    stack.pop()
    return found


def findings_for_patch(patch_name, text):
    hunks = parse_patch(text)
    return (unbalanced_opens(patch_name, hunks)
            + dangling_else(patch_name, hunks)
            + doubled_guard(patch_name, hunks)), hunks


# --- the deeper mode: a real full-file parse ------------------------------------------------------


def strip_block_comments(text):
    """Blank out `/* ... */` spans, keeping line structure.

    A full-file parse must not read a directive that is commented out, and OCCT does quote them:
    a `/* #endif */` inside an explanatory comment would otherwise pop a live conditional. Newlines
    are preserved so reported line numbers stay true. String literals are not modelled, which is
    safe here because the anchor in DIRECTIVE_RE already requires `#` to open the line.
    """
    out = []
    index = 0
    while True:
        start = text.find('/*', index)
        if start < 0:
            out.append(text[index:])
            break
        out.append(text[index:start])
        end = text.find('*/', start + 2)
        if end < 0:
            out.append('\n' * text.count('\n', start))
            break
        out.append('\n' * text.count('\n', start, end + 2))
        index = end + 2
    return ''.join(out)


def scan_source(path, text):
    """Full-file conditional parse: `#else` after `#else`, orphan `#endif`, unterminated `#if`."""
    problems = []
    stack = []
    for number, line in enumerate(strip_block_comments(text).splitlines(), start=1):
        kind = directive(line)
        if kind is None:
            continue
        if kind in OPENERS:
            stack.append({'line': number, 'text': normalise(line), 'else': None})
        elif kind in MIDDLES:
            if not stack:
                problems.append(('ORPHAN_ELSE', path, number,
                                 '`%s` with no open conditional' % normalise(line)))
            elif stack[-1]['else'] is not None:
                problems.append(('ELSE_AFTER_ELSE', path, number,
                                 '`%s` after the `#else` at line %d, for the `%s` opened at line %d'
                                 % (normalise(line), stack[-1]['else'], stack[-1]['text'],
                                    stack[-1]['line'])))
            elif kind == 'else':
                stack[-1]['else'] = number
        elif kind == 'endif':
            if not stack:
                problems.append(('ORPHAN_ENDIF', path, number, '`#endif` with no open conditional'))
            else:
                stack.pop()
    for frame in stack:
        problems.append(('UNTERMINATED', path, frame['line'],
                         '`%s` is never closed' % frame['text']))
    return problems


def patch_targets(patches):
    """Every source file the patches name, as repo-relative OCCT paths."""
    targets = set()
    for text in patches.values():
        for hunk in parse_patch(text):
            if hunk.target and os.path.splitext(hunk.target)[1] in SOURCE_EXTS:
                targets.add(hunk.target)
    return sorted(targets)


def scan_tree(root, patches):
    """Parse every patched file in `root` end to end. Returns (problems, examined, missing)."""
    problems, examined, missing = [], [], []
    for target in patch_targets(patches):
        path = os.path.join(root, target)
        if not os.path.isfile(path):
            missing.append(target)
            continue
        with open(path, encoding='utf-8', errors='replace') as handle:
            problems += scan_source(target, handle.read())
        examined.append(target)
    return problems, examined, missing


# --- running -------------------------------------------------------------------------------------


def collect():
    out = {}
    for pattern in PATCH_GLOBS:
        for path in sorted(glob.glob(pattern)):
            with open(path, encoding='utf-8', errors='replace') as handle:
                out[path] = handle.read()
    return out


def report(found):
    for kind, patch_name, target, number, detail in found:
        print('  %s  %s' % (kind, patch_name))
        print('    %s%s' % (target or '(unknown file)',
                            '' if number is None else '  (patch line %d)' % number))
        print('    %s' % detail)
        print('')


def run(tree=None, require_tree=False):
    patches = collect()
    if not patches:
        print('check-preprocessor-balance: no patches found under %s. This gate reads patch text, '
              'so an empty population is a broken run, not a clean tree.'
              % ' or '.join(PATCH_GLOBS))
        return 1

    found = []
    blind = []
    for name in sorted(patches):
        patch_found, hunks = findings_for_patch(name, patches[name])
        found += patch_found
        # static-gates.md: assert the view is plausible, not only the verdict. A patch file that
        # parsed to no hunk at all was not examined, and a detector that reports clean on a
        # population it never read is the failure this family exists to prevent.
        if not hunks:
            blind.append(name)

    tree_problems, examined, missing = [], [], []
    if tree is not None:
        if os.path.isdir(tree):
            tree_problems, examined, missing = scan_tree(tree, patches)
        elif require_tree:
            print('check-preprocessor-balance: --require-tree was given and %s is not a directory, '
                  'so the full-file parse examined nothing. A run that examined nothing fails '
                  'rather than passes (#2098).' % tree)
            return 1
        else:
            print('check-preprocessor-balance: note, %s is absent, so the full-file parse was '
                  'skipped. Only the patch-text rules ran. Pass --require-tree where the checkout '
                  'is meant to be there.\n' % tree)
        if require_tree and not examined:
            print('check-preprocessor-balance: --require-tree was given and no patched file was '
                  'found under %s (%d target(s) missing), so the full-file parse examined nothing.'
                  % (tree, len(missing)))
            return 1

    if blind:
        print('check-preprocessor-balance: %d patch file(s) parsed to no hunk at all, so they were '
              'never examined:' % len(blind))
        for name in blind:
            print('  %s' % name)
        return 1

    if found or tree_problems:
        if found:
            print('check-preprocessor-balance: %d conditional-directive defect(s) in the patch '
                  'text\n' % len(found))
            report(found)
        if tree_problems:
            print('check-preprocessor-balance: %d unbalanced conditional(s) in the patched tree '
                  'at %s\n' % (len(tree_problems), tree))
            for kind, path, number, detail in tree_problems:
                print('  %s  %s:%d' % (kind, path, number))
                print('    %s' % detail)
                print('')
        print('A patch that unbalances a file\'s #if/#else/#endif breaks it on EVERY platform, not '
              'only the one\nthe guard names, and "the patch applies cleanly" does not measure it. '
              'PR #2076 shipped three such\nfiles behind a green check; #2167 is the record.')
        return 1

    summary = ('check-preprocessor-balance: clean, %d patches leave every conditional balanced'
               % len(patches))
    if tree is not None and examined:
        summary += ' (%d patched file(s) also parsed end to end under %s)' % (len(examined), tree)
    print(summary)
    return 0


def list_deltas():
    patches = collect()
    print('%d patch files, directive deltas per target file (added minus removed)' % len(patches))
    for name in sorted(patches):
        hunks = parse_patch(patches[name])
        rows = deltas(hunks)
        print('  %s' % name)
        for target, count in sorted(rows.items(), key=lambda kv: kv[0] or ''):
            print('    %-70s open %+d  endif %+d  else %+d'
                  % (target, count['open'], count['endif'], count['else']))
    return 0


# --- self-test -------------------------------------------------------------------------------
#
# The four #2076 patches are NOT vendored here. They are on the `wasm-bridge-spike` branch, which is
# where a real-world corpus belongs; committing them into Scripts/patches-wasi/ would put four
# files that break the kernel into the directory build-occt-wasm.sh applies. These fixtures are
# minimal synthetic versions of the same three shapes, and every one was checked by removing the
# rule it exercises and watching the case fail.

DOUBLED_ADJACENT = '''\
--- a/src/FoundationClasses/TKernel/NCollection/NCollection_IncAllocator.hxx
+++ b/src/FoundationClasses/TKernel/NCollection/NCollection_IncAllocator.hxx
@@ -144,3 +144,9 @@ public:
   unsigned int myBlockCount = 0;
+#ifndef __wasi__
+#ifndef __wasi__
   std::unique_ptr<std::shared_mutex> myMutex;
+#else
+  std::unique_ptr<std::atomic_flag> mySpinlock;
+#endif
+#endif
   IBlock* myAllocationHeap = nullptr;
'''

DOUBLED_SEPARATED = '''\
--- a/src/FoundationClasses/TKernel/OSD/OSD_Path.cxx
+++ b/src/FoundationClasses/TKernel/OSD/OSD_Path.cxx
@@ -40,3 +40,9 @@ static OSD_SysType whereAmI()
   return OSD_Aix;
+#else
+#ifdef __wasi__
+  return OSD_Default;
+#else
+#ifdef __wasi__
+  return OSD_Default;
 #else
   struct utsname info;
@@ -50,3 +58,5 @@ static OSD_SysType whereAmI()
   return OSD_Default;
 #endif
+#endif
+#endif
 }
'''

UNBALANCED_ENDIF = '''\
--- a/src/FoundationClasses/TKernel/OSD/OSD_File.cxx
+++ b/src/FoundationClasses/TKernel/OSD/OSD_File.cxx
@@ -1383,3 +1383,7 @@ void OSD_File::SetLock(const OSD_LockType theLock)
 #elif defined(SYSV)
+#ifdef __wasi__
+  const int aStatus = 0;
+#else
   struct flock aLockKey;
+#endif
   const int aStatus = fcntl(myFileChannel, F_SETLKW, &aLockKey);
@@ -1420,4 +1429,5 @@ void OSD_File::SetLock(const OSD_LockType theLock)
     ImperativeFlag = true;
   }
+#endif
 #else /* BSD */
   int aLock = 0;
'''

HIJACKED_ELSE = '''\
--- a/src/FoundationClasses/TKernel/OSD/OSD_signal.cxx
+++ b/src/FoundationClasses/TKernel/OSD/OSD_signal.cxx
@@ -746,4 +746,4 @@ LONG _osd_debug(void)
   #ifdef __linux__
     #include <cfenv>
-  #endif
+  #else // __wasi__
   #include <unistd.h>
'''

WIDENED_CONDITION = '''\
--- a/src/FoundationClasses/TKernel/OSD/OSD_Process.cxx
+++ b/src/FoundationClasses/TKernel/OSD/OSD_Process.cxx
@@ -40,4 +40,4 @@ const OSD_WhoAmI Iam = OSD_WProcess;
   #include <sys/time.h>
-  #if !defined(__EMSCRIPTEN__)
+  #if !defined(__EMSCRIPTEN__) && !defined(__wasi__)
     #include <pwd.h>
   #endif
'''

NEW_GUARD = '''\
--- a/src/FoundationClasses/TKernel/OSD/OSD_Chronometer.cxx
+++ b/src/FoundationClasses/TKernel/OSD/OSD_Chronometer.cxx
@@ -60,3 +60,7 @@ void OSD_Chronometer::Show()
   struct tms aTMS;
+#ifdef __wasi__
+  theUserSeconds = 0.0;
+#else
   times(&aTMS);
+#endif
 }
'''

ELSE_BRANCH_ADDED = '''\
--- a/src/FoundationClasses/TKernel/OSD/OSD_Host.cxx
+++ b/src/FoundationClasses/TKernel/OSD/OSD_Host.cxx
@@ -30,4 +30,6 @@ void OSD_Host::Values()
   #ifdef __linux__
     #include <cfenv>
-  #endif
+  #else
+    #include <cstdio>
+  #endif
   #include <unistd.h>
'''

SIBLING_GUARDS = '''\
--- a/src/FoundationClasses/TKernel/OSD/OSD_Environment.cxx
+++ b/src/FoundationClasses/TKernel/OSD/OSD_Environment.cxx
@@ -20,2 +20,8 @@ void OSD_Environment::Build()
   const char* aValue = nullptr;
+#ifndef __wasi__
+  aValue = getenv(myName.ToCString());
+#endif
+#ifndef __wasi__
+  setenv(myName.ToCString(), myValue.ToCString(), 1);
+#endif
   myError.Reset();
'''

PROSE_PREAMBLE = '''\
Notes on this patch:

- #endif was moved rather than removed, see the discussion in #2076.
- the second bullet deliberately quotes no conditional OPEN, so a parser that read these
  bullets as removed lines would see an unbalanced file rather than a symmetric pair.

diff --git a/src/FoundationClasses/TKernel/OSD/OSD_Directory.cxx b/src/FoundationClasses/TKernel/OSD/OSD_Directory.cxx
--- a/src/FoundationClasses/TKernel/OSD/OSD_Directory.cxx
+++ b/src/FoundationClasses/TKernel/OSD/OSD_Directory.cxx
@@ -20,3 +20,7 @@ void OSD_Directory::Build()
   const int aStatus = 0;
+#ifdef __wasi__
+  (void)aStatus;
+#else
   mkdir(aPath.ToCString(), 0777);
+#endif
   myError.Reset();
'''

COMMENTED_DIRECTIVE = '''\
--- a/src/FoundationClasses/TKernel/OSD/OSD_Plugin.cxx
+++ b/src/FoundationClasses/TKernel/OSD/OSD_Plugin.cxx
@@ -20,2 +20,5 @@ void OSD_Plugin::Load()
   void* aHandle = nullptr;
+  // dlopen is a link-time decision on WASI, so there is no #endif to add here
+  /* and none here either: #endif */
+  aHandle = dlopen(aName, RTLD_LAZY);
   myError.Reset();
'''

# The tree fixtures for the deeper mode. Each is a whole file, not a diff.
TREE_ELSE_AFTER_ELSE = '''\
#ifdef _WIN32
void f() {}
#else
void f() {}
#else
void f() {}
#endif
'''

TREE_ORPHAN_ENDIF = '''\
#ifdef _WIN32
void f() {}
#endif
#endif
'''

TREE_UNTERMINATED = '''\
#ifndef __wasi__
#ifdef _WIN32
void f() {}
#endif
'''

TREE_COMMENTED_OUT = '''\
#ifdef _WIN32
/* an explanatory comment that quotes
#else
#endif
   for the reader */
void f() {}
#endif
'''


def self_test():
    # (name, what the case isolates, patch text, expected finding kinds)
    cases = [
        ('#2076: `#ifndef __wasi__` opened twice on adjacent added lines '
         '(wasi-incallocator.hxx.patch)',
         'rule 3\'s identical-nested-open test, the only rule that fires on a patch whose opens '
         'and #endifs balance perfectly',
         DOUBLED_ADJACENT, ['DOUBLED_GUARD']),

        ('#2076: the same guard opened twice with an `#else` between them (wasi-osd-path.patch)',
         'rule 3\'s STACK, as against comparing adjacent lines: the two opens are four lines '
         'apart and an `#else` sits between them, so a line-adjacency test sees nothing',
         DOUBLED_SEPARATED, ['DOUBLED_GUARD']),

        ('#2076: one conditional opened, two `#endif`s added (wasi-osd-file.patch)',
         'rule 1\'s per-file net delta; the block-scoped rules see nothing here, because each '
         'block on its own is unremarkable',
         UNBALANCED_ENDIF, ['UNBALANCED']),

        ('#2076: an `#endif` rewritten into an `#else` that closes nothing (wasi-osd-signal.patch)',
         'rule 2, and rule 1 with it: the removed #endif is not replaced, so the file delta is '
         'unbalanced AND the #else has no owner. Both fire, which is what the fixture asserts',
         HIJACKED_ELSE, ['UNBALANCED', 'DANGLING_ELSE']),

        ('a widened condition: one open removed, one added (wasi-osd-process.patch, correct)',
         'rule 1\'s use of a NET delta rather than "did the patch add an open": a patch that '
         'rewrites `#if A` as `#if A && B` adds an open and removes one',
         WIDENED_CONDITION, []),

        ('a new guard wrapping existing code, one open and one `#endif` (correct)',
         'nothing on its own beyond the base case: it is the shape every correct WASI patch has, '
         'and it must produce no finding under any of the three rules',
         NEW_GUARD, []),

        ('an `#else` branch added to an existing conditional, bringing its own `#endif` (correct)',
         'rule 2\'s "and adds no #endif of its own" half, the measured tightening: this is '
         'wasi-osd-signal.patch\'s nineteen sites in isolation, and each of them is correct C',
         ELSE_BRANCH_ADDED, []),

        ('two identical guards side by side in one added run, each closed (correct)',
         'rule 3\'s requirement that the outer guard still be OPEN: these two are siblings, not '
         'nested, and reporting them would fail any patch that guards two statements separately',
         SIBLING_GUARDS, []),

        ('a `-` bullet in the patch preamble naming `#endif`, and a `---` file header',
         'the count-driven hunk parser: the preamble line `- #endif was moved ...` is prose, and '
         'reading it as a removed `#endif` unbalances a correct patch, because the bullets quote '
         'no conditional open to pair with it',
         PROSE_PREAMBLE, []),

        ('added lines that quote `#endif` inside a `//` and a `/* */` comment',
         'directive()\'s anchoring: `#` must be the first non-blank character on the line, which '
         'is why it matches rather than searches. Both quoted `#endif`s and no quoted open, so a '
         'searching version reports the file as unbalanced',
         COMMENTED_DIRECTIVE, []),
    ]

    failed = 0
    print('patch-text cases')
    for name, isolates, patch_text, expected in cases:
        found, _ = findings_for_patch('fixture.patch', patch_text)
        got = sorted(kind for kind, _, _, _, _ in found)
        ok = got == sorted(expected)
        failed += not ok
        print('  %s %s' % ('ok  ' if ok else 'MISS', name))
        print('       isolates: %s' % isolates)
        if not ok:
            print('       expected %s, got %s' % (sorted(expected), got))

    # The deeper mode, which is a different parser and needs its own battery: the patch-text rules
    # above never see a whole file, and these four cases never see a diff.
    print('full-file cases')
    tree_cases = [
        ('`#else` after `#else`', 'the per-frame `else` marker in scan_source',
         TREE_ELSE_AFTER_ELSE, ['ELSE_AFTER_ELSE']),
        ('`#endif` with no open conditional', 'the empty-stack branch on #endif',
         TREE_ORPHAN_ENDIF, ['ORPHAN_ENDIF']),
        ('a conditional left open at end of file', 'the leftover-frame sweep after the loop',
         TREE_UNTERMINATED, ['UNTERMINATED']),
        ('directives quoted inside a block comment', 'strip_block_comments: without it the '
         'commented `#else`/`#endif` pop a live frame and the file reports an orphan',
         TREE_COMMENTED_OUT, []),
    ]
    for name, isolates, source, expected in tree_cases:
        got = sorted(kind for kind, _, _, _ in scan_source('fixture.cxx', source))
        ok = got == sorted(expected)
        failed += not ok
        print('  %s %s' % ('ok  ' if ok else 'MISS', name))
        print('       isolates: %s' % isolates)
        if not ok:
            print('       expected %s, got %s' % (sorted(expected), got))

    # A blind run and a clean run must not look alike. run() returns 1 when a patch parses to no
    # hunk; this asserts the parser actually produces hunks for a normal patch, so that guard is
    # testing something.
    print('view cases')
    view_cases = [
        ('a normal patch parses to at least one hunk', len(parse_patch(NEW_GUARD)) >= 1),
        # Not decorative: every fixture above was first written with a hand-guessed `@@` count, and
        # the over-large counts made the parser consume the NEXT hunk header as body, so a
        # two-hunk fixture parsed to one and the rule-1 case reported nothing while looking like a
        # correct fixture. This is the assertion that separates the two.
        ('every fixture parses to as many hunks as it has `@@` headers',
         all(len(parse_patch(text)) == text.count('\n@@ ') + text.startswith('@@ ')
             for text in (DOUBLED_ADJACENT, DOUBLED_SEPARATED, UNBALANCED_ENDIF, HIJACKED_ELSE,
                          WIDENED_CONDITION, NEW_GUARD, ELSE_BRANCH_ADDED, SIBLING_GUARDS,
                          PROSE_PREAMBLE, COMMENTED_DIRECTIVE))),
        ('a patch with no hunk header parses to none',
         len(parse_patch('just prose, no diff at all\n')) == 0),
        ('every hunk entry is classified', all(
            sign in ' -+' for hunk in parse_patch(UNBALANCED_ENDIF) for sign, _, _ in hunk.entries)),
    ]
    for name, ok in view_cases:
        failed += not ok
        print('  %s %s' % ('ok  ' if ok else 'MISS', name))

    total = len(cases) + len(tree_cases) + len(view_cases)
    print('%d/%d cases correct' % (total - failed, total))
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--self-test', action='store_true',
                        help='run the fixture battery instead of the repo')
    parser.add_argument('--list', action='store_true',
                        help='print each patch\'s per-file directive deltas, no verdict')
    parser.add_argument('--tree', nargs='?', const=DEFAULT_TREE, default=None, metavar='DIR',
                        help='also parse each patched file end to end in this checkout '
                             '(default %s); not part of gate-scripts, which has no checkout'
                             % DEFAULT_TREE)
    parser.add_argument('--require-tree', action='store_true',
                        help='fail rather than skip when --tree examined nothing (#2098)')
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if args.list:
        return list_deltas()
    if args.require_tree and args.tree is None:
        args.tree = DEFAULT_TREE
    return run(tree=args.tree, require_tree=args.require_tree)


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
