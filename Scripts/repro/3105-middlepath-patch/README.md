# #3105: patch 0058, BRepOffsetAPI_MiddlePath::Build refuses a path it cannot sweep

`Scripts/patches/0058-...-3105.patch` and its writeup in `Scripts/patches/README.md` are the result;
this directory is the evidence. The earlier investigation (branch `fix/3105-middlepath-remainder`,
`Scripts/repro/3105-middlepath-remainder/`) found the 116 crashing pairs and ruled out a bridge guard;
its probe and scan are the starting point here.

## Result

Against `v4.0.0-kernel.5` (checksum verified), 573 pairs of faces of 16 solids, one process per pair:

| pairs | abort | throw | normal |
|---|---|---|---|
| all 573, pinned kernel (`scan-before.txt`) | 423 | 89 | 61 |
| all 573, with 0058 (`scan-after.txt`) | 14 | 89 | 470 |
| the 196 sharing no vertex, not the same face: pinned | 116 | 37 | 43 |
| the same 196 with 0058 | 0 | 37 | 159 |

The 42 pairs that return a path return the same one (edge count, length, centre of mass, six places).
The 14 that still abort share a vertex with the start face, which #3098's bridge guard refuses; they fault
at lines the patch does not touch. `cmp-output.txt` is `cmp.py`'s answer.

The 116, by faulting line of `Build()` (`sites-before.txt`, `fault-sites.py`) and by the new check that
catches them (`guards-after.txt`, `classify.py`):

| Lines | Pairs | Group | Check that refuses it |
|---|---|---|---|
| 580, 584 | 91 | G1, a path stops short of the end face | the pad reads an edge (45 at the first path, 46 at the second) |
| 664, 668 | 21 | G2, a path is a bare vertex with no edge before it | `IsEdgeAt` before the level `i - 1` cast |
| 672, 706 | 4 | G3, no face holds both edges | `theFace.IsNull()` |

(The 672/706 pair `ushape 4 7` is caught one step earlier by the G2 check: the cast before it is the first
invalid read, and the null face is only where garbage first faulted. Hence 21 and 4, where the line count
says 20 and 5.)

## Swift test

`Tests/OCCTModelingTests/Sweeps/Issue3105MiddlePathKernelTests.swift`, gated on `OCCTSWIFT_LOCAL=1`.
`swift-test-unpatched.txt`: SIGSEGV, exit 1, on a copy of the pinned xcframework. `swift-test-patched.txt`:
4 of 4 pass with the member swapped (`ar r`), and the nine #3098 tests still pass.

## Review images

`review/index.md` and the PNGs beside it. Regenerate with `gather.py` and `render.py` (matplotlib; the
renderer is a stand-in for the Viewport figure tool, which is a separate repo). `mkguard.py` and
`mkviz.py` build instrumented copies of the patched file that print the traced paths and which check
fired; they are for the images and the group table only and are not part of the patch.

## Build lines

`run.sh <clean 44-patch V8_0_1 tree> <work dir>` does all of it. The probe and the file under test are
compiled with the release macros (`-DNo_Exception -DNDEBUG`), or the checked inline `TopoDS::Edge` from the
probe's own TU wins at link time and the fault turns into an exception. The object is linked ahead of
`libOCCT-macos.a`, so `BRepOffsetAPI_MiddlePath::Build` comes from it and nothing else in the kernel is
replaced. The Swift proof swaps that one archive member into a copy of the xcframework
(`ar r` then `ranlib`), compiled `-O2 -mmacosx-version-min=12.0`; do the extraction into a separate
directory (an `ar x` into the directory holding the freshly built object overwrites it with the old one,
which made the first "patched" Swift run here a no-op).

Not done here: the three-slice rebuild that a repin needs (macOS, iOS, simulator). Only macOS was built.
