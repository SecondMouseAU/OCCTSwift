# #766 Surface plate, fill and pipe batch (batch 13): the injection matrix

Evidence for the PR that lifted eighteen Surface test files off `v5.0.0-766-execution`. Measured
against the pinned kernel `v4.0.0-kernel.4`; re-derive rather than quote.

| file | what it is |
|---|---|
| `SweepPlateFillShadow.swift.txt` | module-local Swift functions shadowing the bridge entry points the eighteen suites reach, distorted by `PF_SWITCH`. A `.txt` so nothing builds it in place |
| `switches.txt` | the 89 switches: a wrong answer of the right type, a dropped or swapped input, a constraint accepted and never loaded |
| `run-injection-matrix.py` | runs the built bundle per switch, writes `matrix-LABEL.json`, asserts the sweep both ways |
| `matrix-before.json` | the switches against `origin/main`'s versions of the eighteen files |
| `matrix-after.json` | against the lifted ones |

Running it: copy the `.txt` to `Sources/OCCTSwift/SweepPlateFillShadow.swift` (never commit it), build
with `swift build --build-tests`, symlink `XCTest.framework`, `Testing.framework` and
`libXCTestSwiftSupport.dylib` into `.build/out/Products/Debug/PackageFrameworks`, run the script with
label `after`; for `before`, `git checkout origin/main --` the eighteen test files, rebuild, run with
label `before`, then `git checkout HEAD -- Tests`, delete the shadow, rebuild and require
`strings <bundle> | grep -c PF_SWITCH` to read 0 and the bundle green with a switch set.

A green switch is sometimes the contract, not a gap in the tests:

* `BEZFILL_STYLE_COONS`, `BSFILL4_STYLE_STRETCH`: the kernel gives the same surface for stretch and
  Coons on these curves (two curves; and four curves with these poles), which the tests' own
  comments record.
* `PSB_FIRST_IS_LAST`: on a closed spine the first and last sections coincide.
* `FILLSUP_SUPPORT_IGNORED`: the support in `FillingSupportFaceTests`' fixtures is the very wall the
  rim's own pcurve already supplies, so ignoring it changes nothing. A fixture whose support differs
  from the rim's wall would close this; left open.
