# #1004: what the unwrapped XCAFDimTolObjects accessors actually answer

Ground truth for which of `XCAFDimTolObjects_DimensionObject`'s 42 accessors (and its two siblings')
can be wrapped correctly, and which cannot because absence is not representable through them.

Three programs. Build them from the repo root:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1004-gdt-accessors/gdt_accessor_defaults.mm -o /tmp/gdt_accessor_defaults
/tmp/gdt_accessor_defaults          # transcript.txt is this program's output

clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1004-gdt-accessors/datum_point_without_plane.mm -o /tmp/datum_point_without_plane
/tmp/datum_point_without_plane          # the wrong answer
/tmp/datum_point_without_plane --crash  # the SIGSEGV

clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1004-gdt-accessors/gdt_tolerance_datum_gates.mm -o /tmp/gdt_gates
/tmp/gdt_gates                          # transcript-gates.txt is this program's output
```

`transcript.txt` is `gdt_accessor_defaults`'s output against the pinned kernel, and
`transcript-gates.txt` is `gdt_tolerance_datum_gates`'s.

## What the first program settles

**Which accessors carry a usable presence predicate.** Every accessor that answers a number or an
enum is read three ways: on a default-constructed object, on one that went through the bridge's own
create path and back off a real document, and on one with every value set. An accessor whose "never
set" reading is indistinguishable from a legitimate value is one this wrapper cannot expose without
reintroducing the defect #996 existed to fix.

Three results drove decisions in the first PR.

**`GetNbOfDecimalPlaces` has no predicate, but its store condition is one.**
`XCAFDoc_Dimension::SetObject` writes the pair only when `theL > 0 || theR > 0`, so that expression
is the presence test rather than an approximation of one, and `Dimension.decimalPlaces` is `nil`
where it does not hold. A zero on one side alone is still a stored pair and reads back: part 3
writes `(2, 3)` and the Swift tests also cover `(0, 4)`.

**`GetDirection`'s bool is a constant `true`.** `XCAFDimTolObjects_DimensionObject.cxx:419-423`
returns `true` unconditionally and writes `myDir`, which no constructor assigns. Part 4 measures an
object that never had a direction reporting `(1, 0, 0)`, the default-constructed `gp_Dir`. There is
no reading a caller could use to tell that from a real direction, so `direction` is not wrapped.

**"Semantic name" is the GD&T table's own marker string.**
`XCAFDoc_DimTolTool::AddDimension()` sets the new label's `TDataStd_Name` to the literal
`"DGT:Dimension"`, and `XCAFDoc_Dimension::GetObject` reads that same attribute back as the semantic
name. Part 2 shows a dimension, a tolerance and a datum that nobody named reporting
`DGT:Dimension`, `DGT:Tolerance` and `DGT:Datum`. `SetObject`'s `setString` helper also returns
early on a null handle, so the name cannot be cleared once set. `semanticName` was implemented,
measured, and removed again before the PR opened; the reason is recorded in
`docs/occtswift-wrapping-gaps.md`.

**The three constructors leave most of their members unassigned.** `DimensionObject` sets four
booleans, `GeomToleranceObject` five members, `DatumObject` five; everything else is storage nobody
wrote, and `SetObject` reads several of those unconditionally to decide what to store. Part 1
poisons the allocator's free list with same-size blocks first, and the poison does not come through:
every such member still reads 0 against this kernel and this allocator. That is why the defect is
invisible in ordinary use, and it is not a guarantee, so `OCCTDocumentCreateDimension` now assigns
the neutral values explicitly instead of relying on it.

## What the second program settles

`XCAFDoc_Datum::GetObject` builds the datum's point from the **annotation plane's** location array:

```cpp
gp_Pnt aP(aLoc->Value(aPnt->Lower()),        // aLoc, not aPnt
          aPnt->Value(aPnt->Lower() + 1),
          aPnt->Value(aPnt->Lower() + 2));
```

A datum with plane location `(6,6,6)` and point `(7,7,7)` reads its point back as `(6,7,7)`. A datum
with a point and **no** plane leaves `aLoc` null and dereferences it: an uncatchable SIGSEGV, already
reachable from `Document.datums` on any imported document with that shape. The sibling
`XCAFDoc_GeomTolerance::GetObject` has the identical block and reads `aPnt->Value(aPnt->Lower())`,
so this is a one-character divergence rather than a shared idiom. Confirmed live on upstream
`master`. Filed as #1022; not fixed in #1004, because the fix is a kernel patch and an xcframework
rebuild rather than a Swift read surface.

## What the third program settles

`gdt_accessor_defaults` reports what an unset tolerance or datum accessor answers.
`gdt_tolerance_datum_gates` asks the next question, which is which condition separates that from a
real value, by writing each boundary case and reading it back. Four answers, all of which shaped
#1004's second PR.

**A datum's position is 1-based, so 0 is absence.** `STEPCAFControl_Reader.cxx:3676` declares its
reference-frame counter as `int aPositionCounter = 0` and `:3763` increments it *before* passing it
at `:3774`, so the first datum of a frame is written as position 1 and an import never assigns 0.
The round trip is faithful in both directions, so `nil` for `<= 0` reports a datum with no place in
a frame rather than discarding a value OCCT could have meant.

**A zero zone value and a zero max value are not representable.**
`XCAFDoc_GeomTolerance::SetObject` writes each only under `> 0`, so neither child label exists for a
zero and `GetObject` leaves both at the fresh object's unassigned member, which also reads 0. The
transcript's second row shows zeroes coming back as zeroes, and that is **not** evidence they were
stored: a stored 0 and an unstored one are the same reading, which is the whole reason `> 0` is the
presence test. The third row keeps a zone value with no zone modifier at all, which is what shows
the two conditions are independent rather than one implying the other.

**Which datum target dimensions survive depends on the type, not on the write.** All five types were
written with the same asymmetric `length = 30, width = 18`, so a length reported as a width would be
visible. Measured: `.point` keeps neither, `.line` and `.circle` keep the length, `.rectangle` keeps
both, and `.area` reports `HasDatumTargetParams() == false` because `SetObject` takes its shape
branch and never writes the axis. Two rules cover it: a length under the params flag and a type that
is not `.point`, a width under the params flag and a type that is `.rectangle`.

## What is not measured here

The geometry and presentation accessors on all three classes, which #1004's two PRs deliberately
left unwrapped. `docs/occtswift-wrapping-gaps.md` records the reason per accessor, and
`XCAFDoc_DimTolTool`'s own unreached surface is adjudicated there too, for #1021.
