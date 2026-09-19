# #1690: the #603 injection did reach the path, and is no longer a defect

#1690 asked why removing the adaptive quadrature loop from `occtArcConvergedLength()` did not turn
`Issue603SingleSpanQuadratureTests` red. It offered two hypotheses: the tests' references are
circular, or the injection never reached the code. **Both are wrong.**

## What was measured

`occt_1690_quadrature_probe.mm`, against the pinned kernel, on a 10 x 3 ellipse:

```
CPnts  single span      = 43.859100695688959
CPnts    2 pieces       = 43.859100695688966   rel-diff vs single = 1.620e-16
CPnts  256 pieces       = 43.859100695689087   rel-diff vs single = 2.916e-15
GCPnts single span      = 43.859100695688959
Simpson ground truth    = 43.859100695688255
single-span error       = 1.604e-14 relative
```

The single span already agrees with an independent Simpson ground truth to **1.6e-14 relative**.
`kOCCTArcLengthTolerance` is **1e-9**. The loop's convergence test therefore passes on its FIRST
iteration and it never subdivides meaningfully. Removing it cannot change an answer, which is why
all 15 tests stayed green.

## Why

**Carried patch `0021` fixed this in the kernel.** It replaces `math_GaussSingleIntegration` with
`CPnts_AdaptiveIntegration` inside `CPnts_AbscissaPoint::Length` itself, and `0021` is one of the
seventeen patches in the pinned `v3.0.0` asset. The bridge-side subdivision in
`occtArcConvergedLength` is a mitigation for a kernel defect the pinned kernel no longer has.

CLAUDE.md already predicted exactly this state, under "Retire when the kernel is repinned":

> the bridge-side arc-length subdivision (`occtAdaptorArcLength`, #603, redundant against patch
> `0021`) ... **None of their tests can signal that they have outlived their fix.**

#1690 is that signal, arriving from the injection direction rather than from a test.

## The tests are not defective

The issue's first hypothesis was that the references measure the same single quadrature the
injection produces. They do not. `Issue603SingleSpanQuadratureTests` computes a Richardson
extrapolated chord sum and a composite Simpson integral **in Swift**, neither of which calls
`occtArcQuadrature`. The probe's own Simpson ground truth confirms the single span is correct
rather than merely self-consistent.

So no test expectation needs changing, and the injection site in the issue is correct.

## What this does NOT settle

Whether to retire the bridge-side loop. The measurement above is one ellipse; the suite also covers
a parabola, a hyperbola, a whipping Bezier and a multi-span interpolated BSpline, and a retirement
should measure those before deleting code that costs nothing to keep. Retirement is a behaviour
change with its own risk and belongs in its own issue, not folded into an investigation.

## Reproducing

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1690-arc-quadrature-redundancy/occt_1690_quadrature_probe.mm -o /tmp/occt_1690
/tmp/occt_1690
```
