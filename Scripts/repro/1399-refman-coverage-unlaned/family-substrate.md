# #1399, substrate bucket: 26 classes

The bucket is a routing device, not a verdict. Its rule is a name prefix
(`NCollection_`, `TColStd_`, `TColgp_`, `TCollection_`, `Standard_`), on the reasoning that a
container or a scalar carries no capability to over- or under-document, which is the same
disposition #1045's fifteen substrate packages received.

**The rule over-claims, and here is by how much: two of the 26 are not containers at all, and both
verify as `ok`.** They are adjudicated individually below rather than swept up, because a bucket
whose members are never checked is indistinguishable from a bucket that is wrong.

| verdict | count |
|---|---|
| `deliberate, recorded` | 24 |
| `ok` | 2 |
| `under` | 0 |
| `over` | 0 |

## The 24: containers and scalars

`TColStd_Array1OfReal`, `TColStd_Array1OfInteger`, `TColStd_Array2OfReal`, `TColStd_HArray1OfReal`,
`TColStd_HSequenceOfReal`, `TColStd_IndexedDataMapOfTransientTransient`, `TColgp_Array1OfPnt`,
`TColgp_Array1OfPnt2d`, `TColgp_HArray1OfPnt`, `TColgp_HArray1OfPnt2d`, `NCollection_Sequence`,
`NCollection_HSequence`, `NCollection_Array2`, `NCollection_HArray1`, `NCollection_HArray2`,
`NCollection_Map`, `NCollection_FlatMap`, `NCollection_IndexedDataMap`, `NCollection_Vec3`,
`NCollection_LinearVector`, `TCollection_ExtendedString`, `Standard_ShortReal`,
`Standard_PCharacter`, `Standard_SStream`.

The reason is one reason, stated once because it is the same reason: **the bridge builds these to
hand data to an OCCT call and unpacks the result into C arrays before returning.** None of them
crosses into Swift, so there is no capability to document and no claim that could be wrong. A
Swift caller sees `[Double]`, `[SIMD3<Double>]` or a `String`, never a `TColStd_Array1OfReal`.

Two of them were read individually rather than assumed, because their names do not say "container":

- **`NCollection_Vec3`** is a value type, not a collection. Used at three sites to read a PBR
  material's emission colour (`NCollection_Vec3<float> em = pbr.Emission();`) and to convert a
  linear RGB triple. Both unpack immediately into floats. `deliberate, recorded`.
- **`NCollection_LinearVector`** is the value type of a `BRepGraph` adjacency map inside
  `OCCTBridge_BRepGraph.mm`, entirely internal to one function. `deliberate, recorded`.

## The 2: documented capabilities the prefix rule swept up

### `Standard_GUID`, verdict `ok`

Not substrate: it is the type the OCAF attribute and filter API is addressed by. The bridge builds
one from a caller-supplied string at eight sites in `OCCTBridge_Document_DocumentLifecycle.mm`
(`OCCTIDFilterKeep`, `OCCTIDFilterIgnore` and siblings), and
`docs/reference/Document-OCAF-Attributes.md:1817` describes it accurately: "round-trips the GUID
string through OCCT's `Standard_GUID`". Claim checked against the code, not accepted from the page.

**A cross-finding for #1407, noted rather than fixed here.** `Standard_GUID(const char*)` raises on
a malformed string, so it belongs in `Scripts/check-throwing-calls.py`'s `THROWING_TYPES` list. Every
current call site is already inside a `try`, so there is no live defect; the gap is that a future
one would not be caught. The list is a one-line addition to that gate, which is open as PR #1629.

### `NCollection_Lerp`, verdict `ok`

Not substrate: it is an interpolator. `OCCTTrsfInterpolate` uses `NCollection_Lerp<gp_Trsf>` to
blend two transforms, and it reaches Swift as `MathSolver.transformInterpolate(from:to:t:)`, which
is documented at `docs/reference/Document-Transforms.md:383`.

The doc's behaviour claim, "translation linearly, rotation via NLERP", is **true**, and was worth
checking rather than assuming: `NCollection_Lerp<gp_Trsf>` is specialized in `gp_TrsfNLerp.hxx`,
which includes `gp_QuaternionNLerp.hxx` and runs the rotation through it. Had the specialization
used SLERP, as several kernels do, the sentence would have been a textbook `over`.

One thing the specialization does that our wrapper does not expose: it interpolates the **scale
factor** as well (`myScaleLerp.Init(theStart.ScaleFactor(), theEnd.ScaleFactor())`). The bridge
builds its two `gp_Trsf` from a translation and a quaternion only, so scale is always 1 and the
omission is invisible rather than wrong. Not a finding; recorded so the next reader does not
re-derive it.
