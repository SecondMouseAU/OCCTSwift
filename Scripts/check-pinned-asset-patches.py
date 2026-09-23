#!/usr/bin/env python3
"""Check: the pinned OCCT asset holds the patches `Scripts/patches/` says it holds, and no others.

WHY THIS EXISTS (#2190). Every count this repo keeps about its carried patches compares one piece
of text against another: `check-inventory-prose.py` holds `Package.swift`, `CLAUDE.md` and
`okf/references/carried-occt-patches.md` to `ls Scripts/patches/*.patch | wc -l`. That is a closed
loop over the repo's own prose. **Nothing read the binary.** So when the v4.0.0-kernel.1 asset was
built from a `Libraries/occt-src` tree that still carried two retired patches nobody had reverted,
every count agreed with every other count and the asset shipped with thirty-one patches under a
label saying twenty-nine. `okf/policies/pinned-kernel-patch-check.md` had already written down that
the count is "necessary and not sufficient"; this script is the sufficient half, as far as a
sufficient half is reachable at all.

`build-occt.sh` applies patches idempotently and never reverts (see its own comment), so a retired
patch's edits survive in a shared source tree until somebody deletes them by hand. A rebuild then
picks them up silently. The two that shipped were inert, and the next pair might not be.

WHAT IT CAN AND CANNOT PROVE, stated before the rules rather than after.

It cannot decide "is patch NNNN in this binary" in general. A patch that rewrites a function body
and adds no name, no literal and no new external reference contributes nothing a symbol table or a
byte search can see. Thirteen of the twenty-nine carried patches are that shape. Reporting them
as absent would be wrong and reporting them as present would be a lie, so they get their own
bucket and the summary says how many are in it. A verdict this script does not reach is printed as
a verdict it does not reach.

It also cannot sweep for arbitrary unknown content. "What else is in this binary that no patch
explains" has no answer short of rebuilding and comparing, which is the thing this check exists to
avoid needing. What it does instead is name the patches that were retired and deleted, recover each
one from git history, and look for it. That converts "we hope nothing stale is in there" into "the
known stale candidates are not in there", which is what #2190 actually needed.

THE FOUR EVIDENCE RULES. Each says what a patch leaves behind that survives compilation.

  1. HEADER (decisive in both directions). A patch hunk targeting a `.hxx`/`.lxx` that the
     xcframework ships under `<slice>/Headers/`. Every substantive line the hunk adds must appear
     in the shipped header, and the shipped header is the patched source file verbatim, so a
     missing line is proof the patch did not reach this asset. Fifteen of the twenty-nine carried
     patches are covered this way, 303 added header lines between them.

  2. LITERAL (decisive in both directions). A string literal of twelve characters or more that the
     patch adds and does not remove. It is searched for in the bytes of the one object file its
     translation unit produced, not across the whole archive, so a coincidental match in an
     unrelated file cannot confirm a patch. `0026`'s throw message is the case that motivated it,
     and `Package.swift` already recorded that method by hand.

  3. THREAD-LOCAL (positive only). A variable the patch makes `thread_local` produces a
     `thread-local wrapper routine for <name>` symbol that a plain `static` does not. This is what
     finds retired `0032` in the asset today.

  4. NEW NAME (positive only). A function name that appears only in the patch's added lines, never
     in its context or removed lines, so the patch introduces it. This is what finds the retired
     `LocOpe_SplitDrafts` patch's `TrimInfinite` helper.

RULES 3 AND 4 ARE POSITIVE ONLY, AND THAT IS MEASURED, NOT CAUTIOUS. Patch `0033` adds
`std::recursive_mutex& StaticsMutex()` to `Interface_Static.cxx`. That name is in **no** symbol
table in the pinned asset: `std::recursive_mutex`'s default constructor is `constexpr` in libc++,
so the function-local static needs no guard variable, and at `-O2` the accessor inlines away
completely. The patch is in the binary (`Interface_Static.cxx.o` carries the undefined references
to `recursive_mutex::lock()` that vanilla `V8_0_1` has no reason to hold) and its most obvious
symbol is not. An absent name is therefore inconclusive, and this script says so rather than
reporting a defect it cannot substantiate.

ALL THREE SLICES, EVERY TIME. `macos-arm64`, `ios-arm64` and `ios-arm64-simulator` are three
separate cmake builds out of one source tree, in three `Libraries/occt-build-*` directories that
are configured at different times. Evidence found in some slices and not others is its own finding:
it means the slices were not built from the same tree.

NOT A `gate-scripts` SCRIPT. That job is pure Python over the repo's own text, no OCCT, no build,
no network, and this reads a 157 MB static archive per slice out of a 1.3 GB xcframework that CI
does not check out. It belongs to the release process, at the step that re-points `Package.swift`'s
`url:`/`checksum:`, which is the moment the question is live. `CLAUDE.md`'s Release Process and
`okf/policies/pinned-kernel-patch-check.md` both say so.

Per #2098, a run that examined nothing must fail rather than pass: without the asset the script
prints a note and returns 0, and `--require-asset` turns that into an error.

Usage:
  Scripts/check-pinned-asset-patches.py                      # the check, against Libraries/OCCT.xcframework
  Scripts/check-pinned-asset-patches.py --asset DIR          # ...against another xcframework
  Scripts/check-pinned-asset-patches.py --require-asset      # a missing asset is an error (#2098)
  Scripts/check-pinned-asset-patches.py --list               # the derived evidence, no asset read
  Scripts/check-pinned-asset-patches.py --self-test
"""
import argparse
import glob
import os
import re
import subprocess
import sys

CARRIED_GLOB = 'Scripts/patches/*.patch'
DEFAULT_ASSET = 'Libraries/OCCT.xcframework'

