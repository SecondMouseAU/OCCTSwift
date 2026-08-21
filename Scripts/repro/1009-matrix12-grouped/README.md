# #1009: one GROUPED 12-double reader, and what `gp_Trsf::SetValues` really refuses

The GROUPED 12-double reader was three byte-identical copies of the same permuted `SetValues`, in
three different files:

| Site | Entry point |
|---|---|
| `OCCTBridge_Curve3D.mm` | `OCCTCurve3DParametricTransformation` |
| `OCCTBridge_Document.mm` | `OCCTDocumentAddComponentMatrix` |
| `OCCTBridge_Modeling.mm` | `OCCTShapeTransformed` |

Three files, so the shared reader lands in `OCCTBridge_Internal.h` as
`occtTrsfFromMatrix12Grouped`, next to the `occtTrsfFromMatrix12Interleaved` family #994 put there,
rather than static in any one of them.

`occt_1009_matrix12_grouped.mm` transcribes all three unchanged and runs them against the shared
helper over four matrices: identity, a pure translation, a rotation about Z with a translation (so
no two of the twelve slots share a value and a permuted read cannot coincidentally agree), and a
uniform scale. Result (`probe-output.txt`, pinned kernel): **0 divergent entries**.

## The two layouts must never share a reader

```
INTERLEAVED   m[0..3] = r00 r01 r02 tx | m[4..7] = r10 r11 r12 ty | m[8..11] = r20 r21 r22 tz
GROUPED       m[0..8] = the nine rotation values                  | m[9..11] = tx ty tz
```

Reading one with the other's reader is a silent wrong answer. Both arrays below mean "translate by
(5, 6, 7)":

```
  GROUPED array through the GROUPED reader:         translation (5, 6, 7)
  INTERLEAVED array through the INTERLEAVED reader: translation (5, 6, 7)
  GROUPED array through the INTERLEAVED reader:     translation (0, 0, 7)  accepted
```

which reproduces #994's own measurement against the new helper.

## `gp_Trsf::SetValues` refuses nothing here, and the old comment said the opposite

`OCCTDocumentAddComponentMatrix` carried this, and `Document.addComponent(matrix:)`'s Swift doc
comment and `docs/reference/Document-Persistence-IO.md` said the same:

> gp_Trsf::SetValues throws if not a proper rigid (orthonormal, det +1) transform, reflections must
> be baked as a mirrored product (#174).

That is wrong twice over, and neither half had been measured.

**The precondition is not the one named.** `gp_Trsf.hxx`'s own doc for `SetValues` says "Raises
ConstructionError if the determinant of the aij is null. The matrix is orthogonalized before future
using." A null determinant, not orthonormality, and certainly not `det == +1`: a reflection has
`det == -1`, which is not null.

**And that precondition does not run.** `SetValues` is `Standard_EXPORT`, compiled inside OCCT's own
Release translation units, where `No_Exception` expands every `*_Raise_if` to nothing (#487).
Measured:

```
  identity (det +1)                  ACCEPTED  scale=1   IsNegative=0
  reflection in X (det -1)           ACCEPTED  scale=-1  IsNegative=1
  singular (det 0)                   ACCEPTED  scale=-0  IsNegative=0
  all zeros (det 0)                  ACCEPTED  scale=-0  IsNegative=0
  uniform scale 2 (det +8)           ACCEPTED  scale=2   IsNegative=0
  shear (det +1, not orthonormal)    ACCEPTED  scale=1   IsNegative=0
```

Nothing is refused, including the two cases the header itself names.

**A reflection is not merely tolerated, it works.** Applied to a box spanning `x` in `[1, 11]`:

```
  centre of mass x: 6 -> -6   volume: 1000 -> 1000
```

So a caller handing `Document.addComponent(matrix:)` a mirrored placement gets the mirror, and
#174's premise that `gp_Trsf` rejects reflections does not hold against this kernel. The bridge
comment, the Swift doc comment and the reference page are corrected, and
`Issue1009Matrix12GroupedTests.documentAddComponentAcceptsAReflection` pins it.

## Part 3: the third call site's own quantity

`Geom_Line`'s parameter is arc length from its origin point, so a uniform scale of `k` must map the
parameter by `k`. That is the number `Curve3D.parametricTransformation` returns, and it separates
the two layouts cleanly:

```
  GROUPED uniform scale 2, translate (1,2,3): 2
  the SAME array read INTERLEAVED:            0
  GROUPED identity, translate (5,6,7):        1
```

The INTERLEAVED read turns that array into a rank-deficient matrix, which `SetValues` accepts (see
above) and which then reports a parametric factor of 0.

## Build

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1009-matrix12-grouped/occt_1009_matrix12_grouped.mm -o /tmp/occt_1009
/tmp/occt_1009
```

Exit code is the divergence count from Part 1, clamped to 0/1.
