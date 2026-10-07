# #766 Surface batch (batch 12): the injection matrix

Evidence for the PR that lifted fourteen Surface test files off `v5.0.0-766-execution`. Measured
against the pinned kernel `v4.0.0-kernel.4`; re-derive rather than quote.

| file | what it is |
|---|---|
| `SweepSurfaceShadow.swift.txt` | module-local Swift functions shadowing 40 bridge entry points, distorted by `SF_SWITCH`. A `.txt` so nothing builds it in place |
| `switches.txt` | the 64 switches (semantic distortions, plus three FIX injections for the known-issue pins) |
| `run-injection-matrix.py` | runs the built bundle per switch, writes `matrix-LABEL.json`, asserts the sweep both ways |
| `matrix-before.json` | the switches against `origin/main`'s versions of the fourteen files |
| `matrix-after.json` | against the lifted ones |

Running it: copy the `.txt` to `Sources/OCCTSwift/SweepSurfaceShadow.swift` (never commit it), build
with `swift build --build-tests`, symlink `XCTest.framework`, `Testing.framework` and
`libXCTestSwiftSupport.dylib` into `.build/out/Products/Debug/PackageFrameworks`, run the script with
label `after`; for `before`, `git checkout origin/main --` the fourteen test files, rebuild, run with
label `before`, then `git checkout HEAD -- Tests`, delete the shadow, rebuild and require
`strings <bundle> | grep -c SF_SWITCH` to read 0.

`PLATE_TOL_X100` was dropped: `plateThrough`'s tolerance reddens nothing in either version.
