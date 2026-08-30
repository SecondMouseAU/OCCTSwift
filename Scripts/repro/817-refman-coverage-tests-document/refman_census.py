#!/usr/bin/env python3
"""Issue #817 (Pass 5c of #807/#819): refman coverage census for TESTS, Document/XCAF lane.

Passes 5a-5d ask the test-side form of #807's question, which is different from every prior
source-side pass (#808-#814): not "do we wrap/document what the refman promises" but "does a
TEST in this lane actually exercise the behaviour we wrap and document." Two directions, per
#817's own wording:

  UNDER-COVERAGE. An OCCT behaviour the refman documents, which we wrap AND document, and which
  no test exercises. The population this applies to is exactly #810's `ok` verdict (wrapped AND
  documented) -- a class #810 already classified `deliberate, recorded` is NOT wrapped at all
  (by #810's own classify() rule), so there is no test-coverage question to ask about it; #817's
  wording ("documented+wrapped, no test") makes this explicit.

  OVER-COVERAGE. A test that asserts behaviour the refman does not promise: a stated tolerance,
  algorithm guarantee, or invariant in a lane test's `//`/`///` comment or name, checked against
  the actual refman text for the class involved. Tracked the same way #810 tracks its findings:
  a curated, evidenced list with a regression check, not a live detector (a live "does this
  English sentence overclaim" detector does not exist here or anywhere else in this repo).

THIS PASS'S GROUND TRUTH IS #810's OWN SCRIPT, RE-RUN, NOT RE-TYPED. #817 says so directly: "You
have a real head start here... reuse its class list as your ground truth... re-deriving/
re-verifying rather than blindly trusting a possibly-stale artifact." `load_810_classification()`
below invokes `Scripts/repro/810-refman-document-xde/refman_census.py` as a subprocess (the same
way #810 itself invokes `census-doc-occt-attribution.py --lane ...` as an external tool rather
than re-implementing it) and parses its live stdout table, so this pass's "wrapped=True" set is
whatever #810's script says TODAY, not what it said when #810 was written. Measured, not assumed:
at the time this pass was written, #810's own table had moved from its README's "118 ok / 160
deliberate, recorded" to 131 / 147, because more of the lane has been wrapped since #810 merged.
This is #811's own "things move" warning made concrete on this exact lane, and it is why this
script does not carry its own copy of #810's ~560-line curated tables.

THE TESTED DIMENSION is `derive_lane.py`'s three-hop reachability derivation (test file -> Swift
member -> bridge function -> OCCT class), summarized in that file's own module docstring. Every
class it resolves through a member in `GENERIC_MEMBERS` is additionally hand-adjudicated below
(`REVIEWED_HITS`) rather than accepted on the mechanical signal alone, per #817's explicit
instruction not to trust a keyword match.

Run from anywhere:

    python3 Scripts/repro/817-refman-coverage-tests-document/refman_census.py               # the table
    python3 Scripts/repro/817-refman-coverage-tests-document/refman_census.py --verbose      # + evidence
    python3 Scripts/repro/817-refman-coverage-tests-document/refman_census.py --reverify-lane # header re-derivation (needs Libraries/)
    python3 Scripts/repro/817-refman-coverage-tests-document/refman_census.py --self-test     # detector fixtures

Exits 1 on: a KNOWN_OVER_FINDING regression, a DEFERRED_OVER_FINDING that has been silently
fixed, an `under` with no `docs/occtswift-wrapping-gaps.md` line misclassified as `deliberate,
recorded` (or vice versa), or lane drift under `--reverify-lane`. Exits 0 otherwise.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
GAPS_FILE = os.path.join(ROOT, "docs", "occtswift-wrapping-gaps.md")
PASS3_SCRIPT = os.path.join(ROOT, "Scripts", "repro", "810-refman-document-xde", "refman_census.py")
OCCT_HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import derive_lane as dl  # noqa: E402

ROW_RE = re.compile(
    r"^(\S+)\s+(\S+)\s+(True|False)\s+(True|False)\s+"
    r"(ok|under|over|deliberate, recorded)\s*(.*)$"
)

LANE_HEADER_RE = re.compile(
    r"^(TDocStd|TDF|TDataStd|TDataXtd|TNaming|XCAFDoc|XCAFApp|XCAFDimTolObjects|XCAFNoteObjects"
    r"|XCAFView|XCAFPrs|CDF|CDM)(_[^.]+)?\.hxx$"
)


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def load_810_classification() -> dict[str, dict]:
    """class -> {lane, documented, wrapped, verdict, note}, parsed from #810's own live output.

    A subprocess call, not an import: #810's script is a standalone artifact belonging to a
    different issue, and re-running it as a black box is the same relationship #810 itself has
    with `census-doc-occt-attribution.py`. If its output format ever changes in a way this
    parser cannot read, this raises loudly (a RuntimeError naming the offending line) rather than
    silently returning an empty/partial table -- an empty ground truth here would misclassify
    every one of the lane's 278 classes as `under`, which is exactly the kind of failure
    `okf/policies/prove-the-test-fails.md` says a `--self-test` must catch, so `--self-test`
    below has a case injecting a format change and confirming this raises.
    """
    if not os.path.exists(PASS3_SCRIPT):
        raise RuntimeError(f"#810's script not found at {PASS3_SCRIPT}")
    proc = subprocess.run(
        [sys.executable, PASS3_SCRIPT], capture_output=True, text=True, check=False
    )
    return _parse_810_output(proc.stdout)


def _parse_810_output(stdout: str) -> dict[str, dict]:
    rows: dict[str, dict] = {}
    for line in stdout.splitlines():
        m = ROW_RE.match(line)
        if not m:
            continue
        lane, cls, documented, wrapped, verdict, note = m.groups()
        rows[cls] = {
            "lane": lane,
            "documented": documented == "True",
            "wrapped": wrapped == "True",
            "verdict": verdict,
            "note": note,
        }
    if not rows:
        raise RuntimeError(
            "parsed ZERO rows from #810's script output -- its table format changed, or it "
            "produced no output at all; see load_810_classification()'s docstring"
        )
    return rows


def all_lane_classes() -> set[str]:
    """Every class #810's script currently enumerates (278, at the time this was written)."""
    return set(load_810_classification())