# slice directory -> the static archive inside it, as Scripts/build-occt.sh names them.
SLICES = (
    ('macos-arm64', 'libOCCT-macos.a'),
    ('ios-arm64', 'libOCCT-ios.a'),
    ('ios-arm64-simulator', 'libOCCT-sim.a'),
)

# Patches that were carried, then retired and DELETED from Scripts/patches/. Each is recovered from
# git history rather than restated here, so the evidence rules above run over the real patch text
# and cannot drift from it. A retirement adds a row; nothing else does.
#
# The revision is the last commit that still had the file. `Scripts/patches/README.md`'s "Retired
# patches" section holds each one's writeup and the reason.
# A divergence with a written reason is expected; one without is a finding (`CLAUDE.md`). This is
# where the written reason lives for the machine as well as the reader: {(pinned tag, retired patch
# number): why}. An acknowledged extra is printed and does not fail the run.
#
# The key carries the tag `Package.swift` pins, so a repin retires the row automatically rather
# than leaving it to suppress a finding about an asset it was never written about. An
# acknowledgement whose patch is NOT found in the asset is itself a finding, for the same reason:
# it has outlived what it described and the next reader would trust it.
ACKNOWLEDGED = {
    ('v4.0.0-kernel.1', '0032'):
        'Built from a Libraries/occt-src tree where 0032 had been retired from Scripts/patches/ '
        'but never reverted out of the source. Inert: the twelve globals are unreachable from '
        'this bridge, and thread_local is identical to static single-threaded. Documented in '
        'Package.swift\'s pin block and okf/references/carried-occt-patches.md (#2190).',
    ('v4.0.0-kernel.1', '0034-LocOpe'):
        'Same tree, same cause. Inert: LocOpe_SplitDrafts has no caller anywhere, its Swift '
        'wrapper was removed in v4.0.0, and upstream deleted the class. Documented in '
        'Package.swift\'s pin block and okf/references/carried-occt-patches.md (#2190).',
}

RETIRED = (
    ('0032', 'b7cd990f',
     '0032-TopOpeBRepBuild-KPart-merge-globals-thread-local-1371.patch',
     'retired 2026-09-02 (f4301e93, PR #1472): upstream OCCT#1505/#1509 fix the same twelve '
     'globals as per-instance fields, which is strictly better than thread_local duplication'),
    # Keyed `0034-LocOpe`, not `0034`: the number was reused, which `Scripts/patches/README.md`
    # now records as the one exception to "numbers are never reused". A bare `0034` here would
    # name two different patches.
    ('0034-LocOpe', '19d2f12f',
     '0034-LocOpe_SplitDrafts-trim-infinite-pipe-curves-1393.patch',
     'retired 2026-09-08 (be2d0d77, PR #1657): upstream deleted LocOpe_SplitDrafts outright in '
     'OCCT#1442, and Shape.splitDrafts went with it. The number was later reused by '
     '0034-GeomFill-CoonsAlgPatch-Value-U-parameter-1515.patch'),
)

HUNK_RE = re.compile(r'^@@ ')
TARGET_RE = re.compile(r'^\+\+\+ b/(.+?)\s*$')
OLD_TARGET_RE = re.compile(r'^--- a/(.+?)\s*$')

# `thread_local`/`static thread_local` on a named variable, which is what produces a TLV wrapper.
TLS_RE = re.compile(r'\bthread_local\b[^;=(]*?\b([A-Za-z_]\w*)\s*(?:=|;|\[)')

# A candidate function name: an identifier followed by `(`, not reached through `.`, `->` or `::`,
# which would make it a call on something that already exists.
CALL_RE = re.compile(r'(?:^|[^\w:.>])([A-Za-z_]\w*)\s*\(')
# `Handle(Geom_Curve)`: a macro or a cast, not a function this patch defines. Its parenthesis holds
# one bare identifier, where a parameter list holds a type and a name, a comma, a `&`, a `*`, or
# nothing at all. Without this rule `static Handle(Geom_Curve) TrimInfinite(...)` derives `Handle`,
# which matches in every object file in the archive and would confirm any patch at all.
MACRO_ARG_RE = re.compile(r'^\s*[A-Za-z_]\w*\s*\)')
KEYWORDS = frozenset(('if', 'for', 'while', 'switch', 'return', 'catch', 'sizeof', 'throw',
                      'else', 'do', 'case', 'new', 'delete', 'auto', 'const', 'static',
                      'inline', 'constexpr', 'explicit', 'operator', 'decltype'))

STRING_RE = re.compile(r'"((?:[^"\\\n]|\\.){12,})"')

# A line that is only punctuation or a fragment matches everywhere, so it proves nothing.
MIN_SUBSTANCE = 6


class Evidence(object):
    """One derivable thing a patch leaves in the built asset.

    `decisive` says whether NOT finding it is proof of absence. Only HEADER and LITERAL are, for
    the reason the module docstring gives at length: a name can be inlined out of existence.
    """

    def __init__(self, kind, patch, target, member, tokens, decisive, note=''):
        self.kind = kind
        self.patch = patch
        self.target = target
        self.member = member
        self.tokens = tokens
        self.decisive = decisive
        self.note = note

    def __repr__(self):
        return 'Evidence(%s, %s, %d token(s))' % (self.kind, self.target, len(self.tokens))


# --- patch text --------------------------------------------------------------------------------


def normalise(line):
    """Collapse whitespace, so a line matches regardless of how it was re-indented."""
    return ' '.join(line.split())


