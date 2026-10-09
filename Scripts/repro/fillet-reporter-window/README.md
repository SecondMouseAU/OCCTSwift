# Reporter model, radius window around 1.5 (OCCT#1568, OCCTSwift#2881)

Investigation only. No kernel patch: see the findings in the report that accompanied this branch.

| file | what it is |
| --- | --- |
| `model.brep` | the reporter's model (copy of `../occt1568-fillet-opposite-edge/model.brep`) |
| `wprobe.cxx` | one edge, one radius, one process; prints status, BRepCheck, free edges, volume, mesh |
| `sweep.py` | dense radius sweep and all-edge sweep; outputs in `results/` (k4 = v4.0.0-kernel.4, k5 = kernel.5; draw = DRAW parameters, def = bridge defaults) |
| `faces.cxx`, `geom1568.cxx`, `diag.cxx` | model dump (faces, edges, tolerances), geometry at an edge, where a done result is invalid |
| `instrument.py` | adds StartSol / path-failure traces to a copy of `ChFi3d_Builder_2.cxx`; link the object ahead of the kernel |
| `mini.cxx`, `corner.cxx` | attempted small reductions; neither reaches the 0054 branch (see report) |
| `meshdump.cxx`, `render.py`, `review/` | renders (the tessellation of this model is coarse: treat them as an outcome map, not as geometry) |

Key result: the failing window is [1.4983, 1.5018], not a point; inside it the pinned kernel returns
IsDone() false, a SIGSEGV (kernel.4) or a done-but-invalid solid missing about 26000 mm3.
