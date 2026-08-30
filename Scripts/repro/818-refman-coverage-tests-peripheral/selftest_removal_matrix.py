#!/usr/bin/env python3
r"""#818: proves `derive_lane.py`'s own detection mechanisms are load-bearing on the REAL tree.

`refman_census.py --self-test` proves `classify()`'s dispatch logic (tested / tested-elsewhere /
under / fixed / filed) is not decoration, using synthetic fixtures. This file proves the LOWER
layer -- the four-hop bridge/Swift call-graph trace `derive_lane.py` runs to produce the per-class
`class_hits` signal in the first place -- is not decoration either, against the real 136-class
population, per `okf/policies/prove-the-test-fails.md`'s instruction that a removal matrix proves
guards, not fixtures. Six mechanisms, six real classes this pass found DURING its own investigation
that specifically needed each one (see `derive_lane.py`'s module docstring for the narrative):

  bridge-propagation      StdSelect_BRepOwner needs OCCTSelectorCollectResults's OWN reach
                          propagated up through the OCCTSelectorPick that calls it.
  occt-lowercase-helper   StlAPI_Reader is used only inside `occtImportSTLImpl`, a lowercase
                          internal helper; an OCCT-only-prefixed function-name pattern misses it.
  swift-propagation       ChFi3d is reached only via AAG's PRIVATE buildGraph(), called from the
                          PUBLIC init(shape:) every test actually calls.
  init-handling           AIS_TextLabel is reached only via Annotation's `init` overloads
                          (AngleDimension/DiameterDimension/LengthDimension/RadiusDimension);
                          `init` has no name of its own to match on func/var regexes.
  var-handling            Graphic3d_PolygonOffset is reached only via `ZLayerSettings.polygonOffset`,
                          a computed `var`, not a `func`.
  type-cooccurrence-gate  Plate_Plate (see refman_census.py's MANUAL_OVERRIDES) is the false
                          positive this gate exists to catch: without it, `OCCTStressTests`'
                          unrelated `builder.isDone` (on FilletBuilder/ChamferBuilder) would credit
                          `Plate_Plate` as tested by OCCTStressTests.

Each row disables ONE mechanism in a fresh computation (never a fixture -- this file imports
`derive_lane.py` and monkeypatches its regexes/functions, so the population and every other
mechanism stay exactly as they are on `main`) and reports whether that lane class's `class_hits`
answer actually changes. A row that reports NO CHANGE for its named class is decoration and needs
rewriting, per the policy this file follows.

Run: python3 Scripts/repro/818-refman-coverage-tests-peripheral/selftest_removal_matrix.py
"""

from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import derive_lane  # noqa: E402


def _baseline_hits(cls: str) -> set[str]:
    lane = derive_lane.compute()
    return lane.class_hits.get(cls, set())


def _row(name: str, target_class: str, disable, restore) -> tuple[str, bool, set[str], set[str]]:
    before = _baseline_hits(target_class)
    disable()
    try:
        after = _baseline_hits(target_class)
    finally:
        restore()
    changed = before != after
    return (name, changed, before, after)


