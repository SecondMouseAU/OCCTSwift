# Fillets that meet exactly: forum report against patch 0054 (OCCT#1568)

Question: is "FreeCAD fails when two fillets meet exactly, use 1.9999" the bug patch 0054 fixes
(#2881, #3072, OCCT#1568)? Answer: no. Same family of input, different function, different failure.
Investigation only; nothing here patches the kernel.

Kernels: `v4.0.0-kernel.4` (no 0054) and `v4.0.0-kernel.5` (0054) release assets, downloaded to a
scratch directory, linked by a standalone probe. One process per case, 30 to 120 s limit.

| file | what it is |
| --- | --- |
| `fprobe.cxx` | raw `BRepFilletAPI_MakeFillet` on a corner-origin box, edges by midpoint; modes `add`, `add2` (FreeCAD's `Add(r1, r2, e)`), `seq` |
| `sweep.py` | the radius sweep around the critical radius c (results/sweep-box-cases.tsv, kernel.4, kernel.5, and `Shape.filleted` through a SwiftPM probe) |
| `sweep_trace.py`, `instrument/*-trace.diff` | which ChFi3d function reports each failure; the diffs apply to a clean V8_0_1 tree, override-linked ahead of the kernel |
| `search_obstacle.py` | every ordered pair and triple of box edges, equal radii: does anything reach StartSol's obstacle branch (none of 8712 do) |
| `geom1568.cxx`, `window1568.py` | the reporter's model: geometry at edge 13, and the radius window |
| `meshdump.cxx`, `render.py` | the renders (see the review directory's index.md) |

Build line (per kernel): `clang++ -std=c++17 -w -O1 -I$XC/Headers fprobe.cxx -L$XC -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++`
with `XC=<kernel>/OCCT.xcframework/macos-arm64`.
