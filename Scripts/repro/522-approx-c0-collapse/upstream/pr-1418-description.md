**Status: never applied.** A rewritten description for
[OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418), drafted 2026-08-07 to lead with the
regression provenance instead of the behavioural writeup. It was never pushed to the PR, and #1418
merged on 2026-08-10 with its original description. Kept as the record of what the provenance-first
framing looked like; the provenance itself is in [`../README.md`](../README.md) under "Upstream
provenance (#756)". See [`reply-to-gkv311.md`](reply-to-gkv311.md) beside it for the rest of what
was staged and not sent.

---

# Modeling Data - Fix AdvApp2Var Jacobi maxima written to the wrong workspace slot

## This is a regression, and the mechanism is a single missed decrement

`3016a390713d2e893f4bfa797882b9f0266840e1` (2021-07-28, `0032495: Coding rules - eliminate
CLang UndefinedBehaviorSanitizer warnings`) rebased `mma2ce1_`'s workspace offsets from an
absolute base (`ipt1 = iofwr`, each later offset built on the previous one plus the raw
pointer) to a relative one (`ipt1 = isz1`, each offset built from a new `wrkar_off` base). That
rebase drops what used to be `ipt1` (the base itself, folded into `wrkar_off`) and shifts every
remaining offset name down by one: old `ipt2` becomes new `ipt1`, old `ipt3` becomes new `ipt2`,
and so on through old `ipt7` becoming new `ipt6`. The decrement shows on every other call site
the commit touches, for instance the neighbouring `mmapptt_` calls:

```c
// before
AdvApp2Var_ApproxF2var::mmapptt_(ndjacu, nbpntu, iordru, &wrkar[ipt1], iercod);
AdvApp2Var_ApproxF2var::mmapptt_(ndjacv, nbpntv, iordrv, &wrkar[ipt2], iercod);
// after
AdvApp2Var_ApproxF2var::mmapptt_(ndjacu, nbpntu, iordru, wrkar_off, iercod);
AdvApp2Var_ApproxF2var::mmapptt_(ndjacv, nbpntv, iordrv, &wrkar_off[ipt1], iercod);
```

Applied consistently, the two `mma2jmx_` calls a few lines down (old `ipt5` for U, old `ipt6`
for V, two distinct slots) should have become:

```c
AdvApp2Var_ApproxF2var::mma2jmx_(ndjacu, iordru, &wrkar_off[ipt4]);   // old ipt5 -> new ipt4
AdvApp2Var_ApproxF2var::mma2jmx_(ndjacv, iordrv, &wrkar_off[ipt5]);   // old ipt6 -> new ipt5
```

What the commit actually produced was:

```c
AdvApp2Var_ApproxF2var::mma2jmx_(ndjacu, iordru, &wrkar_off[ipt5]);   // NOT decremented
AdvApp2Var_ApproxF2var::mma2jmx_(ndjacv, iordrv, &wrkar_off[ipt5]);   // decremented correctly
```

The V line moved, the U line did not, and both now write to the slot the V line already owns.
`XMAXJU` (the maxima of the U Jacobi polynomials) is never written; `mma2ce2_` still reads it at
`ipt4`, where the allocation left whatever was there, in practice zeros.

**Our patch is not a redesign, it is the missed decrement, and OCCT 7.5.x computed this
correctly.** Confirmed directly against the two release tags either side of the commit:

```
$ git show V7_5_0:src/AdvApp2Var/AdvApp2Var_ApproxF2var.cxx | grep mma2jmx_
    AdvApp2Var_ApproxF2var::mma2jmx_(ndjacu, iordru, &wrkar[ipt5]);
    AdvApp2Var_ApproxF2var::mma2jmx_(ndjacv, iordrv, &wrkar[ipt6]);

$ git show V7_6_0:src/AdvApp2Var/AdvApp2Var_ApproxF2var.cxx | grep mma2jmx_
    AdvApp2Var_ApproxF2var::mma2jmx_(ndjacu, iordru, &wrkar_off[ipt5]);
    AdvApp2Var_ApproxF2var::mma2jmx_(ndjacv, iordrv, &wrkar_off[ipt5]);
```

`V7_5_0` (released 2020-11-02) has two distinct slots. `V7_6_0` (released 2021-11-01, the first
release to include the commit) already has both calls on the same slot. Current `master` is
unchanged from `V7_6_0` at this site. The regression is confirmed as of OCCT 7.6.0, not merely
attributed to a commit somewhere in that range.

## What the wrong slot does

`mma2ce2_`'s entire truncation-error model is

```
error += |PATJAC(i,j)| * XMAXJU(i - 2*(IORDRU+1)) * XMAXJV(j - 2*(IORDRV+1))
```

A zero `XMAXJU` zeroes every term. Two consequences, both silent:

1. **The approximation error of a patch is reported as exactly 0**, no matter what the
   discarded Jacobi coefficients are, so the tolerance test in `mma2ce2_`
   (`if (errmax[nd] > epsapr[nd])`) can never fail on the patch interior.
   `AdvApp2Var_ApproxAFunc2Var::MaxError` then reflects only the boundary-iso errors
   `AdvApp2Var_Patch::AddErrors` adds afterwards.
2. **`mma2er2_`, asked for the lowest degree whose truncation error still fits the tolerance,
   always answers `NDMINU`**, the floor derived from the constraint order and the neighbouring
   isos, because every candidate scores 0. Where that floor is low, the fit collapses onto it
   and the caller is handed a surface nowhere near its input, with `IsDone()` true.

## Reproducer

`GeomConvert_ApproxSurface` at `GeomAbs_C0` is where both surface. C0 gives `IORDRU = 0`, and a
full sphere's V-boundary isos degenerate to its two poles, one coefficient each, so `NDMINU`
is 1.

```cpp
gp_Ax3 ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(ax3, 10.0);
GeomConvert_ApproxSurface a(sphere, 1e-3, GeomAbs_C0, GeomAbs_C0, 8, 8, 100, 0);
Handle(Geom_BSplineSurface) bs = a.Surface();
```

Measured against the pinned kernel build, before and after this patch:

```
before:  isDone=1 maxError=0.000106971  uDeg=1 vDeg=7 uPoles=2 vPoles=8
         real max deviation over the source domain: 19.9999  (at u=3.14159 v=0)
after:   isDone=1 maxError=0.000261108  uDeg=7 vDeg=7 uPoles=15 vPoles=8
         real max deviation over the source domain: 0.000120909  (at u=1.5708 v=0)
```

Two poles at degree 1 across the sphere's full `[0, 2*pi]` of longitude is a straight line
through the sphere, deviating by its own diameter of 20, reported as `1.07e-4` with the
tolerance met.

A bicubic Bezier at C0/C0 collapses to a 2x2 bilinear patch reporting `4.08e-15`, unchanged from
tolerance `1e-1` down to `1e-7`, because the requested tolerance is compared against a number
that is always zero. After the fix it is reproduced exactly at degree 3x3 at every one of those
tolerances.

C1 and C2 hide the collapse (their `NDMINU` floor is already 8) but not the misreported error,
which was never specific to C0. Degree collapse per se is not the defect either: a cylinder
trimmed in V legitimately fits at `vDegree = 1`, and does so before and after.

## Measurements

Sweep of 98 requests, 7 surface families (sphere, V-trimmed sphere, torus, trimmed cylinder,
trimmed cone, surface of revolution, 4x4 Bezier) by all 9 `(uContinuity, vContinuity)`
combinations of C0/C1/C2 at tolerance `1e-3`, plus C0/C0 across five tolerances, comparing the
reported `MaxError()` against the real maximum deviation over a 21x21 grid of the source domain:

| | before | after |
|---|---|---|
| real deviation > 10x reported `MaxError` | 12 of 98 | 0 of 98 |
| real deviation > reported `MaxError` at all | 17 of 98 | 1 of 98 |
| worst ratio of real deviation to reported error | 3.4e13 | 1.0018 |

The one row still over the line after the fix is the Bezier at C0/C2, reporting `9.95221e-15`
against a measured `9.96978e-15`, a surface reproduced exactly, disagreeing at the last bit.

Reported errors rise slightly everywhere, which is the interior contribution being counted for
the first time. Degrees rise only where the collapse was happening.

Dumping the buffer directly (`-O0` single-TU override-link) shows the mechanism:

```
before:  xmaxju[8] = 0 0 0 0 0 0 0 0
after:   xmaxju[8] = 0.9682 0.986 1.078 1.173 1.265 1.352 1.434 1.513
```

## Draw regression test

Added `tests/bugs/moddata_3/bug1418`, following the `approxsurf` reproducer from review, with
the degree assertion completed and measured rather than assumed:

```tcl
sphere s 10
approxsurf r s 1.e-3 0 0 8 8 100
```

reports `udeg = 7`, `vdeg = 7` after the fix, and `udeg = 1`, `vdeg = 7` on stock. The proposed
degrees of 7/7 are correct, confirmed by measurement rather than assumed from the fix
description.

The commented assertion block in the reviewed script does not run as written, for two
independent reasons. `dumpjson` is not a registered Draw command anywhere in this tree; the
closest equivalent, `bounding -dumpJson`, is a flag on specific commands rather than a
standalone command taking an object name. And `Standard_Dump::DumpFieldToName` strips the `my`
prefix from a field name but does not change its case, so `Geom_BSplineSurface::DumpJson`'s
keys for `myUDeg`/`myVDeg` are `"UDeg"`/`"VDeg"`, not `"udeg"`/`"vdeg"`. Either issue alone
would leave the `udeg`/`vdeg` Tcl variables unset and turn the check into an unrelated Tcl
error rather than a check of the degree.

The test instead captures `dump r`'s classic, already-working textual output via `dlog`, and
reads the `Degrees :` line `GeomTools_SurfaceSet::PrintSurface` already writes for a
`Geom_BSplineSurface`, the same idiom `tests/bugs/modalg_7/bug23942` already uses for the same
purpose:

```tcl
decho off
dlog reset
dlog on
dump r
set info [dlog get]
dlog reset
dlog off
decho on
regexp {Degrees :([0-9]+) +([0-9]+)} ${info} full udeg vdeg
```

This PR does not have an internal bug id assigned. The test file is named for this PR's number
and should be renamed at merge time.

## Scope

`AdvApp2Var_Context`'s own two `mma2jmx_` calls, the only others in the tree, already write to
separate per-direction arrays and are unaffected.

`GeomConvert_ApproxSurface` is not a leaf. Live construction sites are
`GeomFill_Sweep.cxx:296`, `BRepOffset_Offset.cxx:1626`, `ShapeCustom_BSplineRestriction.cxx:852`,
`ShapeConstruct.cxx:265`, `ShapeUpgrade_UnifySameDomain.cxx:3629`, `GeomLib.cxx:1517` and
`GeomConvert_1.cxx:786`/`:960`; `ShapeCustom_ConvertToBSpline` reaches it through
`ShapeConstruct`, and `GeomPlate_MakeApprox` drives `AdvApp2Var_ApproxAFunc2Var` directly. (The
two remaining mentions of the class, `BRepFill_Sweep.cxx:1162` and `BRepFill_Filling.cxx:712`,
are both inside comment blocks.)

Most pass C1 or C2, where the collapse cannot happen, but the always-zero interior error
affected all of them. The healing paths reach C0 on purpose: `ShapeConstruct::ConvertSurfaceToBSpline`
and `ShapeCustom_BSplineRestriction` both loop the requested continuity down to 0 on failure,
then decide whether to accept the result with `anApprox.MaxError() <= tol`, i.e. against the
number that could not be exceeded, and `ShapeCustom_ConvertToBSpline` starts at `GeomAbs_C0` for
any offset surface (`ShapeCustom_ConvertToBSpline.cxx:148`, a 1999 workaround for a hang) before
handing off to the first of those.

Found while building surface-approximation parity tests in the OCCTSwift wrapper. Carried there
as patch `0019`; the file is byte-identical between `master` and the `V8_0_1` tag that project
pins, so this is the same change on both. Full writeup, both reproducers and the before/after
sweep transcripts:
https://github.com/SecondMouseAU/OCCTSwift/tree/main/Scripts/repro/522-approx-c0-collapse
