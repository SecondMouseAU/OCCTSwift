#!/usr/bin/env python3
"""Cross-reference the repo's static gate/census/audit suite against its own defect history (#819
Phase 6, item 3: "Gate script coverage of the gates").

#819's own framing said "six gates, one census and one merge audit" and warned that number is
already stale. It was: by the time this script was written the real count (derived from
`.github/workflows/ci.yml`'s `gate-scripts` job, not assumed) was eight gates, four censuses and one
merge-history audit, matching what `CLAUDE.md`'s "Static Gate Scripts" section currently says, but
matching it only because someone kept the two in sync by hand -- the same failure shape CLAUDE.md's
own patch-count paragraphs document repeatedly (see `Package.swift`'s comment history, #512/#1032,
and the 2026-08-17 same-session staleness). This script exists so that check does not have to be
redone by hand next time either.

Two things live here:

1. **A live enumeration** (`parse_gate_scripts_job()` + `classify()`) that parses `ci.yml`'s
   `gate-scripts` job directly, rather than trusting a hardcoded list, and classifies each script as a
   GATE (its bare run blocks CI unconditionally), a CENSUS (only `--self-test` runs in CI; the bare
   run never executes there and, when run by hand, always exits 0), or the one AUDIT
   (`check-changelog-transcription.py`: its bare run DOES execute in CI, but the script defines a
   `--strict` flag CI deliberately withholds, so it cannot fail the build today). That
   classification is derived structurally (self-test-only vs self-test-plus-bare, and whether a
   `--strict`-shaped flag exists and is withheld), not by matching English words in a comment, so it
   survives a comment being reworded. `--check` cross-references the live count against the
   sentence in `CLAUDE.md`'s own "Static Gate Scripts" section and fails if they disagree, and
   against `Scripts/*.py` actually present on disk, so a renamed or deleted script shows up as a
   dangling reference rather than silently vanishing from the count.

2. **A defect-class cross-reference** (`DEFECT_CLASSES`), hand-built from reading `CLAUDE.md`'s
   Known OCCT Bugs section in full, `docs/v2.0.0-plan.md`'s cluster descriptions, and a
   representative sample of the duplication-audit and correctness-cluster issues (see the README in
   this directory for exactly what fraction of the programme's 664 closed issues that sample is).
   For each defect class it records which current gate/census/audit (if any) would have caught a
   recurrence, and states plainly, with reasoning, when nothing would.

This is a repro-style artifact per `docs/v2.0.0-plan.md`'s rule ("build each census once, as a
committed executable artifact"), not a new CI gate: it is not wired into `ci.yml`, and running it
does not fail a build. `--check` is the one place it can exit 1, and it checks only its own
enumeration's self-consistency (live-derived count vs. `CLAUDE.md`'s stated count, and every
referenced script actually present on disk), not "is coverage good enough" -- that verdict is
qualitative and belongs in the README for a human to read, not in an exit code.

Usage (from anywhere; paths are derived from this file's location):

    python3 Scripts/repro/819-gate-coverage-audit/gate_coverage.py             # full report
    python3 Scripts/repro/819-gate-coverage-audit/gate_coverage.py --check     # enumeration only, exit 1 on drift
    python3 Scripts/repro/819-gate-coverage-audit/gate_coverage.py --self-test # prove the parser isn't blind
"""
from __future__ import annotations

import argparse
import glob
import os
import re
import sys
from dataclasses import dataclass, field

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
CI_YML = os.path.join(REPO_ROOT, ".github", "workflows", "ci.yml")
CLAUDE_MD = os.path.join(REPO_ROOT, "CLAUDE.md")
SCRIPTS_DIR = os.path.join(REPO_ROOT, "Scripts")


# ---------------------------------------------------------------------------
# 1. Live enumeration of the gate-scripts job
# ---------------------------------------------------------------------------

RUN_SCRIPT_RE = re.compile(r"run:\s*python3\s+Scripts/([A-Za-z0-9_\-]+)\.py(.*)$")
JOB_HEADER_RE = re.compile(r"^  ([A-Za-z_][A-Za-z0-9_-]*):\s*$")
STRICT_FLAG_RE = re.compile(r"""(['"])--strict\1""")


@dataclass
class ScriptSteps:
    name: str
    self_test_ran: bool = False
    bare_ran: bool = False
    bare_flags: list = field(default_factory=list)


def extract_job_block(ci_yml_text: str, job_name: str) -> str:
    """Return just the named top-level job's text (2-space-indented key to the next one, or EOF)."""
    lines = ci_yml_text.splitlines()
    start = None
    for i, line in enumerate(lines):
        m = JOB_HEADER_RE.match(line)
        if m and m.group(1) == job_name:
            start = i
            break
    if start is None:
        return ""
    end = len(lines)
    for i in range(start + 1, len(lines)):
        m = JOB_HEADER_RE.match(lines[i])
        if m:
            end = i
            break
    return "\n".join(lines[start:end])


def parse_gate_scripts_job(ci_yml_text: str, job_name: str = "gate-scripts") -> "dict[str, ScriptSteps]":
    """Parse every `run: python3 Scripts/<name>.py ...` line inside the named job.

    Pure function of the text handed to it (never reads `ci.yml` itself) so `--self-test` can feed
    it synthetic, deliberately-broken fixtures without touching the real workflow file.
    """
    block = extract_job_block(ci_yml_text, job_name)
    scripts: "dict[str, ScriptSteps]" = {}
    for line in block.splitlines():
        m = RUN_SCRIPT_RE.search(line)
        if not m:
            continue
        name, rest = m.group(1), m.group(2)
        entry = scripts.setdefault(name, ScriptSteps(name=name))
        flags = rest.split()
        if "--self-test" in flags:
            entry.self_test_ran = True
        else:
            entry.bare_ran = True
            entry.bare_flags = flags
    return scripts


