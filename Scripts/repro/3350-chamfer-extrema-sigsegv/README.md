# #3350: chamfer SIGSEGV on 12 of 36 edges of the OCCT#1576 model

OCCT#1576 ("Crash on chamfer on complex shape", FreeCAD#21369). Nothing here is posted upstream.

## Cause

`BRepFilletAPI_MakeChamfer` at distance 1 on edge 14 or 16 to 26 of the reporter's model dies with
SIGSEGV in `Extrema_GGExtPC::Perform`, under `BRepBlend_Walking::CorrectExtremityOnOneRst`
(`results/backtrace-edge14.txt`). Printing at each stage (`instrument.diff`, override-linked, see
below) gives the origin (`results/instrumented-edge14.txt`):

```
EXT cos=1 sin=0 dis1=1 dis2=1 d1plus=inf d2plus=inf first1=1 first2=1
PES before first=-inf last=459.527
PSOES wf=-inf wl=459.527 periodic=0 spineFirst=-inf spineLast=459.527 nbed=12
WALK Perform Pdep=12.8451 Pmax=-inf MaxStep=1.9147 Tol3d=0.0001 TolGuide=0.0001 Fleche=inf
CORR idx=1 U=69.8852 V=15.1952 param=0.80278 P=(70.8727,15.7654,49.0099) hguide first=-inf last=inf
```

1. `ExtentSpineOnCommonFace` (`ChFi3d_ChBuilder.cxx`, from `ExtentTwoCorner`) extends the two chamfer
   spines that meet at a vertex by `dis / tga`, `tga = sinalpha / (cosalpha + dis2 / dis1)`. Two spine
   tangents at the vertex are parallel (`cos = 1`, `sin = 0`), so `tga = 0` and the extension is
   `+inf`; `if (d1plus > 0.)` accepts it and `Spine->SetFirstParameter(-inf)` is called.
2. The ElSpine range `(-inf, +inf)` becomes `wf`, `wl` in `PerformSetOfSurfOnElSpine`, and
   `BRepBlend_Walking::Perform` is called with `Pmax = -inf` and `Fleche = inf`.
3. `CorrectExtremityOnOneRst` builds `Extrema_ExtPC` on that ElSpine with a NaN point, and
   `Extrema_GGExtPC::Perform` reads out of range.

## Fix and why there

Carried patch `0065`, three changes in `src/ModelingAlgorithms/TKFillet/`:

1. `ExtentSpineOnCommonFace`: a non-finite `d1plus` or `d2plus` is no extension (the origin).
2. `BRepBlend_Walking::Perform` returns `done = false` when the start parameter, end parameter or
   `Fleche` is not finite. Every caller tests `IsDone()` straight after.
3. `BRepFilletAPI_MakeChamfer::Build` reports a result that is not a valid solid (or does not become
   valid under the `SameParameter` pass) as not done, as `BRepFilletAPI_MakeFillet::Build` does in
   the fillet series.

Change 1 alone fixes the crashes and also turns edges 1 to 12, which the pinned kernel declines
because the infinite range makes the walk fail, into done chamfers that BRepCheck rejects (volume
-754972). Change 3 is what refuses them, and edge 15 (volume -775000, on the pinned kernel too).
Change 3 alone leaves the crash. Either of 1 and 2 with 3 declines all 36 edges of this model.

## Measurement

`results/edges-d1.txt`: d = 1, one edge at a time, raw `BRepFilletAPI_MakeChamfer` set up as DRAW's
`chamf` is (`../fillet-open-set/dprobe.cxx`), the pinned kernel (`v4.0.0-kernel.6`) and four
override-linked variants, each with a different part removed.

`results/sweep-r1.0-base-vs-patched.txt` and `results/sweep-r0.5-base-vs-patched.txt`:
`../fillet-open-set/sweep-edges.py` over every reproducer model of that set, fillet and chamfer,
every edge, base against all three changes. Only `chamf` groups change, and in each the change is
`done-invalid` to `declined` (12 crashes to declined for 1576); the `valid` and `valid-bopfaulty`
counts are equal on both sides in all 36 groups at both radii.

Swift side (`ChamferParallelSpineTangentTests`, same build, archive members swapped): validity
refusal alone fails the test (child ends by signal 11); finite extension with validity, walker
guard with validity, walker guard with finite extension, and all three pass. The validity part is
not observable from Swift because the bridge already refuses invalid blend results (#3200).

## Reproduce

```bash
Scripts/repro/fillet-open-set/fetch-attachments.sh attachments           # 1576/model.brep
Scripts/repro/fillet-open-set/build-probe.sh <OCCT.xcframework>/macos-arm64 probes
probes/dprobe attachments/1576/model.brep chamf 1:14                     # SIGSEGV (exit 139)
```

`backtrace-handler.cxx` is a constructor that installs a SIGSEGV handler printing
`backtrace_symbols_fd`, linked into the probe because `lldb` cannot attach here. `instrument.diff`
is applied to copies of three `.cxx` files of the pinned tree and compiled into the probe ahead
of the library, so the linker prefers them to the archive members.