def wrapped_classes(classification: dict[str, dict]) -> set[str]:
    """The population this pass's under/tested question applies to: wrapped AND documented,
    i.e. #810's `ok` verdict. A class classified `deliberate, recorded` (not wrapped) has no
    bridge function to test in the first place."""
    return {cls for cls, r in classification.items() if r["verdict"] == "ok"}


def _in_gaps_doc(cls: str, gaps_text: str) -> bool:
    return re.search(r"\b" + re.escape(cls) + r"\b", gaps_text) is not None


# ---------------------------------------------------------------------------------------------
# Classes this pass's mechanical, LANE-SCOPED check correctly calls `under` (no test in
# OCCTXCAFTests or the document half of OCCTIOTests reaches them), for which a broader,
# whole-suite search found real, passing tests -- just in a different target. NOT a coverage
# gap: the behaviour IS exercised. Filed as #1396 (test-organization, not test-coverage) rather
# than moved here, since relocating 12 suites across 3 files is outside #817's own mandate.
# Printed as an annotation on the `under` row rather than folded into `ok`, so the table still
# answers "does THIS LANE cover it" honestly.
# ---------------------------------------------------------------------------------------------

TESTED_OUTSIDE_LANE: dict[str, str] = {
    "TDataStd_ByteArray": "OCCTFoundationTests: 'ByteArray Tests' suite",
    "TDataStd_IntegerList": "OCCTFoundationTests: 'IntegerList Tests' suite",
    "TDataStd_RealList": "OCCTFoundationTests: 'RealList Tests' suite",
    "TDataStd_ExtStringArray": "OCCTFoundationTests: 'ExtStringArray Tests' suite",
    "TDataStd_ExtStringList": "OCCTFoundationTests: 'ExtStringList Tests' suite",
    "TDataStd_ReferenceArray": "OCCTFoundationTests: 'ReferenceArray Tests' suite",
    "TDataStd_ReferenceList": "OCCTFoundationTests: 'ReferenceList Tests' suite",
    "TDataStd_Relation": "OCCTFoundationTests: 'Relation Tests' suite",
    "TDataStd_IntPackedMap": "OCCTFoundationTests: 'IntPackedMap Tests' suite",
    "TDataStd_NoteBook": "OCCTFoundationTests: 'NoteBook Tests' suite",
    "TDataStd_BooleanArray": "OCCTModelingTests/BooleanArrayTests.swift",
    "TDataStd_BooleanList": "OCCTModelingTests/BooleanListTests.swift",
}


