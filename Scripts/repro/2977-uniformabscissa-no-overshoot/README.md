# OCCTSwift#2977: #501's regression tests had stopped reaching #501's path

`Curve2DTests.uniformDrawRespectsCount` is the regression test for the surplus point
`GCPnts_UniformAbscissa` can return beyond the count the caller asked for. On the pinned kernel it
reached none of its sixteen counts, and the natural distortion (drop the last-slot rule in
`occtSamplerIndex`, use `slot + 1` everywhere) left it green.

#2977 asks which of two things happened: either the 2D uniform path never overshot and the test was
written on the quasi-uniform sibling's behaviour, or the kernel moved under it.

**The kernel moved, by our own carried patch `0018`, and it moved for both samplers and both
dimensions alike.** It also did not close the hole: a larger ellipse still overshoots, so neither
guard is dead and the tests are re-pointed rather than relabelled.

## Why `0018` settles the 1e6 ellipse

`0018` widens the walk's end condition in `GCPnts_UniformAbscissa.cxx`:

```cpp
if (std::abs(aUi - aUU2) <= theEPSILON
    || (aUU2 - aUi < aDelta && theC.Value(aUi).SquareDistance(aPEnd) <= aTol2))
```

`theEPSILON` is parametric, derived through `Resolution()`, and on a 1e6 x 1e-3 ellipse it is about
1e-13 while the walk lands ~1.6e-8 short. The new clause is a **3D** test against `theTol`, and at
that size the same parametric shortfall is a tiny distance in model space, so the walk accepts the
step and stops.

The clause is absolute, not relative, so it stops helping as the curve grows. On a 1e8 major the
same relative shortfall is a hundred times further in model space, lands outside `theTol`, and the
sampler takes its extra step exactly as #501 described.

## Measured on `v4.0.0-kernel.3`, 2026-10-02

```bash
XC=.build/artifacts/<pkg>/OCCT/OCCT.xcframework/macos-arm64   # or Libraries/OCCT.xcframework
clang++ -std=c++17 -ObjC++ -w -I"$XC/Headers" -L"$XC" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2977-uniformabscissa-no-overshoot/probe.mm -o /tmp/probe_2977
/tmp/probe_2977
```

Each row declares whether it expects an overshoot, so the run is the assertion and a later kernel
move is a failure rather than a table nobody reads. It takes about five minutes: a single
`GCPnts_UniformAbscissa` on these curves costs 0.5 to 3 s, because carried patch `0021` made the
CPnts arc-length integration adaptive.

```
curve                                        declared  GCPnts_UniformAbscissa   GCPnts_QuasiUniformAbscissa
2D ellipse 1e6 x 1e-3, the test's 16 counts  expect 0  none                     none                         ok
2D ellipse 1e6 x 1e-3, counts 2..60          expect 0  none                     none                         ok
3D ellipse 1e6 x 1e-3, the test's 16 counts  expect 0  none                     none                         ok
3D ellipse 1e6 x 1e-3, counts 2..60          expect 0  none                     none                         ok
2D ellipse 1e6 x 0.01, 8 spot counts         expect 0  none                     none                         ok
2D ellipse 1e6 x 0.0001, 8 spot counts       expect 0  none                     none                         ok
2D ellipse 1e6 x 1e-06, 8 spot counts        expect 0  none                     none                         ok
2D ellipse 1e+08 x 0.1, 8 spot counts        EXPECT +  41(+1) 100(+1)           41(+1) 100(+1)               ok
2D ellipse 1e+10 x 10, 8 spot counts         EXPECT +  57(+1) 100(+1)           57(+1) 100(+1)               ok
2D 4-pole Bezier, 1e9 aspect, counts 2..60   expect 0  none                     none                         ok
3D 4-pole Bezier, 1e9 aspect, counts 2..60   expect 0  none                     none                         ok
2D circle r=5, counts 2..60                  expect 0  none                     none                         ok
2D line, counts 2..60                        expect 0  none                     none                         ok

PASS: every row matches its declared expectation.
```

Three things that settle #2977's question:

