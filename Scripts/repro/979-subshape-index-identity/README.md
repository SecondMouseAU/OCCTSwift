# #979: what actually makes a sub-shape enumeration drop an element

`Shape.faces()`, `Shape.edges()`, `Shape.subShapes(ofType:)` and `Shape.orientedFaces()` each
skipped an element whose bridge handle came back null. The issue is right that skipping is wrong,
because the array position is an ordinal. Before choosing between "return optionals", "fail the
whole call" and "complete or empty", the question that decides it is whether a null at position `i`
can happen at all, and for what input.

Measured, two ways. The answer is that it cannot: **the bridge fills every slot or fails the whole
call. There is no per-element failure mode.**

## What the three bridge entry points actually do

`OCCTShapeGetFaces` (`OCCTBridge_Topology.mm:6392`), `OCCTShapeGetSubShapes` (`:1499`) and
`OCCTShapeGetEdgeAtIndex` (`:6777`) all bottom out in `occtMapSubShapes`
(`OCCTBridge_Internal.h:1531`), which is `TopExp::MapShapes` into a `TopTools_IndexedMapOfShape`.

- `OCCTShapeGetFaces` allocates `count` slots and assigns **every one** of them
  `new OCCTFace(TopoDS::Face(faceMap(i + 1)))`. C++ `new` either returns a valid pointer or throws;
  it never returns null. A throw anywhere in that loop reaches the function's own `catch (...)`,
  which returns `nullptr` for the whole call with `*outCount` left at 0, and Swift's `guard let`
  turns that into an empty array. So the array is fully populated or it does not exist.
- `OCCTShapeGetSubShapes` is the same shape: every slot in `0..<count` is assigned, and the only
  other return is `0` from `catch (...)`.
- `OCCTShapeGetEdgeAtIndex` returns null only for a negative index, an index past the end, or a
  throw. `Shape.edges()` walks `0..<edgeCount`, and `edgeCount` reads the same enumeration, so the
  index is in range by construction.

## Probe: the three properties that could still make a hole

`probe.mm` asks the questions the source reading cannot settle on its own, against the pinned
kernel and a deliberately hostile battery (null shape, empty compound, a body compounded with
itself, two boxes sharing a cut face, a solid built from one face, sphere and cone poles and
seams, a face beside its own reverse, an `INTERNAL`-orientation face, a vertex-only compound, and
a 2000-box compound with 12000 faces):

1. Can a `TopTools_IndexedMapOfShape` hold a null entry, so `map(i + 1)` is null mid-range?
2. Is `Extent()` stable across independently built maps, and does the same index name the same
   sub-shape in each? `Shape.edges()` takes its count from one bridge call and each element from
   another, so an unstable extent is exactly how an in-range index could go null.
3. Can an entry be of the wrong type, so the per-element `TopoDS::Face`/`TopoDS::Edge` downcast
   throws while its neighbours succeed?

Result (`probe-output.txt`), 39 shape-and-type combinations:

    TOTALS: nullEntries=0 unstableEnumerations=0 wrongTypeEntries=0

No null entries, no unstable or reordered enumerations, no wrong-typed entries anywhere.

Compile and run:

    clang++ -std=c++17 -ObjC++ -w \
      -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
      -L"Libraries/OCCT.xcframework/macos-arm64" \
      -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
      Scripts/repro/979-subshape-index-identity/probe.mm -o /tmp/probe979
    /tmp/probe979

## The same premise, re-measured from Swift against the live bridge

`Issue979SubShapeIndexIdentity.theBridgeNeverHandsBackAHole`
(`Tests/OCCTTopologyTests/Issue979SubShapeIndexIdentityTests.swift`) calls the real bridge
functions over a Swift battery and asserts every slot is non-null and `written == count`. It is a
permanent test rather than a one-off measurement, because the design rests on this property: if a
future bridge change ever makes a hole reachable, the premise is wrong and the design needs
revisiting rather than the array quietly going short again.

## What that means for the fix

A failure that cannot occur per element does not want an optional at every call site. Returning
`[Face?]` would put an impossible `nil` in front of every consumer, and the shortest way for a
consumer to answer it is `compactMap`, which is the defect again, one layer out. So the array keeps
its element type and gains a postcondition instead: **complete or empty, never short**. The
enumerations share one helper, `wrapSubShapeEnumeration` (`Sources/OCCTSwift/SubShapeEnumeration.swift`),
so the policy is written once rather than four times, and the handles of a refused enumeration are
released rather than leaked.

Because the bridge cannot produce a hole, the tests that exercise the refusal induce one at that
helper, which is the seam every enumeration passes through. The injection matrix is in the PR.
