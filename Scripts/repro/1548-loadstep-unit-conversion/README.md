# #1548: `Shape.loadSTEP(from:unitInMeters:)`'s unit parameter was dead on arrival

Two defects, confirmed empirically by `repro_1548.mm`:

1. **Ordering.** `OCCTImportSTEPWithUnitProgress`/`OCCTImportSTEPWithUnit`
   (`Sources/OCCTBridge/src/OCCTBridge_IO_StepFormat.mm`) called
   `STEPControl_Reader::SetSystemLengthUnit()` *before* `ReadFile()`. That method
   (`STEPControl_Reader.cxx`) is `if (StepModel().IsNull()) return; ...`, and `StepModel()` is only
   populated *inside* `ReadFile()`, so the call was a guarded no-op on every invocation, for every
   value of `unitInMeters`.
2. **Scale convention.** `SetSystemLengthUnit`'s own scale is millimeter-based (`1.0` == 1 mm,
   `1000.0` == 1 m, `25.4` == 1 inch, matching `UnitsMethods_LengthUnit`'s table), not
   meters-based. The doc's examples (`0.001` for mm, `0.0254` for inch) are literally `unitInMeters`
   values, so passing them straight through (as the old code did, once the ordering bug is fixed in
   isolation) scales the geometry 1000x in the wrong direction.

## Fix

`OCCTBridge_IO_StepFormat.mm`: `ReadFile()` now runs first, and
`SetSystemLengthUnit(unitInMeters * 1000.0)` runs after it and before the transfer, converting the
Swift-facing meters-based `unitInMeters` into OCCT's millimeter-based cascade unit. This keeps the
existing Swift API doc's examples correct (`0.001` for mm, `0.0254` for inch) rather than needing to
change them.

## Reproducing

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1548-loadstep-unit-conversion/repro_1548.mm -o /tmp/repro_1548
/tmp/repro_1548
```

Writes a 100 x 50 x 25 box to STEP (declared unit: millimeter), then re-imports it four ways:

| case | order | `SetSystemLengthUnit` arg | measured dims | interpretation |
|---|---|---|---|---|
| A | correct | `1.0` | `(100, 50, 25)` | `1.0` == 1 mm, unscaled |
| B | correct | `1000.0` | `(0.1, 0.05, 0.025)` | `1000.0` == 1 m |
| C | correct | `0.001` (doc's old "mm" value) | `(100000, 50000, 25000)` | 1000x too large: the old doc examples were backwards |
| D | **buggy** (before `ReadFile`) | `1000.0` | `(100, 50, 25)` | unscaled regardless of the value: the call never took effect |

Case A/D matching, both `(100, 50, 25)`, is the ordering bug in one line: the buggy order produces
the *default* (unscaled) result no matter what unit is requested. Case B confirms the correct scale
direction (larger unit value -> geometry scaled down), and case C confirms the doc's original
`0.001`/`0.0254` examples, read as raw arguments to `SetSystemLengthUnit`, are exactly 1000x wrong.
