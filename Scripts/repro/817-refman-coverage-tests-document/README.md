# #817: refman coverage audit, tests, Document/XCAF (Pass 5c of #807/#819)

Two files:

| file | what it is |
|---|---|
| `derive_lane.py` | the lane, re-derived **by call**: which OCCT classes `OCCTXCAFTests` and the document half of `OCCTIOTests` exercise, reached through the Swift API they call. Three-hop reachability (test file → Swift member → bridge function → OCCT class), each hop's own module docstring, 17 self-test cases. |
| `refman_census.py` | the census: for every class #810's own script currently calls `ok` (wrapped+documented), is it tested by this lane? Re-runs #810's script live rather than re-typing its tables. 9 self-test cases. |

```bash
python3 Scripts/repro/817-refman-coverage-tests-document/derive_lane.py               # summary
python3 Scripts/repro/817-refman-coverage-tests-document/derive_lane.py --calls       # + full evidence chains
python3 Scripts/repro/817-refman-coverage-tests-document/derive_lane.py --files       # the IOTests document-half derivation
python3 Scripts/repro/817-refman-coverage-tests-document/derive_lane.py --self-test   # 17 detector cases
python3 Scripts/repro/817-refman-coverage-tests-document/refman_census.py             # the table
python3 Scripts/repro/817-refman-coverage-tests-document/refman_census.py --reverify-lane
python3 Scripts/repro/817-refman-coverage-tests-document/refman_census.py --self-test # 9 detector cases
```

Both run from any cwd, in about 40 seconds (the brace-balanced function-span scan over every
bridge `.mm`/`.h` file dominates). `--reverify-lane` needs `Libraries/OCCT.xcframework` and
reports SKIPPED without it, which is the normal case in this worktree and in CI.

## The lane

Per #817's own wording ("Pass 5c sweeps... `OCCTXCAFTests`, and the document half of
`OCCTIOTests`"), mirroring #810/Pass 3's source-side lane.

**`OCCTXCAFTests`**: all 115 files, no exceptions.

**`OCCTIOTests`, document half**: a file counts if the literal identifier `Document` (the
Swift type the XDE/OCAF surface is built on) occurs anywhere in it outside a comment. Seven
files match, confirmed by hand, not just by the regex: `GLTFTests.swift`,
`ImportProgressTests.swift`, `MeshAndExportProgressTests.swift`, `PLYExportOptionsTests.swift`,
`STEPCAFModeControlTests.swift`, `STEPWriterCAFCorruptionTests.swift`, `VrmlWriterTests.swift`.

**File granularity, not per-`@Test`-function granularity, deliberately.** Five of the seven mix
Document-touching tests with plain Shape-level import/export tests in the same `@Suite`:
`GLTFTests` (1 of 5 tests touches `Document`), `ImportProgressTests` (1 of 4),
`MeshAndExportProgressTests` (1 of 10), `PLYExportOptionsTests` (1 of 5), `VrmlWriterTests` (4 of
7). Two are Document-only end to end: `STEPCAFModeControlTests` (8 of 8) and
`STEPWriterCAFCorruptionTests` (1 of 1, and that one test's own *subject* is a shape-level STEP
write, with the CAF read only in its setup — included anyway, since #817 asks about the document
**half** of the target, not about excluding a test whose primary subject is geometry once a
document appears anywhere in its call chain). File granularity doesn't inflate the "tested"
count: the non-Document tests in a mixed file call `Shape`/`Exporter` members outside this
lane's 131-class population, so they contribute zero reachability evidence to any lane class
either way; the choice only affects which files get read, not which classes can be found.
`derive_lane.py --files` prints this derivation and confirms it against the constant every run
(`--self-test`'s `lane-drift` case: deleting the constant and re-deriving it must agree, and does,
0 files differing across 7 confirmed).

## The population: #810's own live output, not a re-typed copy

#817 says to reuse #810's class list "re-deriving/re-verifying rather than blindly trusting a
possibly-stale artifact." `refman_census.py` does this by **invoking #810's script as a
subprocess and parsing its stdout table**, the same relationship #810 itself has with
`census-doc-occt-attribution.py` (an external tool, run and read, not re-implemented). This
matters because #810's own numbers moved since it was written, exactly the "things move" pattern
#811's README already documents on a different lane:

