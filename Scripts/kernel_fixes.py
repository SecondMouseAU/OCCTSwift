#!/usr/bin/env python3
"""The kernel-fix ledger, as a library: parse Scripts/kernel-fixes.tsv and say which fixes a kernel holds.

A library, not a detector, in the style of occt_asset_identity.py: named with an underscore so the
scripts that need it can `import` it, it registers no gate, and `self_test()` returns the failures
for a caller to fold into its own `--self-test`.

Two scripts read it. `emit-kernel-fixes-header.py` writes OCCTKernelFixes.h into a kernel asset, and
`check-kernel-fixes.py` is the gate that keeps the ledger, the patch directory and the guards honest.
Both must agree on what "present" means, which is why it is here and in neither of them:

    a fix is PRESENT in a kernel when
      * upstream_in is set and is at or below the OCCT version the kernel is built from, or
      * the flavour is `carry` and the fix's patch file is in the patch directory the kernel applied.

The vanilla flavour therefore holds exactly what upstream has released, and the carry flavour holds
that plus every patch on disk.
"""
from __future__ import annotations

import hashlib
import os
import re
import sys
import tempfile
from dataclasses import dataclass

GROUPS = ('thread-safety', 'hardening', 'crash-guard', 'wrong-answer', 'ahead', 'absorbed')
RELATIONS = ('identical', 'same-code', 'different-form', 'different-behaviour', 'none')
FLAVOURS = ('carry', 'vanilla')
ID_RE = re.compile(r'^F(\d{4})$')
LEDGER = 'Scripts/kernel-fixes.tsv'


@dataclass(frozen=True)
class Fix:
    id: str
    group: str
    defect: str
    refs: tuple
    upstream_in: str  # '' when no released OCCT holds the fix
    relation: str

    @property
    def patch(self) -> str:
        return self.id[1:]


def parse_version(text: str) -> tuple:
    """'8.0.2' -> (8, 0, 2). Raises ValueError on anything else, so a typo is not read as a version."""
    if not re.fullmatch(r'\d+(\.\d+){1,3}', text):
        raise ValueError('not a dotted version: %r' % text)
    return tuple(int(p) for p in text.split('.'))


def load(path: str = LEDGER) -> list:
    """Parse the ledger. Raises ValueError, naming the line, on a malformed row."""
    fixes = []
    with open(path, encoding='utf-8') as f:
        for number, raw in enumerate(f, 1):
            line = raw.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            cols = line.split('\t')
            if len(cols) != 6:
                raise ValueError('%s:%d: %d columns, want 6' % (path, number, len(cols)))
            fid, group, defect, refs, up, rel = (c.strip() for c in cols)
            fixes.append(Fix(fid, group, defect, tuple(r for r in refs.split() if r != '-'),
                             '' if up == '-' else up, rel))
    return fixes


def patch_numbers(patches_dir: str) -> set:
    """The four-digit numbers of the .patch files in a directory."""
    out = set()
    if os.path.isdir(patches_dir):
        for name in os.listdir(patches_dir):
            m = re.match(r'(\d{4})-.*\.patch$', name)
            if m:
                out.add(m.group(1))
    return out


def is_present(fix: Fix, flavour: str, occt_version: str, patches: set) -> bool:
    if flavour not in FLAVOURS:
        raise ValueError('flavour must be one of %s, not %r' % (FLAVOURS, flavour))
    if fix.upstream_in and parse_version(fix.upstream_in) <= parse_version(occt_version):
        return True
    return flavour == 'carry' and fix.patch in patches


def problems(fixes: list, patches: set) -> list:
    """What is inconsistent between the ledger and the patch directory. Empty means consistent."""
    out = []
    seen = set()
    for fx in fixes:
        if not ID_RE.match(fx.id):
            out.append('%s: an id is F and four digits' % fx.id)
        if fx.id in seen:
            out.append('%s: appears twice' % fx.id)
        seen.add(fx.id)
        if fx.group not in GROUPS:
            out.append('%s: group %r is not one of %s' % (fx.id, fx.group, ', '.join(GROUPS)))
        if fx.relation not in RELATIONS:
            out.append('%s: relation %r is not one of %s' % (fx.id, fx.relation, ', '.join(RELATIONS)))
        if fx.upstream_in:
            try:
                parse_version(fx.upstream_in)
            except ValueError as e:
                out.append('%s: upstream_in: %s' % (fx.id, e))
        if bool(fx.upstream_in) != (fx.relation != 'none'):
            out.append('%s: relation %r with upstream_in %r (a fix upstream holds has a relation, and '
                       'one it does not hold has none)' % (fx.id, fx.relation, fx.upstream_in or '-'))
        if fx.group == 'absorbed':
            if not fx.upstream_in:
                out.append('%s: absorbed, but no upstream release holds it' % fx.id)
            if fx.patch in patches:
                out.append('%s: absorbed, so its patch file must be retired, and it is still on disk' % fx.id)
        else:
            if fx.patch not in patches:
                out.append('%s: group %s but no Scripts/patches/%s-*.patch exists (retire it: group '
                           'absorbed, with the release that holds the fix)' % (fx.id, fx.group, fx.patch))
    ids = {fx.patch for fx in fixes}
    for n in sorted(patches - ids):
        out.append('F%s: Scripts/patches/%s-*.patch has no ledger row' % (n, n))
    return out


