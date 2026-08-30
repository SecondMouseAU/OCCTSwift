#!/usr/bin/env python3
"""#815: the proof that `refman_census.py --self-test`'s cases are load-bearing, not decoration.

Same purpose as `Scripts/repro/811-refman-coverage-features/selftest_removal_matrix.py`: a
`--self-test` that reports "all clear" because a case happens to pass through the WRONG code path
is indistinguishable, from its own output, from one that is genuinely exercising the shape it
claims to. This switches off each accepting shape `member_test_status`/`_call_pattern` recognise
(instance call, static call, instance property, static property, initializer) in turn and shows how
many of `refman_census.py`'s own `SELF_TEST_CASES` fail without it. A shape whose case still passes
with the shape disabled was passing for the wrong reason.

    python3 Scripts/repro/815-refman-coverage-tests-geometry/selftest_removal_matrix.py

Exits 1 if any shape turns out NOT load-bearing (every case that should need it still passes
without it), 0 if every shape is proven load-bearing. This script does not gate CI; it is the
one-time (and re-run-when-touched) proof that the detector's own self-test is not decoration.
"""

from __future__ import annotations

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import derive_lane as dl  # noqa: E402
import refman_census as rc  # noqa: E402


def _pattern_disabling(shape: str):
    """A drop-in replacement for `dl._call_pattern` with one accepting shape switched off."""
    real = dl._call_pattern

    def patched(type_name, member_name, kind, is_static):
        esc = re.escape(member_name)
        if kind == "init":
            if shape == "init":
                return re.compile(r"(?!)")  # matches nothing
            return real(type_name, member_name, kind, is_static)
        if kind == "func":
            if is_static and shape == "static-func":
                return re.compile(r"(?!)")
            if not is_static and shape == "instance-func":
                return re.compile(r"(?!)")
            return real(type_name, member_name, kind, is_static)
        # var
        if is_static and shape == "static-var":
            return re.compile(r"(?!)")
        if not is_static and shape == "instance-var":
            return re.compile(r"(?!)")
        return real(type_name, member_name, kind, is_static)

    return patched


SHAPES = ["instance-var", "instance-func", "static-func", "static-var", "init"]


def run_cases_with(pattern_fn) -> tuple[int, int]:
    """(passed, total) over `refman_census.py`'s own SELF_TEST_CASES, using a patched
    `_call_pattern`. `dl._call_pattern`'s own cache is cleared first: it is keyed by
    (type, name, is_func) with no shape parameter, so a cached compiled pattern from a PRIOR call
    (real or patched) would silently mask the patch."""
    dl.CALL_RE_CACHE.clear()
    original = dl._call_pattern
    dl._call_pattern = pattern_fn
    try:
        passed = 0
        for type_name, member, text, expected, _why in rc.SELF_TEST_CASES:
            got = dl.member_test_status(type_name, member, text, {})
            if got is expected:
                passed += 1
        return passed, len(rc.SELF_TEST_CASES)
    finally:
        dl._call_pattern = original
        dl.CALL_RE_CACHE.clear()


def main() -> int:
    baseline_passed, total = run_cases_with(dl._call_pattern)
    print(f"baseline: {baseline_passed}/{total} cases pass unmodified")
    if baseline_passed != total:
        print("baseline itself is not clean; fix refman_census.py's SELF_TEST_CASES first")
        return 1

    all_load_bearing = True
    print()
    for shape in SHAPES:
        passed, _ = run_cases_with(_pattern_disabling(shape))
        failed = total - passed
        tag = "load-bearing" if failed > 0 else "NOT LOAD-BEARING (decoration)"
        print(f"  {shape:<14} disabled -> {failed}/{total} cases fail  [{tag}]")
        if failed == 0:
            all_load_bearing = False

    print()
    # The two VALVES (genericity blocklist, overload fanout) are load-bearing by a different
    # mechanism: disabling them doesn't change `_call_pattern`, it changes whether
    # `member_test_status` consults it at all. Proved the same way #811 proves its own valves: by
    # running the case WITH the valve's condition true and confirming the answer flips.
    print("valves (proved by construction, not by disabling code):")
    ty, member, text = rc.GENERIC_TEST_CASE
    with_valve = dl.member_test_status(ty, member, text, {})
    # simulate "valve absent" by asking the same question with a name NOT on the blocklist
    member_no_valve = dict(member, name="notGenericAtAll")
    text_no_valve = text.replace("value", "notGenericAtAll")
    without_valve = dl.member_test_status(ty, member_no_valve, text_no_valve, {})
    ok = with_valve is None and without_valve is True
    print(f"  {'load-bearing' if ok else 'NOT LOAD-BEARING':<24} GENERIC_MEMBER_NAMES: "
          f"generic name -> {with_valve}, otherwise-identical non-generic name -> {without_valve}")
    if not ok:
        all_load_bearing = False

    ty1, ty2, member, text1, text2 = rc.FANOUT_TEST_CASE
    combined = text1 + "\n" + text2
    over_threshold = dl.member_test_status(ty1, member, combined,
                                           {"shared": dl.OVERLOAD_FANOUT + 1})
    under_threshold = dl.member_test_status(ty1, member, combined, {"shared": 1})
    ok = over_threshold is None and under_threshold is True
    print(f"  {'load-bearing' if ok else 'NOT LOAD-BEARING':<24} OVERLOAD_FANOUT: "
          f"over threshold -> {over_threshold}, under threshold -> {under_threshold}")
    if not ok:
        all_load_bearing = False

    print()
    if all_load_bearing:
        print("every shape and valve is load-bearing")
        return 0
    print("at least one shape/valve is decoration: a case passes for the wrong reason")
    return 1


if __name__ == "__main__":
    sys.exit(main())