| | #810's README (written) | #810's script (re-run for this pass) |
|---|---|---|
| `ok` (wrapped+documented) | 118 | **131** |
| `deliberate, recorded` | 160 | **147** |
| `under` | 0 | 0 |
| deferred over-coverage | 1 (#971) | **0** (fixed by #984 since) |

Thirteen more classes have been wrapped since #810 merged (GD&T value/modifier enums getting
real setters, `TDataStd_NamedData` gaining coverage, and others), and the one deferred
over-coverage finding was closed. **This pass's population is the live 131**, not the README's
118 — re-verified rather than assumed, per #817's own instruction.

`refman_census.py`'s `--reverify-lane` additionally re-derives the 278-class lane itself from
the pinned headers (the same glob #810's own `--reverify-lane` runs) and confirms it against
what #810's live output enumerates: zero drift, checked interactively against the main
checkout's `Libraries/` tree (absent in this worktree, as it is in CI and a fresh clone; the flag
reports SKIPPED there rather than passing silently).

## Result

| verdict | count |
|---|---|
| `ok` (tested) | **119** |
| `deliberate, recorded` | 0 |
| `under` | **12**, all twelve annotated: real tests exist, outside this lane (see below), filed as #1396 |

131 wrapped+documented classes, zero of them left as a genuine, unexplained gap. One real gap
(`XCAFDoc_LengthUnit`) was found and closed with new tests in this branch; the remaining twelve
`under` rows are a lane-boundary finding, not a coverage hole (also below).

## Five real bugs in the derivation itself, found by running it against the real tree

None of these were hypothesized in advance; each was found because the mechanical output looked
wrong for a class with an obviously-real, well-known test, and each has its own `--self-test`
case proving it both reproduces the bug (via a "naive" comparison using the pre-fix logic on the
same fixture) and that the fix resolves it. This is the shape `okf/policies/prove-the-test-fails.md`
asks for, applied to the detector itself rather than only to Swift test code.

1. **HOP 3, cross-file `static`-helper contamination.** `occtDocumentFormatsImpl` is `static` and
   redefined, differently, in six `.mm` files (a tree-wide sweep for the same shape,
   `static\s+\S+\s+occt\w+\(`, finds 24 further examples: `occtArgList`, `occtQuiltShells`,
   `occtWireInterpolateImpl`, ...). A first version keyed the call graph by bare function name
   alone, so `OCCTDocumentReadingFormats` (which calls the `DocumentLifecycle.mm` copy, touching
   only `TDocStd_Application`) inherited whatever ANY of the other five files' unrelated
   same-named copies reached — caught because `XCAFNoteObjects_NoteObject` and `XCAFView_Object`
   both showed up as "reached via `Document.swift::readingFormats`", which has nothing to do with
   either. Fixed: a graph node is `(file, name)` for a `static` definition, `name` alone
   otherwise, since C++ linkage means a `static` name is only ever callable from its own TU.
   Self-test: `hop3-static-file-scoping`.
2. **HOP 3, the interleaved-struct span boundary.** The same first version's function "body" ran
   from right after a `DEFN` match to the START of the *next* one, which is correct only if
   nothing but bridge functions ever sits between two of them. `OCCTBridge_Document_
   DocumentLifecycle.mm` interleaves three helper structs (`OCCTAssemblyGraph`/`XCAFDoc_
   AssemblyGraph`, `OCCTViewObject`/`XCAFView_Object`, `OCCTNoteObject`/`XCAFNoteObjects_
   NoteObject`) plus a non-`occt`-prefixed `getLabelForTag` between `occtDocumentFormatsImpl` and
   the next real bridge function, so all four leaked into `occtDocumentFormatsImpl`'s "body" and
   from there into every one of its callers. Fixed: proper brace balancing from each function's
   own parameter list to its own `{ ... }`, not "until the next similarly-named thing appears."
   Self-test: `hop3-interleaved-struct`.
