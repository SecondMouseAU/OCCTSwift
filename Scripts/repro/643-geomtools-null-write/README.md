# #643: GeomTools_Curve2dSet/SurfaceSet accept a null handle, GeomTools_CurveSet does not

Cluster C's own census (#666, PR #711) concluded, without re-measuring, that #643 is "already
bridge-guarded ... the remaining defect is inside OCCT's own `GeomTools_*Set` container,
unreachable through OCCTSwift today." This directory verifies that conclusion rather than
inheriting it, and answers the two questions #643 itself asks: is the guard really comprehensive,
and does the upstream asymmetry still hold at the pinned kernel.

## The defect

Three copies of the same writer disagree about a null handle, in `Add()` and, one function down,
in `Index()` too:

| class | `Add()` body | `Index()` body |
|---|---|---|
| `GeomTools_CurveSet` | `return (C.IsNull()) ? 0 : myMap.Add(C);` | `return S.IsNull() ? 0 : myMap.FindIndex(S);` |
| `GeomTools_Curve2dSet` | `return myMap.Add(S);` | `return myMap.FindIndex(S);` |
| `GeomTools_SurfaceSet` | `return myMap.Add(S);` | `return myMap.FindIndex(S);` |

`Add()` never crashes for any of the three. The two unguarded ones bind the null at index 1 and
hand back a valid-looking index, so the caller gets no signal until `Write()` dereferences it
(`Curve2dSet::Write` → `PrintCurve2d` → `C->DynamicType()`; `SurfaceSet::Write` → `PrintSurface` →
`S->DynamicType()`). A SIGSEGV is an OS signal, so the bridge's `catch (...)` cannot absorb it.