def script_defines_strict_flag(path: str) -> bool:
    if not os.path.isfile(path):
        return False
    try:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return False
    return bool(STRICT_FLAG_RE.search(text))


def classify(scripts: "dict[str, ScriptSteps]", strict_flag_lookup) -> "dict[str, str]":
    """GATE / CENSUS / AUDIT, derived structurally rather than from a comment's wording.

    - Only `--self-test` runs in CI -> CENSUS (the bare run, if it exists at all as a local
      invocation, is documented to always exit 0; CI never even calls it).
    - Both run, and the script defines a `--strict`-shaped flag CI's bare invocation does NOT pass
      -> AUDIT (the bare run executes but is architecturally unable to fail the build today).
    - Both run, and either the script has no such flag or CI's invocation DOES pass it -> GATE.
    """
    kinds = {}
    for name, steps in scripts.items():
        if not steps.bare_ran:
            kinds[name] = "census"
            continue
        has_strict = strict_flag_lookup(name)
        strict_passed = "--strict" in steps.bare_flags
        if has_strict and not strict_passed:
            kinds[name] = "audit"
        else:
            kinds[name] = "gate"
    return kinds


def real_strict_flag_lookup(name: str) -> bool:
    return script_defines_strict_flag(os.path.join(SCRIPTS_DIR, name + ".py"))


def find_dangling_scripts(script_names, existing_names) -> list:
    """Scripts ci.yml references (bare name, no .py) that are absent from `existing_names` (also
    bare names). Shared by `run_check()` (against the real Scripts/ directory listing) and
    `--self-test` (against a synthetic fixture "directory listing"), so the self-test exercises
    the same function `--check` actually runs rather than a re-implementation of it."""
    existing = set(existing_names)
    return sorted(n for n in script_names if n not in existing)


# ---------------------------------------------------------------------------
# CLAUDE.md's own stated count, parsed the same way count-operations.py parses a headline
# ---------------------------------------------------------------------------

NUMBER_WORDS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
    "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
    "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
    "nineteen": 19, "twenty": 20,
}
_WORD = "|".join(NUMBER_WORDS)
CLAUDE_COUNT_RE = re.compile(
    rf"\b({_WORD})\s+gates?,\s+({_WORD})\s+census(?:es)?\s+and\s+({_WORD})\s+merge-history audit",
    re.IGNORECASE,
)


def parse_claude_md_count(text: str):
    """Return (gates, censuses, audits) parsed from the "Static Gate Scripts" headline sentence,
    or None if no such sentence is found at all (a stronger signal than a wrong number: the section
    was reworded away from this shape entirely)."""
    m = CLAUDE_COUNT_RE.search(text)
    if not m:
        return None
    return tuple(NUMBER_WORDS[w.lower()] for w in m.groups())


# ---------------------------------------------------------------------------
# 2. The defect-class cross-reference
# ---------------------------------------------------------------------------

# Disposition vocabulary, used consistently in both the script and the README:
#   gated              -- a current gate's bare run blocks a recurrence today.
#   census             -- a current census reports a recurrence for human adjudication; CI only
#                         proves the detector isn't blind (--self-test), the bare report never gates.
#   process-only        -- covered by written policy / code review discipline, not by any script.
#   not-gateable        -- fundamentally outside what a text-scanning Python script over this repo's
#                         own Sources/Tests/docs could ever check (vendored third-party C++ source,
#                         or a judgement call only a human/reviewer can make).
#   ungated-gap          -- gateable in principle, nothing does it today. Each such row states a
#                         disposition: proposed as future work, filed as an issue, or (rare) small
#                         and obvious enough to consider building directly.


@dataclass
class DefectClass:
    id: str
    name: str
    example_issues: str
    mechanism: str
    covered_by: str
    disposition: str
    notes: str


