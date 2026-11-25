# Fillet and chamfer: the open set (#3334)

Evidence for the tracking issue SecondMouseAU/OCCTSwift#3334: every open upstream fillet, chamfer and blend report
(Open-Cascade-SAS/OCCT, with the FreeCAD reports linked from them) replayed through raw OCCT on the pinned kernel
(`v4.0.0-kernel.6`) and on upstream `IR`. Nothing here is posted upstream; the scripts only read public attachments.

| file | what |
| --- | --- |
| `dprobe.cxx` | replays DRAW's `blend` / `chamf` (same parameters), edges numbered as `explode s e`, prints `BUILD`, `STAGE` and a `RESULT` line |
| `run_cases.py` | the 43 reproducer cases of the open issues and PRs, one process each; says which stage a non-returning case is in |
| `sweep-edges.py` | every edge of every model at one radius, both kernels |
| `pr_ports.cxx` | the GTests of OCCT PR#1537 and PR#1592 as plain programs |
| `occt1371.cxx`, `occt1431.cxx`, `occt1494.cxx` | the issues' own programs (reporters' code, quoted for replay) |
| `volcheck.cxx` | the volume of a fillet result by fixed-order and adaptive `BRepGProp` and by a mesh sum, to tell a moved solid from a moved integral (the #3336 re-measure below) |
| `offprobe.cxx`, `histprobe.cxx` | OCCT#1106 / #1107 (arc-join offset) and OCCT#1036 (IsDeleted) |
| `fetch-attachments.sh` | downloads the reporters' BREPs and the two PR data files; nothing of theirs is committed |
| `build-probe.sh` | builds the programs against a macOS slice of an `OCCT.xcframework` |
| `freecad-pool.txt` | the 116 open FreeCAD fillet and chamfer reports, 26 of them linked from OCCT |
| `results/` | the runs behind #3334: `kernel6.txt`, `ir.txt`, `sweep-r0.5.txt`, `programs-*.txt`; and the #3336 re-measure on the 8.0.2 repin, `kernel9.txt` and `kernel-8.0.2-c1.txt` |

```bash
Scripts/repro/fillet-open-set/fetch-attachments.sh attachments
Scripts/repro/fillet-open-set/build-probe.sh <OCCT.xcframework>/macos-arm64 probes     # pinned kernel
python3 Scripts/repro/fillet-open-set/run_cases.py probes/dprobe attachments
```

For IR, compile `dprobe.cxx` against a shared build and pass that binary the same way. The `occt1371.cxx` program needs
`TColStd_*` / `TColgp_*` aliases for the 8.1 headers.

## What to read first

`Build` returns in 15 to 450 ms on every model here. The cases `run_cases.py` reports as `NO RETURN` are results on which
the next step (`BOPAlgo_ArgumentAnalyzer`, the check `bopcheck` runs) does not finish; the line says after which stage.
An earlier pass that timed the whole process read this as "Build hangs", which is wrong, and the stage output is what
corrects it.

## Re-measure on `kernel-8.0.2-c1` (#3336)

`results/kernel9.txt` and `results/kernel-8.0.2-c1.txt` are `run_cases.py` over the same 43 cases, the same
`dprobe.cxx` and the same attachments, built against the macOS slice of the `v4.0.0-kernel.9` asset (zip checksum
`13b866e1`) and of the `kernel-8.0.2-c1` asset that `Package.swift` pins (zip checksum `729937d3`, OCCT `V8_0_2` plus 51
carried patches), on one machine, one after the other. Read them with the `ms=` field removed.

- OCCT#1421's model (`example.brep`, r=1, edge 22) was `done=1 valid=0 bopfaults=139 solids=2 faces=14` and is now
  `done=0 faultyContours=1 faultyVertices=0`: refused, where the caller used to be handed a broken solid. That is upstream's
  form of the fix (OCCT#1708, `ChFi3d_Builder_2.cxx`) replacing carried patch `0054`.
- The other 42 cases agree on `done`, `valid`, `bopfaults`, `solids` and `faces`. Four of them report a different `vol` (the
  default fixed-order `BRepGProp`): OCCT#1570 r=29 (4.09725e6 to 6.58541e6), OCCT#1571 with two edges (5152.99 to 5155.76),
  OCCT#737 r=1 (1597.49 to 1631.58) and OCCT#1619 r=1.25 (2017.79 to 2018.23). Each of those results has `bopcheck` faults on both
  kernels (45, 70, 13 and 141 of them), and an independent mesh sum of the result's volume agrees between the two kernels to
  0.1 percent or better, so the solids agree to within that sum's accuracy and what moved is the fixed-order integral of a
  result that already carried faults. The mesh sum is `BRepMesh_IncrementalMesh` (deflection 0.01, 0.3 for OCCT#1570) and a
  signed-tetrahedron total over the result's triangulations.
  Linking only `ProjLib_CompProjectedCurve.cxx.o`, compiled from OCCT commit `be4e040483` (`V8_0_1` plus the #1741 hunk of that
  file) into the `kernel.9` archive, reproduces all four.
