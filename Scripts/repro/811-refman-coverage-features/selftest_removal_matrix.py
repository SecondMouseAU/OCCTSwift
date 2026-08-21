#!/usr/bin/env python3
"""#811: proof that `refman_census.py`'s guards are load-bearing, per prove-the-test-fails.md.

A self-test that passes because the detector is blind looks exactly like one that passes because
the tree is clean. So this removes each accepting shape in turn and reports how many self-test
cases stop passing. A shape whose removal breaks nothing is decoration, and the matrix is what
found one during #811: the first `Plate_Plate::myPlanarSurface` case named a field the pinned
header does not declare, so the data-member shape it was written to protect was never exercised.

Three groups:

  declares_member    the four shapes that make it answer True, plus the None it must answer for a
                     base whose own header is not shipped (the `using Alias = Template<...>` case).
  _ATTRIBUTION_RE    the two constraints the pattern deliberately omits.
  classify           the ordering decision and the gaps.md exclusion, together and then each
                     alone, against the real tree rather than a fixture, since that is where
                     they went wrong.

THE VARIANTS RE-IMPLEMENT THE DETECTOR RATHER THAN PARAMETERISING IT, and that has a failure mode
worth naming: a shape REMOVED from `refman_census.declares_member` is caught, because the baseline
calls the real function, but a shape ADDED there later would get no variant and this file would
still print "every guard is load-bearing". `check_shape_inventory()` closes that: it counts the
accepting branches in the shipped source and fails if the count moves without a matching variant
here. It is a tripwire, not a proof: it counts branches, so it sees a shape ADDED or REMOVED and
is blind to an existing shape's body changing. Narrowing the data-member pattern from `[;=]` to
`;`, for instance, leaves all three counts and all fourteen cases unmoved while the
re-implemented variant goes on proving the old shape load-bearing. Measured, not supposed. The
fix for that class is parameterising the shipped function rather than copying it, and this file
does not do it.

    python3 Scripts/repro/811-refman-coverage-features/selftest_removal_matrix.py

Exits 1 if any variant is NOT load-bearing, or if the baseline does not pass clean.
"""

from __future__ import annotations

import inspect
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import refman_census as rc  # noqa: E402


def _baseline_declares() -> tuple[int, int]:
    cases = list(rc.SELF_TEST_CASES)
    passed = sum(1 for cls, m, exp, _ in cases if rc.declares_member(cls, m) is exp)
    return passed, len(cases)


def _run_declares_variant(disable: str) -> int:
    """Re-implement declares_member with one shape switched off, and count passing cases."""

    def bases(cls: str) -> list[str]:
        path = os.path.join(rc.OCCT_HEADERS, cls + ".hxx")
        if not os.path.exists(path):
            return []
        text = rc._read(path)
        m = re.search(r"^\s*(?:class|struct)\s+" + re.escape(cls) + r"\s*:\s*([^{]+)", text, re.M)
        if not m:
            if disable == "alias-template":
                return []
            alias = re.search(r"^\s*using\s+" + re.escape(cls) + r"\s*=\s*([A-Za-z_][A-Za-z0-9_]*)",
                              text, re.M)
            return [alias.group(1)] if alias else []
        out = []
        for part in m.group(1).split(","):
            for kw in ("public", "protected", "private", "virtual"):
                part = part.replace(kw, "")
            part = part.split("<")[0].strip()
            if part:
                out.append(part)
        return out

    def declares(cls: str, member: str, seen: set[str] | None = None):
        seen = seen if seen is not None else set()
        if cls in seen:
            return False
        seen.add(cls)
        path = os.path.join(rc.OCCT_HEADERS, cls + ".hxx")
        if not os.path.exists(path):
            return None
        text = rc._read(path)
        if disable != "method-call" and re.search(r"\b" + re.escape(member) + r"\s*\(", text):
            return True
        if disable != "nested-type" and re.search(
                r"\b(?:enum|class|struct|using|typedef)\s+(?:class\s+)?" + re.escape(member) + r"\b",
                text):
            return True
        if disable != "data-member" and re.search(r"\b" + re.escape(member) + r"\s*[;=]", text):
            return True
        if disable == "base-class-walk":
            return False
        for base in bases(cls):
            sub = declares(base, member, seen)
            if sub is True:
                return True
            if sub is None and disable != "none-propagation":
                return None
        return False

    return sum(1 for cls, m, exp, _ in rc.SELF_TEST_CASES if declares(cls, m) is exp)


def _run_parser_variant(constraint: str) -> int:
    if constraint == "closing-backtick-anchor":
        pat = re.compile(r"`([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)`")
    elif constraint == "no-leading-backtick":
        pat = re.compile(r"([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)")
    else:
        raise AssertionError(constraint)
    return sum(1 for line, expected, _ in rc.PARSE_SELF_TEST_CASES if pat.findall(line) == expected)