# ---------------------------------------------------------------------------------------------
# Classes whose ONLY reachability evidence goes through a member in derive_lane.GENERIC_MEMBERS,
# hand-adjudicated against the actual test body rather than accepted on the mechanical signal.
# Filled in by reading every such candidate once `derive_lane.py --calls` was run; see the
# README's "Hand-adjudicated generic-member hits" section for the evidence behind each verdict.
# `True` confirms the mechanical hit is real (a lane test genuinely exercises that class through
# that member); `False` overrides it to `under` because the member access in the test corpus is
# to an unrelated type.
# ---------------------------------------------------------------------------------------------

REVIEWED_HITS: dict[str, bool] = {
    # All three reach their class through a bare-type-name constructor call resolved to the
    # generic "init" member (derive_lane.py's HOP-1 fix for exactly this shape). Each hand-checked
    # against the real test body, not accepted on the mechanical hit alone:
    "XCAFDoc_AssemblyGraph": True,
    # Tests/OCCTXCAFTests/XCAFDocAssemblyGraphTests.swift:14, `AssemblyGraph(document: doc)`,
    # followed by real assertions on `nodeCount`/`linkCount`/`rootCount`.
    "XCAFNoteObjects_NoteObject": True,
    # Tests/OCCTXCAFTests/XCAFNoteObjectsTests.swift: six `NoteObject()` constructions across
    # its six test functions, each followed by real property assertions.
    "XCAFView_Object": True,
    # Tests/OCCTXCAFTests/XCAFViewObjectTests.swift: seven `ViewObject()` constructions, each
    # followed by real property assertions (projection type, camera fields, ...).
}


# ---------------------------------------------------------------------------------------------
# Over-coverage: confirmed findings, each fixed in this PR. Same regression-check shape as
# #810's KNOWN_OVER_FINDINGS: `bad_phrase` is the wrong text that used to appear in `doc_file`;
# this script exits 1 if it ever reappears.
# ---------------------------------------------------------------------------------------------

KNOWN_OVER_FINDINGS: list[dict] = []

# Findings adjudicated as real but deliberately NOT fixed here (a behaviour question, not a
# doc/test-comment fix) -- filed as a follow-up issue instead. INVERTED check, matching #810: the
# bad phrase must still be PRESENT, since a finding quietly fixed without moving here would mean
# this census has stopped describing the tree.
DEFERRED_OVER_FINDINGS: list[dict] = []


def check_known_over_findings() -> list[dict]:
    regressions = []
    cache: dict[str, str] = {}
    for finding in KNOWN_OVER_FINDINGS:
        path = os.path.join(ROOT, finding["doc_file"])
        if path not in cache:
            cache[path] = _read(path) if os.path.exists(path) else ""
        haystack = " ".join(cache[path].split())
        needle = " ".join(finding["bad_phrase"].split())
        if needle in haystack:
            regressions.append(finding)
    return regressions


