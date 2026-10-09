# #3105: patch 0058, BRepOffsetAPI_MiddlePath::Build carries a vertex path forward

`Scripts/patches/0058-...-3105.patch` and its writeup in `Scripts/patches/README.md` are the result;
this directory is the evidence. History: round 1 found the 116 crashing pairs and a first 0058 that
refused them; the user's review said the paths `Build()` traces are valid and should be computed, and the
patch was rewritten to compute them (round 2, this directory).

## Result (all 573 pairs of 16 solids, one process per pair, `summary-*.txt`, `cmp-output.txt`)

| | abort | run on | throw | answers a path | answers not done |
|---|---|---|---|---|---|
| pinned kernel (`scan-before.txt`) | 423 | 0 | 89 | 42 | 19 |
| with 0058 (`scan-after.txt`) | 0 | 0 | 56 | 124 | 393 |

The 116 aborts that share no vertex: 60 of the 91 in G1 and all 21 in G2 now answer a path (81), the
other 35 answer not done, G3 (4 octahedron pairs) is among them. The 42 pairs that answered before answer
the same. `groups116.json` is the round-1 classification of the 116; `sites-before.txt` their faulting
lines (`fault-sites.py`, `dwarfdump`).

## Validation of every answered path

`validate.py` over `gather2.py`'s output: `validate-out.txt` (pass counts per group and every failure),
`verdicts.json` (per pair: sensible or doubtful, and why). 81 new paths: all valid, connected, ending at the
section centroids and in their planes, between the chord and the longest guide, deterministic over three
runs; 14 are doubtful (loops, a crossing, a spline outside the bounding box). `tri 0/0` (the same face)
answers an invalid wire; the bridge refuses it.

## Ablations

`mkabl.py` writes the final file with one change removed; `ablation-summary.txt` is the scan of each:
the carried vertex (72 pairs), the vertex's parameters (81), the face relaxation (46 aborts), the section
edge check (55 throws), the tangent flag (12), the insertion check (5 aborts) and the level bound (every
sweep that cannot reach the end runs on). Four checks that changed nothing were dropped.
`guards-final.txt` lists every pair that answers not done by the return that fires.

## Swift test and images

`Tests/OCCTModelingTests/Sweeps/Issue3105MiddlePathKernelTests.swift`, gated on `OCCTSWIFT_LOCAL=1`;
`swift-test-unpatched.txt` (aborts), `swift-test-patched.txt`. Images and the round-2 index are in
`review/` (`render2.py` draws them with matplotlib; `mkret.py` builds the instrumented copy of the
patched file that prints the traced paths and the return that fired, for the images and
`guards-final.txt` only).

## Build lines

`run.sh <clean 44-patch V8_0_1 tree> <work dir>` runs the scan and the comparison. The probe and the file
under test are compiled with the release macros (`-DNo_Exception -DNDEBUG`), or the checked inline
`TopoDS::Edge` of the probe's own TU wins at link time and the fault turns into an exception. The Swift
proof swaps that one member into a copy of the xcframework (`ar r`, `ranlib`), compiled `-O2
-mmacosx-version-min=12.0`; extract the old member into a separate directory (an `ar x` into the
directory holding the new object overwrites it). `CHECK=1` makes the probe print the checks of a
returned path, `THROWTRACE` via `throwtrace.cpp` (`DYLD_INSERT_LIBRARIES`) the stack of every throw.
Not done: the three-slice rebuild a repin needs; only macOS was built.