3. **HOP 3, non-`occt`-prefixed helper indirection, and the `Handle(...)` macro trap it exposed.**
   `TDataStd_NamedData` — despite having its own dedicated, passing test file,
   `TDataStdNamedDataTests.swift` — came back `under`, because every `OCCTDocumentNamedData*`
   entry point reaches it only through `getOrCreateNamedData`/`findNamedData`, plain helper names
   with no `occt` prefix at all. Widening the definition-matching regex past the `occt`/`OCCT`
   prefix immediately re-broke on OCCT's own `Handle(ClassName)` smart-pointer macro: `static
   Handle(TDataStd_NamedData) getOrCreateNamedData(...)`'s non-greedy scan stopped at `Handle(`
   itself once ANY identifier-plus-paren became a valid match, so the real name was never found
   (the opposite failure). Fixed with a `(?!Handle\b)` exclusion, the one builtin name this
   bridge's style actually needs excluded (measured across all 9032 matches the widened regex
   produces; `bool` also gets caught by `typedef bool (*Callback)(...)`, but always as a
   `;`-terminated declaration with an empty span, so it's harmless without its own exclusion).
   Self-tests: `hop3-handle-macro-exclusion`, `hop3-non-occt-prefixed-helper-indirection`.
4. **HOP 2, a multi-line signature's closing line at the SAME indentation as its own `func`
   line.** `GDTToleranceDatumAccessorTests.swift`'s real, passing calls to
   `setGeomToleranceValueType`/`setGeomToleranceMaterialRequirement`/`setGeomToleranceZoneModifier`
   came back as reaching no lane class, because
   ```swift
   public func setGeomToleranceValueType(
       at index: Int,
       _ valueType: GeomToleranceValueType
   ) -> Bool {
       OCCTDocumentSetGeomToleranceTypeOfValue(handle, Int32(index), valueType.rawValue)
   }
   ```
   has its closing `) -> Bool {` at the same 4-space indentation as `public func
   setGeomToleranceValueType(` itself, not one level deeper, so the indentation-climbing
   algorithm (already rewritten once, see bug 5) dropped its floor to 4 at the closing line and
   then could never recognize the `func` line — also at 4 — as a further, valid dedent. Fixed by
   `_wrapped_signature_start`: before lowering the floor on a non-matching dedent, look further
   back at the SAME indentation for a `func`/`var`/`init` line with an unbalanced open paren (a
   real multi-line signature's tell; a complete one-line declaration like `func helper() {}`
   is parenthesis-balanced and correctly rejected, which the very next bug's fixture depends on).
   Self-tests: `hop2-wrapped-multiline-signature`, `hop2-wrapped-if-condition-not-mistaken-for-signature`.
5. **HOP 1, an `init` call has no dot.** `XCAFDocAssemblyGraphTests.swift`'s real, passing
   `AssemblyGraph(document: doc)` came back as reaching no class: HOP 2 correctly resolves the
   `OCCTAssemblyGraphCreate` call inside `AssemblyGraph.swift`'s `init?(document:)` to member
   `init`, but Swift constructor calls are written `TypeName(args)`, never `.init(args)` — there
   is no dot at all, so the plain `.member\b` substring test can never see it, no matter how many
   tests call it. Fixed by also checking the bare type name (the Swift file's own basename)
   called as `TypeName(`, exploiting this codebase's one-type-per-file convention — checked, not
   assumed, for every file this fix touches (`AssemblyGraph`/`NoteObject`/`ViewObject` all declare
   a type matching their filename). Self-tests: `hop1-constructor-call-has-no-dot`,
   `hop1-constructor-call-type-name-is-specific`.

Also fixed along the way, found on the very first real file the tool ran against, before any of
the five above: a local `var handles = [...]` two lines above its own bridge call resolved as the
enclosing "member" ahead of the real `func tracedForward(...)`, because Swift reuses `var`/`let`
for locals and members alike and a first version took the nearest preceding declaration-shaped
line regardless of nesting. Fixed by climbing indentation instead (a local sits at the SAME
indentation as its sibling statements, never less). Self-test: `hop2-local-var-not-mistaken-for-member`.

**17 self-test cases in `derive_lane.py`, all load-bearing**, each printed with what it proves
when it isn't merely "does this pass":

```
[PASS] hop3-direct-mention
[PASS] hop3-span-isolation
[PASS] hop3-interleaved-struct [load-bearing: the old 'up to the next OCCT*/occt* match' boundary leaks the interleaved struct's class into OCCTHelper's body; brace balancing does not]
[PASS] hop3-handle-macro-exclusion [load-bearing: without the exclusion, the real function name is never found at all -- the match stops at 'Handle']
[PASS] hop3-non-occt-prefixed-helper-indirection
[PASS] hop3-field-translation [load-bearing: field map removed -> class invisible]
[PASS] hop3-two-level-indirection [load-bearing: 1 round alone would miss it]
[PASS] hop3-static-file-scoping [load-bearing: the naive bare-name keying this replaced gives OCCTFoo BOTH classes, cross-contaminated from FileB's unrelated same-named static helper]
[PASS] hop2-nearest-preceding-decl
[PASS] hop2-wrapped-multiline-signature [load-bearing: the plain floor-lowering algorithm never finds this one, since the closing `) -> Bool {` and the `func` line it belongs to are at the exact same indentation]
[PASS] hop2-wrapped-if-condition-not-mistaken-for-signature
[PASS] hop2-local-var-not-mistaken-for-member [load-bearing: the naive nearest-preceding-line approach this replaced resolves the same fixture to 'handles', the local var, not 'tracedForward']
[PASS] hop2-climbs-through-nested-control-flow-to-real-member
[PASS] hop1-generic-member-flagging
[PASS] hop1-constructor-call-has-no-dot [load-bearing: the plain '.init' substring test finds nothing in this exact corpus]
[PASS] hop1-constructor-call-type-name-is-specific
[PASS] lane-drift (0 files differ, 7 confirmed)
```

There is no separate `selftest_removal_matrix.py` companion here, unlike #810/#811. Each case
above already carries its own removal comparison inline (a `naive_*` variable computed with the
pre-fix logic on the identical fixture, asserted to reproduce the original wrong answer) rather
than a second script re-running the same fixtures with each guard toggled off; given every one of
the five bugs above was found by running the tool for real rather than guessed, the inline
comparison is the more direct evidence and a separate matrix would be restating it.

`refman_census.py` has its own 9 self-tests, all load-bearing, covering: #810-output parsing
(including a `RuntimeError` on zero parsed rows, so a format change can't silently reclassify
every lane class `under`), the wrapped-classes filter, the three-way `ok`/`deliberate,
recorded`/`under` split (with the gaps.md-removal flip proven), the generic-member review gate,
the `TESTED_OUTSIDE_LANE` annotation, and the over-coverage regression/deferred/claim-pattern
machinery:

```
[PASS] parse-810-output: all three verdict shapes parsed correctly
[PASS] parse-810-output-empty [load-bearing: an empty/garbled 810 output raises rather than silently classifying every class 'under']
[PASS] wrapped-classes-filter
[PASS] classify-tested-three-way [load-bearing: removing the gaps.md text flips deliberate,recorded -> under]
[PASS] generic-member-requires-review [load-bearing: an un-adjudicated generic hit does not auto-pass]
[PASS] tested-outside-lane-annotation [load-bearing: verdict stays 'under' either way, only the note changes -- removing the entry loses the #1396 pointer]
[PASS] over-finding-regression-substring [load-bearing: phrase present -> detected; phrase removed -> not detected]
[PASS] deferred-finding-inversion [load-bearing: fixed-without-moving is caught]
[PASS] claim-pattern-sweep [load-bearing: a neutral comment does not false-fire]
```

## Hand-adjudicated generic-member hits

Three classes are reached ONLY through a member in `derive_lane.GENERIC_MEMBERS` (`init`, in all
three cases — a bare-type-name constructor call is common enough that requiring hand review
before trusting it is the right default). Each was individually confirmed against the real test
body, recorded in `REVIEWED_HITS`:

- `XCAFDoc_AssemblyGraph`: `Tests/OCCTXCAFTests/XCAFDocAssemblyGraphTests.swift:14`,
  `AssemblyGraph(document: doc)` followed by real assertions on `nodeCount`/`linkCount`/`rootCount`.
- `XCAFNoteObjects_NoteObject`: `Tests/OCCTXCAFTests/XCAFNoteObjectsTests.swift`, six
  `NoteObject()` constructions across its six test functions, each followed by real property
  assertions.
- `XCAFView_Object`: `Tests/OCCTXCAFTests/XCAFViewObjectTests.swift`, seven `ViewObject()`
  constructions, each followed by real property assertions.

## The one real under-coverage finding: fixed in this branch

**`XCAFDoc_LengthUnit`** (backing `Document.lengthUnit`) was wrapped and documented with **zero
test anywhere in the whole suite**, not just this lane — checked directly (`grep -rn
'\.lengthUnit\b' Tests/*/*.swift`), not inferred from the lane result alone. The bridge exposes
no setter (matching `docs/occtswift-wrapping-gaps.md`'s existing pattern for read-only-from-the-
bridge classes; OCCT's own `XCAFDoc_LengthUnit::Set` is never called), so the only way to produce
a document carrying one is a real STEP round-trip: STEP's header carries an explicit unit, and
`STEPCAFControl_Reader` records it via `XCAFDoc_LengthUnit::Set` on import.

Small enough to fix here: two tests added to `Tests/OCCTXCAFTests/DocumentTests.swift`
(`lengthUnitReadsBackFromSTEP`, `lengthUnitNilOnFreshDocument`). Proved per
`okf/policies/prove-the-test-fails.md`: `lengthUnit`'s getter was temporarily forced to
`return nil` — `lengthUnitReadsBackFromSTEP` failed (`Expectation failed: ... lengthUnit → nil →
nil`), `lengthUnitNilOnFreshDocument` still passed (nil is what it expects, so this half also
proves the getter's early-return path isn't the only thing exercised); then forced to
`return LengthUnit(scale: 1.0, name: "mm")` unconditionally — `lengthUnitNilOnFreshDocument`
failed (`Expectation failed: (doc.lengthUnit → LengthUnit(scale: 1.0, name: "mm")) == nil`),
`lengthUnitReadsBackFromSTEP` still passed. Both injections reverted; `swift test --filter
DocumentTests` green (9 tests, 2 suites) after restoring the real implementation.

## Twelve more mechanical `under` rows: tested, but not in this lane — filed as #1396

The remaining twelve `under` classes are all `TDataStd_*`: `BooleanArray`, `BooleanList`,
`ByteArray`, `ExtStringArray`, `ExtStringList`, `IntPackedMap`, `IntegerList`, `NoteBook`,
`RealList`, `ReferenceArray`, `ReferenceList`, `Relation`. Every one of them has a real, passing
test — ten inside `OCCTFoundationTests` (a general catch-all: Color/Material/OSD/Message/Units/
etc., not a dedicated "FoundationClasses toolkit" lane), two (`BooleanArray`/`BooleanList`) as
their own files inside `OCCTModelingTests`, apparently keyword-matched on "Boolean" even though
both test plain `Document.setBooleanArray`/`booleanArray`/`hasBooleanArray`-style OCAF attribute
round-trips with nothing to do with Boolean shape operations. Every *other* `TDataStd_*` test in
the tree lives in `OCCTXCAFTests` (`TDataStdIntegerTests.swift`, `TDataStdRealTests.swift`,
`TDataStdNamedDataTests.swift`, ...), so this reads as historical drift rather than a deliberate
categorization.

This is **not** the "zero test exists" shape #817's own under-coverage handling section
describes, so it is filed rather than fixed here, per that section's own distinction between "add
a test" and "file a follow-up" — moving 12 suites across 3 files is a distinct, mechanical piece
of work outside this pass's mandate (coverage, not organization). Filed as
[#1396](https://github.com/SecondMouseAU/OCCTSwift/issues/1396). `refman_census.py`'s
`TESTED_OUTSIDE_LANE` table carries the evidence (file/suite per class) and annotates each row's
`note` with the issue number, rather than silently promoting any of the twelve to `ok`: the table
still answers "does THIS LANE cover it" honestly, and a reviewer reading the `under` row sees
immediately that it isn't a real gap.

## Over-coverage sweep

`find_claim_candidates()` scans every lane test file's `//`/`///` comments for an explicit
behavioural or numeric claim (`atomic`, `thread-safe`, `guarantee`, `always`, `never`, `must`, `in
order`, `deterministic`, `tolerance of`, `exactly`, `shares...document`, `concurrent`): **28
lines** across 15 files. Every one was read in context and checked against the actual refman text
for the class involved, via the `context` MCP where the claim named an OCCT method directly, per
#817's own instruction not to trust a keyword match.

**Given the XCAF/OCAF thread-safety cluster in CLAUDE.md's Known OCCT Bugs (#298/#341/#344/#349/
#353/#371/#374), a wider, dedicated sweep specifically for save/load atomicity or
document-sharing language** (`thread.safe|concurrent|atomic(ally)?|singleton|shared
(process|across)|mutex|serializ`) was run across the whole lane, not just the 28 keyword hits:
**zero matches**, including in every OCAF save/load test file
(`OCAFSaveLoadBinaryTests.swift`, `OCAFSaveLoadXmlTests.swift`, `OCAFSaveInPlaceTests.swift`,
`OCAFDocumentMetadataTests.swift`, `DirectoryTests.swift`, `OCAFFormatRegistrationTests.swift`).
No lane test comment makes any claim about atomicity, thread-safety, or document-sharing
semantics at all, in either direction. This is a real, checked negative, not an unexamined gap:
the actual thread-safety guarantees CLAUDE.md documents live in `docs/thread-safety.md` and the
kernel-fix writeups, not in test comments, and none of those tests assert on the property in a
way that would break if the refman's own (silent) stance on it ever mattered.

**Zero genuine over-coverage findings.** Every one of the 28 candidates, on reading, falls into
one of three buckets, none of them "asserts a contract the refman doesn't support":

- **Test-fixture design rationale**, not an OCCT contract claim (e.g. `AssemblyNodeIdentityTests.swift:39`'s
  "`Int64.max` is guaranteed not to be a real label," about the test's own sentinel choice; the
  `BRepGraphAttributeTests.swift` determinism claims, about OCCTSwift's own wrapper object model,
  not an OCCT class at all — `BRepGraph`/`NodeRef` are this project's own abstraction).
- **Self-verifying regression tests for already-fixed, already-documented bugs**
  (`Issue970TransactionAPITests.swift:111`'s "never greater than 1" restates #970's own correction,
  already in #810's `KNOWN_OVER_FINDINGS`; `XDEColorToolByShapeTests.swift:49` and
  `STEPWriterCAFCorruptionTests.swift:41` both restate already-filed, already-fixed bugs, #763 and
  #280 respectively, with a test that would fail loudly if OCCT's behaviour ever changed, which is
  the correct response, not a hidden risk).
- **An accurate description of undocumented behaviour, checked against the real refman text and
  found genuinely undocumented rather than contradicted** — the one candidate worth naming
  specifically: `GDTDimensionAccessorTests.swift:75`'s claim that
  `XCAFDimTolObjects_DimensionObject::GetNbOfDecimalPlaces` "answers a flat (0, 0)... which is
  indistinguishable from a real (0, 0) request" traces to the bridge's own comment two lines above
  its read (`OCCTBridge_Document_GDT.mm:856-857`: "its pair is stored on the label only when one
  of the two is positive, so that condition is the presence test") and to the bridge's actual
  logic (`info.hasDecimalPlaces = (left > 0 || right > 0);`). The refman documents
  `GetNbOfDecimalPlaces`/`SetNbOfDecimalPlaces` (checked via the `context` MCP,
  `occt-refman@8.0.1`) with a one-line description each, no mention of a stored/absent
  distinction either way. Not dangerous: the test itself only ever exercises `(2, 3)` against a
  never-written state, never the genuinely ambiguous `(0, 0)` case the comment describes, so the
  comment is an accurate note about a real, separately-observed OCCT persistence quirk rather than
  an assumption the test's own assertions depend on.

## What this pass did not do

- **No per-`@Test`-function lane membership**, only per-file (see "The lane" above). Narrower
  than a function-level derivation would be, in one direction only: a mixed IOTests file is
  entirely in-lane even for its non-Document tests, which is harmless for the reachability
  question (argued above) but means the lane's own *test count* (122 files) overstates how many
  individual `@Test`s are genuinely Document-related.
- **HOP 2's member-name resolution is per bare name, not per overload.** Two different types'
  methods sharing a name (e.g. two unrelated `count` properties) would merge under one
  `(swift_file, member)` key if they lived in the same file; checked, not assumed, for this
  lane's actual resolved names (`derive_lane.py --calls`' own per-class evidence lines show one
  bridge-function set per member, no case observed where a single Swift file's two same-named
  members needed disambiguating), but not proven impossible in general.
- **Swift string literals are not stripped**, only `//`/`/* */` comments (matching
  `Scripts/derive-bridge-header-split.py`'s own `strip_comments`). A member name mentioned only
  inside a Swift string literal (an error message, say) would be a false HOP-1 hit; checked by
  hand that no lane Swift member name resolved here also appears as an English word inside a
  string literal in `Document.swift`/`GDTRead.swift`/`GDTWrite.swift` that isn't the member's own
  name, not proven exhaustively for every file `swift_member_bridge_calls()` reads (all of
  `Sources/OCCTSwift`).
- **The over-coverage sweep is a curated candidate list plus targeted reading, not a live
  detector.** `CLAIM_PATTERNS` is a fixed set of English phrases; a genuine overclaim phrased
  without any of them (no "always"/"never"/"guarantee"/... and no save/load-specific keyword
  either) would not surface. #810/#811's own detectors (`census-doc-occt-attribution.py`, the
  method-attribution checker) answer a *different* question — does a doc/comment name the WRONG
  OCCT class or member — and don't apply here, since a test's over-coverage risk is about
  asserting more than a *correctly-named* class's contract promises, not about naming the wrong
  class.
- **No dedicated `selftest_removal_matrix.py`.** Explained above: every self-test case in
  `derive_lane.py` already carries its own inline "naive" comparison against the pre-fix logic on
  the real bug's own fixture, which is the removal-matrix's evidence in a more direct form here,
  since none of the five bugs were hypothesized in advance to build a matrix row for.
