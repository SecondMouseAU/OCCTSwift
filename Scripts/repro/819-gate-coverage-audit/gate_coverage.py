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
   survives a comment being reworded. #2196 added a fourth kind, the RELEASE CHECK: self-test-only
   like a census, because its real run needs an input this job does not have, and reaching a
   verdict rather than a list. **#2960**: a census is recognised by its `census-` name prefix
   BEFORE either of the other two tests, as the gated `Scripts/check-inventory-prose.py` has always
   done. Keying on the `--require-...` flag instead, which this script did from #2196 until #2960,
   reclassified every census that grew one, and two had: this artifact then reported a drift that
   did not exist against a counting sentence that was correct. The counting sentence covers the
   first three kinds; `--check` holds it to those and prints the fourth beside it. `--check`
   cross-references
   the live count against that sentence and fails if they disagree, and against `Scripts/*.py`
   actually present on disk, so a renamed or deleted script shows up as a dangling reference rather
   than silently vanishing from the count.

   **The sentence moved in #2954.** It was in `CLAUDE.md`'s "Static Gate Scripts" section and is
   now in `okf/policies/static-gates.md`'s "How many there are", because `CLAUDE.md` states no
   counted claim about the repo's own inventories any more: a count there is shared by every open
   PR, so a correct edit to the inventory reds every other branch at merge time. This script reads
   wherever the sentence lives, which is `COUNT_PAGE` below.

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

No CI job runs any of the three, which is why #2960's two red modes sat unnoticed for weeks. What
keeps the enumeration true is not this file: it is `check-inventory-prose.py`, which derives the
same split on every PR from the same `ci.yml` and fails the build when the counting sentence
drifts. Keep this one as the cross-check and the defect-class record, run it by hand when the gate
suite changes, and treat a disagreement between the two as a question about THIS file first.
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
# #2954: the counting sentence lives on the policy page, not in CLAUDE.md.
COUNT_PAGE_REL = os.path.join("okf", "policies", "static-gates.md")
COUNT_PAGE = os.path.join(REPO_ROOT, COUNT_PAGE_REL)
SCRIPTS_DIR = os.path.join(REPO_ROOT, "Scripts")


# ---------------------------------------------------------------------------
# 1. Live enumeration of the gate-scripts job
# ---------------------------------------------------------------------------

RUN_SCRIPT_RE = re.compile(r"run:\s*python3\s+Scripts/([A-Za-z0-9_\-]+)\.py(.*)$")
JOB_HEADER_RE = re.compile(r"^  ([A-Za-z_][A-Za-z0-9_-]*):\s*$")
STRICT_FLAG_RE = re.compile(r"""(['"])--strict\1""")
# #2196/#2098. A `--require-...` flag turns "this run examined nothing" into an error, which a
# script whose real input is absent from the checkout must declare. #2960: that is a PROPERTY of a
# release check, not the test for one. Reading it as the test misclassified the two censuses that
# have since grown such a flag (`census-compiled-out-validation.py --require-occt-src`,
# `census-doc-occt-attribution.py --require-typecheck`), because a census needs #2098's mode
# exactly as much as a release check does. `classify()` keys on the `census-` prefix instead, as
# the gated `Scripts/check-inventory-prose.py` has always done; this reader survives to annotate
# the report and to let `--self-test` pin the property apart from the kind.
REQUIRE_FLAG_RE = re.compile(r"""(['"])--require-[a-z-]+\1""")


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


def _script_text(path: str) -> str:
    if not os.path.isfile(path):
        return ""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return ""


def script_defines_strict_flag(path: str) -> bool:
    return bool(STRICT_FLAG_RE.search(_script_text(path)))


def script_defines_require_flag(path: str) -> bool:
    return bool(REQUIRE_FLAG_RE.search(_script_text(path)))