DEFECT_CLASSES = [
    # -- Bridge / Swift-source defect classes: mechanically gated today -------------------------
    DefectClass(
        id="bridge-index-drift",
        name="OCCTBridge.h class-to-symbol index entry stale, fabricated, or misfiled",
        example_issues="#510, #565, #618 (shared), #624/#630",
        mechanism="A cross-reference-index entry names a symbol that no longer exists, names a "
                   "real symbol that reaches a different class, or gets a direction check wrong.",
        covered_by="check-bridge-index.py",
        disposition="gated",
        notes="#624/#630 is also this project's own instance of 'the detector itself was wrong': "
              "the walk misparsed a template-headed helper and reported 7 correct entries as "
              "misfiled. Fixed and now in the --self-test fixture battery.",
    ),
    DefectClass(
        id="null-handle-guard",
        name="Bridge function dereferences a caller-supplied Curve3D/Curve2D/Surface Handle "
             "(or hands it to an OCCT call that does) with no null guard",
        example_issues="#478, #556, #618, #666/#656",
        mechanism="OCCTCurve3DRef/OCCTCurve2DRef/OCCTSurfaceRef wraps a Handle; the pointer can be "
                   "non-null while the Handle inside it is null, and OCCT often dereferences it "
                   "unconditionally -- an uncatchable OS signal, not something `catch (...)` stops.",
        covered_by="check-null-handle-guards.py",
        disposition="gated",
        notes="Documents its own residual blind spots (a reference-bound alias, a discarded or "
              "non-dominating guard, a negated guard, a helper that guards only some paths) -- see "
              "the script's own docstring, not repeated here.",
    ),
    DefectClass(
        id="shape-deref-guard",
        name="Bridge function dereferences a caller-supplied TopoDS_Shape wrapper (or an OCCT "
             "entry point that dereferences the shape internally) with no presence/type guard",
        example_issues="#1026, #1035",
        mechanism="A null TopoDS_Shape is safe through most of the bridge (copy, cast, TopExp) but "
                   "not through ShapeType()/the eight flag accessors/EmptyCopy(), and not through "
                   "61 measured OCCT entry points that dereference it for the caller.",
        covered_by="check-null-handle-guards.py (SHAPE_* walk)",
        disposition="gated",
        notes="Same script as the row above, a third independent walk with its own ALLOWED table.",
    ),
    DefectClass(
        id="borrowed-handle",
        name="A Swift struct/enum (value type, no deinit) stores an OCCT handle it does not own",
        example_issues="#965",
        mechanism="A value-type view holding `let handle: OCCT*Ref` can outlive the owner that "
                   "would have released it, producing a dangling read (measured: read 1001.0 where "
                   "7.0 was expected) or a SIGSEGV.",
        covered_by="check-borrowed-handles.py",
        disposition="gated",
        notes="Does not verify a class's own deinit actually releases correctly, only that the "
              "handle-storing type is reference, not value.",
    ),
    DefectClass(
        id="doc-default-drift",
        name="A docs/reference/ page restates a default value that no longer matches the "
             "declaration",
        example_issues="#491 (the drift), #626 (the detector's own first miss), #572",
        mechanism="docs/reference/ pages restate a Swift signature by hand in a fenced code block; "
                   "the restatement is a copy and copies drift.",
        covered_by="check-docs-defaults.py",
        disposition="gated",
        notes="#626 is 'the detector itself was wrong' again: the first version resolved a "
              "duplicate-named method (Shape.writeOBJ vs Document.writeOBJ) to the wrong "
              "declaration and let the #626 shape pass through the gate built to catch it.",
    ),
    DefectClass(
        id="doc-existence-drift",
        name="docs/ documents a symbol as current API that no longer exists in Sources/",
        example_issues="#802",
        mechanism="A removed/renamed symbol left an orphaned doc heading or prose mention.",
        covered_by="check-docs-existence.py",
        disposition="gated",
        notes="Bare (undotted) headings are checked only for existence anywhere in the tree, not "
              "against their guessed owning type, by measured design choice (946 false candidates "
              "when tried strictly).",
    ),
    DefectClass(
        id="bridge-header-split-drift",
        name="A bridge C-function declaration lives in the wrong per-domain header, or maps to "
             "more/fewer than exactly one .mm definer",
        example_issues="#395 (original split), #673 (misfiled check added)",
        mechanism="16 per-domain headers, one .mm file (or bucket of .mm files) should own each "
                   "declared symbol; hand-added declarations drift from that over time.",
        covered_by="derive-bridge-header-split.py --verify",
        disposition="gated",
        notes=None,
    ),
    DefectClass(
        id="gdt-enum-drift",
        name="A hand-transcribed GD&T Swift enum drifts from the pinned OCCT "
             "XCAFDimTolObjects headers (member added/removed/reordered/renamed/wrong ordinal)",
        example_issues="#996",
        mechanism="Raw OCCT enum values cross the bridge unremapped, so member order is "
                   "load-bearing, not just membership.",
        covered_by="derive-gdt-enums.py --verify",
        disposition="gated",
        notes="Only the Swift-vs-committed-manifest half runs in CI. The manifest-vs-live-headers "
              "half (--reverify-headers) needs Libraries/OCCT.xcframework and SKIPS (reports "
              "success trivially) in CI and in a fresh clone -- an OCCT version bump that changes "
              "an enum is invisible to CI until someone runs that half locally.",
    ),
    DefectClass(
        id="operation-count-drift",
        name="README.md / docs/API_REFERENCE.md / docs/index.md's stated operation-count "
             "headline drifts from the derived count",
        example_issues="#289 (original desync, 882 off across 11 releases), #899/#902, #914",
        mechanism="Three hand-maintained headline numbers, one derived truth.",
        covered_by="count-operations.py",
        disposition="gated",
        notes="docs/occtswift-wrapping-gaps.md and docs/integration-tests.md's own operation-count "
              "prose sit outside this gate entirely -- named explicitly in CLAUDE.md's Release "
              "Process section as still uncovered.",
    ),
    # -- Values/attribution/comments: covered by a CENSUS (human adjudicates, CI proves the -----
    # -- detector isn't blind, the bare report never blocks a merge) ----------------------------
    DefectClass(
        id="fabricated-measurement",
        name="A value is returned/published as though measured, but is actually a hardcoded "
             "literal, an unverified test count-pin, a gate flag that never flips true, or a "
             "reading taken off a subject the caller's own input never reached",
        example_issues="#726 (the census), seeded by #609 (zero-mass reported as the answer), "
                       "#583, #595, #763/#771 (hasExtent), #703",
        mechanism="Four independent sub-kinds (production literal-vs-computed sibling, unverified "
                   "test count-pin, a gate flag with no live true-path, an unfed/echoed subject); "
                   "each with its own fixture battery.",
        covered_by="census-unmeasured-values.py (CENSUS)",
        disposition="census",
        notes="Documented blind spots per sub-kind include a kernel-side fabrication (#999's "
              "OCCTGeomPlateErrors shape), the #996 GD&T range-dimension shape (real accessor, "
              "wrong applicability), and no Swift-side sweep at all for sub-kind 4. #765 (open) is "
              "the standing spike asking exactly 'can the narrow form become a gate' -- this row "
              "does not reopen that question, it points at it.",
    ),
    DefectClass(
        id="doc-occt-overattribution",
        name="Documentation attributes a wrapped operation to an OCCT class the bridge function "
             "never actually reaches",
        example_issues="#928 (the detector), #807/#808/#809 (the audit it backs)",
        mechanism="A `- **OCCT:**` bullet, bridge-header doc comment, or API_REFERENCE row names "
                   "a class the named symbol's call graph doesn't reach.",
        covered_by="census-doc-occt-attribution.py (CENSUS)",
        disposition="census",
        notes="Measured 41% false-positive rate over a 40-row hand-adjudicated sample -- "
              "explicitly 'a floor on the over-coverage in a lane, never a proof there is none.' "
              "The class-existence half needs Libraries/OCCT.xcframework and SKIPS in CI.",
    ),
    DefectClass(
        id="tuple-shape-toolchain-defect",
        name="A @Test(arguments:) element pairs a reference-counted member with a builtin SIMD "
             "vector >=32 bytes, corrupting the Swift task allocator regardless of the test body",
        example_issues="#1057 (swiftlang/swift#91639)",
        mechanism="A toolchain defect, not this repo's or OCCT's; the pairing is necessary but "
                   "proven NOT sufficient (some larger pairings run clean, the exact cut isn't "
                   "characterised).",
        covered_by="census-arguments-tuple-shapes.py (CENSUS)",
        disposition="census",
        notes="Deliberately reports `unknown` (9/33 real sites) rather than guessing; even a "
              "resolved 'clean' verdict is not a proof of safety for an untested layout.",
    ),
    DefectClass(
        id="comment-staleness",
        name="A comment (Sources/ ///, // ; Scripts/*.py docstring usage line; CLAUDE.md "
             "patch-number citation) names a symbol/flag/patch file that no longer resolves",
        example_issues="#872",
        mechanism="Four independent, mechanically-checkable sub-channels.",
        covered_by="census-comment-staleness.py (CENSUS)",
        disposition="census",
        notes="Explicitly does NOT re-verify CLAUDE.md's Known-OCCT-Bugs narrative claims ('fixed "
              "upstream in vX.Y.Z') against live GitHub/OCCT state, and does not check described "
              "*behavior* (a stated default, a claimed fallback) -- only symbol/flag/file "
              "existence. See feedback-verify-external-status-claims for why the former is "
              "deliberately out of scope for a script.",
    ),
    DefectClass(
        id="changelog-transcription-gap",
        name="A merged PR's CHANGELOG entry (written in the PR body) never lands in "
             "docs/CHANGELOG.md",
        example_issues="#742, #788, #1125",
        mechanism="changelog-on-merge.md's process depends on a human/agent remembering to "
                   "transcribe at merge time.",
        covered_by="check-changelog-transcription.py",
        disposition="audit",
        notes="Bare run executes in CI (unlike a true census) but --strict, which would let it "
              "fail the build, is deliberately withheld: measured 3 legitimately-entry-free merges "
              "on this branch, so gating today would fail CI for correct behaviour. CLAUDE.md "
              "records the promotion criterion (a run of real merges with no false positives) as "
              "not yet met.",
    ),
    # -- Detector-quality: process-gated only ----------------------------------------------------
    DefectClass(
        id="detector-itself-wrong",
        name="A gate/census script's own detection logic has a blind spot (false negative) or "
             "misfires on correct code (false positive)",
        example_issues="#618 (check-null-handle-guards, false negative, blind to 4 indirection "
                       "shapes), #624/#630 (check-bridge-index, false positive, misparsed a "
                       "template head), #626 (check-docs-defaults, false negative, resolved a "
                       "duplicate-named method wrongly) -- plus, in now-retired investigation "
                       "tooling never wired into CI, derive-shape-domain-split.py's --self-test "
                       "passing 6/6 twice while a case proved nothing "
                       "(okf/policies/prove-the-test-fails.md), and derive-swift-file-split.py "
                       "missing every top-level free func (#659)",
        mechanism="The detector for THIS class is `--self-test`: a fixture battery, per script, "
                   "proving each known failure mode is caught. It is a PROCESS requirement "
                   "(okf/policies/prove-the-test-fails.md), enforced by code review and CI running "
                   "every self-test, not by any script that audits a new detector's self-test "
                   "quality before merge.",
        covered_by="Every current gate/census/audit's own --self-test (14/14, including this "
                   "script's)",
        disposition="process-only",
        notes="Nothing here catches a FIFTH such defect in a gate not yet built, or a self-test "
              "whose removal-matrix case looks like coverage but proves nothing (the exact trap "
              "prove-the-test-fails.md documents twice for derive-shape-domain-split.py). This "
              "audit's own --self-test is written under that same policy; see this directory's "
              "README for the removal matrix.",
    ),
    # -- OCCT kernel (vendored C++ source): not gateable by any of these scripts -----------------
    DefectClass(
        id="kernel-data-race",
        name="Unsynchronized static/global/member state inside OCCT's own (vendored) C++ "
             "implementation, live under ordinary concurrent bridge use",
        example_issues="#298, #341, #344, #349, #353, #363, #371, #374, #1154, #1153, #1371, #1157 "
                       "(12 distinct root-caused races)",
        mechanism="A lazily-initialized singleton, an unguarded NCollection container, a "
                   "check-then-act cache handle, an unsynchronized bitfield -- found only by "
                   "building a minimal-module TSan instrumentation of the kernel and driving a "
                   "concurrent reproducer through it.",
        covered_by="Scripts/tsan-stress.sh (ThreadSanitizer) -- a SEPARATE mechanism entirely, not "
                   "a gate-scripts CI job entry, no --self-test, needs a from-source kernel "
                   "rebuild under instrumentation",
        disposition="not-gateable",
        notes="None of the 13 gate-scripts-job scripts reads Libraries/occt-src or "
              "Libraries/OCCT.xcframework's C++ implementation at all; they parse "
              "Sources/OCCTSwift, Sources/OCCTBridge, Tests/, docs/, README, CHANGELOG, and "
              "Package.swift/CLAUDE.md prose. A static Python text scanner cannot detect a data "
              "race; it needs a real concurrent execution under instrumentation. TSan is real "
              "coverage for this class, but it is not what 'gate-scripts' means in this repo, and "
              "it does not run on every PR (Scripts/tsan-stress.sh is invoked deliberately, not "
              "via ci.yml's gate-scripts job).",
    ),
    DefectClass(
        id="kernel-uncatchable-crash",
        name="An unguarded null-handle/pointer dereference or uninitialized read inside OCCT's "
             "own algorithm implementation, reached from specific (often edge-case) input",
        example_issues="#176, #310, #317, #318, #348, #430 (2nd half), #643, #905, #913, #1018, "
                       "#1022 (crash half) -- eleven distinct root-caused kernel crashes",
        mechanism="Found exclusively via targeted manual reproduction: a ground-truth C++ harness, "
                   "an ASan/debug-build backtrace, or override-linking a patched translation unit "
                   "ahead of the production archive.",
        covered_by="none",
        disposition="not-gateable",
        notes="Architecturally out of reach for a text-scanning script the same way as the row "
              "above: the defect lives in vendored third-party source these scripts never read. "
              "A regression test guards the FIX once found (e.g. Issue176LoftPolarTests); nothing "
              "guards against the next unrelated one.",
    ),
    DefectClass(
        id="kernel-silent-wrong-answer",
        name="OCCT's own implementation reports IsDone()/success while the computed geometry or "
             "reported error is silently incorrect",
        example_issues="#522 (Jacobi workspace slot), #532 (part selection), #597 (error "
                       "overwritten with the request), #603 (single-span quadrature), #905 "
                       "(Closed(true) without both caps), #913 (silent stride misalignment), "
                       "#1018 (uninitialized error accessors)",
        mechanism="Same 'vendored C++ source' reach problem as the crash row, compounded: nothing "
                   "even signals failure, so these were found only by cross-checking two "
                   "independent measurements of the same geometry (e.g. #603's BRepGProp vs. "
                   "CPnts disagreement) or by probing internals with a debug build.",
        covered_by="none",
        disposition="not-gateable",
        notes="The single riskiest class in the whole history to leave unguarded, precisely "
              "because nothing about the call signals a problem -- IsDone() is true and the "
              "caller has no reason to suspect the geometry.",
    ),
    DefectClass(
        id="proposed-kernel-patch-defect",
        name="A defect in a PROPOSED kernel patch itself, found only by careful review",
        example_issues="#1153 (PR #1322's first attempt: wrapped BSplCLib_Cache in a "
                       "non-recursive mutex; D1/D2/D3 call back into a *Local overload that "
                       "locks the same mutex again on the same thread -- a guaranteed "
                       "self-deadlock on the very first derivative call, single-threaded, no "
                       "concurrency needed to observe it)",
        mechanism="Human/agent code review of C++ source, not any mechanical check.",
        covered_by="none, and cannot be",
        disposition="not-gateable",
        notes="Explicitly the kind of finding this audit should name plainly rather than force a "
              "gate for: none of these scripts read Scripts/patches/*.patch content at all, only "
              "filenames/counts.",
    ),
    # -- Genuinely uncovered, but at least partly gateable in principle --------------------------
    DefectClass(
        id="missing-throw-guard",
        name="A bridge function constructs/evaluates something OCCT can throw on (gp_Dir, "
             "gp_Ax1/2/3, Geom_Direction, a D0/D1/D2 derivative evaluator) with no enclosing "
             "try/catch anywhere in the call chain",
        example_issues="#345 (49 sites found by manual audit), the general Test Conventions rule "
                       "('wrap OCCT calls that may throw in try-catch')",
        mechanism="An uncaught C++ exception crossing the bridge's extern-C-ish boundary into "
                   "Swift-generated call frames has no matching unwind personality routine -- a "
                   "guaranteed std::terminate()/abort() (SIGABRT), with almost no diagnostic "
                   "trail.",
        covered_by="none",
        disposition="ungated-gap",
        notes="check-null-handle-guards.py is about null HANDLES, a different failure mode from a "
              "VALID handle whose value happens to throw on construction (a near-zero-length "
              "vector). Plausibly gateable (a known-throwing-constructor list plus a "
              "'is this call site lexically inside a try block' scope tracker), but that is "
              "comparable in build cost to check-null-handle-guards.py itself -- not 'small and "
              "obviously correct'. Filed as #1407, not built here; see README.",
    ),
    DefectClass(
        id="semantic-duplication",
        name="Independently reimplemented logic, parallel primitives, or drifted copies spread "
             "across the Swift/bridge codebase",
        example_issues="#377 (the whole programme), #380/#381 (Pass 1a/1b), #382-#392 (lane "
                       "passes 2a-5d), #490 (19->3 continuity decoders), #502 (MapShapes "
                       "duplicate spelling), #443 (first-of-N idiom), #446 (unify mutates its "
                       "input), #724/#733/#762 (detectPocketsAAG), #791/#792/#794/#795 (bridge "
                       "wrapper-pair duplication), #881/#899/#903/#908 (axis/perpendicular-basis "
                       "dedup), #784/#1391 (full-tree rescans)",
        mechanism="Judgement-heavy: two implementations that LOOK different but do the same "
                   "thing, or a naming collision that hides an identical traversal (#502's "
                   "MapShapes).",
        covered_by="bridge-duplication-audit / duplication-audit (project SKILLS -- LLM-driven "
                   "subagent workflows run periodically/manually: Pass 1a/1b, the #784/#1391 "
                   "rescans), plus Scripts/repro/784-duplication-rescan/detect-duplicate-logic.py "
                   "(a one-off scan tool for that specific rescan, not a standing CI gate)",
        disposition="ungated-gap",
        notes="The least self-test-disciplined mechanism this audit found: no --self-test, no "
              "gate-scripts entry, not wired into ci.yml at all. #792 already measured the "
              "rescan's shingle threshold blind to a one-line duplication whose call syntax "
              "differs. Not proposed as a new automated gate here: the whole reason this class "
              "needs judgement is why the programme built a periodic AGENT-driven audit for it "
              "rather than a mechanical script, and that is very likely still the right call.",
    ),
    DefectClass(
        id="stale-self-referential-count",
        name="A hand-maintained count in CLAUDE.md/Package.swift's own prose drifts from what "
             "`ls Scripts/patches/*.patch | wc -l` (or an equivalent live count) actually says",
        example_issues="Self-documented in CLAUDE.md's Project Summary; recurred at v2.0.0-kernel."
                       "1->.2->.3, at #1032, and again within a single session at #1157/#1402 -- "
                       "CLAUDE.md's own patch-count paragraph names itself as 'the proof the "
                       "count check matters' after going stale the moment #1371's patch landed. "
                       "#1066 (open) is an INDEPENDENT, still-live instance of the same class: "
                       "ci.yml's gate-scripts comment block states 'all five'/'three of the "
                       "five' against a job that measurably runs thirteen scripts today, and the "
                       "exact sentence #1066 flagged is still in ci.yml as of this audit.",
        mechanism="An English sentence stating a number, rewritten by hand every time the number "
                   "changes, with no derivation step forcing agreement.",
        covered_by="count-operations.py covers exactly ONE instance of this general pattern (the "
                   "operation-count headline); nothing covers the Scripts/patches/ count vs. "
                   "CLAUDE.md prose vs. Package.swift's own comment, or ci.yml's own comment "
                   "block against its own step count (#1066)",
        disposition="ungated-gap",
        notes="Genuinely gateable in principle (compare `ls Scripts/patches/*.patch | wc -l` "
              "against a number parsed out of CLAUDE.md prose and Package.swift's comment), but "
              "NOT judged 'small and obviously correct' to build in this PR: parsing an arbitrary "
              "English number word out of prose that gets reworded every time it drifts (as this "
              "very paragraph has been, repeatedly) is fragile in exactly the way "
              "count-operations.py's regex-on-a-fixed-headline-format is not. This script's own "
              "CLAUDE_COUNT_RE above is a small demonstration of the same fragility, scoped to "
              "one sentence whose wording this audit controls. Filed as #1408, not built here; "
              "see README.",
    ),
    DefectClass(
        id="stale-tsan-suppression",
        name="A ThreadSanitizer suppression in Scripts/tsan.supp whose named fix has already "
             "shipped in the pinned kernel, left un-retired past its own 'MUST be removed when "
             "the fix lands' policy",
        example_issues="#1154 (TopoDS_TShape::myState, the nine race:TopoDS_TShape::* entries "
                       "currently open) is the live example of the state this policy warns "
                       "about: patch 0030 exists, is override-link-validated, but is not yet in "
                       "a rebuilt xcframework, so the suppression is correctly still in place. "
                       "Filed as #1409 -- a sub-finding of this audit, not previously tracked.",
        mechanism="Scripts/tsan.supp's own header states every open-finding entry needs a "
                   "removal condition and MUST be removed once the fix ships; nothing currently "
                   "checks that against reality.",
        covered_by="none",
        disposition="ungated-gap",
        notes="Half of this is mechanical (cross-reference tsan.supp's cited patch numbers "
              "against Scripts/patches/*.patch presence) but the half that actually matters -- "
              "does the PINNED release asset carry that patch -- is not something any current "
              "script determines either; Package.swift only pins a URL+checksum. Resolving that "
              "needs one of the manual verification techniques CLAUDE.md's Project Summary "
              "already describes (string-literal grep, override-link test, kernel-integration.yml "
              "run), not a Python-text-only check. Filed as #1409, not built here.",
    ),
]