def digest(path: str = LEDGER) -> str:
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()[:12]


def render_header(fixes: list, flavour: str, occt_version: str, patches: set, ledger_digest: str) -> str:
    rows = [(fx.id, is_present(fx, flavour, occt_version, patches)) for fx in sorted(fixes, key=lambda x: x.id)]
    lines = [
        '/* Generated by Scripts/emit-kernel-fixes-header.py from Scripts/kernel-fixes.tsv. Do not edit.',
        ' * Which kernel defects this OCCT build holds a fix for. See okf/policies/kernel-fix-ledger.md. */',
        '#ifndef OCCTSWIFT_KERNEL_FIXES_H',
        '#define OCCTSWIFT_KERNEL_FIXES_H',
        '',
        '#define OCCTSWIFT_KERNEL_FLAVOUR "%s"' % flavour,
        '#define OCCTSWIFT_KERNEL_OCCT_VERSION "%s"' % occt_version,
        '#define OCCTSWIFT_KERNEL_LEDGER_DIGEST "%s"' % ledger_digest,
        '',
    ]
    lines += ['#define OCCTSWIFT_KERNEL_HAS_%s %d' % (i, 1 if p else 0) for i, p in rows]
    lines += ['', '/* X(id, present): every ledger row, for the runtime probe. */',
              '#define OCCTSWIFT_KERNEL_FIX_LIST(X) \\']
    lines += ['    X(%s, %d)%s' % (i, 1 if p else 0, ' \\' if k < len(rows) - 1 else '')
              for k, (i, p) in enumerate(rows)]
    lines += ['', '#endif', '']
    return '\n'.join(lines)


def self_test() -> list:
    fails = []

    def check(name, cond):
        if not cond:
            fails.append(name)

    with tempfile.TemporaryDirectory() as d:
        led = os.path.join(d, 'k.tsv')
        with open(led, 'w') as f:
            f.write('# c\n\nF0010\tcrash-guard\tx\tOCCT#1\t-\tnone\n'
                    'F0019\tabsorbed\ty\tOCCT#2\t8.0.2\tidentical\n'
                    'F0020\twrong-answer\tz\t-\t8.1.0\tsame-code\n')
        fixes = load(led)
        check('three rows parsed, comments skipped', len(fixes) == 3)
        check('refs split, - is none', fixes[0].refs == ('OCCT#1',) and fixes[2].refs == ())
        patches = {'0010', '0020'}
        check('carry holds the patched fix', is_present(fixes[0], 'carry', '8.0.2', patches))
        check('vanilla does not hold a carried-only fix', not is_present(fixes[0], 'vanilla', '8.0.2', patches))
        check('both hold what 8.0.2 absorbed', is_present(fixes[1], 'vanilla', '8.0.2', set())
              and is_present(fixes[1], 'carry', '8.0.2', set()))
        check('a fix in 8.1.0 is not in 8.0.2 for vanilla', not is_present(fixes[2], 'vanilla', '8.0.2', patches))
        check('but is in 8.1.0 for vanilla', is_present(fixes[2], 'vanilla', '8.1.0', patches))
        check('consistent set has no problems', problems(fixes, patches) == [])
        check('a patch with no row is a problem', any('no ledger row' in p for p in problems(fixes, patches | {'0030'})))
        check('a row whose patch is gone is a problem', any('no Scripts/patches' in p for p in problems(fixes, {'0010'})))
        check('an absorbed row with its file still on disk is a problem',
              any('still on disk' in p for p in problems(fixes, patches | {'0019'})))
        check('8.0.10 sorts above 8.0.9, not below', parse_version('8.0.10') > parse_version('8.0.9'))
        check('a relation with no release is a problem', any('relation' in p for p in problems(
            [Fix('F0010', 'crash-guard', 'x', (), '', 'identical')], {'0010'})))
        try:
            parse_version('8.x')
            check('a typo in a version raises', False)
        except ValueError:
            pass
        text = render_header(fixes, 'vanilla', '8.0.2', patches, 'abc')
        check('header marks the absorbed fix present', 'OCCTSWIFT_KERNEL_HAS_F0019 1' in text)
        check('header marks the carried fix absent in vanilla', 'OCCTSWIFT_KERNEL_HAS_F0010 0' in text)
        check('header names the flavour', '#define OCCTSWIFT_KERNEL_FLAVOUR "vanilla"' in text)
        check('the X list has no trailing continuation', not text.split('#endif')[0].rstrip().endswith('\\'))
    return fails


if __name__ == '__main__':
    failures = self_test()
    print('kernel_fixes self-test: %s' % ('FAIL: ' + '; '.join(failures) if failures else 'ok'))
    sys.exit(1 if failures else 0)