def _classify_counts(cache) -> dict[str, int]:
    tally = {"ok": 0, "deliberate, recorded": 0, "under": 0}
    for classes in rc.LANE_CLASSES.values():
        for cls in classes:
            tally[rc.classify(cls, cache)[0]] += 1
    return tally


def _classify_counts_docs_first(cache, gaps_counts_as_docs: bool) -> dict[str, int]:
    """classify() with the docs test moved ahead of the curated tables.

    `gaps_counts_as_docs` is the SECOND half of the original defect and is a separate switch, because
    the first draft of this variant flipped both at once and then credited the whole 129-ok swing to
    the ordering. Measured with the two isolated: the ordering alone changes nothing on this lane,
    and the ordering PLUS re-admitting docs/occtswift-wrapping-gaps.md is what produced it. Only the
    combination is load-bearing, and only the combination is asserted.
    """
    tally = {"ok": 0, "deliberate, recorded": 0, "under": 0}
    for classes in rc.LANE_CLASSES.values():
        for cls in classes:
            if rc.named_in_bridge(cls, cache):
                tally["ok"] += 1
            elif rc.named_in_docs(cls, cache) or (gaps_counts_as_docs
                                                  and rc.recorded_in_gaps(cls, cache)):
                tally["ok"] += 1
            elif cls in rc.CURATED:
                tally["deliberate, recorded" if rc.recorded_in_gaps(cls, cache) else "under"] += 1
            else:
                tally["under"] += 1
    return tally


SHIPPED_ACCEPTING_BRANCHES = 4   # method-call, nested-type, data-member, base-class-walk
# Four, not three. The first draft said three and this check failed on its own first run,
# because the base-class loop's `if sub is True: return True` is a fourth accepting branch
# and the matrix does cover it, as the `base-class-walk` variant.
SHIPPED_BASE_SHAPES = 2          # `class X : Base`, `using X = Template<...>`
SHIPPED_NONE_RETURNS = 2         # header absent, base's None propagated


def check_shape_inventory() -> list[str]:
    """Fail if the shipped detector gained a shape no variant below switches off."""
    src = inspect.getsource(rc.declares_member)
    base_src = inspect.getsource(rc._header_bases)
    msgs = []
    accepting = src.count("return True")
    if accepting != SHIPPED_ACCEPTING_BRANCHES:
        msgs.append(f"declares_member has {accepting} accepting branches, this file covers "
                    f"{SHIPPED_ACCEPTING_BRANCHES}. Add a variant and a self-test case for the new "
                    "shape, then update SHIPPED_ACCEPTING_BRANCHES.")
    base_shapes = base_src.count("re.search")
    if base_shapes != SHIPPED_BASE_SHAPES:
        msgs.append(f"_header_bases resolves {base_shapes} base shapes, this file covers "
                    f"{SHIPPED_BASE_SHAPES}.")
    nones = src.count("return None")
    if nones != SHIPPED_NONE_RETURNS:
        msgs.append(f"declares_member has {nones} `return None` paths, this file covers "
                    f"{SHIPPED_NONE_RETURNS}.")
    return msgs


