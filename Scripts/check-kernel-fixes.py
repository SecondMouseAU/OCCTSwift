#!/usr/bin/env python3
"""GATE: the kernel-fix ledger, the patch directory and every guard that names a fix must agree.

A guard written for a kernel defect carries the tag `kernel-defect: F0080` and is compiled in only
where the kernel lacks the fix (`#if !OCCTSWIFT_KERNEL_HAS_F0080`); a test that needs the fix says
`requiresKernelFix("F0080")`. Scripts/kernel-fixes.tsv is the one list of defects, and this gate
fails on each way the three can drift apart:

  1. the ledger is malformed, or disagrees with Scripts/patches (a patch with no row, a row whose
     patch is gone and which no upstream release absorbs, an absorbed row whose file is still there);
  2. a tag, a macro or a test trait names a fix the ledger has no row for;
  3. a guard is compiled in on `#if !OCCTSWIFT_KERNEL_HAS_Fxxxx` while EVERY shipping flavour
     already holds the fix, so the guard can never run: "retire this guard". The same for a test
     trait on a fix every flavour holds, which is a condition that is always true. This is the
     failure the previous arrangement lacked: three mitigations outlived their fix (okf/references/
     known-occt-bugs.md) because nothing could say so.

The shipping flavours are `carry` (the patches in Scripts/patches) and `vanilla` (none), both at the
OCCT version Scripts/build-occt.sh names. Exits 1 on a finding, 0 clean. `--self-test` proves it is
not blind. The binary-side check (a vanilla asset lists no carried patch) is
check-pinned-asset-patches.py's, because it needs the asset.
"""
from __future__ import annotations

import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import kernel_fixes  # noqa: E402

SCAN_DIRS = ('Sources', 'Tests')
SCAN_EXT = ('.swift', '.mm', '.h', '.m', '.cpp', '.hpp')
TAG_RE = re.compile(r'kernel-defect:\s*(F\d{4})')
MACRO_RE = re.compile(r'OCCTSWIFT_KERNEL_HAS_(F\d{4})')
TRAIT_RE = re.compile(r'requiresKernelFix\(\s*"(F\d{4})"')
# A guard compiles in on the NEGATED macro. Matching the whole directive line keeps a comment that
# merely mentions a macro from counting as a guard.
GUARD_RE = re.compile(r'^\s*#\s*(?:if|elif)\b[^\n]*!\s*OCCTSWIFT_KERNEL_HAS_(F\d{4})', re.MULTILINE)


def occt_version(root: str) -> str:
    text = open(os.path.join(root, 'Scripts', 'build-occt.sh'), encoding='utf-8').read()
    m = re.search(r'^OCCT_VERSION="([^"]+)"', text, re.MULTILINE)
    if not m:
        raise ValueError('Scripts/build-occt.sh has no OCCT_VERSION="..." line')
    return m.group(1)


def source_files(root: str):
    for top in SCAN_DIRS:
        for dirpath, _dirs, files in os.walk(os.path.join(root, top)):
            if '.build' in dirpath.split(os.sep):
                continue
            for name in files:
                if name.endswith(SCAN_EXT):
                    yield os.path.join(dirpath, name)


def check(root: str, version: str | None = None) -> list:
    out = []
    ledger = os.path.join(root, kernel_fixes.LEDGER)
    try:
        fixes = kernel_fixes.load(ledger)
        version = version or occt_version(root)
    except (OSError, ValueError) as e:
        return [str(e)]
    patches = kernel_fixes.patch_numbers(os.path.join(root, 'Scripts', 'patches'))
    out += ['ledger: ' + p for p in kernel_fixes.problems(fixes, patches)]
    by_id = {fx.id: fx for fx in fixes}
    everywhere = {
        fx.id for fx in fixes
        if all(kernel_fixes.is_present(fx, fl, version, patches) for fl in kernel_fixes.FLAVOURS)
    }
    for path in source_files(root):
        rel = os.path.relpath(path, root)
        try:
            text = open(path, encoding='utf-8').read()
        except (OSError, UnicodeDecodeError):
            continue
        for rx, what in ((TAG_RE, 'tag'), (MACRO_RE, 'macro'), (TRAIT_RE, 'test trait')):
            for m in rx.finditer(text):
                if m.group(1) not in by_id:
                    out.append('%s: %s names %s, which has no row in %s' % (rel, what, m.group(1), kernel_fixes.LEDGER))
        for m in GUARD_RE.finditer(text):
            if m.group(1) in everywhere:
                out.append('%s: retire this guard: %s is held by every shipping flavour at OCCT %s, so '
                           '`#if !OCCTSWIFT_KERNEL_HAS_%s` can never compile in. Delete the guard and its '
                           'tag, and keep the regression test that fails if it comes back.'
                           % (rel, m.group(1), version, m.group(1)))
        for m in TRAIT_RE.finditer(text):
            if m.group(1) in everywhere:
                out.append('%s: requiresKernelFix("%s") is always satisfied: every shipping flavour holds '
                           'it at OCCT %s. Drop the trait.' % (rel, m.group(1), version))
    return out


