# #1022: `XCAFDoc_Datum::GetObject` reads the datum point's X from the annotation plane's array

`XCAFDoc_Datum.cxx`'s `ChildLab_Pnt` block builds the point from `aLoc`, the array the
`ChildLab_PlaneLoc` block above it fills, instead of `aPnt`, the point's own:

```cpp
gp_Pnt aP(aLoc->Value(aPnt->Lower()),        // aLoc, not aPnt
          aPnt->Value(aPnt->Lower() + 1),
          aPnt->Value(aPnt->Lower() + 2));
```

`XCAFDoc_GeomTolerance::GetObject`'s block is otherwise identical and reads
`aPnt->Value(aPnt->Lower())`, so this is a one-character divergence rather than a shared idiom.

## Files

| File | What it is |
|---|---|
| `occt_1022_datum_point.cxx` | The reproducer. Four sections, selected by a command-line argument, because two of them abort their process. |
| `run.sh` | Builds and runs it, `before` against the pinned archive and `after` with patch `0029` applied to a scratch copy and override-linked. |
| `run-gtest.sh` | Compiles the upstream GTests and runs them both ways. This is the "prove the test fails" step. |
| `stock.txt` | `run.sh before` transcript. |
| `patched.txt` | `run.sh after` transcript. |
| `gtest.txt` | `run-gtest.sh both` transcript. |

## The two faces of the defect

**A wrong answer when the datum has both a plane and a point.** Section A writes plane location
`(6,6,6)` and point `(7,7,7)` and reads back `point=(6,7,7)`. The stored point is not recoverable
from the returned object. Patched, it reads `(7,7,7)`.

**An uncatchable SIGSEGV when the datum has a point and no plane.** `aLoc` is declared before the
plane block and assigned only by a successful `FindAttribute` there, so it is still a null handle
when the point block dereferences it. That is an OS signal, not a `Standard_Failure`, so the
bridge's `catch (...)` cannot absorb it. Section C crashes in the process that wrote the datum;
section D writes the same document to BinXCAF, reloads it into a fresh `TDocStd_Application`, and
crashes on the reload. Patched, both read `point=(7,7,7)`.

**Section B is the control.** A datum with a plane and no point never enters the point block, and it
is byte-identical before and after.

## Reachability, measured rather than inherited

Both sections C and D read the datum with exactly the three calls `occtDocumentDatumObjectAt`
(`OCCTBridge_Document.mm`) makes: `XCAFDoc_DimTolTool::GetDatumLabels`,
`FindAttribute(XCAFDoc_Datum::GetID(), ...)`, `GetObject()`.

**Seven bridge functions route through that helper**, and five of them are write paths, so the
exposure is not read-side only. #1004 (PR #1025) hoisted the lookup out of what used to be seven
copies, which
means it is also a single guard site rather than seven:

| Bridge function | Swift surface |
|---|---|
| `OCCTDocumentGetDatumInfo` | `Document.datums`, `Document.datum(at:)` |
| `OCCTDocumentGetDatumModifier` | the datum's modifier list |
| `OCCTDocumentSetDatumPosition` | write |
| `OCCTDocumentSetDatumModifiers` | write |
| `OCCTDocumentSetDatumModifierWithValue` | write |
| `OCCTDocumentSetDatumTarget` | write |
| `OCCTDocumentSetDatumTargetPlacement` | write |

The helper calls `GetObject()` before any caller can look at what it returned, so a write that would
never have touched the point still takes the crash.

**A STEP import alone cannot produce the crashing shape.** `STEPCAFControl_Reader` sets a datum
plane (`STEPCAFControl_Reader.cxx:2845`) and never a datum point: the file's only `SetPoint` calls
are on an `XCAFDimTolObjects_DimensionObject`, a different class, and the enumerated mutations of a
datum object are `SetName`, `SetPosition`, `SetModifiers`, `SetModifierWithValue` and the datum
target ones. So a datum that came in from STEP is section B's shape, which is safe.

