# #813: refman coverage audit, Export/interop lane (Pass 4c of #807)

Four files:

| file | what it is |
|---|---|
| `derive_lane.py` | the lane, re-derived from the pinned kernel's own headers. #813's own `## Lane` text names eleven package prefixes and "192 headers"; a naive prefix match without an optional bare-header suffix undercounts at 190, missing four bare `<Package>.hxx` headers (`BinTools.hxx`/`RWMesh.hxx`/`RWObj.hxx`/`StlAPI.hxx`), the same shape #812 found for `HLRAlgo.hxx`/`HLRBRep.hxx`. |
| `refman_census.py` | the census. 192 classes, four verdicts, an over-coverage sweep, a family-count assertion, a lane re-derivation, and its own self-test. |
| `selftest_removal_matrix.py` | the proof that the self-test's guards are load-bearing. Found a real decoration bug on its first run (the same shape #811/#812's own matrices found): the `none-propagation` shape had a case in the module docstring's aspiration but not in `SELF_TEST_CASES` itself, `0/14` broke when disabled. Fixed by adding a real, lane-native case (`RWObj_CafReader`, whose second base `RWObj_IShapeReceiver` has no header of its own). |
| `README.md` | this file. |

```bash
python3 Scripts/repro/813-refman-coverage-export-interop/derive_lane.py
python3 Scripts/repro/813-refman-coverage-export-interop/derive_lane.py --wrapped
python3 Scripts/repro/813-refman-coverage-export-interop/refman_census.py
python3 Scripts/repro/813-refman-coverage-export-interop/refman_census.py --verbose
python3 Scripts/repro/813-refman-coverage-export-interop/refman_census.py --reverify-lane
python3 Scripts/repro/813-refman-coverage-export-interop/refman_census.py --self-test
python3 Scripts/repro/813-refman-coverage-export-interop/selftest_removal_matrix.py
```

All run from any cwd, in about a second. The checks that read the pinned headers report SKIPPED
rather than passing silently without `Libraries/OCCT.xcframework` (a fresh clone or CI has neither;
this checkout symlinks `Libraries/` to the sibling checkout pinned to the same `V8_0_1` + patches
asset as this branch's own `Package.swift`).

## Result

| verdict | count |
|---|---|
| `ok` | 22 |
| `deliberate, recorded` | 170 |
| `under` | 0 |
| `over` | 0 (3 found, all fixed in this PR; see below) |

**Before this PR the same table read `ok` 22, `deliberate, recorded` 0, `under` 170.**

## What the lane actually is

#813's `## Lane` text names eleven package prefixes directly (unlike #811/#812, which each had to
re-derive at least part of their own lane by call): `STEPControl_`, `IGESControl_`, `StlAPI_`,
`RWObj_`, `RWGltf_`, `RWPly_`, `RWMesh_`, `Interface_`, `Transfer_`, `BinTools_`, `Resource_`. The
one thing that DID need re-deriving was the header count: a plain `grep -c '^Prefix_'`-style match
gives 190, not the 192 the issue text states, because four packages ship a bare `<Package>.hxx`
package-utility header with no trailing underscore (`BinTools.hxx`, `RWMesh.hxx`, `RWObj.hxx`,
`StlAPI.hxx`). Once the regex accepts an optional `_Suffix`
(`^Prefix(_[^.]+)?\.hxx$`), the count is exactly 192.