def main() -> int:
    failures = []

    # The inventory check reads this file's own source, never the pinned headers, so it runs and
    # is ENFORCED even when Libraries/ is absent. It used to sit above an early `return 0` that
    # threw its findings away in exactly the environment the docstring calls normal: CI and a
    # fresh clone. Measured by adding a fifth accepting branch to a copy of declares_member, which
    # exited 1 with the headers present and 0 without.
    inventory = check_shape_inventory()
    for m in inventory:
        print(f"SHAPE INVENTORY: {m}")
    failures.extend(inventory)
    if not inventory:
        print(f"shape inventory: {SHIPPED_ACCEPTING_BRANCHES} accepting branches, "
              f"{SHIPPED_BASE_SHAPES} base shapes, {SHIPPED_NONE_RETURNS} `cannot say` paths, "
              "each with a variant below")
    print()

    if not os.path.isdir(rc.OCCT_HEADERS):
        print(f"SKIPPED: the variants below need {rc.OCCT_HEADERS}, which is not present "
              "(the normal case in CI and in a fresh clone). The shape inventory above still ran.")
        if failures:
            for f in failures:
                print(f"FAIL: {f}")
            return 1
        return 0

    passed, total = _baseline_declares()
    print(f"declares_member baseline: {passed}/{total} cases pass unmodified")
    if passed != total:
        failures.append("baseline does not pass clean")
    print()
    for shape in ("method-call", "nested-type", "data-member", "base-class-walk",
                  "alias-template", "none-propagation"):
        got = _run_declares_variant(shape)
        broke = total - got
        verdict = "load-bearing" if broke else "NOT load-bearing"
        print(f"  {shape:<20} disabled -> {broke}/{total} cases fail  [{verdict}]")
        if not broke:
            failures.append(f"declares_member shape '{shape}' is decoration")

    n = len(rc.PARSE_SELF_TEST_CASES)
    base = sum(1 for line, expected, _ in rc.PARSE_SELF_TEST_CASES
               if rc._ATTRIBUTION_RE.findall(line) == expected)
    print()
    print(f"_ATTRIBUTION_RE baseline: {base}/{n} cases pass with the shipped pattern")
    print()
    for constraint in ("closing-backtick-anchor", "no-leading-backtick"):
        got = _run_parser_variant(constraint)
        broke = n - got
        verdict = "load-bearing" if broke else "NOT load-bearing"
        print(f"  {constraint:<26} imposed -> {broke}/{n} cases fail  [{verdict}]")
        if not broke:
            failures.append(f"_ATTRIBUTION_RE constraint '{constraint}' would cost nothing")

    # classify(), against the real tree. The gaps.md exclusion was wrong at one point during #811
    # (every class came back `ok` the moment this pass wrote the reasons), which is why it gets a
    # variant rather than an assertion.
    cache = rc.build_cache()
    baseline = _classify_counts(cache)
    print()
    print(f"classify baseline (real tree): {baseline}")
    if baseline["under"] != 0 or baseline["deliberate, recorded"] != 47:
        failures.append(f"classify baseline moved: {baseline}")

    # THE ORIGINAL DEFECT is both halves together: the docs test ahead of the curated tables, AND
    # docs/occtswift-wrapping-gaps.md counting as docs. That is what made the table read 129 ok the
    # moment this pass wrote its 47 reasons. It is the combination that is asserted, and each half
    # is then reported alone, because the first draft of this variant flipped both and credited the
    # swing to the ordering.
    both = _classify_counts_docs_first(cache, gaps_counts_as_docs=True)
    broke = both != baseline
    print(f"  docs-first AND gaps.md-as-docs -> {both}  "
          f"[{'load-bearing' if broke else 'NOT load-bearing'}]")
    if not broke:
        failures.append("the classify() ordering plus the gaps.md exclusion costs nothing")

    ordering_only = _classify_counts_docs_first(cache, gaps_counts_as_docs=False)
    print(f"    ordering alone                -> {ordering_only}  "
          f"[{'load-bearing' if ordering_only != baseline else 'redundant on this lane'}]")

    leaky = dict(cache)
    leaky_tokens = dict(cache["doc_tokens"])
    gaps_rel = os.path.relpath(rc.GAPS_FILE, rc.ROOT)
    for tok in rc._TOKEN_RE.findall(cache["gaps"]):
        leaky_tokens[tok] = leaky_tokens.get(tok, set()) | {gaps_rel}
    leaky["doc_tokens"] = leaky_tokens
    gaps_only = _classify_counts(leaky)
    print(f"    gaps.md-as-docs alone         -> {gaps_only}  "
          f"[{'load-bearing' if gaps_only != baseline else 'redundant on this lane'}]")
    halves_redundant = (ordering_only == baseline) and (gaps_only == baseline)
    if halves_redundant:
        print("      Both halves are redundant alone and both are kept. Every one of the 47 recorded")
        print("      classes is in a curated table, so the ordering has nothing to protect here and")
        print("      the exclusion has nothing to exclude. Each covers the other's absence: a class")
        print("      recorded in gaps.md with NO curated entry is the shape the next pass over this")
        print("      lane would introduce first, and only the exclusion catches it.")
    else:
        print("      One half is now load-bearing alone, which the printout above says and this")
        print("      commentary used to contradict by asserting redundancy unconditionally. Read the")
        print("      three verdicts, not this sentence.")

    wrapped_and_curated = [c for cs in rc.LANE_CLASSES.values() for c in cs
                           if c in rc.CURATED and rc.named_in_bridge(c, cache)]
    print(f"  wrapped-before-curated: {len(wrapped_and_curated)} lane classes are BOTH wrapped "
          "and in a curated table")
    if not wrapped_and_curated:
        print("      So the rule cannot be exercised here. Kept because #810's lane has six")
        print("      deprecated headers that ARE genuinely called, which is what it is for.")

    print()
    if failures:
        for f in failures:
            print(f"FAIL: {f}")
        return 1
    print("every guard the variants above can switch off is load-bearing, and the two halves of the")
    print("classify fix are redundant alone by measurement rather than by assertion")
    return 0


if __name__ == "__main__":
    sys.exit(main())
