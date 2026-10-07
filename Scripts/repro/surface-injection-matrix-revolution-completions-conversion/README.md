# #766 Surface batch 13: the injection matrix

Evidence for the PR that lifted twenty-two Surface test files (revolution, BSpline and Bezier
completion, conversion, projection, GeomEval) off `v5.0.0-766-execution`. Measured against the
pinned kernel `v4.0.0-kernel.4`; re-derive rather than quote.

| file | what it is |
|---|---|
| `SweepSurfaceShadow.swift.txt` | module-local Swift functions shadowing the bridge entry points the changed tests reach, distorted by `SF_SWITCH`. A `.txt` so nothing builds it in place |
| `switches.txt` | the 108 switches, derived from the shadow file (semantic distortions: a wrong answer of the right type, never "returns nil") |
| `run-injection-matrix.py` | runs the built bundle per switch, writes `matrix-LABEL.json`, asserts the sweep both ways |
| `matrix-before.json` | the switches against `origin/main`'s versions of the twenty-two files |
| `matrix-after.json` | against the lifted ones |

Running it: copy the `.txt` to `Sources/OCCTSwift/SweepSurfaceShadow.swift` (never commit it), build
with `swift build --build-tests`, symlink `XCTest.framework`, `Testing.framework` and
`libXCTestSwiftSupport.dylib` into `.build/out/Products/Debug/PackageFrameworks`, run the script with
label `after`; for `before`, `git checkout origin/main --` the twenty-two test files, rebuild, run
with label `before`, then `git checkout HEAD -- Tests`, delete the shadow, rebuild and require
`strings <bundle> | grep -c SF_SWITCH` to read 0.

Two suites print the same test name ("SetWeightCol and SetWeightRow", in the BSpline and the Bezier
V129 files), which one combined run cannot attribute, so the runner re-runs each owning suite alone
when that name fails.