`BinTools_`/`Resource_` are in this lane on #973's own measurement, not their toolkit's usual
placement: `BinTools_` is BREP-family serialisation (`ModelingData/TKBRep` in OCCT's own toolkit
layout) whose consumers outside OCAF are `DEBREP_`/`BRepFill_`; `Resource_` is the STEP/IGES text
encoding switch (`Resource_Unicode::SetFormat`) plus twelve of its seventeen consumers being
`DESTEP_`/`DEIGES_`/`STEPControl_`/`STEPCAFControl_`/`StepData_`/`XSAlgo_`/`ShapeProcess_`/`Units_`.
Neither is re-litigated here; #813's own body records the measurement. OCAF's own persistence
formats (`PCDM_`/`Storage_`/etc., #983's lane, Pass 3c) are explicitly not this lane's, for the
same reason.

## What found the over-coverage, and what happened to each candidate

`Scripts/census-doc-occt-attribution.py --lane STEPControl_,IGESControl_,StlAPI_,RWObj_,RWGltf_,RWPly_,RWMesh_,Interface_,Transfer_,BinTools_,Resource_`
(#928) surfaced **3 candidates**, **1 true, 2 false**:

```
docs/API_REFERENCE.md:702                       STEPControl_Reader via=OCCTDocumentLoadSTEPProgress,OCCTImageLoad,OCCTSewingLoad  [heading]
docs/reference/Document-Persistence-IO.md:1021  RWMesh_CoordinateSystemConverter via=OCCTDocumentLoadOBJ,... (+1)                 [heading]
docs/reference/Shape.md:1623                    Interface_Static via=OCCTImportSTEPWithUnitProgress                              [explicit]
```

The first is a heading-based mismatch: the detector's walker matched the generic word "load" to
unrelated bridge functions (`OCCTImageLoad`, `OCCTSewingLoad`, neither STEP-related); the real
function, `OCCTImportSTEPProgress`, does construct `STEPControl_Reader` correctly. The second is a
cross-function hidden-member case: `RWMesh_CoordinateSystemConverter` is a private member
`RWObj_CafReader`'s base class owns, set via the public `SetFileCoordinateSystem`/
`SetSystemCoordinateSystem` setters the named function calls directly, not constructed by name in
that function's own body -- the exact shape #812's own `HLRBRep_HLRToShape` false positive was. The
third is TRUE: `Shape.loadSTEP(from:unitInMeters:progress:)`'s doc said "`STEPControl_Reader` with
`Interface_Static` unit setting", but the bridge (`OCCTImportSTEPWithUnitProgress`,
`OCCTBridge_IO.mm:497-498`) calls `reader.SetSystemLengthUnit(unitInMeters)` directly, a real
method on `STEPControl_Reader` itself; `Interface_Static` is never touched for this call.

**Beyond the automated pass, every remaining `- **OCCT:**` bullet touching this lane's 22 wrapped
classes was read against the pinned headers by hand**, the same discipline #811/#812 applied. Two
more findings turned up this way, neither the #928 detector's shape (it only checks whether a
NAMED class is reachable from a NAMED function; these two named the WRONG class/method entirely,
which the detector cannot see):

- `docs/reference/Document-XCAF-Notes.md` (4 lines, `Shape.toBinaryData()`/`fromBinaryData()`/
  `writeBinary()`/`loadBinary()`): attributed to the bare `BinTools` class's static `Write`/`Read`
  methods. The bridge constructs `BinTools_ShapeWriter`/`BinTools_ShapeReader` and calls their
  instance methods (`OCCTBridge_IO.mm:2448-2522`); confirmed zero `BinTools::` call sites
  tree-wide.
- `docs/reference/Shape.md:1885`: `OCCTImportIGESRoot` attributed to
  `IGESControl_Reader::Transfer`. No method named plain `Transfer` is declared on
  `IGESControl_Reader` or its base `XSControl_Reader` -- OCCT's own header comment says
  `reader.Transfer(num)` in prose, a stale name the class itself never implements. The bridge
  calls `reader.TransferOneRoot(rootIndex)`, confirmed real and reachable via a base-class walk
  (`XSControl_Reader.hxx:169`).

