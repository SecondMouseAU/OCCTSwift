# #973: which pass of #807 owns each OCAF-family package

**48 packages, 459 headers of the pinned kernel belonged to no pass of the refman-coverage epic.**
This directory is the partition that ends that, and the standing check that it does not come back.

`partition_census.py` is the artifact required by `docs/v2.0.0-plan.md`'s census rule. It is not a
coverage audit: it decides **ownership**, one line per package, and each owning pass runs its own
per-class `ok`/`under`/`over`/`deliberate, recorded` audit and lands its own artifact.

```bash
python3 Scripts/repro/973-ocaf-package-partition/partition_census.py                  # the partition
python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --pass 983       # one pass's set
python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --why Resource   # one decision
python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --reconcile-973  # vs #973's own table
python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --global         # what is still unowned (#820's)
python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --verify-lanes   # the issue bodies still agree
python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --reverify-family
python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --self-test
```

Exit 0 clean, 1 a defect, 2 the environment cannot answer (no `Libraries/OCCT.xcframework`, no
`Libraries/occt-src`, no `gh`). 2 is deliberately distinct from 1: a missing xcframework is not a
finding about the tree.

## The partition

61 packages, 737 headers, 142 classes reached from the bridge.

| owner | pass | packages | headers | wrapped |
|---|---|---:|---:|---:|
| #810 | Pass 3, Document/XDE assembly | 13 | 278 | 118 |
| #982 | Pass 3b, OCAF framework layer | 5 | 51 | 9 |
| #983 | Pass 3c, OCAF persistence and format drivers | 38 | 342 | 8 |
| #813 | Pass 4c, Export and interop | 2 | 22 | 5 |
| #814 | Pass 4d, Mesh plus presentation | 2 | 39 | 2 |
| #820 | Phase 6 only, no lane pass | 1 | 5 | 0 |

Thirteen of the 61 were already Pass 3's. The other **48, 459 headers**, were owned by nobody.

### Reasoning, by group