def parse_patch(text):
    """{target path: {'added': [...], 'removed': [...], 'context': [...]}} for one patch file.

    Only lines inside a hunk count. A patch preamble is prose about the fix and frequently quotes
    the code it is about, which would otherwise read as added lines (#2190's own two retired
    patches both quote theirs).
    """
    targets = {}
    current = None
    in_hunk = False
    for line in text.split('\n'):
        match = TARGET_RE.match(line)
        if match:
            current = match.group(1)
            if current != '/dev/null':
                targets.setdefault(current, {'added': [], 'removed': [], 'context': []})
            in_hunk = False
            continue
        if OLD_TARGET_RE.match(line):
            in_hunk = False
            continue
        if HUNK_RE.match(line):
            in_hunk = bool(current)
            continue
        if not in_hunk or current not in targets:
            continue
        if line.startswith('+'):
            targets[current]['added'].append(line[1:])
        elif line.startswith('-'):
            targets[current]['removed'].append(line[1:])
        elif line.startswith(' ') or line == '':
            targets[current]['context'].append(line[1:] if line else '')
        elif line.startswith('diff --git') or line.startswith('\\'):
            continue
        else:
            in_hunk = False
    return targets


def object_member(target):
    """The archive member a source file compiles to, or None for a header.

    OCCT's cmake keeps the source basename and appends `.o`, so `.../Interface_Static.cxx` becomes
    `Interface_Static.cxx.o`. Checked against the real archive: every carried patch's target
    resolves.
    """
    base = os.path.basename(target)
    if base.endswith(('.hxx', '.lxx', '.h')):
        return None
    return base + '.o'


def code_lines(added):
    """Added lines with the comments dropped.

    A carried patch explains itself in a comment beside the change, and those comments quote the
    very thing the rules look for: `0032`'s read "// #1371: thread_local, same STATIC_Gmotherope
    precedent", from which the thread-local rule derived a variable named `precedent`. A token
    derived from prose is a token that can never be found, and it makes a clean run look like a
    partial one.
    """
    return [l for l in added if not l.strip().startswith(('//', '*', '/*'))]


def derive(patch_name, text):
    """Every piece of evidence the four rules can derive from one patch's text."""
    found = []
    for target, lines in sorted(parse_patch(text).items()):
        added = lines['added']
        if not added:
            continue
        member = object_member(target)
        if member is None:
            # A header's doc comments ship verbatim in the xcframework, so they are evidence here
            # exactly as code is. Only the object-file rules have to drop them.
            tokens = sorted({normalise(l) for l in added
                             if len(normalise(l)) >= MIN_SUBSTANCE})
            if tokens:
                found.append(Evidence('header', patch_name, target, None, tokens, True))
            continue

        added = code_lines(added)
        removed_text = '\n'.join(lines['removed'])
        literals = []
        for line in added:
            for match in STRING_RE.finditer(line):
                literal = match.group(1)
                if literal not in removed_text and literal not in literals:
                    literals.append(literal)
        if literals:
            found.append(Evidence('literal', patch_name, target, member, literals, True))

        tls = []
        for line in added:
            for match in TLS_RE.finditer(line):
                token = 'thread-local wrapper routine for %s' % match.group(1)
                if token not in tls:
                    tls.append(token)
        if tls:
            found.append(Evidence('thread-local', patch_name, target, member, tls, False))

        introduced = new_names(lines)
        if introduced:
            found.append(Evidence('new name', patch_name, target, member,
                                  ['%s(' % n for n in introduced], False))
    return found


def new_names(lines):
    """Function names the patch DEFINES and that appear nowhere in its context or removed lines.

    The second half is what makes it evidence. A name the surrounding code already uses was in the
    file before the patch, so finding it in the binary says nothing about the patch.
    """
    existing = ' '.join(lines['removed'] + lines['context'])
    names = []
    for line in lines['added']:
        stripped = line.strip()
        if stripped.startswith(('//', '*', '/*', '#')):
            continue
        # A statement, not a definition. `std::lock_guard<...> aLock(TheMutex());` and
        # `throw StdFail_NotDone("...");` both read as `Name(` to any regex, and both names
        # (`aLock`, `StdFail_NotDone`) resolve in the object file whether or not the patch is in
        # it, so accepting them would confirm a patch from evidence that proves nothing. A
        # definition's signature line ends in `{`, in `,` where it wraps, or in nothing.
        if stripped.endswith(';'):
            continue
        for match in CALL_RE.finditer(line):
            name = match.group(1)
            if name in KEYWORDS or len(name) < 4 or name in names:
                continue
            # An assignment makes the right-hand side a call, never a definition.
            if '=' in line[:match.start(1)]:
                break
            # A definition has a return type, so the name is never the line's first token.
            if line[:match.start(1)].strip() == '':
                continue
            if MACRO_ARG_RE.match(line[match.end():]):
                continue
            if re.search(r'\b%s\b' % re.escape(name), existing):
                continue
            names.append(name)
    return names


# --- the asset ---------------------------------------------------------------------------------