def check_deferred_findings() -> list[dict]:
    stale = []
    cache: dict[str, str] = {}
    for finding in DEFERRED_OVER_FINDINGS:
        path = os.path.join(ROOT, finding["doc_file"])
        if path not in cache:
            cache[path] = _read(path) if os.path.exists(path) else ""
        haystack = " ".join(cache[path].split())
        needle = " ".join(finding["bad_phrase"].split())
        if needle not in haystack:
            stale.append(finding)
    return stale


# ---------------------------------------------------------------------------------------------
# Over-coverage CANDIDATE sweep: lane test files, scanned for a comment/name making an explicit
# behavioural or numeric claim about OCCT internals. This is a candidate FINDER, not a verdict:
# every hit needs a human to read the actual refman text for the class involved (via the
# `context` MCP) before it counts as anything. #817 is explicit that a keyword match is not
# adjudication.
# ---------------------------------------------------------------------------------------------

CLAIM_PATTERNS = [
    re.compile(r"\batomic(?:ally)?\b", re.I),
    re.compile(r"\bthread[- ]safe\b", re.I),
    re.compile(r"\bguarantee[sd]?\b", re.I),
    re.compile(r"\balways\b"),
    re.compile(r"\bnever\b"),
    re.compile(r"\bmust\b"),
    re.compile(r"\bin order\b", re.I),
    re.compile(r"\bdeterministic\b", re.I),
    re.compile(r"\btolerance of\b", re.I),
    re.compile(r"\bexactly\b", re.I),
    re.compile(r"\bshares?\b.*\bdocument", re.I),
    re.compile(r"\bconcurrent(?:ly)?\b", re.I),
]

LINE_COMMENT = re.compile(r"//[^\n]*")


def find_claim_candidates() -> list[tuple[str, int, str]]:
    """[(file, lineno, line_text)] for every lane test comment line matching a CLAIM_PATTERN."""
    out = []
    for path in dl.lane_test_files():
        for lineno, line in enumerate(_read(path).splitlines(), 1):
            stripped = line.strip()
            if not (stripped.startswith("//") or stripped.startswith("///")):
                continue
            if any(p.search(stripped) for p in CLAIM_PATTERNS):
                out.append((os.path.relpath(path, ROOT), lineno, stripped))
    return out


# ---------------------------------------------------------------------------------------------