def summarize_dispositions():
    counts = {}
    for d in DEFECT_CLASSES:
        counts[d.disposition] = counts.get(d.disposition, 0) + 1
    return counts


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def render_enumeration(scripts, kinds):
    order = sorted(scripts, key=lambda n: (kinds[n], n))
    lines = []
    for kind in ("gate", "census", "audit"):
        names = [n for n in order if kinds[n] == kind]
        lines.append(f"{kind.upper()} ({len(names)}):")
        for n in names:
            s = scripts[n]
            flag_str = " ".join(s.bare_flags) if s.bare_flags else ""
            lines.append(f"  - {n}{(' ' + flag_str) if flag_str else ''}")
    return "\n".join(lines)


def render_defect_table():
    lines = []
    for d in DEFECT_CLASSES:
        lines.append(f"[{d.disposition}] {d.id}: {d.name}")
        lines.append(f"    issues: {d.example_issues}")
        lines.append(f"    covered by: {d.covered_by}")
    return "\n".join(lines)


def run_report(quiet=False):
    with open(CI_YML, "r", encoding="utf-8") as fh:
        ci_text = fh.read()
    scripts = parse_gate_scripts_job(ci_text)
    kinds = classify(scripts, real_strict_flag_lookup)
    counts = {"gate": 0, "census": 0, "audit": 0}
    for k in kinds.values():
        counts[k] += 1

    if not quiet:
        print("=== Live enumeration (from .github/workflows/ci.yml's gate-scripts job) ===")
        print(render_enumeration(scripts, kinds))
        print()
        print(f"Total: {counts['gate']} gates, {counts['census']} censuses, "
              f"{counts['audit']} merge-history audit(s), {len(scripts)} scripts overall.")
        print()
        print("=== Defect-class cross-reference ===")
        print(render_defect_table())
        print()
        disp = summarize_dispositions()
        print("Disposition summary: " + ", ".join(f"{k}={v}" for k, v in sorted(disp.items())))
    else:
        print(f"{counts['gate']} gates, {counts['census']} censuses, "
              f"{counts['audit']} merge-history audit(s), {len(scripts)} scripts overall.")
    return scripts, kinds


