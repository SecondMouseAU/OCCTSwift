#!/usr/bin/env python3
"""#1026 and #1035 guard-removal matrix for check-null-handle-guards.py's third walk.

One walk, so one matrix: #1035 generalised #1026's builder rule into the SHAPE_DEREF_* table
and added the outward walk through transparent casts, and rows R8-R13 cover both.

Each row removes one mechanism from a COPY of the script, runs --self-test, and reports how many
cases still come back correct. A row that drops nothing is a decorative guard, or a fixture that
proves less than its name says.

Two rows came back full marks on their first run and both were real findings, not noise:

  * the fixpoint row (R4), because the two guard helpers in fixture SG are in definition order, so
    one pass already recognises both. Fixture SI inverts the order, which is the only thing that
    separates them, and the conclusion is that the fixpoint is insurance against a reorder rather
    than a live requirement. The script's own docstring says so.
  * the receiver-type row (R9), which was silently a NO-OP: it still targeted a two-line expression
    that a later tidy had collapsed to one, so `BASE.replace(...)` changed nothing and the row was
    measuring the unmodified script. The `assert text != BASE` below is what catches that, and it
    was missing when R9 first ran. A removal matrix needs its own guard against removing nothing.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

SRC = Path(__file__).resolve().parents[2] / 'check-null-handle-guards.py'
TMP = Path(tempfile.mkdtemp()) / '_gate_copy.py'

BASE = SRC.read_text()


def rows():
    yield 'baseline (no removal)', BASE

    # R1: any member call after the field counts as a use, not only SHAPE_HAZARDS.
    yield ('R1 hazard allowlist: any .X() counts as a use',
           BASE.replace("SHAPE_HAZARD_CALL = re.compile(r'\\s*\\.\\s*(' + '|'.join(SHAPE_HAZARDS) + r')\\s*\\(')",
                        "SHAPE_HAZARD_CALL = re.compile(r'\\s*\\.\\s*(\\w+)\\s*\\(')"))

    # R2: drop the TopoDS_Shape alias half of shape_events.
    m = re.search(r"(    for h, bound in alias\.items\(\):\n(?:.*\n)*?)    ev\.sort\(\)\n    return ev",
                  BASE)
    assert m, 'alias block not found'
    yield ('R2 alias half of shape_events removed',
           BASE.replace(m.group(1), '', 1))

    # R3: a call to a recognised guarding helper no longer counts as a guard.
    yield ('R3 helper call no longer counts as a guard',
           BASE.replace("""            call = enclosing_call(body, m.start())
            if call in shape_helpers:
                ev.append((m.start(), 'guard', call[0]))""",
                        """            call = enclosing_call(body, m.start())
            if False:
                ev.append((m.start(), 'guard', call[0]))"""))

    # R4: shape_guarding_helpers runs one pass instead of a fixpoint.
    yield ('R4 helper detection is one pass, not a fixpoint',
           BASE.replace("""        if not grew:
            return guards


def shape_hazard_sites""", """        return guards


