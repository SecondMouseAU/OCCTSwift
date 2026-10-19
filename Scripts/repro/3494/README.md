# #3490: a count a record declares is refused before an array is sized from it

Evidence for carried patch `0074` (`Scripts/patches/README.md` has the write-up, the census of every
count and reference, and the measured tables). It reuses the #3487 harness, `Scripts/repro/3487/`
(`probe.mm`, `matrix.py`), and adds:

- `fixtures.mm`, built by `build-fixtures.sh <OCCT.xcframework> <out-binary>`: `fixtures <dir>` writes
  `x_<name>.brep` (text), `x_<name>.bset` (`BinTools::Write`, read by `BinTools_ShapeSet`) and
  `x_<name>.bin` (`BinTools_ShapeWriter`, read by `BinTools_ShapeReader`) for the record kinds the
  #3487 corpus lacks: every curve type (Bezier and B-spline, rational and periodic, trimmed, offset),
  every surface type, every 2d curve type as a pcurve, a Polygon3D table, PolygonOnTriangulations and
  Triangulations with normals, composed locations; and six `x_tiny_*` files, the smallest of each
  kind (the records `BREPKernelRecordCountTests` writes into a box are copies of theirs).
- `counts.py <probe> <corpus-dir>... <work-dir> <mode>`: the count matrix. Class `tok` (text, modes
  `path` and `str`): every standalone integer token of every file replaced by each of -1, -2^31,
  2^31 - 1, 10^6 and 10^8, which is every count, index, degree and flag of every record. Class `bint`
  (binary, modes `binset` for `BinTools::Read` and `bin` for `BinTools_ShapeReader`): the four bytes
  at every offset (every 4th for a file over 8,000 bytes) replaced by the same values as a little-endian int. One forked child per case, a
  fault ends only that child, a spin ends at 0.1 s of its own CPU.
- `stage.sh <occt-src> <OCCT.xcframework> <out-dir> <patch>...`: compile the translation units the
  given patches change (or `+worktree` for the uncommitted edits of `<occt-src>`) with the shipped
  slice's flags, and swap them into a copy of the framework's macOS library with `ar r`. A patched
  kernel in about ten seconds; `kernel-integration.yml` is the full build.

```bash
K=<unzipped v4.0.0-kernel.7>/OCCT.xcframework
Scripts/repro/3487/build.sh $K /tmp/probe-k7                 # the probe against kernel.7
Scripts/repro/3494/build-fixtures.sh $K /tmp/fixtures
mkdir /tmp/corpus /tmp/xcorpus
/tmp/probe-k7 gen /tmp/corpus && /tmp/fixtures /tmp/xcorpus
Scripts/repro/3494/stage.sh Libraries/occt-src $K /tmp/stage Scripts/patches/007[0-4]*.patch
Scripts/repro/3487/build.sh /tmp/stage/xcf /tmp/probe-patched
for m in str binset bin; do
  python3 Scripts/repro/3494/counts.py /tmp/probe-patched /tmp/corpus /tmp/xcorpus /tmp/run-$m $m
done
```

`probe.mm` gains the mode `binset` here, and a stack of its own for the fault handler (a stack
overflow has no stack to print its backtrace on, which is what an unbounded recursion in
`Geom_RectangularTrimmedSurface::SetTrim` is). `python3 Scripts/repro/3487/sites.py <probe>
<results.tsv> <mode> --class SIG11` groups the faults by site.

The meaning of the classes in the tables of the patch's README entry: `refused-null` and
`refused-threw` are a read that returned nothing or threw; `accepted-valid` and `accepted-INVALID`
are a read that returned a shape and its `BRepCheck_Analyzer` verdict; `USE-SIG*` and `USE-HANG`
are a read that returned and then faulted or spun in `BRepCheck_Analyzer`, which is the use site of
a damaged coordinate or reference and not the reader; `SIG*` and `HANG` are the reader itself.
