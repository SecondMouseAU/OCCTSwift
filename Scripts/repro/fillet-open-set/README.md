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
| `offprobe.cxx`, `histprobe.cxx` | OCCT#1106 / #1107 (arc-join offset) and OCCT#1036 (IsDeleted) |
| `fetch-attachments.sh` | downloads the reporters' BREPs and the two PR data files; nothing of theirs is committed |
| `build-probe.sh` | builds the programs against a macOS slice of an `OCCT.xcframework` |
| `freecad-pool.txt` | the 116 open FreeCAD fillet and chamfer reports, 26 of them linked from OCCT |
| `results/` | the runs behind #3334: `kernel6.txt`, `ir.txt`, `sweep-r0.5.txt`, `programs-*.txt` |

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
