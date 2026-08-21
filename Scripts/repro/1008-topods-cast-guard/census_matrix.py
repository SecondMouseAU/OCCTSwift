#!/usr/bin/env python3
"""Guard-removal matrix for shapetype_census.py's own --self-test.

Each row removes one mechanism from a copy and reports how many of the 12 cases still come back
correct. A row that leaves 12/12 is a decorative fixture or a decorative guard.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

SRC = Path(__file__).with_name('shapetype_census.py')
TMP = Path(tempfile.mkdtemp()) / '_census_copy.py'
BASE = SRC.read_text()


def rows():
    yield 'baseline (no removal)', BASE

    # R1: the original criterion, any IsNull() anywhere in the body counts as a guard.
    yield ('R1 original criterion: any IsNull() in the body is a guard',
           BASE.replace("""    events.sort()
    first_use = next((p for p, k in events if k == 'use'), None)
    if first_use is None:
        return None
    if any(k == 'guard' and p < first_use for p, k in events):
        return None
    return 'unguarded'""",
                        """    events.sort()
    first_use = next((p for p, k in events if k == 'use'), None)
    if first_use is None:
        return None
    if 'IsNull()' in body:
        return None
    return 'unguarded'"""))

    # R7: drop the binding lower bound, so a pre-binding IsNull() on a local counts as a guard.
    yield ('R7 alias binding position ignored (a pre-binding IsNull() counts)',
           BASE.replace("""            if m.start() < bound:
                continue
""", ""))

    # R2: drop the local copy / reference alias tracking.
    yield ('R2 local copy and reference alias tracking removed',
           BASE.replace("""    for m in re.finditer(r'\\b(\\w+)\\s*=\\s*([^;]*);', body):""",
                        """    for m in re.finditer(r'(?!x)x', body):"""))

    # R3: stop blanking string literals in strip_comments, which is what really uncovers
    # a function defined with `extern "C"` on its own line.
    yield ('R3 string literals no longer blanked by strip_comments',
           BASE.replace("""            out.append(' ' * (min(j, n - 1) + 1 - i))
            i = j + 1""",
                        """            out.append(text[i:j + 1])
            i = j + 1"""))

    # R4: drop the two named guard helpers.
    yield ('R4 the two named bridge guard helpers no longer count',
           BASE.replace("GUARD_HELPERS = ('occtShapeIsPresent', 'occtShapeIsType')",
                        "GUARD_HELPERS = ()"))

    # R5: only OCCTShapeRef is a wrapper.
    yield ('R5 WRAPPERS narrowed to OCCTShapeRef',
           BASE.replace("""WRAPPERS = {'OCCTShapeRef': 'shape', 'OCCTWireRef': 'wire',
            'OCCTEdgeRef': 'edge', 'OCCTFaceRef': 'face'}""",
                        """WRAPPERS = {'OCCTShapeRef': 'shape'}"""))

    # R6: the guard/use ORDER is ignored, any guard anywhere on the same argument clears it.
    yield ('R6 guard-before-use ordering ignored (guard on the arg anywhere clears it)',
           BASE.replace("""    if any(k == 'guard' and p < first_use for p, k in events):
        return None""",
                        """    if any(k == 'guard' for p, k in events):
        return None"""))


print(f'{"row":<62} {"cases correct":>14}  failing')
for label, text in rows():
    assert text != BASE or label.startswith('baseline'), f'{label}: no-op patch'
    TMP.write_text(text)
    r = subprocess.run([sys.executable, str(TMP), '--self-test'], capture_output=True, text=True)
    score = 'CRASH'
    for line in r.stdout.splitlines():
        if line.endswith('cases correct'):
            score = line.strip()
    bad = [ln.strip() for ln in r.stdout.splitlines()
           if ln.strip().startswith(('MISS', 'FALSE'))]
    names = ', '.join(b.split(',')[1].strip()[:36] for b in bad) or '-'
    print(f'{label:<62} {score:>14}  {names}')
    if r.returncode not in (0, 1):
        print(f'    stderr: {r.stderr.strip()[:160]}')
