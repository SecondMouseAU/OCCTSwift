#!/usr/bin/env python3
"""#983: proof that `refman_census.py`'s guards are load-bearing, per prove-the-test-fails.md.

Same shape as #811's and #812's `selftest_removal_matrix.py`, adapted to this lane's own detector
and to the one respect in which this lane's classifier is structurally different: `CURATED` here
is keyed by PACKAGE, not by class, and every class in it is now also individually named in
`docs/occtswift-wrapping-gaps.md`'s new "OCAF persistence and format drivers lane" section. Two
questions the prior two lanes' matrices didn't have to ask follow directly from that:

  1. Is the `docs/occtswift-wrapping-gaps.md` TEXT actually what the gate checks, or would
     `CURATED` alone carry the 333 classes to a passing verdict even with no text in the file?
  2. Is `CURATED`'s own bucketing (as opposed to a bare "named in gaps.md, no reason on file")
     load-bearing for the PASS/FAIL verdict, or only for how informative the note is?

Four groups:

  declares_member    the four shapes that make it answer True, plus the None it must answer for a
                     base whose own header is not shipped, reusing #811's/#812's shapes verified
                     against this lane's own classes (Storage_Schema::myCurrentData /
                     ::ICurrentDataMutex, PCDM_Reader::Mutex).
  _ATTRIBUTION_RE    the two constraints the pattern deliberately omits.
  classify           the ordering decision and the gaps.md exclusion, together and then each
                     alone, against the real tree -- same shape as #811/#812.
  gaps-text vs CURATED   THIS lane's own addition: strip the gaps.md TEXT (simulating the PR that
                     added `CURATED` but never wrote the docs section) and separately empty
                     `CURATED` (simulating a PR that wrote the docs section by hand with no Python
                     table backing it), MEASURED rather than assumed either way. The first was
                     expected to drop all 333 to `under` and instead drops 332: `Storage_Schema`
                     survives on a second, pre-existing gaps.md mention this lane's own section
                     did not create, a genuine exception, not a bug. The second was expected to be
                     pure cosmetics (only the note's bucket label lost) and instead changes the
                     VERDICT for 6 of the 333: classify() checks `cls in CURATED` before the docs
                     test, so a curated class that is ALSO separately documented outside gaps.md
                     (5 real ones, plus `Storage` itself on a bare-word false match) flips from
                     `deliberate, recorded` to `ok` the moment CURATED stops intercepting it first.
                     Both corrections were found by running the check, not by reasoning about it,
                     and both are recorded honestly rather than the check being bent to match a
                     wrong a priori expectation.

    python3 Scripts/repro/983-ocaf-persistence-drivers/selftest_removal_matrix.py

Exits 1 if any variant that SHOULD be load-bearing is not, or if the baseline does not pass clean.
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
            return []
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
    """classify() with the docs test moved ahead of the curated tables. See #811's/#812's own
    version of this function for why the two halves (ordering, gaps.md exclusion) are isolated
    separately rather than only reported together."""
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
SHIPPED_BASE_SHAPES = 1          # `class X : Base` only -- see _header_bases' own docstring for
                                 # why this lane carries no `using X = Template<...>` branch
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


# ------------------------------------------------------------------------------------------------
# This lane's own addition: gaps.md TEXT vs CURATED table, isolated from each other.
# ------------------------------------------------------------------------------------------------

# The exact heading this lane's new section starts with, and the next section's heading, so the
# text can be excised without depending on line numbers that will drift as the file grows.
_SECTION_START = "### OCAF persistence and format drivers lane, family-level (#983)"
_SECTION_END = "### GD&T dimension accessors left unwrapped (#1004)"


def _cache_with_gaps_text_stripped():
    cache = rc.build_cache()
    gaps_text = rc._read(rc.GAPS_FILE) if os.path.exists(rc.GAPS_FILE) else ""
    start = gaps_text.find(_SECTION_START)
    end = gaps_text.find(_SECTION_END)
    if start == -1 or end == -1 or end <= start:
        raise AssertionError(
            f"could not locate this lane's own gaps.md section between {_SECTION_START!r} and "
            f"{_SECTION_END!r} -- the section heading moved or was renamed; update this script's "
            "markers in the same PR that renames it")
    stripped = gaps_text[:start] + gaps_text[end:]
    cache["gaps"] = stripped
    return cache


def main() -> int:
    failures = []

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
                  "none-propagation"):
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

    cache = rc.build_cache()
    baseline = _classify_counts(cache)
    print()
    print(f"classify baseline (real tree): {baseline}")
    if baseline["under"] != 0 or baseline["deliberate, recorded"] != 333:
        failures.append(f"classify baseline moved: {baseline}")

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
    if ordering_only == baseline and gaps_only == baseline:
        print("      Both halves are redundant alone and both are kept, the same shape #811/#812")
        print("      find on their own lanes: nothing here is BOTH curated AND independently")
        print("      documented outside the gaps file, so neither half has anything to protect")
        print("      alone on this lane specifically.")
    else:
        print("      One half is now load-bearing alone; read the two verdicts above, not this")
        print("      sentence.")

    wrapped_and_curated = [c for cs in rc.LANE_CLASSES.values() for c in cs
                           if c in rc.CURATED and rc.named_in_bridge(c, cache)]
    print(f"  wrapped-before-curated: {len(wrapped_and_curated)} lane classes are BOTH wrapped "
          "and in a curated table")
    if not wrapped_and_curated:
        print("      So the rule cannot be exercised here. Kept for the same reason #811/#812")
        print("      keep it: the RULE is what is being asserted, not that this lane has a live")
        print("      instance of it -- CURATED is built from LANE_CLASSES minus the 9 individually")
        print("      wrapped/documented classes, so by construction no class is in both.")

    print()
    print("this lane's own addition: gaps.md TEXT vs the CURATED python table, isolated")
    try:
        stripped_cache = _cache_with_gaps_text_stripped()
    except AssertionError as exc:
        failures.append(str(exc))
        stripped_cache = None

    if stripped_cache is not None:
        stripped_tally = _classify_counts(stripped_cache)
        print(f"  gaps.md TEXT stripped (CURATED intact) -> {stripped_tally}")
        # MEASURED, not the "all 333 -> under" a first draft of this check assumed: `Storage_Schema`
        # has a SECOND, pre-existing mention in gaps.md outside this lane's own new section (the
        # #371/#374 XCAFApp_Application writeup, landed before #983), so it alone survives with
        # `deliberate, recorded` even once this lane's own section is gone. That is still the right
        # answer, not a bug in the check: `recorded_in_gaps` is a name match anywhere in the file,
        # by design, the same "not that the sentence around it is a reason" caveat #811/#812 both
        # already carry. The other 332 have no such second mention and correctly drop to `under`.
        expected_stripped = {"ok": 9, "deliberate, recorded": 1, "under": 332}
        if stripped_tally == expected_stripped:
            print(f"    -> matches {expected_stripped}  [load-bearing: the gaps.md TEXT, not "
                  "just CURATED, is what the gate checks for 332 of the 333 curated classes; "
                  "Storage_Schema is the one exception, and it is genuine, not a bug]")
        else:
            failures.append(
                f"stripping this lane's own gaps.md section did not fail the way it should: got "
                f"{stripped_tally}, expected {expected_stripped}. Either the section markers "
                "drifted (see _SECTION_START/_SECTION_END), Storage_Schema's other pre-existing "
                "gaps.md mention was removed elsewhere, or CURATED alone is silently carrying "
                "classes to a passing verdict with no supporting text.")

    curated_backup = dict(rc.CURATED)
    rc.CURATED.clear()
    try:
        no_curated_tally = _classify_counts(cache)
    finally:
        rc.CURATED.update(curated_backup)
    print(f"  CURATED emptied (gaps.md TEXT intact)  -> {no_curated_tally}")
    # MEASURED, not assumed: classify()'s ordering checks `cls in CURATED` BEFORE the `docs` test,
    # so for the 327 classes named ONLY in gaps.md's own text, emptying CURATED changes nothing --
    # `recorded_in_gaps` alone still carries them to `deliberate, recorded`, just with a generic
    # note instead of a specific bucket reason. But 6 of the 333 curated classes are ALSO named
    # somewhere in docs/ outside gaps.md (BinLDrivers_DocumentStorageDriver, PCDM_Reader,
    # PCDM_StorageDriver, Storage_CallBack and Storage_Schema in docs/thread-safety.md's prose
    # about #349/#353/#374/#371; Storage itself in four unrelated pages, a bare-word
    # `\bStorage\b` match this detector's own limitation cannot tell from the English word rather
    # than the OCCT class -- see #811's/#812's identical "name match, not reason match" caveat).
    # For exactly those 6, removing CURATED lets the docs test fire first and they flip to `ok`
    # ("documented") instead of `deliberate, recorded`. So CURATED IS load-bearing for the verdict
    # after all, for this specific subset, contradicting a first draft of this check that assumed
    # it was purely cosmetic.
    expected_no_curated = {"ok": 15, "deliberate, recorded": 327, "under": 0}
    if no_curated_tally == expected_no_curated:
        print(f"    -> matches {expected_no_curated}  [PARTIALLY load-bearing: 6 of the 333 "
              "curated classes are also separately documented outside gaps.md, and CURATED's "
              "priority over the docs test is what keeps them at `deliberate, recorded` (machinery, "
              "not a capability) instead of `ok` (documented); the other 327 are unaffected]")
    else:
        failures.append(f"emptying CURATED gave {no_curated_tally}, expected "
                        f"{expected_no_curated} -- the measured 6-class overlap with docs/ outside "
                        "gaps.md has changed; re-derive which classes they are before trusting "
                        "this check's own commentary")

    print()
    if failures:
        for f in failures:
            print(f"FAIL: {f}")
        return 1
    print("every guard the variants above can switch off is load-bearing where claimed, and the")
    print("gaps.md TEXT vs CURATED table split behaves exactly as documented")
    return 0


if __name__ == "__main__":
    sys.exit(main())