def run_check() -> int:
    """Exit 1 if the live enumeration disagrees with CLAUDE.md's own stated count, or if any
    script ci.yml references is missing on disk. This is the one place this artifact behaves like
    a gate; everything else here is a report for a human to read."""
    problems = []

    with open(CI_YML, "r", encoding="utf-8") as fh:
        ci_text = fh.read()
    scripts = parse_gate_scripts_job(ci_text)
    kinds = classify(scripts, real_strict_flag_lookup)
    counts = {"gate": 0, "census": 0, "audit": 0}
    for k in kinds.values():
        counts[k] += 1

    with open(CLAUDE_MD, "r", encoding="utf-8") as fh:
        claude_text = fh.read()
    stated = parse_claude_md_count(claude_text)
    if stated is None:
        problems.append("CLAUDE.md's 'Static Gate Scripts' section no longer states a "
                         "'N gates, M censuses and K merge-history audit' sentence in the shape "
                         "this script parses -- update CLAUDE_COUNT_RE or check the section by "
                         "hand.")
    elif stated != (counts["gate"], counts["census"], counts["audit"]):
        problems.append(
            f"CLAUDE.md states ({stated[0]} gates, {stated[1]} censuses, {stated[2]} audit) but "
            f"ci.yml's gate-scripts job derives ({counts['gate']} gates, {counts['census']} "
            f"censuses, {counts['audit']} audit) -- one of the two has drifted."
        )

    existing = {
        os.path.splitext(os.path.basename(p))[0]
        for p in glob.glob(os.path.join(SCRIPTS_DIR, "*.py"))
    }
    for name in find_dangling_scripts(scripts.keys(), existing):
        problems.append(f"ci.yml's gate-scripts job references Scripts/{name}.py, which does "
                         f"not exist on disk (renamed or deleted without updating ci.yml?)")

    if problems:
        for p in problems:
            print(f"DRIFT: {p}")
        return 1
    print(f"OK: live enumeration ({counts['gate']} gates, {counts['census']} censuses, "
          f"{counts['audit']} audit) matches CLAUDE.md's stated count, and every referenced "
          f"script exists on disk.")
    return 0