def main() -> int:
    rows = []

    # 1. bridge-propagation: disable the fixpoint, keep only direct (round-0) reach.
    def disable_bridge_prop():
        derive_lane._ORIG_propagate_bridge_reach = derive_lane.propagate_bridge_reach

        def no_prop(graph, wrapped):
            return {name: (toks & wrapped) for name, (toks, _called) in graph.items()}

        derive_lane.propagate_bridge_reach = no_prop

    def restore_bridge_prop():
        derive_lane.propagate_bridge_reach = derive_lane._ORIG_propagate_bridge_reach

    rows.append(_row("bridge-propagation", "StdSelect_BRepOwner",
                      disable_bridge_prop, restore_bridge_prop))

    # 2. occt-lowercase-helper: bridge function name pattern becomes OCCT-only (uppercase).
    def disable_lowercase():
        derive_lane._ORIG_BFUNC_SIG_RE = derive_lane._BFUNC_SIG_RE
        derive_lane._BFUNC_SIG_RE = re.compile(
            r"^\s*(?:[A-Za-z_][A-Za-z0-9_ \*<>,:&]*?)\b(OCCT[A-Za-z0-9_]*)\s*\([^;{}]*\)\s*\n?\s*\{",
            re.M)

    def restore_lowercase():
        derive_lane._BFUNC_SIG_RE = derive_lane._ORIG_BFUNC_SIG_RE

    rows.append(_row("occt-lowercase-helper", "StlAPI_Reader",
                      disable_lowercase, restore_lowercase))

    # 3. swift-propagation: disable the same-file fixpoint for Swift decls.
    def disable_swift_prop():
        derive_lane._ORIG_propagate_swift_calls = derive_lane.propagate_swift_calls
        derive_lane.propagate_swift_calls = lambda decl_calls: decl_calls

    def restore_swift_prop():
        derive_lane.propagate_swift_calls = derive_lane._ORIG_propagate_swift_calls

    rows.append(_row("swift-propagation", "ChFi3d", disable_swift_prop, restore_swift_prop))

    # 4. init-handling: disable the init regex entirely (matches nothing).
    def disable_init():
        derive_lane._ORIG_SWIFT_INIT_RE = derive_lane._SWIFT_INIT_RE
        derive_lane._SWIFT_INIT_RE = re.compile(r"(?!)")  # matches nothing

    def restore_init():
        derive_lane._SWIFT_INIT_RE = derive_lane._ORIG_SWIFT_INIT_RE

    rows.append(_row("init-handling", "AIS_TextLabel", disable_init, restore_init))

    # 5. var-handling: disable the var regex entirely.
    def disable_var():
        derive_lane._ORIG_SWIFT_VAR_RE = derive_lane._SWIFT_VAR_RE
        derive_lane._SWIFT_VAR_RE = re.compile(r"(?!)")

    def restore_var():
        derive_lane._SWIFT_VAR_RE = derive_lane._ORIG_SWIFT_VAR_RE

    rows.append(_row("var-handling", "Graphic3d_PolygonOffset", disable_var, restore_var))

    # 6. type-cooccurrence-gate: make the gate a no-op (always True once the call-shape matches).
    def disable_gate():
        derive_lane._ORIG_decl_hit = derive_lane._decl_hit

        def no_gate(kind, name, calls, props, idents, file_types, fname):
            if kind == "func":
                return name in calls
            if kind == "init":
                return name in calls
            if kind == "var":
                return name in props or name in calls
            return False

        derive_lane._decl_hit = no_gate

    def restore_gate():
        derive_lane._decl_hit = derive_lane._ORIG_decl_hit

    rows.append(_row("type-cooccurrence-gate", "Plate_Plate", disable_gate, restore_gate))

    print(f"{'mechanism':<24}{'target class':<28}{'load-bearing?':<15}{'before':<45}{'after'}")
    all_load_bearing = True
    for name, changed, before, after in rows:
        status = "[load-bearing]" if changed else "[DECORATION]"
        if not changed:
            all_load_bearing = False
        target = {
            "bridge-propagation": "StdSelect_BRepOwner",
            "occt-lowercase-helper": "StlAPI_Reader",
            "swift-propagation": "ChFi3d",
            "init-handling": "AIS_TextLabel",
            "var-handling": "Graphic3d_PolygonOffset",
            "type-cooccurrence-gate": "Plate_Plate",
        }[name]
        print(f"{name:<24}{target:<28}{status:<15}{sorted(before)!s:<45}{sorted(after)!s}")

    print()
    if all_load_bearing:
        print(f"All {len(rows)}/{len(rows)} mechanisms proved load-bearing: each named class's "
              "class_hits answer changed when its own mechanism was disabled.")
        return 0
    print("At least one mechanism reported DECORATION: it changed nothing when disabled, which "
          "means the case chosen does not actually exercise it, or the mechanism itself is dead "
          "code. Fix the case or the mechanism before trusting the census.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
