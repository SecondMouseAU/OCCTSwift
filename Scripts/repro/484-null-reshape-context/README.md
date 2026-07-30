# OCCTSwift#484 reproducer — null `ShapeBuild_ReShape` context SIGSEGVs in `ShapeFix_ComposeShell` / `ShapeUpgrade_WireDivide`

Standalone, deterministic reproducers for two uncatchable SIGSEGVs in OCCT's shape-healing family,
found while auditing every `ShapeFix_Face` call site in the bridge for #484. Same defect class as
[#317](https://github.com/SecondMouseAU/OCCTSwift/issues/317) (`Scripts/patches/0005-*`), in two
classes that had never been patched or filed upstream.

Filed upstream as [Open-Cascade-SAS/OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409)
(repro) / [OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410) (fix).

No fixture file is needed: a plain 4-edge planar square face crashes both classes 100% of the time.

## Root cause

`ShapeFix_Root::Context()` returns `myContext`, a `Handle(ShapeBuild_ReShape)` that the base
constructor leaves **null**. Only an explicit `SetContext()` call ever fills it, and it is optional —
nothing in either class' documentation, `Init()` signature or `Perform()` contract requires one.

Three public entry points dereference it unconditionally:

| Entry point | First unguarded dereference |
|---|---|
| `ShapeUpgrade_WireDivide::Perform()` | `ShapeUpgrade_WireDivide.cxx:323` — `Context()->Apply(ItW.Value(), TopAbs_SHAPE)`, the first statement of the per-edge loop |
| `ShapeFix_ComposeShell::Perform()` | `ShapeFix_ComposeShell.cxx:506`, via `LoadWires()` — `Context()->Apply(iw.Value())` |
| `ShapeFix_ComposeShell::SplitEdges()` | same `LoadWires()` dereference |

So `Init(...)` followed by `Perform()` — the usage the public API invites — is an immediate
null-handle dereference: Address 0, `EXC_BAD_ACCESS`, uncatchable in-process (a `catch (...)` on the
bridge side cannot trap an OS signal).

**Why this hid for so long.** Both classes are, in-kernel, only ever driven by
`ShapeUpgrade_FaceDivide::Perform()`, which opens with

```cpp
if (Context().IsNull())
{
  SetContext(new ShapeBuild_ReShape);
}
```

and then hands its context down — to the compose shell at `ShapeUpgrade_FaceDivide.cxx:185`, to the
wire divide at `:238`. Reached that way, neither class ever sees a null context, so OCCT's own test
suite never exercises the crash. Reached directly, both crash on the first call.

Nine other classes in the same package already carry that self-creating guard:
`ShapeFix_Shape::Init`, `ShapeFix_Shell::Perform`, `ShapeFix_Solid::Perform`,
`ShapeFix_FixSmallFace::Init`, `ShapeFix_SplitCommonVertex::Init`, `ShapeFix_Wireframe` (both entry
points), `ShapeFix_Wire::FixGap3d`/`FixGap2d`, `ShapeFix_Face::FixMissingSeam` and
`ShapeUpgrade_ShapeDivide::Perform`. `ShapeFix_ComposeShell` and `ShapeUpgrade_WireDivide` are the
odd ones out.

## Fix

`Scripts/patches/0017-null-reshape-context-ComposeShell-WireDivide-484.patch`: add that same guard to
the three unguarded public entry points. `ShapeFix_ComposeShell`'s other context-dereferencing
methods (`LoadWires`, `SplitWire`, `SplitByLine`, `MakeFacesOnPatch`, `DispatchWires`) are all
reached through `Perform()` or `SplitEdges()`, so guarding those two covers them — and they are
`const`, so they could not create a context themselves.

## Reproducers

### `repro_484_crash.mm` — the crash

Runs each case in a `fork()`ed child so one SIGSEGV does not hide the others, and prints the
terminating signal per case. Also covers `ShapeFix_Face::Perform` and the individual `ShapeFix_Wire`
fixes with no context, to bound the blast radius (both are safe — see "Also checked" below).

```bash
clang++ -std=c++17 -ObjC++ -w -g \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/484-null-reshape-context/repro_484_crash.mm -o /tmp/repro_484_crash
/tmp/repro_484_crash
```

Stock `V8_0_0_p1` + patches `0001`–`0016`:

```
ShapeFix_Face::Perform / intersecting wires    ctx=NO  : Perform=1 resultNull=0
ShapeFix_Face::Perform / intersecting wires    ctx=yes : Perform=1 resultNull=0
ShapeFix_Face::FixIntersectingWires direct     ctx=NO  : FixIntersectingWires=0
ShapeFix_Face::FixIntersectingWires direct     ctx=yes : FixIntersectingWires=1
ShapeUpgrade_WireDivide::Perform               ctx=NO  :   *** KILLED BY SIGNAL 11 ***
ShapeUpgrade_WireDivide::Perform               ctx=yes : Perform done, wireNull=0
ShapeFix_ComposeShell::Perform                 ctx=NO  :   *** KILLED BY SIGNAL 11 ***
ShapeFix_ComposeShell::Perform                 ctx=yes : Perform=1 resultNull=0
ShapeFix_Wire individual fixes                 ctx=NO  : reorder=0 conn=0 curves=0 ...
ShapeFix_Wire individual fixes                 ctx=yes : reorder=0 conn=0 curves=0 ...
```

With patch `0017` both `ctx=NO` lines complete normally, matching their `ctx=yes` siblings.

### `repro_484_equivalence.mm` — no behaviour change on the working path

Prints a structural fingerprint (shape type, face/wire/edge/vertex counts, and a hash of the
`BRepTools::Write` dump) of each result, for a planar and an unbounded-cylindrical face.

Verified via the override-link technique (see `Scripts/patches/README.md`'s `#0001` entry): compile
the two patched TUs standalone and link them *before* `libOCCT-macos.a`, so no full rebuild is
needed.

```bash
SRC=Libraries/occt-src/src/ModelingAlgorithms/TKShHealing
clang++ -std=c++17 -O2 -w -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -c $SRC/ShapeFix/ShapeFix_ComposeShell.cxx -o /tmp/cs.o
clang++ -std=c++17 -O2 -w -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -c $SRC/ShapeUpgrade/ShapeUpgrade_WireDivide.cxx -o /tmp/wd.o
clang++ -std=c++17 -ObjC++ -w -g -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  Scripts/repro/484-null-reshape-context/repro_484_equivalence.mm /tmp/cs.o /tmp/wd.o \
  -L Libraries/OCCT.xcframework/macos-arm64 -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ -o /tmp/repro_484_equiv_patched
MMGT_OPT=0 /tmp/repro_484_equiv_patched
```

Result: the four `ctx=yes` fingerprints are **byte-identical** stock vs patched (`brep=` hashes and
all counts match), and the four `ctx=NO` fingerprints — which SIGSEGV on stock — are identical to
their `ctx=yes` counterparts after the patch. The guard only fires when there was no context, and in
that case it produces exactly what an explicitly-provided context produces.

## Also checked (not defects)

Both were candidates in the same audit and came back clean, so the patch deliberately does not touch
them:

- **`ShapeFix_Face::Perform()` with no context** — safe. `FixPeriodicDegenerated` was the #317 site
  and is already guarded by patch `0005`; `FixMissingSeam` self-creates a context;
  `FixIntersectingWires` bails out early (`ShapeFix_IntersectionTool::FixIntersectingWires` opens
  with `if (myContext.IsNull() || face.IsNull()) return false;`). It does **silently skip** fixes
  that need a context, which is a correctness difference, not a crash — see #484's bridge-side fix
  to `OCCTFaceFix`.
- **`ShapeFix_Wire`'s individual fixes with no context** — safe. All 14 `UpdateWire()` call sites
  guard, `FixGap3d`/`FixGap2d` self-create a context, and `FixEdgeCurves`' singularity-split branch
  (`ShapeFix_Wire.cxx:817`) sits inside an `if (!Context().IsNull())` at `:676`.
- **`ShapeUpgrade_RemoveInternalWires`** — safe. Both constructors call
  `SetContext(new ShapeBuild_ReShape)` before anything else.
- **`ShapeFix_Edge`** — safe. All 11 context dereferences are guarded.
