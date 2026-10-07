# #3105: BRepOffsetAPI_MiddlePath faults the #3098 guard leaves open

Result: no exact, cheap precondition exists on the input, so no bridge guard ships. This directory
holds the evidence.

## Files

- `probe.mm`: the #3098 probe plus 11 more solids (`tri pent oct8 star ushape sqtube frustum torus
  bend elbow capsule`), a `count` mode, a `try/catch` around the pair run (a thrown exception exits 4
  instead of reading as a crash), and with `FEAT=1` a replay of `Build()`'s path phase through public
  OCCT pieces only (`ShapeUpgrade_UnifySameDomain`, `BRepTools_WireExplorer`, `TopExp` maps).
- `scan.py`: #3098's scan, extended with the new shapes. One process per pair.
- `scan-output.txt`: its output with `FEAT=1`, 573 pairs, against `v4.0.0-kernel.4`.
- `fault-sites.py`: groups the crashing pairs by the source line of the fault.

## Build lines

```
XC=.build/artifacts/*/OCCT/OCCT.xcframework      # after swift package resolve
clang++ -std=c++17 -ObjC++ -w -g -I$XC/macos-arm64/Headers -L$XC/macos-arm64 probe.mm -lOCCT-macos \
  -framework Foundation -framework AppKit -lz -lc++ -o probe
FEAT=1 python3 scan.py ./probe > scan-output.txt
# fault lines: compile the kernel source with the release macros and link it ahead of the archive
clang++ -std=c++17 -w -g -O0 -DNo_Exception -DNDEBUG -I$XC/macos-arm64/Headers -c \
  Libraries/occt-src/src/ModelingAlgorithms/TKOffset/BRepOffsetAPI/BRepOffsetAPI_MiddlePath.cxx -o mpr.o
clang++ -std=c++17 -ObjC++ -w -g -DNo_Exception -DNDEBUG -I$XC/macos-arm64/Headers -L$XC/macos-arm64 \
  probe.mm mpr.o -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ -o probe_r
python3 fault-sites.py ./probe_r scan-output.txt
```

The probe TU needs the same `-DNo_Exception -DNDEBUG` as `mpr.o`: otherwise the checked inline
`TopoDS::Edge` from the probe's own TU wins at link time and the fault turns into an exception.

## Where the remaining pairs fault

All in the section-building loop of `Build()` (`BRepOffsetAPI_MiddlePath.cxx`, from line 522), not in
the path phase. 116 pairs crash in the release-macro build:

| Line | Pairs | What |
|------|-------|------|
| 580, 584 | 91 | `myPaths(j - 1)(i).ShapeType()`: level `i` is past the end of a path (unchecked `NCollection_Sequence::operator()`), garbage read |
| 664, 668 | 20 | `TopoDS::Edge(myPaths(..)(i - 1))` cast of a bare vertex or an out-of-range element |
| 672, 706 | 5 | `BRep_Tool::CurveOnSurface(E1, theFace, ...)` with a null `theFace`: no face holds both `E1orE2` and `E12` (loop at 596-610) |

The #3098 fault at line 550 (the "end of initial shape" cast) is the same family and is already
refused for vertex-sharing sections.

37 more pairs throw a catchable `Standard_Failure` (`BRep_API: command not done` from
`BRepLib_MakeWire` in the constructor's `GetUnifiedWire`, or `Standard_NoSuchObject` from the maps);
the bridge's `catch (...)` already turns those into nil.

## Why no exact precondition

The section phase is driven by state that only exists while it runs: `ToInsertVertex`, the per-level
padding of short paths (547-558), and the face lookup per level. A pair crashes when that state walks
off a path or finds no face, which no property of the two input faces or of the replayed paths
decides. Measured, with the path phase replayed exactly (196 pairs that share no vertex and are not
the same face; 116 crash, 37 throw, 43 return normally):

| Replay feature group | crash | throw | normal |
|----------------------|-------|-------|--------|
| paths equal length, every path reaches an end vertex | 9 | 0 | 36 |
| paths equal length, some path misses the end set | 26 | 0 | 0 |
| paths unequal length, every path reaches an end vertex | 76 | 2 | 5 |
| paths unequal length, some path misses the end set | 5 | 10 | 0 |
| replay itself fails or constructor throws | 0 | 25 | 2 |

The best candidate, "admit only equal-length paths that all reach an end vertex", admits 9 crashing
pairs (octahedron faces 0/6, 1/7, 2/4, 3/5; L-shaped prism 0/3 and 2/5; U-shaped prism 0/4, 1/5, 3/7)
and refuses 5 pairs that return a result (pentagonal prism non-opposite sides 0/2, 0/3, 1/3, 1/4,
2/4). It misclassifies in both directions, so it is a heuristic and not shipped
(`okf/policies/measure-dont-assume.md`).

Replaying the section phase as well is a reimplementation of roughly 450 lines of
`BRepOffsetAPI_MiddlePath::Build` with checks added, with no way to prove it tracks the kernel's
copy. Not cheap, not shipped.

## OCCT's callers

`BRepTest_SweepCommands.cxx` (`middlepath`, line 1148) is the only caller and checks nothing but null,
so there is no caller convention to follow (`okf/policies/follow-occt-callers.md`).

## Remaining options

1. Kernel patch (not authored here; one patch PR at a time). In `Build()`: bounds-check every
   `myPaths(k)(i)` read at 550, 556, 566, 572, 580, 584, 664, 668 against `myPaths(k).Length()`; check
   `theFace.IsNull()` after the lookup at 596-610 and before 672/706; replace the unchecked
   `TopoDS::Edge` casts on path elements with a type test. On failure, leave the builder not done
   (`NotDone()` and return) or raise `Standard_ConstructionError`, which the bridge catches.
2. Document that `middlePath` is only valid for the two end faces of a pipe-like solid and that other
   pairs can abort the process. #3098's guard stays.
3. Child-process isolation (run `Build` in a forked process): exact but not appropriate for a library
   call; listed for completeness.