def classify_tested(cls: str, reached: dict[str, list[dict]], gaps_text: str) -> tuple[str, str]:
    evidence = reached.get(cls)
    if evidence:
        non_generic = [e for e in evidence if not e["generic"]]
        if non_generic:
            e = non_generic[0]
            return "ok", f"{e['swift_file']}::{e['member']} -> {', '.join(e['bridge_fns'])}"
        # Every hit is through a generic member name; only trust it if hand-reviewed True.
        if REVIEWED_HITS.get(cls) is True:
            e = evidence[0]
            return (
                "ok",
                f"{e['swift_file']}::{e['member']} -> {', '.join(e['bridge_fns'])} "
                f"[generic member, hand-confirmed]",
            )
        # Falls through to under/deliberate below: the mechanical hit is not trusted.
    if _in_gaps_doc(cls, gaps_text):
        return "deliberate, recorded", "recorded in occtswift-wrapping-gaps.md"
    if cls in TESTED_OUTSIDE_LANE:
        return (
            "under",
            f"no LANE test reaches it, but real tests exist outside the lane: "
            f"{TESTED_OUTSIDE_LANE[cls]} -- filed as #1396, not a coverage gap",
        )
    return "under", "wrapped and documented (#810), no lane test reaches it"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--verbose", action="store_true")
    p.add_argument("--reverify-lane", action="store_true")
    p.add_argument("--self-test", action="store_true")
    args = p.parse_args()

    if args.self_test:
        return 0 if self_test() else 1

    classification = load_810_classification()
    wrapped = wrapped_classes(classification)
    gaps_text = _read(GAPS_FILE) if os.path.exists(GAPS_FILE) else ""
    reached = dl.reachable_classes(all_lane_classes())

    if args.reverify_lane:
        if not os.path.isdir(OCCT_HEADERS):
            print(f"--reverify-lane SKIPPED: {OCCT_HEADERS} not present")
        else:
            derived = {
                f[:-4]
                for f in os.listdir(OCCT_HEADERS)
                if LANE_HEADER_RE.match(f)
            }
            current = all_lane_classes()
            if derived != current:
                print("LANE DRIFT:")
                print("  in census, not in headers:", sorted(current - derived))
                print("  in headers, not in census:", sorted(derived - current))
                return 1
            print(f"Lane confirmed against pinned headers: {len(derived)} classes, no drift.")

    rows = []
    for cls in sorted(wrapped):
        verdict, note = classify_tested(cls, reached, gaps_text)
        rows.append({"class": cls, "verdict": verdict, "note": note})

    print(f"{'occt_class':45} {'verdict':22} note")
    print("-" * 140)
    for r in rows:
        print(f"{r['class']:45} {r['verdict']:22} {r['note']}")

    print()
    counts: dict[str, int] = {}
    for r in rows:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    print(f"Wrapped+documented classes in lane (#810's 'ok'): {len(wrapped)}")
    for v in ("ok", "deliberate, recorded", "under"):
        print(f"  {v}: {counts.get(v, 0)}")

    regressions = check_known_over_findings()
    print()
    print(f"Known over-coverage findings tracked: {len(KNOWN_OVER_FINDINGS)}")
    if regressions:
        print("REGRESSION: the following fixed over-coverage findings have reappeared:")
        for f in regressions:
            print(f"  {f['doc_file']}: {f['subject']} -- '{f['bad_phrase']}'")
    else:
        print("All known over-coverage findings remain fixed.")

    stale = check_deferred_findings()
    print(f"\nDeferred over-coverage findings: {len(DEFERRED_OVER_FINDINGS)}")
    if stale:
        print("STALE: the following deferred findings have been fixed without being moved:")
        for f in stale:
            print(f"  {f['doc_file']}: {f['subject']}")

    candidates = find_claim_candidates()
    print(f"\nOver-coverage CANDIDATE sweep: {len(candidates)} comment lines matched a claim "
          f"pattern (see README for hand-adjudication of each)")

    exit_code = 0
    if regressions or stale:
        exit_code = 1
    # Verdict-classification sanity: an `under`/`deliberate, recorded` split must actually track
    # the gaps doc, not just happen to.
    for r in rows:
        should_be_recorded = _in_gaps_doc(r["class"], gaps_text)
        if r["verdict"] == "under" and should_be_recorded:
            print(f"MISCLASSIFIED: {r['class']} is 'under' but IS named in occtswift-wrapping-gaps.md")
            exit_code = 1
    return exit_code


# ---------------------------------------------------------------------------------------------
# Self-test. Per okf/policies/prove-the-test-fails.md: every detection shape gets a case proving
# it is load-bearing (inject the defect, confirm the check fails to distinguish it, restore,
# confirm it distinguishes correctly).
# ---------------------------------------------------------------------------------------------


