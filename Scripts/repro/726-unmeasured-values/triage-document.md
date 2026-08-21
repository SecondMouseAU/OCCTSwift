# #763 triage: `OCCTBridge_Document.mm` + `OCCTBridge_IO.mm` (26 of 62 candidates)

Parent: #726. Sibling issue: #763 ("Unmeasured values, production half: adjudicate the census's 62
bridge candidates"), the `OCCTBridge_Document.mm` (25) + `OCCTBridge_IO.mm` (1) half specifically.
Candidate list reproduced with:

```
python3 Scripts/census-unmeasured-values.py | grep -E "^  OCCTBridge_(Document|IO)\.mm:"
```

Line numbers below are as reported **before** this pass's fix (`OCCTDocumentGetShapeColor` gained
5 lines, shifting everything after it in the file by that amount; re-running the census today
reports `OCCTDocumentGetShapeColor`'s own `result.a` line gone and every later line number +5).

## Verdicts, per #763

1. **Not an instance.** The literal is correct.
2. **Compute it.** Non-breaking.
3. **Make the absence representable** (`nil`/sentinel). Usually breaking.
4. **Remove the field.** Breaking.

Finer tags (reused from `Scripts/repro/726-unmeasured-values/README.md`'s own taxonomy, all of
which collapse to Verdict 1 except where noted): **FLIP** = legitimate default-then-flip
success/validity flag. **ALPHA** = structural default for a color quantity with no alpha channel
anywhere in the data it is drawn from. **CTOR** = plain value-type constructor echoing its own
parameters, not a measurement API returned from OCCT.

## Result: 25 Verdict 1, 1 Verdict 2, 0 Verdict 3, 0 Verdict 4