def shape_hazard_sites"""))

    # R5: only OCCTShapeRef is a topology wrapper.
    yield ('R5 SHAPE_WRAPPERS narrowed to OCCTShapeRef',
           BASE.replace("""SHAPE_WRAPPERS = {
    'OCCTShapeRef': 'shape',
    'OCCTWireRef': 'wire',
    'OCCTEdgeRef': 'edge',
    'OCCTFaceRef': 'face',
}""", """SHAPE_WRAPPERS = {
    'OCCTShapeRef': 'shape',
}"""))

    # R6: a use is reported regardless of any guard before it.
    yield ('R6 guard-before-use ordering ignored',
           BASE.replace("""                if first is None or any(k == 'guard' and p < first for p, k, _ in ev):
                    continue""",
                        """                if first is None:
                    continue"""))

    # R8: the measured-dereferencer table stops counting as a use at all. #1035 generalised
    # #1026's builder rule into this, so this row now covers the builder too.
    yield ('R8 SHAPE_DEREF_* no longer counts as a use',
           BASE.replace("""                    deref = deref_call(body, m.start(), decls)""",
                        """                    deref = None""").replace(
               """                deref = deref_call(body, m.start(), decls)""",
               """                deref = None"""))

    # R9: keyed on the method name alone, ignoring the receiver's declared type. `Add` is one of
    # OCCT's most overloaded names and fixture SK is the BRepBuilderAPI_Sewing::Add that proves it.
    yield ('R9 receiver rule keyed on the method name, not the receiver type',
           BASE.replace(
               """        if recv and name in SHAPE_DEREF_RECEIVERS.get(decls.get(recv.group(1), ''), ()):
            return f'{decls[recv.group(1)]}::{name}'""",
               """        if recv and any(name in ms for ms in SHAPE_DEREF_RECEIVERS.values()):
            return name"""))

    # R10 (#1035): no outward walk. Stopping at the innermost call is what every census before
    # #1035 did, and it is why thirty `Type local(TopoDS::Edge(x->shape))` sites were invisible.
    yield ('R10 enclosing_calls stops at the innermost call',
           BASE.replace('def enclosing_calls(body, pos, limit=4):',
                        'def enclosing_calls(body, pos, limit=1):'))

    # R11 (#1035): the TopoDS:: casts are treated as opaque, so the walk stops at the cast.
    yield ('R11 TopoDS:: casts no longer transparent',
           BASE.replace("""        if qualifier == 'TopoDS' and name in SHAPE_TRANSPARENT_CASTS:
            continue                          # transparent: keep looking outward""",
                        """        if False:
            continue"""))

    # R12 (#1035): the qualifier is ignored, so any `Curve(...)`/`Surface(...)` counts. This is
    # the false-positive direction: BRepAdaptor_Curve::Curve and a dozen others share the names.
    yield ('R12 qualified rule ignores the qualifier',
           BASE.replace("""        if qualifier and name in SHAPE_DEREF_QUALIFIED.get(qualifier, ()):
            return f'{qualifier}::{name}'""",
                        """        if any(name in ns for ns in SHAPE_DEREF_QUALIFIED.values()):
            return f'{qualifier}::{name}'"""))

    # R13 (#1035): the `Type local(...)` constructor spelling is dropped, leaving only the bare
    # temporary `Type(...)`. Every real site in this tree uses the named-local form.
    yield ('R13 named-local constructor spelling dropped',
           BASE.replace("""        before = re.search(r'(\\w+)\\s+$', body[:namestart])
        if before and before.group(1) in SHAPE_DEREF_CTORS:
            return before.group(1)""",
                        """        pass"""))

    # R7: the whole third walk is unplugged from all_sites and direct_walk.
    s = BASE.replace("""            + shape_hazard_sites(parsed, shape_helpers))""",
                     """            )""")
    s = s.replace("""    return shape_hazard_sites(parsed, shape_guarding_helpers(parsed))""",
                  """    return []""")
    yield 'R7 third walk unplugged entirely', s


print(f'{"row":<52} {"cases correct":>14}  failing')
for label, text in rows():
    assert text != BASE or label.startswith('baseline'), f'{label}: no-op patch, it removes nothing'
    TMP.write_text(text)
    r = subprocess.run([sys.executable, str(TMP), '--self-test'],
                       capture_output=True, text=True)
    score = 'CRASH'
    for line in r.stdout.splitlines():
        if line.endswith('cases correct'):
            score = line.strip()
    bad = [ln.strip() for ln in r.stdout.splitlines()
           if ln.strip().startswith(('MISS', 'FALSE'))]
    names = ', '.join(b.split(':')[0].split(', ')[-1][:34] for b in bad) or '-'
    print(f'{label:<52} {score:>14}  {names}')
    if r.returncode not in (0, 1):
        print(f'    stderr: {r.stderr.strip()[:200]}')
