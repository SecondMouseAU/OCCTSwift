# #996: the GD&T read surface, and OCCT's three dimension kinds

Ground truth for the model that `Document.Dimension` now mirrors, and for the wrong answer that
made #996 more than a deduplication.

Build and run from the repo root:

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/996-gdt-read-surface/gdt_dimension_kinds.mm -o /tmp/gdt_dimension_kinds
/tmp/gdt_dimension_kinds
```

`transcript-before.txt` is that program's output against the pinned kernel, with the bridge line
computed the way `OCCTDocumentGetDimensionInfo` computed it before this fix. The program itself is
unchanged by the fix, so re-running it after gives the same transcript: it measures OCCT, and the
"bridge before #996" line is arithmetic the program does itself rather than a call into the bridge.

## The wrong answer

`XCAFDimTolObjects_DimensionObject` stores a dimension's magnitude in one values array whose
**length** is the discriminator, and its own predicates are the length test:

| kind | length | predicate | what the slots hold |
|---|---|---|---|
| unset | 0 (null array) | none | nothing |
| simple | 1 | none of the two | the nominal value |
| range | 2 | `IsDimWithRange()` | lower bound, upper bound |
| plus/minus | 3 | `IsDimWithPlusMinusTolerance()` | value, lower tol, upper tol |

`OCCTDocumentGetDimensionInfo` read `vals->Value(vals->Lower())`, the first slot, and called it
`value`. For a range that is the lower bound, not the value, and the two tolerance accessors answer
a flat `0` because a range has no tolerances. So a 10..12 range came back as

```
value=10 lowerTol=0 upperTol=0
```

which is the exact reading a caller would get from a plain 10mm dimension with zero tolerance. The
two are not distinguishable from the result, and the transcript shows both.

`GetValue()` is the accessor that answers this correctly: it returns the array's single value for a
simple dimension, the **midpoint** for a range (11 for 10..12), and 0 for an empty array. The bridge
now calls it, and reports the kind alongside so the 0 case is not mistaken for a measured zero.

A fourth kind, `IsDimWithClassOfTolerance()` (an ISO 286 class such as H7), is **not** an array
length at all: part 3 shows a range dimension carrying one. That is why the Swift model has
`classOfTolerance` as a separate optional rather than a fourth `Bounds` case.

## The upstream doc defect

`XCAFDimTolObjects_DimensionObject.hxx` has the doc comments on `GetUpperTolValue` and
`GetLowerTolValue` **swapped**:

```cpp
//! Returns the lower value of the toleranced dimension, otherwise - zero.
Standard_EXPORT double GetUpperTolValue() const;

//! Returns the upper value of the toleranced dimension, otherwise - zero.
Standard_EXPORT double GetLowerTolValue() const;
```

The 8.0.1 refman renders the same swap, so it is in OCCT's source rather than in our copy of the
header. The **functions** are correct, measured two independent ways in part 1:

- Writing `SetLowerTolValue(-0.3)` and `SetUpperTolValue(0.7)` produces `[20, -0.3, 0.7]`, and
  `GetLowerTolValue()` reads back `-0.3`.
- Binding a raw `[100, 200, 300]` array with `SetValues` gives `GetLowerTolValue()` 200 (slot 2) and
  `GetUpperTolValue()` 300 (slot 3), the same slots the setters wrote.

The asymmetric `-0.3 / +0.7` pair is deliberate: a symmetric `-0.1 / +0.1` cannot tell a correct
accessor from a swapped one. `OCCTBridge_Document.mm` carries a comment recording this so the next
reader of that header does not "fix" the bridge to match the comment.

## The mutator contracts (part 3)

- `SetLowerBound` / `SetUpperBound` each reset a non-range dimension to a degenerate range holding
  their own argument twice, so either call order converges on the same `[10,12]`. The bridge does
  not depend on an order.
- `SetLowerTolValue` / `SetUpperTolValue` return `false` on a range dimension and leave it
  untouched. `OCCTDocumentSetDimensionTolerance` used to discard both returns and report success for
  a call that changed nothing; it now returns their conjunction.
- `SetValue` overwrites the whole array, so setting a value on a plus/minus dimension drops its
  tolerances. Nothing on `Document` reaches that path today: `createDimension` is the only caller,
  and it runs on a fresh object.
- A default-constructed dimension has a null values array and `GetValue()` answers 0. That 0 is why
  `Dimension.value` is `Double?` and `.unset` is a `Bounds` case rather than a synonym for zero.
