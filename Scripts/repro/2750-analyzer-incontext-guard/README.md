# #2750: the `BRepCheck_Analyzer` guard, and the fixture it is tested with

The defect is #2746's, located and measured in
[`Scripts/repro/2746-brepcheck-incontext-sigsegv/`](../2746-brepcheck-incontext-sigsegv/):
`BRepCheck_Edge::InContext` down_casts `myHCurve` to `GeomAdaptor_Curve` and dereferences the
result without testing it, and `Minimum()` sets `myHCurve` to an `Adaptor3d_CurveOnSurface`
whenever the edge is not degenerated, has no curve-3D representation holding a non-null
`Geom_Curve`, and has a pcurve to adopt instead. This directory holds the two things #2750 needed
on top of that record: the committed test fixture, and the measurement of what the fault actually
does inside the bridge's own process.

Run both with `run.sh` from the repository root:

```bash
Scripts/repro/2750-analyzer-incontext-guard/run.sh
```

## `make-fixture.mm`

Writes `Tests/OCCTStressTests/Fixtures/brepcheck-incontext-pcurve-only-edge.brep`, the file the
Swift regression suite loads, and prints both candidate predicates over three shapes on the way.

```
  healthy box              nullCurve3DRep = false  pcurveOnlyFaceEdges = 0
  box, 3D curve nulled     nullCurve3DRep = true   pcurveOnlyFaceEdges = 1
  same shape off disk      nullCurve3DRep = false  pcurveOnlyFaceEdges = 1
```

The third row is the whole reason the guard's predicate is written the way it is.
`BRep_Builder::UpdateEdge` with a null curve nulls the curve *inside* the existing `BRep_Curve3D`
record rather than removing the record, so the in-memory shape has a null `Curve3D` representation
to find. `BRepTools::Write` then drops that record on the way out, so the shape read back from the
file has none, and it crashes the analyzer just the same. A guard written against "has a null
`Curve3D` representation" would pass the file straight through.

The fixture is committed rather than generated at test time because the state is not constructible
through the public Swift API: it needs `BRep_Builder::UpdateEdge`. That the file is enough is the
reachability that made this P1, since it means a consumer reaches it by opening a document.

## `signal-probe.mm`

Removing the guard and running the whole Swift suite did not kill the test runner, which did not
match the standalone #2746 probe, so the difference was measured rather than argued about. Two
cases, identical but for one call:

| case | result |
|---|---|
| `without-setsignal` | dies, `SIGSEGV` inside `BRepCheck_Edge::InContext`, exit 139 |
| `with-setsignal` | survives, `IsValid() = false`, no exception reaches the caller |

`OSD::SetSignal(Standard_False)` is exactly what the bridge's `occtEnsureSignals()` does, once per
process, from fourteen entry points. Its `SegvHandler` calls
`Standard_ErrorHandler::Abort(OSD_SIGSEGV(...))`, which `longjmp`s to the nearest registered
handler. `BRepCheck_Analyzer.cxx` wraps every `InContext` call in
`try { OCC_CATCH_SIGNALS ... } catch (Standard_Failure const&)`, and that macro is live there
because `BRepCheck` is an OCCT translation unit, so the handler exists to be found: control returns
to it, `Raise()` turns the stored `OSD_SIGSEGV` into a C++ exception, and the `catch` records
`BRepCheck_CheckFail` and carries on.

**This paragraph first said `Abort` was "a plain `throw theError;`" with `OCC_CONVERT_SIGNALS`
undefined, and that `Perform()`'s `OCC_CATCH_SIGNALS` absorbed nothing. Both are wrong** and are
corrected above, on #2763's reading and on four measurements against the pinned asset in
[`Scripts/repro/2763-abort-signal-mechanism/`](../2763-abort-signal-mechanism/). The define is
present for OCCT's own translation units, `OSD_signal.cxx` is the only one that instantiates the
template, and a plain `catch (Standard_Failure const&)` with no handler registered does not run:
OCCT prints "no catch was found" and calls `exit(1)`. Nothing in the table above changes, which is
the point worth keeping: the observation was measured and the mechanism was assumed.

Two things follow, and both are in the guard's favour:

1. **The severity is a race the consumer does not control.** A process that has called one of those
   fourteen entry points gets a wrong answer; one that has not gets a dead process. Nothing in the
   shipped API tells a caller which they are in. `swift test --filter isValidDoesNotCrash` with the
   guard's predicate forced to 0 exits with signal 11; the same build running the whole suite
   survives with six failing expectations.
2. **`OCC_CATCH_SIGNALS` being inert is not the same claim as "a signal is uncatchable".** The
   macro is inert in bridge code, and separately OCCT's installed handler converts the signal at
   any of OCCT's own sites, where the macro is live.
   `CLAUDE.md`'s Known OCCT Bugs bullet said the stronger thing; it is corrected in this PR.