- **The 2D uniform path is not an odd one out.** `GCPnts_QuasiUniformAbscissa`, which is #501's own
  reproducer, agrees with `GCPnts_UniformAbscissa` on every row, and so does the 3D sibling. The
  explanation cannot be "the 2D uniform path never overshot".
- **Shrinking the minor radius does not reopen it.** 1e-2, 1e-4 and 1e-6 are all clean at a 1e6
  major. The shortfall that matters scales with the major radius, which is what an absolute 3D
  tolerance predicts.
- **Nothing on the clean rows is a measurement artefact.** The circle and the line are #501's own
  controls and were clean then too.

`still-overshoots.mm` enumerates the counts, 2D and 3D, and prints the parameters:

```
2D ellipse 1e8 x 0.1, counts 2..60
  uniform count=24 NbPoints=25 last two params 6.2831852529050414 6.2831853071795862  end 6.2831853071795862
  ...
  uniform overshoots: 24 34 35 41 47 48 49 51
  quasi   overshoots: 24 34 35 41 47 48 49 51

3D ellipse 1e8 x 0.1, counts 2..60
  uniform overshoots: 24 34 35 41 47 48 49 51
  quasi   overshoots: 24 34 35 41 47 48 49 51
```

The surplus sample is the end parameter exactly, and the one before it is 5.43e-8 short, which is
1.5e-7 away in model space. That is #501's shape unchanged, and it is what the clamp plus the
last-slot rule exist to turn into "exactly `count` points, the last of which is the curve's end".

## Is `0018` really in the pinned asset?

`check-pinned-asset-patches.py` reports it NOT DERIVABLE: it adds no header line, no string
literal, no `thread_local` wrapper and no new name, so there is no symbol to look for.
`patch-0018-present.mm` reads its other half at runtime instead. `0018` replaces
`GCPnts_QuasiUniformAbscissa::initialize`'s `Standard_ConstructionError_Raise_if(theNbPoints <= 1)`,
which the Release kernel compiles out under `No_Exception` (#487), with an explicit not-done:

```
  circle r=5                         nbPoints=0 -> IsDone=0 NbPoints=-1
  circle r=5                         nbPoints=1 -> IsDone=0 NbPoints=-1
  ellipse 10 x 5                     nbPoints=0 -> IsDone=0 NbPoints=-1
  4-pole Bezier                      nbPoints=0 -> IsDone=0 NbPoints=-1

Survived. 0018 is in the pinned kernel.
```

Against the unpatched kernel, `Scripts/repro/501-quasiuniform-buffer-overflow/README.md` recorded
`IsDone()` with one point on a circle, five on an ellipse, and a **SIGSEGV** on the Bezier. All four
rows have changed, and the process surviving the last one is the clearest of them.

## What changed in the tests

`Curve2DTests.uniformDrawRespectsCount` and the whole of
`Tests/OCCTCurveTests/Sampling/GCPntsSamplerBoundsTests.swift` now run on the 1e8 x 0.1 ellipse at six of
the eight overshooting counts, with #501's own ellipse kept as a control at the same counts. Two
other things were wrong with them and are fixed in the same change:

- **The end-point tolerance was `1e-6` against a 1.5e-7 shortfall**, so it would have accepted the
  defect it exists to catch even on a fixture that does overshoot.
- **Three cases bound the result with `if let` and asserted nothing on an empty sample**, which is
  exactly what a clamp returning nothing produces.

## Injection matrix

`swift test --filter 'OCCT(CurveTests\.GCPntsSamplerBoundsTests|Geom2dTests\.Curve2DTests/uniformDrawRespectsCount)'`,
eight cases.

| injection | result |
|---|---|
| none | 8 of 8 pass |
| `occtSamplerIndex` returns `slot + 1` always, dropping the last-slot rule | **3 fail**: the 2D draw test on all four counts, and both end-point cases in the 3D suite on all six. The `settledEllipse` control **passes**, which is the measurement that the old fixture was dead for this rule |
| `occtSamplerKept` returns `capacity - 1`, breaking the clamp | **6 fail**, every case that asserts a count, including the control |

The two rows are disjoint in what they prove: the first can only fail where the sampler overshoots,
the second fails everywhere, and the control's colour differs between them.
