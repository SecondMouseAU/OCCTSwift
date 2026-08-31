# #819 Phase 6, item 3: gate script coverage of the gates

Issue #819's own framing: *"Six gates, one census and one merge audit exist now. This phase asks
which of the defects the programme actually found would have been caught by any of them, and which
classes of defect still have no gate. The known answer so far is that three gate scripts on this
branch were themselves confidently wrong (#618, #624/#630, #626), which is why every gate carries a
`--self-test`; the open question is coverage, not correctness."*

That "six gates, one census" count was itself stale by the time this pass started. The task's own
instruction was explicit: **do not trust it, re-derive it live.** `gate_coverage.py` in this
directory does exactly that, and its `--check` mode keeps doing it on every future run rather than
letting this document go stale the same way.

## The live count

```
$ python3 Scripts/repro/819-gate-coverage-audit/gate_coverage.py --check
OK: live enumeration (8 gates, 4 censuses, 1 audit) matches CLAUDE.md's stated count, and every
referenced script exists on disk.
```

**Eight gates, four censuses, one merge-history audit. Thirteen scripts total**, derived by parsing
`.github/workflows/ci.yml`'s `gate-scripts` job directly (not by reading `CLAUDE.md`'s prose and
trusting it), and cross-checked against `CLAUDE.md`'s own "Static Gate Scripts" section, which
currently agrees. That agreement is worth stating plainly rather than assuming: at the time #819 was
filed the true count was six gates and one census (a different, smaller set, from before
`check-borrowed-handles.py`, `census-arguments-tuple-shapes.py` and `census-comment-staleness.py`
shipped); `CLAUDE.md` was kept in sync by hand across three intervening PRs and happens to be correct
today. Nothing forces that to stay true tomorrow, which is the entire reason this artifact exists
rather than a one-off count in this README.

| Kind | Scripts |
|---|---|
| **GATE** (8) | `check-borrowed-handles`, `check-bridge-index`, `check-docs-defaults`, `check-docs-existence`, `check-null-handle-guards`, `count-operations`, `derive-bridge-header-split --verify`, `derive-gdt-enums --verify` |
| **CENSUS** (4) | `census-arguments-tuple-shapes`, `census-comment-staleness`, `census-doc-occt-attribution`, `census-unmeasured-values` |
| **AUDIT** (1) | `check-changelog-transcription` |