# ---------------------------------------------------------------------------
# --self-test
# ---------------------------------------------------------------------------

def _fixture(job_body: str, job_name: str = "gate-scripts") -> str:
    return (
        "name: CI\n\n"
        "jobs:\n"
        f"  {job_name}:\n"
        "    runs-on: ubuntu-latest\n"
        "    steps:\n"
        f"{job_body}\n"
        "  build-and-test:\n"
        "    runs-on: macos-15\n"
        "    steps:\n"
        "      - run: echo unrelated job, must not be scanned\n"
    )


def _gate_step(name: str, extra_bare_flags: str = "") -> str:
    return (
        f"      - name: {name}.py --self-test\n"
        f"        run: python3 Scripts/{name}.py --self-test\n\n"
        f"      - name: {name}.py\n"
        f"        run: python3 Scripts/{name}.py{extra_bare_flags}\n"
    )


def _census_step(name: str) -> str:
    return (
        f"      - name: {name}.py --self-test\n"
        f"        run: python3 Scripts/{name}.py --self-test\n"
    )


CLEAN_GATES = [f"gate{i}" for i in range(1, 9)]      # 8 gate-shaped scripts
CLEAN_CENSUSES = [f"census{i}" for i in range(1, 5)]  # 4 census-shaped scripts
CLEAN_AUDIT = "audit1"                                # 1 audit-shaped script


