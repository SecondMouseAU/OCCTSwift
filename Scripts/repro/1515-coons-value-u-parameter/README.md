# #1515: `GeomFill_CoonsAlgPatch::Value` sampled the U boundaries at V

`Value(U, V)` built its result from all four boundaries evaluated at `V`, where `bound[0]` and
`bound[2]` are the **U-direction** sides. For any boundary set whose V-direction sides are straight
the result is then independent of `U` entirely, and the surface collapses onto the `u == v`
diagonal.

Samples with `u == v` are coincidentally correct, which is why the output reads as a valid surface
rather than as an obvious failure. `Shape.coonsAlgPatch` is the only caller of `Value()` in this
package or the kernel; `GeomFill_ConstrainedFilling` evaluates through `Eval()` and is unaffected.

## The probe

`occt_1515_coons_probe.mm` builds a unit square from four straight boundaries and prints, at each
sample, the kernel's `Value(U, V)` beside a re-implementation using **the kernel's own
coefficients** with `bound[0]`/`bound[2]` sampled at `U`. The second column is what the one-line
fix produces, so the two columns agreeing is the fix being live rather than an assertion about it.

```bash
XCF="$PWD/Libraries/OCCT.xcframework/macos-arm64"
clang++ -std=c++17 -ObjC++ -w -I"$XCF/Headers" \
  Scripts/repro/1515-coons-value-u-parameter/occt_1515_coons_probe.mm \
  -L"$XCF" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o /tmp/coons
/tmp/coons
```

## Measured against the pinned kernel, after the v4.0.0-kernel.1 repin

```
   u     v  |      kernel Value()     |   one-line-fixed Value()
------------+-------------------------+--------------------------
 0.00  0.00 | (  0.000,  0.000) | (  0.000,  0.000)
 0.00  0.50 | (  0.000,  0.500) | (  0.000,  0.500)
 0.50  0.00 | (  0.500,  0.000) | (  0.500,  0.000)
 0.50  0.50 | (  0.500,  0.500) | (  0.500,  0.500)
 1.00  0.00 | (  1.000,  0.000) | (  1.000,  0.000)
 1.00  0.50 | (  1.000,  0.500) | (  1.000,  0.500)
 0.25  0.75 | (  0.250,  0.750) | (  0.250,  0.750)
 0.75  0.25 | (  0.750,  0.250) | (  0.750,  0.250)
```

The columns agree at every sample. Before carried patch `0034` was pinned, the kernel column was a
function of `V` alone: `(1.00, 0.00)` read `(0.000, 0.000)` and `(0.25, 0.75)` read
`(0.750, 0.750)`.

## The Swift assertion this unblocked

`Tests/OCCTSurfaceTests/Issue1515CoonsPatchUParameterTests.swift` asserts the bilinear surface over
a flat 10 x 10 square, which is the closed form for a Coons patch with four straight sides.

That test **could not be written before the repin**, and `Package.swift` said so in as many words:
it asserts the correct surface, and `ci.yml`'s `build-and-test` resolved the unpatched asset where
every off-diagonal sample is still wrong. A test that fails in CI and passes locally is worse than
no test, so the note recorded who could add it rather than adding it.

It carries the defect's signature as its own case, not only a sweep: `(u:1, v:0)` must be
`(10, 0, 0)` and not `(0, 0, 0)`. Both of the collapsed values are corners of the same square,
which is the reason this defect was invisible for as long as it was.
