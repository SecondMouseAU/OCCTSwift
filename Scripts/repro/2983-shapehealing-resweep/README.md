# #2983 ShapeHealing re-sweep: the injection matrix

The evidence behind the PR that rewrote `Issue443FirstOfNTests`, `Issue442FixSolidMultiBodyTests`
and `Issue702SolidDemotionTests` (tests the #766 certification recorded Red and never rewrote).
Measured on 2026-10-03 against `origin/main` at `ce2a7dc2f` and the pinned kernel
`v4.0.0-kernel.4`. Every figure below is that day's and is re-derivable from the files here;
re-measure rather than quote.

## What is here

| file | what it is |
|---|---|
| `SweepHealingShadow.swift.txt` | the harness: module-local Swift functions that shadow 14 bridge entry points, each distorted by a switch named in `SWEEP_HEALING_SWITCH`. A `.txt` so no build or linter reads it in place |
| `inject.py` | the two edits to tracked files a shadow cannot make (see its docstring) |
| `switches.txt` | the 116 switches, under `GROSS`, `SEMANTIC` and `FIXTURE` headers |
| `run-injection-matrix.py` | runs the built bundle once per switch and writes `matrix-LABEL.json` |
| `report.py` | compares two matrices from the committed JSON, no build needed |
| `matrix-before.*` | the same switches against `origin/main`'s versions of the four test files |
| `matrix-after.*` | against the rewritten ones |

## Running it

1. `cp Scripts/repro/2983-shapehealing-resweep/SweepHealingShadow.swift.txt Sources/OCCTSwift/SweepHealingShadow.swift`
   and `python3 Scripts/repro/2983-shapehealing-resweep/inject.py apply`.
2. `swift build --target OCCTShapeHealingTests`, with `XCTest.framework`, `Testing.framework` and
   `libXCTestSwiftSupport.dylib` symlinked into `.build/out/Products/Debug/PackageFrameworks`
   (SIP strips `DYLD_*` from the signed helper, so the environment route never reaches it).
3. `python3 Scripts/repro/2983-shapehealing-resweep/run-injection-matrix.py after`. For the "before"
   column, `git checkout origin/main -- <the four test files>`, rebuild, run with label `before`,
   and `git checkout HEAD -- <the four files>` after committing, never before.
4. **Restore, and prove it.** `git checkout --` the two files `inject.py` edited, `rm` the shadow,
   rebuild, and require both `strings <bundle> | grep -c SWEEP_HEALING_SWITCH` to read 0 and the
   bundle to stay green with a switch set. `swift build` exiting 0 says neither
   (`okf/references/injection-sweep-mechanics.md`, "A restore is not finished until the bundle is
   relinked").

## How the switches are chosen

A switch is a defect somebody could plausibly write, not an arbitrary perturbation.

* **GROSS (16)**: the operation returns nil or hands the input back. Every census-era test catches
  these, which is why they are kept apart and not counted as coverage.
* **SEMANTIC (96)**: which body came back (first only, last only, the first body again as a
  distinct copy, the last dropped, the order swapped), orientation (every body inside out, the
  second only, every body after the first left unfixed), parity (every shell a body, the open body
  dropped, a repeated shell built twice), flattening, the cavity filled, one body wrapped in a
  compound, a refusal that stops refusing, the history built from the wrong run, and the
  `analyze` / `analyzeShell` / `totalProblems` / `isHealthy` / validity / self-intersection verdicts.
* **FIXTURE (4)**: the test's own setup stops meaning its name (sewing sews nothing, `solidFromShells`
  heals, a reversal reverses nothing).

The first body twice is built from a **distinct copy**. A bare repeat of one `TopoDS_Shape` counts
once in sub-shape enumeration, so every count catches it and the switch measures nothing about
identity (the first version of this harness did exactly that).

## Result

| family | switches | redden nothing, before | redden nothing, after |
|---|---|---|---|
| solid(from:) | 15 | 2 | 0 |
| solidWithFullHistory | 16 | 6 | 0 |
| solidFromShellFixed | 14 | 2 | 0 |
| fixSolid | 17 | 2 | 0 |
| upgraded | 15 | 3 | 1 |
| healed | 2 | 0 | 0 |
| analyze / analyzeShell | 18 | 6 | 0 |
| totalProblems / isHealthy | 6 | 2 | 0 |
| validity and self-intersection | 9 | 1 | 0 |
| fixtures | 4 | 1 | 0 |
| all | 116 | 25 | 1 |

Before, 24 of the 96 semantic switches reddened nothing, and the one fixture switch that did
(`FX_REVERSE_NOOP`) does not apply, since no old test builds an inverted body. After, one
semantic switch reddens nothing: `UP_SWAP`. `upgraded()` makes no promise about the order of the
bodies it returns (sewing chooses it), so nothing can pin one; that is a green row that is a
finding about the contract, not a gap.

The old tests were not blind: all 50 caught at least one semantic switch, and they caught every
total failure. What they could not see is **which** body came back, whether an orientation fix ran
on every body, whether a history covers every body, and anything about order. By test, at most one
semantic switch reddens 6 of the 50 old tests and none of the 59 new ones, at most three reddens 22
of 50 and 7 of 59, and the median test is red under 5 semantic switches before and 8 after.

## What isolates what

Disjointness is the evidence that a row measures one mechanism and not a coincidence.

* `HIST_FIRST_BODY_HISTORY_ONLY`, `HIST_LAST_BODY_HISTORY_ONLY` and `HIST_UNRELATED_HISTORY` each
  redden exactly `solidWithHistoryRecordsEveryBodysRepair` and nothing else. They reddened nothing
  before, because a healthy body leaves the history empty and a history that covers no body answers
  exactly like one that covers both.
* `AN_CHECKINTERNAL_FALSE_REAL`, a real edit that runs `OCCTShapeAnalyze`'s scan with
  `checkinternaledges` false, reddens exactly `analyzeAgreesWithAnalyzeShellOnInternalDuplicate`.
* `FIX_FILLS_CAVITY` reddens exactly `fixSolidHollow`, and `FIX_PER_INPUT_SOLID_ONLY_FIRST_SHELL`
  exactly `fixSolidMulticonnex`.
* `HEALTHY_IGNORES_FREEEDGES` and `AN_GAP_PLUS1` redden exactly `freeEdgesAloneMakeAShapeUnhealthy`.
  The first reddened nothing before because every box already reads `isHealthy == false`
  (24 gaps, #3040), so "the free edges make it unhealthy" was satisfied by the wrong cause.
* `*_PARTIAL_UNFIXED` (the first body fixed, every later one left as it came in) is red in the
  `*OrientsEveryBody` tests, which build their bodies inside out, and in the two tests whose
  second body is an open shell that only a fix turns into a shell (`documentedUnclosedCheck`,
  `upgradedKeepsOpenBody`). It reddened nothing before, because every old fixture arrives already
  healthy.

## What the matrix cannot say

It proves the guards the switches model, not that every assertion is right. The values are derived
or read from OCCT, and two are deliberately not pinned: `gapCount` (#3040) and that a result holds
the face its history reports as the replacement (#3041, carried as a `withKnownIssue`).