class Slice(object):
    """One xcframework slice: its shipped headers and its static archive."""

    def __init__(self, name, headers, archive):
        self.name = name
        self.headers = headers
        self.archive = archive
        self._symbols = {}
        self._blobs = {}
        self._members = None

    # -- overridable for --self-test, which builds a Slice with no files behind it -------------

    def header_text(self, basename):
        path = os.path.join(self.headers, basename)
        if not os.path.exists(path):
            return None
        with open(path, encoding='utf-8', errors='replace') as handle:
            return handle.read()

    def members(self):
        if self._members is None:
            out = subprocess.run(['ar', 't', self.archive], stdout=subprocess.PIPE,
                                 stderr=subprocess.DEVNULL)
            self._members = set(out.stdout.decode('utf-8', 'replace').split())
        return self._members

    def symbols(self, member):
        """Demangled symbol text for one archive member, '' when the member is absent.

        `nm` is given a real file rather than stdin: Apple's `nm` does not read a Mach-O object
        from a pipe, and a toolchain that silently returns nothing would make every symbol rule
        report "not found" on an asset that has them all.
        """
        if member in self._symbols:
            return self._symbols[member]
        blob = self.blob(member)
        if blob is None:
            self._symbols[member] = ''
            return ''
        import tempfile
        with tempfile.NamedTemporaryFile(suffix='.o', delete=False) as handle:
            handle.write(blob)
            path = handle.name
        try:
            proc = subprocess.run(['nm', '-C', path], stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL)
            self._symbols[member] = proc.stdout.decode('utf-8', 'replace')
        finally:
            os.unlink(path)
        return self._symbols[member]

    def blob(self, member):
        """The raw bytes of one archive member, None when it is absent."""
        if member not in self._blobs:
            if member not in self.members():
                self._blobs[member] = None
            else:
                out = subprocess.run(['ar', 'p', self.archive, member], stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL)
                self._blobs[member] = out.stdout or None
        return self._blobs[member]

    # -- the three lookups the rules need -------------------------------------------------------

    def has_header_lines(self, basename, tokens):
        text = self.header_text(basename)
        if text is None:
            return None, ['%s is not shipped in this slice' % basename]
        present = {normalise(line) for line in text.split('\n')}
        missing = [t for t in tokens if t not in present]
        return not missing, missing

    def has_literals(self, member, tokens):
        blob = self.blob(member)
        if blob is None:
            return None, ['%s is not in this slice\'s archive' % member]
        missing = [t for t in tokens if t.encode('utf-8', 'replace') not in blob]
        return not missing, missing

    def has_symbols(self, member, tokens):
        text = self.symbols(member)
        if not text:
            return None, ['%s has no symbol table in this slice' % member]
        missing = [t for t in tokens if t not in text]
        return len(missing) < len(tokens), missing


class Asset(object):
    def __init__(self, slices):
        self.slices = slices

    @classmethod
    def open(cls, root):
        slices = []
        for name, archive in SLICES:
            headers = os.path.join(root, name, 'Headers')
            lib = os.path.join(root, name, archive)
            if os.path.isdir(headers) and os.path.isfile(lib):
                slices.append(Slice(name, headers, lib))
        return cls(slices) if slices else None


def look_for(asset, evidence):
    """Run one piece of evidence against every slice.

    Returns (verdict, detail). verdict is True (in every slice), False (in no slice), 'partial'
    (in some), or None (nothing to look in).
    """
    results = {}
    detail = []
    for sl in asset.slices:
        if evidence.kind == 'header':
            ok, missing = sl.has_header_lines(os.path.basename(evidence.target), evidence.tokens)
        elif evidence.kind == 'literal':
            ok, missing = sl.has_literals(evidence.member, evidence.tokens)
        else:
            ok, missing = sl.has_symbols(evidence.member, evidence.tokens)
        results[sl.name] = ok
        if missing and ok is not True:
            detail.append('%s: %s' % (sl.name, '; '.join(str(m)[:110] for m in missing[:3])))
    values = [v for v in results.values() if v is not None]
    if not values:
        return None, detail
    if all(values) and len(values) == len(results):
        return True, detail
    if any(values):
        return 'partial', detail + ['found in %s, not in %s'
                                    % (','.join(n for n, v in sorted(results.items()) if v),
                                       ','.join(n for n, v in sorted(results.items()) if not v))]
    return False, detail


# --- the check ---------------------------------------------------------------------------------


def carried_patches(repo='.'):
    out = {}
    for path in sorted(glob.glob(os.path.join(repo, CARRIED_GLOB))):
        with open(path, encoding='utf-8', errors='replace') as handle:
            out[os.path.basename(path)] = handle.read()
    return out


PIN_URL_RE = re.compile(r'url:\s*"https://[^"]*/releases/download/([^/]+)/OCCT\.xcframework\.zip"')
PIN_SUM_RE = re.compile(r'checksum:\s*"([0-9a-f]{64})"')


def pinned_reference_from(text):
    """(tag, checksum) out of Package.swift's text, or (None, None)."""
    tag = PIN_URL_RE.search(text)
    checksum = PIN_SUM_RE.search(text)
    return (tag.group(1) if tag else None), (checksum.group(1) if checksum else None)


def pinned_reference(repo='.'):
    """(tag, checksum) from Package.swift's binaryTarget, or (None, None)."""
    path = os.path.join(repo, 'Package.swift')
    if not os.path.exists(path):
        return None, None
    with open(path, encoding='utf-8', errors='replace') as handle:
        return pinned_reference_from(handle.read())


def zip_identity(asset_root, pinned_checksum):
    """Whether the zip beside this xcframework is the one Package.swift pins.

    Returns (verdict, message). `None` where there is no zip to hash, which is the normal case in
    a worktree and in CI. It matters at the release step, where "is the thing I just checked the
    thing consumers will download" is the whole question.
    """
    candidate = os.path.join(os.path.dirname(os.path.abspath(asset_root)), 'OCCT.xcframework.zip')
    if not os.path.isfile(candidate) or not pinned_checksum:
        return None, ''
    import hashlib
    digest = hashlib.sha256()
    with open(candidate, 'rb') as handle:
        for chunk in iter(lambda: handle.read(1 << 22), b''):
            digest.update(chunk)
    actual = digest.hexdigest()
    if actual == pinned_checksum:
        return True, 'OCCT.xcframework.zip beside it hashes to Package.swift\'s checksum, so ' \
                     'this IS the pinned asset'
    return False, ('OCCT.xcframework.zip beside it hashes to %s, where Package.swift pins %s, so '
                   'this is NOT the pinned asset' % (actual[:16] + '...', pinned_checksum[:16]
                                                     + '...'))


