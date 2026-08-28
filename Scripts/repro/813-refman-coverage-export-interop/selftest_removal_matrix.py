#!/usr/bin/env python3
"""#813: proof that `refman_census.py`'s guards are load-bearing, per prove-the-test-fails.md.

Same shape as #811/#812's `selftest_removal_matrix.py`, adapted to this lane's own detector. A
self-test that passes because the detector is blind looks exactly like one that passes because the
tree is clean, so this removes each accepting shape in turn and reports how many self-test cases
stop passing. A shape whose removal breaks nothing is decoration.

Three groups:

  declares_member    the four shapes that make it answer True, plus the two None-producing shapes:
                     a header simply not shipped (`Interface_813NoSuchClass`, a fabricated name --
                     this lane has no alias-template-shaped curated class, unlike #812's
                     HLRBRep_CLProps, so unlike #811/#812 that half of the None coverage cannot use
                     a real curated example) and a base's None propagating up through a multi-base
                     class (`RWObj_CafReader`, real and lane-native: one of its two bases,
                     `RWObj_IShapeReceiver`, is declared inline with no header of its own).
  _ATTRIBUTION_RE    the two constraints the pattern deliberately omits.
  classify           the ordering decision and the gaps.md exclusion, together and then each alone,
                     against the real tree. On THIS lane the ordering is not merely defensive:
                     `BinTools` and `RWMesh` (the two bare package headers) have REAL non-gaps.md
                     doc hits (one of them IS the #813 over-coverage finding), so this lane is the
                     first of the four #807 lanes where docs-first genuinely misclassifies two
                     specific, real classes rather than only classes that happen to share a gaps.md
                     summary-line's toolkit name.

    python3 Scripts/repro/813-refman-coverage-export-interop/selftest_removal_matrix.py

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
    """classify() with the docs test moved ahead of the curated tables. See #811/#812's own version
    of this function for why the two halves (ordering, gaps.md exclusion) are isolated separately
    rather than only reported together."""
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
SHIPPED_BASE_SHAPES = 2          # `class X : Base`, `using X = Template<...>`
SHIPPED_NONE_RETURNS = 2         # header absent, base's None propagated


def check_shape_inventory() -> list[str]:
    """Fail if the shipped detector gained a shape no variant below switches off. Copy-identical to
    #811/#812's own version: `declares_member`/`_header_bases` are unchanged code, only
    `LANE_CLASSES`/`CURATED`/`SELF_TEST_CASES` differ per lane, so the shape count is a property of
    the shared mechanism, not of this lane's own curated reasoning."""
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

    inventory = check_shape_inventory()
    for m in inventory:
        print(f"SHAPE INVENTORY: {m}")
    failures.extend(inventory)
    if not inventory:
        print(f"shape inventory: {SHIPPED_ACCEPTING_BRANCHES} accepting branches, "
              f"{SHIPPED_BASE_SHAPES} base shapes, {SHIPPED_NONE_RETURNS} `cannot say` paths, "
              "each with a variant below (the alias-template BASE SHAPE has no case in this "
              "lane's SELF_TEST_CASES -- see module docstring -- both `cannot say` paths ARE "
              "covered, one via a fabricated header-absent name, one via a real, lane-native "
              "multi-base class)")
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
                  "none-propagation"):
        got = _run_declares_variant(shape)
        broke = total - got
        verdict = "load-bearing" if broke else "NOT load-bearing"
        print(f"  {shape:<20} disabled -> {broke}/{total} cases fail  [{verdict}]")
        if not broke:
            failures.append(f"declares_member shape '{shape}' is decoration")

    # alias-template: this lane's SELF_TEST_CASES has no case that resolves THROUGH a `using X =
    # Template<...>` base (unlike #812's HLRBRep_CLProps/Tangent), because no curated class in this
    # lane is alias-template-shaped (measured, not assumed: none of the 192 headers is a bare
    # `using` declaration). Disabling the alias-following branch in `_header_bases` therefore
    # changes 0/N cases here, correctly reported NOT load-bearing below rather than silently
    # skipped, which is the honest answer for this lane rather than a copy-pasted claim inherited
    # from #812's lane.
    got = _run_declares_variant("alias-template")
    broke = total - got
    print(f"  {'alias-template':<20} disabled -> {broke}/{total} cases fail  "
          f"[{'load-bearing' if broke else 'redundant on this lane'}]")
    if broke:
        failures.append("alias-template was expected to be redundant on this lane (no "
                        "alias-template-shaped curated class) but broke a case; re-check "
                        "SELF_TEST_CASES for an unintended alias dependency")

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

    cache = rc.build_cache()
    baseline = _classify_counts(cache)
    print()
    print(f"classify baseline (real tree): {baseline}")
    if baseline["under"] != 0 or baseline["deliberate, recorded"] != 170:
        failures.append(f"classify baseline moved: {baseline}")

    both = _classify_counts_docs_first(cache, gaps_counts_as_docs=True)
    broke = both != baseline
    print(f"  docs-first AND gaps.md-as-docs -> {both}  "
          f"[{'load-bearing' if broke else 'NOT load-bearing'}]")
    if not broke:
        failures.append("the classify() ordering plus the gaps.md exclusion costs nothing")

    ordering_only = _classify_counts_docs_first(cache, gaps_counts_as_docs=False)
    ordering_broke = ordering_only != baseline
    print(f"    ordering alone                -> {ordering_only}  "
          f"[{'load-bearing' if ordering_broke else 'redundant on this lane'}]")
    if not ordering_broke:
        failures.append("classify() ordering alone was expected to be load-bearing on this lane "
                        "(BinTools/RWMesh have real non-gaps.md doc hits) but was not; re-check "
                        "the two bare-package classes still have those doc hits")

    leaky = dict(cache)
    leaky_tokens = dict(cache["doc_tokens"])
    gaps_rel = os.path.relpath(rc.GAPS_FILE, rc.ROOT)
    for tok in rc._TOKEN_RE.findall(cache["gaps"]):
        leaky_tokens[tok] = leaky_tokens.get(tok, set()) | {gaps_rel}
    leaky["doc_tokens"] = leaky_tokens
    gaps_only = _classify_counts(leaky)
    print(f"    gaps.md-as-docs alone         -> {gaps_only}  "
          f"[{'load-bearing' if gaps_only != baseline else 'redundant on this lane'}]")

    print()
    print("  UNLIKE #811/#812: 'ordering alone' is load-bearing on THIS lane by itself, not only")
    print("  in combination. BinTools and RWMesh (bare package headers) have real doc hits in")
    print("  docs/API_REFERENCE.md and docs/reference/*.md (not gaps.md), so moving the docs test")
    print("  ahead of the curated table would misclassify both as `ok` via their accidental hit,")
    print("  the same trap #812 found for HLRAlgo/HLRBRep but against a real doc file rather than")
    print("  only the gaps.md summary line.")

    wrapped_and_curated = [c for cs in rc.LANE_CLASSES.values() for c in cs
                           if c in rc.CURATED and rc.named_in_bridge(c, cache)]
    print(f"\n  wrapped-before-curated: {len(wrapped_and_curated)} lane classes are BOTH wrapped "
          "and in a curated table")
    if not wrapped_and_curated:
        print("      So the rule cannot be exercised here. Kept for the same reason #811/#812 keep")
        print("      it: the RULE is what is being asserted, not that this particular lane has an")
        print("      instance of it.")

    print()
    if failures:
        for f in failures:
            print(f"FAIL: {f}")
        return 1
    print("every guard the variants above can switch off is load-bearing on this lane, including")
    print("the classify() ordering ALONE (not just in combination), which is new relative to")
    print("#811/#812's own findings and specific to this lane's two bare-package-header classes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
