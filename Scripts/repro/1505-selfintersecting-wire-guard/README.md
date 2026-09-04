# #1505: bare-wire self-intersection guard gap

`occt_1505_repro.cpp` is the reproducer/prototype for
[#1505](https://github.com/SecondMouseAU/OCCTSwift/issues/1505):
`occtHasSelfIntersectingWire` (the #263 crash guard, `OCCTBridge.mm`) never actually detected
self-intersection on a **bare** `TopoDS_Wire` input, only when the input already was (or
contained) a `TopoDS_Face`.

## Root cause

`BRepCheck_Wire::SelfIntersect(const TopoDS_Face&, ...)` needs a face to project pcurves onto, so
it is only ever invoked by `BRepCheck_Wire::InContext(S)` when `S.ShapeType() == TopAbs_FACE`
(`BRepCheck_Wire.cxx:192`). `BRepCheck_Analyzer`'s walk over a shape whose own top-level type is
`TopAbs_WIRE` never gives it that context, so `BRepCheck_SelfIntersectingWire` never lands in the
wire's own status list, and the guard read that silence as "safe to proceed".

`Shape.fromWire(_:)` produces exactly such a bare-wire `Shape`. Nothing stops a caller from then
extruding or healing it directly (`Shape.fromWire(w)?.extruded(by:)` / `.healed()` /
`.healedWithFullHistory()`), all three of which pass the wire-typed shape straight into the guard.

## What the reproducer does

Builds two planar 4-edge wires (a self-intersecting "bowtie" and a clean square, same fixture the
issue itself used) and runs three implementations against both, bare and pre-wrapped in a face:

- `occtHasSelfIntersectingWire_CURRENT`: the pre-fix function body, byte-for-byte.
- `occtHasSelfIntersectingWire_FIXED`: the proposed fix — when `s` carries no `TopoDS_Face` at
  all, synthesize a planar face per bare wire (`BRepBuilderAPI_MakeFace(wire, /*OnlyPlane=*/true)`)
  and re-run the check against that, falling back to "no verdict from this wire" (not a crash) if
  the wire can't be faced (non-planar, open, degenerate, etc).

## Compile & run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"<repo>/Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"<repo>/Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  occt_1505_repro.cpp -o /tmp/occt_1505_repro
/tmp/occt_1505_repro
```

## Result

```
bowtie bare wire:  CURRENT=0 (want 0, the bug)  FIXED=1 (want 1)
clean  bare wire:  FIXED=0 (want 0, no false positive)
bowtie as face:    IsDone=1  CURRENT=1 (want 1, already worked)  FIXED=1 (want 1, unchanged)
RESULT: PASS
```

Confirms: `CURRENT` misses the bare-wire bowtie (the bug), `FIXED` catches it without a false
positive on the clean wire, and the already-working face-input case (the three real call sites'
existing coverage via `SelfIntersectingProfileGuard263.swift`) is unaffected.

A second, ad hoc pass (not checked in as a separate file, see the issue/PR for the transcript)
confirmed the fallback path degrades gracefully rather than crashing: a non-planar bowtie-shaped
wire, an open wire, and a null shape all return `false` (no verdict) with no exception escaping.

## Fix

Shipped bridge-side in `Sources/OCCTBridge/src/OCCTBridge.mm`'s `occtHasSelfIntersectingWire`, no
OCCT kernel patch needed. Regression coverage:
`Tests/OCCTShapeHealingTests/Issue1505BareWireSelfIntersectionGuardTests.swift`.