def retired_patches(repo='.'):
    """Recover each retired patch's text from git history. Returns (texts, unrecovered)."""
    texts, unrecovered = {}, []
    for number, rev, filename, reason in RETIRED:
        proc = subprocess.run(['git', '-C', repo, 'show',
                               '%s:Scripts/patches/%s' % (rev, filename)],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode != 0 or not proc.stdout.strip():
            unrecovered.append((number, rev, filename, reason))
            continue
        texts[filename] = (number, proc.stdout.decode('utf-8', 'replace'), reason)
    return texts, unrecovered


def run(asset_root=DEFAULT_ASSET, require_asset=False, repo='.', asset=None):
    carried = carried_patches(repo)
    if not carried:
        print('check-pinned-asset-patches: no patches found under %s, so there was nothing to '
              'check the asset against. An empty population is a broken run, not a clean tree.'
              % CARRIED_GLOB)
        return 1

    # static-gates.md: validate the view, not only the verdict. A patch file that parsed to no
    # target was never examined, and "nothing unexpected in the asset" from a parser that read
    # nothing is the exact shape this family of scripts exists to prevent.
    blind = [name for name in sorted(carried) if not parse_patch(carried[name])]
    if blind:
        print('check-pinned-asset-patches: %d patch file(s) parsed to no target at all, so they '
              'were never examined:' % len(blind))
        for name in blind:
            print('  %s' % name)
        return 1

    if asset is None:
        asset = Asset.open(asset_root)
    if asset is None:
        message = ('check-pinned-asset-patches: %s holds no readable slice, so the asset was '
                   'never examined.' % asset_root)
        if require_asset:
            print(message + ' --require-asset was given, and a run that examined nothing fails '
                            'rather than passes (#2098).')
            return 1
        print(message + '\n  Nothing was checked. Build or download the xcframework, or pass '
                        '--asset DIR. Pass --require-asset where the asset is meant to be there.')
        return 0

    retired, unrecovered = retired_patches(repo)

    # A mistyped ACKNOWLEDGED key suppresses nothing and reads as if it does, which is the worst
    # of both. Check it against RETIRED before anything else looks at the asset.
    known = {row[0] for row in RETIRED}
    unknown = sorted(key for key in ACKNOWLEDGED if key[1] not in known)
    if unknown:
        print('check-pinned-asset-patches: ACKNOWLEDGED names %s, which is in no RETIRED row, so '
              'it can never match a finding.' % ', '.join('%s/%s' % k for k in unknown))
        return 1

    confirmed, undetermined, missing, unexpected, divergent = [], [], [], [], []

    for name in sorted(carried):
        evidence = derive(name, carried[name])
        if not evidence:
            undetermined.append((name, 'the patch adds no header line, no string literal, no '
                                       'thread_local and no new name'))
            continue
        seen_true = False
        for item in evidence:
            verdict, detail = look_for(asset, item)
            if verdict is True:
                confirmed.append((name, item, detail))
                seen_true = True
            elif verdict == 'partial':
                divergent.append((name, item, detail))
                seen_true = True
            elif verdict is False and item.decisive:
                missing.append((name, item, detail))
                seen_true = True
            elif verdict is None and item.decisive:
                missing.append((name, item, detail))
                seen_true = True
        if not seen_true:
            kinds = ', '.join(sorted({i.kind for i in evidence}))
            undetermined.append((name, 'only positive-only evidence (%s), none of it found; a '
                                       'name can be inlined away, so this is not proof of absence'
                                 % kinds))

    # One row per retired patch, not per target file: `0032` touches three translation units and
    # reporting it three times reads as three separate problems.
    for filename in sorted(retired):
        number, text, reason = retired[filename]
        hits = []
        for item in derive(filename, text):
            verdict, detail = look_for(asset, item)
            if verdict in (True, 'partial'):
                hits.append((item, detail, verdict))
        if hits:
            unexpected.append((number, filename, reason, hits))

    tag, checksum = pinned_reference(repo)
    identity, identity_note = zip_identity(asset_root, checksum)
    acknowledged, stale = split_acknowledged(unexpected, tag)

    return report(asset, carried, confirmed, undetermined, missing, unexpected, divergent,
                  unrecovered, require_asset, tag, identity, identity_note, acknowledged, stale)


def split_acknowledged(unexpected, tag):
    """Move the extras ACKNOWLEDGED names for this pin out of the findings, and report stale rows.

    `unexpected` is filtered in place. `stale` is every acknowledgement for this pin whose patch
    was NOT found, which is an acknowledgement describing an asset that no longer exists.
    """
    acknowledged = []
    for row in list(unexpected):
        number = row[0]
        why = ACKNOWLEDGED.get((tag, number))
        if why:
            acknowledged.append((number, row[1], why))
            unexpected.remove(row)
    found = {row[0] for row in unexpected} | {row[0] for row in acknowledged}
    stale = [(number, why) for (pin, number), why in sorted(ACKNOWLEDGED.items())
             if pin == tag and number not in found]
    return acknowledged, stale


def report(asset, carried, confirmed, undetermined, missing, unexpected, divergent, unrecovered,
           require_asset, tag=None, identity=None, identity_note='', acknowledged=(), stale=()):
    slices = ', '.join(sl.name for sl in asset.slices)
    print('check-pinned-asset-patches: %d carried patches against %d slice(s): %s'
          % (len(carried), len(asset.slices), slices))
    print('Package.swift pins %s. %s\n' % (tag or '(no tag parsed)',
                                           identity_note or 'No OCCT.xcframework.zip beside the '
                                                            'xcframework, so whether this is that '
                                                            'asset was not checked.'))

    by_patch = {}
    for name, item, _ in confirmed:
        by_patch.setdefault(name, []).append(item.kind)
    print('CONFIRMED PRESENT (%d of %d patches)' % (len(by_patch), len(carried)))
    for name in sorted(by_patch):
        print('  %-72s %s' % (name[:72], ', '.join(sorted(set(by_patch[name])))))

    print('\nNOT DERIVABLE (%d of %d patches), no verdict reached, not a finding'
          % (len(undetermined), len(carried)))
    for name, why in undetermined:
        print('  %-72s %s' % (name[:72], why))

    problems = 0
    if missing:
        problems += len(missing)
        print('\nEXPECTED AND ABSENT (%d), each one decisive evidence that the patch did not '
              'reach this asset' % len(missing))
        for name, item, detail in missing:
            print('  %s' % name)
            print('    %s evidence from %s' % (item.kind, item.target))
            for line in detail:
                print('      %s' % line)

    if divergent:
        problems += len(divergent)
        print('\nSLICE DIVERGENCE (%d), evidence present in some slices and not others, so the '
              'slices were not built from one tree' % len(divergent))
        for name, item, detail in divergent:
            print('  %s' % name)
            print('    %s evidence from %s' % (item.kind, item.target))
            for line in detail:
                print('      %s' % line)

    if acknowledged:
        print('\nACKNOWLEDGED DIVERGENCE (%d), retired patches this asset is KNOWN to carry, with '
              'the reason\nrecorded in Scripts/check-pinned-asset-patches.py\'s ACKNOWLEDGED table '
              'and in the pin block' % len(acknowledged))
        for number, filename, why in acknowledged:
            print('  %s  %s' % (number, filename))
            print('    %s' % why)

    if unexpected:
        problems += len(unexpected)
        print('\nUNEXPECTEDLY PRESENT (%d), retired patches whose code is in this asset and which '
              'nothing explains' % len(unexpected))
        for number, filename, reason, hits in unexpected:
            print('  %s  %s' % (number, filename))
            print('    %s' % reason)
            for item, detail, verdict in hits:
                print('    found by %s evidence in %s: %s'
                      % (item.kind, item.member or item.target, ', '.join(item.tokens[:3])))
                if verdict == 'partial':
                    for line in detail:
                        print('      %s' % line)

    if stale:
        problems += len(stale)
        print('\nSTALE ACKNOWLEDGEMENT (%d), an ACKNOWLEDGED row for this pin whose patch is NOT '
              'in the asset.\nThe divergence it describes is gone, so the row now excuses '
              'something that is not happening' % len(stale))
        for number, why in stale:
            print('  %s  %s' % (number, why.split('.')[0]))

    if unrecovered:
        print('\nNOT RECOVERED (%d), retired patches git could not hand back, so the asset was '
              'NOT checked for them' % len(unrecovered))
        for number, rev, filename, _ in unrecovered:
            print('  %s  git show %s:Scripts/patches/%s failed (a shallow clone cannot reach it)'
                  % (number, rev, filename))
        if require_asset:
            print('\n--require-asset was given and part of the check did not run.')
            return 1

    if problems:
        print('\n%d finding(s). okf/policies/pinned-kernel-patch-check.md has what to do with '
              'each:\nan asset that holds what the tree does not is a rebuild or a written '
              'divergence, never a\nhand-edited number. #2190 is the case this script was written '
              'from.' % problems)
        return 1

    print('\nclean: %d confirmed, %d not derivable, %d acknowledged, 0 absent, 0 unexpected' %
          (len(by_patch), len(undetermined), len(acknowledged)))
    return 0


def list_evidence(repo='.'):
    carried = carried_patches(repo)
    retired, unrecovered = retired_patches(repo)
    print('%d carried patches, %d retired patches recovered from git history\n'
          % (len(carried), len(retired)))
    for name in sorted(carried):
        evidence = derive(name, carried[name])
        print('%s' % name)
        if not evidence:
            print('    (nothing derivable)')
        for item in evidence:
            where = item.member or os.path.basename(item.target)
            sample = ', '.join(str(t)[:60] for t in item.tokens[:2])
            print('    %-12s %-34s %s%s' % (item.kind, where,
                                            '%d token(s)' % len(item.tokens),
                                            ': ' + sample if item.kind != 'header' else ''))
    for filename in sorted(retired):
        number, text, _ = retired[filename]
        print('\nRETIRED %s %s' % (number, filename))
        for item in derive(filename, text):
            print('    %-12s %-34s %s' % (item.kind, item.member or item.target,
                                          ', '.join(str(t)[:60] for t in item.tokens[:2])))
    for number, rev, filename, _ in unrecovered:
        print('\nRETIRED %s %s: NOT RECOVERED from %s' % (number, filename, rev))
    return 0


# --- self-test ---------------------------------------------------------------------------------


HEADER_PATCH = '''\
Subject: [PATCH] a header change

diff --git a/src/Foo/Foo_Thing.hxx b/src/Foo/Foo_Thing.hxx
--- a/src/Foo/Foo_Thing.hxx
+++ b/src/Foo/Foo_Thing.hxx
@@ -10,6 +10,8 @@
   void Perform();
+  //! Returns the achieved error.
+  double AchievedError() const;

   int myCount;
'''

LITERAL_PATCH = '''\
Subject: [PATCH] a throw

diff --git a/src/Foo/Foo_Thing.cxx b/src/Foo/Foo_Thing.cxx
--- a/src/Foo/Foo_Thing.cxx
+++ b/src/Foo/Foo_Thing.cxx
@@ -10,3 +10,4 @@
   if (!B)
+    throw StdFail_NotDone("Foo_Thing: could not close the extremity");
   return;
'''

TLS_PATCH = '''\
Subject: [PATCH] thread_local

diff --git a/src/Foo/Foo_Grid.cxx b/src/Foo/Foo_Grid.cxx
--- a/src/Foo/Foo_Grid.cxx
+++ b/src/Foo/Foo_Grid.cxx
@@ -86,2 +86,2 @@
-Standard_EXPORT bool GLOBAL_flag = false;
+Standard_EXPORT thread_local bool GLOBAL_flag = false;
'''

NEWNAME_PATCH = '''\
Subject: [PATCH] a helper

The preamble quotes the diff it is about, at column zero, the way these writeups do:

+static Handle(Geom_Curve) PreambleOnly(const Handle(Geom_Curve)& C, const Bnd_Box& B)

and quoted code must not be read as added lines.

diff --git a/src/Foo/Foo_Split.cxx b/src/Foo/Foo_Split.cxx
--- a/src/Foo/Foo_Split.cxx
+++ b/src/Foo/Foo_Split.cxx
@@ -83,6 +83,8 @@
 static TopoDS_Edge NewEdge(const TopoDS_Edge&, const TopoDS_Edge&);
+static Handle(Geom_Curve) TrimInfinite(const Handle(Geom_Curve)& theCurve,
+                                       const Bnd_Box&            theBox)

 static bool Contains(const NCollection_List<TopoDS_Shape>&);
--
2.39.5

+static Handle(Geom_Curve) TrailerOnly(const Bnd_Box& theBox, const double theTol)
'''

# Isolates the "name already in the context" filter alone: the added line is a definition, it does
# not end in `;`, it has a return type and it holds no macro call, so every other filter passes it.
REUSED_NAME_PATCH = '''\
Subject: [PATCH] redeclares something that already existed

diff --git a/src/Foo/Foo_Call.cxx b/src/Foo/Foo_Call.cxx
--- a/src/Foo/Foo_Call.cxx
+++ b/src/Foo/Foo_Call.cxx
@@ -10,3 +10,4 @@
 static double ExistingHelper(const double x);
+static double ExistingHelper(const double x, const double y)
 {
'''

# Isolates the comment filter: `thread_local` and a name and a `;`, all inside a comment.
COMMENTED_TLS_PATCH = '''\
Subject: [PATCH] a comment about thread_local

diff --git a/src/Foo/Foo_Grid.cxx b/src/Foo/Foo_Grid.cxx
--- a/src/Foo/Foo_Grid.cxx
+++ b/src/Foo/Foo_Grid.cxx
@@ -86,2 +86,3 @@
+  // #1371: thread_local, same STATIC_Gmotherope precedent; declared extern above.
   int aCount = 0;
'''


class FakeSlice(Slice):
    """A Slice backed by dictionaries, so the self-test needs no xcframework."""

    def __init__(self, name, headers, blobs, symbols):
        Slice.__init__(self, name, '', '')
        self._fake_headers = headers
        self._fake_blobs = blobs
        self._fake_symbols = symbols

    def header_text(self, basename):
        return self._fake_headers.get(basename)

    def members(self):
        return set(self._fake_blobs)

    def symbols(self, member):
        return self._fake_symbols.get(member, '')

    def blob(self, member):
        text = self._fake_blobs.get(member)
        return text.encode('utf-8') if text is not None else None


def fake_asset(**overrides):
    headers = {'Foo_Thing.hxx': ('  void Perform();\n'
                                 '  //! Returns the achieved error.\n'
                                 '  double AchievedError() const;\n'
                                 '  int myCount;\n')}
    blobs = {'Foo_Thing.cxx.o': 'Foo_Thing: could not close the extremity\x00',
             'Foo_Grid.cxx.o': 'nothing here',
             'Foo_Split.cxx.o': 'nothing here',
             'Foo_Call.cxx.o': 'nothing here'}
    symbols = {'Foo_Grid.cxx.o': '0000 T thread-local wrapper routine for GLOBAL_flag\n',
               'Foo_Split.cxx.o': '0000 t TrimInfinite(handle<Geom_Curve> const&, Bnd_Box const&)\n',
               'Foo_Thing.cxx.o': '0000 T Foo_Thing::Perform()\n',
               'Foo_Call.cxx.o': '0000 t ExistingHelper(double)\n'}
    headers.update(overrides.get('headers', {}))
    blobs.update(overrides.get('blobs', {}))
    symbols.update(overrides.get('symbols', {}))
    names = overrides.get('slices', [n for n, _ in SLICES])
    return Asset([FakeSlice(n, headers, blobs, symbols) for n in names])


def acknowledge_fixture():
    """(what is left as a finding, what was acknowledged) for the pin ACKNOWLEDGED describes."""
    rows = [(number, filename, 'retired', []) for (_, number) in [(0, '0032')]
            for filename in ['0032-TopOpeBRepBuild-KPart-merge-globals-thread-local-1371.patch']]
    acknowledged, _ = split_acknowledged(rows, 'v4.0.0-kernel.1')
    return rows, acknowledged


def verdict_of(patch_text, asset, kind=None):
    items = derive('fixture.patch', patch_text)
    if kind:
        items = [i for i in items if i.kind == kind]
    if not items:
        return 'no evidence'
    return look_for(asset, items[0])[0]


def self_test():
    asset = fake_asset()
    cases = [
        ('a header patch whose added lines are in the shipped header is confirmed',
         verdict_of(HEADER_PATCH, asset, 'header') is True),
        ('the same patch against a header missing one line is decisively absent',
         verdict_of(HEADER_PATCH,
                    fake_asset(headers={'Foo_Thing.hxx': '  void Perform();\n  int myCount;\n'}),
                    'header') is False),
        ('a header the slice does not ship yields no verdict, not a pass',
         verdict_of(HEADER_PATCH, fake_asset(headers={'Foo_Thing.hxx': None}), 'header') is None
         or verdict_of(HEADER_PATCH, Asset([FakeSlice('macos-arm64', {}, {}, {})]),
                       'header') is None),
        ('a string literal in the right object file is confirmed',
         verdict_of(LITERAL_PATCH, asset, 'literal') is True),
        ('the same literal in the WRONG object file does not confirm',
         verdict_of(LITERAL_PATCH,
                    fake_asset(blobs={'Foo_Thing.cxx.o': 'unrelated',
                                      'Elsewhere.cxx.o': 'Foo_Thing: could not close the '
                                                         'extremity'}),
                    'literal') is False),
        ('a thread_local variable is found by its TLV wrapper symbol',
         verdict_of(TLS_PATCH, asset, 'thread-local') is True),
        ('a plain static does not produce that symbol, so the patch is not found',
         verdict_of(TLS_PATCH, fake_asset(symbols={'Foo_Grid.cxx.o': '0000 d GLOBAL_flag\n'}),
                    'thread-local') is False),
        ('a name the patch introduces is found in its own object file',
         verdict_of(NEWNAME_PATCH, asset, 'new name') is True),
        ('a name the surrounding context already holds is not derived as evidence at all',
         verdict_of(REUSED_NAME_PATCH, asset, 'new name') == 'no evidence'),
        ('evidence in some slices and not others is reported as divergence',
         verdict_of(LITERAL_PATCH,
                    Asset([FakeSlice('macos-arm64', {}, {'Foo_Thing.cxx.o': 'Foo_Thing: could '
                                                                           'not close the '
                                                                           'extremity'}, {}),
                           FakeSlice('ios-arm64', {}, {'Foo_Thing.cxx.o': 'no'}, {})]),
                    'literal') == 'partial'),
    ]

    parser_cases = [
        ('a macro invocation in a signature is not derived as a name (`Handle(Geom_Curve)`), '
         'which would otherwise match in every object file',
         'Handle(' not in sum([i.tokens for i in derive('x', NEWNAME_PATCH)
                               if i.kind == 'new name'], [])),
        ('a `throw StdFail_NotDone("...");` statement derives no name',
         all(i.kind != 'new name' for i in derive('x', LITERAL_PATCH))),
        ('a comment mentioning thread_local derives no variable',
         derive('x', COMMENTED_TLS_PATCH) == []),
        # Two mechanisms, two cases. A commit message is read before any `+++ b/` has opened a
        # target; a trailer is read after the last hunk has closed. Only the second needs the
        # `in_hunk` flag, and the first would pass without it, so they are kept apart.
        ('a commit message quoting a diff contributes no added lines',
         'PreambleOnly' not in str(new_names(parse_patch(NEWNAME_PATCH)
                                             ['src/Foo/Foo_Split.cxx']))),
        ('a git trailer after the last hunk contributes no added lines',
         'TrailerOnly' not in str(new_names(parse_patch(NEWNAME_PATCH)
                                            ['src/Foo/Foo_Split.cxx']))),
        ('object_member maps a .cxx target to its archive member',
         object_member('src/Foo/Foo_Thing.cxx') == 'Foo_Thing.cxx.o'),
        ('object_member returns None for a header, which has no member',
         object_member('src/Foo/Foo_Thing.hxx') is None),
        ('a literal under twelve characters is not derived',
         derive('x', LITERAL_PATCH.replace('Foo_Thing: could not close the extremity', 'short'))
         == [] or all(i.kind != 'literal' for i in
                      derive('x', LITERAL_PATCH.replace(
                          'Foo_Thing: could not close the extremity', 'short')))),
        ('normalise collapses re-indentation',
         normalise('   double  AchievedError()   const;') == 'double AchievedError() const;'),
        ('HEADER and LITERAL are decisive, the symbol rules are not',
         all(i.decisive for i in derive('x', HEADER_PATCH) + derive('x', LITERAL_PATCH))
         and not any(i.decisive for i in derive('x', TLS_PATCH) + derive('x', NEWNAME_PATCH))),
        ('every carried patch in the tree parses to at least one target, so none is skipped',
         all(parse_patch(text) for text in carried_patches('.').values())),
        ('a patch with no diff at all parses to no target, which the run reports as blind',
         parse_patch('Subject: [PATCH] prose only\n\nNo diff here.\n') == {}),
        ('every RETIRED row names a distinct patch file',
         len({r[2] for r in RETIRED}) == len(RETIRED)),
        ('every ACKNOWLEDGED key names a RETIRED row, so none of them suppresses nothing',
         all(key[1] in {r[0] for r in RETIRED} for key in ACKNOWLEDGED)),
        ('pinned_reference reads the tag and the checksum out of a binaryTarget',
         pinned_reference_from(
             'url: "https://github.com/x/y/releases/download/v9.9.9-kernel.2/'
             'OCCT.xcframework.zip"\nchecksum: "%s"' % ('a' * 64)) == ('v9.9.9-kernel.2', 'a' * 64)),
        ('an acknowledged extra moves out of the findings',
         acknowledge_fixture()[0] == [] and len(acknowledge_fixture()[1]) == 1),
        ('an acknowledgement for a DIFFERENT pin does not suppress this one',
         len(split_acknowledged([('0032', 'f.patch', 'r', [])], 'v0.0.0-other')[0]) == 0),
        ('an acknowledgement whose patch is not in the asset is reported stale',
         split_acknowledged([], 'v4.0.0-kernel.1')[1] != []),
    ]

    failed = 0
    print('check-pinned-asset-patches --self-test')
    for name, ok in cases + parser_cases:
        failed += not ok
        print('  %s %s' % ('ok  ' if ok else 'MISS', name))
    total = len(cases) + len(parser_cases)
    print('%d/%d cases correct' % (total - failed, total))
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--asset', default=DEFAULT_ASSET, metavar='DIR',
                        help='the xcframework to read (default %s)' % DEFAULT_ASSET)
    parser.add_argument('--require-asset', action='store_true',
                        help='fail rather than skip when the asset is not there (#2098)')
    parser.add_argument('--list', action='store_true',
                        help='print the evidence derived from each patch, reading no asset')
    parser.add_argument('--self-test', action='store_true',
                        help='run the fixture battery instead of the repo')
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if args.list:
        return list_evidence()
    return run(asset_root=args.asset, require_asset=args.require_asset)


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
