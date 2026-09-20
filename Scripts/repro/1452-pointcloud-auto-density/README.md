# #1452: auto-density point clouds divided by zero

Companion to `Scripts/repro/1440-pointcloud-density-int-overflow/`, which established the defect.
This directory holds the measurement the **fix** rests on.

## The defect

`BRepLib_PointCloudShape::NbPointsByDensity`:

```cpp
double aDensity = (theDensity < Precision::Confusion() ? computeDensity() : theDensity);
if (aDensity < Precision::Confusion()) { return 0; }
for (...) {
  int aNbPnts = std::max((int)std::ceil(anArea / theDensity), 1);   // theDensity, not aDensity
```

It validates `aDensity` and then divides by `theDensity`. At an exact `0.0`, the documented way to
request auto-density, that is `anArea / 0.0` = `+Infinity`, and `(int)std::ceil(+Infinity)` is
undefined behaviour. On arm64 macOS it saturates to `INT_MAX`, so every face asks for ~2.1 billion
points and the call does not return.

## What this probe measures

`computeDensity()` is `protected`, so the probe subclasses `BRepLib_PointCloudShape` to read it.

```
box computeDensity() = 10   (Confusion=1e-07)
NbPointsByDensity(computed) = 60
vertex computeDensity() = 2.0000000000000002e+99
```

Two facts the fix depends on:

1. **A box's auto-density is 10, giving 60 points.** The header documents the criterion as "10
   points per minimal unreduced face area", and a 10x10x10 box has a minimal face area of 100. So
   resolving auto-density on the bridge side and passing the result down is cheap and produces the
   cloud the kernel intended, rather than hanging.

2. **A shape with no faces answers `2e+99`, not `0.0`.** `computeDensity()` is a minimum-area
   search whose accumulator starts enormous and is never reduced when the face loop finds nothing.
   This matters because it means the bridge's sub-`Confusion` guard does **not** fire for such a
   shape. What refuses a vertex is the zero point count further down, not the guard. An earlier
   draft of the fix's test asserted the opposite and would have recorded a false mechanism.

## Reproducing

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1452-pointcloud-auto-density/occt_1452_density_probe.mm -o /tmp/occt_1452
/tmp/occt_1452
```

## The fix

`OCCTPointCloudCollector::resolveDensity` (`Sources/OCCTBridge/src/OCCTBridge_Mesh.mm`) runs the
kernel's own auto-density line and hands `GeneratePointsByDensity` an explicit positive density, so
`theDensity` equals `aDensity` and the divide is the one the author meant. Auto-density keeps
working, which a plain input guard rejecting `0.0` would have cost.

**Why no kernel patch.** The upstream fix is one word (`theDensity` to `aDensity`), but carrying it
would not help any consumer until the xcframework is rebuilt and repinned, and the bridge-side
resolution is complete on the pinned kernel today. Worth upstreaming separately; the bridge
workaround is marked for retirement when the kernel is repinned.

**Why this defect could not be prove-failed the usual way.** It is a non-terminating call, not a
wrong answer, so reinjecting it hangs the suite rather than failing it. The
`Issue1452PointCloudAutoDensityTests` header records that, and this probe is what stands in for the
automated negative case.
