# OCCTSwift#348 reproducer — `ShapeUpgrade_UnifySameDomain` null-pcurve SIGSEGV

Standalone, deterministic reproducer for the uncatchable SIGSEGV reported against
`UnifySameDomainBuilder.build()` on a mesh-sewn solid (originally found in OCCTReconstruct#194).

## Root cause

`ShapeUpgrade_UnifySameDomain::IntUnifyFaces` (and its file-local `SplitWire` helper) disambiguate
between multiple candidate next-edges at a branching vertex by comparing each candidate's pcurve
tangent direction on the current reference face. Three call sites fetch that pcurve via
`BRep_Tool::CurveOnSurface(edge, refFace, first, last)` and immediately dereference it
(`->D1(...)`/`->Value(...)`) without checking `IsNull()` — unlike every other `CurveOnSurface` call
site in the same file, all of which do check. `CurveOnSurface` legitimately returns a null handle
when an edge has no pcurve on the given face, which is the common case for a raw per-triangle
mesh-sewn solid (`BRepBuilderAPI_Sewing` from an STL/mesh import) at a vertex shared by more than
two edges. Dereferencing the null handle is an unguarded null-pointer call through the `Geom2d_Curve`
vtable — Address 0, `EXC_BAD_ACCESS`, uncatchable in-process (same signature as the #263/#310/#317/
#318 crash family).

Confirmed via a debug (`-g -O0`) single-TU override-link (the patched `.cxx` compiled standalone and
linked *before* `libOCCT-macos.a` so the linker never pulls the stock archive member for these
symbols) plus `lldb`: `bt` on the crash resolves precisely to
`ShapeUpgrade_UnifySameDomain.cxx:4003` (`aPCurve->D1(...)`, called from `IntUnifyFaces`, called
from `UnifyFaces`, called from `Build`). Two further unguarded dereferences at
`ShapeUpgrade_UnifySameDomain.cxx:3989` (`CurPCurve->D1`) and `:4027` (`aPCurve->Value`) are the
same bug pattern, not (yet) individually triggered by this fixture but reachable by the same
code path; the `SplitWire` helper (used elsewhere in the file, structurally identical
disambiguation loop) has the identical unguarded pair.

## Fix

`Scripts/patches/0013-ShapeUpgrade_UnifySameDomain-guard-null-pcurve-348.patch`: guard all five call
sites with `IsNull()` checks, following the file's own established pattern (`if (aPCurve.IsNull())
{ continue; }`/fallback-to-first-candidate), so a missing pcurve degrades to "treat as an ordinary,
unranked candidate" instead of crashing.

## Reproducer

[`unify-crash-mmd-kiha10-body5.brep`](./unify-crash-mmd-kiha10-body5.brep) (606 KB) — one solid, 662
faces, `BRepCheck`-invalid (not a distinguishing factor — other equally-invalid mesh-sewn solids from
the same source file unify cleanly). Sewn from one connected component (662 triangles) of a real
MMD-converted train skin STL (`mmd_kiha10_skin_open.stl`); originally surfaced by OCCTReconstruct's
`--assembly-from-bundle` on a kiha40 reference model.

```bash
clang++ -std=c++17 -ObjC++ -w -g -O0 \
  -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -L Libraries/OCCT.xcframework/macos-arm64 \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/348-unify-null-pcurve/repro_348.mm -o /tmp/repro_348
DYLD_LIBRARY_PATH=Libraries/OCCT.xcframework/macos-arm64 /tmp/repro_348
```

Crashes deterministically (SIGSEGV, `IntUnifyFaces` + 42608, address 0) against stock OCCT 8.0.0p1 +
patches 0001-0012 (v1.15.7); survives with patch 0013 applied.

The same fixture backs the Swift regression test
`Tests/OCCTStressTests/StressNullInvalidTests.swift`'s
`unifySameDomainOnMeshSewnSolidWithMissingPCurve` (copy at
`Tests/OCCTStressTests/Fixtures/unify-crash-mmd-kiha10-body5.brep`).

## Upstream

Filed as Open-Cascade-SAS/OCCT#TBD (repro) / #TBD (fix, this patch).