def classify(scripts: "dict[str, ScriptSteps]", strict_flag_lookup) -> "dict[str, str]":
    """GATE / CENSUS / AUDIT / RELEASE-CHECK, in the order `check-inventory-prose.py` applies them.

    - The name begins `census-` -> CENSUS. A census is a census because its bare run reports a
      list for a human rather than reaching a verdict, which is a property of the script and not
      of how `ci.yml` happens to invoke it today. #2960: this has to be the FIRST discriminator,
      because each of the other two properties below is one a census can also have.
    - Otherwise, only `--self-test` runs in CI -> RELEASE-CHECK (#2196): the bare run reaches a
      verdict, but over an input this job does not have, so it is taken at the release step
      instead. `check-pinned-asset-patches.py` is the one today.
    - Otherwise, the bare run executes and the script defines a `--strict`-shaped flag CI's
      invocation does NOT pass -> AUDIT (it runs, and is architecturally unable to fail the build).
    - Otherwise -> GATE.

    Only the AUDIT rule is derived structurally here; the gated sibling recognises its one audit by
    name. That is the one classification this artifact still derives for itself, and the reason to
    keep the pair rather than collapse them.
    """
    kinds = {}
    for name, steps in scripts.items():
        if name.startswith("census-"):
            kinds[name] = "census"
            continue
        if not steps.bare_ran:
            kinds[name] = "release-check"
            continue
        has_strict = strict_flag_lookup(name)
        strict_passed = "--strict" in steps.bare_flags
        if has_strict and not strict_passed:
            kinds[name] = "audit"
        else:
            kinds[name] = "gate"
    return kinds


def release_checks_missing_require_flag(kinds, require_flag_lookup=None) -> list:
    """Release checks that declare no `--require-...` flag, #2098's "examined nothing" mode.

    Not a classifier (that was #2960's defect), and not part of `--check`, which would duplicate
    `check-inventory-prose.py`'s gated `check_release_checks()`. It annotates the report, and gives
    `--self-test` a fixture that pins the property apart from the kind.
    """
    require_flag_lookup = (real_require_flag_lookup if require_flag_lookup is None
                           else require_flag_lookup)
    return sorted(n for n, k in kinds.items()
                  if k == "release-check" and not require_flag_lookup(n))


def real_strict_flag_lookup(name: str) -> bool:
    return script_defines_strict_flag(os.path.join(SCRIPTS_DIR, name + ".py"))


def real_require_flag_lookup(name: str) -> bool:
    return script_defines_require_flag(os.path.join(SCRIPTS_DIR, name + ".py"))


def find_dangling_scripts(script_names, existing_names) -> list:
    """Scripts ci.yml references (bare name, no .py) that are absent from `existing_names` (also
    bare names). Shared by `run_check()` (against the real Scripts/ directory listing) and
    `--self-test` (against a synthetic fixture "directory listing"), so the self-test exercises
    the same function `--check` actually runs rather than a re-implementation of it."""
    existing = set(existing_names)
    return sorted(n for n in script_names if n not in existing)


# ---------------------------------------------------------------------------
# The repo's own stated count, parsed the same way count-operations.py parses a headline
# ---------------------------------------------------------------------------

NUMBER_WORDS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
    "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
    "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
    "nineteen": 19, "twenty": 20,
}
_WORD = "|".join(NUMBER_WORDS)
STATED_COUNT_RE = re.compile(
    rf"\b({_WORD})\s+gates?,\s+({_WORD})\s+census(?:es)?\s+and\s+({_WORD})\s+merge-history audit",
    re.IGNORECASE,
)