**An OCAF load can, and section D proves it.** `XCAFDimTolObjects_DatumObject::HasPlane()` and
`HasPoint()` are independent flags and `XCAFDoc_Datum::SetObject` writes the two label blocks
independently, so a point-without-plane datum is what the public OCCT API produces for such an
object. Section D shows the shape survives a BinXCAF save and reload, so a document authored by any
other OCCT-based application reaches it through `Document.loadOCAF` plus any of the seven entry
points above.

**Nothing on the GD&T write path can author it.** `OCCTDocumentCreateDatum` builds a
`XCAFDimTolObjects_DatumObject` with a name, a position and a `DatumModifWithValue_None` pair, and
nothing that reaches either branch. (#1004's own comment beside those two explains why they are
required by `SetObject` and why the datum-target setters are deliberately left alone.) So the datums
this package writes take neither branch, which is the only reason the existing suite did not crash.
**The label API can author it, which #1030 established and this sentence originally denied**:
`AssemblyNode.findChild(tag:create:)` plus `initRealArray(lower:upper:)` puts a `TDataStd_RealArray`
straight on the datum label's own point child, and `Tests/OCCTXCAFTests/Issue1030DatumLookupGuardTests.swift`
builds the crashing shape that way with no file and no importer involved.

**The STEP writer is a second reader of the same accessor, on a branch nothing here can take.**
`STEPCAFControl_Writer` calls `GetObject()` on every datum in three places, so exporting a document
that holds such a datum would take the same crash. All three sit on the AP242 branch, and
`writeSTEP` pins AP214 and exposes no schema setter, so the bridge cannot reach them. Unguarded and
unreachable, rather than guarded.

## The bridge guard, shipped as #1030

Implemented. When this directory was written the guard was reported rather than written, because
`OCCTBridge_Document.mm` was held by a concurrent agent; #1030 carried the decision and closed it.
`occtDatumLabelIsReadable` (`OCCTBridge_Document.mm`) refuses a datum whose `ChildLab_Pnt` child
holds a `TDataStd_RealArray` of length 3 while `ChildLab_PlaneLoc` holds none, or holds one that
cannot supply `aPnt->Lower()`, which is the index the kernel actually reads. It runs before
`GetObject()` at all three bridge sites that reach it, and it costs two private tag numbers, `14`
and `17` at this pin, that upstream can renumber with no compile-time signal here.

Two things this directory got wrong, both corrected by measurement in
[`Scripts/repro/1030-datum-lookup-guard/`](../1030-datum-lookup-guard/):

- **`occtDocumentDatumObjectAt` is not the only site.** `OCCTDocumentDimTolToleranceCount` and
  `OCCTDocumentEditorRescaleGeometry` reach `GetObject` through
  `XCAFDimTolObjects_Tool::GetGeomTolerances` and `XCAFDoc_Editor::RescaleGeometry`, outside the
  shared helper, and both crashed. They are guarded too.
- **They read a different table.** The shared helper reads the tool this bridge attaches to
  `Main()`; those two read the `XCAFDoc_DocumentTool` table at `0:1:4`, which is the one every
  importer writes. A datum in one is invisible to the other, so the sentence below about an OCAF
  load reaching the crash holds only for a document whose table sits where this bridge puts it.

The guard prevents the crash and does not recover the stored point: a datum with both a point and a
plane still reads back the plane's X, so patch `0029` is still what fixes the value.

## Relationship to `Scripts/repro/1004-gdt-accessors/`

`datum_point_without_plane.mm` there is where the defect was first measured, while wrapping the
datum accessors for #1004, and it covers the same two faces with the same fixture values. This
directory is the patch's validation harness rather than a second report of the same thing: it adds
the plane-only control, the OCAF save-and-reload that settles whether the crashing shape is
import-reachable, a `run.sh` that drives the patched and unpatched kernel side by side, and the
GTest harness. Read the #1004 probe for the discovery, this one for the fix.

## The fix

`Scripts/patches/0029-XCAFDoc_Datum-point-read-from-plane-array-1022.patch`, one character plus a
one-line comment. Filed upstream as
[OCCT#1483](https://github.com/Open-Cascade-SAS/OCCT/pull/1483).
