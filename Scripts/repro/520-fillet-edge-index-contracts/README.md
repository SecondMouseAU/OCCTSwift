# OCCTSwift#520 ground truth: the radius law `BRepFilletAPI_MakeFillet` was never given

Two standalone probes, run against the pinned `OCCT.xcframework` (8.0.0p1 + our carried patches).
They establish what OCCT does with the calls the two radius-law fillet entry points were making,
and what its `SetRadius(UandR, …)` overload does with a profile no one validates. They are what the
#520 fix is calibrated against: the issue asked three contract questions and the measurement
answered a fourth nobody had asked.

No fixture files: every case is a box.

## Compile and run

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/520-fillet-edge-index-contracts/occt_520_variable_radius_law.mm \
  -o /tmp/occt_520_variable_radius_law
/tmp/occt_520_variable_radius_law     # ends in a SIGSEGV; that is the last case
```

The second probe crashes in two of its cases, so each runs in its own process:

```bash
clang++ … Scripts/repro/520-fillet-edge-index-contracts/occt_520_radius_law_crash.mm \
  -o /tmp/occt_520_radius_law_crash
for c in no-radius radius-dropped zero-radius negative-radius all-radii-zero \
         params-out-of-range-2pt params-out-of-range-3pt params-equivalent-3pt \
         params-degenerate-3pt params-descending-3pt single-point; do
  /tmp/occt_520_radius_law_crash "$c"; echo "  exit=$?"
done
```

## `occt_520_variable_radius_law.mm`: the overload `OCCTShapeFilletVariable` was calling

The bridge wrote, once per profile point:

```cpp
double param = first + params[i] * (last - first);   // a curve parameter
fillet.SetRadius(radii[i], param, 1);                // "1 is the contour index"
```

`BRepFilletAPI_MakeFillet` has no `(Real, Real, Integer)` overload. The viable candidate is
`SetRadius(const double Radius, const int IC, const int IinC)`, so `param` was truncated to an `int`
and used as the **contour** index, and `1` was the edge-within-contour index. The comment was wrong
about which argument it was naming, and the call was wrong about what it was setting.

| profile on a 20mm box, edge 0 | measured |
|---|---|
| bridge: `SetRadius(r, param, 1)` per point | volume 7995.707963 |
| OCCT: `SetRadius(UandR, 1, 1)` | volume 7981.047467 |
| reference: constant 1.0 | volume **7995.707963** |
| reference: constant 3.0 | volume 7961.371669 |

The bridge result is bit-identical to the constant-1.0 reference. Same on a 30mm box with a 3-point
profile: bridge 26993.561945, constant-1.0 26993.561945, the requested profile 26947.284023. The
"variable radius" fillet was a constant one.

Why that particular constant, and why it was a crash waiting to happen, is the third section. A box
edge's curve range is `[0, side]`, so `[(0, 1.0), (1, 3.0)]` truncated to contour indices 0 and 20:

| call on a 20mm box with 1 contour | measured |
|---|---|
| `SetRadius(2.0, IC=0, IinC=1)` | volume 7982.831853 — same as `IC=1`, i.e. it took effect |
| `SetRadius(2.0, IC=1, IinC=1)` | volume 7982.831853 |
| `SetRadius(2.0, IC=20, IinC=1)` | dropped, then **SIGSEGV** in `Build()` |

`ChFi3d_FilBuilder::SetRadius` guards only `IC <= NbElements()`, with no lower bound (the same
one-sided check #505 found). `IC=0` passes it and reaches `Value(0)` on a 1-based sequence, which on
this build happened to read contour 1 — so the first profile point landed as a constant radius. A
large `IC` fails the check and is dropped silently, which is what made the last point a no-op.

## `occt_520_radius_law_crash.mm`: the contour that never gets a radius, and the profile contract

| case | measured |
|---|---|
| `no-radius` — `Add(edge)`, no `SetRadius` at all | **SIGSEGV** (exit 139) |
| `radius-dropped` — the one `SetRadius` dropped by `IC <= NbElements()` | **SIGSEGV** (exit 139) |
| `zero-radius` — profile `[(0, 1.0), (1, 0.0)]` | `IsDone=1`, volume 7998.480894, valid |
| `negative-radius` — profile `[(0, 1.0), (1, -3.0)]` | `IsDone=1`, volume 7999.471533, **`BRepCheck_Analyzer` invalid** |
| `all-radii-zero` | `IsDone=0` |
| `params-out-of-range-2pt` — X of 99 and -3 | volume 7981.047467, identical to X of 0 and 1 |
| `params-out-of-range-3pt` — X of -5, 0, 7 | volume 7963.730821 |
| `params-equivalent-3pt` — X of 0, 0.4166…, 1 | volume 7963.730821, identical to the row above |
| `params-degenerate-3pt` — X all 0.5 | `IsDone=0` (the renormalisation divides by zero) |
| `params-descending-3pt` — X of 1, 0.5, 0 | volume 7960.426609, a different shape from the ascending profile |
| `single-point` | volume 7982.831853, i.e. a constant radius |

Three things follow, and they are what `occtFilletSetRadiusProfile` enforces:

1. **A contour must receive a radius.** Nothing downstream reports the omission; `Build()` crashes,
   uncatchably. Every path that calls `Add(edge)` has to reach a successful `SetRadius` or return
   before `Build()`.
2. **A non-positive radius in a profile is not caught by OCCT.** This is the opposite of what #489
   measured for `Add(radius, edge)`, where a bad radius merely fails `IsDone()`. Here it reports
   success and hands back an invalid shape, so the bridge-side precondition is the only thing
   between that shape and a caller.
3. **`[0, 1]` is a caller-facing contract, not an OCCT-enforced one.** OCCT ignores the parameters
   entirely for 1 or 2 points and renormalises 3 or more, so an out-of-range profile is silently
   *reinterpreted* rather than rejected — `[(-5, 1), (0, 4), (7, 1)]` puts its peak at 41.7% of the
   contour instead of at the start. Equal parameters divide by zero and descending ones reverse the
   law. All three are rejected rather than reinterpreted.

The same renormalisation is why a profile always spans the whole edge: it cannot fillet part of one
and leave the rest alone, and only the *relative* spacing of interior points survives. That is
documented on both Swift entry points rather than being left for a caller to discover.
