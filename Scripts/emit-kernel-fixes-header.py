#!/usr/bin/env python3
"""Write OCCTKernelFixes.h: which kernel defects a given OCCT build holds a fix for.

Called by Scripts/build-occt.sh and Scripts/build-occt-wasm.sh as they stage a kernel's headers, so
each kernel asset states what it holds and the bridge compiles against that statement:

    python3 Scripts/emit-kernel-fixes-header.py --flavour carry --occt-version 8.0.2 \\
        --patches-dir Scripts/patches --out occt-headers/OCCTKernelFixes.h
    python3 Scripts/emit-kernel-fixes-header.py --flavour vanilla --occt-version 8.0.2 --out ...

`carry` reads the patch directory it was told about; `vanilla` takes none, because a vanilla kernel
applies none. The ledger and what "present" means are in Scripts/kernel_fixes.py. A build is refused
(exit 1) when the ledger and the patch directory disagree, so a kernel is never stamped with a header
that was not true of it.
"""
from __future__ import annotations

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kernel_fixes  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--flavour', required=True, choices=kernel_fixes.FLAVOURS)
    ap.add_argument('--occt-version', required=True)
    ap.add_argument('--patches-dir', help='the directory the build applied (carry only)')
    ap.add_argument('--ledger', default=os.path.join(os.path.dirname(HERE), kernel_fixes.LEDGER))
    ap.add_argument('--out', required=True)
    ap.add_argument('--self-test', action='store_true')
    a = ap.parse_args()
    try:
        kernel_fixes.parse_version(a.occt_version)
        fixes = kernel_fixes.load(a.ledger)
    except (OSError, ValueError) as e:
        print('emit-kernel-fixes-header: %s' % e, file=sys.stderr)
        return 1
    if a.flavour == 'carry' and not a.patches_dir:
        print('emit-kernel-fixes-header: --flavour carry needs --patches-dir', file=sys.stderr)
        return 1
    patches = kernel_fixes.patch_numbers(a.patches_dir) if a.flavour == 'carry' else set()
    if a.flavour == 'carry':
        bad = kernel_fixes.problems(fixes, patches)
        if bad:
            print('emit-kernel-fixes-header: the ledger and %s disagree, so no header is written:' % a.patches_dir,
                  file=sys.stderr)
            for b in bad:
                print('  ' + b, file=sys.stderr)
            return 1
    text = kernel_fixes.render_header(fixes, a.flavour, a.occt_version, patches, kernel_fixes.digest(a.ledger))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, 'w', encoding='utf-8') as f:
        f.write(text)
    held = sum(1 for fx in fixes if kernel_fixes.is_present(fx, a.flavour, a.occt_version, patches))
    print('emit-kernel-fixes-header: %s flavour on OCCT %s holds %d of %d ledger fixes -> %s'
          % (a.flavour, a.occt_version, held, len(fixes), a.out))
    return 0


if __name__ == '__main__':
    if '--self-test' in sys.argv:
        fails = kernel_fixes.self_test()
        print('emit-kernel-fixes-header self-test: %s' % ('FAIL: ' + '; '.join(fails) if fails else 'ok'))
        sys.exit(1 if fails else 0)
    sys.exit(main())