def _clean_fixture_body():
    parts = [_gate_step(n) for n in CLEAN_GATES]
    parts += [_census_step(n) for n in CLEAN_CENSUSES]
    parts.append(_gate_step(CLEAN_AUDIT))  # audit's bare run looks identical to a gate's in ci.yml
    return "\n".join(parts)


def _clean_strict_lookup(name: str) -> bool:
    return name == CLEAN_AUDIT  # only the audit script defines --strict


def self_test() -> bool:
    failures = []

    # --- Case A: clean fixture, structurally identical to the real gate-scripts job today -----
    ci_text = _fixture(_clean_fixture_body())
    scripts = parse_gate_scripts_job(ci_text)
    kinds = classify(scripts, _clean_strict_lookup)
    counts = {"gate": 0, "census": 0, "audit": 0}
    for k in kinds.values():
        counts[k] += 1
    if len(scripts) != 13 or counts != {"gate": 8, "census": 4, "audit": 1}:
        failures.append(f"CLEAN fixture: expected 13 scripts / 8 gate / 4 census / 1 audit, "
                         f"got {len(scripts)} scripts / {counts}")
    if kinds.get(CLEAN_AUDIT) != "audit":
        failures.append("CLEAN fixture: the --strict-defining, --strict-withheld script was not "
                         "classified 'audit'")
    # Must NOT scan the unrelated build-and-test job.
    if "run: echo unrelated job" in "\n".join(scripts.keys()):
        failures.append("CLEAN fixture: leaked a line from an unrelated job")

    # --- Case B: a gate silently removed from the job (the #819 worry: renamed/added/removed) -
    body = "\n".join(_gate_step(n) for n in CLEAN_GATES[:-1])  # drop gate8 entirely
    body += "\n" + "\n".join(_census_step(n) for n in CLEAN_CENSUSES)
    body += "\n" + _gate_step(CLEAN_AUDIT)
    scripts_b = parse_gate_scripts_job(_fixture(body))
    kinds_b = classify(scripts_b, _clean_strict_lookup)
    counts_b = {"gate": 0, "census": 0, "audit": 0}
    for k in kinds_b.values():
        counts_b[k] += 1
    if "gate8" in scripts_b or counts_b["gate"] != 7:
        failures.append(f"REMOVED-GATE fixture: expected gate8 gone and 7 gates total, "
                         f"got {sorted(scripts_b)} / {counts_b}")

    # --- Case C: a script renamed in ci.yml (both its self-test and bare lines) ----------------
    renamed_body = _clean_fixture_body().replace("gate1", "gate1-renamed")
    scripts_c = parse_gate_scripts_job(_fixture(renamed_body))
    if "gate1" in scripts_c:
        failures.append("RENAMED-SCRIPT fixture: old name 'gate1' still present after rename")
    if "gate1-renamed" not in scripts_c:
        failures.append("RENAMED-SCRIPT fixture: new name 'gate1-renamed' not picked up")
    # This is exactly what --check's disk-existence pass turns into a reported drift: a fixture
    # "disk" containing only the OLD name would report the new one as a dangling reference.
    fixture_disk = set(CLEAN_GATES + CLEAN_CENSUSES + [CLEAN_AUDIT])  # note: NOT gate1-renamed
    dangling = [n for n in scripts_c if n not in fixture_disk]
    if dangling != ["gate1-renamed"]:
        failures.append(f"RENAMED-SCRIPT fixture: expected exactly ['gate1-renamed'] to be "
                         f"dangling against the old file list, got {dangling}")

    # --- Case D: a brand-new script's steps added, unclassified anywhere else ------------------
    added_body = _clean_fixture_body() + "\n" + _gate_step("gate9-new")
    scripts_d = parse_gate_scripts_job(_fixture(added_body))
    if "gate9-new" not in scripts_d or len(scripts_d) != 14:
        failures.append(f"NEW-SCRIPT fixture: expected 14 scripts including gate9-new, "
                         f"got {len(scripts_d)}: {sorted(scripts_d)}")

    # --- Case E: a census-shaped script grows a bare run (no --strict) -> must reclassify as ---
    # --- 'gate', proving the classifier is live-derived, not trusting a fixed label ------------
    mislabeled_body = _clean_fixture_body().replace(
        _census_step("census1"), _gate_step("census1")
    )
    scripts_e = parse_gate_scripts_job(_fixture(mislabeled_body))
    kinds_e = classify(scripts_e, _clean_strict_lookup)
    if kinds_e.get("census1") != "gate":
        failures.append(f"MISLABELED fixture: census1 grew a bare run with no --strict and "
                         f"should reclassify as 'gate', got {kinds_e.get('census1')!r}")

    # --- Case F: the audit script's bare run gains --strict -> must reclassify as 'gate' -------
    strict_body = _clean_fixture_body().replace(
        f"run: python3 Scripts/{CLEAN_AUDIT}.py\n", f"run: python3 Scripts/{CLEAN_AUDIT}.py --strict\n"
    )
    scripts_f = parse_gate_scripts_job(_fixture(strict_body))
    kinds_f = classify(scripts_f, _clean_strict_lookup)
    if kinds_f.get(CLEAN_AUDIT) != "gate":
        failures.append(f"STRICT-PASSED fixture: {CLEAN_AUDIT} with --strict now passed should "
                         f"reclassify as 'gate', got {kinds_f.get(CLEAN_AUDIT)!r}")

    # --- Case G: parse_claude_md_count ----------------------------------------------------------
    correct = "blah blah Eight gates, four censuses and one merge-history audit, all pure Python"
    if parse_claude_md_count(correct) != (8, 4, 1):
        failures.append(f"CLAUDE-COUNT fixture (correct): expected (8, 4, 1), "
                         f"got {parse_claude_md_count(correct)}")

    stale = "Six gates, one census and one merge-history audit exist now"  # #819's own stale claim
    if parse_claude_md_count(stale) != (6, 1, 1):
        failures.append(f"CLAUDE-COUNT fixture (#819's own stale wording): expected (6, 1, 1), "
                         f"got {parse_claude_md_count(stale)}")

    two_digit = "Twelve gates, three censuses and one merge-history audit"
    if parse_claude_md_count(two_digit) != (12, 3, 1):
        failures.append(f"CLAUDE-COUNT fixture (two-digit word): expected (12, 3, 1), "
                         f"got {parse_claude_md_count(two_digit)}")

    missing = "This section no longer states a count sentence at all."
    if parse_claude_md_count(missing) is not None:
        failures.append(f"CLAUDE-COUNT fixture (absent): expected None, "
                         f"got {parse_claude_md_count(missing)}")

    # --- Case H: find_dangling_scripts() (the exact function --check calls) reports the renamed
    # script as dangling against a fixture "disk listing" that only has the old name, and reports
    # nothing at all when the fixture listing is complete.
    old_disk = fixture_disk  # has 'gate1', not 'gate1-renamed'
    dangling = find_dangling_scripts(scripts_c.keys(), old_disk)
    if dangling != ["gate1-renamed"]:
        failures.append(f"DANGLING-REFERENCE check: expected only 'gate1-renamed' reported "
                         f"against a disk listing missing it, got {dangling}")
    complete_disk = old_disk | {"gate1-renamed"}
    if find_dangling_scripts(scripts_c.keys(), complete_disk):
        failures.append("DANGLING-REFERENCE check: false positive against a complete disk listing")

    if failures:
        for f in failures:
            print(f"SELF-TEST FAILURE: {f}")
        return False
    print("SELF-TEST: OK (8 cases: clean enumeration, gate removed, script renamed, script "
          "added, census-grows-a-gate reclassification, audit-gains---strict reclassification, "
          "CLAUDE.md count parsing incl. a two-digit word and an absent sentence, dangling "
          "reference against a fixture disk listing)")
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--self-test", action="store_true", help="prove the parser isn't blind")
    ap.add_argument("--check", action="store_true",
                     help="exit 1 only if the live enumeration disagrees with CLAUDE.md's stated "
                          "count, or a referenced script is missing on disk")
    ap.add_argument("--quiet", action="store_true", help="with the default report, print only "
                                                           "the summary line")
    args = ap.parse_args()

    if args.self_test:
        return 0 if self_test() else 1
    if args.check:
        return run_check()

    run_report(quiet=args.quiet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
