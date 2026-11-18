# #3526: `Shape.edges()` rebuilt the indexed sub-shape map once per edge

`Shape.edges()` was `(0..<edgeCount).map { edge(at: $0) }`. Every `edge(at:)` goes through
`OCCTShapeGetEdgeAtIndex` and `occtSubShapeAt`, which builds a whole `TopTools_IndexedMapOfShape`
with `TopExp::MapShapes` to read one entry and throws it away. E edges therefore cost E maps of E
entries each: quadratic. `faces()` and `vertices()` map once and were three to four orders of
magnitude faster on the same shape.

The harness is `Scripts/repro/harnesses/EdgesEnumerationTiming.swift`:

```
swift build -c release --product Harnesses
.build/release/Harnesses 3526-edges-enumeration      # or: swift run Harnesses 3526-edges-enumeration
```

The raw output of all four runs (before and after, release and debug) is
[`measured-output.txt`](measured-output.txt). It is not a wasm harness: it times against a wall
clock, so `Package.swift` excludes it for WASI like the other timing harnesses.

## What was measured, and on what

The issue's shape (the vg-cad 2120 whole-assembly BREP: 1,609 faces, 3,883 edges, 2,501 vertices) is
not in the repo, so the harness builds comparable ones:

* **Compounds of translated boxes** of 81, 162, 324 and 648 boxes (972 to 7,776 edges). The 324-box
  row, 3,888 edges / 1,944 faces / 2,592 vertices, is the closest match to the issue's counts. The
  four sizes are there to show the growth rate.
* **1,000 cylinders** (3,000 edges): each has a seam edge two faces share.
* **A plate drilled by one boolean** (1,212 edges, 406 faces): one solid whose edges are shared
  between faces, the shape of a real part and not a compound of disjoint bodies.

Apple M4, 10 cores, `main` at `69105e8ec`, the pinned kernel asset. **The machine was not quiet**:
other agents' builds held the load average between 40 and 245 for the whole session, so the
absolute figures carry that noise (the same code measured 4.9 s and 8.7 s on the 7,776-edge row in
two runs). The growth rate and the ratios are the finding, and each cell is the best of several
runs.

## Result, 3,888 edges (324 boxes), `edges()` against `faces()` and `vertices()`

| build | edges() before | edges() after | faces() | vertices() | before / after |
|---|---|---|---|---|---|
| release | 1.649 s | 0.87 ms | 0.40 ms | 1.73 ms | about 1,900x |
| debug | 1.688 s | 2.74 ms | 1.27 ms | 2.27 ms | about 615x |

The debug "before" figure matches the issue's 1.37 s on 3,883 edges. The C++ is optimised either
way, so release changes only the Swift side and the two builds agree to within noise before the fix.

## The growth rate is the diagnosis (release, boxes)

| edges | edges() before | edges() after |
|---|---|---|
| 972 | 96 ms | 0.29 ms |
| 1,944 | 414 ms | 0.58 ms |
| 3,888 | 1.65 s | 0.87 ms |
| 7,776 | 4.9 s | 1.80 ms |

Before the fix each doubling of the edge count costs roughly four times as much (96 ms, 414 ms,
1.65 s): quadratic. After it each doubling costs about twice as much: linear, and a small constant
multiple of `faces()` (1.3x to 4.4x across every row, the extra being one heap object per edge).

## Other shapes (release)

| shape | edges | before | after |
|---|---|---|---|
| 1,000 cylinders | 3,000 | 987 ms | 0.69 ms |
| drilled plate | 1,212 | 139 ms | 0.32 ms |

## The sibling, fixed in the same PR (#3527)

`Shape.measure()` (`ShapeMeasurements.swift`) read each edge length through `edge(at:)` in a loop,
the identical defect in a different function, and now reads them off one `edges()` pass. The
harness times it on the 324-box shape (3,888 edges), release:

| | `measure()` | the edge-length loop alone | the lengths from `edges()` |
|---|---|---|---|
| before, three runs | 1.58 s, 2.81 s, 3.51 s | 1.38 s, 2.52 s, 1.92 s | 1.2 ms |
| after | 0.40 s | 3.15 s (the old loop, still run by the harness) | 1.6 ms |

What is left in `measure()` after the change is the face work (areas, centroids and perimeters of
1,944 faces), about 0.4 s. The "before" figures are three separate runs on a machine whose load
swung between 19 and 150, which is why they span 1.6 s to 3.5 s; within each run the loop was 55 to
90 percent of `measure()` (the low end is the run whose `measure()` hit a loaded moment), and that
share, not the absolute figure, is the reading. The raw output
is in [`measured-output.txt`](measured-output.txt).