All three are fixed in this PR: see the PR diff for `docs/reference/Document-XCAF-Notes.md` and
`docs/reference/Shape.md`. `census-doc-occt-attribution.py`'s false-positive rate on this lane is
2/3 (67%), the highest of the three lanes it has now run on (41% over a 40-row hand-adjudicated
sample overall, 5.3% on #811's lane, 0% on #812's) -- worth noting, not acted on: CLAUDE.md already
records this script stays a report rather than a gate for exactly this reason, and this lane's own
small sample (3 candidates) is too little to move that rate on its own.

## A limitation this pass found and worked around

`declares_member()` (the header-membership checker `check_method_attributions()` and this file's
own self-test both use) does **not** strip comments before searching. `IGESControl_Reader.hxx`'s
own doc comment literally reads `reader.Transfer(num)` in prose two lines above the real
`TransferOneRoot` declaration it describes, so `declares_member("IGESControl_Reader", "Transfer")`
returns `True`, not `False` -- a false positive from the mechanism's blindness to comments,
inherited unchanged from #811/#812's implementation, not a new defect introduced here. Concretely
this means `check_method_attributions()` (the automated gate inside `refman_census.py`'s main run)
would **not** have caught the `IGESControl_Reader::Transfer` over-coverage finding on its own: a
hand read of the actual bridge call site is what found it. `refman_census.py`'s own main-run output
now says this explicitly next to the "every attribution resolves" line, and `SELF_TEST_CASES`
picks a genuinely comment-free negative (`Resource_Manager::SetValue`,
`RWMesh_FaceIterator::HasNext`, etc.) rather than the misleading one, so the self-test's own
`False` cases stay honest about what the mechanism can and cannot see.

## The findings (under-coverage)

170 of the 192 classes needed a reason. Almost none is a genuine capability gap: this lane is
almost entirely the generic OCCT data-exchange (XSTEP) framework `STEPControl_Reader`/`Writer` and
`IGESControl_Reader`/`Writer` are thin facades over (`Interface_*`/`Transfer_*`, ~100 classes), plus
the low-level format machinery `RWGltf_CafReader`/`CafWriter`, `RWObj_CafReader`/`CafWriter` and
`BinTools_ShapeReader`/`ShapeWriter` drive internally -- the same shape #812 found for hidden-line
removal's own ~60 internal engine classes underneath five public entry points. Every bucket and
reason is in `docs/occtswift-wrapping-gaps.md`'s new "Export/interop lane" section, not repeated
here; that is the file the census checks against, and this README going stale must not be able to
make the gate pass on the wrong evidence.

**Four are real, small, unaddressed capability gaps**, recorded rather than fixed (none large
enough to justify a same-PR fix or its own follow-up issue, per #813's own done-when criteria which
ask only for a recorded reason): `RWMesh_EdgeIterator` (sibling of the wrapped
`RWMesh_FaceIterator`/`VertexIterator`, simply missing), `RWGltf_DracoParameters` (glTF Draco
mesh-compression settings, no bridge control at all), `Interface_Check`/`Interface_CheckIterator`
(per-entity STEP/IGES read diagnostics, not surfaced anywhere in the tree).

## The false-positive risk #813 flags explicitly

#813's own body warns: "The PDF/SVG/DXF writers in this lane have no OCCT counterpart at all (#795
consolidated them onto one pure-Swift dispatcher), the same false-positive risk as Pass 4b's audit
(#812) had to handle explicitly." `derive_lane.py` checks this directly rather than asserting it:
`PDFExporter.swift` and `SVGExporter.swift` call zero `OCCT*` identifiers; `DXFExporter.swift`'s
only `OCCT` occurrence is a comment ("OCCT ships no DXF reader or writer..."), not a symbol. None of
the three is in `LANE_CLASSES`, `CURATED`, or anywhere the census's verdict table could
misclassify them, because they never enter the table at all: the table is built from the pinned
kernel's own 192 headers, not from a Swift-file sweep.

**The lane also changed underneath this issue, exactly as #813's own body warns.** Pass 4c's
duplication work (#387) landed the same day this audit was written, adding
`validateExportInputs`/`DrawingEntityBuffer`/`dashLengths`/`writeWithProgress`/`dataViaTempFile` to
`Exporter.swift`/`DXFExporter.swift`/`PDFExporter.swift`/`SVGExporter.swift`. Re-checked directly
(the `derive_lane.py` output above) rather than assumed stale: none of those additions touches
OCCT, so the false-positive-risk finding is unaffected.

## Proving the detectors fail

`selftest_removal_matrix.py` switches off each accepting shape in turn:

```
declares_member baseline: 15/15 cases pass unmodified

  method-call          disabled -> 6/15 cases fail  [load-bearing]
  nested-type          disabled -> 1/15 cases fail  [load-bearing]
  data-member          disabled -> 1/15 cases fail  [load-bearing]
  base-class-walk      disabled -> 4/15 cases fail  [load-bearing]
  none-propagation     disabled -> 1/15 cases fail  [load-bearing]
  alias-template       disabled -> 0/15 cases fail  [redundant on this lane]

_ATTRIBUTION_RE baseline: 6/6 cases pass with the shipped pattern

  closing-backtick-anchor    imposed -> 2/6 cases fail  [load-bearing]
  no-leading-backtick        imposed -> 1/6 cases fail  [load-bearing]

classify baseline (real tree): {'ok': 22, 'deliberate, recorded': 170, 'under': 0}
  docs-first AND gaps.md-as-docs -> {'ok': 192, ...}  [load-bearing]
    ordering alone                -> {'ok': 25, ...}   [load-bearing]
    gaps.md-as-docs alone         -> {'ok': 22, ...}   [redundant on this lane]
```

**One shape was decoration on the first run, the same class of finding #811/#812's own matrices
made.** `none-propagation` (a base's `None` -- header not shipped -- must propagate up rather than
be swallowed into `False`) reported `0/14 cases fail` because `SELF_TEST_CASES` only had a
header-absent `None` case (`Interface_813NoSuchClass`, a fabricated name, needed because this lane
has no alias-template-shaped curated class the way #812's `HLRBRep_CLProps` was), never a
propagated-`None` one. Fixed by adding a real, lane-native case: `RWObj_CafReader` (wrapped) has
two bases, `RWMesh_CafReader` (shipped, resolves cleanly to `False`) and `RWObj_IShapeReceiver`
(declared inline inside `RWObj_CafReader.hxx` itself, with no separate header of its own,
confirmed absent from the pinned `Headers/`). Re-run after the fix: `1/15 cases fail` with
`none-propagation` disabled, `[load-bearing]`.

**`ordering alone` is load-bearing on THIS lane by itself, unlike #811/#812's own lanes where only
the COMBINATION (ordering + gaps.md-as-docs) was.** `BinTools` and `RWMesh`, the two bare
package-utility headers, have real doc hits in `docs/API_REFERENCE.md` and
`docs/reference/Document-XCAF-Notes.md`/`Document-Mesh-Fixing.md` -- not gaps.md, real reference
docs -- so moving the docs test ahead of the curated table misclassifies both as `ok` on the docs
hit alone, without even needing the gaps.md leak #811/#812's own matrices required. Injected
directly: `docs-first, gaps.md-as-docs=False` gives `{'ok': 25, 'deliberate, recorded': 167,
'under': 0}` against the baseline's `{'ok': 22, 'deliberate, recorded': 170, 'under': 0}`, a
3-class swing, confirmed by name: `BinTools` and `RWMesh` (the over-coverage finding's own bare
class and its package sibling) plus `RWMesh_ShapeIterator` (named once in
`docs/reference/Document-Mesh-Fixing.md`, explaining that `RWMesh_FaceIterator`/`VertexIterator`
inherit it, an informative aside rather than a claim that the abstract base itself is
independently documented). `gaps.md-as-docs alone` is, as in #811/#812, redundant on this lane:
every one of the 170 recorded classes is in a curated table, so the exclusion has nothing to
exclude by itself.

`wrapped-before-curated: 0 lane classes are BOTH wrapped and in a curated table` -- kept anyway,
same as #811/#812 keep it: the property under test is the RULE ("wrapped beats curated"), not that
this particular lane has a live instance of it.

The main check was proved the same way #811/#812 proved theirs: `docs/occtswift-wrapping-gaps.md`'s
new section was temporarily stripped of one class name (`BinTools_ShapeSet` -> `XXXREMOVEDXXX`, a
plain-text substitution) and `refman_census.py` re-run. It reported `BinTools_ShapeSet` as `under`
with "no line in occtswift-wrapping-gaps.md" and exited 1; restoring the file returns it to
`deliberate, recorded` and exit 0.