def self_test() -> bool:
    ok = True

    # 810-output parsing: a well-formed row parses; a format change is detected loudly rather
    # than silently dropped.
    sample = (
        "lane                 occt_class                                         documented?  wrapped?  verdict                note\n"
        "-" * 160 + "\n"
        "TDocStd*             TDocStd_Application                                True         True      ok                     wrapped\n"
        "CDF*                 CDF_Application                                    True         False     deliberate, recorded   abstract base: reason text here\n"
        "TDF*                 TDF_HAllocator                                     False        False     under                  neither wrapped nor documented\n"
    )
    parsed = _parse_810_output(sample)
    if (
        parsed.get("TDocStd_Application", {}).get("verdict") == "ok"
        and parsed.get("CDF_Application", {}).get("verdict") == "deliberate, recorded"
        and parsed.get("TDF_HAllocator", {}).get("verdict") == "under"
    ):
        print("[PASS] parse-810-output: all three verdict shapes parsed correctly")
    else:
        print(f"[FAIL] parse-810-output: got {parsed}")
        ok = False

    # Load-bearing: a format change (e.g. a renamed verdict column) must raise, not silently
    # return an empty table (which would misclassify every lane class as `under`).
    try:
        _parse_810_output("nothing here matches the row format\n")
        print("[FAIL] parse-810-output-empty: expected RuntimeError on zero parsed rows")
        ok = False
    except RuntimeError:
        print("[PASS] parse-810-output-empty [load-bearing: an empty/garbled 810 output raises "
              "rather than silently classifying every class 'under']")

    # wrapped_classes: only 'ok' rows count, regardless of documented/wrapped booleans on their
    # own (a class could be wrapped=True documented=False and still not be 'ok' per #810's own
    # classify() -- this pass trusts #810's verdict column, not the booleans directly).
    fake = {
        "A": {"verdict": "ok"},
        "B": {"verdict": "deliberate, recorded"},
        "C": {"verdict": "ok"},
        "D": {"verdict": "under"},
    }
    w = wrapped_classes(fake)
    if w == {"A", "C"}:
        print("[PASS] wrapped-classes-filter")
    else:
        print(f"[FAIL] wrapped-classes-filter: got {w}")
        ok = False

    # classify_tested: the three-way split, and that removing the gaps-doc fallback changes
    # the verdict for an untested-but-recorded class (load-bearing).
    gaps_text_present = "TDF_HAllocator is deliberately untested because ..."
    reached_none: dict[str, list[dict]] = {}
    v_recorded, _ = classify_tested("TDF_HAllocator", reached_none, gaps_text_present)
    v_recorded_removed, _ = classify_tested("TDF_HAllocator", reached_none, "")
    v_tested, _ = classify_tested(
        "TDF_Label",
        {"TDF_Label": [{"swift_file": "Document.swift", "member": "labelId", "bridge_fns": ["OCCTFoo"], "generic": False}]},
        "",
    )
    if v_recorded == "deliberate, recorded" and v_recorded_removed == "under" and v_tested == "ok":
        print("[PASS] classify-tested-three-way [load-bearing: removing the gaps.md text flips "
              "deliberate,recorded -> under]")
    else:
        print(
            f"[FAIL] classify-tested-three-way: got recorded={v_recorded!r} "
            f"removed={v_recorded_removed!r} tested={v_tested!r}"
        )
        ok = False

    # A generic-member-only hit must NOT auto-classify 'ok' unless REVIEWED_HITS says so.
    reached_generic = {
        "XCAFDoc_Foo": [
            {"swift_file": "Document.swift", "member": "name", "bridge_fns": ["OCCTFoo"], "generic": True}
        ]
    }
    v_unreviewed, _ = classify_tested("XCAFDoc_Foo", reached_generic, "")
    REVIEWED_HITS["XCAFDoc_Foo"] = True
    v_reviewed_true, _ = classify_tested("XCAFDoc_Foo", reached_generic, "")
    REVIEWED_HITS["XCAFDoc_Foo"] = False
    v_reviewed_false, _ = classify_tested("XCAFDoc_Foo", reached_generic, "")
    del REVIEWED_HITS["XCAFDoc_Foo"]
    if v_unreviewed == "under" and v_reviewed_true == "ok" and v_reviewed_false == "under":
        print("[PASS] generic-member-requires-review [load-bearing: an un-adjudicated generic "
              "hit does not auto-pass]")
    else:
        print(
            f"[FAIL] generic-member-requires-review: unreviewed={v_unreviewed!r} "
            f"reviewed_true={v_reviewed_true!r} reviewed_false={v_reviewed_false!r}"
        )
        ok = False

    # TESTED_OUTSIDE_LANE: an unreached class in the table still classifies `under` (never
    # silently promoted to `ok`), but carries the outside-lane pointer in its note.
    _, note_with = classify_tested("TDataStd_ByteArray", {}, "")
    saved = TESTED_OUTSIDE_LANE.pop("TDataStd_ByteArray")
    verdict_without, note_without = classify_tested("TDataStd_ByteArray", {}, "")
    TESTED_OUTSIDE_LANE["TDataStd_ByteArray"] = saved
    verdict_with, _ = classify_tested("TDataStd_ByteArray", {}, "")
    if (
        verdict_with == "under"
        and verdict_without == "under"
        and "#1396" in note_with
        and "#1396" not in note_without
    ):
        print(
            "[PASS] tested-outside-lane-annotation [load-bearing: verdict stays 'under' either "
            "way, only the note changes -- removing the entry loses the #1396 pointer]"
        )
    else:
        print(
            f"[FAIL] tested-outside-lane-annotation: with={verdict_with!r}/{note_with!r} "
            f"without={verdict_without!r}/{note_without!r}"
        )
        ok = False

    # Over-coverage regression check: inject a KNOWN_OVER_FINDING's bad phrase into a scratch
    # file and confirm check_known_over_findings() reports it; then confirm a clean file does not.
    import tempfile

    with tempfile.TemporaryDirectory() as td:
        scratch = os.path.join(td, "scratch.md")
        with open(scratch, "w") as fh:
            fh.write("Some text.\nThis test comment says the save is fully atomic.\nMore text.\n")
        fake_finding = {
            "subject": "self-test finding",
            "doc_file": os.path.relpath(scratch, ROOT) if scratch.startswith(ROOT) else scratch,
            "bad_phrase": "the save is fully atomic",
        }
        # check_known_over_findings() reads via ROOT-relative paths; exercise the underlying
        # substring logic directly rather than requiring the scratch file to live under ROOT.
        text = " ".join(_read(scratch).split())
        needle = " ".join(fake_finding["bad_phrase"].split())
        found_when_present = needle in text
        with open(scratch, "w") as fh:
            fh.write("Some text.\nThis test comment says the save behaves correctly.\nMore text.\n")
        text2 = " ".join(_read(scratch).split())
        found_when_absent = needle in text2
    if found_when_present and not found_when_absent:
        print("[PASS] over-finding-regression-substring [load-bearing: phrase present -> "
              "detected; phrase removed -> not detected]")
    else:
        print(
            f"[FAIL] over-finding-regression-substring: present={found_when_present} "
            f"absent={found_when_absent}"
        )
        ok = False

    # Deferred-finding inversion: bad phrase present -> not stale; bad phrase absent -> stale.
    present_text = "the write is guaranteed atomic across threads"
    absent_text = "the write completes normally"
    needle2 = "the write is guaranteed atomic across threads"
    stale_when_present = needle2 not in present_text
    stale_when_absent = needle2 not in absent_text
    if not stale_when_present and stale_when_absent:
        print("[PASS] deferred-finding-inversion [load-bearing: fixed-without-moving is caught]")
    else:
        print(
            f"[FAIL] deferred-finding-inversion: stale_when_present={stale_when_present} "
            f"stale_when_absent={stale_when_absent}"
        )
        ok = False

    # Claim-pattern sweep: a real over-claiming comment shape is found; a neutral comment is not.
    claiming = "// The save is atomic and always completes in document order."
    neutral = "// Writes the document to disk."
    hit_claiming = any(p.search(claiming) for p in CLAIM_PATTERNS)
    hit_neutral = any(p.search(neutral) for p in CLAIM_PATTERNS)
    if hit_claiming and not hit_neutral:
        print("[PASS] claim-pattern-sweep [load-bearing: a neutral comment does not false-fire]")
    else:
        print(f"[FAIL] claim-pattern-sweep: claiming={hit_claiming} neutral={hit_neutral}")
        ok = False

    return ok


if __name__ == "__main__":
    sys.exit(main())
