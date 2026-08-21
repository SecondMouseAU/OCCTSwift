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

**Nothing in this repo can author it today.** `OCCTDocumentCreateDatum` builds a
`XCAFDimTolObjects_DatumObject` with a name, a position and a `DatumModifWithValue_None` pair, and
nothing that reaches either branch. (#1004's own comment beside those two explains why they are
required by `SetObject` and why the datum-target setters are deliberately left alone.) So the datums
this package writes take neither branch. That is the only reason the existing suite does not crash,
and it is a property of the current write surface rather than of the read path.

**The STEP writer is a second reader of the same accessor.** `STEPCAFControl_Writer` calls
`GetObject()` on every datum in three places, so exporting a document that holds such a datum takes
the same crash as reading it.

## Whether the bridge should guard as well

Reported, not implemented. The reason is an ownership boundary rather than a judgement that the
guard is wrong: `OCCTBridge_Document.mm` is held by a concurrent agent in this lane, so a guard
written here would race their edits in the file the guard belongs in. #1030 carries the decision, so
it is tracked rather than deferred into prose.

The crash is uncatchable and patch `0029` is in no built kernel, so no released consumer is
protected by it today. Tracked as #1030. A bridge-side guard is possible but not free: the check
has to happen **before** `GetObject()` is called, and `XCAFDoc_Datum` exposes no `HasPlane()`, so
the only way to ask is to look at the label's children directly. It would go in
`occtDocumentDatumObjectAt`, the one place all seven entry points share. `ChildLab_PlaneLoc` and
`ChildLab_Pnt` are values of a **file-local anonymous enum** in `XCAFDoc_Datum.cxx`, not visible
from the header, and they are tags `14` and `17` at this pin. The guard would be: if `FindChild(17, false)` holds a
`TDataStd_RealArray` of length 3 and `FindChild(14, false)` holds no `TDataStd_RealArray`, skip the
datum rather than call `GetObject()`. Note the plane condition is only about `ChildLab_PlaneLoc`:
the kernel's `&&` chain assigns `aLoc` before it tests `ChildLab_PlaneN`, so a datum with a plane
location and nothing else already has a non-null `aLoc`.

That is precise and cheap, and it hard-codes two private tag numbers that upstream can renumber
without any compile-time signal here. The trade is a real one either way, and it is the caller's
call rather than this change's.

`XCAFDoc_Datum::GetName()` is not a way out of it: it returns the attribute's own legacy `myName`,
set by `XCAFDoc_Datum::Set(...)`, while `SetObject` writes the object's name to the `ChildLab_Name`
child instead. Substituting it for `GetObject()->GetName()` in `OCCTDocumentGetDatumInfo` would
return an empty name for every datum this package or the STEP reader creates, and it would do
nothing for the other six entry points, which need the object itself.

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