- **#982, Pass 3b (new).** `TFunction_`, `TPrsStd_`, `TObj_`, `AppStd_`, `AppStdL_`. OCAF proper,
  above the document API and below the drivers: the function and regeneration mechanism, the
  presentation attributes, the TObj object model, and the two standard application subclasses. The
  most wrapped part of the unowned set (9 classes of 51 headers) and the part a CAD consumer
  notices missing. **Folding them into #810 was rejected**: that pass's audit is complete and its
  PR (#977) open, so anything added now would sit inside a finished lane and be audited by nothing.
- **#983, Pass 3c (new).** The persistence layer: one driver package per attribute family per
  format, plus the persistent object model, the schema and stream layer, the plugin loader and the
  XML DOM. Eight classes of 342 headers are reached from the bridge and all eight are
  format-registration entry points. **Folding into #813 was rejected on measurement**, which is
  the candidate #973 itself proposed: #813's lane is 192 headers and this is 342, so folding would
  treble it and produce a pass 84% larger than the largest in the epic. The subjects also differ.
  #813 audits formats a consumer names and reaches through a wrapped reader or writer; this is one
  format family the consumer never names, reached through `Document.save(format:)`, where the right
  answer for most of 342 headers is one family-level entry in `docs/occtswift-wrapping-gaps.md`.
- **#813, Pass 4c (existing, gains 2).** `BinTools_` and `Resource_`. Both are wrapped in
  `Sources/OCCTBridge/src/OCCTBridge_IO.mm`, which is Pass 4c's own bridge file, and both reached
  #973's table only by matching a `Bin*`/`Std*` prefix.
- **#814, Pass 4d (existing, gains 2).** `StdPrs_` and `StdSelect_`. Both `Visualization/TKV3d`,
  the same toolkit as the `AIS_` already in that lane, and both prefix-sweep artifacts too.
- **#820, Phase 6 only.** `StdFail_`, and this is a recorded answer rather than a gap. See below.

### The three decisions that were not the obvious ones

**`Resource_` is Pass 4c's, not Phase 6's.** #973 guessed Phase 6 on the grounds that OCAF's format
registration uses it. Measured: it has a public `ResourceManager` Swift type in
`Sources/OCCTSwift/ResourceManager.swift`, thirteen operations in `docs/API_REFERENCE.md`, a bridge
home in `OCCTBridge_IO.mm`, and twelve of its seventeen OCCT consumers are outside OCAF and are
`DESTEP_`, `DEIGES_`, `STEPControl_`, `STEPCAFControl_`, `StepData_`, `XSAlgo_`, `ShapeProcess_` and
`Units_`. `Resource_Unicode::SetFormat` is the STEP and IGES text encoding switch specifically. Two
independent constructions (the bridge site, and the OCCT-wide consumer set) agree, which is what
`okf/policies/measure-dont-assume.md` asks for.

**`StdFail_` belongs to no lane, on purpose.** It is the kernel's exception vocabulary
(`StdFail_NotDone` and four siblings). 56 OCCT packages reference it, every one outside OCAF and
spread across every lane in the epic, so no lane has a better claim than any other. Nothing wraps
it as a capability: it is what the bridge catches, not what it calls, and the only claims `docs/`
makes about it are convention statements in `docs/naming-conventions.md`. Phase 6 (#820) sees the
whole surface by construction and reaches it there. It is kept in the table with that reason rather
than deleted from it, because deleting it would put it straight back into the state this issue
exists to end.

**`StdSelect_` is the one boundary where two passes have a claim.** The `Selection` Swift surface is
Pass 2b's (#809) subject, and `StdSelect_BRepSelectionTool` is named in `docs/reference/Selection.md`.
It is filed with Pass 4d because the OCCT classes are TKV3d and the bridge site is the AIS one in
`OCCTBridge_Visualization.mm`, while #809's OCCT lane is `BRepExtrema_`/`BRepClass*`/`gp_`/`GC_`/
`GCE2d_` geometry rather than presentation. #814's `## Lane` records the overlap so it does not read
as an oversight.

## How the family was derived, and what "44 packages, ~460 headers" turned out to mean

Nothing here is inherited from #973's body. Four mechanical tiers, each recorded per package:

| tier | rule | packages | headers |
|---|---|---:|---:|
| `module` | OCCT's own `ApplicationFramework` module, `src/ApplicationFramework/TK*/<pkg>/` | 43 | 509 |
| `ocaf-only` | outside that module, and every OCCT package referencing its symbols is an OCAF package | 7 | 83 |
| `xde` | the XDE attribute layer in `DataExchange/TKXCAF`, already Pass 3's | 6 | 79 |
| `prefix-stray` | not OCAF at all; in #973's table only because it matches `Bin*`, `Xml*` or `Std*` | 5 | 66 |

`--reconcile-973` prints the comparison. All three of #973's numbers reconcile:

- Every per-package header count in #973's 43-row table is **correct** against the pinned kernel.
- The table is **missing five packages, 49 headers**: `LDOM` (24), `ShapePersistent` (13), `UTL` (1),
  `FSD` (7), `Plugin` (4). The first three are `ApplicationFramework` packages a prefix-shaped
  derivation cannot see, because their names do not begin `Bin`, `Xml`, `Std`, `T` or `App`. The
  last two are `FoundationClasses/TKernel` and were reached here by the consumer measurement.
- 410 + 49 = **459**, which is the "~460" #973's prose gives. **The prose total was right and the
  table under it was not**, the reverse of the usual direction.
- 43 + 5 = **48** packages, so the prose "44" was wrong against both its own table and the kernel.

`LDOM` also shows why the header-to-package split needs care: 3 of its 24 headers (`LDOMParser.hxx`,
`LDOMString.hxx`, `LDOMBasicString.hxx`) do not carry the package underscore, so a naive split
reports 21. There are exactly four such headers in the whole kernel and `--reverify-family` fails if
a fifth appears.

## Prove the test fails

Both matrices below were run, not reasoned about
(`okf/policies/prove-the-test-fails.md`). Each row is a real edit to a copy of the script, the
command as run, and the observed result.

### Removal matrix: each accepting or rejecting shape in the detectors

`--self-test` is 15 cases: 9 for `lane_names_package` (which decides whether an issue claims a
package) and 5 for `header_package` (which decides how many headers a package has), plus 1 table
integrity check.

| removal | self-test result | which case caught it |
|---|---|---|
| R1: drop the backtick anchor from `lane_names_package` | FAILED 1 of 15 | prose naming `StdPrs` with no backticks reported as a claim |
| R2: drop the `` [^`\n]* `` walk inside the backtick run | FAILED 1 of 15 | `` `Handle(TFunction_Driver)` `` reported as no claim |
| R3: drop the `(?:_|\*|\b)` tail assertion | FAILED 1 of 15 | `` `StdSelectSomethingElse_Foo` `` reported as claiming `StdSelect` |
| R4: drop the `HEADER_PACKAGE_OVERRIDES` lookup | FAILED 2 of 15 | `LDOMParser.hxx` and `step.tab.hxx` mapped to the wrong package |
| R5a: remove a package reason that has a group fallback | **PASSED 15 of 15** | nothing, correctly: the group reason is the fallback |
| R5b: remove a group reason with no package fallback | FAILED 5 of 15 | all five of Pass 3b's packages report no recorded reason |
| R6: point one package at an owner not in `OWNERS` | FAILED 1 of 15 | the table integrity check |

Two notes the matrix is worth more than, because both were found by running it rather than by
reading:

- **R2 initially passed**, which meant the prefix walk was decorative. A case was added
  (`` `Handle(TFunction_Driver)` ``) that exercises it. **No `## Lane` in #807 is written that way
  today**, so that one synthetic case is the only thing holding the shape. It is kept rather than
  deleted because a lane written that way tomorrow would otherwise be silently unclaimed, and that
  status is recorded here so the next reader is not left to infer it.
- **R5a passed and was kept as R5a**, with R5b added beside it. The original R5 was the whole of
  the reason check's coverage and proved nothing, exactly the failure
  `derive-shape-domain-split.py` shipped twice.

### Injection matrix: each guard in the run modes

| injection | command | expected | observed |
|---|---|---|---|
| I1: `TDF` baked as 52 headers instead of 51 | plain run | exit 1 | exit 1, `TDF: baked 52 headers, pinned kernel has 51` |
| I2: `Storage` given an owner not in `OWNERS` | plain run | exit 1 | exit 1 |
| I3: `StdStorage` deleted from the table | plain run | exit 1 | **exit 0 at first.** See below |
| I4: `TObj` marked as not in the module | `--reverify-family` | exit 1 | exit 1, `membership drifted: only in kernel ['TObj']` |
| I5: `StdPrs` assigned to #812, whose lane does not name it | `--verify-lanes` | exit 1 | exit 1 |
| I6: `StdFail` assigned to #814, so a lane claims it after all | `--verify-lanes` | exit 1 | exit 1 |

**I3 is the one that mattered.** Deleting a package from the table exited **0**: the prefix sweep
printed it as a note and the run passed. A census whose own failure mode is "a package belongs to no
pass" cannot report all clear when a package leaves its table, so the sweep was changed from a note
to a failure, backed by an explicit `PREFIX_SWEEP_EXCLUSIONS` table (empty today, one entry per
prefix-matching package deliberately outside the family). Re-run after the change: exit 1,
`1 prefix-matching package(s) in neither FAMILY nor PREFIX_SWEEP_EXCLUSIONS: StdStorage`.

## What this does not check

- **`--verify-lanes` is forward only.** Every package assigned to issue N must be named in N's
  `## Lane`; a second issue also naming it is reported, not failed, because a lane legitimately
  names its neighbours (#982's lane explains `AppStd_Application` in terms of `TDocStd_Application`,
  which is #810's). A genuine double claim is visible in that report but is not caught
  automatically. Sixteen such extra namings exist today and every one is cross-reference prose
  written by this issue.
- **Ownership is not coverage.** Nothing here says whether a package's classes are wrapped,
  documented or deliberately omitted. That is each owning pass's job.
- **The family is the OCAF family only.** `--global` reports 248 shipped packages, 4771 headers,
  named by no lane at all. That is Phase 6's (#820) subject and deliberately out of scope: a lane
  names a prefix family, and most of those are foundation containers, collection instantiations and
  internal algorithm packages no pass would ever name individually. `SelectMgr_`, which `StdSelect_`
  sits directly on, is the one that a reader of this partition is most likely to ask about; #814's
  `## Lane` records that it is unowned and outside this scope.
- **`--reverify-family` needs `Libraries/occt-src`**, a `Scripts/build-occt.sh` artifact that is
  gitignored, so it cannot run in CI or a fresh clone. The prefix sweep in the plain run is the
  weaker form that works from the shipped headers alone.