The classification is derived **structurally**, not by matching an English word in a comment
(comments get reworded; structure doesn't drift the same way):

- **CENSUS**: only `--self-test` runs in `ci.yml`. The bare run either never executes in CI at all,
  or is documented to always exit 0 by design.
- **AUDIT**: the bare run DOES execute in CI, but the script defines a `--strict`-shaped flag CI
  deliberately withholds, so it is architecturally unable to fail the build today (only
  `check-changelog-transcription.py` fits this; verified by grepping all thirteen scripts for a
  `'--strict'`/`"--strict"` `add_argument` call, only one has it).
- **GATE**: the bare run executes and nothing softens it.

Two sibling scripts sit outside `gate-scripts` entirely and are correctly excluded from this count:
`check-style-manifest.py` and `comment-ratio-check.py` belong to the separate `code-style` CI job.
Two more, `derive-shape-domain-split.py` and `derive-swift-file-split.py`, are **not wired into any
CI job today** at all: investigation tooling from #660/#393/#394, superseded once #687 closed
(`docs/v2.0.0-plan.md`'s own item 4, "none needed splitting"). They are retired, working tools, not
current gates, and this audit does not count them, per the task's own live-derivation instruction.

## Methodology, and how much of the programme's history this actually classified

The programme's history is large: **664 closed issues** as of this pass (`gh issue list --state
closed`). Individually classifying all of them would be disproportionate, so this pass did not.

**Read in full, individually classified:** `CLAUDE.md`'s entire "Known OCCT Bugs" section (32
distinct root-caused entries, from `BRepExtrema_ExtCC` through #1157), because it is the project's
own curated record of significant defects and every entry already carries the root cause, the fix,
and the verification method needed to reason about gate coverage without re-deriving it. That is
**32 issues** read and classified individually, each mapped to a specific row in `DEFECT_CLASSES`
below, not bucketed by title alone.

**Read for structure, not individually classified per-issue:** `docs/v2.0.0-plan.md`'s five
correctness-cluster descriptions (A through E, #664-#668) and its "why a final pass is needed"
section (#502, #490, #443 named directly with enough detail to classify without opening each
issue), plus a sweep of `docs/CHANGELOG.md`'s ~140 entry headlines across the `v2.0.0`/`v3.0.0`/
`Unreleased`/`v3.0.1` sections to identify the shape of the duplication-audit findings (the
"N similar things merged into one shared implementation" pattern that recurs at #791, #792, #794,
#795, #881, #899, #903, #908, #724, #733, #762, and others). This is **roughly 15-20 issues**
represented by title/one-line evidence in `DEFECT_CLASSES`' `semantic-duplication` row, not opened
and read individually.

**Consulted for cross-reference, not part of the defect-history sample:** `MEMORY.md`'s own
compact per-issue hooks (~80 entries) were used to confirm this pass's classifications agreed with
the project's own prior characterizations, not as a primary source.

**Not read at all:** the remaining ~600 closed issues, overwhelmingly individual wrapping/PR-review
findings from the duplication-audit lane passes (#382-#392) and ordinary feature work, which this
pass's own defect-class taxonomy already covers by pattern (a 21st instance of "two bridge
functions duplicate the same array-building helper" teaches nothing the class row doesn't already
say).

So: **32 of 664 (about 5%) individually classified in full**; a further ~15-20 (about 2-3%)
classified from title/summary evidence; the remaining ~92% bucketed into the same ~10 defect
classes those samples establish, on the judgment that the taxonomy is saturated (the last several
duplication-audit PRs read for this pass were all instances of patterns already in the table, not
new shapes).

## The defect-class cross-reference

Twenty-three defect classes, six dispositions:

| Disposition | Count | Meaning |
|---|---|---|
| `gated` | 9 | A current gate's bare run blocks a recurrence today. |
| `census` | 4 | A current census reports a recurrence for human adjudication; only `--self-test` runs in CI, the bare report never blocks a merge. |
| `audit` | 1 | Same shape as census but the bare run does execute in CI (non-blocking by design). |
| `process-only` | 1 | Covered by written policy + code review discipline (`--self-test` on every detector), not by any script. |
| `not-gateable` | 4 | Fundamentally outside what a text-scanning Python script over `Sources/`/`Tests/`/`docs/` could ever check: vendored third-party C++ source, or a judgement call only a human/reviewer can make. |
| `ungated-gap` | 4 | Gateable in principle. Nothing does it today. Each row states a disposition: filed as an issue, or confirmed not small/obvious enough to build in this PR. |

Full table (also produced live by `python3 gate_coverage.py`, so this file can be regenerated
rather than hand-copied if the script's own data changes):

### Gated today (9)

| Defect class | Issues | Gate |
|---|---|---|
| Bridge-index entry stale/fabricated/misfiled | #510, #565, #618, #624/#630 | `check-bridge-index.py` |
| Caller-supplied Curve3D/Curve2D/Surface Handle dereferenced with no null guard | #478, #556, #618, #656/#666 | `check-null-handle-guards.py` |
| Caller-supplied TopoDS_Shape wrapper dereferenced with no presence/type guard | #1026, #1035 | `check-null-handle-guards.py` (SHAPE_* walk) |
| Value type stores an OCCT handle it has no deinit to release | #965 | `check-borrowed-handles.py` |
| docs/reference/ default restatement drifts from the declaration | #491, #626, #572 | `check-docs-defaults.py` |
| docs/ documents a symbol that no longer exists in Sources/ | #802 | `check-docs-existence.py` |
| Bridge declaration in the wrong header / wrong .mm-definer count | #395, #673 | `derive-bridge-header-split.py --verify` |
| GD&T Swift enum drifts from the pinned OCCT headers | #996 | `derive-gdt-enums.py --verify` |
| Stated operation-count headline drifts from the derived count | #289, #899/#902, #914 | `count-operations.py` |

### Census / audit (human adjudicates, detector self-test only gates CI) (5)

| Defect class | Issues | Detector | Known limitation |
|---|---|---|---|
| A value is published as though measured but was never computed | #726, #609, #583, #595, #763/#771, #703 | `census-unmeasured-values.py` | No Swift-side sweep for sub-kind 4; can't see a kernel-side fabrication (#999's shape) |
| Docs attribute an operation to an OCCT class the bridge never reaches | #928, #807/#808/#809 | `census-doc-occt-attribution.py` | Measured 41% false-positive rate over a 40-row sample; "a floor, never a proof" |
| `@Test(arguments:)` element trips the SIMD/task-allocator toolchain defect | #1057 | `census-arguments-tuple-shapes.py` | Reports `unknown` for 9/33 real sites rather than guessing; pairing proven necessary but not sufficient |
| A comment names a symbol/flag/patch file that no longer resolves | #872 | `census-comment-staleness.py` | Explicitly does not re-verify Known-OCCT-Bugs narrative claims against live GitHub/OCCT state |
| A merged PR's CHANGELOG entry never lands | #742, #788, #1125 | `check-changelog-transcription.py` | Bare run non-blocking by design (`--strict` withheld); promotion criterion not yet met |

### Process-only (1)

**A gate/census script's own detection logic has a blind spot or misfires on correct code**
(#618 false negative, #624/#630 false positive, #626 false negative, plus, in now-retired tooling
never wired into CI, `derive-shape-domain-split.py`'s self-test passing 6/6 twice while a case
proved nothing, and `derive-swift-file-split.py` missing every top-level free `func`, #659).
Covered by every current detector's own `--self-test` (14/14 including this one), which is a
**policy** (`okf/policies/prove-the-test-fails.md`), not a script. Nothing here catches a FIFTH
such defect in a gate not yet built, or a self-test whose removal-matrix case looks like coverage
but isn't.

### Not gateable by any of these scripts (4)

None of the 13 `gate-scripts`-job scripts reads `Libraries/occt-src` or
`Libraries/OCCT.xcframework`'s C++ implementation at all; they parse `Sources/OCCTSwift`,
`Sources/OCCTBridge`, `Tests/`, `docs/`, `README.md`, `docs/CHANGELOG.md`, and
`Package.swift`/`CLAUDE.md` prose. All four rows below live in vendored third-party source or in
human review judgment, out of reach for a static Python text scanner by construction:

| Defect class | Issues | What actually covers it (if anything) |
|---|---|---|
| Kernel data race (unsynchronized static/global/member state in OCCT's own C++) | #298, #341, #344, #349, #353, #363, #371, #374, #1154, #1153, #1371, #1157 (12 root-caused) | `Scripts/tsan-stress.sh` (ThreadSanitizer) -- a separate mechanism, no `--self-test`, needs a from-source kernel rebuild under instrumentation, not run on every PR |
| Kernel uncatchable crash (unguarded internal deref / uninitialized read) | #176, #310, #317, #318, #348, #430, #643, #905, #913, #1018, #1022 (11 root-caused) | Nothing; found only by manual reproduction |
| Kernel silent wrong-answer (`IsDone()` true, geometry/error actually incorrect) | #522, #532, #597, #603, #905, #913, #1018 | Nothing; found only by cross-checking two independent measurements or probing internals |
| A defect in a *proposed* kernel patch itself | #1153 (PR #1322's self-deadlocking mutex, rejected on review) | Nothing, and cannot be; only human/agent code review catches this |

This is the honest negative result the task asked for: **should TSan count as "covered"?** This
audit's answer is *a qualified no* for the purpose of "gate-scripts coverage" specifically.
`Scripts/tsan-stress.sh` is real, working coverage for the data-race row, and it is why 12 real
kernel races were found and fixed rather than zero. But it is not what "gate-scripts" means
anywhere else in this repo: it has no `--self-test`, is not a `ci.yml` job step, is invoked
deliberately rather than automatically, and takes minutes rather than the ~3 seconds the 13 real
gate-scripts-job scripts take together. Counting it as "the gate" for kernel races would blur the
one distinction this whole audit exists to keep sharp.

### Ungated gaps: gateable in principle, nothing does it today (4)

| Defect class | Issues | Disposition |
|---|---|---|
| Missing try/catch around a known-throwing OCCT call in bridge code | #345 (49 sites) | **Filed as #1407.** Plausibly gateable (a known-throwing-call list + a "lexically inside a try block" scope tracker), comparable in build cost to `check-null-handle-guards.py` itself; not "small and obviously correct," so not built here. |
| Semantic code duplication distributed across the codebase | #377, #380-#392, #490, #502, #443, #446, #791/#792/#794/#795, #881/#899/#903/#908, #784/#1391 | **Not proposed as a new gate.** Covered by periodic, LLM-driven audits (`bridge-duplication-audit`/`duplication-audit` skills, the #784/#1391 rescans), by design: this class needs judgement a mechanical script can't safely automate, and #792 already measured the one mechanical scan tool in this space (`Scripts/repro/784-duplication-rescan/detect-duplicate-logic.py`) blind to a one-line duplication whose call syntax differs. The least self-test-disciplined mechanism this audit found (no `--self-test`, not wired into `ci.yml` at all) — worth knowing, not worth "fixing" by forcing it into this suite's shape. |
| Stale self-referential count in CLAUDE.md/Package.swift/ci.yml prose | Recurred at v2.0.0-kernel.1-3, #1032, #1157/#1402; **#1066 (open) is an independent, still-live instance in `ci.yml`'s own comment block** | **Filed as #1408.** `count-operations.py` covers exactly one instance (the operation-count headline); nothing covers the patch count or the gate-scripts step count against their own stated prose. Not built here: parsing an arbitrary, ever-changing English sentence is fragile in exactly the way this script's own `CLAUDE_COUNT_RE` demonstrates on a much narrower, self-controlled case. |
| Stale `Scripts/tsan.supp` suppression past its own "remove when fixed" policy | #1154's nine `race:TopoDS_TShape::*` entries are the live example of the state this policy warns about (correctly still present today, patch 0030 not yet in a rebuilt xcframework) | **Filed as #1409.** Half mechanical (cross-reference cited patch numbers against `Scripts/patches/*.patch`); half needs the manual "is patch N in the *pinned* asset" verification `CLAUDE.md` already documents, not a text-only check. |

## Verification

**This script's own `--self-test`** (`python3 gate_coverage.py --self-test`): 8 fixture cases,
covering the live-parsing (`parse_gate_scripts_job`), classification (`classify`), dangling-reference
detection (`find_dangling_scripts`), and `CLAUDE.md`-count-parsing (`parse_claude_md_count`) logic.
All 8 pass against the correct code.

**Prove-the-test-fails discipline, run for real, not just described**: five targeted mutations,
each applied to a scratch copy, self-test re-run, failure(s) recorded, restored, clean re-confirmed.

| Mutation | Logic broken | Self-test cases that failed |
|---|---|---|
| 1 | `RUN_SCRIPT_RE` captures `.py` inside the name group (the actual bug this script shipped with on its first draft) | A, B, C, D, E, F, H (every case except G, the independent CLAUDE.md-count parser) |
| 2 | `classify()`'s census branch (`if not steps.bare_ran`) disabled | A, B |
| 3 | `classify()`'s `strict_passed` check dropped from the audit condition | F only (cleanly isolated) |
| 4 | `NUMBER_WORDS["twelve"]` mapped to a wrong value | G only (cleanly isolated) |
| 5 | `find_dangling_scripts()` made to always return `[]` | H only (cleanly isolated) |

Mutations 3, 4 and 5 each isolate exactly one case, proving those three guards are load-bearing and
independently testable. Mutation 1 (the core parser) and mutation 2 (the census/gate split) each
break several cases at once, which is expected: both sit upstream of everything else the self-test
checks, the same way a broken `extract_source_symbols()` would break most of
`check-docs-existence.py`'s own battery. After every mutation the file was restored and `diff`-ed
byte-identical against the pre-mutation copy before re-confirming a clean run.

**`--check` against the real tree**: exits 0, confirms the live enumeration (8/4/1) matches
`CLAUDE.md`'s stated sentence and every script `ci.yml` references exists on disk.

**Existing gates unaffected** (spot-checked, not the full 13, since this PR adds a new file and
touches nothing existing): `check-docs-existence.py` (6614 symbol references, 0 stale),
`census-comment-staleness.py --self-test`, `check-bridge-index.py --self-test` (18/18),
`check-null-handle-guards.py --self-test` (50/50), `count-operations.py` (4365, three headlines
agree), `check-changelog-transcription.py --self-test` (25/25) — all clean, matching their state
before this PR.

## What this pass did not do

- **Did not individually read all 664 closed issues.** See "Methodology" above for the exact
  breakdown (32 read in full, ~15-20 read for structure, the rest bucketed by established pattern).
- **Did not build any of the three proposed gates** (#1407 missing-throw-guard, #1408 stale-count,
  #1409 stale-tsan-suppression), per the task's own instruction that a new gate is separate scope
  unless small and obviously correct. None of the three judged to meet that bar.
- **Did not attempt to promote any census to a gate** (`census-unmeasured-values.py` per #765,
  or any other). That is real, separate scope with its own open spike issue; this audit points at
  it rather than re-litigating it.
- **Did not audit `okf/references/carried-occt-patches.md`** or the other four in-repo statements
  of the carried-patch set #1066 names, beyond confirming #1066 itself is still open and still
  accurate about `ci.yml`'s comment block.
- **Does not claim TSan "doesn't count"** as coverage in any absolute sense; it is real, working
  coverage for kernel data races, found 12 real defects, and is not going away. The claim is
  narrower: it is not `gate-scripts` coverage, and conflating the two would understate exactly the
  gap #819 asked this phase to measure.