| # | Site | Function | Field | Verdict | Evidence |
|---|---|---|---|---|---|
| 1 | `OCCTBridge_Document.mm:427` | `OCCTDocumentGetLabelColor` | `result.isSet = true` | 1 (FLIP) | Read the full function. Sits immediately after `result.r/g/b/a` are assigned from a real `Quantity_ColorRGBA` returned by `doc->colorTool->GetColor(label, xcafType, color)`. `isSet` is `true` only on the path where a color was actually found (two call sites in the function, both after a real fetch), the "make absence representable" idiom, not a fabrication. |
| 2 | `OCCTBridge_Document.mm:520` | `OCCTDocumentGetLabelMaterial` | `baseColor.isSet = true` | 1 (FLIP) | Same idiom, one level in: set immediately after `baseColor.r/g/b/a` are populated from `pbr.BaseColor` (a real `Quantity_ColorRGBA`), inside `if (visMat->HasPbrMaterial())`. |
| 3 | `OCCTBridge_Document.mm:530` | `OCCTDocumentGetLabelMaterial` | `emissive.a = 1.0` | 1 (ALPHA) | Verified against the OCCT header, not assumed: `XCAFDoc_VisMaterialPBR::EmissiveFactor` is `NCollection_Vec3<float>` (`Libraries/OCCT.xcframework/macos-arm64/Headers/XCAFDoc_VisMaterialPBR.hxx:40`), RGB only, matching the glTF spec's `emissiveFactor` (no alpha channel exists anywhere upstream for this quantity). `1.0` (fully opaque) is the only sensible constant for an `OCCTColor`-shaped slot with no real alpha to read. Genuinely different from candidate #7 below, which looked structurally identical but was not. |
| 4 | `OCCTBridge_Document.mm:531` | `OCCTDocumentGetLabelMaterial` | `emissive.isSet = true` | 1 (FLIP) | Same branch as #3; `emissive.r/g/b` are real (`pbr.EmissiveFactor.x/y/z()`) immediately above. |
| 5 | `OCCTBridge_Document.mm:775` | `OCCTDocumentGetDimensionInfo` | `info.isValid = false` | 1 (FLIP) | Default set before the `try` block even opens; flipped to `true` only at `:798`, after `dimObj->GetType()`/`GetValues()`/`GetLowerTolValue()`/`GetUpperTolValue()` all ran. Textbook default-then-flip. |
| 6 | `OCCTBridge_Document.mm:807` | `OCCTDocumentGetGeomToleranceInfo` | `info.isValid = false` | 1 (FLIP) | Identical shape to #5: default before `try`, flipped at `:825` after `tolObj->GetType()`/`GetValue()`. |
| 7 | `OCCTBridge_Document.mm:3050` | `OCCTDocumentGetShapeColor` | `result.a = 1.0` | **2 (FIXED)** | **Overrides this repro directory's own prior README verdict of ALPHA for this exact site** ("`Quantity_Color` (not `ColorRGBA`) has no alpha channel; `1.0` is the domain default"). That verdict conflated "the C++ value type this call reads into has no alpha field" with "no alpha data exists to read", they are not the same claim, and the second is false. Read `Libraries/occt-src/.../XCAFDoc_ColorTool.cxx:77-101`: `GetColor(TDF_Label, Quantity_Color&)` internally calls `GetColor(TDF_Label, Quantity_ColorRGBA&)` and then does `col = aCol.GetRGB()`, the underlying `XCAFDoc_Color` attribute always stores full RGBA (`ColorAttribute->GetColorRGBA()`), regardless of which overload a caller uses to read it. A real, non-1.0 alpha reaches this exact storage today: `STEPCAFControl_Reader.cxx:2341` calls `CTool->SetColor(aLabelForStyle, colRGBA, XCAFDoc_ColorSurf)` with a `Quantity_ColorRGBA` carrying the STEP file's own transparency. Second construction, per `measure-dont-assume.md`: `OCCTDocumentGetLabelColor` (candidate #1, same file) does the exact same "get color by X" operation for a label key and already reads via the RGBA overload correctly, this function was the one-off inconsistency, not the norm. **Fixed**: switched to `Quantity_ColorRGBA` + `color.Alpha()`. Non-breaking (same field, same type, corrected value). |
| 8 | `OCCTBridge_Document.mm:3051` | `OCCTDocumentGetShapeColor` | `result.isSet = true` | 1 (FLIP) | Set only inside `if (hasColor)`, beside the (now-fixed) real `r/g/b/a`. Correct presence flag, independent of #7's defect. |
| 9 | `OCCTBridge_Document.mm:4290` | `OCCTXCAFPrsStyleCreate` | `result.surfR = 0` | 1 (CTOR) | Traced every call site of all three `OCCTXCAFPrsStyleCreate*` functions (`grep` across `Sources/`): the only caller is `PresentationStyle.swift`'s private `toOCCT()`, which builds this C struct **from Swift-supplied parameters** to feed `OCCTXCAFPrsStyleIsEqual`, it is never used to read a style back out of a document. A plain value constructor, not a measurement API; #726's own scope is values "returned through an API" that reads as measured, and this reads as "caller building a request," matching the CFG/CTOR false-positive shape the census's own header names explicitly for these exact three functions. |
| 10 | `OCCTBridge_Document.mm:4290` | `OCCTXCAFPrsStyleCreate` | `result.surfG = 0` | 1 (CTOR) | Same as #9. |
| 11 | `OCCTBridge_Document.mm:4290` | `OCCTXCAFPrsStyleCreate` | `result.surfB = 0` | 1 (CTOR) | Same as #9. |
| 12 | `OCCTBridge_Document.mm:4291` | `OCCTXCAFPrsStyleCreate` | `result.surfAlpha = 1.0f` | 1 (CTOR) | Same as #9; also the correct "no color" default given `hasSurfColor = false` on the same path. |
| 13 | `OCCTBridge_Document.mm:4292` | `OCCTXCAFPrsStyleCreate` | `result.hasSurfColor = false` | 1 (CTOR/GOOD) | Same as #9. `PresentationStyle.swift:8` (`surfaceColor: (...)?`) is the consumer, and it is nil exactly when no color was supplied, the "make absence representable" pattern already applied on the Swift side. |
| 14 | `OCCTBridge_Document.mm:4293` | `OCCTXCAFPrsStyleCreate` | `result.curvR = 0` | 1 (CTOR) | Same as #9. |
| 15 | `OCCTBridge_Document.mm:4293` | `OCCTXCAFPrsStyleCreate` | `result.curvG = 0` | 1 (CTOR) | Same as #9. |
| 16 | `OCCTBridge_Document.mm:4293` | `OCCTXCAFPrsStyleCreate` | `result.curvB = 0` | 1 (CTOR) | Same as #9. |
| 17 | `OCCTBridge_Document.mm:4294` | `OCCTXCAFPrsStyleCreate` | `result.hasCurvColor = false` | 1 (CTOR/GOOD) | Same as #13, for `curveColor`. |
| 18 | `OCCTBridge_Document.mm:4307` | `OCCTXCAFPrsStyleCreateWithSurfColor` | `result.hasSurfColor = true` | 1 (CTOR) | This constructor's own parameters are `(r, g, b, alpha)` for the surface color, so `hasSurfColor` is unconditionally true by construction, correct, not fabricated. |
| 19 | `OCCTBridge_Document.mm:4308` | `OCCTXCAFPrsStyleCreateWithSurfColor` | `result.curvR = 0` | 1 (CTOR) | No curve-color parameter exists on this constructor; `curvR/G/B` are placeholder defaults, inert because guarded by `hasCurvColor = false` at every consumer (`OCCTXCAFPrsStyleIsEqual` only calls `SetColorCurv` `if (s->hasCurvColor)`). |
| 20 | `OCCTBridge_Document.mm:4308` | `OCCTXCAFPrsStyleCreateWithSurfColor` | `result.curvG = 0` | 1 (CTOR) | Same as #19. |
| 21 | `OCCTBridge_Document.mm:4308` | `OCCTXCAFPrsStyleCreateWithSurfColor` | `result.curvB = 0` | 1 (CTOR) | Same as #19. |
| 22 | `OCCTBridge_Document.mm:4309` | `OCCTXCAFPrsStyleCreateWithSurfColor` | `result.hasCurvColor = false` | 1 (CTOR) | Same as #19, the gate itself. |
| 23 | `OCCTBridge_Document.mm:4321` | `OCCTXCAFPrsStyleCreateFull` | `result.hasSurfColor = true` | 1 (CTOR) | This constructor's parameters include both a surface and curve color unconditionally, so both `has*` flags are true by construction on every call, correct. |
| 24 | `OCCTBridge_Document.mm:4323` | `OCCTXCAFPrsStyleCreateFull` | `result.hasCurvColor = true` | 1 (CTOR) | Same as #23. |
| 25 | `OCCTBridge_Document.mm:4325` | `OCCTXCAFPrsStyleCreateFull` | `result.isEmpty = false` | 1 (CTOR, verified by formula) | Went further than "plausible constant": read `XCAFPrs_Style::IsEmpty()`'s actual body (`Libraries/OCCT.xcframework/.../Headers/XCAFPrs_Style.hxx:35`): `return !myHasColorSurf && !myHasColorCurv && myMaterial.IsNull() && myIsVisible;`. Since this constructor always sets both colors (`hasSurfColor`/`hasCurvColor` both unconditionally `true`, #23/#24), the formula evaluates to `false` for every possible input to *this specific constructor*, with no exception. The literal is not merely plausible, it is provably the only correct value here. |
| 26 | `OCCTBridge_IO.mm:828` | `OCCTImportSTEPWithDiagnostics` | `result.solidCreated = true` | 1 (FLIP) | Set only inside `if (solidsCreated > 0)`, beside the real, computed `result.solidsCreated = solidsCreated` at the same line/depth, the literal is reached only because a real count was positive, the same "boolean flag flipped true because a condition held" idiom as `result.sewingApplied = true` four lines above it in the same function (already adjudicated FLIP in the parent census's own header comment, for that sibling site). |

## The one correction to record

Candidate #7 (`OCCTDocumentGetShapeColor`'s `result.a`) was pre-labeled **ALPHA** (ostensibly the
same "no alpha channel" shape as candidate #3's `emissive.a`) in this repro directory's own
`README.md`, written during the original census pass. Reading the function is what #763 asks for
before trusting a census line, and doing so here overturns that verdict: `Quantity_Color` lacking
an alpha *field* does not mean the `XCAFDoc_ColorTool` storage this function reads from lacks alpha
*data*, it does not, and OCCT's own STEP importer proves it by writing real transparency through
the RGBA overload of the same `SetColor` this bridge's `GetColor` call is the mirror of. This is the
cautionary case #763 itself names (matching #605's shape): a value that looked like a correct
structural constant on a first pass was actually a wrong choice of accessor, only visible by reading
the OCCT source underneath the call rather than the OCCT value type's own field list.

## Fix implemented (Verdict 2)

`Sources/OCCTBridge/src/OCCTBridge_Document.mm`, `OCCTDocumentGetShapeColor`: switched the read from
`Quantity_Color` to `Quantity_ColorRGBA`, populating `result.a` from `color.Alpha()` instead of the
literal `1.0`. Mirrors `OCCTDocumentGetLabelColor`, which already did this correctly for the
label-keyed sibling.

**Companion fix, not itself a census candidate, needed to make the above testable and coherent:**
`OCCTDocumentSetShapeColor` (the writer) stores through the RGB-only `SetColor` overload, so no
alpha set through it was ever recoverable, and `Document.setShapeColor(_:color:type:)` was silently
dropping `color.alpha` before it even reached the bridge, despite `Color` already carrying an
`alpha` field. Left as-is, the getter fix could never be exercised by any Swift-reachable write path
except a file import. Added a new, additive C function `OCCTDocumentSetShapeColorRGBA` (using the
`Quantity_ColorRGBA` `SetColor` overload) and pointed `Document.setShapeColor` at it instead of the
old RGB-only function, now forwarding `color.alpha`. No existing signature changed, the new bridge
function is additive, and the Swift-facing API (`setShapeColor(_:color:type:)`) keeps its exact
signature; only its internal behavior is corrected. **SemVer: PATCH-compatible / non-breaking**
(same public signatures on the Swift side; new function added to the bridge's C surface, not a
removal or a type change).

## Removal matrix (prove the test fails)

New tests, `Tests/OCCTXCAFTests/OCCTXCAFTests.swift`, suite `XDE ColorTool by Shape`:

- `shapeColorPreservesAlpha`: sets a shape color with `alpha: 0.5`, asserts the read-back color's
  `alpha` is `0.5` (was always `1.0` before the fix).
- `shapeColorOpaqueUnaffected`: regression guard: a fully-opaque color still round-trips to `1.0`.

| Step | `shapeColorPreservesAlpha` | `shapeColorOpaqueUnaffected` | Pre-existing `setAndGetColor` |
|---|---|---|---|
| Defect injected (reverted `OCCTDocumentGetShapeColor` to the original `Quantity_Color`/hardcoded `1.0`, kept the RGBA setter fix) | **FAILED**, `abs(got.alpha - 0.5) → 0.5` not `< 1e-5` | passed (0.5 alpha bug happens to be invisible at alpha=1.0) | passed (never asserted on alpha) |
| Fix restored | passed | passed | passed |

Defect injection method: reverted only the `Quantity_ColorRGBA color; ... result.a = color.Alpha();`
block back to `Quantity_Color color; ... result.a = 1.0;` (the exact original code), left the new
`OCCTDocumentSetShapeColorRGBA` setter untouched, ran `swift test --filter XDEColorToolByShapeTests`,
confirmed the new alpha test failed with the expected assertion message, restored from a backup of
the pre-edit file, re-ran, confirmed all 4 tests in the suite passed.

## Gates and full suite

`Scripts/census-unmeasured-values.py` re-run after the fix confirms `OCCTDocumentGetShapeColor`'s
`result.a` line no longer appears in the `OCCTBridge_Document.mm` candidate list (it is now a
computed field, `color.Alpha()`), and no new candidates were introduced by the new
`OCCTDocumentSetShapeColorRGBA` function (it has no aggregate result struct, void return, no
literal-vs-computed sibling shape for the census to flag).
