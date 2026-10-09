# #766 Surface GeomFill guide, PipeShell and Plate_Plate lift: the injection matrix

Evidence for the PR that lifted twelve Surface test files off `v5.0.0-766-execution` (the
GeomFill guide-trihedron, Stretch, Sweep and Frenet tests, the PipeShell tests, the Plate_Plate
global-translation and linear-XYZ tests and `GeomPlate_BuildAveragePlane`) and added one
`FillingSupportFaceTests` fixture. Measured against the pinned kernel `v4.0.0-kernel.5`; re-derive
rather than quote.

| file | what it is |
|---|---|
| `SweepGeomFillShadow.swift.txt` | module-local Swift functions shadowing the bridge entry points the thirteen suites reach, distorted by `GFPS_SWITCH`. A `.txt` so nothing builds it in place |
| `switches.txt` | the 69 switches: a wrong answer of the right type, a swapped or negated frame axis, a dropped input, a constraint accepted and never loaded |
| `run-injection-matrix.py` | runs the built bundle per switch, writes `matrix-LABEL.json`, asserts the sweep both ways |
| `matrix-before.json` | the switches against `origin/main`'s versions of the thirteen files |
| `matrix-after.json` | against the lifted ones |

Running it: copy the `.txt` to `Sources/OCCTSwift/SweepGeomFillShadow.swift` (never commit it), build
with `swift build --build-tests`, symlink `XCTest.framework`, `Testing.framework` and
`libXCTestSwiftSupport.dylib` into `.build/out/Products/Debug/PackageFrameworks`, run the script with
label `after`; for `before`, commit the lifted files, `git checkout origin/main --` the thirteen test
files, rebuild, run with label `before`, then `git checkout HEAD -- Tests`, delete the shadow,
rebuild and require `strings <bundle> | grep -c GFPS_SWITCH` to read 0 and the bundle green with a
switch set.

Two shadows had to be fixed on the first pass, and both are instructive. `GAC_SETCURVE_FALSE` and its
two siblings first skipped the real `SetCurve`, which leaves a law with no curve and traps inside
OCCT on the next `D0`: that is a crash, not a red row, and no bridge defect looks like it. They now
call the real function and lie only about the verdict. `PLATE_LXYZ_COEFF_SIGN` negated every
coefficient, which is the same constraint, so it was replaced by `PLATE_LXYZ_COEFF_SECOND_PLUS`.

A green switch is sometimes the contract, not a gap in the tests:

* `PSB_FRENET_FLIPPED`: `setFrenet(false)` instead of `true` leaves every pinned torus volume and
  swept area unchanged to 1e-6, because on a circular or rectangular planar spine the Frenet and the
  corrected-Frenet laws give the same shell. The injection models a change the kernel does not
  make observable on these fixtures.
