# #1407: the throwing-call gate, and the one live site it found

`gp_Dir`/`gp_Dir2d`/`gp_Ax*`/`Geom_Direction` raise `Standard_ConstructionError` on a zero-norm or
non-perpendicular argument, and the `D1`/`D2` evaluators raise outside their parameter range. An
exception that reaches Swift-generated frames has no matching unwind personality routine, so it is
a `std::terminate`/SIGABRT that takes the process down rather than an error the caller can handle.
Forty-nine such sites were fixed by hand under #345 and nothing re-checked them since.

`Scripts/check-throwing-calls.py` is that check. Run bare it gates; `--report-only` lists without
failing, `--self-test` runs its own fixtures.

## What it found

One live site, `OCCTGTrsf2dAffinity`, which built `gp_Dir2d(axDx, axDy)` straight from the caller's
two doubles with no length check and no `try` anywhere in the chain. `probe.mm` reproduces the
crash against the pinned kernel with nothing but OCCT:

```
constructing gp_Dir2d(0, 0) the way OCCTGTrsf2dAffinity does...
libc++abi: terminating due to uncaught exception of type Standard_ConstructionError:
  gp_Dir2d() - input vector has zero norm
Abort trap: 6
```

Reached from Swift as `GeneralTransform2D.affinity(axisOrigin:axisDirection:ratio:)` with a zero
direction. With the pre-fix code restored, `swift test --filter GeneralTransform2DTests` does not
report a failure: the runner exits with **signal 6**, which is the whole point of the defect class.

```
error: Process '...swiftpm-testing-helper ...' exited with unexpected signal code 6
```

## The three rules, and why each exists

Each was added because the version before it reported sites that were not hazards. The false
positives are recorded here rather than tuned away silently, since #1407 asked for exactly this
measurement before gating.

| rule | sites it removed | why it is sound |
|---|---|---|
| a construction from numeric literals only | many | `gp_Dir(0, 0, 1)` cannot vary with a caller |
| a value measured and rejected earlier in the same function | 6 | the bridge's idiom is `if (d1.Magnitude() < 1e-12) return false;` before `gp_Dir dir(d1)`, and the involute placement functions compute `dirLen` and return early below `1e-12` |
| a file-local helper whose every call site is inside a `try`, to a fixpoint | 24 | the unwind boundary is the exported entry point, not each frame |

Starting count 33, ending count 1. The 32 removed were false positives of a rule that stopped at
the function body, which is the rate #1407 asked to see before deciding gate versus census.

## A finding this turned up, not fixed here

A fourth category was skipped rather than counted: file-local helpers **never called in their own
file**. The `.mm` splits copied every static helper into every file of a domain, so most copies are
dead where they sit: measured, **441 dead static helper definitions** across the 74 bridge sources,
including 11 copies each of `_storeTrsf`, `occtFacePlane` and `occtWireInterpolateImpl`. They cannot
reach the bridge boundary from where they sit, so they are not hazards, but they are real
duplication debt in the same family as #1385. Filed separately; the gate prints the count so it
cannot quietly grow.