def parse_stated_count(text: str):
    """Return (gates, censuses, audits) parsed from the "How many there are" headline sentence,
    or None if no such sentence is found at all (a stronger signal than a wrong number: the section
    was reworded away from this shape entirely)."""
    m = STATED_COUNT_RE.search(text)
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
    DefectClass(
        id="patch-deletes-guarded-kernel-line",
        name="A carried OCCT patch deletes a kernel line that a regression test's comment says its "
             "invariant depends on",
        example_issues="#2056 (patch 0035 removed STEPControl_Writer::Transfer's "
                       "InitializeMissingParameters() call, reintroducing #280; #280's test caught "
                       "it 1h5m later in kernel-integration.yml, and the test's own comment still "
                       "described the bridge workaround deleted in f2469da2, so reading the test "
                       "while assessing the patch argued FOR the patch), filed as #2058",
        mechanism="A patch author reads the guarding test to decide whether a removal is safe. "
                   "Nothing checks that the line being removed is one a test names, and "
                   "census-comment-staleness.py scans comments in Sources/ only.",
        covered_by="check-patch-deletes-guarded-symbol.py (#2058), which indexes the OCCT symbols "
                   "Tests/**/*.swift comments name and fails when a hunk in Scripts/patches/ "
                   "removes a line naming one. It reads the patch diffs, not Libraries/occt-src, "
                   "so it runs in gate-scripts rather than kernel-integration.yml",
        disposition="gated",
        notes="Scoped to the class's own source file (a removal in STEPControl_Writer.cxx against "
              "a test naming STEPControl_Writer), because the unscoped form measures 12 false "
              "positives over the 27 patches on disk: OCCT method names are Add, Initialize, Set, "
              "IsDone. A symbol removed on one line and re-added on another is a rewrite and is "
              "not reported, which is another 14 sites across four patches.",
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
        covered_by="Every current gate/census/audit's own --self-test: every script the job runs "
                   "except count-operations.py, which has none by design, plus this script's own. "
                   "Stated as a property rather than a count, because the count it used to state "
                   "(14/14) had gone stale by one before anyone read it",
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
                       "#1066 was an INDEPENDENT instance of the same class (ci.yml's "
                       "gate-scripts comment stating 'all five' against a job running thirteen "
                       "scripts), fixed with #1408's gate.",
        mechanism="An English sentence stating a number, rewritten by hand every time the number "
                   "changes, with no derivation step forcing agreement.",
        covered_by="check-inventory-prose.py (#1408), which derives the patch counts from "
                   "Scripts/patches/ and Package.swift's enumerated pin list, and the gate/census/"
                   "audit counts from ci.yml's own job, then checks every registered claim in "
                   "Package.swift, CLAUDE.md, ci.yml and okf/policies/static-gates.md against "
                   "them; count-operations.py continues to cover the operation-count headline",
        disposition="gated",
        notes="Built as check-inventory-prose.py. This audit's worry, that parsing an English "
              "number out of prose which gets reworded whenever it drifts is fragile, was right "
              "and is answered rather than dismissed: a claim is registered as a (file, regex, "
              "derived-fact) triple and the gate fails when its regex matches NOTHING, so a "
              "rewording that escapes the check is itself the failure. Building it immediately "
              "found four live defects: #1066's two ci.yml sentences, plus two carried-patch rows "
              "whose keys named no file on disk (0010, written with an ellipsis, and 0027, keyed "
              "to a name the patch file does not have). Neither row defect had been filed.",
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
    for kind in ("gate", "census", "audit", "release-check"):
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


def _read_ci_yml() -> str:
    with open(CI_YML, "r", encoding="utf-8") as fh:
        return fh.read()


def run_report(quiet=False):
    ci_text = _read_ci_yml()
    scripts = parse_gate_scripts_job(ci_text)
    kinds = classify(scripts, real_strict_flag_lookup)
    counts = {"gate": 0, "census": 0, "audit": 0, "release-check": 0}
    for k in kinds.values():
        counts[k] += 1

    if not quiet:
        print("=== Live enumeration (from .github/workflows/ci.yml's gate-scripts job) ===")
        print(render_enumeration(scripts, kinds))
        print()
        print(f"Total: {counts['gate']} gates, {counts['census']} censuses, "
              f"{counts['audit']} merge-history audit(s), {counts['release-check']} release "
              f"check(s), {len(scripts)} scripts overall.")
        print()
        print("=== Defect-class cross-reference ===")
        print(render_defect_table())
        print()
        missing_require = release_checks_missing_require_flag(kinds)
        if missing_require:
            print(f"Release checks declaring no --require-... flag (#2098): "
                  f"{', '.join(missing_require)}")
            print()
        disp = summarize_dispositions()
        print("Disposition summary: " + ", ".join(f"{k}={v}" for k, v in sorted(disp.items())))
    else:
        print(f"{counts['gate']} gates, {counts['census']} censuses, "
              f"{counts['audit']} merge-history audit(s), {counts['release-check']} release "
              f"check(s), {len(scripts)} scripts overall.")
    return scripts, kinds


def run_check() -> int:
    """Exit 1 if the live enumeration disagrees with the repo's own stated count, or if any
    script ci.yml references is missing on disk. This is the one place this artifact behaves like
    a gate; everything else here is a report for a human to read."""
    problems = []

    ci_text = _read_ci_yml()
    scripts = parse_gate_scripts_job(ci_text)
    kinds = classify(scripts, real_strict_flag_lookup)
    counts = {"gate": 0, "census": 0, "audit": 0, "release-check": 0}
    for k in kinds.values():
        counts[k] += 1

    with open(COUNT_PAGE, "r", encoding="utf-8") as fh:
        page_text = fh.read()
    stated = parse_stated_count(page_text)
    if stated is None:
        problems.append(f"{COUNT_PAGE_REL}'s 'How many there are' section no longer states a "
                         f"'N gates, M censuses and K merge-history audit' sentence in the shape "
                         f"this script parses. Update STATED_COUNT_RE, or check the section by "
                         f"hand. (#2954 moved this sentence here from CLAUDE.md.)")
    elif stated != (counts["gate"], counts["census"], counts["audit"]):
        problems.append(
            f"{COUNT_PAGE_REL} states ({stated[0]} gates, {stated[1]} censuses, {stated[2]} "
            f"audit) but ci.yml's gate-scripts job derives ({counts['gate']} gates, "
            f"{counts['census']} censuses, {counts['audit']} audit). One of the two has drifted."
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
          f"{counts['audit']} audit) matches {COUNT_PAGE_REL}'s stated count, and every referenced "
          f"script exists on disk. Plus {counts['release-check']} release check(s), which that "
          f"sentence deliberately does not count; check-inventory-prose.py holds their own "
          f"sentence to this number (#2196).")
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
# #2960: the `census-` prefix IS the discriminator, so the fixture names have to carry it.
CLEAN_CENSUSES = [f"census-{i}" for i in range(1, 5)]  # 4 census-shaped scripts
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
    counts = {"gate": 0, "census": 0, "audit": 0, "release-check": 0}
    for k in kinds.values():
        counts[k] += 1
    if len(scripts) != 13 or counts != {"gate": 8, "census": 4, "audit": 1, "release-check": 0}:
        failures.append(f"CLEAN fixture: expected 13 scripts / 8 gate / 4 census / 1 audit / "
                         f"0 release-check, got {len(scripts)} scripts / {counts}")
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

    # --- Case E: the two directions of the #2960 discriminator, on one ci.yml shape -----------
    # A `census-` script whose bare run CI starts invoking is STILL a census: what makes it one is
    # that its run reports a list rather than reaching a verdict, which no ci.yml edit changes.
    # The same shape under a non-census name is a gate, so the prefix and not the shape is doing
    # the work, and neither answer is merely the default.
    grown_body = _clean_fixture_body().replace(
        _census_step("census-1"), _gate_step("census-1")
    )
    scripts_e = parse_gate_scripts_job(_fixture(grown_body))
    kinds_e = classify(scripts_e, _clean_strict_lookup)
    if kinds_e.get("census-1") != "census":
        failures.append(f"CENSUS-PREFIX fixture: census-1 with a bare run is still a census, "
                         f"got {kinds_e.get('census-1')!r}")
    renamed_e = _fixture(grown_body.replace("census-1", "check-not-a-census"))
    kinds_e2 = classify(parse_gate_scripts_job(renamed_e), _clean_strict_lookup)
    if kinds_e2.get("check-not-a-census") != "gate":
        failures.append(f"CENSUS-PREFIX fixture: the SAME ci.yml shape under a non-census name "
                         f"is a gate, got {kinds_e2.get('check-not-a-census')!r}")

    # --- Case F: the audit script's bare run gains --strict -> must reclassify as 'gate' -------
    strict_body = _clean_fixture_body().replace(
        f"run: python3 Scripts/{CLEAN_AUDIT}.py\n", f"run: python3 Scripts/{CLEAN_AUDIT}.py --strict\n"
    )
    scripts_f = parse_gate_scripts_job(_fixture(strict_body))
    kinds_f = classify(scripts_f, _clean_strict_lookup)
    if kinds_f.get(CLEAN_AUDIT) != "gate":
        failures.append(f"STRICT-PASSED fixture: {CLEAN_AUDIT} with --strict now passed should "
                         f"reclassify as 'gate', got {kinds_f.get(CLEAN_AUDIT)!r}")

    # --- Case I: #2196's fourth kind, and #2960's regression. Two scripts with IDENTICAL ci.yml
    # --- shapes, self-test and nothing else, classify differently on the name alone: the census
    # --- reports a list wherever it runs, the release check reaches a verdict over an input this
    # --- job does not have. Both directions, so neither answer is the default.
    release_body = _clean_fixture_body() + "\n" + _census_step("check-release1")
    scripts_i = parse_gate_scripts_job(_fixture(release_body))
    kinds_i = classify(scripts_i, _clean_strict_lookup)
    counts_i = {"gate": 0, "census": 0, "audit": 0, "release-check": 0}
    for k in kinds_i.values():
        counts_i[k] += 1
    if kinds_i.get("check-release1") != "release-check":
        failures.append(f"RELEASE-CHECK fixture: a self-test-only script outside the census- "
                         f"namespace should classify 'release-check', got "
                         f"{kinds_i.get('check-release1')!r}")
    if counts_i["census"] != 4:
        failures.append(f"RELEASE-CHECK fixture: the release check inflated the census count to "
                         f"{counts_i['census']}, which is how the counting sentence would "
                         f"go stale without anyone editing it")
    census_i = parse_gate_scripts_job(
        _fixture(_clean_fixture_body() + "\n" + _census_step("census-5")))
    if classify(census_i, _clean_strict_lookup).get("census-5") != "census":
        failures.append("RELEASE-CHECK fixture: the SAME ci.yml shape under a census- name "
                         "should stay a census")
    # The #2098 property, read off the real scripts, and now asserted apart from the kind.
    # Before #2960 this battery asserted the opposite of the second clause: that no census
    # declares a --require-... flag. Two had grown one, which is how a correct repository turned
    # this artifact red.
    if not script_defines_require_flag(os.path.join(SCRIPTS_DIR,
                                                     "check-pinned-asset-patches.py")):
        failures.append("RELEASE-CHECK reader: check-pinned-asset-patches.py declares "
                         "--require-asset, but the reader did not see it")
    declaring_censuses = sorted(
        os.path.splitext(os.path.basename(p))[0]
        for p in glob.glob(os.path.join(SCRIPTS_DIR, "census-*.py"))
        if script_defines_require_flag(p))
    if not declaring_censuses:
        failures.append("RELEASE-CHECK reader: no census declares a --require-... flag, so the "
                         "#2960 regression fixture is no longer exercising anything; either the "
                         "reader went blind or the flags were removed, and both want looking at")
    live_kinds = classify(parse_gate_scripts_job(_read_ci_yml()), real_strict_flag_lookup)
    misread = [n for n in declaring_censuses if live_kinds.get(n, "census") != "census"]
    if misread:
        failures.append(f"CENSUS-PREFIX regression (#2960): {misread} declare a --require-... "
                         f"flag and were classified as something other than a census")

    # --- Case G: parse_stated_count -------------------------------------------------------------
    correct = "blah blah Eight gates, four censuses and one merge-history audit, all pure Python"
    if parse_stated_count(correct) != (8, 4, 1):
        failures.append(f"STATED-COUNT fixture (correct): expected (8, 4, 1), "
                         f"got {parse_stated_count(correct)}")

    stale = "Six gates, one census and one merge-history audit exist now"  # #819's own stale claim
    if parse_stated_count(stale) != (6, 1, 1):
        failures.append(f"STATED-COUNT fixture (#819's own stale wording): expected (6, 1, 1), "
                         f"got {parse_stated_count(stale)}")

    two_digit = "Twelve gates, three censuses and one merge-history audit"
    if parse_stated_count(two_digit) != (12, 3, 1):
        failures.append(f"STATED-COUNT fixture (two-digit word): expected (12, 3, 1), "
                         f"got {parse_stated_count(two_digit)}")

    missing = "This section no longer states a count sentence at all."
    if parse_stated_count(missing) is not None:
        failures.append(f"STATED-COUNT fixture (absent): expected None, "
                         f"got {parse_stated_count(missing)}")

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
    print("SELF-TEST: OK (9 cases: clean enumeration, gate removed, script renamed, script "
          "added, census-prefix wins over the ci.yml shape in both directions, "
          "audit-gains---strict reclassification, release-check-vs-census on the same ci.yml "
          "shape plus the #2960 regression read off the real Scripts/ directory, stated-count "
          "parsing incl. a two-digit word and an absent sentence, dangling reference against a "
          "fixture disk listing)")
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