def self_test() -> list:
    fails = kernel_fixes.self_test()

    def case(name, files, expect_substr, version='8.0.2'):
        with tempfile.TemporaryDirectory() as root:
            for rel, body in files.items():
                p = os.path.join(root, rel)
                os.makedirs(os.path.dirname(p), exist_ok=True)
                with open(p, 'w') as f:
                    f.write(body)
            got = check(root, version)
        hit = any(expect_substr in g for g in got) if expect_substr else not got
        if not hit:
            fails.append('%s: wanted %r, got %r' % (name, expect_substr or 'clean', got))

    base = {
        'Scripts/build-occt.sh': 'OCCT_VERSION="8.0.2"\n',
        'Scripts/patches/0010-x-1.patch': '',
        'Scripts/kernel-fixes.tsv': 'F0010\tcrash-guard\tx\t-\t-\tnone\nF0019\tabsorbed\ty\t-\t8.0.2\tidentical\n',
    }

    def with_src(name, body):
        d = dict(base)
        d['Sources/OCCTBridge/src/a.mm'] = body
        return d

    case('a clean tree', base, '')
    case('a guard on a carried-only fix is fine, it still runs on vanilla',
         with_src('g', '// kernel-defect: F0010\n#if !OCCTSWIFT_KERNEL_HAS_F0010\nint x;\n#endif\n'), '')
    case('a guard on a fix every flavour holds must retire',
         with_src('g', '// kernel-defect: F0019\n#if !OCCTSWIFT_KERNEL_HAS_F0019\nint x;\n#endif\n'), 'retire this guard')
    case('an elif guard is also caught',
         with_src('g', '#if 1\n#elif !OCCTSWIFT_KERNEL_HAS_F0019\nint x;\n#endif\n'), 'retire this guard')
    case('a comment that mentions the macro is not a guard',
         with_src('g', '// see !OCCTSWIFT_KERNEL_HAS_F0019 in the ledger\nint x;\n'), '')
    case('a tag for an unknown fix', with_src('g', '// kernel-defect: F0999\n'), 'no row')
    case('a macro for an unknown fix', with_src('g', '#if OCCTSWIFT_KERNEL_HAS_F0999\n#endif\n'), 'no row')
    t = dict(base)
    t['Tests/OCCTX/a.swift'] = '@Test(.requiresKernelFix("F0019")) func t() {}\n'
    case('a test trait on a fix every flavour holds', t, 'Drop the trait')
    t['Tests/OCCTX/a.swift'] = '@Test(.requiresKernelFix("F0010")) func t() {}\n'
    case('a test trait on a carried-only fix is fine', t, '')
    p = dict(base)
    p['Scripts/patches/0030-y-2.patch'] = ''
    case('a patch with no ledger row', p, 'no ledger row')
    q = dict(base)
    q['Scripts/kernel-fixes.tsv'] = base['Scripts/kernel-fixes.tsv'] + 'F0031\tcrash-guard\tz\t-\t-\tnone\n'
    case('a row with no patch on disk', q, 'no Scripts/patches')
    case('vanilla at 8.1.0 absorbs a fix that is 8.1.0-only',
         {**base, 'Scripts/kernel-fixes.tsv': base['Scripts/kernel-fixes.tsv'].replace('F0010\tcrash-guard\tx\t-\t-\tnone', 'F0010\tcrash-guard\tx\t-\t8.1.0\tsame-code'),
          'Sources/OCCTBridge/src/a.mm': '#if !OCCTSWIFT_KERNEL_HAS_F0010\n#endif\n'}, 'retire this guard', version='8.1.0')
    return fails


def main() -> int:
    if '--self-test' in sys.argv:
        fails = self_test()
        print('check-kernel-fixes self-test: %s' % ('FAIL' if fails else 'ok'))
        for f in fails:
            print('  ' + f)
        return 1 if fails else 0
    found = check(ROOT)
    if found:
        print('check-kernel-fixes: %d finding(s):' % len(found))
        for f in found:
            print('  ' + f)
        print('\nokf/policies/kernel-fix-ledger.md has the rules.')
        return 1
    print('check-kernel-fixes: the ledger, Scripts/patches and every guard agree.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
