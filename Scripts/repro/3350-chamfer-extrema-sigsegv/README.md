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

Carried patch `0064` returns from `BRepBlend_Walking::Perform` with `done = false` when the start
parameter, end parameter or `Fleche` is not finite. Every caller tests `IsDone()` straight after.

Skipping the infinite extension at its origin (`sinalpha > tolesp` before computing `tga`) was tried
first and rejected: it also changes the 12 edges (1 to 12) that the pinned kernel declines into done
chamfers that BRepCheck rejects (volume -754972). The infinite range is what made those decline.

## Measurement

`results/edges-d1.txt`: d = 1, one edge at a time, raw `BRepFilletAPI_MakeChamfer` set up as DRAW's
`chamf` is (`../fillet-open-set/dprobe.cxx`), pinned kernel (`v4.0.0-kernel.6`) against the same
kernel with `BRepBlend_Walking.cxx` override-linked: 12 SIGSEGV become declined, the other 24 rows
are unchanged. ("declined" there includes the "no suitable edges" exceptions; the sweep below keeps
them apart.) Edge 15 stays a done chamfer that BRepCheck rejects with volume -775000, on `IR` too:
a separate defect.

`results/sweep-r1.0-base-vs-patched.txt`: `../fillet-open-set/sweep-edges.py` over every reproducer
model of that set, fillet and chamfer, every edge, radius 1.0, base against patched. One of the 36
(model, operation) groups differs: 1576 chamfer, `crash=12 declined=12 done-invalid=1
exception=11` becomes `declined=24 done-invalid=1 exception=11`. The `timeout` entries are the
sweep's 20 s limit under load and are the same set on both sides.

## Reproduce

```bash
Scripts/repro/fillet-open-set/fetch-attachments.sh attachments           # 1576/model.brep
Scripts/repro/fillet-open-set/build-probe.sh <OCCT.xcframework>/macos-arm64 probes
probes/dprobe attachments/1576/model.brep chamf 1:14                     # SIGSEGV (exit 139)
```

`backtrace-handler.cxx` is a constructor that installs a SIGSEGV handler printing
`backtrace_symbols_fd`, linked into the probe because `lldb` cannot attach here. `instrument.diff`
is applied to copies of the three `.cxx` files of the pinned tree and compiled into the probe ahead
of the library, so the linker prefers them to the archive members.
