# OCCTSwift#578 probe — what may a "face to remove" be, and what belongs to the shape?

Ground truth for giving `Shape.defeature(faces:)` a membership rule, against the pinned OCCT 8.0.0p1
kernel.

`BRepAlgoAPI_Defeaturing::AddFaceToRemove` takes a `TopoDS_Shape`, and its own documentation calls it
"the shape to extract the faces for removal". The header also states the rule the bridge inherited by
passing the caller's shapes straight through:

> The faces should belong to the initial shape, and those that do not belong will be ignored.

So a foreign face was dropped in silence and the rest of the request proceeded — a success, with no
warning, on a shape still carrying the feature the caller named. The index-addressed spelling
(`Shape.withoutFeatures(faces:)`) has failed the whole call on one bad index since #497. Closing that
gap needs more than a `Contains` check, because the argument need not be a face at all: this probe
measures the matrix a rule has to cover before choosing one.

No fixture files: every shape is built from a primitive.

## Build and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/578-defeature-face-membership/occt_578_defeature_face_membership.mm \
  -o /tmp/occt_578
/tmp/occt_578
```

Exit status is 1 if any claim the fix rests on fails.

## Fixture

A 20mm box with one 2mm fillet: seven faces, volume 7982.831853072. Removing the fillet face restores
the plain box (8000.0, six faces), and that removal is the control every case below is compared
against. The fillet face is found by its cylindrical surface, not by its position — it lands at index
3 of 7, not last.

## Result

```
=== 1. carriers, one at a time: what the kernel does, and what membership says ===
carrier                                     kernel                        membership (faces/belong/foreign)
  the fillet face                           done=1 vol=8000.000000 faces=6  1 / 1 / 0
  the fillet face, reversed                 done=1 vol=8000.000000 faces=6  1 / 1 / 0
  a compound holding the fillet face        done=1 vol=8000.000000 faces=6  1 / 1 / 0
  the input's own shell                     done=1 vol=7982.831853 faces=7  7 / 7 / 0
  the whole input solid                     done=1 vol=7982.831853 faces=7  7 / 7 / 0
  a face of a different shape               done=0                        1 / 0 / 1
  the whole different shape                 done=0                        6 / 0 / 6
  an identically built twin's face          done=0                        1 / 0 / 1
  an edge of the input                      done=0                        0 / 0 / 0
  a vertex of the input                     done=0                        0 / 0 / 0
  an empty compound                         done=0                        0 / 0 / 0

=== 2. a carrier that mixes belonging and foreign faces ===
  compound{fillet face, foreign face}     done=1 vol=8000.000000 faces=6   membership 2 / 1 / 1
  two carriers: fillet face + foreign     done=1 vol=8000.000000 faces=6
  two carriers: fillet face + an edge     done=1 vol=8000.000000 faces=6
  two carriers: fillet face + empty cmpd  done=1 vol=8000.000000 faces=6
  ... every one of these removes the fillet and nothing else, silently: yes

=== 3. exploding a carrier is the same request as passing it ===
  a compound holding the fillet face        carrier[done=1 faces=6]  exploded[done=1 faces=6]  IDENTICAL BREP
  the input's own shell                     carrier[done=1 faces=7]  exploded[done=1 faces=7]  IDENTICAL BREP
  the whole input solid                     carrier[done=1 faces=7]  exploded[done=1 faces=7]  IDENTICAL BREP
  the fillet face, reversed                 carrier[done=1 faces=6]  exploded[done=1 faces=6]  IDENTICAL BREP

=== 4. the same face named twice, and a carrier naming it twice ===
  two carriers, same face                 done=1 vol=8000.000000 faces=6  IDENTICAL BREP
  one compound, same face twice           done=1 vol=8000.000000 faces=6  IDENTICAL BREP

=== 5. removing everything ===
  every face of the input                 done=1 vol=7982.831853 faces=7  the input, unchanged
```

## What that establishes

**A carrier is not a face.** A compound, a shell and the whole input solid are all accepted, and each
means the faces it contains. So a rule cannot simply demand that each element *be* a face of the
input — it has to explore first.

**Exploding is free.** Replacing a carrier with the faces it explores to produces a byte-identical
BREP in every case, including the reversed face. That is what makes a membership check implementable
in the bridge: it can hand the kernel the faces it checked rather than the carrier it was given, and
the kernel cannot tell.

**The face map answers the membership question directly.** `TopExp::MapShapes(input, TopAbs_FACE)`
hashes on `TopTools_ShapeMapHasher`, i.e. `IsSame` — so the reversed fillet face is `Contains`, and an
identically-built twin's face is not. Both asserted by the probe, not eyeballed.

**Silence is the whole defect, and it is wider than a foreign face.** A request mixing the fillet face
with a foreign face, with an edge, or with an empty compound all return the control's BREP exactly:
the extra element contributes nothing and says nothing. A single foreign element fails only because
nothing is left to remove, which is why a probe testing one foreign face alone concludes the opposite.

## The rule chosen

> Every element of the request must name at least one face, and every face it names must be a face of
> the input. Otherwise the whole request fails and nothing is removed.

The alternative the issue posed — accept a carrier that yields *some* belonging faces and quietly keep
those — was rejected: it preserves the exact failure mode being removed (a success that silently drops
part of what the caller named), one level further down where it is harder to see. Failing is loud and
recoverable; a caller who wants "remove whichever of these belong" can filter, which is something they
cannot do today because the operation gives them no way to tell.

Section 6 of the probe prints the decision beside today's behaviour for the whole matrix:

```
request                                     today       chosen rule
  the fillet face                           succeeds    accepted
  the fillet face, reversed                 succeeds    accepted
  a compound holding the fillet face        succeeds    accepted
  the input's own shell                     succeeds    accepted
  the whole input solid                     succeeds    accepted
  the same face named twice                 succeeds    accepted
  a face of a different shape               fails       REFUSED
  the whole different shape                 fails       REFUSED
  an identically built twin's face          fails       REFUSED
  an edge of the input                      fails       REFUSED
  an empty compound                         fails       REFUSED
  fillet face + a foreign face              succeeds    REFUSED
  compound{fillet face, foreign face}       succeeds    REFUSED
  fillet face + an edge                     succeeds    REFUSED
  fillet face + an empty compound           succeeds    REFUSED
  nothing at all                            fails       REFUSED
```

Four rows change, and all four are requests that were being partly discarded. Nothing whose elements
all belong behaves differently, including the whole-solid and shell carriers — which stay accepted,
and stay a no-op, because "remove every face" is a question about the algorithm rather than about
membership and the kernel's answer to it is to hand the input back.

There is no defect here and nothing to file upstream: the kernel documents what it does and does it.
The strictness is the bridge's own contract, matching the one `withoutFeatures(faces:)` already had.

## Where the fix lives

`occtDefeaturingFacesFromShapes` (`Sources/OCCTBridge/src/OCCTBridge_Modeling.mm`), the #497 skeleton,
which now takes the input shape so it can build that face map. The contract is written out in
`OCCTBridge_Internal.h` beside it, and pinned by `Tests/OCCTModelingTests/Issue578DefeatureFaceMembershipTests.swift`.