`Index()` was not named in the original issue. It has the identical asymmetry, found while
checking "whether the three writers have other divergences beyond this one," per the issue's own
suggestion. It does not crash (`NCollection_IndexedMap::FindIndex` only hashes/compares the
handle's identity, it never dereferences it), but `Curve2dSet`/`SurfaceSet::Index(null)` silently
returns the bogus index the null was bound at, where `CurveSet::Index` correctly answers 0.

## Question 1: is the crash really unreachable through OCCTSwift?

Yes, confirmed two ways.

**Static: there is exactly one call site of each class in the whole tree.**

```
$ grep -rn "GeomTools_Curve2dSet\|GeomTools_SurfaceSet\|GeomTools_CurveSet" Sources/
```

turns up implementations only in `Sources/OCCTBridge/src/OCCTBridge_IO.mm`, nowhere else. Both
`OCCTGeomToolsCurve2dSetWrite` and `OCCTGeomToolsSurfaceSetWrite` already guard every array element
before it reaches `Add()`:

```cpp
for (int i = 0; i < count; i++) {
    auto* c = (OCCTCurve2D*)curveRefs[i];
    if (!c || c->curve.IsNull()) return nullptr;
    cs.Add(c->curve);
}
```

This is the #618 "array element through a cast" shape, and it is unconditional: the guard runs
before `Add()` regardless of *how* a `Curve2D`/`Surface` came to wrap a null handle, so the
question of whether the public Swift API can ever produce such an object (it cannot: `Curve2D`'s
`init(handle:)` is `internal`, and every public factory already returns `nil` on failure rather
than a wrapper around a null geometry handle) does not change the answer. Even a hypothetical
future factory bug that did produce one would still be caught here, one line before `Add()`.

**Dynamic: `probe_643.mm` calls the real bridge functions, not a reimplementation.** `PART 2`
override-links the actual `Sources/OCCTBridge/src/OCCTBridge_IO.mm` and calls
`OCCTGeomToolsCurve2dSetWrite`/`OCCTGeomToolsSurfaceSetWrite` directly with a genuinely
null-handle-wrapping `OCCTCurve2D`/`OCCTSurface`, the exact struct shape an array element becomes
once the bridge unwraps it. Both refuse (`nullptr`, not a crash), for a null-only array and for a
mixed valid+null array (confirming the whole batch is refused, not just the bad element, matching
the sibling comment in `OCCTGeomToolsCurveSetWrite` about why "refuse the batch" beats "drop the
null").

**Census's conclusion holds.**

## Question 2: does the upstream asymmetry still hold at the pinned kernel?

Yes. The issue was filed against 8.0.0p1; this tree has since re-pinned to `v2.0.0-kernel.1` (OCCT
`V8_0_1` + eleven carried patches, #512). `probe_643.mm` PART 1 re-measures directly against the
pinned kernel's headers/binary and reproduces the identical result:

```
  -- Add() alone --
  GeomTools_CurveSet::Add(null)                  Add returned 0    returned normally
  GeomTools_Curve2dSet::Add(null)                Add returned 1    returned normally
  GeomTools_SurfaceSet::Add(null)                Add returned 1    returned normally

  -- Add() then Write(), which is what the bridge does --
  GeomTools_CurveSet::Add(null) + Write          returned normally
  GeomTools_Curve2dSet::Add(null) + Write        SIGSEGV (uncatchable)
  GeomTools_SurfaceSet::Add(null) + Write        SIGSEGV (uncatchable)

  -- Index(), a second divergence: no crash, but a bogus non-zero index --
  GeomTools_CurveSet::Add(null); Index(null)     Index returned 0  returned normally
  GeomTools_Curve2dSet::Add(null); Index(null)   Index returned 1  returned normally
  GeomTools_SurfaceSet::Add(null); Index(null)   Index returned 1  returned normally
```

`src/ModelingData/TKGeomBase/GeomTools/GeomTools_{CurveSet,Curve2dSet,SurfaceSet}.cxx` are
byte-identical between the pinned `V8_0_1` tag and current upstream `master`, confirmed with a
direct diff against both, not assumed. Worth filing.

## Filed upstream

Following this repo's established pattern (#310, #318, #348, the thread-safety cluster): repro
issue plus fix PR, leading with the sibling that already does it correctly.

- [Open-Cascade-SAS/OCCT#1434](https://github.com/Open-Cascade-SAS/OCCT/issues/1434): repro
- [Open-Cascade-SAS/OCCT#1435](https://github.com/Open-Cascade-SAS/OCCT/pull/1435): fix (four
  one-line guards: `Add`/`Index` on both `Curve2dSet` and `SurfaceSet`)

Carried locally as [`Scripts/patches/0023-GeomTools_Curve2dSet-SurfaceSet-null-handle-643.patch`](../../patches/0023-GeomTools_Curve2dSet-SurfaceSet-null-handle-643.patch).
Inert until the pinned xcframework is rebuilt (tracked in #512); this PR does not rebuild or bump
the pin.

## Prove the test fails: injection matrix

Per `okf/policies/prove-the-test-fails.md`. Each row breaks one thing, confirms the previously-safe
case now fails, then restores.

| injection | subject | before (guard present) | after (guard removed) | verdict |
|---|---|---|---|---|
| remove the bridge-side element guard in `OCCTGeomToolsCurve2dSetWrite` | `OCCTGeomToolsCurve2dSetWrite([nullWrappingCurve2D])` | `nullptr` (refused) | SIGSEGV | guard is load-bearing |
| remove the bridge-side element guard in `OCCTGeomToolsCurve2dSetWrite` | `OCCTGeomToolsCurve2dSetWrite([validLine, nullWrappingCurve2D])` (mixed batch) | `nullptr` (refused) | SIGSEGV | guard is load-bearing, covers the mixed-batch case too |
| remove the bridge-side element guard in `OCCTGeomToolsSurfaceSetWrite` | `OCCTGeomToolsSurfaceSetWrite([nullWrappingSurface])` | `nullptr` (refused) | SIGSEGV | guard is load-bearing |
| apply the upstream kernel patch (`0023-*`) | `GeomTools_Curve2dSet::Add(null)` + `Write()` | SIGSEGV | returns 0, `Write()` completes normally | fix is load-bearing |
| apply the upstream kernel patch (`0023-*`) | `GeomTools_SurfaceSet::Add(null)` + `Write()` | SIGSEGV | returns 0, `Write()` completes normally | fix is load-bearing |
| apply the upstream kernel patch (`0023-*`) | `GeomTools_Curve2dSet::Index(null)` after `Add(null)` | returns 1 (bogus) | returns 0, matching `CurveSet::Index` | fix is load-bearing |
| apply the upstream kernel patch (`0023-*`) | `GeomTools_SurfaceSet::Index(null)` after `Add(null)` | returns 1 (bogus) | returns 0, matching `CurveSet::Index` | fix is load-bearing |

The bridge-side guard rows were tested by editing a scratch copy of `OCCTBridge_IO.mm` (the guard
line removed, everything else unchanged), override-linking it in place of the real file, and
restoring afterward; the tracked file was never left in the broken state. The kernel-patch rows
were tested by override-linking the two patched `.cxx` files ahead of the unpatched static archive,
so the "after" column reflects the actual upstream PR's diff, not a description of it.

## Files

- `probe_643.mm`: the ground-truth probe, self-contained, no fixtures. Compile and run per
  CLAUDE.md's ground-truth recipe with `Sources/OCCTBridge/src/OCCTBridge_IO.mm` linked in directly
  (see the file's own header comment for the exact command).

## Outcome

No bridge-side change. The census's "already guarded, unreachable" conclusion holds under direct
testing, both against the issue's original 8.0.0p1 claim and freshly against the pinned
`v2.0.0-kernel.1`. #643 closes on this evidence: existing bridge guard confirmed comprehensive,
upstream defect confirmed still live and filed (issue + fix PR), kernel patch carried for the next
rebuild (#512).
